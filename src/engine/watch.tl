-- Builds changed Teal files into the directory the game loads from and copies changed
-- assets, then keeps doing it. Holding the compiler in one process makes a rebuild cost
-- 0.02s rather than the 1.1s a fresh `tl gen` spends re-checking every module the file
-- requires. Built module names are appended to a stamp engine.hot_reload reads.
--
-- tlconfig.lua decides what is compiled, how modules are named and which problems hold
-- a file back, read as tl's command line reads it, so a file written here is the file
-- `tl gen` would have written. Asset directories are arguments; tl has no such concept.
--
-- Usage: tl run src/engine/watch.tl <output directory> [asset directory...]
-- Run from the directory holding tlconfig.lua; every path here is relative to it.

-- Nothing from this project is required here, itertools included: this runs before
-- anything has been built, so no project module has a .lua file to load yet.
local tl = require("tl")

local CONFIG_PATH = "tlconfig.lua"

local SECONDS_BETWEEN_POLLS = 0.1

local MARK_PATH = ".watch-mark"
local NEXT_MARK_PATH = ".watch-mark-next"
local STAMP_NAME = ".reload-stamp"

local GENERATE_OPTIONS: tl.GenerateOptions = {
    preserve_indent = true,
    preserve_newlines = true,
}

local function read_file(path: string): string
    local file = io.open(path, "rb")
    if file == nil then
        return nil
    end

    local contents = file:read("*a")
    file:close()

    return contents
end

local function directory_of(path: string): string
    local directory = path:match("^(.*)/[^/]*$")
    return directory
end

local function ensure_directory(path: string)
    os.execute("mkdir -p '" .. path .. "'")
end

-- Creating the directory ahead of every write forks a shell per file, close to a second
-- of a first build, so it is done only once a write has found the directory missing.
local function open_for_writing(path: string): FILE
    local file = io.open(path, "wb")
    if file ~= nil then
        return file
    end

    ensure_directory(directory_of(path))

    return assert(io.open(path, "wb"))
end

local function write_file(path: string, contents: string)
    local file = open_for_writing(path)
    file:write(contents)
    file:close()
end

local function file_exists(path: string): boolean
    local file = io.open(path, "rb")
    if file == nil then
        return false
    end
    file:close()

    return true
end

local function touch_file(path: string)
    write_file(path, "")
end

local function command_lines(command: string): {string}
    local lines: {string} = {}
    local pipe = io.popen(command)
    if pipe == nil then
        return lines
    end

    for line in pipe:lines() do
        table.insert(lines, line)
    end
    pipe:close()

    return lines
end

-- popen rather than os.execute, which is system(): POSIX has system() ignore SIGINT for
-- as long as the child runs, and since this sleep is most of every round, Ctrl+C would
-- kill the sleep and leave the watcher running.
local function sleep(seconds: number)
    io.popen("sleep " .. seconds):close()
end

-- Declared, not validated: tl runs the same file and reports the keys it rejects.
local record TlConfig
    include_dir: {string}
    global_env_def: string
    feat_arity: tl.Feat
    gen_compat: tl.GenCompat
    gen_target: tl.GenTarget
    skip_compat53: boolean
    disable_warnings: {string}
    warning_error: {string}
end

local function effective_gen_compat(given: TlConfig): tl.GenCompat
    if given.skip_compat53 then
        return "off"
    end

    return given.gen_compat
end

function TlConfig.new(loaded?: TlConfig): TlConfig
    local self: TlConfig = setmetatable({}, {__index = TlConfig})
    local given = loaded or {}
    self.include_dir = given.include_dir or {}
    self.global_env_def = given.global_env_def
    self.feat_arity = given.feat_arity
    self.gen_compat = effective_gen_compat(given)
    self.gen_target = given.gen_target
    self.disable_warnings = given.disable_warnings or {}
    self.warning_error = given.warning_error or {}

    return self
end

local function load_config(path: string): TlConfig
    if not file_exists(path) then
        return TlConfig.new()
    end

    -- loadfile rather than load, because a project that turns gen_compat off leaves
    -- this file without the shim that lets load take a string on Lua 5.1.
    local chunk: function(): TlConfig = assert(loadfile(path))
    return TlConfig.new(chunk())
end

local function predefined_modules(config: TlConfig): {string}
    if config.global_env_def == nil then
        return {}
    end

    return {config.global_env_def}
end

local function new_environment(config: TlConfig): tl.Env
    local options: tl.EnvOptions = {
        defaults = {
            -- tl reads a .tl in strict mode whatever the config says; lax is for .lua.
            feat_lax = "off",
            feat_arity = config.feat_arity,
            gen_compat = config.gen_compat,
            gen_target = config.gen_target,
        },
        predefined_modules = predefined_modules(config),
    }

    return assert(tl.new_env(options))
end

-- find echoes a root exactly as spelled and tl caches by the path handed to it, so
-- "./src" from the config and "src" from a find check the same module twice, leaving a
-- record out of one copy a different type from the same record out of the other.
local function normalized(directory: string): string
    return (directory:gsub("^%./", ""):gsub("/$", ""))
end

local function normalized_roots(...: {string}): {string}
    local roots: {string} = {}
    for _, directories in ipairs({...}) do
        for _, directory in ipairs(directories) do
            table.insert(roots, normalized(directory))
        end
    end

    return roots
end

local function prepend_to_search_path(roots: {string})
    for _, root in ipairs(roots) do
        package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
    end
end

local function is_type_definition(path: string): boolean
    return path:match("%.d%.tl$") ~= nil
end

local function is_teal_source(path: string): boolean
    return path:match("%.tl$") ~= nil and not is_type_definition(path)
end

local function relative_to_roots(path: string, roots: {string}): string
    for _, root in ipairs(roots) do
        local prefix = root .. "/"
        if path:sub(1, #prefix) == prefix then
            return path:sub(#prefix + 1)
        end
    end

    return nil
end

-- The inverse of the search path entries installed above, so src/engine/geometry/init.tl
-- gives engine.geometry, the name the running game holds it under and a swap needs.
local function module_name_for(path: string, relative_path: string): string
    if relative_path == nil or not is_teal_source(path) then
        return nil
    end

    local dotted = relative_path:gsub("%.tl$", ""):gsub("/init$", ""):gsub("/", ".")
    return dotted
end

local function output_path(relative_path: string): string
    local output = relative_path:gsub("%.tl$", ".lua")
    return output
end

-- Answered once, when the file turns up, so the build asks the file what it is instead
-- of re-deriving it from the path in an order it has to get right.
local record ChangedFile
    path: string
    module_name: string
    destination: string
end

function ChangedFile.new(
    path: string, source_roots: {string}, dist_dir: string
): ChangedFile
    local self: ChangedFile = setmetatable({}, {__index = ChangedFile})
    local relative = relative_to_roots(path, source_roots)
    self.path = path
    self.module_name = module_name_for(path, relative)
    self.destination = dist_dir .. "/" .. output_path(relative or path)

    return self
end

local function holds_type_definition(paths: {string}): boolean
    for _, path in ipairs(paths) do
        if is_type_definition(path) then
            return true
        end
    end

    return false
end

local function find_command(roots: {string}, newer_than?: string): string
    local command = "find"
    for _, root in ipairs(roots) do
        command = command .. " '" .. root .. "'"
    end
    command = command .. " -type f"
    if newer_than == nil then
        return command
    end

    return command .. " -newer " .. newer_than
end

-- Two marks, so the one a round compares against carries that round's start time: a
-- file saved mid-round is caught next round instead of buried under a newer mark.
local function files_changed_since(roots: {string}, mark?: string): {string}
    touch_file(NEXT_MARK_PATH)
    local changed = command_lines(find_command(roots, mark))
    os.rename(NEXT_MARK_PATH, MARK_PATH)

    return changed
end

local function all_files_under(roots: {string}): {string}
    return files_changed_since(roots)
end

local function warning_set(kinds: {string}): {string: boolean}
    local set: {string: boolean} = {}
    for _, kind in ipairs(kinds) do
        if kind == "all" then
            for known in pairs(tl.warning_kinds) do
                set[known] = true
            end
        else
            set[kind] = true
        end
    end

    return set
end

local record WarningRules
    silenced: {string: boolean}
    fatal: {string: boolean}
end

function WarningRules.new(config: TlConfig): WarningRules
    local self: WarningRules = setmetatable({}, {__index = WarningRules})
    self.silenced = warning_set(config.disable_warnings)
    self.fatal = warning_set(config.warning_error)

    return self
end

-- A disabled kind is dropped before it can be promoted, the order tl applies the two
-- keys in, so a kind named by both kills nothing.
function WarningRules:sorted(warnings: {tl.Error}): {tl.Error}, {tl.Error}
    local notes: {tl.Error} = {}
    local blocking: {tl.Error} = {}
    for _, warning in ipairs(warnings or {}) do
        if self.fatal[warning.tag] and not self.silenced[warning.tag] then
            table.insert(blocking, warning)
        elseif not self.silenced[warning.tag] then
            table.insert(notes, warning)
        end
    end

    return notes, blocking
end

local function problem_line(problem: tl.Error): string
    local location = problem.filename .. ":" .. problem.y .. ":" .. problem.x
    return location .. ": " .. problem.msg .. "\n"
end

-- tl leaves a list nil for problems it never got far enough to look for: a file that
-- failed to parse has no warnings list at all.
local function report(problems: {tl.Error}): integer
    local listed = problems or {}
    for _, problem in ipairs(listed) do
        io.stderr:write(problem_line(problem))
    end

    return #listed
end

local record Builder
    dist_dir: string
    stamp_path: string
    config: TlConfig
    source_roots: {string}
    warning_rules: WarningRules
    environment: tl.Env
end

function Builder.new(
    dist_dir: string, config: TlConfig, source_roots: {string}
): Builder
    local self: Builder = setmetatable({}, {__index = Builder})
    self.dist_dir = dist_dir
    self.stamp_path = dist_dir .. "/" .. STAMP_NAME
    self.config = config
    self.source_roots = source_roots
    self.warning_rules = WarningRules.new(config)
    self.environment = new_environment(config)

    -- The game reads this file's existence as the sign a watcher is running, and a
    -- watcher on current output writes nothing, so waiting for a first module would
    -- leave the game thinking nothing was. Never truncated: the game indexes into it.
    if not file_exists(self.stamp_path) then
        touch_file(self.stamp_path)
    end

    return self
end

-- tl caches a checked file by path and a module's type by name, handing either back
-- unread, so a save not forgotten first compiles to the version before it.
function Builder:_forget(file: ChangedFile)
    if file.module_name == nil then
        return
    end

    self.environment.loaded[file.path] = nil
    self.environment.modules[file.module_name] = nil
end

function Builder:_stamp(module_name: string)
    local stamp = assert(io.open(self.stamp_path, "a"))
    stamp:write(module_name .. "\n")
    stamp:close()
end

-- Compared before writing so that starting the watcher again does not stamp every
-- module and have a running game swap all of them.
function Builder:_write(path: string, contents: string): boolean
    if read_file(path) == contents then
        return false
    end

    write_file(path, contents)
    print("Wrote: " .. path)

    return true
end

-- Everything is printed, but a warning tlconfig has not promoted is a note, not a
-- reason to keep the running game on the code it already has.
function Builder:_blocks_output(result: tl.Result): boolean
    local errors = report(result.syntax_errors) + report(result.type_errors)
    local notes, promoted = self.warning_rules:sorted(result.warnings)
    report(notes)

    return errors + report(promoted) > 0
end

function Builder:_transpile(file: ChangedFile): boolean
    local result, failure = tl.check_file(file.path, self.environment)
    if result == nil then
        io.stderr:write(failure .. "\n")
        return false
    end

    if self:_blocks_output(result) then
        return false
    end

    self.environment.modules[file.module_name] = result.type

    local code = tl.generate(result.ast, self.config.gen_target, GENERATE_OPTIONS)
        .. "\n"
    if not self:_write(file.destination, code) then
        return false
    end

    self:_stamp(file.module_name)

    return true
end

function Builder:_copy(file: ChangedFile): boolean
    local contents = read_file(file.path)
    if contents == nil then
        return false
    end

    return self:_write(file.destination, contents)
end

function Builder:_build(file: ChangedFile): boolean
    if file.module_name == nil then
        return self:_copy(file)
    end

    return self:_transpile(file)
end

-- A type definition is compiler input, never build output.
function Builder:_changed_files(paths: {string}): {ChangedFile}
    local files: {ChangedFile} = {}
    for _, path in ipairs(paths) do
        if not is_type_definition(path) then
            local file = ChangedFile.new(path, self.source_roots, self.dist_dir)
            table.insert(files, file)
        end
    end

    return files
end

function Builder:_build_all(paths: {string}): integer
    local files = self:_changed_files(paths)
    -- All forgotten before any is built: when a module and something it requires are
    -- saved together, find's order would check one against the other's stale type.
    for _, file in ipairs(files) do
        self:_forget(file)
    end

    local written = 0
    for _, file in ipairs(files) do
        if self:_build(file) then
            written = written + 1
        end
    end

    return written
end

function Builder:reset_environment()
    self.environment = new_environment(self.config)
end

function Builder:build_and_report(paths: {string})
    if #paths == 0 then
        return
    end

    local started = os.clock()
    local written = self:_build_all(paths)
    local seconds = string.format("%.2f", os.clock() - started)
    print("Built " .. written .. " of " .. #paths .. " files in " .. seconds .. "s CPU")
end

-- A type definition is read in when the environment is created, so a change to one
-- takes effect only in a new environment, and every file has to be built against it.
local function changed_since_last_round(builder: Builder, roots: {string}): {string}
    local changed = files_changed_since(roots, MARK_PATH)
    if not holds_type_definition(changed) then
        return changed
    end

    builder:reset_environment()

    return all_files_under(roots)
end

local function asset_roots(): {string}
    local roots: {string} = {}
    for index = 2, #arg do
        table.insert(roots, arg[index])
    end

    return roots
end

local function main()
    local dist_dir = arg[1]
    if dist_dir == nil then
        io.stderr:write(
            "Usage: tl run " .. arg[0] .. " <output directory> [asset directory...]\n"
        )
        os.exit(1)
    end

    local config = load_config(CONFIG_PATH)
    local source_roots = normalized_roots(config.include_dir)
    local watched_roots = normalized_roots(config.include_dir, asset_roots())
    prepend_to_search_path(source_roots)

    local builder = Builder.new(dist_dir, config, source_roots)
    builder:build_and_report(all_files_under(watched_roots))

    local watching = table.concat(watched_roots, ", ")
    print("Watching " .. watching .. ", building into " .. dist_dir)

    while true do
        builder:build_and_report(changed_since_last_round(builder, watched_roots))
        sleep(SECONDS_BETWEEN_POLLS)
    end
end

main()
