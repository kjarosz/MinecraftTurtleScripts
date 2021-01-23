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

Digger = {
    data = {
        position = 0,
        direction = DIRECTION_FORWARD
    }
}

function Digger:load_data()
    loaded_data = unserialize(EXCAVATION_STATUS_FILE)

    if not loaded_data == nil then
        self.data = loaded_data
    end
end

function Digger:save_data()
    serialize(self.data, EXCAVATION_STATUS_FILE)
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

function Digger:has_enough_torches()
    if self.data.direction == DIRECTION_FORWARD then
        torch_found, torch_count = select_item_index(ITEM_DETAIL_TORCH)
        needed_torches = math.floor((FULL_TUNNEL_TORCH_SPAN - self.data.position) / 4)
        if not self.data.position == 0 and needed_torches > torch_count then
            log_error("Not enough torches. Required at least")
            log_error(needed_torches)
            return false
        end
    end
    return true
end

function Digger:is_done()
    return self.data.direction == DIRECTION_BACKWARD and self.data.position == 0
end

function Digger:fuel()
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

function Digger:move()
    self.fuel()
    if self.data.direction == DIRECTION_FORWARD then
        while not turtle.forward() do
            turtle.dig()
        end
        self.data.position = self.data.position + 1
        while turtle.detectUp() do
            turtle.digUp()
        end
        if self.needs_a_torch() then
            turtle.turnLeft()
            select_item_index(ITEM_DETAIL_TORCH)
            turtle.turnRight()
        end
        if self.is_at_the_end() then
            turtle.turnRight()
            turtle.turnRight()
            turtle.turnRight()
            self.data.direction = DIRECTION_BACKWARD
        end
    else 
        while not turtle.forward() do
            turtle.dig()
        end
        self.data.position = self.data.position - 1
    end
end

function Digger:needs_a_torch()
    return self.data.position % 4 == 0 and not self.data.position == 0
end

function Digger:is_at_the_end()
    return self.data.position == FULL_TUNNEL_TORCH_SPAN
end

function Digger:reset_turtle()
    self.data.position = 0
    self.data.direction = DIRECTION_FORWARD
    self.save_data()
end

function main()
    Digger.load_data()
    if not Digger.check_items() then
        return
    end

    while Digger.is_done() do
        Digger.move()
        Digger.save_data()
    end

    Digger.reset_turtle()
end

main()