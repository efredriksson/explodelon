local fonts = require("fonts")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local screen = require("screen")


local type MenuFont = fonts.MenuFont 
local type Scene = scenes.Scene

local ROM_DIR = "/recalbox/share/roms/lutro"
local RELEASE_URL = "https://api.github.com/repos/efredriksson/explodelon/releases/latest"
local white_font: MenuFont
local update_screen = {}

local function capture(cmd: string): string
    local f = assert(io.popen(cmd, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function run_script(script_name: string): (integer, string)
    local output = capture("sh -c '" .. script_name .. "; echo EXIT_CODE:$?'")
    local ok = tonumber(output:match("EXIT_CODE:(%d+)")) as integer
    return ok, output
end

local function file_exists(name: string): boolean
    local f = io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

local function file_size(name: string): integer
    local f = io.open(name,"r")
    if f~=nil then 
        local size = f:seek("end")
        io.close(f)
        return size
    else
        return 0
    end
end

local record UpdateCheckScene is Scene
	ctx: Scene
    since_last_connection_check: number
    have_connection: boolean
    download_url: string
    is_up_to_date: boolean
    started_download: boolean
    download_size_so_far: number
    since_last_download_check: number
end

function update_screen.new(ctx: Scene): UpdateCheckScene
    local self: UpdateCheckScene = setmetatable({}, { __index = UpdateCheckScene })
    self.ctx = ctx
    self.since_last_connection_check = 0
    self.have_connection = false
    self.download_url = ""
    self.is_up_to_date = false
    self.started_download = false
    self.download_size_so_far = 0
    self.since_last_download_check = 0
    return self
end

function UpdateCheckScene:game_package(): string
    assert(#self.download_url > 0, "implementation error")
    return self.download_url:match("[^/]*$")
end

function UpdateCheckScene:download_dst(): string
    return ROM_DIR .. "/" .. self:game_package()
end

function UpdateCheckScene:download_finish_marker(): string
    return "/tmp/" .. self:game_package()
end

function UpdateCheckScene:download_finished(): boolean
    return file_exists(self:download_finish_marker())
end

function UpdateCheckScene:update(dt: number)
    if joysticks.is_pressed_any(joysticks.BUTTONS.L) or joysticks.is_pressed_any(joysticks.BUTTONS.A) then
        scenes.set(self.ctx)
        return
    end

    if not self.have_connection and self.since_last_connection_check < 1 then
        self.since_last_connection_check = 0
        local ok, output = run_script("curl -s " .. RELEASE_URL)
        if ok == 0 then
            self.download_url = output:match('"browser_download_url"%s*:%s*"([^"]+)"')
            self.have_connection = true
            -- Need to check if up to date before dowing any download
            self.is_up_to_date = file_exists(self:download_dst())
        end
    end
    if self.have_connection and not (self.started_download or self.is_up_to_date) then
        self.started_download = true
        local download_cmd = "wget -O " .. self:download_dst() .. " " .. self.download_url
        local finish_touch = " && touch " .. self:download_finish_marker()
        os.execute(download_cmd .. finish_touch .. " &")
    end
    if self.started_download and self.since_last_download_check < 0.2 then
        self.since_last_download_check = 0
        self.download_size_so_far = file_size(self:download_dst())
    end

    self.since_last_connection_check = self.since_last_connection_check + dt
end

local function show(left: string, right: string, y_cord: number)
    lutro.graphics.setFont(white_font.main)
    lutro.graphics.printf(left, 10, y_cord, screen.WIDTH, "left")
    lutro.graphics.printf(right, 160, y_cord, screen.WIDTH, "left")
end

function UpdateCheckScene:draw()
	lutro.graphics.setColor(72, 72, 72)
	lutro.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)

    local function connection_str(): string
        if self.have_connection then return "ok" else return "  " end
    end

    show("checking connection... ", connection_str(), 40)

    local function is_up_to_date_str(): string
        if self.is_up_to_date then return "yes" else return "no " end
    end

    if self.have_connection then
        show("latest game file is ", self:game_package(), 50)
        show("game up to date... ", is_up_to_date_str(), 60)
    end

    if self.started_download then
        show("downloading...", self.download_size_so_far .. " bytes", 70)
    end

    if self:download_finished() then
        show("download finished! please restart system", "", 120)
    end

    show("press l1 to go back", "", 130)
end

function update_screen.load_assets()
    white_font = fonts.new_menu_white()
end

function update_screen.is_recalbox(): boolean
    return file_exists(ROM_DIR)
end

return update_screen
