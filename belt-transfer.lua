local BeltTransfer = {}

BeltTransfer.MAX_TRANSFER_PER_TICK = 100
BeltTransfer.TRANSFER_INTERVAL = 60

function BeltTransfer.process_inputs()
    for unit_number, csp_data in pairs(storage.csp_units) do
        if csp_data and csp_data.entity and csp_data.entity.valid then
            BeltTransfer.process_csp_input(csp_data)
        end
    end
end

function BeltTransfer.process_csp_input(csp)
    if not csp.belt_input or not csp.belt_input.valid then return end

    local belt = csp.belt_input
    local belt_pos = belt.position
    local surface = csp.interior_surface

    if not surface then return end

    local items_on_belt = belt.get_item_count()
    if items_on_belt == 0 then return end

    local inserter_pos = {x = belt_pos.x + 1, y = belt_pos.y}
    local nearby_chests = surface.find_entities_filtered({
        position = inserter_pos,
        radius = 2,
        type = {"container", "logistic-container", "storage-tank"}
    })

    if #nearby_chests == 0 then
        local nearby_inserters = surface.find_entities_filtered({
            position = inserter_pos,
            radius = 3,
            type = {"inserter"}
        })

        for _, inserter in pairs(nearby_inserters) do
            if inserter.held_stack and inserter.held_stack.valid_for_read then
                return
            end
        end

        local buffer_chest = surface.create_entity({
            name = "steel-chest",
            position = inserter_pos,
            raise_built = false
        })

        if buffer_chest then
            buffer_chest.destructible = false
            BeltTransfer.transfer_items_to_chest(belt, buffer_chest)
        end
    else
        BeltTransfer.transfer_items_to_chest(belt, nearby_chests[1])
    end
end

function BeltTransfer.transfer_items_to_chest(belt, chest)
    local items = belt.get_item_count()
    if items == 0 then return end

    local item_prototypes = BeltTransfer.get_belt_contents(belt)
    if #item_prototypes == 0 then return end

    local remaining_capacity = BeltTransfer.get_chest_capacity(chest)
    if remaining_capacity <= 0 then return end

    local transfer_count = math.min(items, remaining_capacity, BeltTransfer.MAX_TRANSFER_PER_TICK)

    for _, item in ipairs(item_prototypes) do
        local to_transfer = math.min(item.count, math.floor(transfer_count / #item_prototypes))
        if to_transfer > 0 then
            local removed = belt.remove({name = item.name, count = to_transfer})
            if removed > 0 then
                chest.insert({name = item.name, count = removed})
            end
        end
    end
end

function BeltTransfer.get_belt_contents(belt)
    local contents = {}
    local transport_line = belt.get_transport_line(1)
    if transport_line then
        for i = 1, #transport_line do
            local item = transport_line[i]
            if item and item.valid_for_read then
                local found = false
                for _, existing in ipairs(contents) do
                    if existing.name == item.name then
                        existing.count = existing.count + 1
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(contents, {name = item.name, count = 1})
                end
            end
        end
    end
    return contents
end

function BeltTransfer.get_chest_capacity(chest)
    if chest.name == "storage-tank" then
        local fluids = chest.fluidbox
        if not fluids or #fluids == 0 then
            return 100
        end
        return 0
    else
        local inventory = chest.get_inventory(defines.inventory.chest)
        if not inventory or not inventory.valid then return 0 end

        local free_slots = 0
        for i = 1, #inventory do
            if not inventory[i].valid_for_read then
                free_slots = free_slots + 1
            end
        end

        return free_slots * 100
    end
end

function BeltTransfer.connect_linked_belts()
    for unit_number, surface_info in pairs(storage.csp_surfaces) do
        local csp = storage.csp_units[unit_number]
        if csp and csp.interior_surface then
            local surface = csp.interior_surface

            local nauvis = game.surfaces["nauvis"]
            if nauvis then
                local csp_entity = csp.entity
                if csp_entity and csp_entity.valid then
                    local external_belt = nauvis.create_entity({
                        name = "crash-support-pod-belt-input",
                        position = {x = csp_entity.position.x, y = csp_entity.position.y + 3},
                        direction = defines.direction.south
                    })

                    if external_belt and csp.belt_input and csp.belt_input.valid then
                        local success, err = pcall(function()
                            csp.belt_input.connect_linked_belts(external_belt)
                        end)
                        if not success then
                            external_belt.destroy()
                        end
                    end
                end
            end
        end
    end
end

return BeltTransfer
