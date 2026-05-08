local Event = {}

Event.handlers = {}

function Event.register(event_id, handler)
    if not Event.handlers[event_id] then
        Event.handlers[event_id] = {}
    end
    table.insert(Event.handlers[event_id], handler)
end

function Event.dispatch(event_id, event)
    local handlers = Event.handlers[event_id]
    if not handlers then return end

    for _, handler in ipairs(handlers) do
        local success, err = pcall(handler, event)
        if not success then
            log("Event handler error: " .. tostring(err))
        end
    end
end

return Event
