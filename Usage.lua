local _, DP = ...
local U = {items = {}}
DP.Usage = U

-- Use spells are learned from actual carried/equipped items, never from
-- ability-name guesses. Several items may share one activation spell.
function U.Scan()
    local itemSpell = C_Item and C_Item.GetItemSpell or GetItemSpell
    if not itemSpell then return end
    local function Add(id)
        if not id then return end
        local name, spell = itemSpell(id)
        if type(spell) == "number" and type(name) == "string" then U.items[spell] = name end
    end
    if GetInventoryItemID then
        for slot = 1, 19 do Add(GetInventoryItemID("player", slot)) end
    end
    local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local item = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    if slots and item then
        for bag = 0, 4 do for slot = 1, slots(bag) do Add(item(bag, slot)) end end
    end
end

function U.Begin(session)
    if session and not session.usage then
        session.usage = {version = 1, player = {}, opponent = {}}
    end
end

function U.Observe(session, playerGUID, now, event, sourceGUID, spellID, spellName, baseCooldown)
    if not session or session.excluded or not session.estimatedStartAt or
        now < session.estimatedStartAt or session.finishedAt or event ~= "SPELL_CAST_SUCCESS" then return end
    local side = sourceGUID == playerGUID and "player" or
        (session.identity and sourceGUID == session.identity.guid and "opponent")
    if not side or type(spellID) ~= "number" then return end
    local item = U.items[spellID]
    local long = type(baseCooldown) == "number" and baseCooldown >= 600000
    if not item and not long then return end
    U.Begin(session)
    local entries = session.usage[side]
    local key = tostring(spellID)
    if not entries[key] then
        local count = 0
        for _ in pairs(entries) do count = count + 1 end
        if count >= 64 then return end
        entries[key] = {spellID = spellID, name = spellName or item or ("Spell " .. spellID),
            kind = item and "item" or "cooldown", cooldown = long and baseCooldown / 1000 or nil, count = 0}
    end
    entries[key].count = entries[key].count + 1
end

function U.Combat(session, playerGUID)
    if not session or not CombatLogGetCurrentEventInfo then return end
    local _, event, _, sourceGUID, _, _, _, _, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
    if event ~= "SPELL_CAST_SUCCESS" then return end
    local cooldown
    if GetSpellBaseCooldown and spellID then cooldown = GetSpellBaseCooldown(spellID) end
    U.Observe(session, playerGUID, GetTime(), event, sourceGUID, spellID, spellName, cooldown)
end

function U.Tooltip(record)
    local usage = record.session and record.session.usage
    if not usage then return {"", "|cffffce70Items & long cooldowns|r", "N/A"} end
    local lines = {"", "|cffffce70Items & long cooldowns|r"}
    if not next(usage.player or {}) and not next(usage.opponent or {}) then
        lines[#lines + 1] = "N/A"; return lines
    end
    for _, side in ipairs({"player", "opponent"}) do
        local entries = {}
        for _, entry in pairs(usage[side] or {}) do entries[#entries + 1] = entry end
        table.sort(entries, function(a, b) return a.spellID < b.spellID end)
        lines[#lines + 1] = side == "player" and "|cff79bdffYou|r" or "|cff79bdffOpponent|r"
        if #entries == 0 then lines[#lines + 1] = "  N/A" end
        for index, entry in ipairs(entries) do
            if index > 8 then
                lines[#lines + 1] = string.format("  +%d other activations saved", #entries - 8)
                break
            end
            lines[#lines + 1] = string.format("  %s x%d [%s]", entry.name, entry.count,
                entry.kind == "item" and "item activation" or string.format("%g min cooldown", entry.cooldown / 60))
        end
    end
    return lines
end
