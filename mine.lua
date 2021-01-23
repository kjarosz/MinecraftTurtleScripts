EXCAVATION_STATUS_FILE = "excavation_data.data"

ITEM_DETAIL_COAL = "minecraft:coal"
ITEM_DETAIL_TORCH = "minecraft:torch"

DIRECTION_FORWARD = 1
DIRECTION_BACKWARD = 0

TORCH_SPAN = 4
EXPECTED_TORCHES = 64
FULL_TUNNEL_TORCH_SPAN = TORCH_SPAN * EXPECTED_TORCHES

COAL_FUEL_VALUE = 80

local function log_error(message)
    local log_file = fs.open('log.txt', 'a')
    log_file.write(message)
    log_file.write("\n")
    log_file.flush()
    log_file.close()
end

local function serialize(data, name)
    local data_file = fs.open(name, 'w')
    data_file.write(textutils.serialize(data))
    data_file.flush()
    data_file.close()
end

local function unserialize(name)
    if fs.exists(name) then
        local data_file = fs.open(name, 'r')
        local data = textutils.unserialize(data_file.readAll())
        data_file.close()
        return data
    else
        return nil
    end
end

local function select_item_index(name)
    for i = 1, 16, 1 do
        turtle.select(i)
        local item_detail = turtle.getItemDetail()
        if not (item_detail == nil) and item_detail["name"] == name then
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

function Digger.__init__(baseClass)
    local self = { 
        data = {
            position = 0,
            direction = DIRECTION_FORWARD
        }
    }
    setmetatable(self, { __index = Digger })
    return self
end

setmetatable(Digger, {__call=Digger.__init__})

function Digger:load_data()
    print("Loading data")
    local loaded_data = unserialize(EXCAVATION_STATUS_FILE)

    if not loaded_data == nil then
        print("Data found and loaded: "..textutils.serialize(loaded_data))
        self.data = loaded_data
    end
end

function Digger:save_data()
    print("Saving data: "..textutils.serialize(self.data))
    serialize(self.data, EXCAVATION_STATUS_FILE)
end

function Digger:check_items()
    return self:has_enough_coal() and self:has_enough_torches()
end

function Digger:has_enough_coal()
    print("Checking for coal")
    local coal_found, coal_count = select_item_index(ITEM_DETAIL_COAL)

    local needed_coal = 0
    if self.data.direction == DIRECTION_FORWARD then
        needed_coal = math.ceil((2 * FULL_TUNNEL_TORCH_SPAN - turtle.getFuelLevel()) / COAL_FUEL_VALUE)
    else
        needed_coal = math.ceil((FULL_TUNNEL_TORCH_SPAN - turtle.getFuelLevel()) / COAL_FUEL_VALUE)
    end

    if not (coal_count >= needed_coal) then
        print("Not enough coal. Required at least " .. needed_coal .. " but found " .. coal_count .. ".")
        return false
    else
        print("Enough coal found")
        return true
    end
end

function Digger:has_enough_torches()
    print("Checking torches")
    if self.data.direction == DIRECTION_FORWARD then
        local torch_found, torch_count = select_item_index(ITEM_DETAIL_TORCH)
        local needed_torches = math.floor((FULL_TUNNEL_TORCH_SPAN - self.data.position) / 4)
        if not self.data.position == 0 and needed_torches > torch_count then
            print("Not enough torches. Required at least " .. needed_torches .. " but found " .. torch_count .. ".")
            return false
        else
            print("Enough torches found")
        end
    else
        print("Torches not needed")
    end
    return true
end

function Digger:is_done()
    return self.data.direction == DIRECTION_BACKWARD and self.data.position == 0
end

function Digger:fuel()
    if turtle.getFuelLevel() == 0 then
        print("Fueling")
        local found, count = select_item_index(ITEM_DETAIL_COAL)
        if found then
            turtle.refuel(1)
        else
            print("Coal has not been found")
            return false
        end
    end
end

function Digger:move()
    self:fuel()
    if self.data.direction == DIRECTION_FORWARD then
        print("Moving forward")
        while not turtle.forward() do
            turtle.dig()
        end
        self.data.position = self.data.position + 1
        print("Digging above")
        while turtle.detectUp() do
            turtle.digUp()
        end
        if self:needs_a_torch() then
            print("Placing a torch")
            turtle.turnLeft()
            select_item_index(ITEM_DETAIL_TORCH)
            turtle.turnRight()
        end
        if self:is_at_the_end() then
            print("Turning around")
            turtle.turnRight()
            turtle.turnRight()
            turtle.turnRight()
            self.data.direction = DIRECTION_BACKWARD
        end
    else
        print("Moving back")
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
    self:save_data()
end

local function main()
    local digger = Digger()
    digger:load_data()
    if not digger:check_items() then
        return
    end

    while digger:is_done() do
        digger:move()
        digger:save_data()
    end

    digger:reset_turtle()
end

main()