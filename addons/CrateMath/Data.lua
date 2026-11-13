-- CrateMath data: Waylaid Crate bundles and Merchant's Favor recipe targets.
--
-- Bundle contents and MF values come from community guides written during
-- the WoW: Forever beta (wow-professions.com, method.gg). Treat them as a
-- starting point: /cm check verifies the item IDs, and the tooltip log
-- (CrateMathDB.crates) records what real crates say so this table can be
-- corrected.
--
-- Item IDs are the original Classic IDs. Forever appears to reuse them, but
-- /cm check is the proof.

local _, CM = ...

CM.items = {
  -- ore
  [2770] = "Copper Ore",   [2771] = "Tin Ore",     [2772] = "Iron Ore",
  [2775] = "Silver Ore",   [2776] = "Gold Ore",    [3858] = "Mithril Ore",
  -- bars
  [3859] = "Steel Bar",    [3860] = "Mithril Bar", [3577] = "Gold Bar",
  -- cloth
  [2589] = "Linen Cloth",  [2592] = "Wool Cloth",  [4306] = "Silk Cloth",
  [4338] = "Mageweave Cloth", [14047] = "Runecloth",
  [4339] = "Bolt of Mageweave",
  -- leather
  [2318] = "Light Leather", [2319] = "Medium Leather", [4234] = "Heavy Leather",
  [4304] = "Thick Leather", [8170] = "Rugged Leather", [4236] = "Cured Heavy Hide",
}

-- Each bundle fills one crate. mf = nil means the reward isn't known yet.
-- Add Herbs / Curiosities / Parts bundles here once their contents are known.
CM.bundles = {
  { tier = "Apprentice", cat = "Textiles", mf = 5,  items = { {2589, 40} } },
  { tier = "Apprentice", cat = "Textiles", mf = 5,  items = { {2318, 20} } },
  { tier = "Apprentice", cat = "Ore",      mf = 5,  items = { {2770, 20}, {2771, 20} } },

  { tier = "Journeyman", cat = "Textiles", mf = 10, items = { {2592, 40} } },
  { tier = "Journeyman", cat = "Textiles", mf = 10, items = { {4306, 40} } },
  { tier = "Journeyman", cat = "Textiles", mf = 10, items = { {2319, 20} } },
  { tier = "Journeyman", cat = "Ore",      mf = 10, items = { {2775, 10}, {2772, 20} } },

  { tier = "Expert",     cat = "Textiles", mf = 15, items = { {4338, 40} } },
  { tier = "Expert",     cat = "Textiles", mf = 15, items = { {4234, 20} } },
  { tier = "Expert",     cat = "Ore",      mf = 15, items = { {2776, 10}, {3858, 20} } },
  { tier = "Expert",     cat = "Fabrics",  mf = 30, items = { {4339, 8}, {4236, 2} } },
  { tier = "Expert",     cat = "Ingots",   mf = 30, items = { {3860, 20} } },
  { tier = "Expert",     cat = "Ingots",   mf = 30, items = { {3859, 15} } },
  { tier = "Expert",     cat = "Ingots",   mf = 30, items = { {3577, 10} } },

  { tier = "Artisan",    cat = "Textiles", mf = nil, items = { {14047, 40} } },
  { tier = "Artisan",    cat = "Textiles", mf = nil, items = { {4304, 20} } },
  { tier = "Artisan",    cat = "Textiles", mf = nil, items = { {8170, 20} } },
}

-- Recipes bought with Merchant's Favor that we're saving toward.
-- Some also need Durotar Supply and Logistics reputation.
CM.targets = {
  { name = "Elixir of the Grizzly",        mf = 240, who = "Frostbone" },
  { name = "Major Frenzy Potion",          mf = 240, who = "Frostbone" },
  { name = "Elixir of Greater Fortitude",  mf = 120, who = "Frostbone" },
  { name = "Leatherworking set piece (Honored)",  mf = 90, who = "Tahnu" },
  { name = "Leatherworking set piece (Friendly)", mf = 60, who = "Tahnu" },
}
