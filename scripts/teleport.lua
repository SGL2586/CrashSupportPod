local Teleport = {}
local CSP = require("scripts.csp")
local Deploy = require("scripts.deploy")

function Teleport.enter_interior(player)
    if not player or not player.valid then return false, "Invalid player" end
    if not player.character then return false, "No character" end

    local csp = nil
    local unit_number = nil
    local vehicle = player.vehicle

    if vehicle and vehicle.name == "crash-support-pod" then
        unit_number = vehicle.unit_number
        csp = storage.csp_units[unit_number]
    else
        local closest_dist = math.huge
        for un, csp_data in pairs(storage.csp_units or {}) do
            if csp_data and csp_data.entity and csp_data.entity.valid then
                local dist = math.sqrt(
                    (player.position.x - csp_data.entity.position.x)^2 +
                    (player.position.y - csp_data.entity.position.y)^2
                )
                if dist < closest_dist and dist <= 10 then
                    closest_dist = dist
                    csp = csp_data
                    unit_number = un
                end
            end
        end
        if not csp then return false, "No CSP found nearby" end
    end

    local surface_name = "csp-interior-" .. unit_number
    local interior_surface = game.surfaces[surface_name]
    local expansion_level = storage.csp_expansion_level or 1

    if storage.csp_surfaces[unit_number] and storage.csp_surfaces[unit_number].expansion_level then
        expansion_level = storage.csp_surfaces[unit_number].expansion_level
    end

    if interior_surface then
        Teleport.setup_interior_surface(interior_surface, expansion_level)
    else
        interior_surface = game.create_surface(surface_name, {})
        if interior_surface then
            Teleport.setup_interior_surface(interior_surface, expansion_level)
        end
    end

    if not interior_surface then
        return false, "Failed to create interior surface"
    end

    if not csp then
        csp = CSP.create(vehicle or csp.entity, player.index)
        if csp then
            csp.interior_surface = interior_surface
            csp.interior_surface_name = surface_name
            storage.csp_units[unit_number] = csp
            storage.csp_surfaces[unit_number] = {
                surface_name = surface_name,
                belt_input_pos = {x = 0, y = -10},
                belt_output_pos = {x = 0, y = 10},
                expansion_level = expansion_level
            }
        end
    else
        if vehicle then csp.entity = vehicle end
        csp.interior_surface = interior_surface
    end

    local safe_pos = interior_surface.find_non_colliding_position("character", {x = 0, y = 0}, 0, 0.5, false)
    if not safe_pos then
        safe_pos = {x = 0, y = 0}
    end

    if not csp.power_interface or not csp.power_interface.valid then
        local existing_solar = interior_surface.find_entity("csp-solar-interface", {0, 0})
        if existing_solar and existing_solar.valid then
            csp.power_interface = existing_solar
        end
    end

    player.teleport(safe_pos, interior_surface)

    Deploy.create_io_pad(csp)

    -- Place pending coal generator if tech was researched before interior existed
    if csp.pending_generator and csp.interior_surface and csp.interior_surface.valid then
        -- Skip if generator already exists (placed by tech handler)
        if not (csp.coal_generator_entity and csp.coal_generator_entity.valid) then
            local surface = csp.interior_surface
            local pos = {-1, 1.5} -- Center of 2x3 hazard concrete

            local generator = surface.create_entity({
                name = "csp-coal-generator",
                position = pos,
                force = "player",
                raise_built = false
            })

                 if generator then
                     generator.destructible = false
                     generator.minable = false
                     generator.active = (csp.state == "deployed")
                     csp.coal_generator_entity = generator

                     local power_interface = surface.create_entity({
                         name = "csp-generator-interface",
                         position = pos,
                         force = "player",
                         raise_built = false
                     })

                     if power_interface then
                         power_interface.electric_buffer_size = 10000000
                         power_interface.power_production = 0
                         power_interface.active = (csp.state == "deployed")
                         csp.generator_power = power_interface
                     end

                     csp.pending_generator = false
                end
        else
            -- Generator already exists, just clear the pending flag
            csp.pending_generator = false
        end
    end

    -- Place pending reactor if tech was researched
    if csp.pending_reactor and csp.interior_surface and csp.interior_surface.valid then
        -- Destroy coal generator if it exists
        if csp.coal_generator_entity and csp.coal_generator_entity.valid then
            csp.coal_generator_entity.destroy()
            csp.coal_generator_entity = nil
        end
        -- Place reactor at center {-1, 3}
        local reactor = csp.interior_surface.create_entity({
            name = "csp-reactor",
            position = {-1, 3},
            force = "player",
            raise_built = false
        })
        if reactor then
            reactor.destructible = false
            reactor.minable = false
            reactor.active = (csp.state == "deployed")
            csp.reactor_entity = reactor
            csp.pending_reactor = false
        end
    end

    return true, surface_name
end

function Teleport.setup_interior_surface(surface, expansion_level)
    expansion_level = expansion_level or 1

    -- Set map gen settings to prevent terrain generation (Warptorio-style)
    local settings = surface.map_gen_settings
    settings.default_enable_all_autoplace_controls = false
    settings.autoplace_settings = {
        tile = {settings = {["out-of-map"] = {frequency="none", size="none", richness="none"}}}
    }
    -- Set surface bounds based on expansion level (with padding)
    -- Level 1: 32, Level 2: 64, Level 3: 96, etc.
    local surface_size = 32 + ((expansion_level - 1) * 32)
    settings.width = surface_size
    settings.height = surface_size
    surface.map_gen_settings = settings

    -- Calculate platform size based on expansion level
    -- Level 1: 30x30 (half_size=15, range -15 to 14), Level 2: 62x62, etc.
    local half_size = 15 + ((expansion_level - 1) * 16)

    -- For new surfaces, generate starting chunk first to ensure tiles render
    if not surface.is_chunk_generated({0, 0}) then
        surface.request_to_generate_chunks({0, 0}, 1)
        surface.force_generate_chunk_requests()
    end

    -- Only set tiles where they don't exist (idempotent - preserves existing buildings)
    local tiles_to_set = {}
    -- 30x30 = 900 tiles for level 1: x from -15 to 14, y from -15 to 14
    local tile_start = -15 - ((expansion_level - 1) * 16)
    local tile_end = 14 + ((expansion_level - 1) * 16)
    for x = tile_start, tile_end do
        for y = tile_start, tile_end do
            local existing_tile = surface.get_tile(x, y)
            if not existing_tile or not existing_tile.valid then
                table.insert(tiles_to_set, {name = "concrete", position = {x, y}})
            elseif existing_tile.name ~= "concrete" then
                table.insert(tiles_to_set, {name = "concrete", position = {x, y}})
            end
        end
    end

    if #tiles_to_set > 0 then
        surface.set_tiles(tiles_to_set)
    end

    -- Place 2x3 hazard concrete marker for future csp-coal-generator
    local reactor_top_left = Deploy.REACTOR_MARKER_POS
    local reactor_tiles = {}
    for x = reactor_top_left.x, reactor_top_left.x + 2 do  -- 3 tiles wide (x=-2,-1,0)
        for y = reactor_top_left.y, reactor_top_left.y + 1 do  -- 2 tiles tall (y=1,2)
            table.insert(reactor_tiles, {name = "hazard-concrete-left", position = {x, y}})
        end
    end
    if #reactor_tiles > 0 then
        surface.set_tiles(reactor_tiles)
    end

    -- Place 5x5 hazard concrete marker for future csp-reactor
    local reactor_tl = Deploy.REACTOR_FOOTPRINT_POS
    local reactor_tiles2 = {}
    for x = reactor_tl.x, reactor_tl.x + 4 do  -- 5 tiles wide
        for y = reactor_tl.y, reactor_tl.y + 4 do  -- 5 tiles tall
            table.insert(reactor_tiles2, {name = "hazard-concrete-left", position = {x, y}})
        end
    end
    if #reactor_tiles2 > 0 then
        surface.set_tiles(reactor_tiles2)
    end

    -- Clear decoratives in platform area
    surface.destroy_decoratives({area = {{-half_size - 1, -half_size - 1}, {half_size + 1, half_size + 1}}})

    -- Only create power interface if one doesn't exist
    local existing_power = surface.find_entity("csp-solar-interface", {0, 0})
    if not existing_power then
        local power_interface = surface.create_entity({
            name = "csp-solar-interface",
            position = {0, 0},
            raise_built = false
        })
        if power_interface then
            power_interface.destructible = false
            power_interface.minable = false
            power_interface.operable = false
        end
    end
end

function Teleport.exit_interior(player)
    if not player or not player.valid then return false, "Invalid player" end

    local current_surface = player.surface
    if not current_surface then return false, "No surface" end

    local surface_name = current_surface.name or ""

    if not string.find(surface_name, "csp%-interior%-%d+") then
        return false, "Not in CSP interior: " .. surface_name
    end

    local csp = nil
    for unit_num, csp_data in pairs(storage.csp_units or {}) do
        if csp_data.interior_surface_name == surface_name then
            csp = csp_data
            break
        end
    end

    if csp and csp.entity and csp.entity.valid then
        local csp_position = csp.entity.position
        local csp_surface = csp.entity.surface

        local safe_pos = csp_surface.find_non_colliding_position("character", csp_position, 0, 1, false)
        if not safe_pos then
            safe_pos = csp_position
        end

        player.teleport(safe_pos, csp_surface)
        return true
    else
        player.print("CSP entity not found, returning to nauvis")
        local nauvis = game.surfaces["nauvis"]
        if nauvis then
            local safe_pos = nauvis.find_non_colliding_position("character", {x = 0, y = 0}, 0, 0.5, false) or {x = 0, y = 0}
            player.teleport(safe_pos, nauvis)
        end
        return false, "CSP entity invalid"
    end
end

function Teleport.is_player_in_csp_interior(player)
    if not player or not player.valid then return false, nil end

    local surface = player.surface
    if not surface then return false, nil end

    if string.find(surface.name, "csp%-interior%-%d+") then
        for unit_number, csp_data in pairs(storage.csp_units or {}) do
            if csp_data.interior_surface_name == surface.name then
                return true, unit_number
            end
        end
    end

    return false, nil
end

function Teleport.get_csp_for_surface(surface_name)
    for unit_number, csp_data in pairs(storage.csp_units or {}) do
        if csp_data.interior_surface_name == surface_name then
            return csp_data
        end
    end
    return nil
end

return Teleport
