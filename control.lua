local CSP = require("scripts.csp")
local GUI = require("scripts.gui")
local Teleport = require("scripts.teleport")
local BeltTransfer = require("scripts.belt-transfer")
local Power = require("scripts.power")
local Deploy = require("scripts.deploy")
local PipeTransfer = require("scripts.pipe-transfer")
local Rover = require("scripts.rover")
local BuildingRestrictions = require("scripts.building-restrictions")
local TechHandlers = require("scripts.tech-handlers")
local Pollution = require("scripts.pollution")
local Aggro = require("scripts.aggro")

-- Register metatables for automatic relinking on load
script.register_metatable("csp", CSP.metatable)
script.register_metatable("rover", Rover.metatable)

-- Local flag for post-load restoration (cannot use storage in on_load due to CRC check)
local needs_post_load_restore = false

local function check_csp_preset()
    if storage.csp_preset_warned then return end
    local nauvis = game.surfaces["nauvis"]
    if not nauvis then return end
    local controls = nauvis.map_gen_settings.autoplace_controls
    if controls and controls["iron-ore"] and controls["iron-ore"].frequency then
        if controls["iron-ore"].frequency < 2.0 then
            for _, player in pairs(game.players) do
                if player.valid then
                    player.print({"csp-message.preset-warning"})
                end
            end
        end
    end
    storage.csp_preset_warned = true
end
local function on_init()
    storage.csp_units = storage.csp_units or {}
    storage.csp_surfaces = storage.csp_surfaces or {}
    storage.csp_solar_tech_level = storage.csp_solar_tech_level or 0
    storage.csp_expansion_level = storage.csp_expansion_level or 1
    storage.csp_intro_shown = false
    storage.csp_rovers = storage.csp_rovers or {}
    storage.rover_enabled = storage.rover_enabled or false
    storage.csp_generator_enabled = storage.csp_generator_enabled or false
    storage.csp_nest_cooldowns = {}
end

-- Use both events: on_player_created for normal spawn, on_cutscene_cancelled for after intro cutscene
-- This handles the Factorio 2.0 cutscene state where character may not be fully initialized yet
script.on_event({defines.events.on_player_created, defines.events.on_cutscene_cancelled}, function(event)
    local player = game.get_player(event.player_index)
    if player and player.valid then
        -- Use cutscene_character or character (handles cutscene state)
        local character = player.cutscene_character or player.character
        if character then
            local inventory = character.get_inventory(defines.inventory.character_main)
            if inventory then
                -- Only insert if player doesn't already have CSP
                if inventory.get_item_count("crash-support-pod") == 0 then
                    inventory.insert({name = "crash-support-pod", count = 1})
                end
            end
        end
        -- Only show intro message once (use storage flag to prevent duplicate from both events)
        if not storage.csp_intro_shown then
            player.print({"csp-intro-message.intro-message"})
            storage.csp_intro_shown = true
        end
    end
end)

local function on_load()
    -- Set local flag to do post-load restoration in on_tick when game is available
    needs_post_load_restore = true
end

local function on_configuration_changed(data)
    if data and data.mod_changes and data.mod_changes["CrashSupportPod"] then
        storage.csp_units = storage.csp_units or {}
        storage.csp_surfaces = storage.csp_surfaces or {}
        storage.csp_solar_tech_level = storage.csp_solar_tech_level or 0
        storage.csp_expansion_level = storage.csp_expansion_level or 1
        storage.csp_rovers = storage.csp_rovers or {}
        storage.rover_enabled = storage.rover_enabled or false
        storage.csp_generator_enabled = storage.csp_generator_enabled or false

        for unit_number, csp_data in pairs(storage.csp_units) do
            if not csp_data or not csp_data.entity or not csp_data.entity.valid then
                storage.csp_units[unit_number] = nil
            else
                CSP.rebuild(csp_data)
            end
        end

        for player_index, rover_data in pairs(storage.csp_rovers) do
            if not rover_data or not rover_data.entity or not rover_data.entity.valid then
                storage.csp_rovers[player_index] = nil
            else
                Rover.rebuild(rover_data)
            end
        end
    end
end

local function on_built_entity(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    local player = game.get_player(event.player_index)

    if entity.name == "crash-support-pod" then
        local player_index = event.player_index
        if not player_index then return end
        player = game.get_player(player_index)
        if not player or not player.valid then return end

        local csp = CSP.create(entity, player.index)
        if csp then
            storage.csp_units[entity.unit_number] = csp

            local surface_name = "csp-interior-" .. entity.unit_number
            storage.csp_surfaces[entity.unit_number] = {
                surface_name = surface_name,
                belt_input_pos = {x = 0, y = -10},
                belt_output_pos = {x = 0, y = 10},
                expansion_level = storage.csp_expansion_level or 1
            }
            csp.interior_surface_name = surface_name
        end
    elseif entity.name == "crash-support-rover" then
        local player_index = event.player_index
        if not player_index then return end
        Rover.handle_placement(player_index, entity)
    else
        if storage.csp_restriction_debug and player and player.valid then
            player.print("DEBUG: Entity placed: " .. entity.name .. " (type: " .. entity.type .. ")")
        end
        BuildingRestrictions.check_and_handle(event)
    end
end

local function on_gui_click(event)
    if not event.element then return end

    local element = event.element
    if not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    if element.name == "csp_enter_interior" then
        Teleport.enter_interior(player)
    elseif element.name == "csp_exit_interior" then
        Teleport.exit_interior(player)
    elseif element.name == "csp_deploy" then
        Deploy.handle_deploy(player)
    elseif element.name == "csp_undeploy" then
        Deploy.handle_undeploy(player)
    elseif element.name == "csp_deploy_rover" then
        Rover.handle_deploy(player)
    elseif element.name == "csp_undeploy_rover" then
        Rover.handle_undeploy(player)
    elseif element.name == "csp_destroy_rover" then
        Rover.handle_remote_destroy(player)
    end
end

local function recheck_belt_levels()
    local interval = settings.global["csp-belt-recheck-interval"] and settings.global["csp-belt-recheck-interval"].value or 60
    if interval < 1 then interval = 60 end

    storage.csp_recheck = storage.csp_recheck or {tick = 0, remaining = 0}

    storage.csp_recheck.tick = storage.csp_recheck.tick + 1
    if storage.csp_recheck.tick < interval * 60 then
        return
    end
    storage.csp_recheck.tick = 0

    if storage.csp_recheck.remaining > 0 then
        storage.csp_recheck.remaining = storage.csp_recheck.remaining - 1
        for unit_number, csp_data in pairs(storage.csp_units) do
            if csp_data and csp_data.state == "deployed" then
                Deploy.recalculate_io_pad(csp_data)
            end
        end
    end
end

function Deploy.trigger_recheck()
    storage.csp_recheck = storage.csp_recheck or {tick = 0, remaining = 0}
    storage.csp_recheck.remaining = 3
    storage.csp_recheck.tick = 0
end

local function on_tick(event)
    -- Post-load restoration (game is now available)
    if needs_post_load_restore then
        needs_post_load_restore = false
        for unit_number, csp_data in pairs(storage.csp_units or {}) do
            if not csp_data or not csp_data.entity or not csp_data.entity.valid then
                storage.csp_units[unit_number] = nil
            else
                CSP.rebuild(csp_data)
                Deploy.scan_existing_entities(csp_data)
            end
        end
        for player_index, rover_data in pairs(storage.csp_rovers or {}) do
            if not rover_data or not rover_data.entity or not rover_data.entity.valid then
                storage.csp_rovers[player_index] = nil
            else
                Rover.rebuild(rover_data)
            end
        end
    end

    -- Update CSP entities
    for unit_number, csp_data in pairs(storage.csp_units) do
        if csp_data and csp_data.entity and csp_data.entity.valid then
            -- Lock deployed CSP in position
            if csp_data.state == "deployed" and csp_data.deployed_position then
                local pos = csp_data.entity.position
                local deployed_pos = csp_data.deployed_position
                if pos.x ~= deployed_pos.x or pos.y ~= deployed_pos.y then
                    csp_data.entity.teleport(deployed_pos)
                end
            end
        else
            storage.csp_units[unit_number] = nil
        end
    end

    -- Periodic tasks
    if event.tick % 60 == 0 then
        Pollution.on_tick()
        BeltTransfer.process_inputs()
    end

    PipeTransfer.on_tick()
    recheck_belt_levels()

    if event.tick % 300 == 0 then
        Aggro.on_tick()
    end

    if event.tick % 30 == 0 then
        Power.update_passive_generation()
    end

    Rover.update(event.tick)

    -- Update CSP generators (every 10 ticks)
    if event.tick % 10 == 0 then
        for unit_number, csp_data in pairs(storage.csp_units) do
            if csp_data and csp_data.generator_power and csp_data.generator_power.valid then
                local power_interface = csp_data.generator_power

                -- Check if power interface is active before producing power
                if not power_interface.active then
                    power_interface.power_production = 0
                else
                    if csp_data.reactor_entity and csp_data.reactor_entity.valid then
                        -- Reactor: 480MW when >=500°C
                        local reactor = csp_data.reactor_entity
                        if reactor.valid and reactor.temperature >= 500 then
                            power_interface.power_production = 480000000 / 60  -- 480 MW
                            -- Check if just reached temp
                            if not csp_data.reactor_at_temp then
                                csp_data.reactor_at_temp = true
                                for _, player in pairs(game.players) do
                                    if player.valid then
                                        player.print({"csp-message.reactor-at-temp"})
                                    end
                                end
                            end
                        else
                            power_interface.power_production = 0
                            csp_data.reactor_at_temp = false
                        end
                    elseif csp_data.coal_generator_entity and csp_data.coal_generator_entity.valid then
                        -- Coal generator: 9MW when burning
                        local generator = csp_data.coal_generator_entity
                        if generator.burner and generator.burner.currently_burning then
                            -- Clear steam output so boiler doesn't stop
                            local fb = generator.fluidbox
                            if fb and fb[2] then  -- fb[2] = steam output for boilers
                                fb[2] = nil
                            end
                            power_interface.power_production = 9000000 / 60 -- 9MW
                        else
                            power_interface.power_production = 0
                        end
                    else
                        power_interface.power_production = 0
                    end
                end
            end
        end
    end

    if event.tick % 30 == 0 then
        for _, player in pairs(game.players) do
            if player and player.valid then
                GUI.update(player)
            end
        end
    end
end

local function on_entity_died(event)
    local entity = event.entity
    if not entity or not entity.valid then return end

    if entity.name == "crash-support-pod" then
        local unit_number = entity.unit_number
        local csp_data = storage.csp_units[unit_number]
        if csp_data then
            CSP.rebuild(csp_data)
            csp_data:on_destroyed()

            if csp_data.coal_generator_entity and csp_data.coal_generator_entity.valid then
                csp_data.coal_generator_entity.destroy()
            end
            if csp_data.reactor_entity and csp_data.reactor_entity.valid then
                csp_data.reactor_entity.destroy()
            end
            if csp_data.generator_power and csp_data.generator_power.valid then
                csp_data.generator_power.destroy()
            end

            for _, player in pairs(game.players) do
                if player.valid and player.character then
                    player.character.active = false
                    player.print({"csp-message.csp-destroyed"})
                end
            end
        end

        storage.csp_units[unit_number] = nil
        storage.csp_surfaces[unit_number] = nil
    elseif entity.name == "crash-support-rover" then
        Rover.on_destroyed(entity.unit_number)
    elseif entity.name == "csp-pollution-lure-coal" or entity.name == "csp-pollution-lure-reactor" then
        for _, csp_data in pairs(storage.csp_units) do
            if csp_data.lure_entity and csp_data.lure_entity == entity then
                csp_data.lure_entity = nil
                if csp_data.cleaning_up_lure then
                    csp_data.cleaning_up_lure = nil
                    break
                end
                if csp_data.entity and csp_data.entity.valid and csp_data.state == "deployed" then
                    Deploy.undeploy(csp_data)
                    local player = game.get_player(csp_data.player_index)
                    if player and player.valid then
                        player.print({"csp-message.evacuated-by-biters"})
                    end
                end
                break
            end
        end
    end
end

local function on_player_respawned(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    for _, csp_data in pairs(storage.csp_units) do
        if csp_data.player_index == player.index and csp_data.entity and csp_data.entity.valid then
            local surface = csp_data.entity.surface
            local pos = csp_data.entity.position
            local safe_pos = surface.find_non_colliding_position("character", pos, 10, 0.5)
            player.teleport(safe_pos or pos, surface)
            return
        end
    end
end

local function on_player_driving_changed_state(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    if entity.name ~= "crash-support-pod" then return end

    local unit_number = entity.unit_number
    if storage.csp_units[unit_number] then
        CSP.rebuild(storage.csp_units[unit_number])
        return
    end

    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    local csp = CSP.create(entity, player.index)
    if csp then
        storage.csp_units[unit_number] = csp
        local surface_name = "csp-interior-" .. unit_number
        storage.csp_surfaces[unit_number] = {
            surface_name = surface_name,
            belt_input_pos = {x = 0, y = -10},
            belt_output_pos = {x = 0, y = 10},
            expansion_level = storage.csp_expansion_level or 1
        }
        csp.interior_surface_name = surface_name
        CSP.rebuild(csp)
    end
end

-- Debug commands
commands.add_command("csp-debug", "Debug CSP state", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    player.print("=== CSP Debug ===")
    player.print("Player surface: " .. (player.surface and player.surface.name or "none"))
    player.print("Player vehicle: " .. (player.vehicle and player.vehicle.name or "none"))
    player.print("Storage csp_units: " .. tostring(storage.csp_units ~= nil))
    if storage.csp_units then
        local count = 0
        for _ in pairs(storage.csp_units) do count = count + 1 end
        player.print("CSP count: " .. count)
    end
    player.print("--- Rover Info ---")
    player.print("Storage csp_rovers: " .. tostring(storage.csp_rovers ~= nil))
    if storage.csp_rovers then
        local count = 0
        for _ in pairs(storage.csp_rovers) do count = count + 1 end
        player.print("Rover count: " .. count)
        local my_rover = storage.csp_rovers[player.index]
        if my_rover then
            player.print("Your rover registered: " .. tostring(my_rover.entity and my_rover.entity.valid))
            player.print("Your rover state: " .. (my_rover.state or "nil"))
        else
            player.print("No rover registered for you")
        end
    end
    player.print("================")
end)

commands.add_command("csp-power-debug", "Debug CSP power interfaces", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    player.print("=== CSP Power Debug ===")
    player.print("Solar tech level: " .. tostring(storage.csp_solar_tech_level or 0))

    if not player.surface or player.surface.name ~= "nauvis" then
        player.print("Must be on Nauvis surface")
        return
    end

    local solar_ents = player.surface.find_entities_filtered({name = "csp-solar-interface"})
    player.print("CSP Solar Interfaces on Nauvis: " .. #solar_ents)
    for i, ent in ipairs(solar_ents) do
        player.print("  [" .. i .. "] Position: " .. string.format("%.1f,%.1f", ent.position.x, ent.position.y))
        player.print("      power_production: " .. tostring(ent.power_production) .. " (" .. (ent.power_production * 60 / 1000000) .. " MW)")
        player.print("      energy: " .. tostring(ent.energy))
        player.print("      electric_buffer_size: " .. tostring(ent.electric_buffer_size))
    end

    local gen_ents = player.surface.find_entities_filtered({name = "csp-generator-interface"})
    player.print("CSP Generator Interfaces on Nauvis: " .. #gen_ents)
    for i, ent in ipairs(gen_ents) do
        player.print("  [" .. i .. "] Position: " .. string.format("%.1f,%.1f", ent.position.x, ent.position.y))
        player.print("      power_production: " .. tostring(ent.power_production) .. " (" .. (ent.power_production * 60 / 1000000) .. " MW)")
    end

    player.print("--- Interior surfaces ---")
    for unit_number, csp_data in pairs(storage.csp_units or {}) do
        if csp_data and csp_data.interior_surface and csp_data.interior_surface.valid then
            local surf = csp_data.interior_surface
            local int_solar = surf.find_entities_filtered({name = "csp-solar-interface"})
            for _, ent in ipairs(int_solar) do
                player.print("  Interior CSP " .. unit_number .. ": power_production=" .. tostring(ent.power_production) .. " (" .. (ent.power_production * 60 / 1000000) .. " MW)")
            end
        end
    end
    player.print("=======================")

end)

commands.add_command("csp-tp-in", "Teleport player into CSP interior", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local success, err = Teleport.enter_interior(player)
    player.print("Teleport in: " .. tostring(success) .. " - " .. (err or ""))
end)

commands.add_command("csp-tp-out", "Teleport player out of CSP interior", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local success, err = Teleport.exit_interior(player)
    player.print("Teleport out: " .. tostring(success) .. " - " .. (err or ""))
end)

commands.add_command("csp-surfaces", "List all CSP surfaces", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local surfaces = {}
    for name, _ in pairs(game.surfaces) do
        if string.find(name, "csp-interior-") then
            table.insert(surfaces, name)
        end
    end
    player.print("CSP Surfaces: " .. table.concat(surfaces, ", "))
end)

commands.add_command("csp-cleanup", "Clean up all CSP surfaces and data", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    storage.csp_units = {}
    storage.csp_surfaces = {}

    local count = 0
    for name, surface in pairs(game.surfaces) do
        if string.find(name, "csp-interior-") then
            for _, entity in pairs(surface.find_entities()) do
                if entity and entity.valid then
                    entity.destroy()
                end
            end
            game.delete_surface(name)
            count = count + 1
        end
    end
    player.print("Cleaned up " .. count .. " CSP surfaces")
end)

commands.add_command("csp-pipes", "Debug pipe entities", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    player.print("=== CSP Pipes ===")

    for unit_number, csp_data in pairs(storage.csp_units or {}) do
        player.print("CSP " .. unit_number .. ":")
        player.print("  state: " .. (csp_data.state or "nil"))
        player.print("  input_level: " .. (csp_data.input_level or 0))
        player.print("  belt_entities: " .. tostring(csp_data.belt_entities and #csp_data.belt_entities or 0))
        player.print("  pipe_entities: " .. tostring(csp_data.pipe_entities and #csp_data.pipe_entities or 0))
        player.print("  nauvis_belt_entities: " .. tostring(csp_data.nauvis_belt_entities and #csp_data.nauvis_belt_entities or 0))
        player.print("  nauvis_pipe_entities: " .. tostring(csp_data.nauvis_pipe_entities and #csp_data.nauvis_pipe_entities or 0))
        if csp_data.belt_entities then
            for i, p in ipairs(csp_data.belt_entities) do
                player.print("    interior_belt[" .. i .. "]: " .. tostring(p and p.entity and p.entity.valid) .. " name: " .. tostring(p and p.name))
            end
        end
        if csp_data.nauvis_belt_entities then
            for i, p in ipairs(csp_data.nauvis_belt_entities) do
                player.print("    nauvis_belt[" .. i .. "]: " .. tostring(p and p.entity and p.entity.valid) .. " name: " .. tostring(p and p.name))
            end
        end
        if csp_data.pipe_entities then
            for i, p in ipairs(csp_data.pipe_entities) do
                player.print("    interior[" .. i .. "]: " .. tostring(p and p.entity and p.entity.valid))
            end
        end
        if csp_data.nauvis_pipe_entities then
            for i, p in ipairs(csp_data.nauvis_pipe_entities) do
                player.print("    nauvis[" .. i .. "]: " .. tostring(p and p.entity and p.entity.valid))
            end
        end
    end
    player.print("===============")
end)

commands.add_command("csp-state", "Debug CSP state", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    player.print("=== CSP State ===")

    for unit_number, csp_data in pairs(storage.csp_units or {}) do
        player.print("CSP " .. unit_number .. ":")
        player.print("  state: " .. (csp_data.state or "nil"))
        player.print("  deployed_position: " .. tostring(csp_data.deployed_position ~= nil))
        player.print("  deployed_pad_tiles: " .. tostring(csp_data.deployed_pad_tiles ~= nil))
        player.print("  entity valid: " .. tostring(csp_data.entity and csp_data.entity.valid))
        if csp_data.entity and csp_data.entity.valid then
            player.print("  entity active: " .. tostring(csp_data.entity.active))
        end
    end
    player.print("===============")
end)

commands.add_command("csp-pipe-debug", "Toggle pipe debug mode", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    storage.csp_pipe_debug = not (storage.csp_pipe_debug or false)
    player.print("Pipe debug: " .. tostring(storage.csp_pipe_debug))
end)

commands.add_command("csp-relink", "Force re-link all belts and refresh IO", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    player.print("[DEBUG] Force re-linking all CSP belts...")
    for unit_number, csp_data in pairs(storage.csp_units or {}) do
        if csp_data and csp_data.entity and csp_data.entity.valid then
            player.print("[DEBUG] Re-linking CSP " .. unit_number)
            Deploy.recalculate_io_pad(csp_data)
        end
    end
    player.print("[DEBUG] Re-linking complete")
end)

commands.add_command("csp-restrictions", "Toggle building restrictions debug mode", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    storage.csp_restriction_debug = not (storage.csp_restriction_debug or false)
    player.print("Building restrictions debug: " .. tostring(storage.csp_restriction_debug))
end)

commands.add_command("rover-debug", "Debug rover state", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    player.print("=== Rover Debug ===")

    player.print("Total registered rovers: " .. table_count(storage.csp_rovers))

    player.print("--- All registered rovers ---")
    for pid, rover_data in pairs(storage.csp_rovers or {}) do
        player.print("Player " .. pid .. ":")
        player.print("  Registered: " .. tostring(rover_data.entity and rover_data.entity.valid))
        player.print("  State: " .. (rover_data.state or "nil"))
        player.print("  Unit number: " .. tostring(rover_data.unit_number))
        if rover_data.entity and rover_data.entity.valid then
            local pos = rover_data.entity.position
            player.print("  Position: " .. pos.x .. "," .. pos.y)
            local dist_from_player = math.sqrt(
                (player.position.x - pos.x)^2 + (player.position.y - pos.y)^2
            )
            player.print("  Distance from you: " .. dist_from_player .. " tiles")
        end
        player.print("  Power interface: " .. tostring(rover_data.power_interface and rover_data.power_interface.valid))
    end

    player.print("--- Your rover ---")
    local rover_data = storage.csp_rovers[player.index]
    if rover_data then
        player.print("You have a rover registered")
        player.print("  Unit number: " .. tostring(rover_data.unit_number))
    else
        player.print("No rover registered for you")
    end
    player.print("==================")
end)

function table_count(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

commands.add_command("rover-unreg", "Unregister rover without destroying", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local rover_data = storage.csp_rovers[player.index]
    if rover_data then
        if rover_data.power_interface and rover_data.power_interface.valid then
            rover_data.power_interface.destroy()
        end
        storage.csp_rovers[player.index] = nil
        player.print("Rover unregistered")
    else
        player.print("No rover registered")
    end
end)

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)

local function on_technologyResearched(event)
    local research = event.research
    if not research or not research.valid then return end

    local tech_name = research.name
    local handler = TechHandlers[tech_name]
    if handler then
        handler()
    end
end

script.on_event(defines.events.on_research_finished, on_technologyResearched)

local function on_player_configured_blueprint(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    local surface = player.surface
    if not surface or surface.name ~= "nauvis" then return end

    local blueprint = player.blueprint_to_setup
    if not blueprint or not blueprint.valid then return end

    local entities = blueprint.get_inventory(defines.inventory.blueprint_equipment)
    if not entities then return end

    local entity_list = {}
    for i = 1, #entities do
        local entity_data = entities[i]
        if entity_data and entity_data.valid then
            table.insert(entity_list, entity_data)
        end
    end

    if #entity_list > 0 then
        BuildingRestrictions.check_blueprint(player, surface, entity_list)
    end
end

script.on_event(defines.events.on_player_configured_blueprint, on_player_configured_blueprint)

script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_built_entity)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_entity_died, on_entity_died)

local function on_player_mined_entity(event)
    local entity = event.entity
    if not entity or not entity.valid then return end

    if entity.name == "crash-support-rover" then
        for player_index, rover_data in pairs(storage.csp_rovers or {}) do
            if rover_data.unit_number == entity.unit_number then
                if rover_data.power_interface and rover_data.power_interface.valid then
                    rover_data.power_interface.destroy()
                end
                storage.csp_rovers[player_index] = nil
                break
            end
        end
    end
end

script.on_event(defines.events.on_player_mined_entity, on_player_mined_entity)
script.on_event(defines.events.on_player_respawned, on_player_respawned)
script.on_event(defines.events.on_player_driving_changed_state, on_player_driving_changed_state)
