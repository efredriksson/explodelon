-- Makes a saved .tl take effect in the running game, objects already alive
-- included. Assets and built scenes need a rebuild: hold L2 and press R2.

local audio = require("engine.audio")
local joysticks = require("engine.joysticks")
local logger = require("engine.logger")

-- package.loaded has no type, which is what every `as` and every `any` is for.
local type ModuleTable = {string: any}

-- Not finding this file is what turns hot reloading off in a release.
local STAMP_PATH = ".reload-stamp"

local SECONDS_BETWEEN_POLLS = 0.1
local OWN_MODULE_NAME = "engine.hot_reload"

local enabled = false
local applied_module_count = 0
local seconds_since_poll = 0.0
local last_stamp = ""

local hot_reload = {}

local function is_table(value: any): boolean
    return type(value) == "table"
end

local function is_function(value: any): boolean
    return type(value) == "function"
end

local function is_empty_table(value: any): boolean
    return is_table(value) and next(value as {any: any}) == nil
end

local function has_contents(value: any): boolean
    return is_table(value) and next(value as {any: any}) ~= nil
end

-- The same table on both sides is one the module got from elsewhere and passes
-- on, so clearing its functions would empty out whichever module owns it.
local function is_forwardable_pair(old_value: any, fresh_value: any): boolean
    return old_value ~= fresh_value and is_table(old_value) and is_table(fresh_value)
end

-- src/settings.tl returns a record instance, so every function it has is here.
local function methods_behind_index(value: any): ModuleTable
    local own_metatable = getmetatable(value) as ModuleTable
    if own_metatable == nil then
        return nil
    end

    local index = own_metatable.__index
    if not is_table(index) then
        return nil
    end

    return index as ModuleTable
end

-- A fresh chunk's file scope locals start empty, and load_assets only runs at
-- startup. An empty table belongs to a setup or a memo cache; a record table or
-- a constant is never empty.
local function should_carry_over(fresh_value: any, old_value: any): boolean
    if old_value == nil then
        return false
    end

    if fresh_value == nil then
        return true
    end

    return is_empty_table(fresh_value) and has_contents(old_value)
end

local function each_upvalue(fn: function): function(): (integer, string, any)
    local index = 0
    return function(): (integer, string, any)
        index = index + 1
        local name, value = debug.getupvalue(fn, index)
        if name == nil then
            return nil, nil, nil
        end

        return index, name, value
    end
end

local function source_of(fn: function): string
    local definition = debug.getinfo(fn, "S")
    if definition == nil then
        return ""
    end

    local source = definition.source:gsub("\\", "/")
    return source
end

-- Every module sits under the directory the game was loaded from, which a module
-- name does not say, so it is read off this module's own chunk.
local function chunk_source_of(name: string): string
    local own_source = source_of(each_upvalue)
    local own_file = OWN_MODULE_NAME:gsub("%.", "/") .. ".lua"
    local directory = own_source:sub(1, #own_source - #own_file)
    return directory .. name:gsub("%.", "/") .. ".lua"
end

-- Marked as walked before the walk starts: following upvalues reaches every
-- required module's table, and traversing those is most of the work in a swap.
local function other_modules(own: ModuleTable): {any: boolean}
    local reached: {any: boolean} = {}
    for _, module_table in pairs(package.loaded) do
        if module_table ~= own then
            reached[module_table] = true
        end
    end

    return reached
end

-- Upvalues are followed and not just table fields, because src/options_selection.tl
-- keeps private both its record and the draw helpers holding its sprites.
local function each_function_in_chunk(
    value: any,
    chunk_source: string,
    visited: {any: boolean},
    apply: function(fn: function, values: {string: any}),
    values: {string: any}
)
    if value == nil or visited[value] then
        return
    end
    visited[value] = true

    if is_function(value) then
        if source_of(value as function) ~= chunk_source then
            return
        end
        apply(value as function, values)

        for _, _, held_value in each_upvalue(value as function) do
            each_function_in_chunk(held_value, chunk_source, visited, apply, values)
        end
        return
    end

    if not is_table(value) then
        return
    end

    for _, held_value in pairs(value as {any: any}) do
        each_function_in_chunk(held_value, chunk_source, visited, apply, values)
    end

    local behind_index = methods_behind_index(value)
    if behind_index ~= nil then
        each_function_in_chunk(behind_index, chunk_source, visited, apply, values)
    end
end

local function collect_upvalues(fn: function, collected: {string: any})
    for _, name, value in each_upvalue(fn) do
        if collected[name] == nil then
            collected[name] = value
        end
    end
end

local function fill_missing_upvalues(fn: function, collected: {string: any})
    for index, name, fresh_value in each_upvalue(fn) do
        if should_carry_over(fresh_value, collected[name]) then
            debug.setupvalue(fn, index, collected[name])
        end
    end
end

local function replace_upvalues_in(fn: function, replacements: {string: any})
    for index, name, value in each_upvalue(fn) do
        local replacement = replacements[name]
        if replacement ~= nil and replacement ~= value then
            debug.setupvalue(fn, index, replacement)
        end
    end
end

local function forward_to_fresh(
    old: ModuleTable, fresh: ModuleTable, forwarded: {ModuleTable: boolean}
)
    if forwarded[old] then
        return
    end
    forwarded[old] = true

    for key, old_value in pairs(old) do
        local fresh_value = fresh[key]
        if is_forwardable_pair(old_value, fresh_value) then
            -- The same table is kept, because live instances hold it as __index.
            forward_to_fresh(
                old_value as ModuleTable, fresh_value as ModuleTable, forwarded
            )
        elseif is_function(old_value) then
            old[key] = nil
        end
        -- Other values are left alone: asset handles parked here are live, and a
        -- settings singleton's own fields hold the current map and ruleset.
    end

    local old_index = methods_behind_index(old)
    local fresh_index = methods_behind_index(fresh)
    if is_forwardable_pair(old_index, fresh_index) then
        forward_to_fresh(old_index, fresh_index, forwarded)
    end

    setmetatable(old, {__index = fresh})
end

-- game.pause_scene exports neither GamePauseScene nor its methods, so a pause
-- screen already on screen would keep running the code it was opened with.
local function forward_private_records(
    old_upvalues: {string: any},
    fresh_upvalues: {string: any},
    forwarded: {ModuleTable: boolean}
)
    for name, old_value in pairs(old_upvalues) do
        local fresh_value = fresh_upvalues[name]
        if is_forwardable_pair(old_value, fresh_value) then
            forward_to_fresh(
                old_value as ModuleTable, fresh_value as ModuleTable, forwarded
            )
        end
    end
end

-- A settings module's setters write through the chunk local holding its
-- singleton, so the fresh chunk is pointed at the old table the game still reads.
local function self_references(
    old: ModuleTable, fresh: ModuleTable, fresh_upvalues: {string: any}
): {string: any}
    local replacements: {string: any} = {}

    for name, value in pairs(fresh_upvalues) do
        if value == fresh then
            replacements[name] = old
        end
    end

    return replacements
end

local function swap_module(name: string)
    local old = package.loaded[name] as ModuleTable
    if old == nil then
        logger.info("Not loaded, so nothing to swap: " .. name)
        return
    end

    local chunk_source = chunk_source_of(name)
    local carried: {string: any} = {}
    each_function_in_chunk(
        old, chunk_source, other_modules(old), collect_upvalues, carried
    )

    package.loaded[name] = nil
    local required, result = pcall(require, name)
    if not required then
        package.loaded[name] = old
        logger.warning("Hot swap of " .. name .. " failed: " .. tostring(result))
        return
    end

    local fresh = result as ModuleTable
    local function each_fresh_function(
        apply: function(fn: function, values: {string: any}), values: {string: any}
    )
        each_function_in_chunk(fresh, chunk_source, other_modules(fresh), apply, values)
    end

    each_fresh_function(fill_missing_upvalues, carried)

    local fresh_upvalues: {string: any} = {}
    each_fresh_function(collect_upvalues, fresh_upvalues)
    each_fresh_function(
        replace_upvalues_in, self_references(old, fresh, fresh_upvalues)
    )

    local forwarded: {ModuleTable: boolean} = {}
    forward_to_fresh(old, fresh, forwarded)
    forward_private_records(carried, fresh_upvalues, forwarded)
    package.loaded[name] = fresh
    logger.info("Hot swapped " .. name)
end

local function read_stamped_modules(): {string}
    local stamped: {string} = {}
    for name in last_stamp:gmatch("[^\n]+") do
        table.insert(stamped, name)
    end

    return stamped
end

local function stamp_changed(): boolean
    -- Guarded because the core returns a negative result count when it cannot
    -- open the file, which Lua cannot be handed. Deleting the stamp gets there.
    if not lutro.filesystem.exists(STAMP_PATH) then
        return false
    end

    local stamp = lutro.filesystem.read(STAMP_PATH)
    if stamp == last_stamp then
        return false
    end

    last_stamp = stamp
    return true
end

local function apply_stamped_modules()
    local stamped = read_stamped_modules()

    for index = applied_module_count + 1, #stamped do
        local name = stamped[index]
        if name ~= OWN_MODULE_NAME then
            swap_module(name)
        end
    end

    -- Counted even where a swap failed, so a module that raises is reported once
    -- rather than every poll. Saving it again stamps it again, which is a retry.
    applied_module_count = #stamped
end

-- R2 as a press and not as held, because two held buttons would rebuild every
-- frame, and a rebuild reloads every asset in the game.
local function wants_game_rebuild(): boolean
    return joysticks.is_down_any(joysticks.BUTTONS.L2)
        and joysticks.is_pressed_any(joysticks.BUTTONS.R2)
end

-- Only running the constructors again makes the objects built by the old code
-- new, so the game is built from the top. lutro.load ends on the start screen.
local function rebuild_game()
    audio.purge()
    lutro.load()
end

function hot_reload.setup()
    enabled = lutro.filesystem.exists(STAMP_PATH)
    if not enabled then
        return
    end

    -- Adopted, not applied: builds from before this game started are already in it.
    stamp_changed()
    applied_module_count = #read_stamped_modules()
    logger.info(
        "Hot reloading enabled, "
            .. applied_module_count
            .. " modules already built."
            .. " Hold L2 and press R2 to reload assets"
            .. " and rebuild from the start screen."
    )
end

-- Called before joysticks.update, so R2 still reads as a press, and every frame
-- rather than behind the poll interval, which would miss most presses.
function hot_reload.poll(dt: number)
    if not enabled then
        return
    end

    if wants_game_rebuild() then
        logger.info("Reloading assets and rebuilding the game from the start screen")
        rebuild_game()
    end

    seconds_since_poll = seconds_since_poll + dt
    if seconds_since_poll < SECONDS_BETWEEN_POLLS then
        return
    end
    seconds_since_poll = 0

    if stamp_changed() then
        apply_stamped_modules()
    end
end

return hot_reload
