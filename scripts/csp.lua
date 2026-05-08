local CSP = {}

CSP.metatable = {
    __index = CSP
}

function CSP.create(entity, player_index)
    if not entity or not entity.valid then return nil end

    local csp = {
        entity = entity,
        player_index = player_index,
        unit_number = entity.unit_number,
        interior_surface_name = nil,
        interior_surface = nil,
        state = "mobile",
        reactor_enabled = false,
        deployed_pad_tiles = nil,
        deployed_position = nil,
        input_level = 0,
        pipe_level = 0,
        belt_entities = {},
        pipe_entities = {},
        nauvis_belt_entities = {},
        nauvis_pipe_entities = {},
        power_interface = nil,
        nauvis_power_interface = nil,
        belt_input = nil,
        belt_output = nil,
        expansion_level = storage.csp_expansion_level or 1,
        last_update = 0
    }

    setmetatable(csp, CSP.metatable)

    -- Surface now created on-demand in teleport.lua, not here
    -- csp:init_surface()

    return csp
end

function CSP.rebuild(data)
    if not data then return end

    setmetatable(data, CSP.metatable)

    if data.entity and data.entity.valid then
        data.unit_number = data.entity.unit_number

        if data.interior_surface_name then
            local surface = game.surfaces[data.interior_surface_name]
            if surface then
                data.interior_surface = surface
            end
        end

        if data.power_interface_name then
            local surface = data.entity.surface
            local power_ent = surface.find_entity(data.power_interface_name, data.power_interface_position)
            if power_ent then
                data.power_interface = power_ent
            end
        end

        if data.belt_input_name then
            local surface = data.interior_surface
            if surface then
                local belt_ent = surface.find_entity(data.belt_input_name, data.belt_input_position)
                if belt_ent then
                    data.belt_input = belt_ent
                end
            end
        end

        -- Re-link interior generator/reactor entities after save/load or re-registration
        if data.interior_surface and data.interior_surface.valid then
            local surf = data.interior_surface

            if not data.reactor_entity or not data.reactor_entity.valid then
                local reactors = surf.find_entities_filtered({name = "csp-reactor"})
                if reactors and #reactors > 0 then
                    data.reactor_entity = reactors[1]
                end
            end

            if not data.coal_generator_entity or not data.coal_generator_entity.valid then
                local gens = surf.find_entities_filtered({name = "csp-coal-generator"})
                if gens and #gens > 0 then
                    data.coal_generator_entity = gens[1]
                end
            end

            if not data.generator_power or not data.generator_power.valid then
                local pwr = surf.find_entities_filtered({name = "csp-generator-interface"})
                if pwr and #pwr > 0 then
                    data.generator_power = pwr[1]
                end
            end
        end
    end
end

function CSP:init_surface()
    local surface_name = "csp-interior-" .. self.unit_number

    local existing_surface = game.surfaces[surface_name]
    if existing_surface then
        self.interior_surface = existing_surface
        self.interior_surface_name = surface_name
        return
    end

    local surface = game.create_surface(surface_name, {
        name = surface_name,
        peaceful_mode = false,
        property_evaluations = {
            moisture = 0.1,
            terrain = 0.1
        }
    })

    if surface then
        self.interior_surface = surface
        self.interior_surface_name = surface_name

        self:generate_floor()
        self:setup_power_interface()
        self:setup_belt_io()
    end
end

function CSP:generate_floor()
    if not self.interior_surface then return end

    local surface = self.interior_surface
    local tiles = {}

    for x = -15, 15 do
        for y = -15, 15 do
            local dist = math.sqrt(x*x + y*y)
            if dist <= 14 then
                table.insert(tiles, {name = "concrete", position = {x, y}})
            end
        end
    end

    if #tiles > 0 then
        surface.set_tiles(tiles)
    end

    surface.create_entity({
        name = "coal",
        position = {0, 0},
        amount = 500
    })
end

function CSP:setup_power_interface()
    if not self.interior_surface then return end

    -- Check if power interface already exists
    local existing_power = self.interior_surface.find_entity("csp-solar-interface", {0, 0})

    if existing_power then
        -- Reuse existing entity
        self.power_interface = existing_power
        self.power_interface_name = "csp-solar-interface"
        self.power_interface_position = {0, 0}
    else
        -- Create new entity
        local power_interface = self.interior_surface.create_entity({
            name = "csp-solar-interface",
            position = {0, 0},
            raise_built = false
        })

        if power_interface then
            self.power_interface = power_interface
            self.power_interface_name = "csp-solar-interface"
            self.power_interface_position = {0, 0}
        end
    end

    -- Configure the entity (existing or new)
    if self.power_interface and self.power_interface.valid then
        self.power_interface.destructible = false
        self.power_interface.minable = false
        self.power_interface.operable = false
        self.power_interface.power_production = 0
        self.power_interface.power_usage = 0
    end
end

function CSP:setup_belt_io()
    if not self.interior_surface then return end

    local input_pos = {x = 0, y = -10}
    local output_pos = {x = 0, y = 10}

    local input_belt = self.interior_surface.create_entity({
        name = "crash-support-pod-belt-input",
        position = input_pos,
        direction = defines.direction.south,
        raise_built = false
    })

    if input_belt then
        input_belt.destructible = false
        input_belt.minable = false
        self.belt_input = input_belt
        self.belt_input_name = "crash-support-pod-belt-input"
        self.belt_input_position = input_pos
    end

    local output_belt = self.interior_surface.create_entity({
        name = "crash-support-pod-belt-input",
        position = output_pos,
        direction = defines.direction.north,
        raise_built = false
    })

    if output_belt then
        output_belt.destructible = false
        output_belt.minable = false
        self.belt_output = output_belt
        self.belt_output_name = "crash-support-pod-belt-input"
        self.belt_output_position = output_pos
    end
end

function CSP:valid()
    return self.entity and self.entity.valid
end

function CSP:on_destroyed()
    if self.interior_surface then
        for _, entity in pairs(self.interior_surface.find_entities()) do
            if entity and entity.valid and entity.name ~= "character" then
                entity.destroy()
            end
        end
    end

    if self.state == "deployed" and self.deployed_pad_tiles then
        local entity = self.entity
        if entity and entity.valid then
            local surface = entity.surface
            local tiles = {}
            for _, tile in ipairs(self.deployed_pad_tiles) do
                table.insert(tiles, {
                    name = "out-of-map",
                    position = tile.position
                })
            end
            if #tiles > 0 then
                surface.set_tiles(tiles)
            end
        end
        self.deployed_pad_tiles = nil
    end
end

function CSP.get_by_entity(entity)
    if not entity or not entity.valid then return nil end
    return storage.csp_units[entity.unit_number]
end

function CSP.get_by_unit_number(unit_number)
    return storage.csp_units[unit_number]
end

function CSP.get_surface_for_csp(unit_number)
    return storage.csp_surfaces[unit_number]
end

return CSP
