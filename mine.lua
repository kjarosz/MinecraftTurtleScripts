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

function serialize(data, name)
    if not fs.exists('/data') then
        fs.makeDir('/data')
    end
    local f = fs.open('/data/'..name, 'w')
    f.write(textutils.serialize(data))
    f.close()
end
 
function unserialize(name)
    if fs.exists('/data/'..name) then
        local f = fs.open('/data/'..name, 'r')
        data = textutils.unserialize(f.readAll())
        f.close()
    end
    return data
end

function initialize_status()
    digging_status = {}
    digging_status["position"] = 0
    digging_status["direction"] = DIRECTION_FORWARD
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
            print(reason)
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
        print("Not enough torches. Required at least")
        print(needed_torches)
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
        print("Not enough coal. Required at least")
        print(needed_coal)
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

function main()
    digging_status = unserialize(EXCAVATION_STATUS_FILE)

    if digging_status == nil then
        digging_status = initialize_status()
    end

    if not has_enough_items(digging_status) then
        print("Please provide enough could to fuel a full trip")
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