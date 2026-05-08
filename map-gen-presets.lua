data:extend({
  {
    type = "map-gen-presets",
    name = "default",
    ["crash-support-pod"] = {
      order = "a[crash-support-pod]",
      default = false,
      basic_settings = {
        autoplace_controls = {
          ["iron-ore"]   = {frequency = 3.0, size = 0.33, richness = 0.5},
          ["copper-ore"] = {frequency = 3.0, size = 0.33, richness = 0.5},
          ["stone"]      = {frequency = 1.33, size = 0.25, richness = 0.5},
          ["coal"]       = {frequency = 1.5, size = 0.5, richness = 0.75},
          ["crude-oil"]  = {frequency = 3.0, size = 1.0, richness = 1.0},
          ["uranium-ore"] = {frequency = 2.0, size = 0.5, richness = 0.5},
          ["enemy-base"] = {frequency = 1.5, size = 0.75},
        },
      },
      advanced_settings = {
        enemy_evolution = {
          pollution_factor = 0.00001,
        },
        enemy_expansion = {
          min_expansion_cooldown = 2,
          max_expansion_cooldown = 30,
        },
      },
    },
  },
})
