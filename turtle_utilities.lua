local M = {}

local Logger = require("logging")
local log = Logger.new("Utils")

function M.serialize(data, name)
    log.debug("Serializing data for "..name)
    local data_file = fs.open(name, 'w')
    data_file.write(textutils.serialize(data))
    data_file.flush()
    data_file.close()
    log.debug("Serialized and written")
end

function M.unserialize(name)
    log.debug("Unserializing "..name)
    if fs.exists(name) then
        log.debug("File "..name.." found")
        local data_file = fs.open(name, 'r')
        local data = textutils.unserialize(data_file.readAll())
        data_file.close()
        log.debug("File "..name.." unserialized")
        return data
    else
        log.debug("File "..name.." could not be found")
        return nil
    end
end

function M.select_item_index(name)
    log.debug("Looking for "..name.." in inventory")
    for i = 1, 16, 1 do
        turtle.select(i)
        local item_detail = turtle.getItemDetail()
        if not (item_detail == nil) and item_detail["name"] == name then
            log.debug(name.." found in position "..i.." with "..item_detail["count"].." units")
            return true, item_detail["count"]
        end
    end
    log.debug(name.." was not be found")
    return false, 0
end

return M