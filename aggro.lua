local Aggro = {}

local RANGE = 192
local COOLDOWN_TICKS = 600
local POLLUTION_THRESHOLD = 5

local function get_biter_types(evolution)
    if evolution < 0.15 then
        return {"small-biter", "small-spitter"}
    elseif evolution < 0.3 then
        return {"small-biter", "small-spitter", "medium-biter"}
    elseif evolution < 0.5 then
        return {"medium-biter", "medium-spitter"}
    elseif evolution < 0.7 then
        return {"medium-biter", "medium-spitter", "big-biter"}
    elseif evolution < 0.9 then
        return {"big-biter", "big-spitter"}
    else
        return {"behemoth-biter", "behemoth-spitter"}
    end
end

local function get_wave_size(evolution)
    if evolution < 0.15 then return math.random(1, 2)
    elseif evolution < 0.3 then return math.random(1, 3)
    elseif evolution < 0.5 then return math.random(2, 3)
    elseif evolution < 0.7 then return math.random(2, 4)
    elseif evolution < 0.9 then return math.random(2, 4)
    else return math.random(3, 5) end
end

function Aggro.on_tick()
    storage.csp_nest_cooldowns = storage.csp_nest_cooldowns or {}

    for _, csp in pairs(storage.csp_units) do
        if not (csp and csp.entity and csp.entity.valid) then goto continue end
        if csp.state ~= "deployed" then goto continue end

        local lure = csp.lure_entity
        if not (lure and lure.valid) then goto continue end

        local surface = csp.entity.surface
        local pos = csp.entity.position
        local lure_pos = {x = pos.x + 3, y = pos.y + 3}

        local nests = surface.find_entities_filtered{
            type = "unit-spawner",
            force = "enemy",
            area = {{pos.x - RANGE, pos.y - RANGE}, {pos.x + RANGE, pos.y + RANGE}}
        }

        if #nests == 0 then goto continue end

        local evolution = game.forces.enemy.get_evolution_factor()
        local biter_types = get_biter_types(evolution)
        local wave_size = get_wave_size(evolution)

        for _, nest in ipairs(nests) do
            if not (nest and nest.valid) then goto next_nest end

            local last_tick = storage.csp_nest_cooldowns[nest.unit_number] or 0
            if game.tick - last_tick < COOLDOWN_TICKS then goto next_nest end

            local nest_pollution = surface.get_pollution(nest.position)
            if nest_pollution < POLLUTION_THRESHOLD then goto next_nest end

            local group = surface.create_unit_group{position = nest.position, force = "enemy"}
            local count = wave_size
            local added = 0

            for _ = 1, count do
                local biter_type = biter_types[math.random(#biter_types)]
                local spawn_pos = surface.find_non_colliding_position(biter_type, nest.position, 0, 3, false)
                if spawn_pos then
                    local biter = surface.create_entity{
                        name = biter_type,
                        position = spawn_pos,
                        force = "enemy"
                    }
                    if biter and biter.valid then
                        group.add_member(biter)
                        added = added + 1
                    end
                end
            end

            if added > 0 then
                group.set_command{
                    type = defines.command.attack_area,
                    destination = lure_pos,
                    radius = 3
                }
                group.start_moving()
            else
                group.destroy()
            end

            -- Redirect existing biter groups milling near this nest
            local nearby = surface.find_entities_filtered{
                type = "unit",
                force = "enemy",
                area = {{nest.position.x - 30, nest.position.y - 30}, {nest.position.x + 30, nest.position.y + 30}}
            }
            local seen = {}
            for _, u in ipairs(nearby) do
                if u and u.valid then
                    local ug = u.commandable and u.commandable.parent_group
                    if ug and not seen[ug] then
                        seen[ug] = true
                        local cmd = ug.command
                        local already_going = cmd and (cmd.type == defines.command.attack_area
                            and cmd.destination
                            and math.abs(cmd.destination.x - lure_pos.x) < 10
                            and math.abs(cmd.destination.y - lure_pos.y) < 10)
                        if not already_going then
                            ug.set_command{
                                type = defines.command.attack_area,
                                destination = lure_pos,
                                radius = 3
                            }
                            ug.start_moving()
                        end
                    end
                end
            end

            storage.csp_nest_cooldowns[nest.unit_number] = game.tick

            ::next_nest::
        end

        ::continue::
    end
end

return Aggro
