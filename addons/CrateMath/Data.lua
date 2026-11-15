-- CrateMath data: Waylaid Crate types, their fill options, and MF rewards.
--
-- Crate options: method.gg's post-launch crate list. Each crate needs ONE of
-- its options, not all of them.
-- MF rewards: Stoyven's Merchant's Favor guide (mobalytics, Oct 2026). Raw-
-- material crates (Ore, Herbs, Textiles, Curiosities) pay 5/10/15 by tier;
-- crafted-material crates (Ingots, Fabrics, Parts) pay double. Artisan
-- rewards aren't published yet (mf = nil).
--
-- Item IDs are the original Classic IDs. /cm check confirms each one against
-- the game and prints any that don't match.

local _, CM = ...

CM.items = {
  -- ore
  [2770] = "Copper Ore", [2771] = "Tin Ore", [2772] = "Iron Ore",
  [2775] = "Silver Ore", [2776] = "Gold Ore", [3858] = "Mithril Ore",
  [7911] = "Truesilver Ore", [10620] = "Thorium Ore", [11370] = "Dark Iron Ore",
  -- bars
  [2840] = "Copper Bar", [3576] = "Tin Bar", [2841] = "Bronze Bar",
  [2842] = "Silver Bar", [3575] = "Iron Bar", [3860] = "Mithril Bar",
  [3859] = "Steel Bar", [3577] = "Gold Bar", [11371] = "Dark Iron Bar",
  [6037] = "Truesilver Bar", [12359] = "Thorium Bar",
  -- herbs
  [2447] = "Peacebloom", [765] = "Silverleaf", [2449] = "Earthroot",
  [785] = "Mageroyal", [2450] = "Briarthorn",
  [3820] = "Stranglekelp", [2453] = "Bruiseweed", [3355] = "Wild Steelbloom",
  [3369] = "Grave Moss", [3356] = "Kingsblood",
  [3357] = "Liferoot", [3818] = "Fadeleaf", [3821] = "Goldthorn",
  [3358] = "Khadgar's Whisker",
  [3819] = "Wintersbite", [4625] = "Firebloom", [8831] = "Purple Lotus",
  [8836] = "Arthas' Tears",
  [13464] = "Golden Sansam", [8838] = "Sungrass", [8839] = "Blindweed",
  [8845] = "Ghost Mushroom", [8846] = "Gromsblood",
  [13463] = "Dreamfoil", [13465] = "Mountain Silversage", [13466] = "Plaguebloom",
  [13467] = "Icecap",
  -- engineering parts
  [4359] = "Handful of Copper Bolts", [4361] = "Copper Tube", [4363] = "Copper Modulator",
  [4371] = "Bronze Tube", [4375] = "Whirring Bronze Gizmo", [4382] = "Bronze Framework",
  [10558] = "Gold Power Core",
  [4387] = "Iron Strut", [10559] = "Mithril Tube", [10560] = "Unstable Trigger",
  [10561] = "Mithril Casing",
  [15994] = "Thorium Widget", [18631] = "Truesilver Transformer", [16000] = "Thorium Tube",
  -- cloth and leather
  [2589] = "Linen Cloth", [2592] = "Wool Cloth", [4306] = "Silk Cloth",
  [4338] = "Mageweave Cloth", [14047] = "Runecloth",
  [2318] = "Light Leather", [2319] = "Medium Leather", [4234] = "Heavy Leather",
  [4304] = "Thick Leather", [8170] = "Rugged Leather",
  -- bolts and cured hides
  [2996] = "Bolt of Linen Cloth", [2997] = "Bolt of Woolen Cloth", [4305] = "Bolt of Silk Cloth",
  [4339] = "Bolt of Mageweave", [14048] = "Bolt of Runecloth",
  [4231] = "Cured Light Hide", [4233] = "Cured Medium Hide", [4236] = "Cured Heavy Hide",
  [8172] = "Cured Thick Hide",
  -- enchanting
  [10940] = "Strange Dust", [10939] = "Greater Magic Essence",
  [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard",
  [11083] = "Soul Dust", [11082] = "Greater Astral Essence",
  [11138] = "Small Glowing Shard", [11139] = "Large Glowing Shard",
  [11137] = "Vision Dust", [11135] = "Greater Mystic Essence",
  [11177] = "Small Radiant Shard", [11178] = "Large Radiant Shard",
  [11176] = "Dream Dust", [11175] = "Greater Nether Essence",
  [14343] = "Small Brilliant Shard", [14344] = "Large Brilliant Shard",
}

-- MF reward by tier. "raw" crates take gathered materials, "crafted" crates
-- take processed ones.
CM.mfByTier = {
  raw     = { Apprentice = 5,  Journeyman = 10, Expert = 15 },
  crafted = { Apprentice = 10, Journeyman = 20, Expert = 30 },
}

-- Keyed by the part of the crate's name after "Waylaid Crate: ".
-- level = level needed to use the crate. opts = { {itemID, qty}, ... }.
CM.crates = {
  ["Apprentice Ore"]  = { tier = "Apprentice", kind = "raw", level = 10, opts = { {2770, 20}, {2771, 20} } },
  ["Journeyman Ore"]  = { tier = "Journeyman", kind = "raw", level = 10, opts = { {2775, 10}, {2772, 20} } },
  ["Expert Ore"]      = { tier = "Expert",     kind = "raw", level = 20, opts = { {2776, 10}, {3858, 20} } },
  ["Artisan Ore"]     = { tier = "Artisan",    kind = "raw", level = 35, opts = { {7911, 10}, {10620, 20}, {11370, 20} } },

  ["Apprentice Ingots"] = { tier = "Apprentice", kind = "crafted", level = 10, opts = { {2840, 20}, {3576, 20}, {2841, 10} } },
  ["Journeyman Ingots"] = { tier = "Journeyman", kind = "crafted", level = 10, opts = { {2842, 10}, {3575, 20} } },
  ["Expert Ingots"]     = { tier = "Expert",     kind = "crafted", level = 20, opts = { {3860, 20}, {3859, 15}, {3577, 10} } },
  ["Artisan Ingots"]    = { tier = "Artisan",    kind = "crafted", level = 35, opts = { {11371, 2}, {6037, 10}, {12359, 20} } },

  ["Apprentice Herbs"]        = { tier = "Apprentice", kind = "raw", level = 10, opts = { {2447, 20}, {765, 20}, {2449, 10}, {785, 10}, {2450, 10} } },
  ["Journeyman Herbs"]        = { tier = "Journeyman", kind = "raw", level = 10, opts = { {3820, 10}, {2453, 10}, {3355, 10}, {3369, 10}, {3356, 10} } },
  ["Earthly Expert Herbs"]    = { tier = "Expert",     kind = "raw", level = 20, opts = { {3357, 20}, {3818, 10}, {3821, 10}, {3358, 10} } },
  ["Flowering Expert Herbs"]  = { tier = "Expert",     kind = "raw", level = 20, opts = { {3819, 10}, {4625, 10}, {8831, 20}, {8836, 10} } },
  ["Earthly Artisan Herbs"]   = { tier = "Artisan",    kind = "raw", level = 35, opts = { {13464, 10}, {8838, 20}, {8839, 10}, {8845, 10}, {8846, 10} } },
  ["Flowering Artisan Herbs"] = { tier = "Artisan",    kind = "raw", level = 35, opts = { {13463, 20}, {13465, 20}, {13466, 20}, {13467, 20} } },

  ["Apprentice Parts"] = { tier = "Apprentice", kind = "crafted", level = 10, opts = { {4359, 16}, {4361, 16}, {4363, 4} } },
  ["Journeyman Parts"] = { tier = "Journeyman", kind = "crafted", level = 10, opts = { {4371, 8}, {4375, 7}, {4382, 4}, {10558, 45} } },
  ["Expert Parts"]     = { tier = "Expert",     kind = "crafted", level = 20, opts = { {4387, 8}, {10559, 5}, {10560, 12}, {10561, 5} } },
  ["Artisan Parts"]    = { tier = "Artisan",    kind = "crafted", level = 35, opts = { {15994, 5}, {18631, 5}, {16000, 2} } },

  ["Apprentice Textiles"] = { tier = "Apprentice", kind = "raw", level = 10, opts = { {2589, 40}, {2318, 20} } },
  ["Journeyman Textiles"] = { tier = "Journeyman", kind = "raw", level = 10, opts = { {2592, 20}, {4306, 40}, {2319, 20} } },
  ["Expert Textiles"]     = { tier = "Expert",     kind = "raw", level = 20, opts = { {4338, 40}, {4234, 20} } },
  ["Artisan Textiles"]    = { tier = "Artisan",    kind = "raw", level = 35, opts = { {14047, 40}, {4304, 20}, {8170, 20} } },

  ["Apprentice Fabrics"] = { tier = "Apprentice", kind = "crafted", level = 10, opts = { {4231, 2}, {2996, 20} } },
  ["Journeyman Fabrics"] = { tier = "Journeyman", kind = "crafted", level = 10, opts = { {2997, 6}, {4305, 10}, {4233, 2} } },
  ["Expert Fabrics"]     = { tier = "Expert",     kind = "crafted", level = 20, opts = { {4339, 8}, {4236, 2} } },
  ["Artisan Fabrics"]    = { tier = "Artisan",    kind = "crafted", level = 35, opts = { {14048, 8}, {8172, 2} } },

  ["Apprentice Curiosities"] = { tier = "Apprentice", kind = "raw", level = 10, opts = { {10940, 20}, {10939, 4}, {10978, 6}, {11084, 2} } },
  ["Journeyman Curiosities"] = { tier = "Journeyman", kind = "raw", level = 10, opts = { {11083, 20}, {11082, 4}, {11138, 6}, {11139, 2} } },
  ["Expert Curiosities"]     = { tier = "Expert",     kind = "raw", level = 20, opts = { {11137, 20}, {11135, 4}, {11177, 6}, {11178, 2} } },
  ["Artisan Curiosities"]    = { tier = "Artisan",    kind = "raw", level = 35, opts = { {11176, 20}, {11175, 4}, {14343, 6}, {14344, 2} } },
}

for _, c in pairs(CM.crates) do
  c.mf = CM.mfByTier[c.kind][c.tier]
end

-- Recipes bought with Merchant's Favor that we're saving toward. MF costs
-- are from beta-era guides; correct them from the vendor once you see it.
CM.targets = {
  { name = "Elixir of the Grizzly",        mf = 240, who = "Frostbone" },
  { name = "Major Frenzy Potion",          mf = 240, who = "Frostbone" },
  { name = "Elixir of Greater Fortitude",  mf = 120, who = "Frostbone" },
  { name = "Leatherworking set piece (Honored)",  mf = 90, who = "Tahnu" },
  { name = "Leatherworking set piece (Friendly)", mf = 60, who = "Tahnu" },
}
