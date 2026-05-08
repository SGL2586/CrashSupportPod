local Deploy = {}
local Power = require("scripts.power")

function Deploy.deploy(csp_data)
    if not csp_data or not csp_data.entity or not csp_data.entity.valid then
        return false, "Invalid CSP entity"
    end

    if csp_data.state == "deployed" then
        return false, "Already deployed"
    end

    local entity = csp_data.entity
    local surface = entity.surface
    local pos = entity.position

    local pad_tiles = Deploy.create_concrete_pad(surface, pos)
    if not pad_tiles then
        return false, "Failed to create concrete pad"
    end

    csp_data.deployed_pad_tiles = pad_tiles
    csp_data.state = "deployed"
    csp_data.reactor_enabled = true
    csp_data.deployed_position = {x = pos.x, y = pos.y}

    entity.active = false

    -- Ensure CSP is registered in global before power sync runs
    storage.csp_units = storage.csp_units or {}
    storage.csp_units[csp_data.unit_number or entity.unit_number] = csp_data

    -- Activate generator/reactor entities when deploying
    if csp_data.coal_generator_entity and csp_data.coal_generator_entity.valid then
        csp_data.coal_generator_entity.active = true
    end
    if csp_data.generator_power and csp_data.generator_power.valid then
        csp_data.generator_power.active = true
    end
    if csp_data.reactor_entity and csp_data.reactor_entity.valid then
        csp_data.reactor_entity.active = true
    end

    -- Create Nauvis solar interface for power generation (position offset x=4, y=4)
    local existing_nauvis_power = surface.find_entity("csp-solar-interface", {x = pos.x + 3, y = pos.y + 3})
    if not existing_nauvis_power then
        local nauvis_power = surface.create_entity({
            name = "csp-solar-interface",
            position = {x = pos.x + 3, y = pos.y + 3},
            force = "player",
            raise_built = false
        })
        if nauvis_power then
            nauvis_power.destructible = false
            nauvis_power.minable = false
            nauvis_power.operable = false
            nauvis_power.power_usage = 0
            nauvis_power.electric_buffer_size = 5000000
            nauvis_power.power_production = Power.BASE_SOLAR_OUTPUT * 1000000 / 60
            csp_data.nauvis_power_interface = nauvis_power
        end
    else
        csp_data.nauvis_power_interface = existing_nauvis_power
    end

    -- Sync power production on both interior and Nauvis interfaces
    Power.update_passive_generation()

    -- Create all IO entities (interior + nauvis) via create_io_pad()
    Deploy.create_io_pad(csp_data)

    return true, "deployed"
end

function Deploy.undeploy(csp_data)
    if not csp_data or not csp_data.entity or not csp_data.entity.valid then
        return false, "Invalid CSP entity"
    end

    if csp_data.state == "mobile" then
        return false, "Already mobile"
    end

    local entity = csp_data.entity
    if not entity or not entity.valid then
        return false, "CSP entity is invalid"
    end

    Deploy.destroy_concrete_pad(csp_data)

    csp_data.deployed_pad_tiles = nil
    csp_data.state = "mobile"
    csp_data.reactor_enabled = false
    csp_data.deployed_position = nil

    -- Deactivate generator/reactor entities when undeploying
    if csp_data.coal_generator_entity and csp_data.coal_generator_entity.valid then
        csp_data.coal_generator_entity.active = false
    end
    if csp_data.generator_power and csp_data.generator_power.valid then
        csp_data.generator_power.active = false
    end
    if csp_data.reactor_entity and csp_data.reactor_entity.valid then
        csp_data.reactor_entity.active = false
    end

    entity.active = true

    local surface = entity.surface
    local pos = entity.position

    local belt_types = {"csp-linked-belt-basic", "csp-linked-belt-fast", "csp-linked-belt-express"}
    local existing_belts = surface.find_entities_filtered({
        name = belt_types,
        position = pos,
        radius = 15
    })
    for _, belt in ipairs(existing_belts) do
        if belt.valid then belt.destroy() end
    end

    local pipe_types = {"csp-pipe-1", "csp-pipe-2"}
    local existing_pipes = surface.find_entities_filtered({
        name = pipe_types,
        position = pos,
        radius = 15
    })
    for _, pipe in ipairs(existing_pipes) do
        if pipe.valid then pipe.destroy() end
    end

    -- Destroy Nauvis belt/pipe entities on undeploy
    Deploy.destroy_io_pad(csp_data)

    -- Destroy Nauvis power interface on undeploy
    if csp_data.nauvis_power_interface and csp_data.nauvis_power_interface.valid then
        csp_data.nauvis_power_interface.destroy()
        csp_data.nauvis_power_interface = nil
    end

    -- Destroy biter lure
    if csp_data.lure_entity and csp_data.lure_entity.valid then
        csp_data.lure_entity.destroy()
        csp_data.lure_entity = nil
    end

    -- Register in storage.csp_units if not already
    storage.csp_units = storage.csp_units or {}
    storage.csp_units[csp_data.unit_number] = csp_data

    return true, "mobile"
end

function Deploy.create_io_pad(csp_data)
    if not csp_data or not csp_data.entity or not csp_data.entity.valid then
        return false, "Invalid CSP entity"
    end

    -- Debug logging
    local debug_mode = storage.csp_pipe_debug
    if debug_mode then
        local player = game.get_player(csp_data.player_index)
        if player and player.valid then
            player.print("[DEBUG] create_io_pad called, state=" .. (csp_data.state or "nil") .. ", level=" .. (csp_data.input_level or 0))
        end
    end

    -- Scan for existing entities that might not be tracked
    Deploy.scan_existing_entities(csp_data)

    -- Clean up existing entities
    Deploy.destroy_io_pad(csp_data)

    local level = csp_data.input_level or 0
    local pipe_level = csp_data.input_level or 0
    local belt_name = Deploy.BELT_VARIANTS[level] or "csp-linked-belt-basic"
    local belt_count = Deploy.BELT_COUNT[level] or 1
    local pipe_count = Deploy.PIPE_COUNT[pipe_level] or 1

    if debug_mode then
        local player = game.get_player(csp_data.player_index)
        if player and player.valid then
            player.print("[DEBUG] belt_name=" .. belt_name .. ", belt_count=" .. belt_count .. ", pipe_count=" .. pipe_count)
        end
    end

    csp_data.belt_entities = {}
    csp_data.pipe_entities = {}

    local is_deployed = csp_data.state == "deployed"
    if is_deployed then
        csp_data.nauvis_belt_entities = {}
        csp_data.nauvis_pipe_entities = {}
    end

    local interior_surface = csp_data.interior_surface
    local csp_entity = csp_data.entity
    local nauvis_surface = csp_entity.surface

    -- Interior entities - always create
    if interior_surface then
        -- Search for any linked belt at the position (any variant)
        local belt_types = {"csp-linked-belt-basic", "csp-linked-belt-fast", "csp-linked-belt-express"}
        for i = 1, belt_count do
            local pos = Deploy.INTERIOR_BELT_POSITIONS[i]
            if pos then
                -- Check for existing entity at position before creating (search all belt types)
                local existing = nil
                for _, bt in ipairs(belt_types) do
                    existing = interior_surface.find_entity(bt, {pos.x, pos.y})
                    if existing and existing.valid then break end
                end
                if existing and existing.valid then
                    existing.destroy()
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Destroyed existing interior belt at " .. pos.x .. "," .. pos.y)
                        end
                    end
                end

                local belt = interior_surface.create_entity({
                    name = belt_name,
                    position = {x = pos.x, y = pos.y},
                    direction = pos.dir,
                    force = "player",
                    raise_built = false
                })
                if belt then
                    belt.minable = false
                    belt.destructible = false
                    belt.operable = true
                    belt.linked_belt_type = "output"
                    table.insert(csp_data.belt_entities, {entity = belt, name = belt_name, index = i})
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Created interior belt " .. i .. " at " .. pos.x .. "," .. pos.y .. " type=" .. belt_name)
                        end
                    end
                end
            end
        end

        for i = 1, pipe_count do
            local pos = Deploy.INTERIOR_PIPE_POSITIONS[i]
            local pipe_name = "csp-pipe-" .. i
            if pos then
                -- Check for existing entity at position before creating
                local existing = interior_surface.find_entity(pipe_name, {pos.x, pos.y})
                if existing and existing.valid then
                    existing.destroy()
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Destroyed existing interior pipe at " .. pos.x .. "," .. pos.y)
                        end
                    end
                end

                local pipe = interior_surface.create_entity({
                    name = pipe_name,
                    position = {x = pos.x, y = pos.y},
                    direction = pos.dir,
                    raise_built = false
                })
                if pipe then
                    pipe.minable = false
                    pipe.destructible = false
                    pipe.operable = false
                    table.insert(csp_data.pipe_entities, {entity = pipe, name = pipe_name})
                end
            end
        end
    end

    -- Only create Nauvis entities when deployed
    if is_deployed then
        local nauvis_pos = csp_entity.position

        -- Search for any linked belt at the position (any variant)
        local belt_types = {"csp-linked-belt-basic", "csp-linked-belt-fast", "csp-linked-belt-express"}
        for i = 1, belt_count do
            local pos = Deploy.NAUVIS_BELT_POSITIONS[i]
            if pos then
                local abs_pos = {x = nauvis_pos.x + pos.x, y = nauvis_pos.y + pos.y}
                -- Check for existing entity at position before creating (search all belt types)
                local existing = nil
                for _, bt in ipairs(belt_types) do
                    existing = nauvis_surface.find_entity(bt, abs_pos)
                    if existing and existing.valid then break end
                end
                if existing and existing.valid then
                    existing.destroy()
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Destroyed existing nauvis belt at " .. abs_pos.x .. "," .. abs_pos.y)
                        end
                    end
                end

                local belt = nauvis_surface.create_entity({
                    name = belt_name,
                    position = abs_pos,
                    direction = pos.dir,
                    raise_built = false
                })
                if belt then
                    belt.minable = false
                    belt.destructible = false
                    belt.operable = false
                    table.insert(csp_data.nauvis_belt_entities, {entity = belt, name = belt_name})
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Created nauvis belt " .. i .. " at " .. abs_pos.x .. "," .. abs_pos.y)
                        end
                    end
                end
            end
        end

        -- Link belt pairs (interior[i] to nauvis[i])
        for i = 1, belt_count do
            local interior_data = csp_data.belt_entities[i]
            local nauvis_data = csp_data.nauvis_belt_entities[i]
            if interior_data and interior_data.entity and interior_data.entity.valid and
               nauvis_data and nauvis_data.entity and nauvis_data.entity.valid then
                local success, err = pcall(function()
                    interior_data.entity.linked_belt_type = "output"
                    nauvis_data.entity.linked_belt_type = "input"
                    interior_data.entity.connect_linked_belts(nauvis_data.entity)
                end)
                if not success then
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Belt link failed: " .. (err or "unknown error"))
                        end
                    end
                else
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Linked belt " .. i .. " (interior->nauvis)")
                        end
                    end
                end
            end
        end

        for i = 1, pipe_count do
            local pos = Deploy.NAUVIS_PIPE_POSITIONS[i]
            local pipe_name = "csp-pipe-" .. i
            if pos then
                local abs_pos = {x = nauvis_pos.x + pos.x, y = nauvis_pos.y + pos.y}
                -- Check for existing entity at position before creating (scan both pipe types)
                local existing = nil
                for p = 1, 2 do
                    existing = nauvis_surface.find_entity("csp-pipe-" .. p, abs_pos)
                    if existing and existing.valid then break end
                end
                if existing and existing.valid then
                    existing.destroy()
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Destroyed existing nauvis pipe at " .. abs_pos.x .. "," .. abs_pos.y)
                        end
                    end
                end

                local pipe = nauvis_surface.create_entity({
                    name = pipe_name,
                    position = abs_pos,
                    direction = pos.dir,
                    raise_built = false
                })
                if pipe then
                    pipe.minable = false
                    pipe.destructible = false
                    pipe.operable = false
                    table.insert(csp_data.nauvis_pipe_entities, {entity = pipe, name = pipe_name})
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Created nauvis pipe " .. i .. " at " .. abs_pos.x .. "," .. abs_pos.y)
                        end
                    end
                end
            end
        end
    end

    return true, "IO pad created"
end

function Deploy.destroy_io_pad(csp_data)
    if csp_data.belt_entities then
        for _, belt_data in ipairs(csp_data.belt_entities) do
            if belt_data.entity and belt_data.entity.valid then
                belt_data.entity.destroy()
            end
        end
        csp_data.belt_entities = {}
    end

    if csp_data.pipe_entities then
        for _, pipe_data in ipairs(csp_data.pipe_entities) do
            if pipe_data.entity and pipe_data.entity.valid then
                pipe_data.entity.destroy()
            end
        end
        csp_data.pipe_entities = {}
    end

    if csp_data.nauvis_belt_entities then
        for _, belt_data in ipairs(csp_data.nauvis_belt_entities) do
            if belt_data.entity and belt_data.entity.valid then
                belt_data.entity.destroy()
            end
        end
        csp_data.nauvis_belt_entities = {}
    end

    if csp_data.nauvis_pipe_entities then
        for _, pipe_data in ipairs(csp_data.nauvis_pipe_entities) do
            if pipe_data.entity and pipe_data.entity.valid then
                pipe_data.entity.destroy()
            end
        end
        csp_data.nauvis_pipe_entities = {}
    end
end

function Deploy.recalculate_io_pad(csp_data)
    if storage.csp_pipe_debug then
        local player = game.get_player(csp_data.player_index)
        if player and player.valid then
            player.print("[DEBUG] recalculate_io_pad: state=" .. (csp_data.state or "nil") .. ", level=" .. (csp_data.input_level or 0))
        end
    end
    Deploy.destroy_io_pad(csp_data)
    return Deploy.create_io_pad(csp_data)
end

function Deploy.scan_existing_entities(csp_data)
    -- Scan for entities that should exist but aren't tracked (e.g., after save/load or failed cleanup)
    local interior_surface = csp_data.interior_surface
    local nauvis_surface = csp_data.entity and csp_data.entity.valid and csp_data.entity.surface
    local debug_mode = storage.csp_pipe_debug

    if interior_surface then
        -- Scan for belts at expected positions
        for i = 1, 4 do
            local pos = Deploy.INTERIOR_BELT_POSITIONS[i]
            if pos then
                local existing = interior_surface.find_entity("csp-linked-belt-basic", pos)
                if not existing then existing = interior_surface.find_entity("csp-linked-belt-fast", pos) end
                if not existing then existing = interior_surface.find_entity("csp-linked-belt-express", pos) end
                if existing and existing.valid then
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Found untracked interior belt at " .. pos.x .. "," .. pos.y)
                        end
                    end
                end
            end
        end
    end

    if nauvis_surface and csp_data.state == "deployed" then
        local base_pos = csp_data.entity.position
        -- Scan for Nauvis belts
        for i = 1, 4 do
            local pos = Deploy.NAUVIS_BELT_POSITIONS[i]
            if pos then
                local abs_pos = {x = base_pos.x + pos.x, y = base_pos.y + pos.y}
                local existing = nauvis_surface.find_entity("csp-linked-belt-basic", abs_pos)
                if not existing then existing = nauvis_surface.find_entity("csp-linked-belt-fast", abs_pos) end
                if not existing then existing = nauvis_surface.find_entity("csp-linked-belt-express", abs_pos) end
                if existing and existing.valid then
                    if debug_mode then
                        local player = game.get_player(csp_data.player_index)
                        if player and player.valid then
                            player.print("[DEBUG] Found untracked nauvis belt at " .. abs_pos.x .. "," .. abs_pos.y)
                        end
                    end
                end
            end
        end
    end
end

function Deploy.create_concrete_pad(surface, center_pos)
    local tiles = {}
    local half_size = 4

    for x = -half_size, half_size do
        for y = -half_size, half_size do
            table.insert(tiles, {
                name = "concrete",
                position = {x = center_pos.x + x, y = center_pos.y + y}
            })
        end
    end

    if #tiles > 0 then
        surface.set_tiles(tiles)
    end

    return tiles
end

function Deploy.destroy_concrete_pad(csp_data)
    if not csp_data.deployed_pad_tiles then
        return
    end

    local entity = csp_data.entity
    if not entity or not entity.valid then
        csp_data.deployed_pad_tiles = nil
        return
    end

    local surface = entity.surface
    local tiles = {}

    for _, tile in ipairs(csp_data.deployed_pad_tiles) do
        table.insert(tiles, {
            name = "dirt-1",
            position = tile.position
        })
    end

    if #tiles > 0 then
        surface.set_tiles(tiles)
    end

    csp_data.deployed_pad_tiles = nil
end

function Deploy.get_by_entity(entity)
    if not entity or not entity.valid then return nil end
    return storage.csp_units[entity.unit_number]
end

function Deploy.find_nearby_csp(player)
    if not player or not player.valid then return nil end

    global = global or {}
    storage.csp_units = storage.csp_units or {}

    local player_pos = player.position

    -- First check registered CSPs
    for unit_number, csp_data in pairs(storage.csp_units) do
        if csp_data and csp_data.entity and csp_data.entity.valid then
            if csp_data.entity.surface.name == player.surface.name then
                local dist = math.sqrt((player_pos.x - csp_data.entity.position.x)^2 +
                                           (player_pos.y - csp_data.entity.position.y)^2)
                if dist <= 10 then
                    return csp_data
                end
            end
        end
    end

    -- If not found in storage.csp_units, search surface for unregistered CSPs
    if player.surface then
        local pods = player.surface.find_entities_filtered({name = "crash-support-pod"})
        for _, pod in ipairs(pods) do
            if pod and pod.valid then
                local dist = math.sqrt((player_pos.x - pod.position.x)^2 +
                                           (player_pos.y - pod.position.y)^2)
                if dist <= 10 then
                    local registered = storage.csp_units[pod.unit_number]
                    if registered then
                        return registered
                    end
                    return {
                        entity = pod,
                        unit_number = pod.unit_number,
                        state = "mobile",
                        reactor_enabled = false,
                        deployed_pad_tiles = nil,
                        expansion_level = storage.csp_expansion_level or 1
                    }
                end
            end
        end
    end

    return nil
end

function Deploy.handle_deploy(player)
    if not player or not player.valid then return end

    if player.vehicle and player.vehicle.name == "crash-support-pod" then
        player.print({"csp-message.cannot-deploy-in-vehicle"})
        return
    end

    local csp_data = Deploy.find_nearby_csp(player)
    if not csp_data then
        player.print({"csp-message.no-nearby-csp"})
        return
    end

    if csp_data.state ~= "mobile" then
        player.print({"csp-message.already-deployed"})
        return
    end

    local success, err = Deploy.deploy(csp_data)
    if success then
        player.print({"csp-message.deployed"})
    else
        player.print({"csp-message.deploy-failed", err})
    end
end

function Deploy.handle_undeploy(player)
    if not player or not player.valid then return end

    if player.vehicle and player.vehicle.name == "crash-support-pod" then
        player.print({"csp-message.cannot-undeploy-in-vehicle"})
        return
    end

    local csp_data = Deploy.find_nearby_csp(player)

    if not csp_data then
        player.print({"csp-message.no-nearby-csp"})
        return
    end

    if csp_data.state ~= "deployed" then
        player.print({"csp-message.already-mobile"})
        return
    end

    local success, err = Deploy.undeploy(csp_data)
    if success then
        player.print({"csp-message.undeployed"})
        -- Register in storage.csp_units if this was a fallback entry
        storage.csp_units = storage.csp_units or {}
        if not storage.csp_units[csp_data.unit_number] then
            storage.csp_units[csp_data.unit_number] = csp_data
        end
    else
        player.print({"csp-message.undeploy-failed", err})
    end
end

function Deploy.trigger_recheck()
    storage.csp_recheck = storage.csp_recheck or {tick = 0, remaining = 0}
    storage.csp_recheck.remaining = 3
    storage.csp_recheck.tick = 0
end

Deploy.BELT_COUNT = {
    [0] = 1,
    [1] = 2,
    [2] = 3,
    [3] = 3,
    [4] = 4,
    [5] = 4
}

Deploy.BELT_VARIANTS = {
    [0] = "csp-linked-belt-basic",
    [1] = "csp-linked-belt-basic",
    [2] = "csp-linked-belt-basic",
    [3] = "csp-linked-belt-fast",
    [4] = "csp-linked-belt-fast",
    [5] = "csp-linked-belt-express"
}

Deploy.PIPE_COUNT = {
    [0] = 1,
    [1] = 1,
    [2] = 1,
    [3] = 1,
    [4] = 2,
    [5] = 2
}

Deploy.INTERIOR_BELT_POSITIONS = {
    {x = -1, y = -2, dir = defines.direction.south},
    {x = 0, y = -2, dir = defines.direction.south},
    {x = 1, y = -1, dir = defines.direction.west},
    {x = 1, y = 0, dir = defines.direction.west}
}

Deploy.INTERIOR_PIPE_POSITIONS = {
    {x = -2, y = -1, dir = defines.direction.west},
    {x = -2, y = 0, dir = defines.direction.west}
}

Deploy.NAUVIS_BELT_POSITIONS = {
    {x = -4, y = -3, dir = defines.direction.east},
    {x = -4, y = -1, dir = defines.direction.east},
    {x = -4, y = 1, dir = defines.direction.east},
    {x = -4, y = 3, dir = defines.direction.east}
}

Deploy.NAUVIS_PIPE_POSITIONS = {
    {x = 4, y = -1, dir = defines.direction.east},
    {x = 4, y = 1, dir = defines.direction.east}
}

Deploy.REACTOR_MARKER_POS = {x = -2, y = 1}
Deploy.REACTOR_FOOTPRINT_POS = {x = -3, y = 1}  -- Top-left of 5×5 reactor area

return Deploy
