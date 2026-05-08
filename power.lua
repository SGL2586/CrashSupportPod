local Power = {}

Power.BASE_SOLAR_OUTPUT = 3
Power.SOLAR_PER_LEVEL = 3

function Power.update_passive_generation()
    local tech_level = storage.csp_solar_tech_level or 0
    local power_mw = Power.BASE_SOLAR_OUTPUT + (tech_level * Power.SOLAR_PER_LEVEL)
    local power_jpt = power_mw * 1000000 / 60

    for unit_number, csp in pairs(storage.csp_units) do
        if csp and csp.entity and csp.entity.valid then
            if csp.power_interface and csp.power_interface.valid then
                csp.power_interface.power_production = power_jpt
            end
            if csp.nauvis_power_interface and csp.nauvis_power_interface.valid then
                csp.nauvis_power_interface.power_production = power_jpt
            end
        end
    end
end

function Power.get_power_status(csp)
    if not csp or not csp.power_interface or not csp.power_interface.valid then
        return 0, 0, 0
    end

    local power_interface = csp.power_interface
    local production = power_interface.power_production or 0
    local current_power = power_interface.energy or 0

    return production * 60 / 1000000,
           current_power,
           power_interface.electric_buffer_size or 0
end

return Power
