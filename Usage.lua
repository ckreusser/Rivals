local _, DP = ...
local U = {items = {}}
local racialSpells = {[20572]=true, [20594]=true, [7744]=true, [20549]=true,
    [26296]=true, [26297]=true, [20554]=true, [20580]=true, [20600]=true,
    [20577]=true, [20589]=true}
local colors = {[0]="9d9d9d", [1]="ffffff", [2]="1eff00", [3]="0070dd", [4]="a335ee", [5]="ff8000"}
U.sections = {{"potions", "Potions/Consumables:"}, {"engineering", "Engineering Gadgets:"}, {"equipment", "Equipment:"},
    {"cooldowns", "Cooldowns (≥3 min):"}, {"racials", "Racials:"}}

-- Classic Era's original PvP trinkets are class- and faction-specific items,
-- but CLEU reports one of five generic internal "Immune ..." item-effect spells.
-- Treat every one of those effects as equipment, then recover the exact Insignia
-- from the actor's class/faction instead of misclassifying the 5 minute effect as
-- a class cooldown.
local insigniaItems = {
    Horde = {
        WARRIOR = 18834, SHAMAN = 18845, HUNTER = 18846, ROGUE = 18849,
        MAGE = 18850, PRIEST = 18851, WARLOCK = 18852, DRUID = 18853,
    },
    Alliance = {
        WARRIOR = 18854, HUNTER = 18856, ROGUE = 18857, WARLOCK = 18858,
        MAGE = 18859, PRIEST = 18862, DRUID = 18863, PALADIN = 18864,
    },
}
local insigniaSpells = {
    [5579] = true,  -- Immune Root/Snare/Stun (Warrior/Hunter/Shaman)
    [23273] = true, -- Immune Charm/Fear/Polymorph (Rogue/Warlock)
    [23274] = true, -- Immune Fear/Polymorph/Snare (Mage)
    [23276] = true, -- Immune Fear/Polymorph/Stun (Priest/Paladin)
    [23277] = true, -- Immune Charm/Fear/Stun (Druid)
}
local factionByRace = {
    Human = "Alliance", Dwarf = "Alliance", NightElf = "Alliance", Gnome = "Alliance",
    Orc = "Horde", Scourge = "Horde", Undead = "Horde", Tauren = "Horde", Troll = "Horde",
}

local function OppositeFaction(faction)
    if faction == "Alliance" then return "Horde" end
    if faction == "Horde" then return "Alliance" end
end

local function FindIdentity(session, guid, record)
    if guid and session then
        if session.participants and session.participants[guid] then return session.participants[guid] end
        if session.enemies and session.enemies[guid] then return session.enemies[guid] end
        if session.friendlies and session.friendlies[guid] then return session.friendlies[guid] end
    end
    if guid and record then
        local saved = record.session and record.session.participants
        if saved and saved[guid] then return saved[guid] end
        for _, group in ipairs({record.enemies or {}, record.friendlies or {}}) do
            for _, identity in ipairs(group) do
                if identity and identity.guid == guid then return identity end
            end
        end
    end
    return session and session.identity or nil
end

local function ActorFaction(session, guid, record, identity)
    local race = identity and (identity.raceFile or identity.race)
    local faction = race and factionByRace[tostring(race):gsub("%s+", "")] or nil
    if faction then return faction end

    local playerFaction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local playerGUID = (session and session.playerGUID) or (record and record.playerGUID)
    if guid and playerGUID and guid == playerGUID then return playerFaction end

    if guid and session and session.worldPvP and session.enemies and session.enemies[guid] then
        return OppositeFaction(playerFaction)
    end
    if guid and record and record.kind == "worldpvp" then
        for _, enemy in ipairs(record.enemies or {}) do
            if enemy and enemy.guid == guid then return OppositeFaction(playerFaction) end
        end
    end
    -- Classic Era duels are same-faction; friendly/open-world actors also use the
    -- player's faction when no retained race is available.
    return playerFaction
end

local function ResolveInsignia(spellID, session, guid, spellName, record)
    if not insigniaSpells[tonumber(spellID)] then return nil end
    local identity = FindIdentity(session, guid, record)
    local class = identity and identity.class or nil
    if not class and guid and session and guid == session.playerGUID then class = session.playerClass end
    if not class and guid and record and guid == record.playerGUID then class = record.playerClass end
    local faction = ActorFaction(session, guid, record, identity)
    local itemID = faction and class and insigniaItems[faction] and insigniaItems[faction][class] or nil
    return {
        itemID = itemID,
        name = faction == "Alliance" and "Insignia of the Alliance" or
            faction == "Horde" and "Insignia of the Horde" or "PvP Insignia",
        quality = 3,
        category = "equipment",
        forceItem = true,
        pvpInsignia = true,
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

function U.Observe(session, playerGUID, now, event, sourceGUID, spellID, spellName, baseCooldown, destGUID, destName)
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
        item = ResolveInsignia(spellID, session, sourceGUID, spellName) or Catalog(spellID)
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
            observedAt = now, t = math.max(0, now - usageStart), targetGUID = destGUID, targetName = destName,
            count = 0}
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
    if session and (not session._lastDuelBuffScan or now - session._lastDuelBuffScan >= 2) then
        session._lastDuelBuffScan = now
        if U.CaptureDuelBuffs then U.CaptureDuelBuffs(session) end
    end

    -- Usage detection remains SPELL_CAST_SUCCESS based, but the threshold is now
    -- three minutes. The combat-log panes capture the broader event stream.
    if event == "SPELL_CAST_SUCCESS" then
        local cooldown
        if GetSpellBaseCooldown and spellID then cooldown = GetSpellBaseCooldown(spellID) end
        U.Observe(session, playerGUID, now, event, sourceGUID, spellID, spellName, cooldown, destGUID, info[9])
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
-- Reagents which are consumed by combat-relevant spells rather than by an
-- explicit item-use spell.  These are recorded as their own consumable events
-- so the encounter economy can include them without pretending the spell itself
-- is an item.  Name fallbacks keep rank variants and localization-adjacent Era
-- builds useful when a spell ID differs.
local REAGENT_BY_SPELL = {
    [1856] = {itemID=5140, name="Flash Powder"}, [1857] = {itemID=5140, name="Flash Powder"}, -- Vanish
    [2094] = {itemID=5530, name="Blinding Powder"}, -- Blind
    [130] = {itemID=17056, name="Light Feather"}, -- Slow Fall
    [1706] = {itemID=17056, name="Light Feather"}, -- Levitate
    [23028] = {itemID=17020, name="Arcane Powder"}, -- Arcane Brilliance
    [20484] = {itemID=17034, name="Maple Seed"},
    [20739] = {itemID=17035, name="Stranglethorn Seed"},
    [20742] = {itemID=17036, name="Ashwood Seed"},
    [20747] = {itemID=17037, name="Hornbeam Seed"},
    [20748] = {itemID=17038, name="Ironwood Seed"}, -- Rebirth ranks
    [19752] = {itemID=17033, name="Symbol of Divinity"}, -- Divine Intervention
    [17877] = {itemID=6265, name="Soul Shard"}, [18867] = {itemID=6265, name="Soul Shard"},
    [18868] = {itemID=6265, name="Soul Shard"}, [18869] = {itemID=6265, name="Soul Shard"},
    [18871] = {itemID=6265, name="Soul Shard"}, -- Shadowburn ranks
    [6353] = {itemID=6265, name="Soul Shard"}, [17924] = {itemID=6265, name="Soul Shard"},
    [27211] = {itemID=6265, name="Soul Shard"}, -- Soul Fire variants seen on Era-family clients
}
local REAGENT_BY_NAME = {
    ["Vanish"] = {itemID=5140, name="Flash Powder"},
    ["Blind"] = {itemID=5530, name="Blinding Powder"},
    ["Slow Fall"] = {itemID=17056, name="Light Feather"},
    ["Levitate"] = {itemID=17056, name="Light Feather"},
    ["Arcane Brilliance"] = {itemID=17020, name="Arcane Powder"},
    ["Prayer of Fortitude"] = {itemID=17029, name="Sacred Candle"},
    ["Prayer of Spirit"] = {itemID=17029, name="Sacred Candle"},
    ["Prayer of Shadow Protection"] = {itemID=17029, name="Sacred Candle"},
    ["Greater Blessing of Kings"] = {itemID=21177, name="Symbol of Kings"},
    ["Greater Blessing of Might"] = {itemID=21177, name="Symbol of Kings"},
    ["Greater Blessing of Wisdom"] = {itemID=21177, name="Symbol of Kings"},
    ["Greater Blessing of Salvation"] = {itemID=21177, name="Symbol of Kings"},
    ["Greater Blessing of Light"] = {itemID=21177, name="Symbol of Kings"},
    ["Greater Blessing of Sanctuary"] = {itemID=21177, name="Symbol of Kings"},
    ["Divine Intervention"] = {itemID=17033, name="Symbol of Divinity"},
    ["Shadowburn"] = {itemID=6265, name="Soul Shard"},
    ["Soul Fire"] = {itemID=6265, name="Soul Shard"},
}

local function WorldUsageEvent(session, event)
    session.worldUsage = session.worldUsage or {version = 2, events = {}}
    local events = session.worldUsage.events
    -- CLEU can occasionally surface the same item-use signal twice on Era-family
    -- clients. Two uses of the same consumable by the same player cannot happen
    -- inside a single instant, so collapse duplicate item rows within 0.75 sec.
    if event and event.itemID and event.guid then
        local eventTime = tonumber(event.t) or 0
        for index = #events, math.max(1, #events - 10), -1 do
            local prior = events[index]
            if prior and prior.guid == event.guid and tonumber(prior.itemID) == tonumber(event.itemID) then
                local dt = math.abs(eventTime - (tonumber(prior.t) or 0))
                if dt <= .75 then return false end
                if dt > 4 then break end
            end
        end
    end
    if #events >= 128 then session.worldUsage.truncated = true; return false end
    events[#events + 1] = event
    return true
end

local function WorldUsageBase(session, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
    return {
        t = math.max(0, GetTime() - (session.startedElapsed or GetTime())),
        guid = sourceGUID,
        actorName = sourceName,
        targetGUID = destGUID,
        targetName = destName,
        sourceSpellID = spellID,
        sourceSpellName = spellName,
        count = 1,
    }
end

local function ReagentForSpell(spellID, spellName)
    return REAGENT_BY_SPELL[spellID] or REAGENT_BY_NAME[spellName]
end

local function RecentWorldItemUse(session, guid, itemID, seconds)
    local events = session and session.worldUsage and session.worldUsage.events or nil
    if not events then return false end
    local now = math.max(0, GetTime() - (session.startedElapsed or GetTime()))
    for index = #events, math.max(1, #events - 12), -1 do
        local entry = events[index]
        if entry and entry.guid == guid and tonumber(entry.itemID) == tonumber(itemID) and
                math.abs(now - (tonumber(entry.t) or 0)) <= (seconds or 3) then return true end
    end
    return false
end

function U.WorldObserve(session, playerGUID, info)
    if not session or not session.worldPvP or type(info) ~= "table" then return end
    local eventType = info[2]
    local sourceGUID, sourceName, destGUID, destName = info[4], info[5], info[8], info[9]
    local spellID, spellName = info[12], info[13]
    -- Classic Era's Chronoboon charge can surface only as the applied
    -- Supercharged aura in CLEU. Treat that aura as proof that one base
    -- Chronoboon Displacer was consumed, while deduping the normal Charging cast
    -- if a client happens to emit both signals.
    if eventType == "SPELL_AURA_APPLIED" and tonumber(spellID) == 349981 then
        if not sourceGUID or not session.participants or not session.participants[sourceGUID] then return end
        if not RecentWorldItemUse(session, sourceGUID, 184937, 10) then
            local event = WorldUsageBase(session, sourceGUID, sourceName, destGUID, destName, 349981, spellName)
            event.spellID = 349981
            event.nameSpell = spellName
            event.name = "Chronoboon Displacer"
            event.itemID = 184937
            event.itemName = "Chronoboon Displacer"
            event.kind = "item"
            event.category = "potions"
            event.consumable = true
            WorldUsageEvent(session, event)
        end
        return
    end
    if eventType ~= "SPELL_CAST_SUCCESS" then return end
    if not sourceGUID or not session.participants or not session.participants[sourceGUID] then return end
    if type(spellID) ~= "number" then return end

    local item, ambiguous
    if sourceGUID == playerGUID then
        item, ambiguous = ResolvePlayerItem(spellID)
        if not item and not ambiguous then
            item = ResolveInsignia(spellID, session, sourceGUID, spellName) or Catalog(spellID)
        end
    else
        item = ResolveInsignia(spellID, session, sourceGUID, spellName) or Catalog(spellID)
    end
    local cooldown
    if GetSpellBaseCooldown then cooldown = GetSpellBaseCooldown(spellID) end
    local long = type(cooldown) == "number" and cooldown >= 180000
    if not item and ambiguous then
        item = Catalog(spellID) or {name = spellName or ("Spell " .. spellID), category = "equipment", ambiguous = true}
    end
    local reagent = ReagentForSpell(spellID, spellName)
    if not item and not long and not racialSpells[spellID] and not reagent then return end

    if item or long or racialSpells[spellID] then
        local category = type(item) == "table" and item.category or nil
        local itemName = type(item) == "table" and item.name or nil
        category = EngineeringCategory(itemName) or category
        if not category then
            category = racialSpells[spellID] and "racials" or (item and "equipment" or "cooldowns")
        end
        local event = WorldUsageBase(session, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
        event.spellID = spellID
        event.nameSpell = spellName
        event.name = spellName or itemName or ("Spell " .. spellID)
        event.kind = item and "item" or racialSpells[spellID] and "racial" or "cooldown"
        event.itemID = type(item) == "table" and item.itemID or nil
        event.itemName = itemName
        event.quality = type(item) == "table" and item.quality or nil
        event.category = category
        event.cooldown = long and cooldown / 1000 or nil
        if not (tonumber(event.itemID) == 184937 and RecentWorldItemUse(session, sourceGUID, 184937, 10)) then
            WorldUsageEvent(session, event)
        end
    end

    if reagent then
        local event = WorldUsageBase(session, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
        event.spellID = spellID
        event.itemID = reagent.itemID
        event.itemName = reagent.name
        event.name = reagent.name
        event.kind = "reagent"
        event.category = "reagents"
        event.consumable = true
        event.count = reagent.count or 1
        WorldUsageEvent(session, event)
    end
end

-- Encounter consumable economy ------------------------------------------------
-- Keep the migration generation in one exported constant so WorldPvP and the
-- snapshot writer cannot silently drift apart. Any change to legacy evidence or
-- proxy pricing must bump this number so already-frozen legacy snapshots are
-- recalculated once with the improved logic.
U.LEGACY_CONSUMABLE_BACKFILL_VERSION = 10

-- Prices are resolved once, when the encounter is finalized, and copied into
-- the record. Historical records never query a pricing addon again, so their
-- totals remain stable even as the market moves.
local ZERO_GOLD_COST_ITEMS = {
    [5513]=true, -- Mana Jade
    [5514]=true, -- Mana Agate
    [8007]=true, -- Mana Citrine
    [8008]=true, -- Mana Ruby
}

local CONSUMABLE_NAME_TERMS = {
    "potion", "elixir", "flask", "bandage", "dynamite", "grenade", "bomb", "sapper",
    "target dummy", "magic dust", "juju", "zanza", "firewater", "sharpening stone",
    "weightstone", "mana oil", "wizard oil", "scroll", "rune", "tea", "healthstone",
    "whipper root", "night dragon", "crystal charge", "crystal restore", "crystal force",
    "crystal ward", "crystal yield", "crystal spire", "food", "drink",
}

local function LowerName(entry, itemName)
    return tostring(itemName or entry.itemName or entry.name or ""):lower()
end

local function ItemConsumptionMeta(itemID)
    if not itemID then return nil, nil, nil, nil end
    local name, _, _, _, _, _, _, _, equipLoc, _, sellPrice, classID, subclassID = ItemInfo(itemID)
    return name, equipLoc, classID, subclassID, sellPrice
end

local function LooksConsumedByName(name)
    name = tostring(name or ""):lower()
    for _, term in ipairs(CONSUMABLE_NAME_TERMS) do
        if name:find(term, 1, true) then return true end
    end
    return false
end

function U.IsConsumableWorldEvent(entry)
    if type(entry) ~= "table" or not entry.itemID then return false end
    if entry.consumable == false then return false end

    -- Prefer our catalog/category knowledge before item-cache heuristics.  This is
    -- important for uncached gear such as Diamond Flask: its name contains
    -- "Flask", but it is reusable equipment and must never become encounter spend.
    local known = Catalog(tonumber(entry.spellID or entry.sourceSpellID))
    if entry.category == "equipment" or (known and known.category == "equipment") then return false end
    if entry.kind == "reagent" or entry.category == "reagents" then return true end
    if entry.consumable == true then return true end

    local itemName, equipLoc, classID = ItemConsumptionMeta(entry.itemID)
    -- Anything with an equipment location is reusable gear even if the use spell
    -- happens to sit in the engineering section.
    if type(equipLoc) == "string" and equipLoc ~= "" then return false end
    -- Blizzard item class 0 is Consumable on Classic clients.
    if classID == 0 then return true end
    if entry.category == "potions" or (known and known.category == "potions") then return true end
    return LooksConsumedByName(LowerName(entry, itemName))
end

local function TSMItemString(itemID)
    local _, link = ItemInfo(itemID)
    if type(TSM_API) == "table" and type(TSM_API.ToItemString) == "function" and link then
        local ok, value = pcall(TSM_API.ToItemString, link)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    -- TSM4 Classic-era builds expose the older TSMAPI_FOUR surface rather than
    -- TSM_API. Supporting both lets Rivals read the same DBMarket value visible
    -- in the player's TSM tooltip instead of silently freezing an item unpriced.
    if type(TSMAPI_FOUR) == "table" and type(TSMAPI_FOUR.Item) == "table" and
            type(TSMAPI_FOUR.Item.ToItemString) == "function" and link then
        local ok, value = pcall(TSMAPI_FOUR.Item.ToItemString, link)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    return "i:" .. tostring(itemID)
end

local function TSMPrice(itemID)
    local itemString = TSMItemString(itemID)
    if type(TSM_API) == "table" and type(TSM_API.GetCustomPriceValue) == "function" then
        local ok, value = pcall(TSM_API.GetCustomPriceValue, "DBMarket", itemString)
        if ok and type(value) == "number" and value > 0 then
            return math.floor(value + .5), "TradeSkillMaster", "DBMarket"
        end
    end
    if type(TSMAPI_FOUR) == "table" and type(TSMAPI_FOUR.CustomPrice) == "table" and
            type(TSMAPI_FOUR.CustomPrice.GetValue) == "function" then
        local ok, value = pcall(TSMAPI_FOUR.CustomPrice.GetValue, "DBMarket", itemString)
        if ok and type(value) == "number" and value > 0 then
            return math.floor(value + .5), "TradeSkillMaster", "DBMarket"
        end
    end
end

local function AuctionatorPrice(itemID)
    local api = type(Auctionator) == "table" and Auctionator.API and Auctionator.API.v1
    if api and type(api.GetAuctionPriceByItemID) == "function" then
        local ok, value = pcall(api.GetAuctionPriceByItemID, "Rivals", tonumber(itemID))
        if ok and type(value) == "number" and value > 0 then
            local age
            if type(api.GetAuctionAgeByItemID) == "function" then
                local ageOK, ageValue = pcall(api.GetAuctionAgeByItemID, "Rivals", tonumber(itemID))
                if ageOK and type(ageValue) == "number" then age = ageValue end
            end
            return math.floor(value + .5), "Auctionator", nil, age
        end
    end
    -- Older Classic-era Auctionator branches exposed this compatibility getter.
    if type(Atr_GetAuctionBuyout) == "function" then
        local _, link = ItemInfo(itemID)
        local ok, value = pcall(Atr_GetAuctionBuyout, link or tonumber(itemID))
        if ok and type(value) == "number" and value > 0 then
            return math.floor(value + .5), "Auctionator", "legacy"
        end
    end
end

function U.HasSnapshotPriceSource()
    if type(TSM_API) == "table" and type(TSM_API.GetCustomPriceValue) == "function" then return true end
    if type(TSMAPI_FOUR) == "table" and type(TSMAPI_FOUR.CustomPrice) == "table" and
            type(TSMAPI_FOUR.CustomPrice.GetValue) == "function" then return true end
    local api = type(Auctionator) == "table" and Auctionator.API and Auctionator.API.v1
    if api and type(api.GetAuctionPriceByItemID) == "function" then return true end
    return type(Atr_GetAuctionBuyout) == "function"
end

local ZANZA_ITEMS = {[20079]=true, [20080]=true, [20081]=true}
local HAKKARI_BIJOUS = {19707, 19708, 19709, 19710, 19711, 19712, 19713, 19714, 19715}
local HAKKARI_BIJOU_NAMES = {
    [19707]="Red Hakkari Bijou", [19708]="Blue Hakkari Bijou", [19709]="Yellow Hakkari Bijou",
    [19710]="Orange Hakkari Bijou", [19711]="Green Hakkari Bijou", [19712]="Purple Hakkari Bijou",
    [19713]="Bronze Hakkari Bijou", [19714]="Silver Hakkari Bijou", [19715]="Gold Hakkari Bijou",
}
-- One destroyed Hakkari Bijou grants one Zandalar Honor Token, and one token
-- purchases one Zanza potion.  The correct replacement-cost ratio is 1:1.
local ZANZA_BIJOU_COUNT = 1

-- Winterspring repeatable quests exchange 3 E'ko for 3 matching Jujus, so one
-- Juju represents one E'ko of replacement cost.  The Juju itself is BOP and has
-- no meaningful auction market, while the E'ko is tradeable.
local JUJU_EKO_PROXY = {
    [12450]=12430, -- Juju Flurry  <- Frostsaber E'ko
    [12451]=12431, -- Juju Power   <- Winterfall E'ko
    [12455]=12432, -- Juju Ember   <- Shardtooth E'ko
    [12458]=12433, -- Juju Guile   <- Wildkin E'ko
    [12457]=12434, -- Juju Chill   <- Chillwind E'ko
    [12459]=12435, -- Juju Escape  <- Ice Thistle E'ko
    [12460]=12436, -- Juju Might   <- Frostmaul E'ko
}
local EKO_NAMES = {
    [12430]="Frostsaber E'ko", [12431]="Winterfall E'ko", [12432]="Shardtooth E'ko",
    [12433]="Wildkin E'ko", [12434]="Chillwind E'ko", [12435]="Ice Thistle E'ko", [12436]="Frostmaul E'ko",
}

-- A Supercharged Chronoboon is created by consuming one base Chronoboon.  It
-- has no independent market value, so releasing one uses the base item's
-- replacement cost rather than pretending the generated item is free/unpriced.
local CHRONOBOON_PROXY = {[184938]=184937}

local function DirectSnapshotPrice(itemID)
    local value, source, sourceKey, age = TSMPrice(itemID)
    if value then return value, source, sourceKey, age end
    return AuctionatorPrice(itemID)
end

local function ZanzaProxyPrice()
    local best, bestSource, bestKey, bestAge, bestBijou
    for _, bijouID in ipairs(HAKKARI_BIJOUS) do
        local value, source, sourceKey, age = DirectSnapshotPrice(bijouID)
        if value and (not best or value < best) then
            best, bestSource, bestKey, bestAge, bestBijou = value, source, sourceKey, age, bijouID
        end
    end
    if best then
        local bijouName = HAKKARI_BIJOU_NAMES[bestBijou] or select(1, ItemInfo(bestBijou)) or "Hakkari Bijou"
        return best * ZANZA_BIJOU_COUNT, bestSource,
            (bestKey and (bestKey .. " / ") or "") .. "1x " .. bijouName,
            bestAge, bestBijou, bijouName
    end
end

local function SingleProxyPrice(proxyItemID, label)
    local value, source, sourceKey, age = DirectSnapshotPrice(proxyItemID)
    if not value then return nil end
    local proxyName = select(1, ItemInfo(proxyItemID)) or label
    return value, source, (sourceKey and (sourceKey .. " / ") or "") .. "1x " .. proxyName, age, proxyItemID, proxyName
end

function U.GetSnapshotPrice(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    -- Noggenfogger is a fixed vendor purchase in Classic Era. Marin sells five
    -- for 35 silver, so each consumed elixir is exactly 7 silver replacement cost.
    if itemID == 8529 then return 700, "Vendor", "Fixed vendor price", nil, nil, nil end
    -- Proxy-derived BOP/generated consumables before trying their own item ID;
    -- stale addon databases sometimes expose meaningless prices for those IDs.
    if ZANZA_ITEMS[itemID] then return ZanzaProxyPrice() end
    local ekoID = JUJU_EKO_PROXY[itemID]
    if ekoID then
        local ekoName = EKO_NAMES[ekoID] or select(1, ItemInfo(ekoID)) or "E'ko"
        return SingleProxyPrice(ekoID, ekoName)
    end
    local chronoboonID = CHRONOBOON_PROXY[itemID]
    if chronoboonID then return SingleProxyPrice(chronoboonID, "Chronoboon Displacer") end
    return DirectSnapshotPrice(itemID)
end

local NOGGENFOGGER_AURA_SPELLS = {[16591]=true, [16593]=true, [16595]=true}

local CatalogByName
local function ConsumableFromTrackedBuff(buff)
    if type(buff) ~= "table" then return nil end
    local known = buff.spellID and Catalog(tonumber(buff.spellID)) or nil
    if known and known.category == "equipment" then return nil end
    if known and known.category == "potions" and known.itemID then
        if tonumber(buff.spellID) == 349981 then return 184937, "Chronoboon Displacer", 1 end
        return tonumber(known.itemID), known.name or buff.name, known.quality
    end
    if buff.itemID then
        local probe = {itemID=tonumber(buff.itemID), spellID=tonumber(buff.spellID),
            name=buff.name, itemName=buff.name, category="potions"}
        if U.IsConsumableWorldEvent(probe) then return tonumber(buff.itemID), buff.name end
    end
    local byName = CatalogByName(buff.name)
    if byName and byName.category == "potions" then return tonumber(byName.itemID), byName.name, byName.quality end
end

local function CurrentConsumableEvents(session)
    local source = session and session.worldUsage and session.worldUsage.events or {}
    local events, counts = {}, {}
    local function Key(guid, itemID) return tostring(guid or "unknown") .. ":" .. tostring(itemID or "") end
    local lastSeen = {}
    for _, entry in ipairs(source) do
        local include = true
        if U.IsConsumableWorldEvent(entry) and entry.itemID and entry.guid then
            local key = Key(entry.guid, tonumber(entry.itemID))
            local at = tonumber(entry.t) or 0
            local prior = lastSeen[key]
            -- Repair old records which retained duplicate CLEU/item-use signals.
            -- The same consumable cannot legitimately be used twice inside this
            -- short window (and FAP/LIP have much longer cooldowns).
            if prior ~= nil and math.abs(at - prior) <= .75 and not entry.legacyAuraEvidence then
                include = false
            else
                lastSeen[key] = at
                counts[key] = (counts[key] or 0) + math.max(1, tonumber(entry.count) or 1)
            end
        end
        if include then events[#events + 1] = entry end
    end

    local inferred = 0
    for _, enemy in pairs(session and session.enemies or {}) do
        local detected = enemy and enemy.detectedBuffs and enemy.detectedBuffs.consumables
        if type(detected) == "table" then
            local demand = {}
            for _, buff in pairs(detected) do
                local itemID, itemName, quality = ConsumableFromTrackedBuff(buff)
                if itemID then
                    local key = Key(enemy.guid, itemID)
                    if NOGGENFOGGER_AURA_SPELLS[tonumber(buff.spellID)] then
                        demand[key] = (demand[key] or 0) + 1
                    else
                        demand[key] = math.max(demand[key] or 0, 1)
                    end
                    while (counts[key] or 0) < demand[key] do
                        events[#events + 1] = {
                            t = tonumber(buff.appliedAt or buff.firstSeenAt) or 0,
                            guid = enemy.guid, actorName = enemy.name,
                            spellID = tonumber(buff.spellID), sourceSpellID = tonumber(buff.spellID),
                            sourceSpellName = buff.name, name = itemName or buff.name,
                            itemID = itemID, itemName = itemName or buff.name, quality = quality,
                            kind = "item", category = "potions", consumable = true, count = 1,
                            buffInferred = true,
                        }
                        counts[key] = (counts[key] or 0) + 1
                        inferred = inferred + 1
                    end
                end
            end
        end
    end
    return events, inferred
end

local function ActorMeta(session, guid, fallbackName)
    local identity = session.participants and session.participants[guid]
    return {
        guid = guid,
        name = identity and identity.name or fallbackName or (guid == session.playerGUID and session.playerName) or "Unknown",
        class = identity and identity.class or (guid == session.playerGUID and session.playerClass) or nil,
    }
end

function U.CaptureWorldConsumableCost(session, options)
    options = options or {}
    local capturedAt = tonumber(options.capturedAt) or (time and time() or 0)
    local snapshot = {version=1, captureModelVersion=2, capturedAt=capturedAt, totalCopper=0, pricedCount=0, unpricedCount=0,
        actors={}, priceSourceOrder={"Fixed vendor prices", "TradeSkillMaster DBMarket", "Auctionator"}}
    if options.backfilled then
        snapshot.backfilled = true
        snapshot.originalEncounterTimestamp = tonumber(options.originalEncounterTimestamp)
    end
    -- Reconcile the same retained casts, item uses and aura evidence used by
    -- historical repair before freezing a new encounter's prices.
    local evidence = session
    if not options.backfilled and not options.skipReconstruct and U.ReconstructLegacyWorldUsage then
        local enemies = {}
        for _, enemy in pairs(session.enemies or {}) do enemies[#enemies + 1] = enemy end
        local usage = U.ReconstructLegacyWorldUsage({enemies=enemies}, session)
        evidence = {worldUsage=usage, enemies=session.enemies}
    end
    local events, buffInferredCount = CurrentConsumableEvents(evidence)
    snapshot.buffInferredCount = tonumber(buffInferredCount) or 0
    if not events or #events == 0 then return snapshot end
    -- A shared cache can be supplied while migrating older records. That makes
    -- the migration a coherent one-time market snapshot: the same item receives
    -- the same captured value across every legacy encounter in that pass.
    local actorsByGUID, priceCache = {}, options.priceCache or {}

    local function Price(itemID)
        local cached = priceCache[itemID]
        if cached then return cached[1], cached[2], cached[3], cached[4], cached[5], cached[6] end
        local value, source, sourceKey, age, proxyItemID, proxyItemName = U.GetSnapshotPrice(itemID)
        priceCache[itemID] = {value or false, source, sourceKey, age, proxyItemID, proxyItemName}
        return value, source, sourceKey, age, proxyItemID, proxyItemName
    end

    for _, entry in ipairs(events) do
        if U.IsConsumableWorldEvent(entry) and not ZERO_GOLD_COST_ITEMS[tonumber(entry.itemID)] then
            local guid = entry.guid or "unknown"
            local actor = actorsByGUID[guid]
            if not actor then
                actor = ActorMeta(session, guid, entry.actorName)
                actor.totalCopper, actor.pricedCount, actor.unpricedCount, actor.items = 0, 0, 0, {}
                actor._items = {}
                actorsByGUID[guid] = actor
                snapshot.actors[#snapshot.actors + 1] = actor
            end
            local itemID = tonumber(entry.itemID)
            local key = tostring(itemID or entry.itemName or entry.name or entry.spellID or "unknown")
            local item = actor._items[key]
            if not item then
                local itemName = itemID and select(1, ItemInfo(itemID)) or nil
                item = {itemID=itemID, name=itemName or entry.itemName or entry.name or "Unknown consumable", count=0,
                    firstUsedAt=entry.t or 0}
                actor._items[key] = item
                actor.items[#actor.items + 1] = item
            end
            local count = math.max(1, tonumber(entry.count) or 1)
            item.count = item.count + count
            if itemID and item.unitCopper == nil and not item.priceChecked then
                item.priceChecked = true
                local price, source, sourceKey, age, proxyItemID, proxyItemName = Price(itemID)
                item.unitCopper, item.priceSource, item.priceSourceKey, item.priceAgeDays = price, source, sourceKey, age
                item.priceProxyItemID = proxyItemID
                item.priceProxyItemName = proxyItemName
                item.priceCapturedAt = snapshot.capturedAt
            end
        end
    end

    for _, actor in ipairs(snapshot.actors) do
        table.sort(actor.items, function(a, b)
            if (a.firstUsedAt or 0) ~= (b.firstUsedAt or 0) then return (a.firstUsedAt or 0) < (b.firstUsedAt or 0) end
            return tostring(a.name) < tostring(b.name)
        end)
        for _, item in ipairs(actor.items) do
            if item.unitCopper and item.unitCopper > 0 then
                item.totalCopper = item.unitCopper * item.count
                actor.totalCopper = actor.totalCopper + item.totalCopper
                actor.pricedCount = actor.pricedCount + item.count
                snapshot.totalCopper = snapshot.totalCopper + item.totalCopper
                snapshot.pricedCount = snapshot.pricedCount + item.count
            else
                item.unpriced = true
                actor.unpricedCount = actor.unpricedCount + item.count
                snapshot.unpricedCount = snapshot.unpricedCount + item.count
            end
        end
        actor._items = nil
    end
    snapshot.partial = snapshot.unpricedCount > 0 and true or nil
    return snapshot
end


function U.SanitizeConsumableCostSnapshot(record)
    local snapshot = type(record) == "table" and record.consumableCost or nil
    if type(snapshot) ~= "table" or type(snapshot.actors) ~= "table" then return false end
    local changed = false
    local actors = {}
    snapshot.totalCopper, snapshot.pricedCount, snapshot.unpricedCount = 0, 0, 0
    for _, actor in ipairs(snapshot.actors) do
        local items = {}
        actor.totalCopper, actor.pricedCount, actor.unpricedCount = 0, 0, 0
        for _, item in ipairs(type(actor.items) == "table" and actor.items or {}) do
            local zeroCost = ZERO_GOLD_COST_ITEMS[tonumber(item.itemID)]
            if not zeroCost then
                local name = tostring(item.name or "")
                zeroCost = name == "Mana Agate" or name == "Mana Jade" or name == "Mana Citrine" or name == "Mana Ruby"
            end
            if zeroCost then
                changed = true
            else
                items[#items + 1] = item
                local count = math.max(1, tonumber(item.count) or 1)
                if item.unpriced or not tonumber(item.unitCopper) or tonumber(item.unitCopper) <= 0 then
                    actor.unpricedCount = actor.unpricedCount + count
                    snapshot.unpricedCount = snapshot.unpricedCount + count
                else
                    local total = tonumber(item.totalCopper) or (tonumber(item.unitCopper) * count)
                    item.totalCopper = total
                    actor.totalCopper = actor.totalCopper + total
                    actor.pricedCount = actor.pricedCount + count
                    snapshot.totalCopper = snapshot.totalCopper + total
                    snapshot.pricedCount = snapshot.pricedCount + count
                end
            end
        end
        actor.items = items
        if #items > 0 then actors[#actors + 1] = actor elseif #((actor.items) or {}) == 0 then changed = true end
    end
    snapshot.actors = actors
    snapshot.partial = snapshot.unpricedCount > 0 and true or nil
    if changed then snapshot.zeroGoldCostSanitized = 1 end
    return changed
end

local function LegacyParticipants(record, saved)
    local participants = {}
    for guid, identity in pairs(type(saved.participants) == "table" and saved.participants or {}) do
        participants[guid] = identity
    end
    local function Add(guid, name, class)
        if not guid then return end
        local identity = participants[guid] or {}
        identity.name = identity.name or name
        identity.class = identity.class or class
        participants[guid] = identity
    end
    Add(record.playerGUID, record.playerName, record.playerClass)
    for _, enemy in ipairs(record.enemies or {}) do Add(enemy.guid, enemy.name, enemy.class) end
    for _, friendly in ipairs(record.friendlies or {}) do Add(friendly.guid, friendly.name, friendly.class) end
    return participants
end

local function ShallowCopy(source)
    local copy = {}
    for key, value in pairs(type(source) == "table" and source or {}) do copy[key] = value end
    return copy
end

local function CleanLegacyItemName(name)
    if type(name) ~= "string" or name == "" then return nil end
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local linked = name:match("|Hitem:[^|]+|h%[([^%]]+)%]|h")
    if linked then name = linked end
    name = name:gsub("^%[", ""):gsub("%]$", "")
    return name
end

CatalogByName = function(name)
    name = CleanLegacyItemName(name)
    if not name or not DP.UsageCatalog then return nil end
    for _, candidate in pairs(DP.UsageCatalog) do
        if type(candidate) == "table" and candidate.itemID and candidate.name == name then return candidate end
    end
end

local function NormalizeLegacyUsageEvent(entry)
    if type(entry) ~= "table" then return nil end
    local event = ShallowCopy(entry)
    local spellID = tonumber(event.spellID or event.sourceSpellID)
    local known = spellID and Catalog(spellID) or nil
    if known then
        -- Legacy rows occasionally retained a spell/effect ID in itemID. For
        -- catalogued consumables the catalog identity is authoritative, so use
        -- the real item ID rather than letting a stale field make the row vanish
        -- from the cost ledger while Items & Abilities can still display it.
        if known.itemID and known.category ~= "equipment" then
            event.itemID = tonumber(known.itemID)
        else
            event.itemID = tonumber(event.itemID) or tonumber(known.itemID)
        end
        event.itemName = known.name or event.itemName
        event.name = event.name or event.itemName or known.name
        event.quality = event.quality or known.quality
        event.category = known.category or event.category
        event.kind = event.kind or (known.itemID and "item" or nil)
        if known.category == "potions" or known.category == "reagents" then event.consumable = true end
    end
    local byName = CatalogByName(event.itemName or event.name or event.sourceSpellName)
    if byName and byName.category ~= "equipment" then
        -- Exact retained item names are another strong legacy signal. Canonicalize
        -- them even when an old row contains a bogus/non-item itemID.
        event.itemID = tonumber(byName.itemID) or tonumber(event.itemID)
        event.itemName = byName.name or event.itemName
        event.name = event.name or byName.name
        event.quality = event.quality or byName.quality
        event.category = byName.category or event.category
        event.kind = event.kind or "item"
        if byName.category == "potions" or byName.category == "reagents" then event.consumable = true end
    end
    -- The Supercharged aura is the retained CLEU evidence emitted when a base
    -- Chronoboon Displacer is consumed to store world buffs.  Price/count that
    -- original consumed item, not the generated Supercharged item.
    if spellID == 349981 and event.event == "SPELL_AURA_APPLIED" then
        event.itemID = 184937
        event.itemName = "Chronoboon Displacer"
        event.name = "Chronoboon Displacer"
        event.category = "potions"
        event.kind = "item"
        event.consumable = true
    end
    return event
end

local function ReconstructLegacyWorldUsage(record, saved)
    local usage = {version = 2, events = {}}
    local sources, retainedCounts, totalCounts = {}, {}, {}

    local function ItemKey(guid, itemID)
        return itemID and (tostring(guid or "unknown") .. ":" .. tostring(itemID)) or nil
    end

    local function AddEvent(rawEvent, source)
        local event = NormalizeLegacyUsageEvent(rawEvent)
        if not event then return false end
        local known = Catalog(tonumber(event.spellID or event.sourceSpellID))
        local legacyConsumable = event.itemID and
            ((known and known.category ~= "equipment" and (known.category == "potions" or known.category == "reagents")) or
             event.category == "potions" or event.category == "reagents" or event.consumable == true)
        if not legacyConsumable and not U.IsConsumableWorldEvent(event) then return false end
        event.legacySource = event.legacySource or source
        usage.events[#usage.events + 1] = event
        local key = ItemKey(event.guid, tonumber(event.itemID))
        local count = math.max(1, tonumber(event.count) or 1)
        if key then totalCounts[key] = (totalCounts[key] or 0) + count end
        if source == "worldUsage" and key then retainedCounts[key] = (retainedCounts[key] or 0) + count end
        if source then sources[source] = true end
        return true
    end

    -- Retained usage is the highest-confidence source. Normalize old rows first:
    -- early 0.21 builds often saved spell/name/category but omitted itemID, which
    -- made the pricing pass throw away rows that Items & Abilities could display.
    local retained = saved.worldUsage
    if type(retained) == "table" and type(retained.events) == "table" then
        for _, entry in ipairs(retained.events) do AddEvent(entry, "worldUsage") end
    end

    local log = type(saved.worldCombatLog) == "table" and saved.worldCombatLog or nil
    if log then
        local logEvidenceCounts, recentCasts = {}, {}
        local function EvidenceKey(guid, spellID)
            return tostring(guid or "unknown") .. ":" .. tostring(spellID or "")
        end
        local function AddLogCandidate(event)
            event = NormalizeLegacyUsageEvent(event)
            if not event or not U.IsConsumableWorldEvent(event) then return false end
            local key = ItemKey(event.guid, tonumber(event.itemID))
            if not key then return false end
            logEvidenceCounts[key] = (logEvidenceCounts[key] or 0) + math.max(1, tonumber(event.count) or 1)
            -- Reconcile, don't blanket-dedupe: if the retained table has one FAP
            -- but the combat log proves two, recover the missing second use.
            if logEvidenceCounts[key] > (retainedCounts[key] or 0) then return AddEvent(event, "worldCombatLog") end
            return false
        end

        for _, entry in ipairs(log) do
            local spellID, spellName = tonumber(entry.spellID), entry.spellName
            local eventType = entry.event
            local now = tonumber(entry.t) or 0
            local castKey = EvidenceKey(entry.sourceGUID, spellID)
            if eventType == "SPELL_CAST_SUCCESS" and entry.sourceGUID and spellID then
                recentCasts[castKey] = now
                local item = Catalog(spellID)
                if item then
                    AddLogCandidate({
                        event = eventType, t = now, guid = entry.sourceGUID, actorName = entry.sourceName,
                        targetGUID = entry.destGUID, targetName = entry.destName, sourceSpellID = spellID,
                        sourceSpellName = spellName, spellID = spellID, nameSpell = spellName,
                        name = spellName or item.name or ("Spell " .. spellID), kind = "item",
                        itemID = item.itemID, itemName = item.name, quality = item.quality,
                        category = EngineeringCategory(item.name) or item.category, count = 1,
                    })
                end
                local reagent = ReagentForSpell(spellID, spellName)
                if reagent then
                    AddLogCandidate({
                        event = eventType, t = now, guid = entry.sourceGUID, actorName = entry.sourceName,
                        targetGUID = entry.destGUID, targetName = entry.destName, sourceSpellID = spellID,
                        sourceSpellName = spellName, spellID = spellID, itemID = reagent.itemID,
                        itemName = reagent.name, name = reagent.name, kind = "reagent", category = "reagents",
                        consumable = true, count = reagent.count or 1,
                    })
                end
            elseif eventType == "SPELL_AURA_APPLIED" and entry.sourceGUID and spellID then
                local sameCast = recentCasts[castKey]
                local duplicateCast = sameCast and math.abs(now - sameCast) <= 3
                if NOGGENFOGGER_AURA_SPELLS[spellID] then
                    -- The item-use cast is 16589 while the three possible result
                    -- auras use 16591/16593/16595. If both signals survived, one
                    -- drink must not become two; if only distinct result auras
                    -- survived, each aura is proof of a separate drink.
                    local drinkAt = recentCasts[EvidenceKey(entry.sourceGUID, 16589)]
                    duplicateCast = drinkAt and math.abs(now - drinkAt) <= 4
                end
                if spellID == 349981 then
                    -- Charging uses spell 349858 and then applies aura 349981.
                    -- Old logs frequently retained only the aura; use it as a
                    -- fallback, but never count both signals for one Chronoboon.
                    local chargeAt = recentCasts[EvidenceKey(entry.sourceGUID, 349858)]
                    duplicateCast = chargeAt and math.abs(now - chargeAt) <= 10
                    if not duplicateCast then
                        AddLogCandidate({
                            event = eventType, t = now, guid = entry.sourceGUID, actorName = entry.sourceName,
                            targetGUID = entry.destGUID, targetName = entry.destName, sourceSpellID = spellID,
                            sourceSpellName = spellName, spellID = spellID, name = "Chronoboon Displacer",
                            itemID = 184937, itemName = "Chronoboon Displacer", kind = "item",
                            category = "potions", consumable = true, count = 1,
                        })
                    end
                elseif not duplicateCast then
                    -- Aura application is useful fallback evidence for old logs
                    -- which retained the buff but dropped the item cast itself.
                    local item = Catalog(spellID)
                    if item then
                        AddLogCandidate({
                            event = eventType, t = now, guid = entry.sourceGUID, actorName = entry.sourceName,
                            targetGUID = entry.destGUID, targetName = entry.destName, sourceSpellID = spellID,
                            sourceSpellName = spellName, spellID = spellID, name = spellName or item.name,
                            itemID = item.itemID, itemName = item.name, quality = item.quality,
                            kind = "item", category = EngineeringCategory(item.name) or item.category, count = 1,
                        })
                    end
                end
            end
        end
    end

    local function ConsumableFromBuff(buff)
        return ConsumableFromTrackedBuff(buff)
    end

    local inferredAuraCount = 0
    local auraDemand = {}
    local function AddBuffEvidence(enemy, buff)
        local itemID, itemName, quality = ConsumableFromBuff(buff)
        local key = itemID and ItemKey(enemy.guid, itemID) or nil
        if not itemID or not key then return end

        local spellID = tonumber(buff.spellID)
        if NOGGENFOGGER_AURA_SPELLS[spellID] then
            -- Different Noggenfogger result auras cannot come from one drink.
            -- Treat each distinct retained result as another lower-bound use.
            auraDemand[key] = (auraDemand[key] or 0) + 1
        else
            auraDemand[key] = math.max(auraDemand[key] or 0, 1)
        end
        if (totalCounts[key] or 0) >= auraDemand[key] then return end

        local event = {
            t = tonumber(buff.appliedAt or buff.firstSeenAt) or 0,
            guid = enemy.guid, actorName = enemy.name,
            spellID = spellID, sourceSpellID = spellID,
            sourceSpellName = buff.name, name = itemName or buff.name, itemID = itemID,
            itemName = itemName or buff.name, quality = quality,
            kind = "item", category = "potions", consumable = true, count = 1,
            legacyAuraEvidence = buff.gainedDuringFight and "gained" or "present",
        }
        if AddEvent(event, "auraEvidence") then inferredAuraCount = inferredAuraCount + 1 end
    end

    -- A retained consumable aura is a one-use lower-bound for old encounters.
    -- Deduplicate the same aura appearing in both detectedBuffs.consumables and
    -- detectedBuffs.all, but preserve distinct Noggenfogger result auras because
    -- each one proves another elixir was consumed.
    for _, enemy in ipairs(record.enemies or {}) do
        local detected = enemy.detectedBuffs
        if type(detected) == "table" then
            local unique = {}
            local function Collect(bucket)
                for _, buff in pairs(type(bucket) == "table" and bucket or {}) do
                    local identity = tostring(buff.spellID or "") .. ":" .. tostring(buff.name or "")
                    if not unique[identity] then unique[identity] = buff end
                end
            end
            Collect(detected.consumables)
            Collect(detected.all)
            for _, buff in pairs(unique) do AddBuffEvidence(enemy, buff) end
        end
    end

    if #usage.events == 0 then
        return nil, true, log and "worldCombatLog-empty" or "no-retained-events", 0
    end
    table.sort(usage.events, function(a, b) return (tonumber(a.t) or 0) < (tonumber(b.t) or 0) end)
    local sourceNames = {}
    for _, name in ipairs({"worldUsage", "worldCombatLog", "auraEvidence"}) do
        if sources[name] then sourceNames[#sourceNames + 1] = name end
    end
    return usage, true, table.concat(sourceNames, "+"), inferredAuraCount
end

-- WorldPvP's Items & Abilities pane uses this only to supplement missing
-- retained combat-log item uses in legacy records. Aura-inferred long buffs
-- remain in the dedicated ENEMY BUFFS viewer instead of being duplicated there.
U.ReconstructLegacyWorldUsage = ReconstructLegacyWorldUsage

-- A few legacy builds managed to freeze an empty cost snapshot even though the
-- same encounter still has item-use rows that Items & Abilities can render.
-- Treat that mismatch as repairable evidence instead of trusting the stale 0c
-- snapshot forever. This is intentionally conservative: once a snapshot contains
-- any priced or unpriced item, its captured prices stay frozen.
local function LegacyUsageFingerprint(usage)
    local counts = {}
    for _, event in ipairs(usage and usage.events or {}) do
        if U.IsConsumableWorldEvent(event) then
            local key = tostring(event.guid or "unknown") .. ":" .. tostring(event.itemID or event.itemName or event.name or "unknown")
            counts[key] = (counts[key] or 0) + math.max(1, tonumber(event.count) or 1)
        end
    end
    local keys = {}
    for key in pairs(counts) do keys[#keys + 1] = key end
    table.sort(keys)
    local out = {}
    for _, key in ipairs(keys) do out[#out + 1] = key .. "=" .. tostring(counts[key]) end
    return table.concat(out, "|")
end

local function SnapshotFingerprint(cost)
    local counts = {}
    for _, actor in ipairs(cost and cost.actors or {}) do
        for _, item in ipairs(actor.items or {}) do
            local key = tostring(actor.guid or "unknown") .. ":" .. tostring(item.itemID or item.name or "unknown")
            counts[key] = (counts[key] or 0) + math.max(1, tonumber(item.count) or 1)
        end
    end
    local keys = {}
    for key in pairs(counts) do keys[#keys + 1] = key end
    table.sort(keys)
    local out = {}
    for _, key in ipairs(keys) do out[#out + 1] = key .. "=" .. tostring(counts[key]) end
    return table.concat(out, "|")
end

function U.NeedsLegacyConsumableBackfill(record)
    if type(record) ~= "table" then return false end
    local cost = record.consumableCost
    if not cost then return true end
    if not cost.backfilled then
        -- Old live recordings could freeze a false zero before aura inference
        -- existed. Preserve all nonempty market snapshots, including unpriced ones.
        if (tonumber(cost.pricedCount) or 0) > 0 or (tonumber(cost.unpricedCount) or 0) > 0 or
                #(cost.actors or {}) > 0 then return false end
        local usage = ReconstructLegacyWorldUsage(record, record.session or {})
        return usage ~= nil and #(usage.events or {}) > 0
    end
    if (tonumber(cost.legacyBackfillVersion) or 0) < U.LEGACY_CONSUMABLE_BACKFILL_VERSION then return true end

    local saved = type(record.session) == "table" and record.session or {}
    local usage = ReconstructLegacyWorldUsage(record, saved)
    if usage and type(usage.events) == "table" and #usage.events > 0 then
        -- Repair partial legacy snapshots too, not only 0c snapshots. This catches
        -- the exact failure mode where Items & Abilities still shows four retained
        -- consumables but an older ledger snapshot contains only one participant/item.
        if LegacyUsageFingerprint(usage) ~= SnapshotFingerprint(cost) then return true end
        return false
    end
    return (tonumber(cost.pricedCount) or 0) == 0 and (tonumber(cost.unpricedCount) or 0) == 0 and false or false
end

function U.CaptureLegacyWorldConsumableCost(record, capturedAt, priceCache, force)
    if type(record) ~= "table" then return nil end
    if record.consumableCost and not force then return record.consumableCost end
    local saved = type(record.session) == "table" and record.session or {}
    local legacyUsage, reconstructed, reconstructedFrom, inferredAuraCount = ReconstructLegacyWorldUsage(record, saved)
    local legacySession = {
        worldPvP = true,
        worldUsage = legacyUsage,
        participants = LegacyParticipants(record, saved),
        playerGUID = record.playerGUID,
        playerName = record.playerName,
        playerClass = record.playerClass,
        playerLevel = record.playerLevel,
    }
    local snapshot = U.CaptureWorldConsumableCost(legacySession, {
        capturedAt = capturedAt,
        priceCache = priceCache,
        backfilled = true,
        originalEncounterTimestamp = record.timestamp,
    })
    snapshot.legacyBackfillVersion = U.LEGACY_CONSUMABLE_BACKFILL_VERSION
    snapshot.legacyReconstructed = reconstructed and true or nil
    snapshot.legacyReconstructedFrom = reconstructedFrom
    snapshot.legacyAuraInferredCount = tonumber(inferredAuraCount) or 0
    snapshot.priceSourceReady = U.HasSnapshotPriceSource and U.HasSnapshotPriceSource() or nil
    return snapshot
end


-- Duel opponent aura snapshot -------------------------------------------------
-- Duels have a single rival, so retain a compact snapshot of the opponent's
-- long-duration buffs whenever Rivals has a usable target/mouseover token. The
-- five-minute floor deliberately excludes reactive/in-fight effects such as
-- Power Word: Shield, Blessing of Freedom/Protection, HoTs, forms and stances.
local DUEL_BUFF_MIN_DURATION = 300
local DUEL_BUFF_EXCLUDED = {
    ["Lightning Shield"] = true,
}

local function DuelUnitMatches(session, unit)
    if not (session and unit and UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit)) then return false end
    local identity = session.identity
    local guid = UnitGUID and UnitGUID(unit)
    if identity and identity.guid and guid then return identity.guid == guid end
    local name, realm
    if UnitName then name, realm = UnitName(unit) end
    if not name then return false end
    if realm and realm ~= "" then name = name .. "-" .. realm end
    if DP.Parser and DP.Parser.SameName then return DP.Parser.SameName(name, session.opponent or (identity and identity.name)) end
    return ShortName(name) == ShortName(session.opponent or (identity and identity.name))
end

function U.CaptureDuelBuffs(session)
    if not session then return false end
    local unit
    for _, candidate in ipairs({"target", "mouseover"}) do
        if DuelUnitMatches(session, candidate) then unit = candidate; break end
    end
    if not unit or not UnitBuff then return false end

    -- The same live token is also our best chance to retain a durable portrait
    -- identity for Duel Details. Older duel records only kept class/level.
    session.identity = session.identity or {}
    local identity = session.identity
    identity.guid = identity.guid or (UnitGUID and UnitGUID(unit))
    local name, realm
    if UnitName then name, realm = UnitName(unit) end
    if name and not identity.name then
        if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() or nil end
        identity.name = realm and realm ~= "" and (name .. "-" .. realm) or name
    end
    local class
    if UnitClass then local _; _, class = UnitClass(unit) end
    local localizedRace, raceFile
    if UnitRace then localizedRace, raceFile = UnitRace(unit) end
    identity.class = identity.class or class
    identity.level = identity.level or (UnitLevel and UnitLevel(unit))
    identity.localizedRace = identity.localizedRace or localizedRace
    identity.race = identity.race or raceFile or localizedRace
    identity.raceFile = identity.raceFile or raceFile
    identity.sex = identity.sex or (UnitSex and UnitSex(unit))
    identity.portraitSex = identity.portraitSex or identity.sex
    identity.faction = identity.faction or (UnitFactionGroup and UnitFactionGroup(unit))
    identity.portraitDisplayID = identity.portraitDisplayID or (UnitCreatureDisplayID and UnitCreatureDisplayID(unit))

    session.duelBuffs = session.duelBuffs or {version = 1, opponent = {}}
    local bucket = session.duelBuffs.opponent
    local captured = false
    for index = 1, 64 do
        local name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellID = UnitBuff(unit, index)
        if not name then break end
        duration = tonumber(duration) or 0
        if duration >= DUEL_BUFF_MIN_DURATION and not DUEL_BUFF_EXCLUDED[name] then
            local key = tostring(spellID or name)
            local existing = bucket[key] or {}
            existing.name = name
            existing.icon = icon or existing.icon
            existing.count = tonumber(count) or existing.count or 0
            existing.duration = math.max(duration, tonumber(existing.duration) or 0)
            existing.expirationTime = tonumber(expirationTime) or existing.expirationTime
            existing.source = source or existing.source
            existing.isStealable = isStealable and true or existing.isStealable
            existing.spellID = tonumber(spellID) or existing.spellID
            existing.firstSeenAt = existing.firstSeenAt or (GetTime and GetTime() or 0)
            bucket[key] = existing
            captured = true
        end
    end
    return captured
end

-- Freeze duel consumable spend with the same price engine used by World PvP.
-- Duel usage historically stored one collapsed row per ability, so old records
-- can still be priced from retained item identity/count even when exact per-use
-- timestamps were not available.
function U.CaptureDuelConsumableCost(record)
    if type(record) ~= "table" then return nil end
    if type(record.duelConsumableCost) == "table" then return record.duelConsumableCost end
    local session = record.session or {}
    local usage = session.usage or {}
    local playerGUID = session.playerGUID or record.playerGUID or "duel-player"
    local opponentGUID = session.identity and session.identity.guid or ("duel-opponent:" .. tostring(record.opponent or "unknown"))
    local opponentName = (session.identity and session.identity.name) or record.opponent or "Opponent"
    local fake = {
        worldPvP = true,
        playerGUID = playerGUID,
        playerName = session.playerName or "You",
        playerClass = session.playerClass or record.playerClass,
        participants = {
            [playerGUID] = {name = session.playerName or "You", class = session.playerClass or record.playerClass},
            [opponentGUID] = {name = opponentName, class = session.identity and session.identity.class},
        },
        worldUsage = {version = 2, events = {}},
    }
    local function AddSide(sideName, guid, actorName)
        for _, entry in pairs(usage[sideName] or {}) do
            local display = U.Describe and U.Describe(entry, record) or nil
            local event = {
                t = tonumber(entry.t) or math.max(0, (tonumber(entry.observedAt) or 0) - (tonumber(session.estimatedStartAt) or tonumber(session.acceptedAt) or 0)),
                guid = guid, actorName = actorName,
                spellID = tonumber(entry.spellID), itemID = tonumber(entry.itemID) or (display and tonumber(display.itemID)),
                itemName = entry.itemName, name = entry.itemName or entry.name,
                category = (display and display.category) or entry.category,
                kind = entry.kind, count = math.max(1, tonumber(entry.count) or 1),
                consumable = entry.consumable,
            }
            fake.worldUsage.events[#fake.worldUsage.events + 1] = event
        end
    end
    AddSide("player", playerGUID, session.playerName or "You")
    AddSide("opponent", opponentGUID, opponentName)
    local snapshot = U.CaptureWorldConsumableCost(fake, {capturedAt = record.timestamp, skipReconstruct = true})
    record.duelConsumableCost = snapshot
    return snapshot
end

function U.Describe(entry, record)
    local known = ResolveInsignia(entry.spellID, record and record.session, entry.guid, entry.nameSpell or entry.name, record) or Catalog(entry.spellID)
    local id = entry.itemID or (known and known.itemID)
    local name, quality, itemClass
    -- Preserve multiple returns when resolving client item metadata.
    if id then
        local link, level, required, kind, subtype, stack, equip, icon, price
        name, link, quality, level, required, kind, subtype, stack, equip, icon, price, itemClass = ItemInfo(id)
    end
    name = name or entry.itemName or (known and known.name)
    quality = quality or entry.quality or (known and known.quality) or 1
    local category = (known and known.forceItem and known.category) or entry.category or
        (known and known.category) or (itemClass and (itemClass == 0 and "potions" or "equipment"))
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
        if U.RefreshDetailContent then U.RefreshDetailContent() end
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
    if window.logScroll.RefreshRivalsScrollbar then window.logScroll:RefreshRivalsScrollbar(true)
    elseif window.logScroll.SetVerticalScroll then window.logScroll:SetVerticalScroll(0) end
end

local function BindRivalsScroll(scroll, body, bar, step)
    step = step or 28
    bar:SetValueStep(step)
    bar:SetOnValueChanged(function(self, value)
        if self._syncing then return end
        local range = math.max(0, (body:GetHeight() or 0) - (scroll:GetHeight() or 0))
        value = math.max(0, math.min(range, value or 0))
        scroll:SetVerticalScroll(value)
    end)
    function scroll:RefreshRivalsScrollbar(reset)
        local range = math.max(0, (body:GetHeight() or 0) - (self:GetHeight() or 0))
        local current = reset and 0 or math.max(0, math.min(range, self:GetVerticalScroll() or 0))
        bar._syncing = true; bar:SetMinMaxValues(0, range); bar:SetValue(current); bar._syncing = false
        bar:SetShown(range > 1)
        if reset then self:SetVerticalScroll(0) end
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local low, high = bar:GetMinMaxValues()
        bar:SetValue(math.max(low or 0, math.min(high or 0, (bar:GetValue() or 0) - delta * step)))
    end)
    scroll:RefreshRivalsScrollbar(true)
end

-- Duel Details now uses the same three-tab visual language as World PvP:
-- Summary / Items & Abilities / Combat Log, the same 650px window, the same
-- 20px content guides, the same Rivals scrollbar, compact participant selector,
-- rock-plaque category dividers, and a dedicated ENEMY BUFFS header card.
local DUEL_DETAIL_HEIGHT = 480
local DUEL_CATEGORY_ORDER = {potions=1, engineering=2, reagents=3, equipment=4, cooldowns=5, racials=6}
local DUEL_CATEGORY_LABEL = {
    potions="POTIONS/CONSUMABLES", engineering="ENGINEERING GADGETS", reagents="REAGENTS",
    equipment="EQUIPMENT", cooldowns="COOLDOWNS (≥3 MIN)", racials="RACIALS",
}

local DUEL_WORLD_BUFF_NAMES = {
    ["Rallying Cry of the Dragonslayer"] = true, ["Spirit of Zandalar"] = true,
    ["Warchief's Blessing"] = true, ["Songflower Serenade"] = true,
    ["Fengus' Ferocity"] = true, ["Mol'dar's Moxie"] = true, ["Slip'kik's Savvy"] = true,
}
local DUEL_CLASS_BUFF_TERMS = {
    "fortitude", "divine spirit", "shadow protection", "mark of the wild", "gift of the wild", "thorns",
    "blessing of kings", "blessing of might", "blessing of wisdom", "blessing of salvation", "blessing of light",
    "blessing of sanctuary", "arcane intellect", "arcane brilliance", "mage armor", "ice armor", "frost armor",
    "demon armor", "demon skin", "inner fire",
}

local function DuelBuffPriority(buff)
    local name = tostring(buff and buff.name or "")
    local lower = name:lower()
    if DUEL_WORLD_BUFF_NAMES[name] then return 1 end
    if lower:find("flask", 1, true) then return 2 end
    if lower:find("zanza", 1, true) then return 3 end
    if lower:find("noggenfogger", 1, true) then return 7 end
    if lower:find("elixir", 1, true) or lower:find("juju", 1, true) or lower:find("firewater", 1, true) then return 4 end
    if lower:find("protection", 1, true) and not lower:find("shadow protection", 1, true) then return 5 end
    for _, term in ipairs(DUEL_CLASS_BUFF_TERMS) do
        if lower:find(term, 1, true) then return 6 end
    end
    return 7
end

local function DuelSortedBuffs(record)
    local bucket = record and record.session and record.session.duelBuffs and record.session.duelBuffs.opponent or {}
    local buffs = {}
    for _, buff in pairs(bucket or {}) do
        if type(buff) == "table" and tostring(buff.name or "") ~= "Lightning Shield" and (tonumber(buff.duration) or 0) >= 300 then
            buffs[#buffs + 1] = buff
        end
    end
    table.sort(buffs, function(a, b)
        local ap, bp = DuelBuffPriority(a), DuelBuffPriority(b)
        if ap ~= bp then return ap < bp end
        local an, bn = tostring(a.name or ""), tostring(b.name or "")
        if an ~= bn then return an < bn end
        return (tonumber(a.spellID) or 0) < (tonumber(b.spellID) or 0)
    end)
    return buffs
end

local function DuelIdentity(record)
    local identity = record and record.session and record.session.identity or {}
    if identity.guid and GetPlayerInfoByGUID and (not identity.class or not identity.race) then
        local _, class, localizedRace, raceFile, sex = GetPlayerInfoByGUID(identity.guid)
        identity.class = identity.class or class
        identity.localizedRace = identity.localizedRace or localizedRace
        identity.race = identity.race or raceFile or localizedRace
        identity.raceFile = identity.raceFile or raceFile
        identity.sex = identity.sex or sex
        identity.portraitSex = identity.portraitSex or sex
    end
    identity.name = identity.name or (record and record.opponent) or "Opponent"
    return identity
end

local function DuelMatchupStats(record)
    local stats = {wins=0, losses=0, ratedWins=0, ratedLosses=0, classWins=0, classLosses=0, duels=0}
    if not record then return stats end
    local identity = DuelIdentity(record)
    local guid = identity.guid
    local name = ShortName(identity.name or record.opponent):lower()
    local class = identity.class
    for _, prior in ipairs((DP.AllDuelRecords and DP.AllDuelRecords()) or {}) do
        if prior and prior.status == "matched-request-history-only" then
            local pident = prior.session and prior.session.identity or {}
            local same = guid and pident.guid and guid == pident.guid
            if not same then same = ShortName(pident.name or prior.opponent):lower() == name end
            if same then
                stats.duels = stats.duels + 1
                if prior.won then stats.wins = stats.wins + 1 else stats.losses = stats.losses + 1 end
                if DP.Views and DP.Views.Mode and DP.Views.Mode(prior) == "Rated" then
                    if prior.won then stats.ratedWins = stats.ratedWins + 1 else stats.ratedLosses = stats.ratedLosses + 1 end
                end
            end
            if class and pident.class == class then
                if prior.won then stats.classWins = stats.classWins + 1 else stats.classLosses = stats.classLosses + 1 end
            end
        end
    end
    return stats
end

local function CopperText(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    if gold > 0 then return string.format("%dg %02ds %02dc", gold, silver, cop) end
    if silver > 0 then return string.format("%ds %02dc", silver, cop) end
    return string.format("%dc", cop)
end

local function DuelCostForActor(snapshot, guid, name)
    for _, actor in ipairs(snapshot and snapshot.actors or {}) do
        if (guid and actor.guid == guid) or (name and ShortName(actor.name):lower() == ShortName(name):lower()) then return actor end
    end
end

local function ApplyCompactDropChrome(frame, alpha)
    if frame.SetBackdrop then
        frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\UI-SliderBar-Border",
            edgeSize=8, insets={left=2,right=2,top=2,bottom=2}})
        frame:SetBackdropColor(.025,.03,.04,alpha or .98)
        frame:SetBackdropBorderColor(1,.82,.42,.92)
    else
        local bg = frame:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.025,.03,.04,alpha or .98)
    end
end

local function CreateCompactDuelDropDown(parent, menuParent, width, getOptions, onSelect)
    local control = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    control:SetSize(width,26); ApplyCompactDropChrome(control,.98)
    control.textLabel = control:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    control.textLabel:SetPoint("LEFT",7,0); control.textLabel:SetPoint("RIGHT",-22,0); control.textLabel:SetJustifyH("CENTER"); control.textLabel:SetWordWrap(false)
    control.arrow = CreateFrame("Button",nil,control); control.arrow:SetSize(18,18); control.arrow:SetPoint("RIGHT",1,0)
    control.arrow:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    control.arrow:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
    control.arrow:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight","ADD")
    control.menu = CreateFrame("Frame",nil,menuParent or parent,BackdropTemplateMixin and "BackdropTemplate" or nil)
    control.menu:SetWidth(width); control.menu:SetPoint("TOPLEFT",control,"BOTTOMLEFT",0,0); ApplyCompactDropChrome(control.menu,.99)
    if control.menu.SetFrameLevel and menuParent and menuParent.GetFrameLevel then control.menu:SetFrameLevel(menuParent:GetFrameLevel()+40) end
    control.menuRows={}; control.menu:Hide()
    function control:SetSelectedValue(value,text)
        self.selectedValue=value
        if not text then for _,o in ipairs((getOptions and getOptions()) or {}) do if o.value==value then text=o.text; break end end end
        self.textLabel:SetText(text or tostring(value or ""))
    end
    function control:SelectValue(value)
        local text
        for _,o in ipairs((getOptions and getOptions()) or {}) do if o.value==value then text=o.text; break end end
        self:SetSelectedValue(value,text); self.menu:Hide(); if onSelect then onSelect(value) end
    end
    function control:RefreshMenu()
        local options={}
        for _,o in ipairs((getOptions and getOptions()) or {}) do if o.value~=self.selectedValue then options[#options+1]=o end end
        local rowH,pad=20,2; self.menu:SetHeight(math.max(8,#options*rowH+pad*2))
        for i,o in ipairs(options) do
            local row=self.menuRows[i]
            if not row then
                row=CreateFrame("Button",nil,self.menu); row:SetHeight(rowH)
                row.highlight=row:CreateTexture(nil,"HIGHLIGHT"); row.highlight:SetPoint("TOPLEFT",1,-1); row.highlight:SetPoint("BOTTOMRIGHT",-1,1); row.highlight:SetColorTexture(1,.72,.18,.14)
                row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.label:SetPoint("LEFT",6,0); row.label:SetPoint("RIGHT",-6,0); row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(false)
                self.menuRows[i]=row
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",pad,-(pad+(i-1)*rowH)); row:SetPoint("TOPRIGHT",-pad,-(pad+(i-1)*rowH))
            row.value=o.value; row.label:SetText(o.text or tostring(o.value or "")); row:SetScript("OnClick",function(clicked) control:SelectValue(clicked.value) end); row:Show()
        end
        for i=#options+1,#self.menuRows do self.menuRows[i]:Hide() end
    end
    control:SetScript("OnClick",function(self) if self.menu:IsShown() then self.menu:Hide() else self:RefreshMenu(); self.menu:Show() end end)
    control.arrow:SetScript("OnClick",function() control:Click() end)
    control:SetScript("OnHide",function(self) if self.menu then self.menu:Hide() end end)
    return control
end

local function DuelUsageEvents(record, filter)
    local session = record and record.session or {}
    local usage = session.usage or {}
    local identity = DuelIdentity(record)
    local playerGUID = session.playerGUID or record.playerGUID or "duel-player"
    local opponentGUID = identity.guid or ("duel-opponent:" .. tostring(record.opponent or "unknown"))
    local out = {}
    local function Add(side, guid, actorName, class)
        if filter ~= "all" and filter ~= guid then return end
        for _, entry in pairs(usage[side] or {}) do
            local display = U.Describe(entry, record)
            out[#out+1] = {
                t = tonumber(entry.t) or math.max(0,(tonumber(entry.observedAt) or 0)-(tonumber(session.estimatedStartAt) or tonumber(session.acceptedAt) or 0)),
                guid=guid, actorName=actorName, class=class, targetName=entry.targetName,
                entry=entry, display=display, category=display.category or entry.category or "cooldowns",
            }
        end
    end
    Add("player", playerGUID, "You", record.playerClass or session.playerClass)
    Add("opponent", opponentGUID, ShortName(identity.name or record.opponent), identity.class)
    table.sort(out,function(a,b)
        local ao,bo=DUEL_CATEGORY_ORDER[a.category] or 99,DUEL_CATEGORY_ORDER[b.category] or 99
        if ao~=bo then return ao<bo end
        if a.t~=b.t then return a.t<b.t end
        return tostring(a.actorName)<tostring(b.actorName)
    end)
    return out
end

local function EnsureDuelUsageRow(window,index,kind)
    local width=window.usageTableWidth or 592
    local row=window.usageRows[index]
    if row and row.kind==kind then
        row:SetWidth(width); if row.categoryBorder then row.categoryBorder:ClearAllPoints(); row.categoryBorder:SetAllPoints(row) end
        if row.label then row.label:SetWidth(width-20) end
        return row
    end
    if row then row:Hide() end
    row=CreateFrame("Button",nil,window.usageBody); row.kind=kind; row:SetSize(width,kind=="category" and 26 or 22)
    row.bg=row:CreateTexture(nil,"BACKGROUND"); row.bg:SetAllPoints()
    if kind=="category" then
        row.bg:SetColorTexture(.022,.018,.014,.98)
        row.rock=row:CreateTexture(nil,"BACKGROUND"); row.rock:SetPoint("TOPLEFT",3,-3); row.rock:SetPoint("BOTTOMRIGHT",-3,3); row.rock:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock"); row.rock:SetVertexColor(.22,.18,.12,.54)
        row.categoryBorder=DP.Theme.PlaqueBorder(row,width,26,12); row.categoryBorder:ClearAllPoints(); row.categoryBorder:SetAllPoints(row); row.categoryBorder:EnableMouse(false)
        row.label=row.categoryBorder:CreateFontString(nil,"OVERLAY","GameFontNormal"); row.label:SetPoint("CENTER"); row.label:SetWidth(width-20); row.label:SetJustifyH("CENTER")
        local fp,fs=row.label:GetFont(); if fp and fs then row.label:SetFont(fp,fs,"OUTLINE") end; row.label:SetShadowColor(0,0,0,1); row.label:SetShadowOffset(1,-2)
    else
        row.time=row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); row.time:SetPoint("TOPLEFT",6,-5); row.time:SetWidth(48); row.time:SetJustifyH("LEFT")
        row.player=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.player:SetPoint("TOPLEFT",60,-5); row.player:SetWidth(106); row.player:SetJustifyH("LEFT"); row.player:SetWordWrap(false)
        row.used=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.used:SetPoint("TOPLEFT",178,-5); row.used:SetWidth(281); row.used:SetJustifyH("LEFT"); row.used:SetWordWrap(false)
        row.target=row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); row.target:SetPoint("TOPLEFT",473,-5); row.target:SetWidth(113); row.target:SetJustifyH("LEFT"); row.target:SetWordWrap(false)
        row:SetScript("OnEnter",function(self)
            if not self.entry then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            if self.entry.itemID then GameTooltip:SetHyperlink("item:"..tostring(self.entry.itemID))
            elseif self.entry.spellID and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(self.entry.spellID)
            else GameTooltip:SetText(self.used:GetText() or "Ability") end
            GameTooltip:AddLine("Shift-click to link in chat",.55,.6,.68,true); GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:SetScript("OnClick",function(self)
            if not (self.entry and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink) then return end
            local link=EntryChatLink(self.entry); if link then ChatEdit_InsertLink(link) end
        end)
    end
    window.usageRows[index]=row
    return row
end

local function DuelCombinedCombatLog(record)
    local log=record and record.session and record.session.combatLog
    if not log then return "|cff8f98a6Combat log capture was not available for this duel.|r" end
    local entries={}
    for _,key in ipairs({"myActions","toMe"}) do
        for _,entry in ipairs(log[key] or {}) do
            entries[#entries+1]={t=type(entry)=="table" and tonumber(entry.t) or 0,text=type(entry)=="table" and entry.text or tostring(entry),key=key}
        end
    end
    table.sort(entries,function(a,b) if a.t~=b.t then return a.t<b.t end return a.key<b.key end)
    if #entries==0 then return "|cff8f98a6No qualifying combat-log events were recorded.|r" end
    local lines={}
    for _,entry in ipairs(entries) do
        lines[#lines+1]=string.format("|cff8f98a6+%05.1fs|r  %s",entry.t or 0,ColorDuelCombatText(record,entry.key,entry.text or ""))
    end
    if log.myTruncated or log.toMeTruncated then lines[#lines+1]="|cff8f98a6… additional events were omitted.|r" end
    return table.concat(lines,"\n")
end

local function CreateDuelPortrait(frame)
    frame.portraitFrame=CreateFrame("Frame",nil,frame); frame.portraitFrame:SetSize(64,64)
    frame.portrait=frame.portraitFrame:CreateTexture(nil,"ARTWORK"); frame.portrait:SetSize(52,52); frame.portrait:SetPoint("CENTER")
    if frame.portrait.AddMaskTexture and frame.portraitFrame.CreateMaskTexture then
        frame.portraitMask=frame.portraitFrame:CreateMaskTexture(); frame.portraitMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE"); frame.portraitMask:SetSize(52,52); frame.portraitMask:SetPoint("CENTER"); frame.portrait:AddMaskTexture(frame.portraitMask)
    end
    frame.portraitModel=CreateFrame("DressUpModel",nil,frame.portraitFrame); frame.portraitModel:SetPoint("CENTER",0,-1); frame.portraitModel:SetSize(50,50); frame.portraitModel:Hide()
    frame.portraitRing=frame.portraitFrame:CreateTexture(nil,"OVERLAY"); frame.portraitRing:SetPoint("CENTER"); frame.portraitRing:SetSize(64,64)
    local ok=frame.portraitRing.SetAtlas and pcall(frame.portraitRing.SetAtlas,frame.portraitRing,"AdventureMap-combatally-ring",false)
    if not ok then frame.portraitRing:SetTexture("Interface\\Buttons\\UI-Quickslot2") end
    return frame
end

local function ApplyDuelPortrait(frame,record)
    local identity=DuelIdentity(record)
    if DP.WorldPvP and DP.WorldPvP.ApplyOpponentPortrait then
        DP.WorldPvP.ApplyOpponentPortrait(frame,identity)
    else
        frame.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); frame.portrait:SetTexCoord(.08,.92,.08,.92); frame.portrait:Show()
    end
end

local function RefreshDuelBuffBox(window,record)
    local buffs=DuelSortedBuffs(record)
    window.buffEmpty:SetShown(#buffs==0)
    for i,buff in ipairs(buffs) do
        local button=window.buffIcons[i]
        if not button then
            button=CreateFrame("Button",nil,window.buffBody); button:SetSize(30,30)
            button.icon=button:CreateTexture(nil,"ARTWORK"); button.icon:SetAllPoints(); button.icon:SetTexCoord(.08,.92,.08,.92)
            button.border=button:CreateTexture(nil,"OVERLAY"); button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2"); button.border:SetPoint("TOPLEFT",-2,2); button.border:SetPoint("BOTTOMRIGHT",2,-2)
            button:SetScript("OnEnter",function(self)
                local b=self.buff; if not b then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                if b.spellID and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(b.spellID) else GameTooltip:SetText(b.name or "Buff") end
                if b.duration then GameTooltip:AddLine(string.format("Observed duration: %.0f min",b.duration/60),.65,.7,.76) end
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave",function() GameTooltip:Hide() end)
            window.buffIcons[i]=button
        end
        local col=(i-1)%5; local row=math.floor((i-1)/5)
        button:ClearAllPoints(); button:SetPoint("TOPLEFT",2+col*33,-2-row*33); button.buff=buff
        local texture=buff.icon or (buff.spellID and GetSpellTexture and GetSpellTexture(buff.spellID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
        button.icon:SetTexture(texture); button:Show()
    end
    for i=#buffs+1,#window.buffIcons do window.buffIcons[i]:Hide(); window.buffIcons[i].buff=nil end
    local rows=math.max(1,math.ceil(#buffs/5)); window.buffBody:SetHeight(math.max(72,rows*33+2))
    if window.buffScroll.RefreshRivalsScrollbar then window.buffScroll:RefreshRivalsScrollbar(true) end
end

local function RefreshDuelSummary(window,record)
    local identity=DuelIdentity(record)
    local stats=DuelMatchupStats(record)
    local className=identity.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[identity.class]) or identity.class) or "Unknown class"
    local race=tostring(identity.localizedRace or identity.race or "Unknown race")
    local level=identity.level and ("Lv "..tostring(identity.level)) or "Lv ?"
    local spec=OpponentSpecLabel(record)
    window.rivalName:SetText(OpponentNameColored(record,false))
    window.rivalMeta:SetText(string.format("%s %s %s%s",level,race,className,spec and (" • "..spec) or ""))
    window.rivalRecord:SetText(string.format("Your record  |cff65e6ad%d|r-|cffff8888%d|r  •  %d duels",stats.wins,stats.losses,stats.duels))
    ApplyDuelPortrait(window,record)

    local won=record.won and true or false
    window.duelResult:SetText(won and "|cff65e6adWIN|r" or "|cffff8888LOSS|r")
    window.duelMode:SetText((DP.Views and DP.Views.Mode and DP.Views.Mode(record) or "Duel") .. "  •  " .. (DP.Views and DP.Views.EvidenceLabel and DP.Views.EvidenceLabel(record) or "Local Record"))
    window.duelDuration:SetText(record.duration and string.format("%.2fs",record.duration) or "Duration unknown")
    window.duelDate:SetText(record.timestamp and date("%m/%d/%y %H:%M",record.timestamp) or "")

    local d=record.ratingDecision
    if d and d.before~=nil and d.after~=nil then
        local delta=(d.after or 0)-(d.before or 0); local color=delta>0 and "|cff65e6ad" or delta<0 and "|cffff8888" or "|cffadb5c2"
        window.summaryRatingValue:SetText(string.format("%.1f > %.1f  %s%+.2f|r",d.before,d.after,color,delta))
        if d.matchup and d.matchup.before~=nil then
            window.summaryMatchupRating:SetText(string.format("%s matchup  %.1f > %.1f",className,d.matchup.before or 0,d.matchup.after or d.matchup.before or 0))
        else window.summaryMatchupRating:SetText("No class-matchup rating change") end
    else
        window.summaryRatingValue:SetText("No rating impact")
        window.summaryMatchupRating:SetText(record.modeFailure or (d and DP.Views and DP.Views.Reason and DP.Views.Reason(d)) or "History only")
    end

    local snapshot=record.duelConsumableCost
    if not snapshot and U.CaptureDuelConsumableCost then snapshot=U.CaptureDuelConsumableCost(record) end
    local playerGUID=record.session and record.session.playerGUID
    local opponentGUID=identity.guid
    local you=DuelCostForActor(snapshot,playerGUID,record.session and record.session.playerName)
    local rival=DuelCostForActor(snapshot,opponentGUID,identity.name)
    window.summaryConsumedValue:SetText(string.format("You %s  •  Rival %s",CopperText(you and you.totalCopper),CopperText(rival and rival.totalCopper)))
    window.summaryConsumedHit.snapshot=snapshot

    window.matchupOpponent:SetText(DP.Theme.ClassName(ShortName(identity.name),identity.class))
    window.matchupLifetime:SetText(string.format("Lifetime                     |cff65e6ad%d|r-|cffff8888%d|r",stats.wins,stats.losses))
    window.matchupRated:SetText(string.format("Rated                         |cff65e6ad%d|r-|cffff8888%d|r",stats.ratedWins,stats.ratedLosses))
    window.matchupClass:SetText(string.format("vs %s                 |cff65e6ad%d|r-|cffff8888%d|r",className,stats.classWins,stats.classLosses))
    window.matchupEvidence:SetText((DP.Views and DP.Views.EvidenceLabel and DP.Views.EvidenceLabel(record) or "Local Record") .. (record.verification and record.verification.matchId and ("  •  "..tostring(record.verification.matchId)) or ""))
end

local function RefreshDuelUsage(window,record)
    local filter=window.participantFilter or "all"; window.filter:SetSelectedValue(filter)
    local events=DuelUsageEvents(record,filter)
    local y,rowIndex,dataIndex,lastCategory=0,0,0,nil
    for _,rendered in ipairs(events) do
        if rendered.category~=lastCategory then
            rowIndex=rowIndex+1; local header=EnsureDuelUsageRow(window,rowIndex,"category")
            header:ClearAllPoints(); header:SetPoint("TOPLEFT",0,-y); header.label:SetText("|cffffd86a"..(DUEL_CATEGORY_LABEL[rendered.category] or tostring(rendered.category):upper()).."|r"); header:Show(); y=y+26; lastCategory=rendered.category
        end
        rowIndex=rowIndex+1; dataIndex=dataIndex+1; local row=EnsureDuelUsageRow(window,rowIndex,"entry")
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-y); row.bg:SetColorTexture(dataIndex%2==0 and .085 or .035,dataIndex%2==0 and .085 or .035,dataIndex%2==0 and .085 or .035,dataIndex%2==0 and .72 or .82)
        row.time:SetText(string.format("%05.1f",rendered.t or 0)); row.player:SetText(DP.Theme.ClassName(rendered.actorName,rendered.class)); row.used:SetText(rendered.display.text or rendered.entry.name or "Unknown")
        row.target:SetText(rendered.targetName and ShortName(rendered.targetName) or "—")
        row.entry={itemID=rendered.display.itemID or rendered.entry.itemID,spellID=rendered.display.spellID or rendered.entry.spellID}; row:Show(); y=y+22
    end
    if #events==0 then
        rowIndex=1; local row=EnsureDuelUsageRow(window,rowIndex,"category"); row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,0); row.label:SetText("|cffadb5c2No tracked item, engineering, racial, or ≥3 minute cooldown use for this filter.|r"); row:Show(); y=26
    end
    for i=rowIndex+1,#window.usageRows do window.usageRows[i]:Hide() end
    window.usageBody:SetHeight(math.max(1,y)); if window.usageScroll.RefreshRivalsScrollbar then window.usageScroll:RefreshRivalsScrollbar(true) end
end

local function RefreshDuelCombatLog(window,record)
    window.logText:SetText(DuelCombinedCombatLog(record))
    local height=window.logText.GetStringHeight and window.logText:GetStringHeight() or 100
    window.logBody:SetHeight(math.max(1,(height or 100)+10)); if window.logScroll.RefreshRivalsScrollbar then window.logScroll:RefreshRivalsScrollbar(true) end
end

local function SelectDuelDetailTab(window,key)
    window.activeTab=key
    DP.Theme.SelectDataTab(window.summaryTab,key=="summary","Summary")
    DP.Theme.SelectDataTab(window.usageTab,key=="usage","Items & Abilities")
    DP.Theme.SelectDataTab(window.logTab,key=="log","Combat Log")
    window.summaryStatsTitle:SetShown(key=="summary"); window.summaryStatsBox:SetShown(key=="summary"); window.matchupTitle:SetShown(key=="summary"); window.matchupBox:SetShown(key=="summary")
    window.usageHeader:SetShown(key=="usage"); window.usageScroll:SetShown(key=="usage"); window.usageScrollbar:SetShown(key=="usage" and window.usageScrollbar._needed==true); window.filter:SetShown(key=="usage")
    window.logBox:SetShown(key=="log")
    if window.record then
        if key=="summary" then RefreshDuelSummary(window,window.record)
        elseif key=="usage" then RefreshDuelUsage(window,window.record)
        else RefreshDuelCombatLog(window,window.record) end
    end
end

local function EnsureDetailWindow()
    if U.window then return U.window end
    local window=CreateFrame("Frame","RivalsDuelUsageDetails",UIParent,BackdropTemplateMixin and "BackdropTemplate" or nil)
    window:SetSize(650,DUEL_DETAIL_HEIGHT); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG"); window:SetMovable(true); window:EnableMouse(true)
    if window.SetClampedToScreen then window:SetClampedToScreen(true) end
    window.bg=window:CreateTexture(nil,"BACKGROUND"); window.bg:SetPoint("TOPLEFT",1,-1); window.bg:SetPoint("BOTTOMRIGHT",-1,1); window.bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock"); window.bg:SetVertexColor(.28,.30,.33,.97)
    local border=DP.Theme.Border(window,0,0,650,DUEL_DETAIL_HEIGHT); border:ClearAllPoints(); border:SetAllPoints(window); border:EnableMouse(false)
    local header=DP.Theme.PlaqueHeader(window,360,"Duel Details","GameFontNormal"); header:SetPoint("BOTTOM",window,"TOP",0,-4); header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() window:StartMoving() end); header:SetScript("OnDragStop",function() window:StopMovingOrSizing() end); window.header=header
    local close=CreateFrame("Button",nil,window,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-2,-2); close:SetScript("OnClick",function() window:Hide() end); window.close=close
    window:SetScript("OnHide",function(self) self.activeTab="summary"; GameTooltip:Hide(); U.HideHistoryTooltip() end)

    -- Rival header card (same footprint as World PvP's map card).
    window.rivalBox=CreateFrame("Frame",nil,window); window.rivalBox:SetPoint("TOPLEFT",20,-34); window.rivalBox:SetSize(230,142)
    window.rivalBox.bg=window.rivalBox:CreateTexture(nil,"BACKGROUND"); window.rivalBox.bg:SetAllPoints(); window.rivalBox.bg:SetColorTexture(.03,.036,.045,.58); DP.Theme.Border(window.rivalBox,0,0,230,142)
    window.rivalLabel=window.rivalBox:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); window.rivalLabel:SetPoint("TOPLEFT",10,-8); window.rivalLabel:SetText("RIVAL")
    CreateDuelPortrait(window); window.portraitFrame:SetParent(window.rivalBox); window.portraitFrame:ClearAllPoints(); window.portraitFrame:SetPoint("TOPLEFT",10,-30)
    window.rivalName=window.rivalBox:CreateFontString(nil,"OVERLAY","GameFontNormal"); window.rivalName:SetPoint("TOPLEFT",82,-32); window.rivalName:SetWidth(136); window.rivalName:SetJustifyH("LEFT")
    window.rivalMeta=window.rivalBox:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); window.rivalMeta:SetPoint("TOPLEFT",82,-51); window.rivalMeta:SetWidth(136); window.rivalMeta:SetHeight(45); window.rivalMeta:SetJustifyH("LEFT"); window.rivalMeta:SetJustifyV("TOP"); window.rivalMeta:SetWordWrap(true)
    window.rivalRecord=window.rivalBox:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); window.rivalRecord:SetPoint("BOTTOMLEFT",10,10); window.rivalRecord:SetWidth(210); window.rivalRecord:SetJustifyH("LEFT")

    window.duelBox=CreateFrame("Frame",nil,window); window.duelBox:SetPoint("TOPLEFT",260,-34); window.duelBox:SetSize(164,142)
    window.duelBox.bg=window.duelBox:CreateTexture(nil,"BACKGROUND"); window.duelBox.bg:SetAllPoints(); window.duelBox.bg:SetColorTexture(.03,.036,.045,.58); DP.Theme.Border(window.duelBox,0,0,164,142)
    local duelLabel=window.duelBox:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); duelLabel:SetPoint("TOPLEFT",10,-8); duelLabel:SetText("DUEL")
    window.duelResult=window.duelBox:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); window.duelResult:SetPoint("TOPLEFT",10,-30); window.duelResult:SetWidth(144); window.duelResult:SetJustifyH("LEFT")
    window.duelMode=window.duelBox:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); window.duelMode:SetPoint("TOPLEFT",10,-58); window.duelMode:SetWidth(144); window.duelMode:SetJustifyH("LEFT"); window.duelMode:SetWordWrap(true)
    window.duelDuration=window.duelBox:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); window.duelDuration:SetPoint("TOPLEFT",10,-88); window.duelDuration:SetWidth(144); window.duelDuration:SetJustifyH("LEFT")
    window.duelDate=window.duelBox:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); window.duelDate:SetPoint("BOTTOMLEFT",10,10); window.duelDate:SetWidth(144); window.duelDate:SetJustifyH("LEFT")

    window.buffBox=CreateFrame("Frame",nil,window); window.buffBox:SetPoint("TOPLEFT",434,-34); window.buffBox:SetSize(196,142)
    window.buffBox.bg=window.buffBox:CreateTexture(nil,"BACKGROUND"); window.buffBox.bg:SetAllPoints(); window.buffBox.bg:SetColorTexture(.03,.036,.045,.58); DP.Theme.Border(window.buffBox,0,0,196,142)
    window.buffTitle=window.buffBox:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); window.buffTitle:SetPoint("TOPLEFT",8,-8); window.buffTitle:SetText("ENEMY BUFFS")
    window.buffEmpty=window.buffBox:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); window.buffEmpty:SetPoint("CENTER",0,-10); window.buffEmpty:SetWidth(180); window.buffEmpty:SetJustifyH("CENTER"); window.buffEmpty:SetText("No long buffs observed")
    window.buffScroll=CreateFrame("ScrollFrame",nil,window.buffBox); window.buffScroll:SetPoint("TOPLEFT",8,-29); window.buffScroll:SetPoint("BOTTOMRIGHT",-17,8)
    if window.buffScroll.SetClipsChildren then window.buffScroll:SetClipsChildren(true) end
    window.buffBody=CreateFrame("Frame",nil,window.buffScroll); window.buffBody:SetSize(166,72); window.buffScroll:SetScrollChild(window.buffBody); window.buffIcons={}
    window.buffScrollbar=DP.Theme.ScrollBar(window.buffBox,30); window.buffScrollbar:SetPoint("TOPRIGHT",-1,-35); window.buffScrollbar:SetPoint("BOTTOMRIGHT",-1,8)
    BindRivalsScroll(window.buffScroll,window.buffBody,window.buffScrollbar,30)

    window.summaryTab=DP.Theme.DataTab(window,"Summary",20,-191,110,function() SelectDuelDetailTab(window,"summary") end)
    window.usageTab=DP.Theme.DataTab(window,"Items & Abilities",131,-191,150,function() SelectDuelDetailTab(window,"usage") end)
    window.logTab=DP.Theme.DataTab(window,"Combat Log",282,-191,120,function() SelectDuelDetailTab(window,"log") end)
    window.content=CreateFrame("Frame",nil,window); window.content:SetPoint("TOPLEFT",20,-221); window.content:SetPoint("BOTTOMRIGHT",-20,18)

    -- Summary uses the exact World PvP two-column footprint.
    window.summaryStatsTitle=window.content:CreateFontString(nil,"OVERLAY","GameFontNormal"); window.summaryStatsTitle:SetPoint("TOPLEFT",0,-4); window.summaryStatsTitle:SetText("DUEL STATS")
    window.summaryStatsBox=CreateFrame("Frame",nil,window.content); window.summaryStatsBox:SetPoint("TOPLEFT",0,-24); window.summaryStatsBox:SetSize(220,206)
    window.summaryStatsBox.bg=window.summaryStatsBox:CreateTexture(nil,"BACKGROUND"); window.summaryStatsBox.bg:SetAllPoints(); window.summaryStatsBox.bg:SetColorTexture(.035,.045,.06,.78); DP.Theme.Border(window.summaryStatsBox,0,0,220,206)
    local ratingLabel=window.summaryStatsBox:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); ratingLabel:SetPoint("TOPLEFT",10,-10); ratingLabel:SetText("RATING")
    window.summaryRatingValue=window.summaryStatsBox:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); window.summaryRatingValue:SetPoint("TOPLEFT",10,-29); window.summaryRatingValue:SetWidth(200); window.summaryRatingValue:SetJustifyH("LEFT")
    window.summaryMatchupRating=window.summaryStatsBox:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); window.summaryMatchupRating:SetPoint("TOPLEFT",10,-55); window.summaryMatchupRating:SetWidth(200); window.summaryMatchupRating:SetHeight(36); window.summaryMatchupRating:SetJustifyH("LEFT"); window.summaryMatchupRating:SetWordWrap(true)
    local rule=window.summaryStatsBox:CreateTexture(nil,"ARTWORK"); rule:SetPoint("TOPLEFT",9,-96); rule:SetPoint("TOPRIGHT",-9,-96); rule:SetHeight(1); rule:SetColorTexture(.34,.26,.18,.65)
    window.summaryConsumedHit=CreateFrame("Frame",nil,window.summaryStatsBox); window.summaryConsumedHit:SetPoint("TOPLEFT",4,-104); window.summaryConsumedHit:SetPoint("BOTTOMRIGHT",-4,4); window.summaryConsumedHit:EnableMouse(true)
    window.summaryConsumedHit.bg=window.summaryConsumedHit:CreateTexture(nil,"BACKGROUND"); window.summaryConsumedHit.bg:SetAllPoints(); window.summaryConsumedHit.bg:SetColorTexture(.025,.03,.04,.72)
    local consumedLabel=window.summaryConsumedHit:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); consumedLabel:SetPoint("TOPLEFT",6,-7); consumedLabel:SetText("CONSUMED")
    window.summaryConsumedValue=window.summaryConsumedHit:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); window.summaryConsumedValue:SetPoint("TOPLEFT",6,-28); window.summaryConsumedValue:SetWidth(196); window.summaryConsumedValue:SetJustifyH("LEFT"); window.summaryConsumedValue:SetWordWrap(true)
    window.summaryConsumedHit:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText("Estimated consumable spend")
        local snapshot=self.snapshot
        if not snapshot or #(snapshot.actors or {})==0 then GameTooltip:AddLine("No priced consumable use was retained for this duel.",.65,.7,.76,true)
        else
            for _,actor in ipairs(snapshot.actors or {}) do
                GameTooltip:AddLine(" "); GameTooltip:AddDoubleLine(ShortName(actor.name),CopperText(actor.totalCopper),1,.82,.42,1,1,1)
                for _,item in ipairs(actor.items or {}) do GameTooltip:AddDoubleLine((item.name or "Item")..((item.count or 1)>1 and (" x"..item.count) or ""),item.totalCopper and CopperText(item.totalCopper) or "unpriced",.82,.84,.88,.72,.76,.82) end
            end
        end
        GameTooltip:Show()
    end); window.summaryConsumedHit:SetScript("OnLeave",function() GameTooltip:Hide() end)

    window.matchupTitle=window.content:CreateFontString(nil,"OVERLAY","GameFontNormal"); window.matchupTitle:SetPoint("TOPLEFT",236,-4); window.matchupTitle:SetText("MATCHUP")
    window.matchupBox=CreateFrame("Frame",nil,window.content); window.matchupBox:SetPoint("TOPLEFT",236,-24); window.matchupBox:SetSize(374,206)
    window.matchupBox.bg=window.matchupBox:CreateTexture(nil,"BACKGROUND"); window.matchupBox.bg:SetAllPoints(); window.matchupBox.bg:SetColorTexture(.035,.045,.06,.72); DP.Theme.Border(window.matchupBox,0,0,374,206)
    window.matchupOpponent=window.matchupBox:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); window.matchupOpponent:SetPoint("TOPLEFT",12,-12); window.matchupOpponent:SetWidth(350); window.matchupOpponent:SetJustifyH("LEFT")
    window.matchupLifetime=window.matchupBox:CreateFontString(nil,"OVERLAY","GameFontHighlight"); window.matchupLifetime:SetPoint("TOPLEFT",12,-47); window.matchupLifetime:SetWidth(350); window.matchupLifetime:SetJustifyH("LEFT")
    window.matchupRated=window.matchupBox:CreateFontString(nil,"OVERLAY","GameFontHighlight"); window.matchupRated:SetPoint("TOPLEFT",12,-76); window.matchupRated:SetWidth(350); window.matchupRated:SetJustifyH("LEFT")
    window.matchupClass=window.matchupBox:CreateFontString(nil,"OVERLAY","GameFontHighlight"); window.matchupClass:SetPoint("TOPLEFT",12,-105); window.matchupClass:SetWidth(350); window.matchupClass:SetJustifyH("LEFT")
    local mRule=window.matchupBox:CreateTexture(nil,"ARTWORK"); mRule:SetPoint("TOPLEFT",12,-139); mRule:SetPoint("TOPRIGHT",-12,-139); mRule:SetHeight(1); mRule:SetColorTexture(.34,.26,.18,.65)
    window.matchupEvidence=window.matchupBox:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); window.matchupEvidence:SetPoint("TOPLEFT",12,-153); window.matchupEvidence:SetWidth(350); window.matchupEvidence:SetHeight(40); window.matchupEvidence:SetJustifyH("LEFT"); window.matchupEvidence:SetWordWrap(true)

    window.filter=CreateCompactDuelDropDown(window,window,180,function()
        local record=window.record; if not record then return {{text="All participants",value="all"}} end
        local identity=DuelIdentity(record); local s=record.session or {}; local pg=s.playerGUID or record.playerGUID or "duel-player"; local og=identity.guid or ("duel-opponent:"..tostring(record.opponent or "unknown"))
        return {{text="All participants",value="all"},{text=DP.Theme.ClassName("You",record.playerClass or s.playerClass),value=pg},{text=DP.Theme.ClassName(ShortName(identity.name),identity.class),value=og}}
    end,function(value) window.participantFilter=value or "all"; if window.record then RefreshDuelUsage(window,window.record) end end)
    window.filter:SetPoint("TOPRIGHT",window,"TOPRIGHT",-28,-191)

    window.usageTableWidth=592
    window.usageHeader=CreateFrame("Frame",nil,window.content); window.usageHeader:SetPoint("TOPLEFT",0,-8); window.usageHeader:SetSize(592,24)
    window.usageHeader.bg=window.usageHeader:CreateTexture(nil,"BACKGROUND"); window.usageHeader.bg:SetAllPoints(); window.usageHeader.bg:SetColorTexture(.08,.09,.11,.95)
    window.tableHeader=window.usageHeader
    window.entryButtons={}
    window.usageHeaderLabels={}; local headers={{"Time",0,54},{"Player",54,118},{"Used",172,295},{"Target",467,125}}
    for i,h in ipairs(headers) do local t=window.usageHeader:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); t:SetPoint("TOPLEFT",h[2]+6,-6); t:SetWidth(h[3]-10); t:SetJustifyH("LEFT"); t:SetText(h[1]); window.usageHeaderLabels[i]=t end
    window.usageScroll=CreateFrame("ScrollFrame",nil,window.content); window.usageScroll:SetPoint("TOPLEFT",0,-32); window.usageScroll:SetPoint("BOTTOMRIGHT",-18,8)
    if window.usageScroll.SetClipsChildren then window.usageScroll:SetClipsChildren(true) end
    window.usageBody=CreateFrame("Frame",nil,window.usageScroll); window.usageBody:SetSize(592,1); window.usageScroll:SetScrollChild(window.usageBody); window.usageRows={}
    window.usageScrollbar=DP.Theme.ScrollBar(window.content,30); window.usageScrollbar:SetPoint("TOPRIGHT",0,-32); window.usageScrollbar:SetPoint("BOTTOMRIGHT",0,8)
    BindRivalsScroll(window.usageScroll,window.usageBody,window.usageScrollbar,30)
    local oldUsageRefresh=window.usageScroll.RefreshRivalsScrollbar
    function window.usageScroll:RefreshRivalsScrollbar(reset)
        local range=math.max(0,(window.usageBody:GetHeight() or 0)-(self:GetHeight() or 0)); local needs=range>1; local width=needs and 592 or 610; window.usageTableWidth=width
        self:ClearAllPoints(); self:SetPoint("TOPLEFT",window.content,"TOPLEFT",0,-32); self:SetPoint("BOTTOMRIGHT",window.content,"BOTTOMRIGHT",needs and -18 or 0,8)
        window.usageHeader:SetWidth(width); window.usageBody:SetWidth(width); window.usageHeaderLabels[4]:SetWidth((width-467)-10)
        for _,row in ipairs(window.usageRows) do row:SetWidth(width); if row.categoryBorder then row.categoryBorder:ClearAllPoints(); row.categoryBorder:SetAllPoints(row) end; if row.label then row.label:SetWidth(width-20) end; if row.target then row.target:SetWidth(math.max(40,width-479)) end end
        window.usageScrollbar._needed=needs; window.usageScrollbar._syncing=true; window.usageScrollbar:SetMinMaxValues(0,range); window.usageScrollbar:SetValue(reset and 0 or math.min(range,self:GetVerticalScroll() or 0)); window.usageScrollbar._syncing=false; window.usageScrollbar:SetShown(needs and window.activeTab=="usage")
        if reset then self:SetVerticalScroll(0) end
    end

    window.logBox=CreateFrame("Frame",nil,window.content); window.logBox:SetPoint("TOPLEFT",0,-8); window.logBox:SetPoint("BOTTOMRIGHT",0,8)
    window.logBox.bg=window.logBox:CreateTexture(nil,"BACKGROUND"); window.logBox.bg:SetAllPoints(); window.logBox.bg:SetColorTexture(.025,.032,.043,.78); local lb=DP.Theme.Border(window.logBox,0,0,598,322); lb:ClearAllPoints(); lb:SetAllPoints(window.logBox); lb:EnableMouse(false)
    window.logScroll=CreateFrame("ScrollFrame",nil,window.logBox); window.logScroll:SetPoint("TOPLEFT",10,-10); window.logScroll:SetPoint("BOTTOMRIGHT",-17,10)
    window.logBody=CreateFrame("Frame",nil,window.logScroll); window.logBody:SetSize(583,1); window.logScroll:SetScrollChild(window.logBody)
    window.logText=window.logBody:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); window.logText:SetPoint("TOPLEFT",4,-4); window.logText:SetWidth(575); window.logText:SetJustifyH("LEFT"); window.logText:SetJustifyV("TOP"); window.logText:SetWordWrap(true)
    window.logScrollbar=DP.Theme.ScrollBar(window.logBox,30); window.logScrollbar:SetPoint("TOPRIGHT",-4,-8); window.logScrollbar:SetPoint("BOTTOMRIGHT",-4,8); BindRivalsScroll(window.logScroll,window.logBody,window.logScrollbar,30)

    UISpecialFrames[#UISpecialFrames+1]="RivalsDuelUsageDetails"; U.window=window
    return window
end

function U.RefreshDetailContent()
    local window=U.window
    if not (window and window.record) then return end
    RefreshDuelBuffBox(window,window.record)
    RefreshDuelSummary(window,window.record)
    SelectDuelDetailTab(window,window.activeTab or "summary")
end

function U.OpenDetails(record)
    if DP.WorldPvP and DP.WorldPvP.details and DP.WorldPvP.details:IsShown() then DP.WorldPvP.details:Hide() end
    local window=EnsureDetailWindow(); window.record=record; window.participantFilter="all"
    RefreshDuelBuffBox(window,record); RefreshDuelSummary(window,record); window:Show(); SelectDuelDetailTab(window,window.activeTab or "summary")
end
