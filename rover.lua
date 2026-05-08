local Rover = {}

Rover.metatable = {
    __index = Rover
}

function Rover.register(player, entity)
    if not player or not player.valid then return false, "Invalid player" end
    if not entity or not entity.valid then return false, "Invalid entity" end

    storage.csp_rovers = storage.csp_rovers or {}

    storage.csp_rovers[player.index] = {
        entity = entity,
        unit_number = entity.unit_number,
        state = "mobile",
        power_interface = nil,
        deployed_position = nil,
    }

    setmetatable(storage.csp_rovers[player.index], Rover.metatable)

    player.print({"csp-message.rover-registered"})

    return true, "Rover registered"
end

function Rover.unregister(player_index)
    storage.csp_rovers = storage.csp_rovers or {}
    storage.csp_rovers[player_index] = nil
end

function Rover.spawn(player)
    if not player or not player.valid then return false, "Invalid player" end

    global = global or {}
    storage.csp_units = storage.csp_units or {}
    storage.csp_rovers = storage.csp_rovers or {}

    -- Find first registered CSP
    local csp_data = nil
    for unit_number, csp in pairs(storage.csp_units) do
        if csp and csp.entity and csp.entity.valid then
            csp_data = csp
            break
        end
    end

    if not csp_data then
        return false, "No CSP registered"
    end

    -- Get spawn position (4 tiles south of CSP)
    local csp_pos = csp_data.entity.position
    local spawn_pos = {x = csp_pos.x, y = csp_pos.y + 4}
    local surface = csp_data.entity.surface

    -- Create rover entity
    local entity = surface.create_entity({
        name = "crash-support-rover",
        position = spawn_pos,
        force = player.force
    })

    if not entity then
        return false, "Failed to create rover"
    end

    -- If player already has rover registered, destroy old one
    local existing = storage.csp_rovers[player.index]
    if existing then
        if existing.entity and existing.entity.valid then
            existing.entity.destroy()
        end
        if existing.power_interface and existing.power_interface.valid then
            existing.power_interface.destroy()
        end
    end

    -- Register the rover
    storage.csp_rovers[player.index] = {
        entity = entity,
        unit_number = entity.unit_number,
        state = "mobile",
        power_interface = nil,
        deployed_position = nil,
    }

    setmetatable(storage.csp_rovers[player.index], Rover.metatable)

    player.print({"csp-message.rover-registered"})

    return true, "Rover spawned"
end

function Rover.rebuild(data)
    if not data then return end

    setmetatable(data, Rover.metatable)

    if data.entity and data.entity.valid then
        data.unit_number = data.entity.unit_number

        if data.power_interface_name and data.power_interface_position then
            local surface = data.entity.surface
            local power_ent = surface.find_entity(data.power_interface_name, data.power_interface_position)
            if power_ent then
                data.power_interface = power_ent
            end
        end
    end
end

function Rover.deploy(rover_data)
    if not rover_data or not rover_data.entity or not rover_data.entity.valid then
        return false, "Invalid rover entity"
    end

    if rover_data.state == "deployed" then
        return false, "Already deployed"
    end

    local entity = rover_data.entity
    local pos = entity.position
    local surface = entity.surface

    local power_interface = surface.create_entity({
        name = "hidden-electric-energy-interface",
        position = {x = pos.x, y = pos.y + 2},
        raise_built = false
    })

    if power_interface then
        power_interface.destructible = false
        power_interface.minable = false
        power_interface.operable = false
        power_interface.power_production = 6000000  -- 6MW in watts
        power_interface.power_usage = 0
        power_interface.electric_buffer_size = 5000000  -- 5MJ in joules

        rover_data.power_interface = power_interface
        rover_data.power_interface_name = "hidden-electric-energy-interface"
        rover_data.power_interface_position = {x = pos.x, y = pos.y + 2}
    end

    rover_data.state = "deployed"
    rover_data.deployed_position = {x = pos.x, y = pos.y}
    rover_data.entity.active = false
    rover_data.entity.operable = false

    return true, "deployed"
end

function Rover.undeploy(rover_data)
    if not rover_data or not rover_data.entity or not rover_data.entity.valid then
        return false, "Invalid rover entity"
    end

    if rover_data.state ~= "deployed" then
        return false, "Not deployed"
    end

    if rover_data.power_interface and rover_data.power_interface.valid then
        rover_data.power_interface.destroy()
    end

    rover_data.power_interface = nil
    rover_data.power_interface_name = nil
    rover_data.power_interface_position = nil
    rover_data.state = "mobile"
    rover_data.deployed_position = nil
    rover_data.entity.active = true
    rover_data.entity.operable = true

    return true, "mobile"
end

function Rover.on_destroyed(unit_number)
    storage.csp_rovers = storage.csp_rovers or {}

    for player_index, rover_data in pairs(storage.csp_rovers) do
        if rover_data.unit_number == unit_number then
            if rover_data.power_interface and rover_data.power_interface.valid then
                rover_data.power_interface.destroy()
            end
            storage.csp_rovers[player_index] = nil
            return true
        end
    end

    return false
end

function Rover.find_nearby_rover(player)
    if not player or not player.valid then return nil end

    global = global or {}
    storage.csp_rovers = storage.csp_rovers or {}

    local player_pos = player.position
    local player_index = player.index

    local rover_data = storage.csp_rovers[player_index]
    if rover_data and rover_data.entity and rover_data.entity.valid then
        local dist = math.sqrt(
            (player_pos.x - rover_data.entity.position.x)^2 +
            (player_pos.y - rover_data.entity.position.y)^2
        )
        if dist <= 10 then
            return rover_data
        end
    end

    return nil
end

function Rover.get_by_entity(entity)
    if not entity or not entity.valid then return nil end

    global = global or {}
    storage.csp_rovers = storage.csp_rovers or {}

    for player_index, rover_data in pairs(storage.csp_rovers) do
        if rover_data.unit_number == entity.unit_number then
            return rover_data
        end
    end

    return nil
end

function Rover.update(tick)
    global = global or {}
    storage.csp_rovers = storage.csp_rovers or {}

    for player_index, rover_data in pairs(storage.csp_rovers) do
        if rover_data and rover_data.entity and rover_data.entity.valid then
            if rover_data.state == "deployed" and rover_data.deployed_position then
                local pos = rover_data.entity.position
                local deployed_pos = rover_data.deployed_position
                if pos.x ~= deployed_pos.x or pos.y ~= deployed_pos.y then
                    rover_data.entity.teleport(deployed_pos)
                end
            end
        else
            if rover_data and rover_data.power_interface and rover_data.power_interface.valid then
                rover_data.power_interface.destroy()
            end
            storage.csp_rovers[player_index] = nil
        end
    end
end

function Rover.handle_placement(player_index, entity)
    local player = game.get_player(player_index)
    if not player or not player.valid then return end

    global = global or {}
    storage.csp_rovers = storage.csp_rovers or {}

    local existing = storage.csp_rovers[player_index]

    if existing and existing.entity and existing.entity.valid then
        local pos = existing.entity.position
        player.print({"csp-message.rover-already-registered", pos.x, pos.y})

        player.add_item({name = "crash-support-rover", count = 1})
        entity.destroy()

        player.marker_to_position(pos, true)

        return false, "Placement denied - rover already registered"
    end

    Rover.register(player, entity)

    return true, "Rover registered"
end

function Rover.handle_deploy(player)
    if not player or not player.valid then return end

    global = global or {}
    storage.csp_rovers = storage.csp_rovers or {}

    -- Check if rover already exists
    local existing = storage.csp_rovers[player.index]
    if existing and existing.entity and existing.entity.valid then
        -- Rover exists, activate power if not already
        if existing.state == "mobile" then
            local success, err = Rover.deploy(existing)
            if success then
                player.print({"csp-message.rover-deployed"})
            end
        end
        return
    end

    -- No rover exists, spawn new one
    local success, err = Rover.spawn(player)
    if not success then
        player.print(err)
    end
end

function Rover.handle_undeploy(player)
    if not player or not player.valid then return end

    local rover_data = Rover.find_nearby_rover(player)
    if not rover_data then
        return
    end

    if rover_data.state ~= "deployed" then
        return
    end

    local success, err = Rover.undeploy(rover_data)
    if success then
        player.print({"csp-message.rover-undeployed"})
    end
end

function Rover.handle_remote_destroy(player)
    if not player or not player.valid then return end

    global = global or {}
    storage.csp_rovers = storage.csp_rovers or {}

    local rover_data = storage.csp_rovers[player.index]
    if not rover_data then
        return
    end

    if rover_data.power_interface and rover_data.power_interface.valid then
        rover_data.power_interface.destroy()
    end

    if rover_data.entity and rover_data.entity.valid then
        local entity = rover_data.entity
        local surface = player.surface
        local pos = player.position

        -- Use pcall with anonymous function wrapper for safety
        local function safe_get_inv(entity, inv_def)
            if not inv_def then return nil end
            return pcall(function() return entity.get_inventory(inv_def) end)
        end

        local ok_fuel, result_fuel = safe_get_inv(entity, defines.inventory.fuel)
        local fuel_inv = (ok_fuel and result_fuel) or nil

        local ok_trunk, result_trunk = safe_get_inv(entity, defines.inventory.car_trunk)
        local trunk_inv = (ok_trunk and result_trunk) or nil

        local ok_ammo, result_ammo = safe_get_inv(entity, defines.inventory.car_ammo)
        local ammo_inv = (ok_ammo and result_ammo) or nil

        local player_inv = player.get_main_inventory()

        if fuel_inv and player_inv then
            for i = 1, #fuel_inv do
                local stack = fuel_inv[i]
                if stack.valid_for_read then
                    local to_insert = {name = stack.name, count = stack.count}
                    local inserted = player_inv.insert(to_insert)
                    local remaining = to_insert.count - inserted

                    if remaining > 0 then
                        surface.spill_item_stack(pos, {name = stack.name, count = remaining}, true)
                    end

                    stack.clear()
                end
            end
        end

        if trunk_inv and player_inv then
            for i = 1, #trunk_inv do
                local stack = trunk_inv[i]
                if stack.valid_for_read then
                    local to_insert = {name = stack.name, count = stack.count}
                    local inserted = player_inv.insert(to_insert)
                    local remaining = to_insert.count - inserted

                    if remaining > 0 then
                        surface.spill_item_stack(pos, {name = stack.name, count = remaining}, true)
                    end

                    stack.clear()
                end
            end
        end

        if ammo_inv and player_inv then
            for i = 1, #ammo_inv do
                local stack = ammo_inv[i]
                if stack.valid_for_read then
                    local to_insert = {name = stack.name, count = stack.count}
                    local inserted = player_inv.insert(to_insert)
                    local remaining = to_insert.count - inserted

                    if remaining > 0 then
                        surface.spill_item_stack(pos, {name = stack.name, count = remaining}, true)
                    end

                    stack.clear()
                end
            end
        end

        entity.destroy()
    end

    storage.csp_rovers[player.index] = nil
    player.print({"csp-message.rover-destroyed"})
end

return Rover