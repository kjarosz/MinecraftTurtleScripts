local Logger = require("logging")
local turtle_utilities = require("turtle_utilities")

local log = Logger.new()

EXCAVATION_STATUS_FILE = "excavation_data.data"
GPS_SETTINGS_FILE = "gps_settings.data"

ITEM_DETAIL_COAL = "minecraft:coal"
ITEM_DETAIL_TORCH = "minecraft:torch"

DIRECTION_FORWARD = 1
DIRECTION_BACKWARD = 0

AXIS_POSITIVE = 1
AXIS_NEGATIVE = -1

TORCH_SPAN = 4
EXPECTED_TORCHES = 64
FULL_TUNNEL_TORCH_SPAN = TORCH_SPAN * EXPECTED_TORCHES

COAL_FUEL_VALUE = 80

GPS_DEFAULT_TIMEOUT = 2

Digger = {
    gps = false,
    gps_settings = {
        timeout = GPS_DEFAULT_TIMEOUT,
        main_corridor_axis = "X",
        main_corridor_direction = AXIS_POSITIVE,
        main_corridor_start_position = {
            x = 1, 
            y = 1, 
            z = 1 
        },
        branch_corridor_axis = "Y",
        branch_corridor_direction = AXIS_POSITIVE
    },
    data = {
        position = 0,
        direction = DIRECTION_FORWARD
    }
}

function Digger.__init__(baseClass)
    local self = { 
        gps = gps.locate(GPS_DEFAULT_TIMEOUT) != nil,
        gps_settings = nil,
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
    log.info("Loading data")
    local loaded_data = turtle_utilities.unserialize(EXCAVATION_STATUS_FILE)

    if not (loaded_data == nil) then
        log.debug("Data found and loaded: "..textutils.serialize(loaded_data))
        self.data = loaded_data
    end

    if self.gps then
        log.info("Loading gps settings")
        local gps_settings = turtle_utilities.unserialize(GPS_SETTINGS_FILE)
        if self.gps_settings_valid(gps_settings) then
            log.debug("GPS Settings found and loaded: "..textutils.serialize(gps_settings))
        else
            log.debug("Turning off GPS.")
            self.gps = false
        end
    end
end

function Digger:validate_gps_settings(settings)
    if settings == nil then
        log.error("GPS file not found")
        return false
    end

    if gps_settings.main_corridor_axis == gps_settings.branch_corridor_axis then
        log.error("Main corridor and branch corridor axes cannot be the same")
        return false
    end

    if gps_settings.main_corridor_axis == "Z" or gps.settings.branch_corridor_axis == "Z" then
        log.error("Z axis corridors not yet supported")
        return false
    end

    if gps_settings.timeout == nil then
        log.info("No timeout set. Setting default: "..GPS_DEFAULT_TIMEOUT)
        gps_settings.timeout = GPS_DEFAULT_TIMEOUT
    end
end

function Digger:save_data()
    log.debug("Saving data: "..textutils.serialize(self.data))
    turtle_utilities.serialize(self.data, EXCAVATION_STATUS_FILE)
end

function Digger:check_items()
    return self:has_enough_coal() and self:has_enough_torches()
end

function Digger:has_enough_coal()
    log.debug("Checking for coal")
    local coal_found, coal_count = turtle_utilities.select_item_index(ITEM_DETAIL_COAL)

    local remaining_distance = self:get_remaining_tunnel_length()
    local needed_coal = math.ceil((remaining_distance - turtle.getFuelLevel()) / COAL_FUEL_VALUE)

    if not (coal_count >= needed_coal) then
        log.error("Not enough coal. Required at least " .. needed_coal .. " but found " .. coal_count .. ".")
        return false
    else
        log.debug("Enough coal found")
        return true
    end
end

function Digger:get_remaining_tunnel_length(onlyDiggable)
    local distance_from_axis = self:get_distance_from_main_corridor()

    if self.data.direction == DIRECTION_FORWARD then
        return 2 * FULL_TUNNEL_TORCH_SPAN - distance_from_axis
    else
        return distance_from_axis
    end
end

function Digger:get_distance_from_main_corridor() 
    if self.gps then
        local x, y, z = gps.locate(self.gps_settings.timeout)
        if self.gps_settings.main_corridor_axis == "X" then
            if self.gps_settings.branch_corridor_axis == "Y" then
                distance_from_axis = (y - self.gps_settings.main_corridor_start_position.y)
            else
                error("Z axis corridors not yet supported")
            end
        elseif self.gps_settings.main_corridor_axis == "Y" then
            if self.gps_settings.branch_corridor_axis == "X" then
                distance_from_axis = (x - self.gps_settings.main_corridor_start_position.x)
            else
                error("Z axis corridors not yet supported")
            end
        else
            error("Z axis corridors not yet suppoerted")
        end
        distance_from_axis = distance_from_axis*self.gps_settings.main_corridor_direction
    else
        return self.data.position
    end
end

function Digger:has_enough_torches()
    log.debug("Checking torches")
    if self.data.direction == DIRECTION_FORWARD then
        local torch_found, torch_count = turtle_utilities.select_item_index(ITEM_DETAIL_TORCH)
        local remaining_distance = self:get_distance_from_main_corridor()
        local needed_torches = math.floor(remaining_distance / TORCH_SPAN)
        if needed_torches > torch_count then
            log.error("Not enough torches. Required at least " .. needed_torches .. " but found " .. torch_count .. ".")
            return false
        else
            log.debug("Enough torches found")
        end
    else
        log.debug("Torches not needed")
    end
    return true
end

function Digger:is_done()
    local done = self.data.direction == DIRECTION_BACKWARD and self:get_remaining_tunnel_length() == 0
    if done then
        log.info("Digger is done")
    end
    return done
end

function Digger:fuel()
    if turtle.getFuelLevel() == 0 then
        log.debug("Fueling")
        local found, count = turtle_utilities.select_item_index(ITEM_DETAIL_COAL)
        if found then
            turtle.refuel(1)
        else
            log.error("Coal has not been found")
            return false
        end
    end
end

function Digger:move()
    self:fuel()
    if self.data.direction == DIRECTION_FORWARD then
        log.debug("Moving forward")
        while not turtle.forward() do
            turtle.dig()
        end
        self.data.position = self.data.position + 1
        log.debug("Digging above")
        while turtle.detectUp() do
            turtle.digUp()
        end
        if self:needs_a_torch() then
            log.debug("Placing a torch")
            turtle.turnLeft()
            turtle_utilities.select_item_index(ITEM_DETAIL_TORCH)
            turtle.placeUp()
            turtle.turnRight()
        end
        if self:is_at_the_end() then
            log.debug("Turning around")
            turtle.turnRight()
            turtle.turnRight()
            self.data.direction = DIRECTION_BACKWARD
        end
    else
        log.debug("Moving back")
        while not turtle.forward() do
            turtle.dig()
        end
        self.data.position = self.data.position - 1
    end
end

function Digger:needs_a_torch()
    return ((self.data.position % 4) == 0) and (not (self.data.position == 0))
end

function Digger:is_at_the_end()
    if self.gps then
        local location = gps.locate()

    else
        return self.data.position == FULL_TUNNEL_TORCH_SPAN
    end
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

    while not digger:is_done() do
        digger:move()
        digger:save_data()
    end

    digger:reset_turtle()
end

main()