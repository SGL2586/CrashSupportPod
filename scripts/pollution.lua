local Pollution = {}

-- Lure emissions_per_second at prototype level handles the base pollution rate:
--   Reactor lure: emissions_per_second = 3600  (3600/s)
--   Coal lure:    emissions_per_second = 300   (300/s)
-- This script spawns/destroys the lure based on power source state
-- so pollution only happens when the reactor or coal gen is actually running.
-- Interior surface pollution is still mirrored via surface.pollute().

function Pollution.on_tick()
    for _, csp in pairs(storage.csp_units) do
        if not (csp and csp.entity and csp.entity.valid) then goto continue end
        if csp.state ~= "deployed" then goto continue end

        -- Mirror interior pollution to Nauvis (then clear it)
        if csp.interior_surface and csp.interior_surface.valid then
            local interior_pollution = csp.interior_surface.get_total_pollution()
            if interior_pollution > 0 then
                csp.entity.surface.pollute(csp.entity.position, interior_pollution)
                csp.interior_surface.clear_pollution()
            end
        end

        -- Check if a pollution source should be active
        local reactor_running = csp.reactor_entity and csp.reactor_entity.valid
            and csp.reactor_entity.active and csp.reactor_at_temp
        local coal_running = csp.coal_generator_entity and csp.coal_generator_entity.valid
            and csp.coal_generator_entity.active
            and csp.coal_generator_entity.burner and csp.coal_generator_entity.burner.currently_burning

        local should_run = reactor_running or coal_running

        -- Determine which lure type matches current tech
        local reactor_tech = csp.reactor_entity and csp.reactor_entity.valid
        local desired_lure = reactor_tech and "csp-pollution-lure-reactor" or "csp-pollution-lure-coal"

        local lure = csp.lure_entity
        local have_lure = lure and lure.valid

        if should_run and not have_lure then
            -- Spawn lure (offset to nestle inside the solar interface)
            local lure_pos = {x = csp.entity.position.x + 3, y = csp.entity.position.y + 3}
            local new_lure = csp.entity.surface.create_entity({
                name = desired_lure,
                position = lure_pos,
                force = "player",
                raise_built = false
            })
            csp.lure_entity = new_lure

        elseif not should_run and have_lure then
            -- Destroy lure (set flag so death handler skips undeploy)
            csp.cleaning_up_lure = true
            lure.destroy()
            csp.lure_entity = nil

        elseif should_run and have_lure and lure.name ~= desired_lure then
            -- Tech upgrade while deployed: swap lure type
            csp.cleaning_up_lure = true
            lure.destroy()
            local lure_pos = {x = csp.entity.position.x + 3, y = csp.entity.position.y + 3}
            local new_lure = csp.entity.surface.create_entity({
                name = desired_lure,
                position = lure_pos,
                force = "player",
                raise_built = false
            })
            csp.lure_entity = new_lure
        end

        ::continue::
    end
end

return Pollution
