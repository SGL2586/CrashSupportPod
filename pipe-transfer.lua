local PipeTransfer = {}

local TRANSFER_RATE = 60

function PipeTransfer.on_tick()
    storage.csp_units = storage.csp_units or {}

    for unit_number, csp_data in pairs(storage.csp_units) do
        if csp_data and csp_data.state == "deployed" then
            if storage.csp_pipe_debug then
                game.print("CSP " .. unit_number .. " - attempting transfer, state: " .. csp_data.state)
            end
            PipeTransfer.transfer_fluids(csp_data)
        end
    end
end

function PipeTransfer.transfer_fluids(csp_data)
    if storage.csp_pipe_debug then
        game.print("transfer_fluids called")
        game.print("  pipe_entities: " .. tostring(#(csp_data.pipe_entities or {})))
        game.print("  nauvis_pipe_entities: " .. tostring(#(csp_data.nauvis_pipe_entities or {})))
    end

    if not csp_data.pipe_entities or #csp_data.pipe_entities == 0 then
        if storage.csp_pipe_debug then game.print("  No interior pipes, returning") end
        return
    end
    if not csp_data.nauvis_pipe_entities or #csp_data.nauvis_pipe_entities == 0 then
        if storage.csp_pipe_debug then game.print("  No nauvis pipes, returning") end
        return
    end

    local pipe_count = #csp_data.pipe_entities
    local nauvis_count = #csp_data.nauvis_pipe_entities

    if storage.csp_pipe_debug then
        game.print("  Pipe counts - interior: " .. pipe_count .. ", nauvis: " .. nauvis_count)
    end

    for i = 1, pipe_count do
        local interior_pipe_data = csp_data.pipe_entities[i]
        local nauvis_pipe_data = csp_data.nauvis_pipe_entities[i]

        if not interior_pipe_data or not nauvis_pipe_data then
            goto continue
        end

        local interior_pipe = interior_pipe_data.entity
        local nauvis_pipe = nauvis_pipe_data.entity

        if not (interior_pipe and interior_pipe.valid and nauvis_pipe and nauvis_pipe.valid) then
            goto continue
        end

        if i == 1 then
            PipeTransfer.transfer_between_pipes(nauvis_pipe, interior_pipe)
        elseif i == 2 then
            PipeTransfer.transfer_between_pipes(interior_pipe, nauvis_pipe)
        end

        ::continue::
    end
end

function PipeTransfer.transfer_between_pipes(source_pipe, target_pipe)
    if not source_pipe or not source_pipe.valid or not target_pipe or not target_pipe.valid then
        if storage.csp_pipe_debug then game.print("  Invalid pipe, returning") end
        return
    end

    local source_fluidbox = source_pipe.fluidbox
    local target_fluidbox = target_pipe.fluidbox

    if not source_fluidbox or not target_fluidbox then
        if storage.csp_pipe_debug then game.print("  No fluidbox, returning") end
        return
    end

    local source_fluid = source_fluidbox[1]
    if not source_fluid or not source_fluid.name then
        if storage.csp_pipe_debug then game.print("  No source fluid, returning") end
        return
    end

    if storage.csp_pipe_debug then
        game.print("  Found fluid: " .. source_fluid.name .. " amount: " .. source_fluid.amount)
    end

    local amount_to_transfer = math.min(source_fluid.amount, TRANSFER_RATE)

    if amount_to_transfer <= 0 then
        return
    end

    local removed = source_pipe.remove_fluid({
        name = source_fluid.name,
        amount = amount_to_transfer
    })

    if removed and removed > 0 then
        local inserted = target_pipe.insert_fluid({
            name = source_fluid.name,
            amount = removed
        })
    end
end

return PipeTransfer