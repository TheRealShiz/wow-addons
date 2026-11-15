-- CrateMath: what it costs to fill a Waylaid Crate, in gold per Merchant's Favor.
--
--   /cm            crate types ranked by cheapest gold per MF
--   /cm bags       crates in your bags: best fill, and what you can fill now
--   /cm targets    gold cost of the MF recipes we're saving toward
--   /cm check      verify the item IDs in Data.lua against the game
--   /cm log        what has been recorded (crate/writ tooltips, MF gains)
--   /cm source X   set the TSM price string (default below)
--
-- Hovering a Waylaid Crate (bags, bank, Auction House) shows its MF reward,
-- the cheapest fill, which options your bags + bank already cover, and the
-- crate's own market value. Crate and writ tooltips and Merchant's Favor
-- gains are saved to CrateMathDB so the data can be corrected from real play.

local ADDON, CM = ...

local DEFAULT_SOURCE = "first(DBMinBuyout, DBMarket, DBRegionMarketAvg)"
local PREFIX = "Waylaid Crate: "

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

local function itemName(id)
  return CM.items[id] or C_Item.GetItemNameByID(id) or ("item " .. id)
end

---------------------------------------------------------------- prices, counts

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

-- How many you own on this character, bags + bank.
function CM.have(id)
  local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not fn then return 0 end
  local ok, n = pcall(fn, id, true)
  return (ok and n) or 0
end

-- Crate definition from an item name, or nil if it isn't a known crate type.
function CM.crateFor(name)
  if not name or name:sub(1, #PREFIX) ~= PREFIX then return nil end
  return CM.crates[name:sub(#PREFIX + 1)], name:sub(#PREFIX + 1)
end

-- Every option of a crate with cost and owned count, cheapest first.
-- Unpriced options sort last.
function CM.options(crate)
  local out = {}
  for _, o in ipairs(crate.opts) do
    local id, qty = o[1], o[2]
    local p = CM.price(id)
    local have = CM.have(id)
    out[#out + 1] = {
      id = id, qty = qty, cost = p and p * qty,
      have = have, canFill = have >= qty,
    }
  end
  table.sort(out, function(a, z)
    if a.cost and z.cost then return a.cost < z.cost end
    return a.cost ~= nil
  end)
  return out
end

-- Cheapest priced option, and cheapest option you can fill from bags + bank.
function CM.best(crate)
  local opts = CM.options(crate)
  local cheapest, fillable
  for _, o in ipairs(opts) do
    if o.cost and not cheapest then cheapest = o end
    if o.canFill and not fillable then fillable = o end
  end
  return cheapest, fillable, opts
end

local function optLabel(o)
  return o.qty .. " " .. itemName(o.id)
end

local function playerLevel()
  return (UnitLevel and UnitLevel("player")) or 60
end

-- All crate types with a known MF reward and a price, cheapest gold per MF first.
function CM.ranked(usableOnly)
  local lvl = playerLevel()
  local out = {}
  for key, c in pairs(CM.crates) do
    if c.mf and (not usableOnly or lvl >= c.level) then
      local cheapest = CM.best(c)
      if cheapest then
        out[#out + 1] = { key = key, c = c, o = cheapest, perMF = cheapest.cost / c.mf }
      end
    end
  end
  table.sort(out, function(a, z) return a.perMF < z.perMF end)
  return out
end

---------------------------------------------------------------- commands

local function cmdRank()
  local r = CM.ranked(false)
  if #r == 0 then
    say("no prices yet. Is TSM (with its app data) or Auctionator loaded? Try /cm check.")
    return
  end
  local lvl = playerLevel()
  say("cheapest Merchant's Favor by crate type (gold per MF):")
  for i, e in ipairs(r) do
    if i > 12 then break end
    local lock = lvl < e.c.level and string.format(" |cffff5555(level %d)|r", e.c.level) or ""
    print(string.format("  %2d. %s per MF - %s: %s = %s for %d MF%s",
      i, money(e.perMF), e.key, optLabel(e.o), money(e.o.cost), e.c.mf, lock))
  end
end

-- Crates in your bags.
local function bagCrates()
  local found = {}
  if not C_Container then return found end
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        local name = C_Item.GetItemNameByID(info.itemID)
        local crate, key = CM.crateFor(name)
        if crate then
          local e = found[key]
          if e then e.n = e.n + (info.stackCount or 1)
          else found[key] = { key = key, c = crate, id = info.itemID, n = info.stackCount or 1 } end
        elseif name and name:find("Waylaid", 1, true) then
          found[name] = { key = name, n = info.stackCount or 1 }
        end
      end
    end
  end
  return found
end

local function cmdBags()
  local found = bagCrates()
  local any = false
  local lvl = playerLevel()
  for _, e in pairs(found) do
    any = true
    if not e.c then
      print(string.format("  %dx %s: unknown crate type (hover it once so it gets recorded)", e.n, e.key))
    else
      local cheapest, fillable = CM.best(e.c)
      local head = string.format("  %dx %s (%s MF%s)", e.n, e.key, e.c.mf or "?",
        lvl < e.c.level and string.format(", |cffff5555level %d|r", e.c.level) or "")
      print(head)
      if fillable then
        print(string.format("      |cff55ff55fill now|r with %s (you have %d)", optLabel(fillable), fillable.have))
      end
      if cheapest and cheapest ~= fillable then
        print(string.format("      cheapest to buy: %s = %s", optLabel(cheapest), money(cheapest.cost)))
      end
      local cv = CM.price(e.id)
      if cv then print("      crate sells for " .. money(cv)) end
    end
  end
  if not any then say("no Waylaid Crates in your bags.") end
end

local function cmdTargets()
  local r = CM.ranked(true)
  local best = r[1]
  if not best then say("no priced crate types you can use yet - see /cm") return end
  say(string.format("recipe costs at your best rate (%s per MF, %s):", money(best.perMF), best.key))
  for _, t in ipairs(CM.targets) do
    print(string.format("  %s (%s): %d MF = %s", t.name, t.who, t.mf, money(best.perMF * t.mf)))
  end
  print("  Rate is materials only, at your current level. Reputation not included.")
end

local function cmdCheck()
  local bad, pending, noPrice, total = 0, 0, 0, 0
  for id, expected in pairs(CM.items) do
    total = total + 1
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
    say("all " .. total .. " item IDs match.")
  end
  if noPrice > 0 then say(noPrice .. " of " .. total .. " items have no price yet (normal for high-level mats).") end
  say("price source: " .. (TSM_API and ("TSM (" .. db.source .. ")") or "none")
    .. ((Auctionator and Auctionator.API) and ", Auctionator fallback" or ""))
end

local function cmdLog()
  local c, w, unknown = 0, 0, 0
  for name in pairs(db.crates) do
    c = c + 1
    if not CM.crateFor(name) then unknown = unknown + 1 end
  end
  for _ in pairs(db.writs) do w = w + 1 end
  say(string.format("recorded %d crate types (%d not in Data.lua), %d writs, %d Merchant's Favor gains. Saved on logout or /reload.",
    c, unknown, w, #db.mfGains))
end

SLASH_CRATEMATH1 = "/cm"
SLASH_CRATEMATH2 = "/cratemath"
SlashCmdList.CRATEMATH = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "" or cmd == "rank" then cmdRank()
  elseif cmd == "bags" then cmdBags()
  elseif cmd == "targets" then cmdTargets()
  elseif cmd == "check" then cmdCheck()
  elseif cmd == "log" then cmdLog()
  elseif cmd == "source" then
    if rest == "" then say("price source: " .. db.source)
    else db.source = rest; say("price source set to: " .. rest) end
  else
    say("/cm, /cm bags, /cm targets, /cm check, /cm log, /cm source <TSM price string>")
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

local function record(store, name, id, lines)
  local e = store[name]
  if not e then
    store[name] = { id = id, lines = lines, seen = 1, first = time() }
  else
    e.seen = e.seen + 1
    e.id = id
    e.lines = lines
  end
end

local function onItemTooltip(tooltip, data)
  if not data or not data.id then return end
  local name = C_Item.GetItemNameByID(data.id)
  if not name then return end

  if name:find("Writ", 1, true) then
    record(db.writs, name, data.id, tooltipLines(data))
    return
  end
  if not (name:find("Waylaid", 1, true) or name:find("Sealed", 1, true)) then return end
  record(db.crates, name, data.id, tooltipLines(data))

  local crate = CM.crateFor(name)
  tooltip:AddLine(" ")
  if not crate then
    tooltip:AddLine("|cff33ccffCrateMath|r: crate type not in Data.lua (recorded)", 0.8, 0.8, 0.8)
    return
  end

  local cheapest, fillable = CM.best(crate)
  local W, G = 0.8, 1
  tooltip:AddDoubleLine("|cff33ccffCrateMath|r", (crate.mf and (crate.mf .. " Merchant's Favor") or "MF unknown"),
    1, 1, 1, 1, 1, 1)
  if playerLevel() < crate.level then
    tooltip:AddLine("Needs level " .. crate.level, 1, 0.33, 0.33)
  end
  if fillable then
    tooltip:AddDoubleLine("Fill now: " .. optLabel(fillable), "have " .. fillable.have, 0.33, 1, 0.33, 0.33, 1, 0.33)
  end
  if cheapest then
    local per = crate.mf and ("  (" .. money(cheapest.cost / crate.mf) .. "/MF)") or ""
    tooltip:AddDoubleLine("Cheapest: " .. optLabel(cheapest), money(cheapest.cost) .. per, W, W, W, G, G, G)
  else
    tooltip:AddLine("No prices for this crate's options yet", W, W, W)
  end
  local cv = CM.price(data.id)
  if cv then
    tooltip:AddDoubleLine("Crate market value", money(cv), W, W, W, G, G, G)
    if cheapest and crate.mf then
      tooltip:AddDoubleLine("MF cost incl. crate", money((cv + cheapest.cost) / crate.mf) .. "/MF", W, W, W, G, G, G)
    end
  end
end

---------------------------------------------------------------- MF gains

-- Log every Merchant's Favor gain, so real rewards (Artisan crates, writs,
-- first-label bonus) can be checked against Data.lua.
local function onCurrency(currencyID, quantity, change)
  if not currencyID or not change or change == 0 then return end
  local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID)
  if not info or not info.name or not info.name:find("Merchant", 1, true) then return end
  db.mfCurrencyID = currencyID
  table.insert(db.mfGains, { t = time(), change = change, total = quantity })
  while #db.mfGains > 500 do table.remove(db.mfGains, 1) end
end

---------------------------------------------------------------- startup

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, a1, a2, a3)
  if event == "CURRENCY_DISPLAY_UPDATE" then
    pcall(onCurrency, a1, a2, a3)
    return
  end
  if a1 ~= ADDON then return end
  CrateMathDB = CrateMathDB or {}
  db = CrateMathDB
  db.source = db.source or DEFAULT_SOURCE
  db.crates = db.crates or {}
  db.writs = db.writs or {}
  db.mfGains = db.mfGains or {}
  if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
      local ok, err = pcall(onItemTooltip, tt, data)
      if not ok and db.debug then say("tooltip error: " .. tostring(err)) end
    end)
  end
  f:UnregisterEvent("ADDON_LOADED")
  f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
end)
