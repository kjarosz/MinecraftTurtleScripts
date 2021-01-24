local M = {}

function M.serialize(data, name)
    local data_file = fs.open(name, 'w')
    data_file.write(textutils.serialize(data))
    data_file.flush()
    data_file.close()
end

function M.unserialize(name)
    if fs.exists(name) then
        local data_file = fs.open(name, 'r')
        local data = textutils.unserialize(data_file.readAll())
        data_file.close()
        return data
    else
        return nil
    end
end

function M.select_item_index(name)
    for i = 1, 16, 1 do
        turtle.select(i)
        local item_detail = turtle.getItemDetail()
        if not (item_detail == nil) and item_detail["name"] == name then
            return true, item_detail["count"]
        end
    end
    return false, 0
end

return M