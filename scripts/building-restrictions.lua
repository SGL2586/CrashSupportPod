local BuildingRestrictions = {}

local ALLOWED_ENTITY_TYPES = {
    ["mining-drill"] = true,
    ["pump"] = true,
    ["transport-belt"] = true,
    ["underground-belt"] = true,
    ["splitter"] = true,
    ["electric-pole"] = true,
    ["pipe"] = true,
    ["pipe-to-ground"] = true,
    ["ammo-turret"] = true,
    ["electric-turret"] = true,
    ["fluid-turret"] = true,
    ["artillery-turret"] = true,
    ["wall"] = true,
    ["gate"] = true,
    ["radar"] = true,
    ["loader"] = true,
    ["inserter"] = true,
    ["logistic-container"] = true,
    ["container"] = true,
    ["storage-tank"] = true,
    ["roboport"] = true,
    ["construction-robot"] = true,
    ["logistic-robot"] = true,
    ["rail-signal"] = true,
    ["rail-chain-signal"] = true,
    ["train-stop"] = true,
    ["locomotive"] = true,
    ["cargo-wagon"] = true,
    ["fluid-wagon"] = true,
    ["artillery-wagon"] = true,
    ["car"] = true,
    ["straight-rail"] = true,
    ["curved-rail"] = true,
    ["rail-planner"] = true,
    ["item-request-proxy"] = true,
	["offshore-pump"] = true,
	["lamp"] = true,
}

local ALLOWED_ENTITY_NAMES = {
    ["crash-support-pod"] = true,
    ["crash-support-rover"] = true,
}

local CSP_SURFACE_PREFIX = "csp-interior-"

function BuildingRestrictions.is_allowed_on_nauvis(entity)
    if not entity or not entity.valid then
        return false
    end

    local surface = entity.surface
    if not surface then
        return false
    end

    if string.find(surface.name, CSP_SURFACE_PREFIX) then
        return true
    end

    if surface.name ~= "nauvis" then
        return true
    end

    local entity_type = entity.type
    local entity_name = entity.name

    if ALLOWED_ENTITY_NAMES[entity_name] then
        return true
    end

    if ALLOWED_ENTITY_TYPES[entity_type] then
        return true
    end

    return false
end

function BuildingRestrictions.handle_disallowed_build(event, entity)
    if not entity or not entity.valid then
        return
    end

    local surface = entity.surface
    if not surface or surface.name ~= "nauvis" then
        return
    end

    local entity_name = entity.name
    local entity_type = entity.type

    local item_name = nil
    local item_count = 1

    if storage.csp_restriction_debug then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            player.print("DEBUG: event.item = " .. tostring(event.item) .. ", event.stack_size = " .. tostring(event.stack_size))
            player.print("DEBUG: prototype.items_to_place_this = table")
            
            local items = entity.prototype.items_to_place_this
            local msg = "DEBUG: items_to_place_this contents: "
            local first = true
            for k, v in pairs(items or {}) do
                if not first then msg = msg .. ", " end
                first = false
                msg = msg .. tostring(k) .. "={"
                if type(v) == "table" then
                    local inner_first = true
                    for kk, vv in pairs(v or {}) do
                        if not inner_first then msg = msg .. ", " end
                        inner_first = false
                        msg = msg .. tostring(kk) .. "=" .. tostring(vv)
                    end
                else
                    msg = msg .. tostring(v)
                end
                msg = msg .. "}"
            end
            player.print(msg)
        end
    end

    if event.item then
        item_name = event.item.name or event.item
        item_count = event.stack_size or 1
    end

    if not item_name then
        local items = entity.prototype.items_to_place_this
        if items and items[1] then
            item_name = items[1].name
            item_count = items[1].count or 1
        end
    end

    entity.destroy()

    if storage.csp_restriction_debug then
        log("BuildingRestrictions: Destroyed disallowed entity: " .. entity_name .. " (type: " .. entity_type .. ")")
    end

    local player_index = event.player_index
    if player_index and item_name then
        local player = game.get_player(player_index)
        if player and player.valid then
            player.insert({name = item_name, count = item_count})
            player.print({"csp-building-restriction.not-allowed"})
        end
    end
end

function BuildingRestrictions.check_and_handle(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then
        return false
    end

    if BuildingRestrictions.is_allowed_on_nauvis(entity) then
        return true
    end

    BuildingRestrictions.handle_disallowed_build(event, entity)
    return false
end

function BuildingRestrictions.check_blueprint(player, surface, entities)
    if not player or not player.valid then
        return true
    end

    if not surface or surface.name ~= "nauvis" then
        return true
    end

    local disallowed = {}
    for _, entity_data in pairs(entities or {}) do
        local entity_name = entity_data.name
        local entity_type = entity_data.type

        local allowed = false

        if ALLOWED_ENTITY_NAMES[entity_name] then
            allowed = true
        elseif ALLOWED_ENTITY_TYPES[entity_type] then
            allowed = true
        end

        if not allowed then
            table.insert(disallowed, entity_name or entity_type)
        end
    end

    if #disallowed > 0 then
        player.print({"csp-building-restriction.blueprint-not-allowed", table.concat(disallowed, ", ")})
        return false
    end

    return true
end

return BuildingRestrictions
