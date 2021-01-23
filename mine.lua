require("turtle")
require("fs")

EXCAVATION_STATUS_FILE = "excavation_data.data"

ITEM_DETAIL_COAL = "minecraft:coal"
ITEM_DETAIL_TORCH = "minecraft:torch" 

DIRECTION_FORWARD = 1
DIRECTION_BACKWARD = 0

TORCH_SPAN = 4
EXPECTED_TORCHES = 64
FULL_TUNNEL_TORCH_SPAN = TORCH_SPAN * EXPECTED_TORCHES

function log_error(message)
    log_file = fs.open('log.txt', 'a')
    log_file.write(message)
    log_file.write("\n")
    log_file.flush()
    log_file.close()
end

function serialize(data, name)
    data_file = fs.open(name, 'w')
    data_file.write(textutils.serialize(data))
    data_file.flush()
    data_file.close()
end
 
function unserialize(name)
    if fs.exists(name) then
        data_file = fs.open(name, 'r')
        data = textutils.unserialize(data_file.readAll())
        data_file.close()
    end
    return data
end

function is_done(status)
    if status["direction"] == DIRECTION_BACKWARD and status["position"] == 0 then
        return true
    else
        return false
    end
end

function fuel()
    if turtle.getFuelLevel() == 0 then
        found, reason = select_item_index(ITEM_DETAIL_COAL)
        if found then
            turtle.refuel(1)
        else 
            log_error(reason)
            return false
        end
    end
end

function select_item_index(name)
    for i = 1, 16, 1 do
        turtle.select(i)
        item_detail = turtle.getItemDetail()
        if item_detail == nil and item_detail["name"] == name then
            return true, item_detail["count"]
        end
    end
    return false, 0
end

function has_enough_torches(status)
    torch_found, torch_count = select_item_index(ITEM_DETAIL_TORCH)
    needed_torches = math.floor((FULL_TUNNEL_TORCH_SPAN - status["position"]) / 4)
    if not status["position"] == 0 and needed_torches > torch_count then
        log_error("Not enough torches. Required at least")
        log_error(needed_torches)
        return false
    end
    return true
end

function has_enough_coal(status)
    coal_found, coal_count = select_item_index(ITEM_DETAIL_COAL)
    if status["direction"] == DIRECTION_FORWARD then
        needed_coal = math.ceil((2 * FULL_TUNNEL_TORCH_SPAN - turtle.getFuelLeve()) / COAL_FUEL_VALUE)
    else 
        needed_coal = math.ceil((FULL_TUNNEL_TORCH_SPAN - turtle.getFuelLeve()) / COAL_FUEL_VALUE)
    end
    if not (coal_count >= needed_coal) then
        log_error("Not enough coal. Required at least")
        log_error(needed_coal)
        return false
    end
    return true
end

function has_enough_fuel(status)
    if status["direction"] == DIRECTION_FORWARD then
        return has_enough_torches(status) and has_enough_coal(status)
    else
        return has_enough_coal(status)
    end
end

Digger = {
    data = {
        position = 0,
        direction = DIRECTION_FORWARD
    }
}

function Digger:load_data()
    loaded_data = unserialize(EXCAVATION_STATUS_FILE)

    if not digging_status == nil then
        self.data = loaded_data
    end

    if not has_enough_items(digging_status) then
        log_error("Please provide enough coal to fuel a full trip")
        return
    end
end

function Digger:check_items()
    return self.has_enough_coal() and self.has_enough_torches()
end

function Digger:has_enough_coal()
    coal_found, coal_count = select_item_index(ITEM_DETAIL_COAL)

    if self.data.direction == DIRECTION_FORWARD then
        needed_coal = math.ceil((2 * FULL_TUNNEL_TORCH_SPAN - turtle.getFuelLeve()) / COAL_FUEL_VALUE)
    else 
        needed_coal = math.ceil((FULL_TUNNEL_TORCH_SPAN - turtle.getFuelLeve()) / COAL_FUEL_VALUE)
    end

    if not (coal_count >= needed_coal) then
        log_error("Not enough coal. Required at least")
        log_error(needed_coal)
        return false
    else
        return true
    end
end


function main()
    Digger.load_data()
    if not Digger.check_items() then
        return
    end

    while is_done do
        fuel()
        if digging_status["direction"] == DIRECTION_FORWARD then
            turtle.digUp()
            turtle.dig()
            turtle.forward()
            digging_status["position"] = digging_status["position"] + 1
        else 
            digging_status["position"] = digging_status["position"] + 1
        end
        serialize(digging_status, EXCAVATION_STATUS_FILE)
    end
end

main()