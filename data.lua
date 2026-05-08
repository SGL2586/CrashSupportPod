require "util"
require "__base__.prototypes.entity.spidertron-animations"

local tint = {r = 0.3, g = 0.3, b = 1, a = 1}
local tech_base = "__base__/graphics/technology/"

local function tinted_tech_icon(tech_icon_path)
    local icons = util.technology_icon_constant_equipment(tech_icon_path)
    icons[1].tint = tint
    return {icons[1]}
end

local function tinted_capacity_icon(tech_icon_path)
    local icons = util.technology_icon_constant_capacity(tech_icon_path)
    icons[1].tint = tint
    return {icons[1]}
end

local function tinted_speed_icon(tech_icon_path)
    local icons = util.technology_icon_constant_speed(tech_icon_path)
    icons[1].tint = tint
    return {icons[1]}
end

local function tinted_damage_icon(tech_icon_path)
    local icons = util.technology_icon_constant_damage(tech_icon_path)
    icons[1].tint = tint
    return {icons[1]}
end

data:extend({
    {
        type = "technology",
        name = "csp-modules",
        icons = tinted_tech_icon(tech_base .. "spidertron.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-modules"}}
        },
        prerequisites = {"automation", "logistics"},
        order = "z[csp-modules]",
        unit = {
            count = 50,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1}
            },
            time = 60
        }
    },
    {
        type = "technology",
        name = "csp-solar1",
        icons = tinted_speed_icon(tech_base .. "solar-energy.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-solar-increase"}}
        },
        prerequisites = {"csp-modules"},
        unit = {
            count = 200,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-solar2",
        icons = tinted_speed_icon(tech_base .. "solar-energy.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-solar-increase"}}
        },
        prerequisites = {"csp-solar1"},
        unit = {
            count = 400,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-solar3",
        icons = tinted_speed_icon(tech_base .. "solar-energy.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-solar-increase"}}
        },
        prerequisites = {"csp-solar2"},
        unit = {
            count = 800,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-input1",
        icons = tinted_capacity_icon(tech_base .. "logistics-1.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-input1"}}
        },
        prerequisites = {"csp-modules"},
        unit = {
            count = 100,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-input2",
        icons = tinted_capacity_icon(tech_base .. "logistics-1.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-input2"}}
        },
        prerequisites = {"csp-input1"},
        unit = {
            count = 100,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-input3",
        icons = tinted_capacity_icon(tech_base .. "logistics-1.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-input3"}}
        },
        prerequisites = {"csp-input2"},
        unit = {
            count = 150,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-input4",
        icons = tinted_capacity_icon(tech_base .. "logistics-1.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-input4"}}
        },
        prerequisites = {"csp-input3"},
        unit = {
            count = 200,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-input5",
        icons = tinted_capacity_icon(tech_base .. "logistics-1.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-input5"}}
        },
        prerequisites = {"csp-input4"},
        unit = {
            count = 250,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-folding1",
        icons = tinted_tech_icon(tech_base .. "spidertron.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-folding1"}}
        },
        prerequisites = {"csp-modules"},
        unit = {
            count = 200,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-folding2",
        icons = tinted_tech_icon(tech_base .. "spidertron.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-folding2"}}
        },
        prerequisites = {"csp-folding1"},
        unit = {
            count = 300,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-coal-generator",
        icons = tinted_speed_icon(tech_base .. "steam-power.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-coal-generator"}}
        },
        prerequisites = {"csp-modules"},
        unit = {
            count = 100,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1}
            },
            time = 30
        }
    },
    {
        type = "technology",
        name = "csp-reactor",
        icons = tinted_damage_icon(tech_base .. "nuclear-power.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-reactor"}}
        },
        prerequisites = {"csp-coal-generator"},
        unit = {
            count = 500,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1}
            },
            time = 30
        }
    }
})

local spidertron_entity = util.table.deepcopy(data.raw["spider-vehicle"]["spidertron"])
spidertron_entity.name = "crash-support-pod"
spidertron_entity.icons = {{icon = "__base__/graphics/icons/spidertron.png", icon_size = 64, icon_mipmaps = 4}}
spidertron_entity.minable = {mining_time = 1, result = nil}
spidertron_entity.guns = {"tank-machine-gun", "spidertron-rocket-launcher-1", "spidertron-rocket-launcher-1", "spidertron-rocket-launcher-1"}
spidertron_entity.automatic_weapon_cycling = true
spidertron_entity.color = {r=1, g=1, b=0, a=0.75}
data:extend{spidertron_entity}

local spidertron_item = util.table.deepcopy(data.raw["item-with-entity-data"]["spidertron"])
spidertron_item.name = "crash-support-pod"
spidertron_item.icons = {{icon = "__base__/graphics/icons/spidertron.png", icon_size = 64, icon_mipmaps = 4}}
spidertron_item.order = "z[csp]"
spidertron_item.place_result = "crash-support-pod"
data:extend{spidertron_item}

local belt_template = util.table.deepcopy(data.raw["linked-belt"]["linked-belt"])
belt_template.name = "crash-support-pod-belt-input"
belt_template.minable_properties = {minable = false}
belt_template.flags = {}
data:extend{belt_template}

local function add_csp_linked_belt(name, speed, order_suffix)
    local belt = util.table.deepcopy(data.raw["linked-belt"]["linked-belt"])
    belt.name = name
    belt.order = (belt.order or "z") .. order_suffix
    belt.speed = speed
    belt.minable_properties = {minable = false}
    belt.flags = {}
    data:extend({belt})

    if data.raw["item"]["linked-belt"] then
        local item = util.table.deepcopy(data.raw["item"]["linked-belt"])
        item.name = name
        item.order = (item.order or "z") .. order_suffix
        item.place_result = name
        data:extend({item})
    end
end

add_csp_linked_belt("csp-linked-belt-basic", 15/480, "-a")
add_csp_linked_belt("csp-linked-belt-fast", 30/480, "-b")
add_csp_linked_belt("csp-linked-belt-express", 45/480, "-c")

local function pipecoverspictures()
    return data.raw["pipe-to-ground"]["pipe-to-ground"].fluid_box.pipe_covers
end

local function add_csp_pipe(name, link_id)
    link_id = link_id or 3410006
    local pipe = util.table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
    pipe.name = name
    pipe.minable = {mining_time = 1, result = name}
    pipe.fast_replaceable_group = nil
    pipe.fluid_box = {
        volume = 100,
        pipe_covers = pipecoverspictures(),
        pipe_connections = {
            {direction = defines.direction.north, position = {0, 0}},
            {connection_type = "linked", flow_direction = "input-output", linked_connection_id = link_id},
            {connection_type = "linked", flow_direction = "input-output", linked_connection_id = link_id + 1}
        },
        hide_connection_info = true,
        max_pipeline_extent = 9999999999
    }
    data:extend({pipe})

    local item = util.table.deepcopy(data.raw["item"]["pipe-to-ground"])
    item.name = name
    item.order = item.order .. "[csp-" .. name .. "]"
    item.place_result = name
    data:extend({item})
end

add_csp_pipe("csp-pipe-1", 3410006)
add_csp_pipe("csp-pipe-2", 3410008)

local base_car = data.raw.car["car"]
local rover_entity = util.table.deepcopy(base_car)

rover_entity.name = "crash-support-rover"
rover_entity.icon = "__base__/graphics/icons/spidertron.png"
rover_entity.icon_size = 64
rover_entity.icon_mipmaps = 4
rover_entity.flags = {"placeable-neutral", "player-creation", "placeable-off-grid"}
rover_entity.minable = {mining_time = 1, result = nil}

local torso_graphics = spidertron_torso_graphics_set(1)
rover_entity.animation = torso_graphics.base_animation
rover_entity.shadow_animation = torso_graphics.shadow_base_animation
rover_entity.light_animation = nil

rover_entity.guns = {"vehicle-machine-gun"}
rover_entity.automatic_weapon_cycling = true
rover_entity.color = {r = 0.8, g = 0.6, b = 0.2, a = 0.75}

rover_entity.max_health = 200
rover_entity.energy_per_hit_point = 1
rover_entity.weight = 200
rover_entity.inventory_size = 30
rover_entity.effectivity = 0.5
rover_entity.braking_power = "200kW"

rover_entity.max_speed = 0.25
rover_entity.acceleration_per_energy = 0.8
rover_entity.braking_speed = 0.03
rover_entity.rotation_speed = 0.012

rover_entity.terrain_friction_modifier = 0
rover_entity.friction = 0.001

rover_entity.has_belt_immunity = true
rover_entity.collision_mask = { layers = {} }

rover_entity.render_layer = "air-object"
rover_entity.final_render_layer = "air-object"

rover_entity.corpse = "medium-remnants"
rover_entity.dying_explosion = "medium-explosion"

rover_entity.vehicle_impact_sound = { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 }

rover_entity.working_sound = {
    sound = { filename = "__base__/sound/car-engine.ogg", volume = 0.5 },
    match_speed_to_activity = true,
}
data:extend{rover_entity}

local rover_item = {
    type = "item-with-entity-data",
    name = "crash-support-rover",
    icon = "__base__/graphics/icons/spidertron.png",
    icon_size = 64,
    icon_mipmaps = 4,
    subgroup = "transport",
    order = "z[rover]",
    place_result = "crash-support-rover",
    stack_size = 5,
}
data:extend{rover_item}

data:extend{
    {
        type = "technology",
        name = "csp-rover",
        icons = tinted_tech_icon(tech_base .. "spidertron.png"),
        effects = {
            {type = "nothing", effect_description = {"technology-effect-description.csp-rover"}}
        },
        prerequisites = {"csp-modules"},
        unit = {
            count = 200,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
            },
            time = 30
        }
    }
}
local boiler_entity = util.table.deepcopy(data.raw["boiler"]["boiler"])
boiler_entity.name = "csp-coal-generator"
boiler_entity.icons = {{icon = "__base__/graphics/icons/boiler.png", icon_size = 64, icon_mipmaps = 4}}
boiler_entity.collision_box = {{-1.4, -0.9}, {1.4, 0.9}}
boiler_entity.selection_box = {{-1.5, -1.0}, {1.5, 1.0}}
boiler_entity.energy_consumption = "1.8MW"
boiler_entity.target_temperature = 165
boiler_entity.fluid_box.filter = "water"
boiler_entity.fluid_box.minimum_temperature = 15
boiler_entity.fluid_box.maximum_temperature = 100
data:extend{boiler_entity}

local reactor_entity = util.table.deepcopy(data.raw["reactor"]["nuclear-reactor"])
reactor_entity.name = "csp-reactor"
reactor_entity.icons = {{icon = "__base__/graphics/icons/nuclear-reactor.png", icon_size = 64, icon_mipmaps = 4}}
reactor_entity.collision_box = {{-2.4, -2.4}, {2.4, 2.4}}  -- 5×5
reactor_entity.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
reactor_entity.energy_consumption = "120MW"
data:extend{reactor_entity}

-- CSP Solar interface (solar icon, "CSP Solar Array")
local solar_interface = util.table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
solar_interface.name = "csp-solar-interface"
solar_interface.energy_production = "0kW"
solar_interface.power_production = 0
solar_interface.energy_usage = "0kW"
solar_interface.energy_source = {
	type="electric",
	buffer_capacity="5MJ",
	usage_priority="tertiary"
}
solar_interface.icons = {{icon = "__base__/graphics/icons/solar-panel.png", icon_size = 64, icon_mipmaps = 4}}
solar_interface.localised_name = {"entity-name.csp-solar-array"}
data:extend{solar_interface}

-- CSP Generator interface (steam engine icon, "CSP Generator")
local gen_interface = util.table.deepcopy(data.raw["electric-energy-interface"]["hidden-electric-energy-interface"])
gen_interface.name = "csp-generator-interface"
gen_interface.energy_production = "0kW"
gen_interface.icons = {{icon = "__base__/graphics/icons/steam-engine.png", icon_size = 64, icon_mipmaps = 4}}
gen_interface.localised_name = {"entity-name.csp-generator"}
data:extend{gen_interface}

-- CSP Biter Lures (hidden attackable targets for biters, emissions match pollution script rates)
local lure_base = {
    type = "simple-entity-with-force",
    flags = {"not-on-map", "placeable-off-grid", "player-creation", "not-flammable", "not-repairable", "not-selectable-in-game"},
    pictures = {
        {filename = "__CrashSupportPod__/graphics/empty.png", width = 1, height = 1}
    },
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selection_box = {{0, 0}, {0, 0}},
    max_health = 200,
}

local lure_coal = util.table.deepcopy(lure_base)
lure_coal.name = "csp-pollution-lure-coal"
lure_coal.emissions_per_second = {pollution = 300}
lure_coal.order = "z[csp-lure-coal]"

local lure_reactor = util.table.deepcopy(lure_base)
lure_reactor.name = "csp-pollution-lure-reactor"
lure_reactor.emissions_per_second = {pollution = 3600}
lure_reactor.order = "z[csp-lure-reactor]"

data:extend{lure_coal, lure_reactor}
