local Logger = {}

Logger.LOGGER_CONFIG_FILE = "logger_config.data"

Logger.LOGGER_OUTPUT_FILE = "log.txt"

Logger.LOGGER_LEVEL_STATUS_ERROR = "error"
Logger.LOGGER_LEVEL_STATUS_INFO = "info"
Logger.LOGGER_LEVEL_STATUS_DEBUG = "debug"

-- Copied from turtle_utilities
function serialize(data, name)
    local data_file = fs.open(name, 'w')
    data_file.write(textutils.serialize(data))
    data_file.flush()
    data_file.close()
end

function unserialize(name)
    if fs.exists(name) then
        local data_file = fs.open(name, 'r')
        local data = textutils.unserialize(data_file.readAll())
        data_file.close()
        return data
    else
        return nil
    end
end

Logger.new = function(_tag)
    local self = {
        tag = _tag or "Untagged"
    }

    self.config = unserialize(Logger.LOGGER_CONFIG_FILE)
    if self.config == nil then
        self.config = {
            level = Logger.LOGGER_LEVEL_STATUS_INFO,
            filename = Logger.LOGGER_OUTPUT_FILE
        }
        serialize(self.config, Logger.LOGGER_CONFIG_FILE)
    end

    if not (
        self.config.level == Logger.LOGGER_LEVEL_STATUS_ERROR or
        self.config.level == Logger.LOGGER_LEVEL_STATUS_DEBUG or
        self.config.level == Logger.LOGGER_LEVEL_STATUS_INFO
    ) then
        self.config.level = Logger.LOGGER_LEVEL_STATUS_INFO
    end

    local function write_to_file(level, message)
        local out_string = self.tag.." - ["..level.."] - "..message

        print(out_string)

        local log_file = fs.open(self.config.filename, 'a')
        log_file.write(out_string.."\n")
        log_file.flush()
        log_file.close()
    end

    local function log(level, message)
        if (self.config.level == Logger.LOGGER_LEVEL_STATUS_DEBUG) 
        or (self.config.level == Logger.LOGGER_LEVEL_STATUS_INFO and
                (level == Logger.LOGGER_LEVEL_STATUS_ERROR or
                 level == Logger.LOGGER_LEVEL_STATUS_INFO))
        or (self.config.level == Logger.LOGGER_LEVEL_STATUS_ERROR and
                (level == Logger.LOGGER_LEVEL_STATUS_ERROR)) 
        then
            write_to_file(level, message)
        end
    end

    self.info = function(message) 
        log(Logger.LOGGER_LEVEL_STATUS_INFO, message)
    end

    self.debug = function(message)
        log(Logger.LOGGER_LEVEL_STATUS_DEBUG, message)
    end

    self.error = function(message, die)
        log(Logger.LOGGER_LEVEL_STATUS_ERROR, message)
        if die then
            error(message, 2)
        end
    end

    return self
end

return Logger