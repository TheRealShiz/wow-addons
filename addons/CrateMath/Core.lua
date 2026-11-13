-- CrateMath: price Waylaid Crate bundles in gold per Merchant's Favor.
--
--   /cm            cheapest bundles, ranked by gold per MF
--   /cm targets    gold cost of the MF recipes we're saving toward
--   /cm check      verify that the item IDs in Data.lua are right
--   /cm source X   set the TSM price string (default below)
--   /cm log        how many crate and writ tooltips have been recorded
--
-- Tooltips: hovering a Waylaid Crate (bags or Auction House) adds the
-- cheapest way to fill it. Crate and Craftsman's Writ tooltips are saved to
-- CrateMathDB so we learn what they really ask for.

local ADDON, CM = ...

local DEFAULT_SOURCE = "first(DBMinBuyout, DBMarket, DBRegionMarketAvg)"

local db

local function say(msg)
  print("|cff33ccffCrateMath|r: " .. msg)
end

local function money(copper)
  if not copper then return "|cff888888no price|r" end
  copper = math.floor(copper + 0.5)
  if GetMoneyString then return GetMoneyString(copper, true) end
  return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

---------------------------------------------------------------- prices

-- Price of one unit in copper, or nil. TSM first, then Auctionator.
function CM.price(id)
  if TSM_API and TSM_API.GetCustomPriceValue then
    local ok, v = pcall(TSM_API.GetCustomPriceValue, db.source, "i:" .. id)
    if ok and v and v > 0 then return v end
  end
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.GetAuctionPriceByItemID then
    local ok, v = pcall(api.GetAuctionPriceByItemID, ADDON, id)
    if ok and v and v > 0 then return v end
  end
  return nil
end

-- Total cost of a bundle in copper, or nil if any item has no price.
function CM.bundleCost(b)
  local total = 0
  for _, it in ipairs(b.items) do
    local p = CM.price(it[1])
    if not p then return nil end
    total = total + p * it[2]
  end
  return total
end

function CM.bundleLabel(b)
  local parts = {}
  for _, it in ipairs(b.items) do
    parts[#parts + 1] = it[2] .. " " .. (CM.items[it[1]] or ("item " .. it[1]))
  end
  return table.concat(parts, " + ")
end

-- All bundles with a known MF value and a price, cheapest gold-per-MF first.
function CM.ranked()
  local out = {}
  for _, b in ipairs(CM.bundles) do
    local cost = CM.bundleCost(b)
    if cost and b.mf then
      out[#out + 1] = { b = b, cost = cost, perMF = cost / b.mf }
    end
  end
  table.sort(out, function(a, z) return a.perMF < z.perMF end)
  return out
end

---------------------------------------------------------------- commands

local function cmdRank()
  local r = CM.ranked()
  if #r == 0 then
    say("no prices yet. Is TSM (with its app data) or Auctionator loaded? Try /cm check.")
    return
  end
  say("cheapest Merchant's Favor (gold per MF, then bundle cost):")
  for i, e in ipairs(r) do
    if i > 10 then break end
    print(string.format("  %2d. %s per MF - %s %s: %s (%s for %d MF)",
      i, money(e.perMF), e.b.tier, e.b.cat, CM.bundleLabel(e.b), money(e.cost), e.b.mf))
  end
  local unknown = 0
  for _, b in ipairs(CM.bundles) do if not b.mf then unknown = unknown + 1 end end
  if unknown > 0 then
    print(string.format("  (%d bundles skipped: MF reward not known yet)", unknown))
  end
end

local function cmdTargets()
  local r = CM.ranked()
  local best = r[1]
  if not best then say("no prices yet - see /cm") return end
  say(string.format("recipe costs at the best rate (%s per MF, %s %s):",
    money(best.perMF), best.b.tier, best.b.cat))
  for _, t in ipairs(CM.targets) do
    print(string.format("  %s (%s): %d MF = %s",
      t.name, t.who, t.mf, money(best.perMF * t.mf)))
  end
  print("  Rate assumes you can turn in crates of that tier. Reputation not included.")
end

local function cmdCheck()
  local bad, pending, noPrice = 0, 0, 0
  for id, expected in pairs(CM.items) do
    local name = C_Item.GetItemNameByID(id)
    if not name then
      pending = pending + 1
      C_Item.RequestLoadItemDataByID(id)
    elseif name ~= expected then
      bad = bad + 1
      say(string.format("item %d is \"%s\", expected \"%s\"", id, name, expected))
    end
    if not CM.price(id) then noPrice = noPrice + 1 end
  end
  if pending > 0 then
    say(pending .. " items still loading from the server - run /cm check again in a few seconds.")
  elseif bad == 0 then
    say("all item IDs match.")
  end
  if noPrice > 0 then say(noPrice .. " items have no price yet.") end
  say("price source: " .. (TSM_API and ("TSM (" .. db.source .. ")") or "none")
    .. ((Auctionator and Auctionator.API) and ", Auctionator fallback" or ""))
end

local function cmdLog()
  local c, w = 0, 0
  for _ in pairs(db.crates) do c = c + 1 end
  for _ in pairs(db.writs) do w = w + 1 end
  say(string.format("recorded %d crate and %d writ tooltips (saved on logout/reload).", c, w))
end

SLASH_CRATEMATH1 = "/cm"
SLASH_CRATEMATH2 = "/cratemath"
SlashCmdList.CRATEMATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "" or cmd == "rank" then cmdRank()
  elseif cmd == "targets" then cmdTargets()
  elseif cmd == "check" then cmdCheck()
  elseif cmd == "log" then cmdLog()
  elseif cmd == "source" then
    if rest == "" then say("price source: " .. db.source)
    else db.source = rest; say("price source set to: " .. rest) end
  else
    say("/cm, /cm targets, /cm check, /cm log, /cm source <TSM price string>")
  end
end

---------------------------------------------------------------- tooltips

local function tooltipLines(data)
  local lines = {}
  for _, line in ipairs(data.lines or {}) do
    if line.leftText and line.leftText ~= "" then lines[#lines + 1] = line.leftText end
  end
  return lines
end

local function record(store, name, lines)
  local e = store[name]
  if not e then
    store[name] = { lines = lines, seen = 1, first = time() }
  else
    e.seen = e.seen + 1
    e.lines = lines
  end
end

-- Bundles whose every item name appears somewhere in the crate's tooltip.
local function bundlesInTooltip(text)
  local hits = {}
  for _, b in ipairs(CM.bundles) do
    local all = true
    for _, it in ipairs(b.items) do
      local n = CM.items[it[1]]
      if not n or not text:find(n, 1, true) then all = false break end
    end
    if all then hits[#hits + 1] = b end
  end
  return hits
end

local function onItemTooltip(tooltip, data)
  if not data or not data.id then return end
  local name = C_Item.GetItemNameByID(data.id)
  if not name then return end

  if name:find("Writ", 1, true) then
    record(db.writs, name, tooltipLines(data))
    return
  end
  if not name:find("Waylaid", 1, true) then return end

  local lines = tooltipLines(data)
  record(db.crates, name, lines)

  local hits = bundlesInTooltip(table.concat(lines, "\n"))
  local best, bestCost
  for _, b in ipairs(hits) do
    local c = CM.bundleCost(b)
    if c and (not bestCost or c < bestCost) then best, bestCost = b, c end
  end

  tooltip:AddLine(" ")
  if best then
    tooltip:AddDoubleLine("|cff33ccffCrateMath|r cheapest fill", money(bestCost), 1, 1, 1, 1, 1, 1)
    tooltip:AddLine(CM.bundleLabel(best), 0.8, 0.8, 0.8, true)
    if best.mf then
      tooltip:AddDoubleLine("Merchant's Favor", best.mf .. " (" .. money(bestCost / best.mf) .. " per MF)",
        0.8, 0.8, 0.8, 1, 1, 1)
    end
  elseif #hits > 0 then
    tooltip:AddLine("|cff33ccffCrateMath|r: no prices for this crate's bundles yet", 0.8, 0.8, 0.8)
  else
    tooltip:AddLine("|cff33ccffCrateMath|r: unknown bundle list (recorded - see /cm log)", 0.8, 0.8, 0.8)
  end
end

---------------------------------------------------------------- startup

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
  if name ~= ADDON then return end
  CrateMathDB = CrateMathDB or {}
  db = CrateMathDB
  db.source = db.source or DEFAULT_SOURCE
  db.crates = db.crates or {}
  db.writs = db.writs or {}
  if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
      local ok, err = pcall(onItemTooltip, tt, data)
      if not ok and db.debug then say("tooltip error: " .. tostring(err)) end
    end)
  end
  f:UnregisterEvent("ADDON_LOADED")
end)
