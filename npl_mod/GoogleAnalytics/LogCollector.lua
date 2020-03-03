--[[
title: LogCollector
author: DreamAndDead
date: 2020/03/02
desc: a logger for collecting anything you care to log server
    
===========================================================================================
useage:
===========================================================================================

local LogCollector = NPL.load("npl_mod/GoogleAnalytics/LogCollector")
local logger = LogCollector:new():init()

-- level, title, body
logger:send('info', 'runtime error at line 122 in file server.lua', 'server does not support this operation.')
]]


local LogCollector = commonlib.inherit(nil, NPL.export())

local LOG_SERVER_URL = 'http://paralog.kp-para.cn'

function LogCollector:ctor()
end

function LogCollector:init(server_url)
    self.server_url = server_url or LOG_SERVER_URL

    self.base = {
        os = {
            platform = nil,                -- windows, linux, mac, android, ios
            bits = nil,                    -- x64 or x32
            version = nil,                 -- can't detect it
        },
        device = {
            memory = {
                total = nil,                -- 16294 (MB)
            },
            graphics = {
                videocard = nil,            -- HAL (pure hw vp): Intel(R) HD Graphics 530|58.70 fps (960x560), backbuf A8R8G8B8, adapter X8R8G8B8 (D24S8)
            }
        },
        app = {
            name = nil,                    -- paracraft, haqi or haqi2
            version = nil,                 -- like 0.7.523
            env = nil,                     -- dev, prod
        },
        user = {
            name = nil,                    -- keepwork name or machine id
            source = nil,                  -- keepwork or anonymous
        },

        level = nil,                       -- info, warn, debug, error
        title = nil,                       --
        body = nil,                        --
    }

    -- GetPlatform returns win32, linux, mac, android, ios
    local plat = System.os.GetPlatform()
    if plat == 'win32' then
        plat = 'windows'
    end
    self.base['os']['platform'] = plat

    if System.os.Is64BitsSystem() then
        self.base['os']['bits'] = 'x64'
    else
        self.base['os']['bits'] = 'x32'
    end

    local pc_stat = System.os.GetPCStats()
    self.base['device']['memory']['total'] = math.floor(pc_stat['memory'])
    self.base['device']['graphics']['videocard'] = pc_stat['videocard']

    -- TODO: os version

    self.base['app']['name'] = self:_app_name()
    self.base['app']['version'] = System.options.ClientVersion

    self.base['user']['name'], self.base['user']['source'] = self:_user_info()

    return self
end

function LogCollector:_app_name()
    if System.options.mc then
        return "paracraft"
    end

    if System.options.version == 'kids' then
        return "haqi"
    end

    if System.options.version == 'teen' then
        return "haqi2"
    end
end

function LogCollector:_user_info()
    token = System.User.keepworktoken
    if not token then
        return self:_client_id(), 'anonymous'
    end

    -- token format, xxxxxxxxx.xxxxxxxxxx.xxxxxxxxxx
    -- the middle part(seperated by .) is user info in base64 format
    base64_info = string.gsub(token, '[^.]*.([^.]*).[^.]*', '%1')

    -- padding '=' until info len reaches multiple of 4
    mod = string.len(base64_info) % 4
    if mod ~= 0 then
        mod = 4 - mod
    end
    base64_info = base64_info .. string.rep('=', mod)

    NPL.load("(gl)script/ide/System/Encoding/base64.lua");
    local Encoding = commonlib.gettable("System.Encoding");
    -- user_json content like below
    -- "{\"username\":\"dreamanddead\",\"userId\":1234,\"exp\":1542093124}"
    json_info = Encoding.unbase64(base64_info)

    NPL.load("(gl)script/ide/Json.lua");
    user = commonlib.Json.Decode(json_info)

    if user and user.username then
        return user.username, 'keepwork'
    end
end

function LogCollector:_client_id()
    return commonlib.Encoding.PasswordEncodeWithMac("uid")
end

function LogCollector:_post(url, payload)
    local http_post = System.os.GetUrl
    http_post(
        {
            url = url,
            headers = {
                ['Content-Type'] = 'application/json',
            },
            json = true,
            form = payload,
        },
        function (err, msg, data)
            if(err == 200) then
                LOG.std(nil, "debug", "LogCollector event sent", payload)
            else
                LOG.std(nil, "warn", "LogCollector", "failed with http code: %d", err)
                LOG.std(nil, "warn", "LogCollector", payload)
            end
        end
    )
end

function LogCollector:send(level, title, body)
    self.base['level'] = level
    self.base['title'] = title
    self.base['body'] = body

    self:_post(self.server_url, self.base)
end
