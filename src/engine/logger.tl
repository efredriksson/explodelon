local logger = {}

local config_app_name = "NOT-CONFIGURED"

function logger.setup(app_name: string)
    config_app_name = app_name
end

function logger.info(msg: string)
    print('[INFO] [' .. config_app_name .. ']: ' .. msg)
end

function logger.warning(msg: string)
    print('[WARN] [' .. config_app_name .. ']: ' .. msg)
end

return logger
