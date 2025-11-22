local logger = {}

function logger.info(msg: string)
    print('[INFO] [EXPLODELON]: ' .. msg)
end

function logger.warning(msg: string)
    print('[WARN] [EXPLODELON]: ' .. msg)
end

return logger
