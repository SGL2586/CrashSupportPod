local GUI = {}

local function get_csp_gui_root(player)
    if not player or not player.valid then return nil end

    local gui = player.gui
    if not gui then return nil end

    local left = gui.left
    if not left then return nil end
    
    return left
end

function GUI.update(player)
    if not player or not player.valid then return end

    local root = get_csp_gui_root(player)
    if not root then return end

    -- Single persistent frame
    local frame = root["csp_main_frame"]
    if frame then
        frame.destroy()
    end

    frame = root.add({
        type = "frame",
        name = "csp_main_frame",
        caption = {"gui.csp-title"},
        direction = "vertical"
    })

    -- Get player context
    local current_surface = player.surface and player.surface.name or nil
    local vehicle = player.vehicle
    local in_csp_vehicle = vehicle and vehicle.name == "crash-support-pod"

    -- Determine button states
    local on_nauvis = (current_surface == "nauvis")
    local on_csp_interior = current_surface and string.sub(current_surface, 1, 13) == "csp-interior-"

    -- Exit button (show when on csp-interior surface)
    local show_exit = on_csp_interior

    -- Determine deploy state - need to check ALL CSPs on Nauvis, not just player's vehicle
    local csp_data = nil
    local csp_on_nauvis = nil

    global = global or {}
    storage.csp_units = storage.csp_units or {}

    -- First, check registered CSPs
    for unit_number, csp in pairs(storage.csp_units) do
        if csp and csp.entity and csp.entity.valid then
            if csp.entity.surface.name == "nauvis" then
                csp_on_nauvis = csp
                break
            end
        end
    end

    -- If no registered CSP found, search for any crash-support-pod on Nauvis surface
    if not csp_on_nauvis then
        local nauvis = game.surfaces.nauvis
        if nauvis then
            local pods = nauvis.find_entities_filtered({name = "crash-support-pod"})
            for _, pod in ipairs(pods) do
                if pod and pod.valid then
                    csp_on_nauvis = storage.csp_units[pod.unit_number]
                    if not csp_on_nauvis then
                        -- Create a minimal entry if not registered
                        csp_on_nauvis = {
                            entity = pod,
                            unit_number = pod.unit_number,
                            state = "mobile",
                            reactor_enabled = false,
                            expansion_level = storage.csp_expansion_level or 1
                        }
                    end
                    break
                end
            end
        end
    end

    if in_csp_vehicle then
        csp_data = storage.csp_units[vehicle.unit_number]
    end

    local is_deployed = csp_data and csp_data.state == "deployed"

    -- Enter button always shows on Nauvis; enabled based on proximity to CSP
    local enter_enabled = false
    local enter_tooltip = {"gui.csp-enter-tip-no-csp"}

    if on_nauvis and csp_on_nauvis and csp_on_nauvis.entity and csp_on_nauvis.entity.valid then
        local dist = math.sqrt((player.position.x - csp_on_nauvis.entity.position.x)^2 +
                              (player.position.y - csp_on_nauvis.entity.position.y)^2)
        if dist <= 10 then
            enter_enabled = true
            enter_tooltip = {"gui.csp-enter-tip"}
        else
            enter_tooltip = {"gui.csp-enter-tip-too-far"}
        end
    end

    -- Deploy button: player must be outside CSP (not in vehicle), on Nauvis, CSP is mobile
    -- Check if player is near any CSP on Nauvis and can deploy it
    local show_deploy = false
    if on_nauvis and not in_csp_vehicle and csp_on_nauvis then
        if csp_on_nauvis.state == "mobile" then
            -- Check if player is close enough to the CSP (within 10 tiles)
            local dist = math.sqrt((player.position.x - csp_on_nauvis.entity.position.x)^2 +
                                  (player.position.y - csp_on_nauvis.entity.position.y)^2)
            if dist <= 10 then
                show_deploy = true
            end
        end
    end

    -- Undeploy button: show when player is outside and near a deployed CSP
    local show_undeploy = false
    if on_nauvis and not in_csp_vehicle and csp_on_nauvis then
        if csp_on_nauvis.state == "deployed" then
            -- Check if player is close enough to the deployed CSP (within 10 tiles)
            local dist = math.sqrt((player.position.x - csp_on_nauvis.entity.position.x)^2 +
                                  (player.position.y - csp_on_nauvis.entity.position.y)^2)
            if dist <= 10 then
                show_undeploy = true
            end
        end
    end

    -- Add button flow
    local button_flow = frame.add({
        type = "flow",
        name = "csp_button_flow",
        direction = "horizontal"
    })

    if on_nauvis then
        button_flow.add({
            type = "button",
            name = "csp_enter_interior",
            caption = {"gui.csp-enter"},
            tooltip = enter_tooltip,
            enabled = enter_enabled
        })
    elseif show_exit then
        button_flow.add({
            type = "button",
            name = "csp_exit_interior",
            caption = {"gui.csp-exit"},
            tooltip = {"gui.csp-exit-tip"}
        })
    else
        -- No teleport available
        local label = frame.add({
            type = "label",
            name = "csp_no_teleport",
            caption = {"gui.csp-no-teleport"}
        })
    end

    -- Add deploy/undeploy button (separate flow for layout)
    local deploy_flow = frame.add({
        type = "flow",
        name = "csp_deploy_flow",
        direction = "horizontal"
    })

    -- Show deploy button when in CSP on Nauvis (mobile) - needs player to not be in vehicle per requirements
    -- Actually user said must exit, so check if NOT in vehicle for deploy
    local player_outside = not in_csp_vehicle
    if show_deploy and player_outside then
        deploy_flow.add({
            type = "button",
            name = "csp_deploy",
            caption = {"gui.csp-deploy"},
            tooltip = {"gui.csp-deploy-tip"}
        })
    elseif show_undeploy then
        deploy_flow.add({
            type = "button",
            name = "csp_undeploy",
            caption = {"gui.csp-undeploy"},
            tooltip = {"gui.csp-undeploy-tip"}
        })
    end

    -- Status label
    local state = "mobile"
    global = global or {}
    storage.csp_units = storage.csp_units or {}

    if in_csp_vehicle then
        local csp = storage.csp_units[vehicle.unit_number]
        state = csp and csp.state or "mobile"
    elseif on_csp_interior then
        state = "interior"
    else
        local csp = csp_on_nauvis
        if csp and csp.state then
            state = csp.state
        end
    end

    frame.add({
        type = "label",
        name = "csp_status",
        caption = {"gui.csp-status", state}
    })

    storage.csp_rovers = storage.csp_rovers or {}
    storage.rover_enabled = storage.rover_enabled or false
    local rover_data = storage.csp_rovers[player.index]
    local has_rover = rover_data and rover_data.entity and rover_data.entity.valid

    -- Determine if player has registered CSP
    storage.csp_units = storage.csp_units or {}
    local has_registered_csp = false
    for unit_number, csp in pairs(storage.csp_units) do
        if csp and csp.entity and csp.entity.valid then
            has_registered_csp = true
            break
        end
    end

    local rover_state = "none"
    if has_rover then
        rover_state = rover_data.state
    end

    frame.add({
        type = "label",
        name = "rover_status",
        caption = {"gui.csp-rover-status", rover_state}
    })

    local rover_button_flow = frame.add({
        type = "flow",
        name = "csp_rover_button_flow",
        direction = "horizontal"
    })

    -- Show Deploy Rover button if tech enabled, CSP registered, no rover yet
    if storage.rover_enabled and has_registered_csp and not has_rover then
        rover_button_flow.add({
            type = "button",
            name = "csp_deploy_rover",
            caption = {"gui.csp-deploy-rover"},
            tooltip = {"gui.csp-deploy-rover-tip"}
        })
    elseif has_rover then
        local dist = math.sqrt(
            (player.position.x - rover_data.entity.position.x)^2 +
            (player.position.y - rover_data.entity.position.y)^2
        )
        local near_rover = dist <= 10

        if near_rover then
            if rover_data.state == "mobile" then
                rover_button_flow.add({
                    type = "button",
                    name = "csp_deploy_rover",
                    caption = {"gui.csp-rover-power"},
                    tooltip = {"gui.csp-rover-power-tip"}
                })
            else
                rover_button_flow.add({
                    type = "button",
                    name = "csp_undeploy_rover",
                    caption = {"gui.csp-undeploy-rover"},
                    tooltip = {"gui.csp-undeploy-rover-tip"}
                })
            end
        end

        rover_button_flow.add({
            type = "button",
            name = "csp_destroy_rover",
            caption = {"gui.csp-destroy-rover"},
            tooltip = {"gui.csp-destroy-rover-tip"}
        })
    end
end

function GUI.destroy(player)
    if not player or not player.valid then return end

    local root = get_csp_gui_root(player)
    if not root then return end

    local frame = root["csp_main_frame"]
    if frame then
        frame.destroy()
    end
end

return GUI
