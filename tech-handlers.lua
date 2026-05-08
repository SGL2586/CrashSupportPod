local Deploy = require("scripts.deploy")
local Teleport = require("scripts.teleport")
local Power = require("scripts.power")

local function broadcast_to_all_players(message)
    for _, player in pairs(game.players) do
        if player.valid then
            player.print(message)
        end
    end
end

local function is_player_inside_surface(surface_name)
    for _, player in pairs(game.players) do
        if player.valid and player.surface and player.surface.name == surface_name then
            return true
        end
    end
    return false
end

local function iterate_csp_units(callback)
    for unit_number, csp_data in pairs(storage.csp_units) do
        if csp_data then
            callback(unit_number, csp_data)
        end
    end
end

local function set_input_level(level)
    iterate_csp_units(function(unit_number, csp_data)
        if storage.csp_pipe_debug then
            local player = game.get_player(csp_data.player_index)
            if player and player.valid then
                player.print("[DEBUG] set_input_level: CSP " .. unit_number .. " upgrading to level " .. level)
            end
        end
        csp_data.input_level = level
        Deploy.recalculate_io_pad(csp_data)
    end)
    Deploy.trigger_recheck()
end

local function set_expansion_level(level)
    storage.csp_expansion_level = level
    iterate_csp_units(function(unit_number, csp_data)
        csp_data.expansion_level = level
        if storage.csp_surfaces[unit_number] then
            storage.csp_surfaces[unit_number].expansion_level = level
        end
        if csp_data.interior_surface and csp_data.interior_surface.valid then
            Teleport.setup_interior_surface(csp_data.interior_surface, level)
        end
    end)
end

local function handle_rover_tech()
    storage.rover_enabled = true
end

local function handle_coal_generator_tech()
    storage.csp_generator_enabled = true
    iterate_csp_units(function(unit_number, csp_data)
        csp_data.pending_generator = true
        if csp_data.interior_surface and csp_data.interior_surface.valid then
            local surface_name = csp_data.interior_surface.name
            local player_inside = is_player_inside_surface(surface_name)
            if player_inside then
                local surface = csp_data.interior_surface
                local pos = {-1, 1.5}
                local generator = surface.create_entity({
                    name = "csp-coal-generator",
                    position = pos,
                    force = "player",
                    raise_built = false
                })
                if generator then
                    generator.destructible = false
                    generator.minable = false
                    csp_data.coal_generator_entity = generator
                    local power_interface = surface.create_entity({
                        name = "csp-generator-interface",
                        position = pos,
                        force = "player",
                        raise_built = false
                    })
                    if power_interface then
                        power_interface.electric_buffer_size = 10000000
                        power_interface.power_production = 0
                        csp_data.generator_power = power_interface
                    end
                    csp_data.pending_generator = false
                end
            else
                broadcast_to_all_players({"csp-message.generator-ready-exit"})
            end
        end
    end)
end

local function handle_reactor_tech()
    iterate_csp_units(function(unit_number, csp_data)
        csp_data.pending_reactor = true
        if csp_data.interior_surface and csp_data.interior_surface.valid then
            if csp_data.coal_generator_entity and csp_data.coal_generator_entity.valid then
                csp_data.coal_generator_entity.destroy()
                csp_data.coal_generator_entity = nil
            end
            local reactor = csp_data.interior_surface.create_entity({
                name = "csp-reactor",
                position = {-1, 3},
                force = "player",
                raise_built = false
            })
            if reactor then
                reactor.destructible = false
                reactor.minable = false
                reactor.active = (csp_data.state == "deployed")
                csp_data.reactor_entity = reactor
                csp_data.pending_reactor = false
                csp_data.pending_generator = false
            end
            broadcast_to_all_players({"csp-message.reactor-ready"})
        end
    end)
end

local function handle_solar_tech()
    storage.csp_solar_tech_level = math.min((storage.csp_solar_tech_level or 0) + 1, 3)
    Power.update_passive_generation()
end

local tech_handlers = {
    ["csp-input1"] = function() set_input_level(1) end,
    ["csp-input2"] = function() set_input_level(2) end,
    ["csp-input3"] = function() set_input_level(3) end,
    ["csp-input4"] = function() set_input_level(4) end,
    ["csp-input5"] = function() set_input_level(5) end,
    ["csp-folding1"] = function() set_expansion_level(2) end,
    ["csp-folding2"] = function() set_expansion_level(3) end,
    ["csp-rover"] = handle_rover_tech,
    ["csp-coal-generator"] = handle_coal_generator_tech,
    ["csp-reactor"] = handle_reactor_tech,
    ["csp-solar1"] = handle_solar_tech,
    ["csp-solar2"] = handle_solar_tech,
    ["csp-solar3"] = handle_solar_tech,
}

return tech_handlers
