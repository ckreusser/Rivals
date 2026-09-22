local _, DP = ...
local U = {items = {}}
local racialSpells = {[20572]=true, [20594]=true, [7744]=true, [20549]=true,
    [26296]=true, [26297]=true, [20554]=true, [20580]=true, [20600]=true,
    [20577]=true, [20589]=true}
local colors = {[0]="9d9d9d", [1]="ffffff", [2]="1eff00", [3]="0070dd", [4]="a335ee", [5]="ff8000"}
U.sections = {{"potions", "Potions/Consumables:"}, {"engineering", "Engineering Gadgets:"}, {"equipment", "Equipment:"},
    {"cooldowns", "Cooldowns (≥3 min):"}, {"racials", "Racials:"}}

-- Several Classic Era PvP insignias share generic effect spell names. Resolve
-- the faction/class-specific trinket instead of displaying the internal spell.
local insigniaItems = {
    Horde = {WARRIOR = 18834, HUNTER = 18846, SHAMAN = 18845},
    Alliance = {WARRIOR = 18854, HUNTER = 18856},
}

local function ResolveInsignia(spellID, session)
    if spellID ~= 5579 then return nil end -- Immune Root/Snare/Stun
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local class = session and session.identity and session.identity.class
    local itemID = faction and class and insigniaItems[faction] and insigniaItems[faction][class] or nil
    return {
        itemID = itemID,
        name = faction == "Alliance" and "Insignia of the Alliance" or "Insignia of the Horde",
        quality = 3,
        category = "equipment",
        forceItem = true,
    }
end

local engineeringTerms = {
    "grenade", "dynamite", "bomb", "rocket", "gnomish", "goblin", "target dummy",
    "discombobulator", "recombobulator", "reflector", "dragonling", "flame deflector",
    "sapper charge", "alarm-o-bot", "battle chicken", "jumper cables", "land mine",
    "seaforium", "deflector", "harvest reaper", "mechanical"
}

local function EngineeringCategory(name)
    local lower = type(name) == "string" and name:lower() or ""
    for _, term in ipairs(engineeringTerms) do
        if lower:find(term, 1, true) then return "engineering" end
    end
end

local function ItemInfo(id)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not get then return end
    return get(id)
end
local function Catalog(spell) return DP.UsageCatalog and DP.UsageCatalog[spell] end
local function PlainCategory(title) return (title or ""):gsub(":$", "") end
local function DisplayCategory(title)
    local plain = PlainCategory(title)
    if plain == "Engineering Gadgets" then return "Engineering\nGadgets" end
    return plain
end
local function ShortName(name)
    if type(name) ~= "string" or name == "" then return "Opponent" end
    return name:match("^([^-]+)") or name
end
local function SideText(entries)
    if not entries or #entries == 0 then return "|cff777f8c—|r" end
    local lines = {}
    for _, entry in ipairs(entries) do lines[#lines + 1] = entry.text end
    return table.concat(lines, "\n")
end

function U.Item(id)
    local name, link, quality, _, _, _, _, _, equip, _, _, class = ItemInfo(id)
    local category = class and (class == 0 and "potions" or "equipment") or nil
    category = EngineeringCategory(name) or category
    return {itemID=id, name=name, quality=quality, category=category}
end
DP.Usage = U

-- Use spells are learned from actual carried/equipped items, never from
-- ability-name guesses. Multiple items can legitimately share one activation
-- spell (for example Horned Viking Helmet and Goblin Rocket Helmet both cast
-- Reckless Charge), so never let a bag scan overwrite the equipped identity.
local function AddScannedItem(bySpell, spell, id, equipSlot, bag, bagSlot)
    if type(spell) ~= "number" or not id then return end
    local candidate = U.Item(id)
    candidate.equipSlot, candidate.bag, candidate.bagSlot = equipSlot, bag, bagSlot
    local current = bySpell[spell]
    if not current then
        bySpell[spell] = candidate
        return
    end
    if current.itemID == id then
        if equipSlot then current.equipSlot = equipSlot end
        return
    end
    local list = current.candidates
    if not list then
        list = {current}
        current = {candidates = list, sharedSpell = true}
        bySpell[spell] = current
    end
    for _, existing in ipairs(list) do
        if existing.itemID == id then
            if equipSlot then existing.equipSlot = equipSlot end
            return
        end
    end
    list[#list + 1] = candidate
end

function U.Scan()
    local itemSpell = C_Item and C_Item.GetItemSpell or GetItemSpell
    if not itemSpell then return end
    local scanned = {}
    local function Add(id, equipSlot, bag, bagSlot)
        if not id then return end
        local name, spell = itemSpell(id)
        if type(spell) == "number" and type(name) == "string" then
            AddScannedItem(scanned, spell, id, equipSlot, bag, bagSlot)
        end
    end
    if GetInventoryItemID then
        for slot = 1, 19 do Add(GetInventoryItemID("player", slot), slot) end
    end
    local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local item = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    if slots and item then
        for bag = 0, 4 do
            for slot = 1, slots(bag) do Add(item(bag, slot), nil, bag, slot) end
        end
    end
    U.items = scanned
end

local function ResolvePlayerItem(spellID)
    local scanned = U.items[spellID]
    if not scanned then return nil end
    if not scanned.candidates then return scanned end

    -- On-use armor/trinkets must be equipped when activated. Re-check the live
    -- inventory at the combat-log event instead of trusting scan order or stale
    -- bag state. This makes shared effects resolve to the item actually worn.
    local equipped
    if GetInventoryItemID then
        for _, candidate in ipairs(scanned.candidates) do
            if candidate.equipSlot and GetInventoryItemID("player", candidate.equipSlot) == candidate.itemID then
                if equipped then
                    -- More than one matching candidate is equipped. Rare, but do
                    -- not invent an identity if the spell itself cannot distinguish them.
                    return nil, true
                end
                equipped = candidate
            end
        end
    end
    if equipped then return equipped end

    -- A shared spell with no uniquely equipped source is genuinely ambiguous.
    -- Prefer no item claim over silently choosing whichever candidate was scanned last.
    return nil, true
end

local function UsageEntryKey(spellID, item)
    local base = tostring(spellID)
    if type(item) == "table" and item.itemID then
        local known = Catalog(spellID)
        local scanned = U.items[spellID]
        -- Shared activation spells need one record per actual item identity.
        -- Otherwise using two different items with the same spell collapses into
        -- a single x2 entry carrying whichever item happened to be seen first.
        if (known and known.ambiguous) or (scanned and scanned.sharedSpell) then
            return base .. ":" .. tostring(item.itemID)
        end
    end
    return base
end

function U.Begin(session)
    if not session then return end
    if not session.usage then session.usage = {version = 1, player = {}, opponent = {}} end
    if not session.combatLog then
        session.combatLog = {version = 1, myActions = {}, toMe = {}, myTruncated = false, toMeTruncated = false}
    end
end

function U.Observe(session, playerGUID, now, event, sourceGUID, spellID, spellName, baseCooldown)
    local usageStart = session and (session.acceptedAt or session.estimatedStartAt)
    if not session or session.excluded or not usageStart or
        now < usageStart or session.finishedAt or event ~= "SPELL_CAST_SUCCESS" then return end
    local side = sourceGUID == playerGUID and "player" or
        (session.identity and sourceGUID == session.identity.guid and "opponent")
    if not side or type(spellID) ~= "number" then return end
    local item, ambiguous
    if side == "player" then
        item, ambiguous = ResolvePlayerItem(spellID)
        if not item and not ambiguous then item = Catalog(spellID) end
    else
        item = ResolveInsignia(spellID, session) or Catalog(spellID)
    end
    local long = type(baseCooldown) == "number" and baseCooldown >= 180000
    if not item and ambiguous then
        local known = Catalog(spellID)
        item = known or {name = spellName or ("Spell " .. spellID), category = "equipment", ambiguous = true}
    end
    if not item and not long and not racialSpells[spellID] then return end
    U.Begin(session)
    local entries = session.usage[side]
    local key = UsageEntryKey(spellID, item)
    if not entries[key] then
        local count = 0
        for _ in pairs(entries) do count = count + 1 end
        if count >= 64 then return end
        entries[key] = {spellID = spellID, name = spellName or (type(item) == "string" and item) or ("Spell " .. spellID),
            kind = item and "item" or racialSpells[spellID] and "racial" or "cooldown",
            itemID = type(item) == "table" and item.itemID or nil,
            itemName = type(item) == "table" and item.name or nil,
            quality = type(item) == "table" and item.quality or nil,
            category = type(item) == "table" and item.category or nil, cooldown = long and baseCooldown / 1000 or nil,
            observedAt = now, count = 0}
    end
    entries[key].count = entries[key].count + 1
end

local COMBAT_LOG_LIMIT = 120

local function CombatActor(name, fallback)
    local short = ShortName(name)
    return short == "Opponent" and (fallback or "Opponent") or short
end

local function CombatSpell(name, id)
    return name or (id and ("Spell " .. id)) or "Unknown"
end

local function CombatAmount(value)
    return type(value) == "number" and tostring(math.floor(value + .5)) or "?"
end

local function AppendCombat(session, key, text, elapsed)
    U.Begin(session)
    local log = session.combatLog
    local list = log[key]
    if #list >= COMBAT_LOG_LIMIT then
        log[key == "myActions" and "myTruncated" or "toMeTruncated"] = true
        return
    end
    list[#list + 1] = {t = math.max(0, elapsed or 0), text = text}
end

local function MyCombatText(event, info)
    local target = CombatActor(info[9], "target")
    if event == "SWING_DAMAGE" then return "Melee hit " .. target .. " for " .. CombatAmount(info[12]) end
    if event == "SWING_MISSED" then return "Melee missed " .. target .. " (" .. tostring(info[12] or "miss") .. ")" end
    if event == "ENVIRONMENTAL_DAMAGE" then return nil end
    if event:find("^SPELL_") or event:find("^RANGE_") then
        local spell = CombatSpell(info[13], info[12])
        if event == "SPELL_CAST_SUCCESS" then return "Cast " .. spell .. (info[9] and (" on " .. target) or "") end
        if event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" then
            return spell .. " hit " .. target .. " for " .. CombatAmount(info[15])
        end
        if event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
            return spell .. " healed " .. target .. " for " .. CombatAmount(info[15])
        end
        if event == "SPELL_MISSED" or event == "RANGE_MISSED" then
            return spell .. " missed " .. target .. " (" .. tostring(info[15] or "miss") .. ")"
        end
        if event == "SPELL_AURA_APPLIED" then return "Applied " .. spell .. " to " .. target end
        if event == "SPELL_AURA_REMOVED" then return spell .. " faded from " .. target end
        if event == "SPELL_AURA_REFRESH" then return "Refreshed " .. spell .. " on " .. target end
        if event == "SPELL_INTERRUPT" then
            return spell .. " interrupted " .. target .. "'s " .. CombatSpell(info[16], info[15])
        end
        if event == "SPELL_DISPEL" or event == "SPELL_STOLEN" then
            return spell .. " removed " .. CombatSpell(info[16], info[15]) .. " from " .. target
        end
        if event == "SPELL_ENERGIZE" then return spell .. " restored " .. CombatAmount(info[15]) .. " resource" end
    end
end

local function IncomingCombatText(event, info)
    local source = CombatActor(info[5], "Opponent")
    if event == "SWING_DAMAGE" then return source .. " hit you for " .. CombatAmount(info[12]) end
    if event == "SWING_MISSED" then return source .. " missed you (" .. tostring(info[12] or "miss") .. ")" end
    if event == "ENVIRONMENTAL_DAMAGE" then return tostring(info[12] or "Environment") .. " hit you for " .. CombatAmount(info[13]) end
    if event:find("^SPELL_") or event:find("^RANGE_") then
        local spell = CombatSpell(info[13], info[12])
        if event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" then
            return source .. "'s " .. spell .. " hit you for " .. CombatAmount(info[15])
        end
        if event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
            return source .. "'s " .. spell .. " healed you for " .. CombatAmount(info[15])
        end
        if event == "SPELL_MISSED" or event == "RANGE_MISSED" then
            return source .. "'s " .. spell .. " missed you (" .. tostring(info[15] or "miss") .. ")"
        end
        if event == "SPELL_AURA_APPLIED" then return source .. " applied " .. spell .. " to you" end
        if event == "SPELL_AURA_REMOVED" then return spell .. " faded from you" end
        if event == "SPELL_AURA_REFRESH" then return source .. " refreshed " .. spell .. " on you" end
        if event == "SPELL_INTERRUPT" then
            return source .. "'s " .. spell .. " interrupted your " .. CombatSpell(info[16], info[15])
        end
        if event == "SPELL_DISPEL" or event == "SPELL_STOLEN" then
            return source .. "'s " .. spell .. " removed your " .. CombatSpell(info[16], info[15])
        end
        if event == "SPELL_ENERGIZE" then return source .. "'s " .. spell .. " restored " .. CombatAmount(info[15]) .. " resource" end
    end
end

function U.Combat(session, playerGUID)
    if not session or not CombatLogGetCurrentEventInfo then return end
    local info = {CombatLogGetCurrentEventInfo()}
    local event, sourceGUID, destGUID, spellID, spellName = info[2], info[4], info[8], info[12], info[13]
    local now = GetTime()

    -- Usage detection remains SPELL_CAST_SUCCESS based, but the threshold is now
    -- three minutes. The combat-log panes capture the broader event stream.
    if event == "SPELL_CAST_SUCCESS" then
        local cooldown
        if GetSpellBaseCooldown and spellID then cooldown = GetSpellBaseCooldown(spellID) end
        U.Observe(session, playerGUID, now, event, sourceGUID, spellID, spellName, cooldown)
    end

    if session.excluded or not session.estimatedStartAt or now < session.estimatedStartAt or session.finishedAt then return end
    if DP.Specs and DP.Specs.ObserveCombat then DP.Specs.ObserveCombat(session, info) end
    local elapsed = now - session.estimatedStartAt
    if sourceGUID == playerGUID then
        local text = MyCombatText(event, info)
        if text then AppendCombat(session, "myActions", text, elapsed) end
    end
    if destGUID == playerGUID and sourceGUID ~= playerGUID then
        local text = IncomingCombatText(event, info)
        if text then AppendCombat(session, "toMe", text, elapsed) end
    end
end


-- Open-world encounters have an arbitrary number of participants, so usage is
-- stored as a chronological event list instead of the duel-only player/opponent
-- pair. The detail dataframe can then filter by participant without adding more
-- and more horizontal columns for 1v2+ fights.
function U.WorldObserve(session, playerGUID, info)
    if not session or not session.worldPvP or type(info) ~= "table" or info[2] ~= "SPELL_CAST_SUCCESS" then return end
    local sourceGUID, sourceName, destGUID, destName = info[4], info[5], info[8], info[9]
    if not sourceGUID or not session.participants or not session.participants[sourceGUID] then return end
    local spellID, spellName = info[12], info[13]
    if type(spellID) ~= "number" then return end

    local item, ambiguous
    if sourceGUID == playerGUID then
        item, ambiguous = ResolvePlayerItem(spellID)
        if not item and not ambiguous then item = Catalog(spellID) end
    else
        item = Catalog(spellID)
    end
    local cooldown
    if GetSpellBaseCooldown then cooldown = GetSpellBaseCooldown(spellID) end
    local long = type(cooldown) == "number" and cooldown >= 180000
    if not item and ambiguous then
        item = Catalog(spellID) or {name = spellName or ("Spell " .. spellID), category = "equipment", ambiguous = true}
    end
    if not item and not long and not racialSpells[spellID] then return end

    local category = type(item) == "table" and item.category or nil
    local itemName = type(item) == "table" and item.name or nil
    category = EngineeringCategory(itemName) or category
    if not category then
        category = racialSpells[spellID] and "racials" or (item and "equipment" or "cooldowns")
    end
    session.worldUsage = session.worldUsage or {version = 1, events = {}}
    local events = session.worldUsage.events
    if #events >= 128 then session.worldUsage.truncated = true; return end
    events[#events + 1] = {
        t = math.max(0, GetTime() - (session.startedElapsed or GetTime())),
        guid = sourceGUID,
        actorName = sourceName,
        targetGUID = destGUID,
        targetName = destName,
        spellID = spellID,
        nameSpell = spellName,
        name = spellName or itemName or ("Spell " .. spellID),
        kind = item and "item" or racialSpells[spellID] and "racial" or "cooldown",
        itemID = type(item) == "table" and item.itemID or nil,
        itemName = itemName,
        quality = type(item) == "table" and item.quality or nil,
        category = category,
        cooldown = long and cooldown / 1000 or nil,
        count = 1,
    }
end

function U.Describe(entry, record)
    local known = ResolveInsignia(entry.spellID, record and record.session) or Catalog(entry.spellID)
    local id = entry.itemID or (known and known.itemID)
    local name, quality, itemClass
    -- Preserve multiple returns when resolving client item metadata.
    if id then
        local link, level, required, kind, subtype, stack, equip, icon, price
        name, link, quality, level, required, kind, subtype, stack, equip, icon, price, itemClass = ItemInfo(id)
    end
    name = name or entry.itemName or (known and known.name)
    quality = quality or entry.quality or (known and known.quality) or 1
    local category = entry.category or (known and known.category) or (itemClass and (itemClass == 0 and "potions" or "equipment"))
    category = EngineeringCategory(name) or category
    if not category then
        category = (entry.kind == "racial" or racialSpells[entry.spellID]) and "racials" or
            (entry.kind == "item" and "equipment" or "cooldowns")
    end
    local text
    if id or entry.kind == "item" or (known and known.forceItem) then
        text = "|cff" .. (colors[quality] or "ffffff") .. "[" .. (name or entry.name) .. "]|r"
    else
        text = entry.name or ("Spell " .. entry.spellID)
        if category == "cooldowns" and entry.cooldown then text = text .. string.format(" [%g min]", entry.cooldown / 60) end
    end
    if (entry.count or 1) > 1 then text = text .. " x" .. entry.count end
    return {text=text, category=category, itemID=id, spellID=entry.spellID}
end

function U.Groups(record)
    local usage = record.session and record.session.usage or {}
    local groups = {}
    for _, spec in ipairs(U.sections) do
        local group = {key=spec[1], title=spec[2], player={}, opponent={}}
        for _, side in ipairs({"player", "opponent"}) do
            for _, entry in pairs(usage[side] or {}) do
                local display = U.Describe(entry, record)
                if display.category == group.key then group[side][#group[side]+1] = display end
            end
            table.sort(group[side], function(a,b)
                if a.spellID ~= b.spellID then return a.spellID < b.spellID end
                local ai, bi = tonumber(a.itemID) or 0, tonumber(b.itemID) or 0
                if ai ~= bi then return ai < bi end
                return tostring(a.text or "") < tostring(b.text or "")
            end)
        end
        if #group.player + #group.opponent > 0 then groups[#groups+1] = group end
    end
    return groups
end

-- Legacy line representation remains available to exports/tests. History hover uses
-- the structured three-column table below instead of stacking Category > Side > Item.
function U.Tooltip(record)
    local lines = {}
    for _, group in ipairs(U.Groups(record)) do
        lines[#lines+1] = "|cffffce70" .. group.title .. "|r"
        for _, side in ipairs({"player", "opponent"}) do
            if #group[side] > 0 then
                lines[#lines+1] = side == "player" and "|cff79bdffYou|r" or "|cffffad66Opponent|r"
                for _, entry in ipairs(group[side]) do lines[#lines+1] = entry.text end
            end
        end
    end
    return lines
end

local function AddRule(parent, vertical)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(.42, .46, .52, .34)
    if vertical then rule:SetWidth(1) else rule:SetHeight(1) end
    return rule
end

local function CreateGridRow(parent, compact)
    local row = CreateFrame("Frame", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.category = row:CreateFontString(nil, "OVERLAY", compact and "GameFontNormalSmall" or "GameFontNormal")
    row.player = row:CreateFontString(nil, "OVERLAY", compact and "GameFontHighlightSmall" or "GameFontHighlight")
    row.opponent = row:CreateFontString(nil, "OVERLAY", compact and "GameFontHighlightSmall" or "GameFontHighlight")
    for _, label in ipairs({row.category, row.player, row.opponent}) do
        label:SetJustifyH("LEFT")
        if label.SetJustifyV then label:SetJustifyV("TOP") end
        if label.SetWordWrap then label:SetWordWrap(true) end
    end
    row.leftRule, row.rightRule, row.bottomRule = AddRule(row, true), AddRule(row, true), AddRule(row, false)
    return row
end

local function LayoutTextGrid(parent, rows, groups, width, categoryWidth, playerWidth, compact, originX, originY)
    originX, originY = originX or 0, originY or 0
    local opponentWidth = width - categoryWidth - playerWidth
    local lineHeight = compact and 16 or 20
    local pad = compact and 7 or 9
    local y = 0
    for index, group in ipairs(groups) do
        local row = rows[index]
        if not row then
            row = CreateGridRow(parent, compact)
            rows[index] = row
        end
        local count = math.max(1, #group.player, #group.opponent)
        local height = count * lineHeight + pad * 2
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", originX, -(originY + y)); row:SetSize(width, height)
        row.bg:SetColorTexture(.07, .085, .105, index % 2 == 0 and .72 or .43)
        row.category:ClearAllPoints(); row.category:SetPoint("TOPLEFT", pad, -pad)
        row.category:SetWidth(categoryWidth - pad * 2); row.category:SetText("|cffffce70" .. DisplayCategory(group.title) .. "|r")
        row.player:ClearAllPoints(); row.player:SetPoint("TOPLEFT", categoryWidth + pad, -pad)
        row.player:SetWidth(playerWidth - pad * 2); row.player:SetText(SideText(group.player))
        row.opponent:ClearAllPoints(); row.opponent:SetPoint("TOPLEFT", categoryWidth + playerWidth + pad, -pad)
        row.opponent:SetWidth(opponentWidth - pad * 2); row.opponent:SetText(SideText(group.opponent))
        row.leftRule:ClearAllPoints(); row.leftRule:SetPoint("TOPLEFT", categoryWidth, 0); row.leftRule:SetPoint("BOTTOMLEFT", categoryWidth, 0)
        row.rightRule:ClearAllPoints(); row.rightRule:SetPoint("TOPLEFT", categoryWidth + playerWidth, 0); row.rightRule:SetPoint("BOTTOMLEFT", categoryWidth + playerWidth, 0)
        row.bottomRule:ClearAllPoints(); row.bottomRule:SetPoint("BOTTOMLEFT", 0, 0); row.bottomRule:SetWidth(width)
        row:Show(); y = y + height
    end
    for index = #groups + 1, #rows do rows[index]:Hide() end
    return y
end

local function MakeSpecFont(parent, compact)
    local font = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    if font.GetFont and font.SetFont then
        local path, size, flags = font:GetFont()
        if path and size then font:SetFont(path, math.max(8, size - (compact and 1 or 0)), flags) end
    end
    if font.SetWordWrap then font:SetWordWrap(false) end
    return font
end

local function LayoutTableHeader(header, width, categoryWidth, playerWidth, compact)
    local height = compact and 24 or 30
    local pad = compact and 7 or 9
    header._width, header._categoryWidth, header._playerWidth, header._pad = width, categoryWidth, playerWidth, pad
    header:SetSize(width, height)
    header.category:ClearAllPoints(); header.category:SetPoint("LEFT", pad, 0)
    header.category:SetWidth(categoryWidth - pad * 2); header.category:SetJustifyH("LEFT")
    header.player:ClearAllPoints(); header.player:SetPoint("LEFT", categoryWidth + pad, 0)
    header.player:SetWidth(playerWidth - pad * 2); header.player:SetJustifyH("CENTER")
    header.opponent:ClearAllPoints(); header.opponent:SetPoint("LEFT", categoryWidth + playerWidth + pad, 0)
    header.opponent:SetWidth(width - categoryWidth - playerWidth - pad * 2); header.opponent:SetJustifyH("CENTER")
    if header.opponentSpec then header.opponentSpec:Hide() end
    header.leftRule:ClearAllPoints(); header.leftRule:SetPoint("TOPLEFT", categoryWidth, 0); header.leftRule:SetPoint("BOTTOMLEFT", categoryWidth, 0)
    header.rightRule:ClearAllPoints(); header.rightRule:SetPoint("TOPLEFT", categoryWidth + playerWidth, 0); header.rightRule:SetPoint("BOTTOMLEFT", categoryWidth + playerWidth, 0)
end

local function CreateTableHeader(parent, width, categoryWidth, playerWidth, compact)
    local header = CreateFrame("Frame", nil, parent)
    header.compact = compact
    local bg = header:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(header); bg:SetColorTexture(.055, .07, .09, .94)
    header.category = header:CreateFontString(nil, "OVERLAY", compact and "GameFontNormalSmall" or "GameFontNormal")
    header.player = header:CreateFontString(nil, "OVERLAY", compact and "GameFontNormalSmall" or "GameFontNormal")
    header.opponent = header:CreateFontString(nil, "OVERLAY", compact and "GameFontNormalSmall" or "GameFontNormal")
    header.opponentSpec = MakeSpecFont(header, compact)
    header.category:SetText("|cffffce70Category|r"); header.player:SetText("You")
    header.leftRule, header.rightRule = AddRule(header, true), AddRule(header, true)
    header.topRule = header:CreateTexture(nil, "ARTWORK"); header.topRule:SetColorTexture(.84, .58, .24, .95); header.topRule:SetHeight(1); header.topRule:SetPoint("TOPLEFT"); header.topRule:SetPoint("TOPRIGHT")
    header.bottomRule = header:CreateTexture(nil, "ARTWORK"); header.bottomRule:SetColorTexture(.84, .58, .24, .95); header.bottomRule:SetHeight(1); header.bottomRule:SetPoint("BOTTOMLEFT"); header.bottomRule:SetPoint("BOTTOMRIGHT")
    LayoutTableHeader(header, width, categoryWidth, playerWidth, compact)
    return header
end

local function StripColor(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text
end

local function MeasureText(fontString, text, fallbackPerCharacter)
    fontString:SetText(text or "")
    local width = fontString.GetStringWidth and fontString:GetStringWidth() or 0
    if not width or width <= 0 then width = #StripColor(text) * (fallbackPerCharacter or 7) end
    return width
end

local function MeasureMultiline(fontString, text, fallbackPerCharacter)
    text = tostring(text or "")
    local width = 0
    for line in string.gmatch(text, "([^\n]+)") do
        width = math.max(width, MeasureText(fontString, line, fallbackPerCharacter))
    end
    if width == 0 then width = MeasureText(fontString, text, fallbackPerCharacter) end
    return width
end

local function Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function ResolvedOpponent(record)
    local spec, profile
    if DP.Specs and DP.Specs.Resolve then spec, profile = DP.Specs.Resolve(record) end
    local identity = record and record.session and record.session.identity
    local class = identity and identity.class or (profile and profile.class)
    return spec, class, profile
end

local function OpponentSpecLabel(record)
    local spec, _, profile = ResolvedOpponent(record)
    if not spec or spec == "" then return nil end
    if profile and profile.source == "combat" then return spec .. ", inferred" end
    return spec
end

local function OpponentNamePlain(record, short)
    local name = record and record.opponent or "Unknown"
    return short and ShortName(name) or name
end

local function OpponentDisplayPlain(record, short)
    local name = OpponentNamePlain(record, short)
    local spec = OpponentSpecLabel(record)
    return spec and (name .. " (" .. spec .. ")") or name
end

local function OpponentNameColored(record, short)
    local name = OpponentNamePlain(record, short)
    local _, class = ResolvedOpponent(record)
    return class and DP.Theme and DP.Theme.ClassName and DP.Theme.ClassName(name, class) or ("|cffffad66" .. name .. "|r")
end

local function PlayerHeaderText(record)
    local class = record and record.playerClass
    if not class and UnitClass then local _, detected = UnitClass("player"); class = detected end
    if class and DP.Theme and DP.Theme.ClassName then return DP.Theme.ClassName("You", class) end
    return "You"
end

-- History is intentionally content-sized: each side gets only enough horizontal
-- room for its longest displayed item/ability (plus modest cell padding).
local function HistoryGridWidths(tip, groups, record)
    local category = MeasureMultiline(tip.measureCategory, "Category", 6.5)
    local player = MeasureMultiline(tip.measureValue, "You", 6.5)
    local opponent = MeasureMultiline(tip.measureValue, OpponentNamePlain(record, true), 6.5)
    for _, group in ipairs(groups) do
        category = math.max(category, MeasureMultiline(tip.measureCategory, DisplayCategory(group.title), 6.5))
        for _, entry in ipairs(group.player) do player = math.max(player, MeasureMultiline(tip.measureValue, entry.text, 6.5)) end
        for _, entry in ipairs(group.opponent) do opponent = math.max(opponent, MeasureMultiline(tip.measureValue, entry.text, 6.5)) end
    end
    category = Clamp(math.ceil(category + 18), 88, 132)
    player = Clamp(math.ceil(player + 18), 72, 205)
    opponent = Clamp(math.ceil(opponent + 18), 72, 205)
    local width = category + player + opponent
    if width < 272 then
        local extra = 272 - width
        player = player + math.floor(extra / 2)
        opponent = opponent + math.ceil(extra / 2)
        width = 272
    end
    return width, category, player
end

local function SetOpponentHeader(header, record)
    header.player:SetText(PlayerHeaderText(record))
    header.opponentSpec:Hide()
    header.opponentSpec:SetText("")

    local name = OpponentNameColored(record, true)
    header.opponent:SetText(name)

    local width = header._width or header:GetWidth()
    local categoryWidth = header._categoryWidth or 0
    local playerWidth = header._playerWidth or 0
    local pad = header._pad or 7
    local cellStart = categoryWidth + playerWidth
    local cellWidth = width - cellStart
    local nameWidth = header.opponent.GetStringWidth and header.opponent:GetStringWidth() or 60
    local x = cellStart + math.max(pad, (cellWidth - nameWidth) / 2)

    header.opponent:ClearAllPoints(); header.opponent:SetPoint("LEFT", header, "LEFT", x, 0)
    header.opponent:SetWidth(math.max(1, math.min(nameWidth + 1, cellWidth - pad * 2)))
    header.opponent:SetJustifyH("LEFT")
end

local function SetDetailSummaryTitle(window, record)
    local result = record.won and "|cff65e6adWin|r" or "|cffff8888Loss|r"
    window.summaryTitle:SetText(result .. "|cffffce70 vs |r")
    window.summaryOpponent:SetText(OpponentNameColored(record, false))

    window.summaryTitle:ClearAllPoints()
    window.summaryTitle:SetPoint("TOPLEFT", window, "TOPLEFT", 24, -34)
    window.summaryOpponent:ClearAllPoints()
    window.summaryOpponent:SetPoint("LEFT", window.summaryTitle, "RIGHT", 0, 0)

    local spec = OpponentSpecLabel(record)
    window.summarySpec:SetText(spec and ("|cff8f98a6(" .. spec .. ")|r") or "")
    window.summarySpec:ClearAllPoints()
    window.summarySpec:SetPoint("LEFT", window.summaryOpponent, "RIGHT", 2, -1)
    window.summarySpec:SetShown(spec and true or false)
end

-- History hover: a compact data-table instead of a deeply nested text list.
function U.ShowHistoryTooltip(owner, record, meta)
    if not record then return end
    if not U.historyTip then
        local tip = CreateFrame("Frame", "RivalsHistoryDuelTooltip", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        tip:SetFrameStrata("TOOLTIP"); tip:SetSize(360, 120)
        if tip.SetClampedToScreen then tip:SetClampedToScreen(true) end
        tip.bg = tip:CreateTexture(nil, "BACKGROUND"); tip.bg:SetPoint("TOPLEFT", 1, -1); tip.bg:SetPoint("BOTTOMRIGHT", -1, 1); tip.bg:SetColorTexture(.015, .02, .028, .97)
        tip.border = DP.Theme.Border(tip, 0, 0, 360, 120); tip.border:ClearAllPoints(); tip.border:SetAllPoints(tip); tip.border:EnableMouse(false)
        tip.title = tip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        if tip.title.SetWordWrap then tip.title:SetWordWrap(false) end
        tip.titleOpponent = tip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        if tip.titleOpponent.SetWordWrap then tip.titleOpponent:SetWordWrap(false) end
        tip.titleSpec = MakeSpecFont(tip, false)
        tip.date = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tip.meta = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tip.title:SetPoint("TOPLEFT", 12, -9); tip.title:SetJustifyH("LEFT")
        tip.date:SetPoint("TOPLEFT", 12, -32); tip.date:SetJustifyH("LEFT")
        tip.meta:SetPoint("TOPLEFT", 12, -50); tip.meta:SetJustifyH("LEFT")
        if tip.meta.SetJustifyV then tip.meta:SetJustifyV("TOP") end
        tip.header = CreateTableHeader(tip, 336, 120, 108, true)
        tip.rows = {}
        tip.footer = tip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tip.footer:SetJustifyH("LEFT")
        if tip.footer.SetJustifyV then tip.footer:SetJustifyV("TOP") end
        if tip.footer.SetWordWrap then tip.footer:SetWordWrap(true) end
        -- Invisible measuring strings use the exact fonts rendered in the compact table.
        tip.measureCategory = tip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tip.measureValue = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tip.measureCategory:SetAlpha(0); tip.measureValue:SetAlpha(0)
        U.historyTip = tip
    end
    local tip = U.historyTip
    local result = record.won and "|cff65e6adWin|r" or "|cffff8888Loss|r"
    tip.title:SetText(result .. "|cffffce70 vs |r")
    tip.titleOpponent:SetText(OpponentNameColored(record, false))
    local titleSpec = OpponentSpecLabel(record)
    tip.titleSpec:SetText(titleSpec and ("|cff8f98a6(" .. titleSpec .. ")|r") or "")
    tip.date:SetText("|cffadb5c2" .. date("%Y-%m-%d %H:%M:%S", record.timestamp) .. "|r")

    local outerPad = 12
    local sectionGap = 5
    local lineGap = 3

    local metaLines = {}
    if meta then
        local lead = {}
        if meta.mode then lead[#lead + 1] = meta.mode end
        if meta.duration then lead[#lead + 1] = meta.duration end
        if #lead > 0 then metaLines[#metaLines + 1] = "|cffd4d8df" .. table.concat(lead, "  •  ") .. "|r" end
        if meta.verificationNote and meta.verificationNote ~= "" then
            metaLines[#metaLines + 1] = "|cff9da6b5" .. meta.verificationNote .. "|r"
        end
        if meta.ratingSummary then
            for _, line in ipairs(meta.ratingSummary) do metaLines[#metaLines + 1] = line end
        else
            -- Backward-compatible fallback for callers from older builds.
            if meta.rating then
                local line = "|cff79bdffRating|r " .. meta.rating
                if meta.opponentRating then line = line .. "    |cffffad66Rival estimate|r " .. meta.opponentRating end
                metaLines[#metaLines + 1] = line
            end
            if meta.matchup then metaLines[#metaLines + 1] = meta.matchup end
            if meta.warning then metaLines[#metaLines + 1] = "|cff9da6b5" .. meta.warning .. "|r" end
        end
    end
    tip.meta:SetText(table.concat(metaLines, "\n"))
    local groups = U.Groups(record)
    local tableWidth, categoryWidth, playerWidth = HistoryGridWidths(tip, groups, record)
    local prefixWidth = (tip.title.GetUnboundedStringWidth and tip.title:GetUnboundedStringWidth()) or (tip.title.GetStringWidth and tip.title:GetStringWidth()) or 70
    local opponentWidth = (tip.titleOpponent.GetUnboundedStringWidth and tip.titleOpponent:GetUnboundedStringWidth()) or (tip.titleOpponent.GetStringWidth and tip.titleOpponent:GetStringWidth()) or 80
    local titleSpecWidth = titleSpec and ((tip.titleSpec.GetUnboundedStringWidth and tip.titleSpec:GetUnboundedStringWidth()) or (tip.titleSpec.GetStringWidth and tip.titleSpec:GetStringWidth()) or 0) or 0
    local specGap = 2
    local titleWidth = prefixWidth + opponentWidth + (titleSpec and (specGap + titleSpecWidth) or 0)
    local metaWidth = 0
    for _, line in ipairs(metaLines) do
        metaWidth = math.max(metaWidth, MeasureMultiline(tip.measureValue, StripColor(line), 6.5))
    end
    local contentWidth = math.max(tableWidth, math.min(520, math.ceil(math.max(titleWidth, metaWidth))))
    tip:SetWidth(contentWidth + outerPad * 2)
    tip.date:SetWidth(contentWidth); tip.meta:SetWidth(contentWidth); tip.footer:SetWidth(contentWidth)
    LayoutTableHeader(tip.header, tableWidth, categoryWidth, playerWidth, true)

    -- Do not position the spec from a measured X coordinate. Chain three
    -- unconstrained FontStrings so the spec is physically anchored to the
    -- rendered opponent name's RIGHT edge in the client.
    tip.title:ClearAllPoints(); tip.title:SetPoint("TOPLEFT", outerPad, -outerPad)
    tip.titleOpponent:ClearAllPoints(); tip.titleOpponent:SetPoint("LEFT", tip.title, "RIGHT", 0, 0)
    local titleHeight = math.max(
        math.ceil((tip.title.GetStringHeight and tip.title:GetStringHeight()) or 18),
        math.ceil((tip.titleOpponent.GetStringHeight and tip.titleOpponent:GetStringHeight()) or 18))
    if titleSpec then
        tip.titleSpec:ClearAllPoints(); tip.titleSpec:SetPoint("LEFT", tip.titleOpponent, "RIGHT", specGap, -1)
        tip.titleSpec:Show()
        titleHeight = math.max(titleHeight, math.ceil((tip.titleSpec.GetStringHeight and tip.titleSpec:GetStringHeight()) or 11))
    else
        tip.titleSpec:Hide()
    end
    tip.date:ClearAllPoints(); tip.date:SetPoint("TOPLEFT", outerPad, -(outerPad + titleHeight + lineGap))
    local dateHeight = math.ceil((tip.date.GetStringHeight and tip.date:GetStringHeight()) or 14)
    tip.meta:ClearAllPoints(); tip.meta:SetPoint("TOPLEFT", outerPad, -(outerPad + titleHeight + lineGap + dateHeight + lineGap))
    local metaHeight = math.max(0, math.ceil((tip.meta.GetStringHeight and tip.meta:GetStringHeight()) or (#metaLines * 15)))
    local tableTop = outerPad + titleHeight + lineGap + dateHeight + lineGap + metaHeight + sectionGap
    tip.header:ClearAllPoints(); tip.header:SetPoint("TOPLEFT", outerPad, -tableTop); SetOpponentHeader(tip.header, record)
    local bodyHeight = 0
    if #groups > 0 then
        bodyHeight = LayoutTextGrid(tip, tip.rows, groups, tableWidth, categoryWidth, playerWidth, true, outerPad, tableTop + 24)
    else
        for _, row in ipairs(tip.rows) do row:Hide() end
    end

    local footerY = tableTop + 24 + bodyHeight + 6
    local footer = meta and meta.footer or nil
    if #groups == 0 then
        footer = footer or "No item, cooldown, racial, or engineering gadget use recorded."
    end
    local footerLines = {}
    if footer and footer ~= "" then footerLines[#footerLines + 1] = "|cffadb5c2" .. footer .. "|r" end
    footerLines[#footerLines + 1] = "|cff8f98a6Click for additional details|r"
    local footerText = table.concat(footerLines, "\n")
    tip.footer:ClearAllPoints(); tip.footer:SetPoint("TOPLEFT", outerPad, -footerY)
    tip.footer:SetText(footerText)
    local footerHeight = tip.footer.GetStringHeight and math.ceil(tip.footer:GetStringHeight()) or (#footerLines * 14)
    local bottomPad = outerPad
    tip:SetHeight(footerY + footerHeight + bottomPad)
    tip.owner, tip.record, tip.historyMeta = owner, record, meta
    tip:ClearAllPoints(); tip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 8, 4); tip:Show()
end

function U.RefreshSpecDisplays()
    if U.window and U.window.record and U.window.IsShown and U.window:IsShown() then
        local record = U.window.record
        SetDetailSummaryTitle(U.window, record)
        SetOpponentHeader(U.window.tableHeader, record)
    end
    local tip = U.historyTip
    if tip and tip.record and tip.owner and tip.IsShown and tip:IsShown() then
        U.ShowHistoryTooltip(tip.owner, tip.record, tip.historyMeta)
    end
end

function U.SpecTargetRecord()
    if U.window and U.window.record and U.window.IsShown and U.window:IsShown() then return U.window.record end
    local tip = U.historyTip
    if tip and tip.record and tip.IsShown and tip:IsShown() then return tip.record end
    return nil
end

function U.HideHistoryTooltip()
    if U.historyTip then U.historyTip:Hide() end
end

local function EntryChatLink(entry)
    if not entry then return end
    if entry.itemID then
        local _, link = ItemInfo(entry.itemID)
        return link or ("item:" .. tostring(entry.itemID))
    end
    if entry.spellID then
        if GetSpellLink then
            local link = GetSpellLink(entry.spellID)
            if link then return link end
        end
        if C_Spell and C_Spell.GetSpellLink then
            local link = C_Spell.GetSpellLink(entry.spellID)
            if link then return link end
        end
    end
end

local function FitEntryLabel(label, text, maxWidth)
    text = text or ""
    local path, size, flags = label:GetFont()
    label.baseFontPath = label.baseFontPath or path
    label.baseFontSize = label.baseFontSize or size or 14
    label.baseFontFlags = label.baseFontFlags or flags
    path = label.baseFontPath or path
    size = label.baseFontSize or size or 14
    flags = label.baseFontFlags or flags

    if path and label.SetFont then label:SetFont(path, size, flags) end
    label:SetText(text)

    -- Measure unconstrained. Measuring after the FontString had already been
    -- narrowed to the cell caused Classic Era to report misleading widths and
    -- shrink long item names much more than necessary.
    label:SetWidth(1000)
    local naturalWidth = label.GetStringWidth and label:GetStringWidth() or maxWidth

    if naturalWidth and naturalWidth > maxWidth and naturalWidth > 0 then
        -- Scale directly to the usable cell width, then make only tiny corrective
        -- reductions if Classic's font rasterization still leaves it a hair wide.
        size = math.max(8, math.min(size, math.floor((size * maxWidth / naturalWidth) * 10 + .5) / 10))
        if path and label.SetFont then label:SetFont(path, size, flags) end
        label:SetWidth(1000)
        local measured = label.GetStringWidth and label:GetStringWidth() or naturalWidth
        while measured > maxWidth and size > 8 do
            size = math.max(8, size - .25)
            if path and label.SetFont then label:SetFont(path, size, flags) end
            measured = label.GetStringWidth and label:GetStringWidth() or measured
        end
    end

    label:SetWidth(maxWidth)
    return label.GetStringWidth and label:GetStringWidth() or maxWidth, size
end

local function CreateEntryButton(window)
    local button = CreateFrame("Button", nil, window.body)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("LEFT", 0, 0); button.label:SetJustifyH("LEFT")
    if button.label.SetWordWrap then button.label:SetWordWrap(false) end
    button:SetScript("OnEnter", function(self)
        if not self.entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.entry.itemID then GameTooltip:SetHyperlink("item:" .. self.entry.itemID)
        elseif GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(self.entry.spellID)
        elseif GetSpellLink and self.entry.spellID then
            local link = GetSpellLink(self.entry.spellID)
            if link then GameTooltip:SetHyperlink(link) end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self)
        if not (self.entry and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink) then return end
        local link = EntryChatLink(self.entry)
        if link then ChatEdit_InsertLink(link) end
    end)
    return button
end

local function CreateDetailRow(window)
    local row = CreateFrame("Frame", nil, window.body)
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(row)
    row.category = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.category:SetJustifyH("LEFT"); if row.category.SetJustifyV then row.category:SetJustifyV("TOP") end
    row.playerEmpty = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    row.opponentEmpty = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    row.playerEmpty:SetText("—"); row.opponentEmpty:SetText("—")
    row.leftRule, row.rightRule, row.bottomRule = AddRule(row, true), AddRule(row, true), AddRule(row, false)
    return row
end

local function EscapeCombatPattern(text)
    return (tostring(text or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function WhiteCombat(text) return "|cffffffff" .. tostring(text or "") .. "|r" end
local function GoldCombat(text) return "|cffffce70" .. tostring(text or "") .. "|r" end
local function DamageCombat(text) return "|cffff8888" .. tostring(text or "") .. "|r" end
local function HealCombat(text) return "|cff65e6ad" .. tostring(text or "") .. "|r" end
local function MutedCombat(text) return "|cffadb5c2" .. tostring(text or "") .. "|r" end

local function DuelOpponentClassFromLog(record)
    local _, class = ResolvedOpponent(record)
    if class then return class end
    local log = record and record.session and record.session.combatLog
    if not (log and DP.Specs and DP.Specs.InferClassFromAbility) then return nil end
    for _, entry in ipairs(log.toMe or {}) do
        local text = type(entry) == "table" and entry.text or tostring(entry or "")
        local spell = text:match("^[^']+'s (.-) hit you") or
            text:match("^[^']+'s (.-) healed you") or
            text:match("^[^']+'s (.-) missed you") or
            text:match("^.- applied (.-) to you$") or
            text:match("^.- refreshed (.-) on you$") or
            text:match("^[^']+'s (.-) interrupted your ") or
            text:match("^[^']+'s (.-) removed your ") or
            text:match("^(.-) faded from you$")
        if spell then
            class = DP.Specs.InferClassFromAbility(nil, spell)
            if class then
                if record.session and record.session.identity and not record.session.identity.class then
                    record.session.identity.class = class
                end
                return class
            end
        end
    end
end

local function ColorDuelCombatText(record, key, rawText)
    local text = tostring(rawText or "")
    local opponent = OpponentNamePlain(record, true)
    local opponentClass = DuelOpponentClassFromLog(record)
    local opponentColored = opponentClass and DP.Theme.ClassName(opponent, opponentClass) or ("|cffffad66" .. opponent .. "|r")
    local playerClass = record and record.playerClass
    if not playerClass and UnitClass then local _, detected = UnitClass("player"); playerClass = detected end
    local youColored = playerClass and DP.Theme.ClassName("you", playerClass) or "you"

    -- Color spell/ability names from the fixed duel-log sentence grammar before
    -- actor names inject WoW color escape sequences into those same strings.
    if key == "myActions" then
        text = text:gsub("^Cast (.-)( on .+)$", function(spell, rest) return GoldCombat("Cast") .. " " .. WhiteCombat(spell) .. rest end)
        text = text:gsub("^([^|].-) hit (.+) for (%d+)$", function(spell, target, amount)
            if spell == "Melee" then return WhiteCombat(spell) .. " " .. DamageCombat("hit") .. " " .. target .. " for " .. DamageCombat(amount) end
            return WhiteCombat(spell) .. " " .. DamageCombat("hit") .. " " .. target .. " for " .. DamageCombat(amount)
        end)
        text = text:gsub("^([^|].-) healed (.+) for (%d+)$", function(spell, target, amount)
            return WhiteCombat(spell) .. " " .. HealCombat("healed") .. " " .. target .. " for " .. HealCombat(amount)
        end)
        text = text:gsub("^([^|].-) missed (.+) %((.-)%)$", function(spell, target, miss)
            return WhiteCombat(spell) .. " missed " .. target .. " " .. MutedCombat("(" .. miss .. ")")
        end)
        text = text:gsub("^Applied (.-) to (.+)$", function(spell, target) return "Applied " .. WhiteCombat(spell) .. " to " .. target end)
        text = text:gsub("^Refreshed (.-) on (.+)$", function(spell, target) return "Refreshed " .. WhiteCombat(spell) .. " on " .. target end)
        text = text:gsub("^([^|].-) faded from (.+)$", function(spell, target) return WhiteCombat(spell) .. " faded from " .. target end)
        text = text:gsub("^([^|].-) interrupted (.+)'s (.+)$", function(spell, target, interrupted)
            return WhiteCombat(spell) .. " " .. GoldCombat("interrupted") .. " " .. target .. "'s " .. WhiteCombat(interrupted)
        end)
        text = text:gsub("^([^|].-) removed (.-) from (.+)$", function(spell, removed, target)
            return WhiteCombat(spell) .. " removed " .. WhiteCombat(removed) .. " from " .. target
        end)
        text = text:gsub("^([^|].-) restored (%d+) resource$", function(spell, amount)
            return WhiteCombat(spell) .. " restored " .. HealCombat(amount) .. " resource"
        end)
        text = text:gsub(EscapeCombatPattern(opponent), function() return opponentColored end)
    else
        local opp = EscapeCombatPattern(opponent)
        text = text:gsub("^" .. opp .. "'s (.-) hit you for (%d+)$", function(spell, amount)
            return opponentColored .. "'s " .. WhiteCombat(spell) .. " " .. DamageCombat("hit") .. " " .. youColored .. " for " .. DamageCombat(amount)
        end)
        text = text:gsub("^" .. opp .. " hit you for (%d+)$", function(amount)
            return opponentColored .. " " .. DamageCombat("hit") .. " " .. youColored .. " for " .. DamageCombat(amount)
        end)
        text = text:gsub("^" .. opp .. "'s (.-) healed you for (%d+)$", function(spell, amount)
            return opponentColored .. "'s " .. WhiteCombat(spell) .. " " .. HealCombat("healed") .. " " .. youColored .. " for " .. HealCombat(amount)
        end)
        text = text:gsub("^" .. opp .. "'s (.-) missed you %((.-)%)$", function(spell, miss)
            return opponentColored .. "'s " .. WhiteCombat(spell) .. " missed " .. youColored .. " " .. MutedCombat("(" .. miss .. ")")
        end)
        text = text:gsub("^" .. opp .. " missed you %((.-)%)$", function(miss)
            return opponentColored .. " missed " .. youColored .. " " .. MutedCombat("(" .. miss .. ")")
        end)
        text = text:gsub("^" .. opp .. " applied (.-) to you$", function(spell)
            return opponentColored .. " applied " .. WhiteCombat(spell) .. " to " .. youColored
        end)
        text = text:gsub("^" .. opp .. " refreshed (.-) on you$", function(spell)
            return opponentColored .. " refreshed " .. WhiteCombat(spell) .. " on " .. youColored
        end)
        text = text:gsub("^(.-) faded from you$", function(spell) return WhiteCombat(spell) .. " faded from " .. youColored end)
        text = text:gsub("^" .. opp .. "'s (.-) interrupted your (.+)$", function(spell, interrupted)
            return opponentColored .. "'s " .. WhiteCombat(spell) .. " " .. GoldCombat("interrupted") .. " your " .. WhiteCombat(interrupted)
        end)
        text = text:gsub("^" .. opp .. "'s (.-) removed your (.+)$", function(spell, removed)
            return opponentColored .. "'s " .. WhiteCombat(spell) .. " removed your " .. WhiteCombat(removed)
        end)
        text = text:gsub("^" .. opp .. "'s (.-) restored (%d+) resource$", function(spell, amount)
            return opponentColored .. "'s " .. WhiteCombat(spell) .. " restored " .. HealCombat(amount) .. " resource"
        end)
        -- All sentence shapes emitted by IncomingCombatText are handled above.
        -- Avoid a second generic replacement pass here; it can re-color names
        -- already wrapped in WoW color escapes.
    end
    return text
end

local function CombatLogText(record, key)
    local log = record and record.session and record.session.combatLog
    if not log then return "|cff8f98a6Combat log capture was not available for this duel.|r" end
    local entries = log[key] or {}
    if #entries == 0 then
        return key == "myActions" and "|cff8f98a6No qualifying actions were recorded.|r" or
            "|cff8f98a6No qualifying incoming events were recorded.|r"
    end
    local lines = {}
    for _, entry in ipairs(entries) do
        local elapsed = type(entry) == "table" and tonumber(entry.t) or nil
        local text = type(entry) == "table" and entry.text or tostring(entry)
        text = ColorDuelCombatText(record, key, text)
        if elapsed then
            lines[#lines + 1] = string.format("|cff8f98a6+%05.1fs|r  %s", elapsed, text or "")
        else
            lines[#lines + 1] = text or ""
        end
    end
    local truncated = key == "myActions" and log.myTruncated or log.toMeTruncated
    if truncated then lines[#lines + 1] = "|cff8f98a6… additional events were omitted.|r" end
    return table.concat(lines, "\n")
end

local function SelectCombatLogTab(window, key)
    window.activeLogTab = key
    DP.Theme.SelectDataTab(window.myActionsTab, key == "myActions", "My actions")
    DP.Theme.SelectDataTab(window.toMeTab, key == "toMe", "What happened to me")
    window.logText:SetText(CombatLogText(window.record, key))
    local height = window.logText.GetStringHeight and window.logText:GetStringHeight() or 100
    window.logBody:SetHeight(math.max(128, (height or 100) + 10))
    if window.logScroll.SetVerticalScroll then window.logScroll:SetVerticalScroll(0) end
end

local function EnsureDetailWindow()
    if U.window then return U.window end
    local window = CreateFrame("Frame", "RivalsDuelUsageDetails", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    window.baseHeight = 620
    window:SetSize(600, window.baseHeight)
    window.maxUsageHeight = 210
    window.minUsageHeight = 44; window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG")
    if window.SetClampedToScreen then window:SetClampedToScreen(true) end
    window:SetMovable(true); window:EnableMouse(true)

    -- Keep the rock fill inside the metal border. SetAllPoints let the square
    -- texture protrude through the decorative corners on Classic Era.
    window.bg = window:CreateTexture(nil, "BACKGROUND")
    window.bg:SetPoint("TOPLEFT", 1, -1); window.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    window.bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
    window.bg:SetVertexColor(.28, .30, .33, .97)
    window.border = DP.Theme.Border(window, 0, 0, 600, 620); window.border:ClearAllPoints(); window.border:SetAllPoints(window); window.border:EnableMouse(false)

    -- This is the exact Zurk Maps / Duel Rating plaque assembly from Theme.lua,
    -- not another bordered rectangle layered on top of the outer frame.
    local header = DP.Theme.PlaqueHeader(window, 360, "Duel Details", "GameFontNormal")
    header:SetPoint("BOTTOM", window, "TOP", 0, -4)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:StartMoving() end)
    header:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    window.header = header

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2); close:SetScript("OnClick", function() window:Hide() end)
    window.close = close

    window.summaryTitle = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.summaryTitle:SetPoint("TOPLEFT", 24, -34); window.summaryTitle:SetJustifyH("LEFT")
    if window.summaryTitle.SetWordWrap then window.summaryTitle:SetWordWrap(false) end
    window.summaryOpponent = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    if window.summaryOpponent.SetWordWrap then window.summaryOpponent:SetWordWrap(false) end
    window.summarySpec = MakeSpecFont(window, false)
    window.summaryDate = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.summaryDate:SetPoint("TOPLEFT", 24, -60); window.summaryDate:SetWidth(540); window.summaryDate:SetJustifyH("LEFT")
    window.summaryMeta = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.summaryMeta:SetPoint("TOPLEFT", 24, -81); window.summaryMeta:SetWidth(540); window.summaryMeta:SetJustifyH("LEFT")

    window.tableHeader = CreateTableHeader(window, 540, 160, 190, false)
    window.tableHeader:SetPoint("TOPLEFT", 20, -107)

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -137); scroll:SetSize(560, window.maxUsageHeight)
    local body = CreateFrame("Frame", nil, scroll); body:SetSize(540, 1); scroll:SetScrollChild(body)
    window.body, window.rows, window.entryButtons, window.scroll = body, {}, {}, scroll

    -- Persistent duel combat log. Tabs sit on the upper lip of the inset box,
    -- while each view gets its own independent scroll position/content.
    local logBox = CreateFrame("Frame", nil, window, BackdropTemplateMixin and "BackdropTemplate" or nil)
    logBox:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, -38); logBox:SetPoint("RIGHT", window, "RIGHT", -20, 0); logBox:SetHeight(170)
    logBox.bg = logBox:CreateTexture(nil, "BACKGROUND"); logBox.bg:SetPoint("TOPLEFT", 1, -1); logBox.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    logBox.bg:SetColorTexture(.018, .024, .032, .93)
    logBox.border = DP.Theme.Border(logBox, 0, 0, 560, 190); logBox.border:ClearAllPoints(); logBox.border:SetAllPoints(logBox); logBox.border:EnableMouse(false)
    window.logBox = logBox

    local logScroll = CreateFrame("ScrollFrame", nil, logBox, "UIPanelScrollFrameTemplate")
    logScroll:SetPoint("TOPLEFT", 8, -9); logScroll:SetPoint("BOTTOMRIGHT", -30, 9)
    local logBody = CreateFrame("Frame", nil, logScroll); logBody:SetSize(510, 128); logScroll:SetScrollChild(logBody)
    local logText = logBody:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    logText:SetPoint("TOPLEFT", 4, -4); logText:SetWidth(500); logText:SetJustifyH("LEFT")
    if logText.SetJustifyV then logText:SetJustifyV("TOP") end
    if logText.SetWordWrap then logText:SetWordWrap(true) end
    window.logScroll, window.logBody, window.logText = logScroll, logBody, logText

    window.myActionsTab = DP.Theme.DataTab(window, "My actions", 0, 0, 110, function()
        SelectCombatLogTab(window, "myActions")
    end)
    window.myActionsTab:ClearAllPoints(); window.myActionsTab:SetPoint("BOTTOMLEFT", logBox, "TOPLEFT", 0, -1)
    window.toMeTab = DP.Theme.DataTab(window, "What happened to me", 0, 0, 160, function()
        SelectCombatLogTab(window, "toMe")
    end)
    window.toMeTab:ClearAllPoints(); window.toMeTab:SetPoint("LEFT", window.myActionsTab, "RIGHT", 1, 0)

    window:SetScript("OnHide", function()
        GameTooltip:Hide(); U.HideHistoryTooltip()
    end)
    UISpecialFrames[#UISpecialFrames+1] = "RivalsDuelUsageDetails"
    U.window = window
    return window
end

local function LayoutDetailRows(window, groups)
    local width, categoryWidth, playerWidth = 540, 160, 190
    local opponentWidth = width - categoryWidth - playerWidth
    local entryIndex, y = 0, 0
    for index, group in ipairs(groups) do
        local row = window.rows[index]
        if not row then row = CreateDetailRow(window); window.rows[index] = row end
        local count = math.max(1, #group.player, #group.opponent)
        local height = count * 22 + 18
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetSize(width, height)
        row.bg:SetColorTexture(.045, .055, .07, index % 2 == 0 and .78 or .54)
        row.category:ClearAllPoints(); row.category:SetPoint("TOPLEFT", 10, -10); row.category:SetWidth(categoryWidth - 20)
        row.category:SetText("|cffffce70" .. DisplayCategory(group.title) .. "|r")
        row.leftRule:ClearAllPoints(); row.leftRule:SetPoint("TOPLEFT", categoryWidth, 0); row.leftRule:SetPoint("BOTTOMLEFT", categoryWidth, 0)
        row.rightRule:ClearAllPoints(); row.rightRule:SetPoint("TOPLEFT", categoryWidth + playerWidth, 0); row.rightRule:SetPoint("BOTTOMLEFT", categoryWidth + playerWidth, 0)
        row.bottomRule:ClearAllPoints(); row.bottomRule:SetPoint("BOTTOMLEFT", 0, 0); row.bottomRule:SetWidth(width)

        row.playerEmpty:SetText("—"); row.opponentEmpty:SetText("—")
        row.playerEmpty:Hide(); row.opponentEmpty:Hide()
        if #group.player == 0 then
            row.playerEmpty:ClearAllPoints(); row.playerEmpty:SetPoint("TOPLEFT", categoryWidth + 10, -10); row.playerEmpty:Show()
        end
        if #group.opponent == 0 then
            row.opponentEmpty:ClearAllPoints(); row.opponentEmpty:SetPoint("TOPLEFT", categoryWidth + playerWidth + 10, -10); row.opponentEmpty:Show()
        end

        for _, side in ipairs({"player", "opponent"}) do
            local x = side == "player" and categoryWidth + 10 or categoryWidth + playerWidth + 10
            local cellWidth = side == "player" and playerWidth - 20 or opponentWidth - 20
            for line, entry in ipairs(group[side]) do
                entryIndex = entryIndex + 1
                local button = window.entryButtons[entryIndex]
                if not button then button = CreateEntryButton(window); window.entryButtons[entryIndex] = button end
                button.entry = entry
                local measured = FitEntryLabel(button.label, entry.text, cellWidth)
                button:ClearAllPoints(); button:SetPoint("TOPLEFT", row, "TOPLEFT", x, -8 - (line - 1) * 22)
                button:SetSize(cellWidth, 20); button.label:SetWidth(cellWidth); button:Show()
            end
        end
        row:Show(); y = y + height
    end
    for index = #groups + 1, #window.rows do window.rows[index]:Hide() end
    for index = entryIndex + 1, #window.entryButtons do window.entryButtons[index]:Hide(); window.entryButtons[index].entry = nil end

    local displayHeight = math.min(window.maxUsageHeight or y, math.max(window.minUsageHeight or 44, y))
    window.scroll:SetHeight(displayHeight)
    window.body:SetHeight(math.max(1, y))
    local scrollBar = window.scroll.ScrollBar or _G[(window.scroll.GetName and window.scroll:GetName()) and (window.scroll:GetName() .. "ScrollBar") or ""]
    if scrollBar then scrollBar:SetShown(y > displayHeight + 1) end
    if window.logBox then
        window.logBox:ClearAllPoints()
        window.logBox:SetPoint("TOPLEFT", window.scroll, "BOTTOMLEFT", 0, -38)
        window.logBox:SetPoint("RIGHT", window, "RIGHT", -20, 0)
    end
    return y, displayHeight
end

-- Scrollable duel details with a fixed dataframe-style header. Item/spell tooltip
-- hitboxes are sized to the text itself rather than the entire horizontal cell.
function U.OpenDetails(record)
    if DP.WorldPvP and DP.WorldPvP.details and DP.WorldPvP.details:IsShown() then
        DP.WorldPvP.details:Hide()
    end
    local window = EnsureDetailWindow()
    SetDetailSummaryTitle(window, record)
    window.summaryDate:SetText("|cffadb5c2" .. date("%Y-%m-%d %H:%M:%S", record.timestamp) .. "|r")
    local meta = {}
    if DP.Views and DP.Views.Mode then meta[#meta + 1] = DP.Views.Mode(record) end
    if record.duration then
        local suffix = record.durationQuality and (" (" .. record.durationQuality .. ")") or ""
        meta[#meta + 1] = string.format("%.2fs%s", record.duration, suffix)
    end
    window.summaryMeta:SetText("|cffadb5c2" .. table.concat(meta, "  •  ") .. "|r")
    SetOpponentHeader(window.tableHeader, record)

    local groups = U.Groups(record)
    local height, displayHeight = LayoutDetailRows(window, groups)
    if #groups == 0 then
        local row = window.rows[1]
        if not row then row = CreateDetailRow(window); window.rows[1] = row end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, 0); row:SetSize(540, 44); row.bg:SetColorTexture(.045, .055, .07, .54)
        row.category:ClearAllPoints(); row.category:SetText("|cffffce70Usage|r"); row.category:SetPoint("TOPLEFT", 10, -12)
        row.playerEmpty:SetText("No item, cooldown, racial, or engineering gadget use recorded.")
        row.playerEmpty:ClearAllPoints(); row.playerEmpty:SetPoint("TOPLEFT", 170, -12); row.playerEmpty:SetWidth(350); row.playerEmpty:Show()
        row.opponentEmpty:Hide(); row:Show(); height = 44
        for index = 2, #window.rows do window.rows[index]:Hide() end
        window.scroll:SetHeight(height)
        window.body:SetHeight(height)
        local scrollBar = window.scroll.ScrollBar or _G[(window.scroll.GetName and window.scroll:GetName()) and (window.scroll:GetName() .. "ScrollBar") or ""]
        if scrollBar then scrollBar:Hide() end
        if window.logBox then
            window.logBox:ClearAllPoints()
            window.logBox:SetPoint("TOPLEFT", window.scroll, "BOTTOMLEFT", 0, -38)
            window.logBox:SetPoint("RIGHT", window, "RIGHT", -20, 0)
        end
    end
    local targetHeight = window.baseHeight or 620
    if (displayHeight or window.maxUsageHeight) < (window.maxUsageHeight or 210) then
        targetHeight = math.max(420, math.min(targetHeight, 374 + (displayHeight or 0)))
    end
    window:SetHeight(targetHeight)

    window.record = record
    SelectCombatLogTab(window, window.activeLogTab or "myActions")
    window:Show()
    if window.scroll.SetVerticalScroll then window.scroll:SetVerticalScroll(0) end
end
