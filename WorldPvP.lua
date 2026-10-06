local _, DP = ...

local W = {}
DP.WorldPvP = W

-- PLAYER_REGEN_ENABLED is the primary encounter boundary. Keep a short grace
-- period for Classic quirks (Vanish/Feign/CC/combat-drop flicker), but do not
-- let unrelated players arriving during the old 60-second inactivity window
-- accumulate into one giant encounter. The 60-second timer remains only as a
-- hard safety net for cases where combat-state events are missed.
-- Keep module-wide constants in one table instead of one top-level local per
-- value. WorldPvP.lua is large enough that separate locals can hit Classic's
-- 200-local-variable limit for the file chunk even though the individual
-- functions are small.
local CFG = {
    COMBAT_END_GRACE = 10,
    INACTIVITY_TIMEOUT = 60,
    ALL_ENEMIES_DEAD_GRACE = 6,
    ENEMY_PRESSURE_WINDOW = 12,
    MAX_ENCOUNTERS = 250,
    MAX_WORLD_LOG = 2000,
    WPVP_SCREENSHOT_KILL_DELAY = 0.20,
    BAND = bit and bit.band or bit32 and bit32.band,
    DIVINE_SHIELD_SPELLS = {[642] = true, [1020] = true},
    HEARTHSTONE_SPELLS = {[8690] = true},
    BUBBLE_HEARTH_WINDOW = 20,
    -- Gnomish Mind Control Cap can temporarily charm a hostile player and make
    -- PLAYER_REGEN_ENABLED fire in the middle of the same fight. Keep that
    -- encounter alive through the control/backfire window instead of splitting it.
    MIND_CONTROL_GRACE = 45,
    -- Full-duration hard immunity can also create a legitimate combat drop while
    -- the fight is still plainly in progress. Track the aura itself rather than
    -- globally lengthening every encounter boundary. Ice Block is 10 seconds;
    -- the small ceiling/after-fade buffers cover CLEU/regen ordering jitter.
    COMBAT_SUSPENSION_MAX = 13,
    COMBAT_SUSPENSION_POST_GRACE = 3,
}

function W.IsMindControlCapSpell(spellID, spellName)
    local id = tonumber(spellID)
    if id == 13180 or id == 13181 then return true end
    return type(spellName) == "string" and spellName == "Gnomish Mind Control Cap"
end

function W.MindControlUseInfo(entry, participants)
    if not entry or not W.IsMindControlCapSpell(entry.spellID, entry.spellName) then return nil end
    local event = tostring(entry.event or "")
    if event ~= "SPELL_CAST_SUCCESS" and event ~= "SPELL_AURA_APPLIED" and event ~= "SPELL_AURA_REFRESH" then return nil end
    participants = participants or {}
    if entry.itemUserGUID then
        return entry.itemUserGUID, entry.itemUserName, entry.mindControlBackfire and true or false
    end
    if entry.sourceGUID and participants[entry.sourceGUID] then
        return entry.sourceGUID, entry.sourceName, false
    end
    if entry.destGUID and participants[entry.destGUID] then
        return entry.destGUID, entry.destName, true
    end
    return nil
end

-- Some defensive states can drop both players out of combat without ending the
-- actual PvP engagement. Keep this deliberately narrow: these are encounter
-- suspension mechanics, not a reason to make the normal combat-end grace longer.
function W.IsCombatSuspensionSpell(spellID, spellName)
    return spellName == "Ice Block"
end

function W.UpdateCombatSuspension(session, info, spellID, spellName)
    if not session or not info or not W.IsCombatSuspensionSpell(spellID, spellName) then return end
    local event = tostring(info[2] or "")
    local guid = info[8] or info[4]
    if not guid or not session.enemies or not session.enemies[guid] then return end
    local now = GetTime()
    session.combatSuspensions = session.combatSuspensions or {}
    if event == "SPELL_CAST_SUCCESS" or event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
        session.combatSuspensions[guid] = math.max(tonumber(session.combatSuspensions[guid]) or 0, now + CFG.COMBAT_SUSPENSION_MAX)
        session.lastActivity = now
    elseif event == "SPELL_AURA_REMOVED" then
        session.combatSuspensions[guid] = nil
        session.combatSuspensionGraceUntil = math.max(tonumber(session.combatSuspensionGraceUntil) or 0, now + CFG.COMBAT_SUSPENSION_POST_GRACE)
        session.lastActivity = now
    end
end

function W.CombatSuspensionActive(session, now)
    if not session then return false end
    now = now or GetTime()
    local active = false
    for guid, expiresAt in pairs(session.combatSuspensions or {}) do
        local enemy = session.enemies and session.enemies[guid]
        if enemy and not enemy.died and now < (tonumber(expiresAt) or 0) then
            active = true
        else
            session.combatSuspensions[guid] = nil
        end
    end
    return active or now < (tonumber(session.combatSuspensionGraceUntil) or 0)
end


-- Buff intelligence ----------------------------------------------------------
-- World buffs are keyed by spell ID so the tracker is localization-safe.  The
-- name table is only a fallback for unusual client builds/variants.
local WORLD_BUFFS = {
    [22888] = "Rallying Cry of the Dragonslayer",
    [16609] = "Warchief's Blessing",
    [24425] = "Spirit of Zandalar",
    [15366] = "Songflower Serenade",
    [22817] = "Fengus' Ferocity",
    [22818] = "Mol'dar's Moxie",
    [22820] = "Slip'kik's Savvy",
    [23735] = "Sayge's Dark Fortune of Strength",
    [23736] = "Sayge's Dark Fortune of Agility",
    [23737] = "Sayge's Dark Fortune of Stamina",
    [23738] = "Sayge's Dark Fortune of Spirit",
    [23766] = "Sayge's Dark Fortune of Intelligence",
    [23767] = "Sayge's Dark Fortune of Armor",
    [23768] = "Sayge's Dark Fortune of Damage",
    [23769] = "Sayge's Dark Fortune of Resistance",
    [29534] = "Traces of Silithyst",
    [1216566] = "Traces of Silithyst",
    -- Anniversary/alternate-era variants still count when present on an Era
    -- client.  Exact-name fallback below also catches future spell-ID variants.

}
local WORLD_BUFF_NAMES = {}
for _, name in pairs(WORLD_BUFFS) do WORLD_BUFF_NAMES[name] = true end

-- Long-lived class buffs belong in ENEMY BUFFS too, but this stays deliberately
-- curated instead of dumping every helpful aura. Known long buffs may be
-- observed only through combat-log removal events, without a duration snapshot.
-- The allowlist excludes forms/stances/aspects with indefinite durations and short
-- in-fight effects such as Power Word: Shield, Blessing of Freedom/Protection,
-- Regrowth, etc. The exact-name list is rank-agnostic because UnitAura returns
-- the base spell name rather than the rank text.
local LONG_CLASS_BUFF_NAMES = {
    -- Priest
    ["Power Word: Fortitude"] = true, ["Prayer of Fortitude"] = true,
    ["Divine Spirit"] = true, ["Prayer of Spirit"] = true,
    ["Shadow Protection"] = true, ["Prayer of Shadow Protection"] = true,
    ["Inner Fire"] = true, ["Fear Ward"] = true,
    ["Touch of Weakness"] = true, ["Shadowguard"] = true,

    -- Druid
    ["Mark of the Wild"] = true, ["Gift of the Wild"] = true,
    ["Thorns"] = true, ["Omen of Clarity"] = true,

    -- Paladin. Short emergency blessings are intentionally absent.
    ["Blessing of Might"] = true, ["Greater Blessing of Might"] = true,
    ["Blessing of Wisdom"] = true, ["Greater Blessing of Wisdom"] = true,
    ["Blessing of Kings"] = true, ["Greater Blessing of Kings"] = true,
    ["Blessing of Salvation"] = true, ["Greater Blessing of Salvation"] = true,
    ["Blessing of Light"] = true, ["Greater Blessing of Light"] = true,
    ["Blessing of Sanctuary"] = true, ["Greater Blessing of Sanctuary"] = true,

    -- Mage
    ["Arcane Intellect"] = true, ["Arcane Brilliance"] = true,
    ["Frost Armor"] = true, ["Ice Armor"] = true, ["Mage Armor"] = true,
    ["Dampen Magic"] = true, ["Amplify Magic"] = true,

    -- Warlock
    ["Demon Skin"] = true, ["Demon Armor"] = true,
    ["Unending Breath"] = true, ["Detect Lesser Invisibility"] = true,
    ["Detect Invisibility"] = true, ["Detect Greater Invisibility"] = true,

    -- Shaman
    ["Water Breathing"] = true, ["Water Walking"] = true,
}

local function IsLongClassBuff(entry)
    if not entry or not LONG_CLASS_BUFF_NAMES[entry.name] then return false end
    local duration = tonumber(entry.duration)
    -- CLEU removal events have no duration. The curated spell list still
    -- identifies long class buffs when no UnitAura snapshot was available.
    return not duration or duration >= 300
end

local function LooksLikeConsumableBuff(name)
    if type(name) ~= "string" or name == "" then return false end
    return name:find("Flask", 1, true) ~= nil or
        name:find("Elixir", 1, true) ~= nil or
        name:find("Juju", 1, true) ~= nil or
        name:find("Zanza", 1, true) ~= nil or
        name == "Winterfall Firewater" or
        name == "R.O.I.D.S." or name == "Ground Scorpok Assay" or
        name == "Cerebral Cortex Compound" or name == "Gizzard Gum" or
        name == "Lung Juice Cocktail" or name == "Gift of Arthas"
end

local function TrackedBuffMeta(spellID, name)
    local worldName = spellID and WORLD_BUFFS[spellID]
    if worldName then return "world", worldName, nil end
    if WORLD_BUFF_NAMES[name] or (type(name) == "string" and name:find("Rallying Cry of the Dragonslayer", 1, true)) then
        return "world", name, nil
    end
    local known = spellID and DP.UsageCatalog and DP.UsageCatalog[spellID]
    if known and known.category == "potions" then
        return "consumable", known.name or name or ("Spell " .. tostring(spellID)), known.itemID
    end
    if LooksLikeConsumableBuff(name) then return "consumable", name, known and known.itemID end
    return nil
end

local function EnsureDetectedBuffs(enemy)
    enemy.detectedBuffs = enemy.detectedBuffs or {}
    local buffs = enemy.detectedBuffs
    buffs.world = buffs.world or {}
    buffs.consumables = buffs.consumables or {}
    buffs.all = buffs.all or {}
    return buffs
end

local function BuffBucket(enemy, category)
    local buffs = EnsureDetectedBuffs(enemy)
    return category == "world" and buffs.world or buffs.consumables
end

local function SpellIcon(spellID)
    if not spellID then return nil end
    if GetSpellTexture then
        local ok, texture = pcall(GetSpellTexture, spellID)
        if ok and texture then return texture end
    end
    if GetSpellInfo then
        local ok, _, _, texture = pcall(GetSpellInfo, spellID)
        if ok then return texture end
    end
end

local function RecordEnemyAura(session, enemy, spellID, name, icon, duration, expirationTime, source, state)
    if not session or not enemy or (not spellID and not name) then return end
    local buffs = EnsureDetectedBuffs(enemy)
    local key = tostring(spellID or name or "unknown")
    local now = math.max(0, GetTime() - (session.startedElapsed or GetTime()))
    local entry = buffs.all[key]
    if not entry then
        entry = {
            spellID = spellID,
            name = name or (spellID and ("Spell " .. tostring(spellID))) or "Unknown buff",
            icon = icon or SpellIcon(spellID),
            firstSeenAt = now,
            source = source,
        }
        buffs.all[key] = entry
    end
    entry.lastSeenAt = now
    entry.source = entry.source or source
    if icon and not entry.icon then entry.icon = icon end
    if duration and duration > 0 then entry.duration = duration end
    if expirationTime and expirationTime > 0 then entry.expirationTime = expirationTime end
    if source == "snapshot" then
        entry.presentWhenObserved = true
        if now <= 3 then entry.activeAtEngagement = true end
    elseif state == "applied" then
        entry.gainedDuringFight = true
        entry.appliedAt = entry.appliedAt or now
    elseif state == "removed" then
        entry.removedAt = now
    end
    return entry
end

local function RecordEnemyBuff(session, enemy, category, spellID, name, itemID, source, state)
    if not session or not enemy or not category then return end
    local bucket = BuffBucket(enemy, category)
    local key = tostring(spellID or name or "unknown")
    local now = math.max(0, GetTime() - (session.startedElapsed or GetTime()))
    local entry = bucket[key]
    if not entry then
        entry = {spellID = spellID, name = name or (spellID and ("Spell " .. tostring(spellID))) or "Unknown buff",
            itemID = itemID, firstSeenAt = now, source = source}
        bucket[key] = entry
    end
    entry.lastSeenAt = now
    entry.source = entry.source or source
    if itemID and not entry.itemID then entry.itemID = itemID end
    if source == "snapshot" then
        entry.presentWhenObserved = true
        -- A snapshot obtained in the opening seconds is strong evidence that
        -- the buff was already present for the engagement. Later snapshots are
        -- still recorded, but are not mislabeled as pull-state evidence.
        if now <= 3 then entry.activeAtEngagement = true end
    elseif state == "applied" then
        entry.gainedDuringFight = true
        entry.appliedAt = entry.appliedAt or now
    elseif state == "removed" then
        entry.removedAt = now
    end
end

local function ReadHelpfulAura(unit, index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if ok and aura then return aura.name, aura.spellId, aura.duration, aura.expirationTime, aura.icon end
    end
    local reader = UnitBuff or UnitAura
    if not reader then return nil end
    local ok, name, _, icon, _, duration, expirationTime, _, _, _, spellID = pcall(reader, unit, index, "HELPFUL")
    if not ok then return nil end
    return name, spellID, duration, expirationTime, icon
end

local function ScanEnemyUnitBuffs(session, unit)
    if not session or not unit or not UnitGUID then return end
    local guid = UnitGUID(unit)
    local enemy = guid and session.enemies and session.enemies[guid]
    if not enemy then return end
    local detected = EnsureDetectedBuffs(enemy)
    detected.scanned = true
    detected.firstScanAt = detected.firstScanAt or math.max(0, GetTime() - session.startedElapsed)
    for index = 1, 80 do
        local name, spellID, duration, expirationTime, icon = ReadHelpfulAura(unit, index)
        if not name then break end
        RecordEnemyAura(session, enemy, spellID, name, icon, duration, expirationTime, "snapshot", "present")
        local category, canonical, itemID = TrackedBuffMeta(spellID, name)
        if category then RecordEnemyBuff(session, enemy, category, spellID, canonical or name, itemID, "snapshot", "present") end
    end
end

local function ScanVisibleEnemyBuffs(session, force)
    if not session or not UnitGUID then return end
    local now = GetTime()
    if not force and session.lastBuffScanAt and now - session.lastBuffScanAt < .35 then return end
    session.lastBuffScanAt = now
    for _, unit in ipairs({"player", "target", "mouseover", "focus", "targettarget", "mouseovertarget", "focustarget"}) do ScanEnemyUnitBuffs(session, unit) end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local unit = plate and (plate.namePlateUnitToken or plate.unitToken)
                if unit then ScanEnemyUnitBuffs(session, unit) end
            end
        end
    end
end

local function TrackCombatLogBuff(session, info)
    if not session or type(info) ~= "table" then return end
    local event = info[2]
    if event ~= "SPELL_AURA_APPLIED" and event ~= "SPELL_AURA_REFRESH" and event ~= "SPELL_AURA_REMOVED" then return end
    if info[15] and info[15] ~= "BUFF" then return end
    local enemy = session.enemies and session.enemies[info[8]]
    if not enemy then return end
    local spellID, name = info[12], info[13]
    local state = event == "SPELL_AURA_REMOVED" and "removed" or "applied"
    RecordEnemyAura(session, enemy, spellID, name, SpellIcon(spellID), nil, nil, "combatlog", state)
    local category, canonical, itemID = TrackedBuffMeta(spellID, name)
    if category then
        RecordEnemyBuff(session, enemy, category, spellID, canonical or name, itemID, "combatlog", state)
    end
end

local function CountDetectedBuffs(enemy)
    local world, consumes = 0, 0
    local buffs = enemy and enemy.detectedBuffs
    for _ in pairs(buffs and buffs.world or {}) do world = world + 1 end
    for _ in pairs(buffs and buffs.consumables or {}) do consumes = consumes + 1 end
    return world, consumes
end

local function SortedDetectedBuffs(enemy, bucketName)
    local result = {}
    local bucket = enemy and enemy.detectedBuffs and enemy.detectedBuffs[bucketName] or {}
    for _, entry in pairs(bucket or {}) do result[#result + 1] = entry end
    table.sort(result, function(a, b)
        if (a.firstSeenAt or 0) ~= (b.firstSeenAt or 0) then return (a.firstSeenAt or 0) < (b.firstSeenAt or 0) end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    return result
end

local function IsLongDurationConsumableName(name)
    if type(name) ~= "string" then return false end
    return name:find("Elixir", 1, true) ~= nil or
        name:find("Flask", 1, true) ~= nil and name ~= "Flask of Petrification" or
        name:find("Juju", 1, true) ~= nil or
        name:find("Zanza", 1, true) ~= nil or
        name == "Winterfall Firewater" or name == "R.O.I.D.S." or
        name == "Ground Scorpok Assay" or name == "Cerebral Cortex Compound" or
        name == "Gizzard Gum" or name == "Lung Juice Cocktail" or name == "Gift of Arthas"
end

local function IsShortTermConsumableAura(entry)
    if not entry then return false end
    local name = entry.name or ""
    if name == "Free Action Potion" or name == "Limited Invulnerability Potion" or
        name == "Flask of Petrification" then return true end
    local known = entry.spellID and DP.UsageCatalog and DP.UsageCatalog[entry.spellID]
    if not (known and known.category == "potions") then return false end
    -- Protection shields are meaningful enemy buffs even when the only
    -- evidence is their removal on death, with no duration snapshot available.
    if (known.name or name):find("Protection Potion", 1, true) then return false end
    if entry.duration and entry.duration > 0 then return entry.duration <= 120 end
    return not IsLongDurationConsumableName(known.name or name)
end

local function IsIgnoredEnemyBuff(entry)
    if not entry then return false end
    local spellID = tonumber(entry.spellID)
    local itemID = tonumber(entry.itemID)
    local name = tostring(entry.name or "")
    -- This aura only means the player has world buffs stored in a Chronoboon.
    -- It is not a combat advantage to enumerate in ENEMY BUFFS and it is not
    -- evidence of an in-encounter Chronoboon use.
    return spellID == 349981 or itemID == 184938 or name == "Supercharged Chronoboon Displacer"
end

local function SortedOpponentBuffs(enemy)
    local result, seen = {}, {}
    local detected = enemy and enemy.detectedBuffs or nil
    local all = detected and detected.all or nil

    -- ENEMY BUFFS is intentionally ordered by PvP significance rather than by
    -- capture time.  This keeps the most meaningful pre-fight advantages at the
    -- front of the icon grid: world buffs, flasks, Zanzas, elixirs,
    -- protection potions, long class buffs, then novelty/miscellaneous effects.
    local function BuffPriority(entry)
        if not entry then return 99 end
        local spellID = tonumber(entry.spellID)
        local name = tostring(entry.name or "")
        local known = spellID and DP.UsageCatalog and DP.UsageCatalog[spellID] or nil
        local canonical = known and known.name or name
        local itemID = tonumber(entry.itemID or (known and known.itemID))

        if (spellID and WORLD_BUFFS[spellID]) or WORLD_BUFF_NAMES[name] or
                WORLD_BUFF_NAMES[canonical] or name:find("Rallying Cry of the Dragonslayer", 1, true) then
            return 1
        end

        -- Noggenfogger is technically named an Elixir, but it belongs with the
        -- low-priority novelty/miscellaneous effects rather than stat elixirs.
        if itemID == 8529 or canonical == "Noggenfogger Elixir" or
                spellID == 16589 or spellID == 16591 or spellID == 16593 or spellID == 16595 then
            return 7
        end

        if canonical:find("Flask", 1, true) then return 2 end
        if canonical:find("Zanza", 1, true) or name:find("Zanza", 1, true) then return 3 end
        if canonical:find("Elixir", 1, true) then return 4 end
        if canonical:find("Protection Potion", 1, true) then return 5 end
        if IsLongClassBuff(entry) then return 6 end
        return 7
    end

    local function Enriched(entry)
        if not entry then return nil end
        local key = tostring(entry.spellID or entry.name or "unknown")
        local rich = all and all[key]
        if not rich and all then
            for _, candidate in pairs(all) do
                if candidate and ((entry.spellID and candidate.spellID == entry.spellID) or
                    (entry.name and candidate.name == entry.name)) then
                    rich = candidate
                    break
                end
            end
        end
        if rich and rich ~= entry then
            entry.icon = entry.icon or rich.icon
            entry.duration = entry.duration or rich.duration
            entry.expires = entry.expires or rich.expires
            entry.activeAtEngagement = entry.activeAtEngagement or rich.activeAtEngagement
            entry.firstSeenAt = entry.firstSeenAt or rich.firstSeenAt
            entry.appliedAt = entry.appliedAt or rich.appliedAt
        end
        return entry
    end

    local function Add(entry)
        entry = Enriched(entry)
        if not entry or IsIgnoredEnemyBuff(entry) or IsShortTermConsumableAura(entry) then return end
        local key = tostring(entry.spellID or entry.name or "unknown")
        if seen[key] then return end
        seen[key] = true
        if not entry.icon then entry.icon = SpellIcon(entry.spellID) end
        -- Aura snapshots store the spell identity, while Items & Abilities uses
        -- the source item. Rejoin those identities here so long-duration
        -- consumable buffs use the same item tooltip as the usage table.
        if not entry.itemID and entry.spellID and DP.UsageCatalog then
            local known = DP.UsageCatalog[entry.spellID]
            if known and known.category == "potions" and known.itemID then entry.itemID = known.itemID end
        end
        if not entry.itemID and entry.name and DP.UsageCatalog then
            for _, known in pairs(DP.UsageCatalog) do
                if known and known.category == "potions" and known.itemID and known.name == entry.name then
                    entry.itemID = known.itemID
                    break
                end
            end
        end
        result[#result + 1] = entry
    end

    -- The header is a curated enemy-buff view, not a generic aura dump. Keep
    -- world/consumable intelligence, then add known long class buffs, including
    -- removal-only observations without a duration snapshot. This preserves useful
    -- pre-fight/self-buff context without filling the card with forms, HoTs,
    -- shields, short blessings, or temporary combat cooldowns.
    for _, entry in pairs(detected and detected.world or {}) do Add(entry) end
    for _, entry in pairs(detected and detected.consumables or {}) do Add(entry) end
    for _, entry in pairs(all or {}) do
        if IsLongClassBuff(entry) then Add(entry) end
    end

    table.sort(result, function(a, b)
        local ap, bp = BuffPriority(a), BuffPriority(b)
        if ap ~= bp then return ap < bp end
        if (a.activeAtEngagement and true or false) ~= (b.activeAtEngagement and true or false) then
            return a.activeAtEngagement and true or false
        end
        if (a.firstSeenAt or 0) ~= (b.firstSeenAt or 0) then return (a.firstSeenAt or 0) < (b.firstSeenAt or 0) end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    return result
end

W.GetOpponentBuffsForDetail = SortedOpponentBuffs

function W.OpponentBuffIcon(entry)
    if entry.itemID then
        local reader = C_Item and C_Item.GetItemIconByID or GetItemIcon
        if reader then
            local ok, texture = pcall(reader, entry.itemID)
            if ok and texture then return texture end
        end
        if GetItemInfoInstant then
            local ok, _, _, _, _, texture = pcall(GetItemInfoInstant, entry.itemID)
            if ok and texture then return texture end
        end
    end
    return entry.icon or SpellIcon(entry.spellID) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function HasFlag(flags, mask)
    if type(flags) ~= "number" or type(mask) ~= "number" then return false end
    if CFG.BAND then return CFG.BAND(flags, mask) ~= 0 end
    -- Test/runtime fallback. WoW Classic provides bit.band, but keeping this
    -- tiny arithmetic path makes the tracker deterministic in stripped clients.
    local a, b = flags, mask
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then return true end
        a, b = math.floor(a / 2), math.floor(b / 2)
    end
    return false
end

local function IsPlayer(flags)
    return HasFlag(flags, COMBATLOG_OBJECT_TYPE_PLAYER)
end

local function IsHostile(flags)
    return HasFlag(flags, COMBATLOG_OBJECT_REACTION_HOSTILE)
end

local function IsFriendly(flags)
    return HasFlag(flags, COMBATLOG_OBJECT_REACTION_FRIENDLY)
end

local function ShortName(name)
    if type(name) ~= "string" or name == "" then return "Unknown" end
    return name:match("^([^-]+)") or name
end

local STAR_ATLAS_FILLED, STAR_ATLAS_EMPTY
local function ResolveStarAtlases()
    if STAR_ATLAS_FILLED then return STAR_ATLAS_FILLED, STAR_ATLAS_EMPTY end
    local function HasAtlas(name)
        if C_Texture and C_Texture.GetAtlasInfo then
            local ok, info = pcall(C_Texture.GetAtlasInfo, name)
            return ok and info ~= nil
        end
        return true
    end
    -- Prefer Blizzard's explicit favorite on/off pair when this Classic client
    -- ships it; otherwise use the Classic UI favorites star and desaturate it
    -- for the unstarred state.
    if HasAtlas("auctionhouse-icon-favorite") and HasAtlas("auctionhouse-icon-favorite-off") then
        STAR_ATLAS_FILLED, STAR_ATLAS_EMPTY = "auctionhouse-icon-favorite", "auctionhouse-icon-favorite-off"
    elseif HasAtlas("PetJournal-FavoritesIcon") then
        STAR_ATLAS_FILLED, STAR_ATLAS_EMPTY = "PetJournal-FavoritesIcon", "PetJournal-FavoritesIcon"
    else
        STAR_ATLAS_FILLED, STAR_ATLAS_EMPTY = "PetJournal-FavoritesIcon", "PetJournal-FavoritesIcon"
    end
    return STAR_ATLAS_FILLED, STAR_ATLAS_EMPTY
end

function W.StyleStarTexture(texture, starred)
    if not texture then return end
    local filled, empty = ResolveStarAtlases()
    local atlas = starred and filled or empty
    local applied = texture.SetAtlas and pcall(texture.SetAtlas, texture, atlas, false)
    if not applied then
        texture:SetTexture("Interface\\COMMON\\ReputationStar")
    end
    if texture.SetDesaturated then texture:SetDesaturated(not starred and filled == empty) end
    texture:SetVertexColor(starred and 1 or .62, starred and .86 or .64, starred and .18 or .70, starred and 1 or .82)
    texture:SetAlpha(starred and 1 or .78)
end

function W.VisibleUnitForGUID(guid)
    if not guid or not UnitGUID then return nil end
    local function Match(unit)
        return unit and UnitGUID(unit) == guid and unit or nil
    end
    if UnitTokenFromGUID then
        local ok, unit = pcall(UnitTokenFromGUID, guid)
        if ok and Match(unit) then return unit end
    end
    for _, unit in ipairs({"target", "mouseover", "focus", "targettarget"}) do
        if Match(unit) then return unit end
    end
    -- Party/raid tokens work even when friendly nameplates are disabled or
    -- UnitTokenFromGUID cannot resolve a group member on this Classic client.
    for index = 1, 4 do
        local unit = "party" .. index
        if Match(unit) then return unit end
    end
    for index = 1, 40 do
        local unit = "raid" .. index
        if Match(unit) then return unit end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local unit = plate and (plate.namePlateUnitToken or plate.unitToken)
                if Match(unit) then return unit end
            end
        end
    end
    return nil
end

local function ResolvePlayerLevel(guid)
    if not guid or not UnitLevel then return nil end
    local unit = W.VisibleUnitForGUID(guid)
    if unit then
        local level = UnitLevel(unit)
        if type(level) == "number" and level > 0 then return level end
    end
    return nil
end

-- Snapshot an opponent's Classic PvP/Honor rank whenever the client gives us a
-- usable unit token. Keep the raw UnitPVPRank index as well as Blizzard's
-- localized title/number so future UI can choose either representation without
-- having to reinterpret old encounters. A zero index is still meaningful: it
-- records that we actually observed the player and they had no visible rank.
function W.CaptureOpponentPVPRank(identity, unit)
    if not identity or not unit or not UnitGUID or UnitGUID(unit) ~= identity.guid or not UnitPVPRank then return false end
    local ok, rawRank = pcall(UnitPVPRank, unit)
    if not ok or type(rawRank) ~= "number" or rawRank < 0 then return false end

    local changed = identity.pvpRankIndex ~= rawRank or not identity.pvpRankObserved
    identity.pvpRankObserved = true
    identity.pvpRankIndex = rawRank
    identity.pvpRankCapturedAt = time and time() or 0

    if GetPVPRankInfo then
        local infoOK, title, rankNumber = pcall(GetPVPRankInfo, rawRank, unit)
        if not infoOK then infoOK, title, rankNumber = pcall(GetPVPRankInfo, rawRank) end
        if infoOK then
            if type(title) == "string" and title ~= "" then
                if identity.pvpRankTitle ~= title then changed = true end
                identity.pvpRankTitle = title
            elseif rawRank == 0 then
                identity.pvpRankTitle = nil
            end
            if type(rankNumber) == "number" then
                if identity.pvpRankNumber ~= rankNumber then changed = true end
                identity.pvpRankNumber = rankNumber
            elseif rawRank == 0 then
                identity.pvpRankNumber = nil
            end
        end
    end
    return changed
end

function W.RefreshFriendlyLevels(session)
    if not session then return end
    for guid, friendly in pairs(session.friendlies or {}) do
        if not tonumber(friendly.level) or tonumber(friendly.level) <= 0 then
            local level = guid == session.playerGUID and tonumber(session.playerLevel) or nil
            if not level or level <= 0 then level = ResolvePlayerLevel(friendly.guid or guid) end
            if level and level > 0 then friendly.level = level end
        end
    end
end

W._portraitSessionID = W._portraitSessionID or (tostring(time and time() or 0) .. ":" .. tostring(GetTime and GetTime() or 0))

function W.CaptureOpponentPortrait(identity, unit)
    if identity and identity.portraitFrozen then return false end
    if not identity or not identity.guid or not unit or not UnitGUID or UnitGUID(unit) ~= identity.guid then return false end
    if DP.Portraits then
        -- Clone the actual opponent first so generic body-pool warming cannot win
        -- the race and commit a donor face for this encounter.
        if DP.Portraits.RetainIdentityBody then DP.Portraits.RetainIdentityBody(identity, unit) end
        if DP.Portraits.ObserveUnit then DP.Portraits.ObserveUnit(unit) end
        DP.Portraits.Capture(identity, unit)
    end
    local changed = false
    -- Try to retain the exact portrait texture produced by the client first.
    -- When the client exposes that render as a reusable file/string handle this
    -- preserves encounter-specific appearance (including visible headgear).
    if SetPortraitTexture and CreateFrame then
        if not W._portraitCaptureFrames then W._portraitCaptureFrames = setmetatable({}, {__mode = "k"}) end
        local holder = W._portraitCaptureFrames[identity]
        if not holder then
            holder = CreateFrame("Frame", nil, UIParent)
            holder:SetSize(46, 46); holder:Hide()
            holder.tex = holder:CreateTexture(nil, "ARTWORK")
            holder.tex:SetAllPoints()
            W._portraitCaptureFrames[identity] = holder
        end
        local tex = holder.tex
        if tex then
            local ok = pcall(SetPortraitTexture, tex, unit)
            if ok then holder.captured = true; changed = true end
            -- SetPortraitTexture writes into a client-owned render target.  On
            -- Classic, Texture:GetTexture() may report either an RTPortrait handle
            -- or a numeric value that is *not* a durable fileDataID. Persisting
            -- that numeric value caused old portraits to reopen as unrelated item/
            -- spell icons after the render target was recycled. Keep the live
            -- Texture object in _portraitCaptureFrames for this UI session only;
            -- never serialize its backing handle into the encounter record.
            if identity.portraitTexture ~= nil or identity.portraitSessionID ~= nil then
                identity.portraitTexture = nil
                identity.portraitSessionID = nil
                changed = true
            end
        end
    end
    if UnitCreatureDisplayID then
        local ok, displayID = pcall(UnitCreatureDisplayID, unit)
        if ok and type(displayID) == "number" and displayID > 0 then
            identity.portraitDisplayID = displayID
            changed = true
        end
    end
    if UnitSex then
        local ok, sex = pcall(UnitSex, unit)
        if ok and type(sex) == "number" and sex > 0 then identity.portraitSex = sex end
    end
    if GetPlayerInfoByGUID then
        local _, _, _, englishRace = GetPlayerInfoByGUID(identity.guid)
        if englishRace then identity.raceFile = identity.raceFile or englishRace end
    end
    if changed then identity.portraitCapturedAt = time and time() or 0 end
    return changed
end


local function CopyIdentity(guid, name, flags)
    local class, race, raceFile, sex
    if guid and GetPlayerInfoByGUID then
        local _, englishClass, localizedRace, englishRace, playerSex = GetPlayerInfoByGUID(guid)
        class = englishClass
        race = localizedRace or englishRace
        raceFile = englishRace
        sex = playerSex
    end
    local identity = {guid = guid, name = name or "Unknown", class = class, race = race, raceFile = raceFile,
        sex = sex, level = ResolvePlayerLevel(guid), flags = flags}
    local unit = W.VisibleUnitForGUID(guid)
    if unit then
        W.CaptureOpponentPVPRank(identity, unit)
        W.CaptureOpponentPortrait(identity, unit)
    end
    return identity
end

local function Count(tableValue)
    local n = 0
    for _ in pairs(tableValue or {}) do n = n + 1 end
    return n
end

local function CountUnstarredEncounters(encounters)
    local n = 0
    for _, record in ipairs(encounters or {}) do if not record.starred then n = n + 1 end end
    return n
end

-- Return only the captured value spent by enemy player participants. The
-- encounter snapshot also contains the local player's consumables, so using
-- snapshot.totalCopper would overstate the new lifetime enemy-spend stat.
local function EnemyConsumableSpend(record)
    local snapshot = record and record.consumableCost
    if type(snapshot) ~= "table" then return 0, false, 0, 0 end

    local enemyGUIDs, enemyNames = {}, {}
    for _, enemy in ipairs(record.enemies or {}) do
        if enemy.guid then enemyGUIDs[enemy.guid] = true end
        local name = ShortName(enemy.name)
        if name and name ~= "" then enemyNames[name:lower()] = true end
    end

    local total, pricedCount, unpricedCount = 0, 0, 0
    local categories = {}
    for _, actor in ipairs(snapshot.actors or {}) do
        local actorName = ShortName(actor.name)
        local isEnemy = (actor.guid and enemyGUIDs[actor.guid]) or
            (actorName and actorName ~= "" and enemyNames[actorName:lower()])
        if isEnemy then
            for _, item in ipairs(actor.items or {}) do
                local copper = math.max(0, tonumber(item.totalCopper) or
                    (tonumber(item.unitCopper) or 0) * (tonumber(item.count) or 1))
                local key = DP.SpendChart.Category(item)
                categories[key] = (categories[key] or 0) + copper
            end
            total = total + math.max(0, tonumber(actor.totalCopper) or 0)
            pricedCount = pricedCount + math.max(0, tonumber(actor.pricedCount) or 0)
            unpricedCount = unpricedCount + math.max(0, tonumber(actor.unpricedCount) or 0)
        end
    end
    local categorized = 0
    for _, copper in pairs(categories) do categorized = categorized + copper end
    categories.other = (categories.other or 0) + math.max(0, total - categorized)
    return total, unpricedCount > 0, pricedCount, unpricedCount, categories
end

local function ArchiveEnemyConsumableSpend(store, record)
    if not store or not record then return end
    local copper, partial, pricedCount, unpricedCount, categories = EnemyConsumableSpend(record)
    store.enemyGoldArchivedCategories = store.enemyGoldArchivedCategories or {}
    DP.SpendChart.Merge(store.enemyGoldArchivedCategories, categories)
    store.enemyGoldArchivedCopper = math.max(0, tonumber(store.enemyGoldArchivedCopper) or 0) + copper
    store.enemyGoldArchivedPricedCount = math.max(0, tonumber(store.enemyGoldArchivedPricedCount) or 0) + pricedCount
    store.enemyGoldArchivedUnpricedCount = math.max(0, tonumber(store.enemyGoldArchivedUnpricedCount) or 0) + unpricedCount
    if partial then store.enemyGoldArchivedPartial = true end
end

local function TrimEncounterStore(store)
    local encounters = store and store.encounters
    if not encounters then return end
    while CountUnstarredEncounters(encounters) > CFG.MAX_ENCOUNTERS do
        local removed = false
        for index, record in ipairs(encounters) do
            if not record.starred then
                -- Preserve enemy consumable spend before the encounter itself
                -- ages out. The Overview lifetime total therefore survives the
                -- rolling 250 unstarred-record History cap.
                ArchiveEnemyConsumableSpend(store, record)
                DP.OverviewArchive.Add(store,record,WORLD_BUFFS)
                table.remove(encounters, index)
                removed = true
                break
            end
        end
        if not removed then break end
    end
end

local function OrderedParticipants(map)
    local result = {}
    for _, value in pairs(map or {}) do result[#result + 1] = value end
    table.sort(result, function(a, b)
        local an, bn = ShortName(a.name), ShortName(b.name)
        if an ~= bn then return an < bn end
        return tostring(a.guid or "") < tostring(b.guid or "")
    end)
    return result
end

local function InOpenWorld()
    if IsInInstance then
        local inside = IsInInstance()
        if inside then return false end
    end
    return true
end

local GENERIC_WORLD_ZONES = {
    ["Azeroth"] = true,
    ["Kalimdor"] = true,
    ["Eastern Kingdoms"] = true,
    ["Outland"] = true,
    ["Northrend"] = true,
    ["The Maelstrom"] = true,
    ["Pandaria"] = true,
    ["Draenor"] = true,
    ["Broken Isles"] = true,
    ["Kul Tiras"] = true,
    ["Zandalar"] = true,
    ["Shadowlands"] = true,
    ["Dragon Isles"] = true,
    ["Khaz Algar"] = true,
}

local function IsGenericWorldZone(zone, mapID)
    if type(zone) ~= "string" or zone == "" then return true end
    if GENERIC_WORLD_ZONES[zone] then return true end
    if mapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent
        local worldType = Enum and Enum.UIMapType and Enum.UIMapType.World
        if info and info.name == zone and
            ((continentType and info.mapType == continentType) or (worldType and info.mapType == worldType)) then
            return true
        end
    end
    return false
end

local function CurrentZoneName(mapInfo)
    -- Classic can report a continent around instance portals/transition areas.
    -- Prefer the real zone APIs and reject continent/world labels for statistics.
    local zone = GetRealZoneText and GetRealZoneText() or nil
    if type(zone) == "string" and zone ~= "" and zone ~= "Unknown" and not IsGenericWorldZone(zone) then return zone end
    zone = GetZoneText and GetZoneText() or nil
    if type(zone) == "string" and zone ~= "" and zone ~= "Unknown" and not IsGenericWorldZone(zone) then return zone end
    local subzone = GetSubZoneText and GetSubZoneText() or nil
    if type(subzone) == "string" and subzone ~= "" and not IsGenericWorldZone(subzone) then return subzone end
    zone = mapInfo and mapInfo.name or nil
    if type(zone) == "string" and zone ~= "" then return zone end
    return "Unknown"
end

local function SummaryZoneName(location)
    if not location then return nil end
    local zone = location.zone
    if not IsGenericWorldZone(zone, location.mapID) then return zone end
    -- Old records may already have stored a continent name. A retained
    -- subzone is a more useful fallback than calling a continent a zone.
    local subzone = location.subzone
    if type(subzone) == "string" and subzone ~= "" and not IsGenericWorldZone(subzone) then return subzone end
    return nil
end

local function PlayerPosition()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position or not position.GetXY then return nil end
    local x, y = position:GetXY()
    if not x or not y or x <= 0 or y <= 0 or x > 1 or y > 1 then return nil end
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return {
        mapID = mapID,
        x = x,
        y = y,
        zone = CurrentZoneName(info),
        subzone = (GetSubZoneText and GetSubZoneText()) or "",
    }
end

local function AddPosition(session)
    local p = PlayerPosition()
    if not p then return end
    session.positions = session.positions or {}
    local previous = session.positions[#session.positions]
    if previous and previous.mapID == p.mapID and math.abs(previous.x - p.x) < .002 and math.abs(previous.y - p.y) < .002 then return end
    if #session.positions < 64 then session.positions[#session.positions + 1] = p end
end

local function FinalLocation(session)
    local positions = session.positions or {}
    local terminal = session.deathPosition or session.lastKillPosition
    if terminal and terminal.mapID and terminal.x and terminal.y then
        return terminal
    end
    if #positions == 0 then
        return {zone = (GetZoneText and GetZoneText()) or "Unknown", subzone = (GetSubZoneText and GetSubZoneText()) or ""}
    end
    local lastMap = positions[#positions].mapID
    local x, y, count = 0, 0, 0
    local zone, subzone
    for _, p in ipairs(positions) do
        if p.mapID == lastMap then
            x, y, count = x + p.x, y + p.y, count + 1
            zone, subzone = p.zone, p.subzone
        end
    end
    local first, last = positions[1], positions[#positions]
    return {
        mapID = lastMap,
        x = count > 0 and x / count or last.x,
        y = count > 0 and y / count or last.y,
        startX = first.x,
        startY = first.y,
        endX = last.x,
        endY = last.y,
        zone = zone or last.zone,
        subzone = subzone or last.subzone,
    }
end

local function GroupGUIDs(playerGUID)
    local guids = {[playerGUID] = true}
    if IsInRaid and IsInRaid() and GetNumGroupMembers then
        for index = 1, GetNumGroupMembers() do
            local guid = UnitGUID("raid" .. index)
            if guid then guids[guid] = true end
        end
    else
        local max = GetNumSubgroupMembers and GetNumSubgroupMembers() or 4
        for index = 1, max do
            local guid = UnitGUID("party" .. index)
            if guid then guids[guid] = true end
        end
    end
    return guids
end

local function EventTouchesPlayer(info, playerGUID)
    local sourceGUID, destGUID = info[4], info[8]
    return sourceGUID == playerGUID or destGUID == playerGUID
end

local function PvPInteraction(info, playerGUID)
    local event = info[2]
    local sourceGUID, sourceFlags = info[4], info[6]
    local destGUID, destFlags = info[8], info[10]
    if not sourceGUID or not destGUID then return false end
    if event == "UNIT_DIED" or event == "UNIT_DESTROYED" then return false end
    local sourcePlayer, destPlayer = IsPlayer(sourceFlags), IsPlayer(destFlags)
    if not sourcePlayer or not destPlayer then return false end
    return (sourceGUID == playerGUID and IsHostile(destFlags)) or
        (destGUID == playerGUID and IsHostile(sourceFlags))
end

local function DirectHostileGUID(info, playerGUID)
    local sourceGUID, sourceFlags = info[4], info[6]
    local destGUID, destFlags = info[8], info[10]
    if sourceGUID == playerGUID and IsPlayer(destFlags) and IsHostile(destFlags) then return destGUID end
    if destGUID == playerGUID and IsPlayer(sourceFlags) and IsHostile(sourceFlags) then return sourceGUID end
    return nil
end

local function AddParticipant(session, bucketName, guid, name, flags)
    if not guid then return nil end
    local bucket = session[bucketName]
    local identity = bucket[guid]
    if not identity then
        identity = CopyIdentity(guid, name, flags)
        bucket[guid] = identity
    elseif name and (not identity.name or identity.name == "Unknown") then
        identity.name = name
    end
    if guid and GetPlayerInfoByGUID and (not identity.class or not identity.race or not identity.raceFile) then
        local _, class, localizedRace, englishRace, playerSex = GetPlayerInfoByGUID(guid)
        identity.class = identity.class or class
        identity.race = identity.race or localizedRace or englishRace
        identity.raceFile = identity.raceFile or englishRace
        identity.sex = identity.sex or playerSex
    end
    if not tonumber(identity.level) or tonumber(identity.level) <= 0 then identity.level = ResolvePlayerLevel(guid) end
    if bucketName == "enemies" then
        local unit = W.VisibleUnitForGUID(guid)
        if unit then
            W.CaptureOpponentPVPRank(identity, unit)
            W.CaptureOpponentPortrait(identity, unit)
        end
    end
    return identity
end

local function IsPressureEvent(event)
    if type(event) ~= "string" then return false end
    if event == "SWING_DAMAGE" or event == "SWING_MISSED" or event == "RANGE_DAMAGE" or event == "RANGE_MISSED" then return true end
    if event:find("_DAMAGE", 1, true) or event:find("_MISSED", 1, true) then return true end
    return event == "SPELL_AURA_APPLIED" or event == "SPELL_INTERRUPT" or event == "SPELL_DISPEL" or
        event == "SPELL_STOLEN" or event == "SPELL_DRAIN" or event == "SPELL_LEECH"
end

-- Friendly headcount is intentionally stricter than general encounter participation.
-- Another player only counts on the friendly side of NvN after they actually try to
-- harm an enemy in this encounter. Being attacked, healing/bandaging themselves, or
-- supporting the player does not make them part of the kill headcount.
local function IsFriendlyContributionEvent(event)
    if IsPressureEvent(event) then return true end
    return event == "SPELL_AURA_REFRESH" or event == "PARTY_KILL"
end

local function UpdateEnemyPressure(session, now)
    now = now or GetTime()
    local active, contesting = 0, 0
    for _, enemy in pairs(session.enemies or {}) do
        if enemy.pressuredPlayer then
            contesting = contesting + 1
            if not enemy.died and enemy.lastPressureAt and now - enemy.lastPressureAt <= CFG.ENEMY_PRESSURE_WINDOW then
                active = active + 1
            end
        end
    end
    session.contestingEnemyCount = math.max(session.contestingEnemyCount or 0, contesting)
    session.peakContestingEnemies = math.max(session.peakContestingEnemies or 0, active)
end

local function UpdatePeaks(session)
    session.peakFriendly = math.max(session.peakFriendly or 1, Count(session.friendlies))
    session.peakEnemy = math.max(session.peakEnemy or 0, Count(session.enemies))
    UpdateEnemyPressure(session)
end

local function IsUnconsciousDeathEvent(info)
    if not info then return false end
    local event = info[2]
    local flag
    if event == "UNIT_DIED" or event == "UNIT_DESTROYED" or event == "UNIT_DISSIPATES" then
        -- UNIT_DIED payload: recapID, unconsciousOnDeath.  Hunter Feign Death
        -- intentionally uses the unconscious form of the death event.
        flag = info[13]
    elseif event == "PARTY_KILL" then
        -- Blizzard's combat-log processor also exposes unconsciousOnDeath for
        -- PARTY_KILL as its fifth event-specific value. Classic normally does
        -- not emit PARTY_KILL for Feign Death, but honor the flag if present.
        flag = info[16]
    end
    return flag == true or tonumber(flag) == 1
end

local function CombatSpellInfo(info)
    local event = info and info[2]
    if type(event) ~= "string" then return nil, nil end
    -- CLEU argument 12/13 only represent spell ID/name for spell/range events.
    -- On SWING_* events those same slots contain damage/miss payload fields, and
    -- may be numbers or booleans. Never persist or infer class from them as spells.
    if event:match("^SPELL_") or event:match("^RANGE_") then
        local spellID = tonumber(info[12])
        local spellName = type(info[13]) == "string" and info[13] or nil
        return spellID, spellName
    end
    return nil, nil
end

local function AppendWorldLog(session, info)
    session.worldCombatLog = session.worldCombatLog or {}
    local event = info[2]
    -- The ordinary event budget must never hide the encounter's ending.
    -- Critical lifecycle events can exceed it and remain in chronological order.
    local criticalEvent = event == "PARTY_KILL" or event == "UNIT_DIED" or
        event == "UNIT_DESTROYED" or event == "SPELL_RESURRECT" or
        (event=="ENVIRONMENTAL_DAMAGE" and tonumber(info[14]) and tonumber(info[14])>=0) or
        (event=="SPELL_DISPEL" and info[4]==session.playerGUID and WORLD_BUFFS[tonumber(info[15])])
    if #session.worldCombatLog >= CFG.MAX_WORLD_LOG and not criticalEvent then
        session.worldCombatTruncated = true
        return
    end
    local sourceName, destName = ShortName(info[5]), ShortName(info[9])
    local spellID, spellName = CombatSpellInfo(info)
    local combatItem = DP.Usage and DP.Usage.ResolveCombatItem and DP.Usage.ResolveCombatItem(spellID, session, info[4], spellName) or nil
    local procItem = DP.Usage and DP.Usage.ResolveProcItem and DP.Usage.ResolveProcItem(spellID, spellName, session, info[4]) or nil
    local mindControlSignal = W.IsMindControlCapSpell(spellID, spellName) and
        (event == "SPELL_CAST_SUCCESS" or event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH")
    local mindControlUserGUID, mindControlUserName, mindControlBackfire
    if mindControlSignal then
        if info[4] and session.participants and session.participants[info[4]] then
            mindControlUserGUID, mindControlUserName = info[4], sourceName
        elseif info[8] and session.participants and session.participants[info[8]] then
            -- On a backfire the charm aura can be sourced by an NPC/temporary
            -- controller and land on the player who actually activated the cap.
            mindControlUserGUID, mindControlUserName = info[8], destName
            mindControlBackfire = true
        end
    end
    local logTime = math.max(0, GetTime() - session.startedElapsed)
    if mindControlSignal and mindControlUserGUID then
        -- Spell 13180 is the item effect while 13181 is the 20-second charm aura.
        -- Classic may emit either or both, and the aura can duplicate. Collapse
        -- all of those CLEU signals into one player item-use line. If the cast was
        -- seen first and the later aura proves a backfire, upgrade that same row.
        for index = #session.worldCombatLog, math.max(1, #session.worldCombatLog - 8), -1 do
            local prior = session.worldCombatLog[index]
            if prior and prior.mindControlCapUse and prior.itemUserGUID == mindControlUserGUID and
                    math.abs(logTime - (tonumber(prior.t) or 0)) <= 1.25 then
                if mindControlBackfire then prior.mindControlBackfire = true end
                prior.itemUserName = prior.itemUserName or mindControlUserName
                prior.itemID, prior.itemName, prior.itemQuality, prior.itemCategory = 10726, "Gnomish Mind Control Cap", 2, "engineering"
                return
            end
        end
        combatItem = {itemID=10726, name="Gnomish Mind Control Cap", quality=2, category="engineering"}
    end
    local text
    if event == "SWING_DAMAGE" then
        text = string.format("%s hit %s for %s", sourceName, destName, tostring(math.floor((tonumber(info[12]) or 0) + .5)))
    elseif event == "SWING_MISSED" then
        text = string.format("%s missed %s (%s)", sourceName, destName, tostring(info[12] or "miss"))
    elseif event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" then
        text = string.format("%s's %s hit %s for %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName,
            tostring(math.floor((tonumber(info[15]) or 0) + .5)))
    elseif event == "SPELL_MISSED" or event == "RANGE_MISSED" then
        local missType = tostring(info[15] or "MISS")
        local amountMissed = tonumber(info[17])
        if missType == "ABSORB" then
            text = string.format("%s's %s was absorbed by %s%s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName,
                amountMissed and (" for " .. tostring(math.floor(amountMissed + .5))) or "")
        elseif missType == "RESIST" then
            text = string.format("%s resisted %s's %s%s", destName, sourceName, spellName or ("Spell " .. tostring(spellID)),
                amountMissed and (" (" .. tostring(math.floor(amountMissed + .5)) .. ")") or "")
        elseif missType == "IMMUNE" then
            text = string.format("%s was immune to %s's %s", destName, sourceName, spellName or ("Spell " .. tostring(spellID)))
        else
            text = string.format("%s's %s missed %s (%s)", sourceName, spellName or ("Spell " .. tostring(spellID)), destName, missType)
        end
    elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
        text = string.format("%s's %s healed %s for %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName,
            tostring(math.floor((tonumber(info[15]) or 0) + .5)))
    elseif event == "SPELL_CAST_SUCCESS" then
        text = string.format("%s cast %s%s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName ~= "Unknown" and (" on " .. destName) or "")
    elseif event == "SPELL_AURA_APPLIED" then
        text = string.format("%s applied %s to %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName)
    elseif event == "SPELL_AURA_REMOVED" then
        text = string.format("%s's %s faded from %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName)
    elseif event == "SPELL_AURA_REFRESH" then
        text = string.format("%s refreshed %s on %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName)
    elseif event == "SPELL_INTERRUPT" then
        text = string.format("%s's %s interrupted %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName)
    elseif event == "PARTY_KILL" then
        if IsUnconsciousDeathEvent(info) then
            text = destName .. " became unconscious"
        else
            text = string.format("%s killed %s", sourceName, destName)
        end
    elseif event == "SPELL_RESURRECT" then
        text = string.format("%s resurrected %s with %s", sourceName, destName, spellName or ("Spell " .. tostring(spellID)))
    elseif event == "SPELL_DISPEL" then
        text=string.format("%s removed %s from %s",sourceName or "Player",tostring(info[16] or "buff"),destName or "Player")
    elseif event == "ENVIRONMENTAL_DAMAGE" then
        text=string.format("%s took %d %s damage",destName or "Player",tonumber(info[13]) or 0,tostring(info[12] or "environmental"):lower())
    elseif event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
        text = IsUnconsciousDeathEvent(info) and (destName .. " became unconscious") or (destName .. " died")
    end
    if text then
        local amount
        if event == "ENVIRONMENTAL_DAMAGE" then amount=tonumber(info[13])
        elseif event == "SWING_DAMAGE" then amount = tonumber(info[12])
        elseif event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or
            event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then amount = tonumber(info[15]) end
        local overhealing, effectiveAmount
        if event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
            overhealing = tonumber(info[16]) or 0
            effectiveAmount = math.max(0, (tonumber(amount) or 0) - overhealing)
        end
        local overkill, critical
        if event == "ENVIRONMENTAL_DAMAGE" then
            overkill=tonumber(info[14])
        elseif event == "SWING_DAMAGE" then
            overkill = tonumber(info[13])
            critical = info[18] == true
        elseif event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" then
            overkill = tonumber(info[16])
            critical = info[21] == true
        elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
            -- CLEU heal payload: amount, overhealing, absorbed, critical.
            -- Keep the crit bit so the recovery ledger can distinguish normal
            -- and critical heals instead of flattening them into one row.
            critical = info[18] == true
        end
        session.worldCombatLog[#session.worldCombatLog + 1] = {
            t = logTime,
            text = text,
            sourceGUID = info[4], sourceName = sourceName,
            destGUID = info[8], destName = destName,
            event = event, spellID = spellID, spellName = spellName,
            environmentalType = event=="ENVIRONMENTAL_DAMAGE" and info[12] or nil,
            removedSpellID = event=="SPELL_DISPEL" and tonumber(info[15]) or nil,
            unconscious = IsUnconsciousDeathEvent(info) and true or nil,
            itemID = combatItem and combatItem.itemID or nil, itemName = combatItem and combatItem.name or nil,
            itemQuality = combatItem and combatItem.quality or nil, itemCategory = combatItem and combatItem.category or nil,
            procItemID = procItem and procItem.itemID or nil, procItemName = procItem and procItem.name or nil,
            procItemQuality = procItem and procItem.quality or nil,
            mindControlCapUse = mindControlSignal and mindControlUserGUID and true or nil,
            mindControlBackfire = mindControlBackfire and true or nil,
            itemUserGUID = mindControlUserGUID,
            itemUserName = mindControlUserName,
            spellSchool = (event:match("^SPELL_") or event:match("^RANGE_")) and tonumber(info[14]) or nil,
            amount = amount, overhealing = overhealing, effectiveAmount = effectiveAmount,
            overkill = overkill, critical = critical,
            missType = event == "SWING_MISSED" and info[12] or ((event == "SPELL_MISSED" or event == "RANGE_MISSED") and info[15] or nil),
            amountMissed = (event == "SPELL_MISSED" or event == "RANGE_MISSED") and tonumber(info[17]) or nil,
            killingBlow = ((event == "SWING_DAMAGE" or event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE") and
                overkill ~= nil and overkill >= 0 and IsPlayer(info[6]) and IsPlayer(info[10])) and true or nil,
        }
    end
end

local function LevelGap(record, enemy)
    local playerLevel = tonumber(record and record.playerLevel)
    local enemyLevel = tonumber(enemy and enemy.level)
    if not playerLevel or not enemyLevel or playerLevel <= enemyLevel then return nil end
    return playerLevel - enemyLevel
end

local function GankKind(record, enemy)
    local gap = LevelGap(record, enemy)
    if not gap then return nil end
    -- A 5+ level disparity is always a lowbie gank. For smaller gaps, reserve
    -- the generic GANK label for max-level (60) players killing downward.
    if gap >= 5 then return "lowbie", gap end
    if (tonumber(record and record.playerLevel) or 0) >= 60 then return "gank", gap end
    return nil
end

local function CountGanks(record)
    -- "Ganks" is the umbrella stat: every lower-level gank counts here.
    -- Lowbie ganks (5+ level disparity) are retained as a breakdown for
    -- History/tooltip context rather than consuming a separate Overview tile.
    local ganks, lowbies = 0, 0
    for _, enemy in ipairs(record and record.enemies or {}) do
        if enemy.died then
            local kind = GankKind(record, enemy)
            if kind then
                ganks = ganks + 1
                if kind == "lowbie" then lowbies = lowbies + 1 end
            end
        end
    end
    return ganks, lowbies
end

local function OpponentInteractionStats(record, enemy)
    if not record or not enemy then return 0, 0, 0 end
    local hits = tonumber(enemy.playerInteractionCount) or 0
    local damage = tonumber(enemy.damageFromPlayer) or 0
    local pressure = tonumber(enemy.pressureEventCount) or 0
    local log = record.session and record.session.worldCombatLog
    if type(log) == "table" then
        local logHits, logDamage, logPressure = 0, 0, 0
        for _, entry in ipairs(log) do
            if entry.sourceGUID == record.playerGUID and entry.destGUID == enemy.guid and IsFriendlyContributionEvent(entry.event) then
                logHits = logHits + 1
                logDamage = logDamage + (tonumber(entry.amount) or 0)
            elseif entry.sourceGUID == enemy.guid and entry.destGUID == record.playerGUID and IsPressureEvent(entry.event) then
                logPressure = logPressure + 1
            end
        end
        hits = math.max(hits, logHits)
        damage = math.max(damage, logDamage)
        pressure = math.max(pressure, logPressure)
    end
    return hits, damage, pressure
end

local function MeaningfullyEngaged(record, enemy)
    if not enemy then return false end
    if enemy.died or enemy.killingBlow then return true end
    local hits, _, pressure = OpponentInteractionStats(record, enemy)
    -- One stray cleave/Whirlwind or one token poke is context, not enough by
    -- itself to redefine the fight. Repeated actions or repeated hostile
    -- pressure make the player a real combatant even if nobody dies.
    return hits >= 2 or pressure >= 2
end

local function PrimaryOpponentScore(record, enemy)
    if not enemy then return -1 end
    local hits, damage, pressure = OpponentInteractionStats(record, enemy)
    local score = 0
    if enemy.killingBlow then score = score + 1000000 end
    if enemy.died then score = score + 100000 end
    if MeaningfullyEngaged(record, enemy) then score = score + 20000 end
    score = score + pressure * 3000 + hits * 1000 + math.min(damage, 10000)
    local playerLevel, enemyLevel = tonumber(record.playerLevel), tonumber(enemy.level)
    if playerLevel and enemyLevel then
        score = score + math.max(0, 100 - math.abs(playerLevel - enemyLevel)) * 10
    end
    return score
end

local function PrimaryOpponent(record)
    local best, bestScore
    for _, enemy in ipairs(record and record.enemies or {}) do
        local score = PrimaryOpponentScore(record, enemy)
        if not best or score > bestScore or (score == bestScore and (tonumber(enemy.level) or 0) > (tonumber(best.level) or 0)) then
            best, bestScore = enemy, score
        end
    end
    return best
end

local function SortEnemiesByRelevance(record)
    if not record or type(record.enemies) ~= "table" then return end
    table.sort(record.enemies, function(a, b)
        local as, bs = PrimaryOpponentScore(record, a), PrimaryOpponentScore(record, b)
        if as ~= bs then return as > bs end
        local al, bl = tonumber(a.level) or 0, tonumber(b.level) or 0
        if al ~= bl then return al > bl end
        return ShortName(a.name) < ShortName(b.name)
    end)
end

local function EncounterComposition(record)
    local lowbies, others = 0, 0
    for _, enemy in ipairs(record and record.enemies or {}) do
        local gap = LevelGap(record, enemy)
        if gap and gap >= 5 then lowbies = lowbies + 1 else others = others + 1 end
    end
    if lowbies > 0 and others > 0 then return "MIXED-LEVEL FIGHT", "mixed_level" end
    return nil, nil
end

local function MeaningfulEnemyCount(record)
    local count = 0
    for _, enemy in ipairs(record and record.enemies or {}) do
        if MeaningfullyEngaged(record, enemy) then count = count + 1 end
    end
    if count == 0 then count = #(record and record.enemies or {}) end
    return count
end

local function DisplayHeadcount(record)
    local meaningful = MeaningfulEnemyCount(record)
    local total = #(record and record.enemies or {})
    local friendlies = tonumber(record and record.friendlyCount) or 1
    local text
    if friendlies > 1 then text = string.format("%d vs %d", friendlies, meaningful)
    elseif meaningful == 1 then text = "1 vs 1"
    else text = string.format("1 vs %d", meaningful) end
    if total > meaningful then text = text .. string.format(" • %d encountered", total) end
    return text
end

local function IsDivineShieldSpell(spellID, spellName)
    return (spellID and CFG.DIVINE_SHIELD_SPELLS[tonumber(spellID)]) or spellName == "Divine Shield"
end

local function IsHearthstoneSpell(spellID, spellName)
    return (spellID and CFG.HEARTHSTONE_SPELLS[tonumber(spellID)]) or spellName == "Hearthstone"
end

local function BubbleHearthEnemy(record)
    if not record then return nil end
    local wanted = record.bubbleHearthEnemyGUID
    if wanted then
        for _, enemy in ipairs(record.enemies or {}) do
            if enemy.guid == wanted or enemy.name == wanted then return enemy end
        end
    end

    -- Backfill older encounters from the retained combat log so existing
    -- Divine Shield -> Hearthstone escapes are recognized retroactively.
    local lastShield = {}
    for _, entry in ipairs(record.session and record.session.worldCombatLog or {}) do
        local guid = entry.sourceGUID or entry.destGUID
        if guid and (entry.event == "SPELL_CAST_SUCCESS" or entry.event == "SPELL_AURA_APPLIED" or entry.event == "SPELL_AURA_REFRESH") and
            IsDivineShieldSpell(entry.spellID, entry.spellName) then
            lastShield[guid] = tonumber(entry.t) or 0
        elseif guid and entry.event == "SPELL_CAST_SUCCESS" and IsHearthstoneSpell(entry.spellID, entry.spellName) then
            local shieldAt = lastShield[guid]
            local hearthAt = tonumber(entry.t) or 0
            if shieldAt and hearthAt - shieldAt >= 0 and hearthAt - shieldAt <= CFG.BUBBLE_HEARTH_WINDOW then
                for _, enemy in ipairs(record.enemies or {}) do
                    if enemy.guid == guid and not enemy.died then
                        record.bubbleHearthEnemyGUID = guid
                        enemy.bubbleHearthed = true
                        enemy.bubbleHearthAt = hearthAt
                        return enemy
                    end
                end
            end
        end
    end
    return nil
end

function W.CompactEncounterLabel(record, key)
    key = key or record.resultKey
    local suffix = ({outnumbered_victory="VICTORY", outnumbered_escape="ESCAPE", outnumbered_partial="FIGHT"})[key]
    if not suffix then return nil end
    local n = record.completedSoloSweep or record.peakContestingEnemies or record.contestingEnemyCount or record.enemyCount or 2
    return string.format("1v%d %s", math.max(2, n), suffix)
end

function W.PetriDisengage(record)
    local participants={[record.playerGUID or ""]=not record.playerDied}
    for _,enemy in ipairs(record.enemies or {}) do
        if enemy.guid then participants[enemy.guid]=not enemy.died end
    end
    local function IsPetri(entry)
        return tonumber(entry.spellID)==17624 or tonumber(entry.itemID)==13506 or
            entry.spellName=="Petrification" or entry.spellName=="Flask of Petrification" or
            entry.itemName=="Flask of Petrification" or entry.name=="Flask of Petrification"
    end
    for _,entry in ipairs(record.session and record.session.worldCombatLog or {}) do
        if IsPetri(entry) and (entry.event=="SPELL_CAST_SUCCESS" or entry.event=="SPELL_AURA_APPLIED" or entry.event=="SPELL_AURA_REFRESH") then
            local guid=entry.event=="SPELL_CAST_SUCCESS" and entry.sourceGUID or entry.destGUID
            if participants[guid] then return true end
        end
    end
    for _,entry in ipairs(record.session and record.session.worldUsage and record.session.worldUsage.events or {}) do
        if participants[entry.guid or entry.sourceGUID] and IsPetri(entry) then return true end
    end
    return false
end

local function Outcome(record)
    if record.playerDied and record.playerDeathCause=="FALLING" then return "FALL DAMAGE","fall_damage" end
    local enemies = record.enemyCount or 0
    local friendlies = record.friendlyCount or 1
    local kills = record.enemyDeaths or 0
    if record.playerDied and record.lowHealthEngagement and (record.enemyDeaths or 0) == 0 then
        return "LOW-HEALTH DEATH", "low_health_death"
    end
    local survived = not record.playerDied
    if survived and record.completedSoloSweep then return W.CompactEncounterLabel(record, "outnumbered_victory"), "outnumbered_victory" end
    -- "Outnumbered" means multiple enemy players were simultaneously applying
    -- meaningful pressure to the player, not merely that several unique enemy
    -- names appeared during a long encounter. This prevents sequential ganks of
    -- non-responsive players from becoming a 1v2+ accomplishment.
    local pressureKnown = record.pressureModelVersion == 1
    local peakPressure = record.peakContestingEnemies or 0
    local contesting = record.contestingEnemyCount
    if contesting == nil then contesting = pressureKnown and 0 or enemies end
    local contestingDeaths = record.contestingEnemyDeaths
    if contestingDeaths == nil then contestingDeaths = pressureKnown and 0 or kills end
    local outnumbered = friendlies == 1 and peakPressure >= 2
    local contestedOneOnOne = friendlies == 1 and enemies == 1 and contesting == 1

    if outnumbered and survived and contesting > 0 and contestingDeaths >= contesting then return W.CompactEncounterLabel(record, "outnumbered_victory"), "outnumbered_victory" end
    if outnumbered and survived and contestingDeaths > 0 then return W.CompactEncounterLabel(record, "outnumbered_escape"), "outnumbered_escape" end
    if outnumbered and record.playerDied and contestingDeaths > 0 then return W.CompactEncounterLabel(record, "outnumbered_partial"), "outnumbered_partial" end
    -- A level-advantaged solo kill is called what it is. A max-level (60)
    -- player killing downward is a gank; any 5+ level gap is a lowbie gank.
    -- This is descriptive only and never affects Duel Rating.
    if enemies == 1 and kills == 1 then
        local enemy = record.enemies and record.enemies[1]
        local kind = GankKind(record, enemy)
        if kind == "lowbie" then return "LOWBIE GANK", "lowbie_gank" end
        if kind == "gank" then return "GANK", "gank" end
    end
    -- A clean 1v1 is only a Victory if the opponent actually fought back.
    if survived and contestedOneOnOne and kills == 1 then return "VICTORY", "victory" end
    if record.playerDied and kills > 0 then return "TRADE", "trade" end
    if record.playerDied then return "DEATH", "death" end
    if survived and kills > 0 then return kills == 1 and "1 KILL" or (tostring(kills) .. " KILLS"), "kills" end
    if survived and BubbleHearthEnemy(record) then return "BUBBLE HEARTHED", "bubble_hearth" end
    if W.PetriDisengage(record) then
        record.resultSubcategory="petri"
        return "DISENGAGED • PETRI", "disengaged"
    end
    record.resultSubcategory=nil
    return "DISENGAGED", "disengaged"
end

local function EncounterHeadcount(record)
    local friendlies = record.friendlyCount or 1
    local enemies = record.enemyCount or 0
    local contesting = record.contestingEnemyCount
    if contesting == nil then contesting = enemies end
    local peak = record.completedSoloSweep or record.peakContestingEnemies or contesting
    if friendlies > 1 then return string.format("%d vs %d", friendlies, enemies) end
    if peak >= 2 then return string.format("1 vs %d", peak) end
    if enemies == 1 and contesting == 1 then return "1 vs 1" end
    if enemies == 1 then return "1 enemy" end
    return string.format("%d enemies", enemies)
end

local function SurvivalText(record)
    if record.playerDied then return "death" end
    if record.resultKey == "victory" or record.resultKey == "outnumbered_victory" or record.resultKey == "outnumbered_escape" or record.resultKey == "bubble_hearth" then return "survived" end
    if (record.enemyDeaths or 0) > 0 then return "survived" end
    return "disengaged"
end

local function HeaderOutcomeText(record)
    local key = record and record.resultKey
    if key=="disengaged" and record.resultSubcategory=="petri" then return "Disengaged • PETRI" end
    local compact = record and W.CompactEncounterLabel(record)
    if compact then return compact end
    local labels = {
        outnumbered_victory = "Outnumbered Victory",
        outnumbered_escape = "Outnumbered Escape",
        outnumbered_partial = "Outnumbered Fight",
        lowbie_gank = "Lowbie Gank",
        gank = "Gank",
        victory = "Victory",
        trade = "Trade",
        death = "Death",
        fall_damage = "FALL DAMAGE",
        low_health_death = "Low-health death",
        disengaged = "Disengaged",
        bubble_hearth = "Bubble Hearthed",
    }
    if key == "kills" then
        local kills = tonumber(record and record.enemyDeaths) or 0
        return string.format("%d %s", kills, kills == 1 and "kill" or "kills")
    end
    return labels[key] or (record and record.resultLabel) or "World PvP"
end

local function EncounterTypeLabel(record)
    local mixed = EncounterComposition(record)
    return mixed or HeaderOutcomeText(record)
end

local function HeaderSurvivalText(record)
    if record and record.playerDied then return "|cffff8888Died|r" end
    if record and record.resultKey == "bubble_hearth" then return "|cff65e6adSurvived|r" end
    if (record and record.enemyDeaths or 0) > 0 or (record and (record.resultKey == "victory" or record.resultKey == "outnumbered_victory" or record.resultKey == "outnumbered_escape")) then
        return "|cff65e6adSurvived|r"
    end
    return "|cffadb5c2Disengaged|r"
end

local function HeaderDurationText(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + .5))
    if seconds >= 3600 then
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        return string.format("%dh %02dm", hours, minutes)
    end
    if seconds >= 60 then
        return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
    end
    return string.format("%ds", seconds)
end

local function HeaderCompactDurationText(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + .5))
    if seconds >= 3600 then return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60) end
    if seconds >= 60 then return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60) end
    return string.format("%ds", seconds)
end

local function EnemyNames(record, limit)
    local names = {}
    for _, enemy in ipairs(record.enemies or {}) do
        names[#names + 1] = ShortName(enemy.name)
        if limit and #names >= limit then break end
    end
    return names
end

local function ResultColor(key)
    local colors = {
        outnumbered_victory = "|cff74e6ff", -- cyan
        victory = "|cff65e6ad", -- green
        outnumbered_escape = "|cff8fafff", -- blue
        outnumbered_partial = "|cffffa35c", -- orange
        kills = "|cffffd56a", -- gold
        trade = "|cffeb93df", -- pink
        death = "|cffff7070", -- red
        fall_damage = "|cff92b7d0", -- environmental death
        low_health_death = "|cffffbb91", -- peach
        gank = "|cffc9a0ff", -- purple
        lowbie_gank = "|cffff91bb", -- rose
        bubble_hearth = "|cffb9c7ff", -- lavender
        mixed_level = "|cffd8b6ff",
    }
    return colors[key] or "|cffadb5c2"
end

W.ResultColor = ResultColor
W.EnemyNames = EnemyNames
W.EncounterHeadcount = EncounterHeadcount
W.SurvivalText = SurvivalText
W.GankKind = GankKind
W.CountGanks = CountGanks
W.PrimaryOpponent = PrimaryOpponent
W.MeaningfullyEngaged = MeaningfullyEngaged
W.EncounterComposition = EncounterComposition
W.DisplayHeadcount = DisplayHeadcount
W.BubbleHearthEnemy = BubbleHearthEnemy

local function RebuildPressureEvidence(record)
    if not record or record.pressureModelVersion == 1 then return end
    local log = record.session and record.session.worldCombatLog
    if type(log) ~= "table" or #log == 0 then return end
    local byGUID, lastPressure = {}, {}
    for _, enemy in ipairs(record.enemies or {}) do
        if enemy.guid then byGUID[enemy.guid] = enemy end
        enemy.pressuredPlayer = nil
        enemy.firstPressureAt, enemy.lastPressureAt = nil, nil
    end
    local peak = 0
    for _, entry in ipairs(log) do
        local t = tonumber(entry.t) or 0
        local enemy = byGUID[entry.sourceGUID]
        if enemy and entry.destGUID == record.playerGUID and IsPressureEvent(entry.event) then
            enemy.pressuredPlayer = true
            enemy.firstPressureAt = enemy.firstPressureAt or t
            enemy.lastPressureAt = t
            lastPressure[entry.sourceGUID] = t
        end
        local active = 0
        for guid, lastAt in pairs(lastPressure) do
            local participant = byGUID[guid]
            if participant and t - lastAt <= CFG.ENEMY_PRESSURE_WINDOW and
                (not participant.killedAt or participant.killedAt >= t) then active = active + 1 end
        end
        peak = math.max(peak, active)
    end
    local contesting, deaths = 0, 0
    for _, enemy in ipairs(record.enemies or {}) do
        if enemy.pressuredPlayer then
            contesting = contesting + 1
            if enemy.died then deaths = deaths + 1 end
        end
    end
    record.contestingEnemyCount = contesting
    record.contestingEnemyDeaths = deaths
    record.peakContestingEnemies = peak
    record.pressureModelVersion = 1
    record.resultLabel, record.resultKey = Outcome(record)
end

local function RebuildFriendlyContributionEvidence(record)
    if not record or record.friendlyContributionModelVersion == 1 then return end
    local log = record.session and record.session.worldCombatLog
    if type(log) ~= "table" or #log == 0 then return end

    local enemyGUIDs, contributorGUIDs = {}, {}
    for _, enemy in ipairs(record.enemies or {}) do
        if enemy.guid then enemyGUIDs[enemy.guid] = true end
    end
    if record.playerGUID then contributorGUIDs[record.playerGUID] = true end

    for _, entry in ipairs(log) do
        if entry.sourceGUID and entry.sourceGUID ~= record.playerGUID and enemyGUIDs[entry.destGUID] and
            IsFriendlyContributionEvent(entry.event) then
            contributorGUIDs[entry.sourceGUID] = true
        end
    end

    local filtered = {}
    for _, friendly in ipairs(record.friendlies or {}) do
        if friendly.guid == record.playerGUID or contributorGUIDs[friendly.guid] then
            friendly.contributedToEnemy = friendly.guid ~= record.playerGUID and true or friendly.contributedToEnemy
            filtered[#filtered + 1] = friendly
        end
    end

    -- Older records always stored the player in friendlies, but preserve a sane
    -- minimum if a legacy record is malformed.
    record.friendlies = filtered
    record.friendlyCount = math.max(1, #filtered)
    record.friendlyContributionModelVersion = 1
    record.resultLabel, record.resultKey = Outcome(record)
end

local function BuildRecord(session, reason)
    for guid, enemy in pairs(session.enemies or {}) do
        local unit = W.VisibleUnitForGUID(guid)
        if unit then
            W.CaptureOpponentPVPRank(enemy, unit)
            W.CaptureOpponentPortrait(enemy, unit)
            if DP.Portraits then DP.Portraits.Capture(enemy, unit, true) end
        end
    end
    local enemies = OrderedParticipants(session.enemies)
    for index, enemy in ipairs(enemies) do
        if not enemy.portraitFallbackVariant then
            enemy.portraitFallbackVariant = (((tonumber(session.startedAt) or 0) + index) % 2) + 1
        end
        enemy.portraitFrozen = true
    end
    W.RefreshFriendlyLevels(session)
    local friendlies = OrderedParticipants(session.friendlies)
    -- Resolve market values exactly once at encounter finalization.  The
    -- resulting snapshot is saved on the record and is never repriced later.
    local consumableCost = DP.Usage and DP.Usage.CaptureWorldConsumableCost and DP.Usage.CaptureWorldConsumableCost(session) or nil
    local deaths, contesting, contestingDeaths = 0, 0, 0
    for _, enemy in ipairs(enemies) do
        if enemy.died then deaths = deaths + 1 end
        if enemy.pressuredPlayer then
            contesting = contesting + 1
            if enemy.died then contestingDeaths = contestingDeaths + 1 end
        end
    end
    local record = {
        kind = "worldpvp",
        modelVersion = 1,
        pressureModelVersion = 1,
        friendlyContributionModelVersion = 1,
        outcomeModelVersion = 6,
        timestamp = session.startedAt or time(),
        endedAt = time(),
        startedAt = session.startedAt,
        duration = math.max(0, GetTime() - session.startedElapsed),
        endReason = reason,
        playerGUID = session.playerGUID,
        playerName = session.playerName,
        playerClass = session.playerClass,
        playerLevel = session.playerLevel,
        enemies = enemies,
        friendlies = friendlies,
        enemyCount = math.max(session.peakEnemy or 0, #enemies),
        friendlyCount = math.max(session.peakFriendly or 1, #friendlies),
        contestingEnemyCount = contesting,
        contestingEnemyDeaths = contestingDeaths,
        peakContestingEnemies = session.peakContestingEnemies or 0,
        enemyDeaths = deaths,
        playerDied = session.playerDied and true or false,
        playerDiedAt = session.playerDiedAt,
        playerDeathCause = session.playerDeathCause,
        killLocations = session.killLocations,
        engagementHealthPercent = session.engagementHealthPercent,
        lowHealthEngagement = session.lowHealthEngagement,
        killingBlows = session.killingBlows or 0,
        honorableKills = session.honorableKills or 0,
        consumableCost = consumableCost,
        bubbleHearthEnemyGUID = session.bubbleHearthEnemyGUID,
        honorMessages = session.honorMessages,
        npcAssistance = session.npcAssistance and true or false,
        location = FinalLocation(session),
        session = {
            worldPvP = true,
            worldUsage = session.worldUsage,
            worldCombatLog = session.worldCombatLog,
            worldCombatTruncated = session.worldCombatTruncated,
            participants = session.participants,
        },
    }
    SortEnemiesByRelevance(record)
    record.resultLabel, record.resultKey = Outcome(record)
    return record
end


-- Repair historical encounter splits caused by mechanics that temporarily break
-- WoW's combat state without ending the fight. The original migration covered
-- Gnomish Mind Control Cap backfires; version 3 also repairs full-duration Ice
-- Block splits where a reinforcement can be the first hostile action afterward.
-- Keep this conservative: records must be adjacent, geographically consistent,
-- close in time, and have retained combat-log evidence that bridges the boundary.
function W.RepairMindControlSplitEncounters(store)
    if not store or type(store.encounters) ~= "table" then return false end
    local repairVersion = 3
    if (tonumber(store.mindControlSplitRepairVersion) or 0) >= repairVersion then return false end

    local function StartAt(record)
        return tonumber(record and (record.startedAt or record.timestamp)) or 0
    end

    local function EndAt(record)
        local started = StartAt(record)
        return tonumber(record and record.endedAt) or (started + math.max(0, tonumber(record and record.duration) or 0))
    end

    local function SameOpponent(first, second)
        local a, b = first and first.enemies, second and second.enemies
        if type(a) ~= "table" or type(b) ~= "table" or #a ~= 1 or #b ~= 1 then return false end
        local ae, be = a[1], b[1]
        if ae.guid and be.guid then return ae.guid == be.guid end
        local an, bn = ShortName(ae.name), ShortName(be.name)
        return an ~= "" and an ~= "Unknown" and an == bn
    end

    local function RecordHasEnemy(record, guid, name)
        local wantedName = ShortName(name)
        for _, enemy in ipairs(record and record.enemies or {}) do
            if guid and enemy.guid and guid == enemy.guid then return true end
            local enemyName = ShortName(enemy.name)
            if wantedName ~= "" and wantedName ~= "Unknown" and enemyName == wantedName then return true end
        end
        return false
    end

    local function CombatSuspensionSignalAt(first, second)
        local active = {}
        for _, entry in ipairs(first and first.session and first.session.worldCombatLog or {}) do
            if W.IsCombatSuspensionSpell(entry.spellID, entry.spellName) then
                local event = tostring(entry.event or "")
                local guid = entry.destGUID or entry.sourceGUID
                local name = entry.destName or entry.sourceName
                if guid then
                    if event == "SPELL_CAST_SUCCESS" or event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
                        active[guid] = {t=tonumber(entry.t) or 0, name=name}
                    elseif event == "SPELL_AURA_REMOVED" then
                        active[guid] = nil
                    end
                end
            end
        end
        local latest
        for guid, signal in pairs(active) do
            if RecordHasEnemy(first, guid, signal.name) and RecordHasEnemy(second, guid, signal.name) then
                if not latest or signal.t > latest then latest = signal.t end
            end
        end
        return latest
    end

    local function MindControlSignalAt(record)
        local latest
        for _, entry in ipairs(record and record.session and record.session.worldCombatLog or {}) do
            local event = tostring(entry.event or "")
            if W.IsMindControlCapSpell(entry.spellID, entry.spellName) and
                    (event == "SPELL_CAST_SUCCESS" or event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH") then
                local at = tonumber(entry.t) or 0
                if not latest or at > latest then latest = at end
            end
        end
        return latest
    end

    local function SameArea(first, second)
        local a, b = first and first.location or {}, second and second.location or {}
        if a.mapID and b.mapID and tonumber(a.mapID) ~= tonumber(b.mapID) then return false end
        local az, bz = tostring(a.zone or ""), tostring(b.zone or "")
        if az ~= "" and bz ~= "" and az ~= bz then return false end
        return true
    end

    local function Eligible(first, second)
        if not first or not second or not SameArea(first, second) then return false end
        if first.playerGUID and second.playerGUID and first.playerGUID ~= second.playerGUID then return false end
        if first.endReason ~= "combat-ended" and first.endReason ~= "inactivity" and first.endReason ~= "new-opponent-after-combat" then return false end
        local firstStart, firstEnd, secondStart = StartAt(first), EndAt(first), StartAt(second)
        if firstStart <= 0 or secondStart <= 0 then return false end
        local boundaryGap = secondStart - firstEnd

        -- Original Mind Control Cap repair: both fragments were the same 1v1.
        if SameOpponent(first, second) and boundaryGap >= -5 and boundaryGap <= CFG.MIND_CONTROL_GRACE then
            local signalAt = MindControlSignalAt(first)
            if signalAt ~= nil then
                local toRestart = secondStart - (firstStart + signalAt)
                if toRestart >= -5 and toRestart <= (CFG.MIND_CONTROL_GRACE + 10) then return "mind-control" end
            end
        end

        -- Ice Block can leave the original opponent immune while somebody else
        -- joins. Require that the still-blocked enemy is retained in BOTH halves;
        -- this prevents a nearby unrelated fight from being glued on merely
        -- because it happened soon after an Ice Block.
        if boundaryGap >= -5 and boundaryGap <= CFG.COMBAT_SUSPENSION_MAX + CFG.COMBAT_SUSPENSION_POST_GRACE + 5 then
            local signalAt = CombatSuspensionSignalAt(first, second)
            if signalAt ~= nil then
                local toRestart = secondStart - (firstStart + signalAt)
                if toRestart >= -5 and toRestart <= CFG.COMBAT_SUSPENSION_MAX + CFG.COMBAT_SUSPENSION_POST_GRACE + 5 then
                    return "combat-suspension"
                end
            end
        end
        return false
    end

    local function ShiftRelativeFields(value, offset)
        if type(value) ~= "table" or offset == 0 then return end
        for _, key in ipairs({"t", "firstSeenAt", "lastSeenAt", "appliedAt", "removedAt", "killedAt", "bubbleHearthAt", "lastDivineShieldAt"}) do
            if tonumber(value[key]) then value[key] = tonumber(value[key]) + offset end
        end
    end

    local function MergeBuffBucket(target, source, offset)
        if type(source) ~= "table" then return target end
        target = type(target) == "table" and target or {}
        for key, incoming in pairs(source) do
            if type(incoming) == "table" then
                ShiftRelativeFields(incoming, offset)
                local current = target[key]
                if type(current) ~= "table" then
                    target[key] = incoming
                else
                    for field, value in pairs(incoming) do
                        if field == "firstSeenAt" or field == "appliedAt" then
                            if tonumber(value) and (not tonumber(current[field]) or tonumber(value) < tonumber(current[field])) then current[field] = value end
                        elseif field == "lastSeenAt" or field == "removedAt" then
                            if tonumber(value) and (not tonumber(current[field]) or tonumber(value) > tonumber(current[field])) then current[field] = value end
                        elseif type(value) == "boolean" then
                            current[field] = current[field] or value
                        elseif current[field] == nil then
                            current[field] = value
                        end
                    end
                end
            elseif target[key] == nil then
                target[key] = incoming
            end
        end
        return target
    end

    local function MergeDetectedBuffs(targetEnemy, sourceEnemy, offset)
        local source = sourceEnemy and sourceEnemy.detectedBuffs
        if type(source) ~= "table" then return end
        targetEnemy.detectedBuffs = type(targetEnemy.detectedBuffs) == "table" and targetEnemy.detectedBuffs or {}
        local target = targetEnemy.detectedBuffs
        target.world = MergeBuffBucket(target.world, source.world, offset)
        target.consumables = MergeBuffBucket(target.consumables, source.consumables, offset)
        target.all = MergeBuffBucket(target.all, source.all, offset)
        target.scanned = target.scanned or source.scanned
        local shiftedFirstScan = tonumber(source.firstScanAt) and (tonumber(source.firstScanAt) + offset) or nil
        if shiftedFirstScan and (not tonumber(target.firstScanAt) or shiftedFirstScan < tonumber(target.firstScanAt)) then
            target.firstScanAt = shiftedFirstScan
        end
    end

    local function MergeIdentity(target, source, offset, isEnemy)
        if not target or not source then return target end
        for _, field in ipairs({"name", "class", "race", "raceFile", "sex", "level", "flags", "spec",
                "portraitFallbackVariant", "portraitDisplayID", "portraitSex", "portraitAppearance", "portraitCapturedAt"}) do
            if target[field] == nil and source[field] ~= nil then target[field] = source[field] end
        end
        target.contributedToEnemy = target.contributedToEnemy or source.contributedToEnemy
        if isEnemy then
            target.died = target.died or source.died
            target.killingBlow = target.killingBlow or source.killingBlow
            target.bubbleHearthed = target.bubbleHearthed or source.bubbleHearthed
            target.playerInteractionCount = (tonumber(target.playerInteractionCount) or 0) + (tonumber(source.playerInteractionCount) or 0)
            target.damageFromPlayer = (tonumber(target.damageFromPlayer) or 0) + (tonumber(source.damageFromPlayer) or 0)
            target.pressureEventCount = (tonumber(target.pressureEventCount) or 0) + (tonumber(source.pressureEventCount) or 0)
            if tonumber(source.killedAt) then target.killedAt = tonumber(source.killedAt) + offset end
            if tonumber(source.bubbleHearthAt) then target.bubbleHearthAt = tonumber(source.bubbleHearthAt) + offset end
            if type(source.killingBlowDetail) == "table" then
                ShiftRelativeFields(source.killingBlowDetail, offset)
                target.killingBlowDetail = source.killingBlowDetail
            end
            MergeDetectedBuffs(target, source, offset)
            target.portraitFrozen = true
        end
        return target
    end

    local function ParticipantKey(identity)
        if not identity then return nil end
        return identity.guid or (identity.name and ("name:" .. ShortName(identity.name):lower())) or nil
    end

    local function MergeIdentityList(targetList, sourceList, offset, isEnemy)
        targetList = type(targetList) == "table" and targetList or {}
        local byKey = {}
        for _, identity in ipairs(targetList) do
            local key = ParticipantKey(identity)
            if key then byKey[key] = identity end
        end
        for _, incoming in ipairs(sourceList or {}) do
            local key = ParticipantKey(incoming)
            local current = key and byKey[key] or nil
            if current then
                MergeIdentity(current, incoming, offset, isEnemy)
            else
                if isEnemy then
                    if tonumber(incoming.killedAt) then incoming.killedAt = tonumber(incoming.killedAt) + offset end
                    if tonumber(incoming.bubbleHearthAt) then incoming.bubbleHearthAt = tonumber(incoming.bubbleHearthAt) + offset end
                    if type(incoming.killingBlowDetail) == "table" then ShiftRelativeFields(incoming.killingBlowDetail, offset) end
                    MergeDetectedBuffs(incoming, {}, offset)
                    incoming.portraitFrozen = true
                end
                targetList[#targetList + 1] = incoming
                if key then byKey[key] = incoming end
            end
        end
        return targetList
    end

    local function MergeLogs(first, second, offset)
        first.session = first.session or {worldPvP=true}
        second.session = second.session or {}
        local target = first.session.worldCombatLog or {}
        for _, entry in ipairs(second.session.worldCombatLog or {}) do
            ShiftRelativeFields(entry, offset)
            target[#target + 1] = entry
        end
        table.sort(target, function(a, b) return (tonumber(a.t) or 0) < (tonumber(b.t) or 0) end)
        first.session.worldCombatLog = target
        first.session.worldCombatTruncated = first.session.worldCombatTruncated or second.session.worldCombatTruncated
    end

    local function MergeUsage(first, second, offset)
        first.session = first.session or {worldPvP=true}
        second.session = second.session or {}
        local a, b = first.session.worldUsage, second.session.worldUsage
        if type(b) ~= "table" then return end
        if type(a) ~= "table" then a = {version=b.version or 2, events={}}; first.session.worldUsage = a end
        a.events = a.events or {}
        for _, entry in ipairs(b.events or {}) do
            ShiftRelativeFields(entry, offset)
            a.events[#a.events + 1] = entry
        end
        table.sort(a.events, function(x, y) return (tonumber(x.t) or 0) < (tonumber(y.t) or 0) end)
        a.version = math.max(tonumber(a.version) or 0, tonumber(b.version) or 0)
        a.truncated = a.truncated or b.truncated
    end

    local function RebuildParticipants(record)
        record.session = record.session or {worldPvP=true}
        local merged = {}
        for guid, identity in pairs(record.session.participants or {}) do merged[guid] = identity end
        for _, identity in ipairs(record.friendlies or {}) do if identity.guid then merged[identity.guid] = identity end end
        for _, identity in ipairs(record.enemies or {}) do if identity.guid then merged[identity.guid] = identity end end
        record.session.participants = merged
        -- Upgrade retained legacy cap signals now that the merged participant map
        -- can correctly identify the player beneath an NPC-sourced backfire aura.
        for _, entry in ipairs(record.session.worldCombatLog or {}) do
            local actorGUID, actorName, backfire = W.MindControlUseInfo(entry, merged)
            if actorGUID then
                entry.mindControlCapUse = true
                entry.mindControlBackfire = entry.mindControlBackfire or backfire or nil
                entry.itemUserGUID = actorGUID
                entry.itemUserName = actorName
                entry.itemID, entry.itemName, entry.itemQuality, entry.itemCategory = 10726, "Gnomish Mind Control Cap", 2, "engineering"
            end
        end
    end

    local function MergeRecords(first, second, mergeKind)
        local firstStart, secondStart = StartAt(first), StartAt(second)
        local offset = math.max(0, secondStart - firstStart)
        first.enemies = MergeIdentityList(first.enemies, second.enemies, offset, true)
        first.friendlies = MergeIdentityList(first.friendlies, second.friendlies, offset, false)
        MergeLogs(first, second, offset)
        MergeUsage(first, second, offset)

        if second.playerDiedAt and tonumber(second.playerDiedAt) then first.playerDiedAt = tonumber(second.playerDiedAt) + offset end
        first.playerDied = first.playerDied or second.playerDied
        first.killingBlows = (tonumber(first.killingBlows) or 0) + (tonumber(second.killingBlows) or 0)
        first.honorableKills = (tonumber(first.honorableKills) or 0) + (tonumber(second.honorableKills) or 0)
        first.npcAssistance = first.npcAssistance or second.npcAssistance
        first.starred = first.starred or second.starred
        first.endReason = second.endReason or first.endReason
        first.endedAt = math.max(EndAt(first), EndAt(second))
        first.duration = math.max(tonumber(first.duration) or 0, offset + math.max(0, tonumber(second.duration) or 0), first.endedAt - firstStart)
        if second.location then first.location = second.location end
        if second.bubbleHearthEnemyGUID then first.bubbleHearthEnemyGUID = second.bubbleHearthEnemyGUID end
        first.honorMessages = first.honorMessages or second.honorMessages
        first.session.worldPvP = true
        if mergeKind == "mind-control" then first.retroMergedMindControl = true end
        if mergeKind == "combat-suspension" then first.retroMergedCombatSuspension = true end
        first.retroMergedCombatSplit = true
        first.mergedEncounterIDs = first.mergedEncounterIDs or {first.id}
        first.mergedEncounterIDs[#first.mergedEncounterIDs + 1] = second.id

        RebuildParticipants(first)
        first.enemyCount = math.max(tonumber(first.enemyCount) or 0, tonumber(second.enemyCount) or 0, #(first.enemies or {}))
        first.friendlyCount = math.max(1, #(first.friendlies or {}))
        first.enemyDeaths = 0
        for _, enemy in ipairs(first.enemies or {}) do if enemy.died then first.enemyDeaths = first.enemyDeaths + 1 end end

        -- Recompute headcount/pressure/outcome from the merged event stream.
        first.pressureModelVersion = nil
        first.friendlyContributionModelVersion = nil
        RebuildPressureEvidence(first)
        RebuildFriendlyContributionEvidence(first)
        first.outcomeModelVersion = 6
        first.resultLabel, first.resultKey = Outcome(first)
        SortEnemiesByRelevance(first)

        -- The two frozen snapshots represented halves of one fight. Rebuild one
        -- snapshot from the now-combined retained evidence so duplicate/phantom
        -- uses (including the old Chronoboon aura bug) are repaired as well.
        first.consumableCost = nil
    end

    local changed, index = false, 1
    while index < #store.encounters do
        local first, second = store.encounters[index], store.encounters[index + 1]
        local mergeKind = Eligible(first, second)
        if mergeKind then
            MergeRecords(first, second, mergeKind)
            table.remove(store.encounters, index + 1)
            changed = true
            -- Do not advance: a pathological multi-split can now be compared to
            -- the next adjacent fragment using the already-merged record.
        else
            index = index + 1
        end
    end
    store.mindControlSplitRepairVersion = repairVersion
    return changed
end

function W.Initialize(observer, db, callbacks)
    W.observer, W.db, W.callbacks = observer, db, callbacks or {}
    observer.worldPvP = observer.worldPvP or {nextSequence = 1, encounters = {}}
    observer.worldPvP.encounters = observer.worldPvP.encounters or {}
    observer.worldPvP.nextSequence = observer.worldPvP.nextSequence or 1
    observer.worldPvP.enemyGoldArchivedCopper = math.max(0, tonumber(observer.worldPvP.enemyGoldArchivedCopper) or 0)
    observer.worldPvP.enemyGoldArchivedPricedCount = math.max(0, tonumber(observer.worldPvP.enemyGoldArchivedPricedCount) or 0)
    observer.worldPvP.enemyGoldArchivedUnpricedCount = math.max(0, tonumber(observer.worldPvP.enemyGoldArchivedUnpricedCount) or 0)

    -- Run structural encounter repairs before any per-record migration. Version
    -- 3 covers both the earlier Mind Control Cap split and full-duration Ice
    -- Block combat drops, including reinforcements joining during the block.
    W.RepairMindControlSplitEncounters(observer.worldPvP)
    if DP.RepairConfirmedEncounter then DP.RepairConfirmedEncounter(observer.worldPvP) end
    if DP.RepairColdbullyFall then DP.RepairColdbullyFall(observer.worldPvP) end

    -- Reclassify older 0.21.x encounters when their saved combat log has
    -- enough evidence to distinguish actual simultaneous opposition from a
    -- sequence of passive victims inside the long encounter timeout.
    --
    -- 0.21.122 introduced encounter-end consumable price snapshots. Legacy
    -- encounters are migrated after login rather than immediately here: TSM and
    -- Auctionator can expose their globals before their market databases are
    -- ready. Waiting briefly prevents Rivals from permanently freezing a false
    -- "unpriced" snapshot during PLAYER_LOGIN.
    local legacyConsumableBackfillVersion = (DP.Usage and DP.Usage.LEGACY_CONSUMABLE_BACKFILL_VERSION) or 8
    local needsLegacyConsumableBackfill = false
    for _, record in ipairs(observer.worldPvP.encounters) do
        local cost = record.consumableCost
        local needsCost = DP.Usage and DP.Usage.NeedsLegacyConsumableBackfill and DP.Usage.NeedsLegacyConsumableBackfill(record)
        if needsCost or not cost or (cost.backfilled and (tonumber(cost.legacyBackfillVersion) or 0) < legacyConsumableBackfillVersion) then
            needsLegacyConsumableBackfill = true
        end
        for enemyIndex, enemy in ipairs(record.enemies or {}) do
            -- portraitTexture was historically populated from SetPortraitTexture's
            -- backing render target. Those handles are session-local (and numeric
            -- values can later alias completely unrelated icon textures), so never
            -- trust a persisted value after login/reload.
            if enemy.portraitTexture ~= nil or enemy.portraitSessionID ~= nil then
                enemy.portraitTexture = nil
                enemy.portraitSessionID = nil
            end
            if not enemy.portraitFallbackVariant then
                enemy.portraitFallbackVariant = (((tonumber(record.timestamp) or 0) + enemyIndex) % 2) + 1
            end
            if enemy.guid and GetPlayerInfoByGUID and (not enemy.class or not enemy.race or not enemy.raceFile) then
                local _, class, localizedRace, englishRace, playerSex = GetPlayerInfoByGUID(enemy.guid)
                enemy.class = enemy.class or class
                enemy.race = enemy.race or localizedRace or englishRace
                enemy.raceFile = enemy.raceFile or englishRace
                enemy.sex = enemy.sex or playerSex
            end
            if not enemy.level then enemy.level = ResolvePlayerLevel(enemy.guid) end
            -- A later sighting is not evidence of the encounter's appearance.
            enemy.portraitFrozen = true
        end
        RebuildPressureEvidence(record)
        RebuildFriendlyContributionEvidence(record)
        if record.playerDeathCause=="FALLING" or record.outcomeModelVersion ~= 6 then
            BubbleHearthEnemy(record)
            record.resultLabel, record.resultKey = Outcome(record)
            record.outcomeModelVersion = 6
        end
        if record.resultKey=="disengaged" then
            record.resultLabel,record.resultKey=Outcome(record)
        end
        record.resultLabel = W.CompactEncounterLabel(record) or record.resultLabel
        SortEnemiesByRelevance(record)
    end
    local function BackfillLegacyConsumablePrices(attempt)
        if not DP.Usage or not DP.Usage.CaptureLegacyWorldConsumableCost then return false end
        local capturedAt = time and time() or 0
        local priceCache, retryAgain, changed = {}, false, false
        for _, record in ipairs(observer.worldPvP.encounters) do
            local cost = record.consumableCost
            local version = cost and tonumber(cost.legacyBackfillVersion) or 0
            local shouldRetry = (DP.Usage.NeedsLegacyConsumableBackfill and DP.Usage.NeedsLegacyConsumableBackfill(record)) or
                not cost or (cost.backfilled and version < legacyConsumableBackfillVersion)
            -- If the first delayed pass still found nothing priceable, give TSM /
            -- Auctionator one final chance after their databases finish loading.
            if not shouldRetry and cost and cost.backfilled and version == legacyConsumableBackfillVersion and
                    (tonumber(cost.legacyBackfillAttempt) or 0) < attempt and
                    (tonumber(cost.pricedCount) or 0) == 0 and (tonumber(cost.unpricedCount) or 0) > 0 then
                shouldRetry = true
            end
            if shouldRetry then
                local snapshot = DP.Usage.CaptureLegacyWorldConsumableCost(record, capturedAt, priceCache, true)
                if snapshot then
                    snapshot.legacyBackfillAttempt = attempt
                    record.consumableCost = snapshot
                    changed = true
                    if attempt < 2 and (tonumber(snapshot.pricedCount) or 0) == 0 and
                            (tonumber(snapshot.unpricedCount) or 0) > 0 then
                        retryAgain = true
                    end
                end
            end
        end
        if changed and W.callbacks and W.callbacks.changed then W.callbacks.changed() end
        return retryAgain
    end

    if needsLegacyConsumableBackfill then
        if C_Timer and C_Timer.After then
            C_Timer.After(2, function()
                if BackfillLegacyConsumablePrices(1) then
                    C_Timer.After(6, function() BackfillLegacyConsumablePrices(2) end)
                end
            end)
        else
            BackfillLegacyConsumablePrices(2)
        end
    end

    DP.OverviewArchive.Recover(observer.worldPvP,observer.guid or (UnitGUID and UnitGUID("player")))
    TrimEncounterStore(observer.worldPvP)
    -- World PvP tracking is now a core Rivals feature rather than a user-toggleable mode.
    -- Force legacy profiles that previously disabled it back on during initialization.
    db.worldPvPEnabled = true
    if db.worldPvPOverviewMode ~= "world" then db.worldPvPOverviewMode = "duels" end


end

function W.Enabled()
    return W.db and W.db.worldPvPEnabled ~= false
end

function W.SetEnabled(enabled)
    if not W.db then return end
    W.db.worldPvPEnabled = enabled and true or false
    if not W.db.worldPvPEnabled and W.active then W.Finish("tracking-disabled") end
    if W.callbacks and W.callbacks.changed then W.callbacks.changed() end
end

function W.GetEncounters()
    return W.observer and W.observer.worldPvP and W.observer.worldPvP.encounters or {}
end

function W.IsStarred(record)
    return record and record.starred and true or false
end

function W.SetStarred(record, starred)
    if not record then return end
    record.starred = starred and true or nil
    if W.observer and W.observer.worldPvP then TrimEncounterStore(W.observer.worldPvP) end
    if W.details and W.details.record == record and W.RefreshDetailStar then W.RefreshDetailStar() end
    if W.callbacks and W.callbacks.changed then W.callbacks.changed() end
end

-- Capture only an enemy opening against the player, before its damage.
function W.CaptureEngagementHealth(session, info)
    if not info or info[4] == session.playerGUID or info[8] ~= session.playerGUID or
            not IsPlayer(info[6]) or not IsHostile(info[6]) or not IsPressureEvent(info[2]) or
            not UnitHealth or not UnitHealthMax then return end
    local health, maximum = UnitHealth("player"), UnitHealthMax("player")
    if not maximum or maximum <= 0 or not health then return end
    local damage = info[2] == "SWING_DAMAGE" and tonumber(info[12]) or
        (info[2] == "SPELL_DAMAGE" or info[2] == "SPELL_PERIODIC_DAMAGE" or info[2] == "RANGE_DAMAGE") and tonumber(info[15]) or 0
    -- CLEU may arrive after health updates. Adding the opening hit is a
    -- conservative upper bound; a healthy target cannot become a low-health
    -- engagement merely because this first hit was large.
    health = math.min(maximum, health + math.max(0, damage or 0))
    session.engagementHealthPercent = 100 * health / maximum
    session.lowHealthEngagement = session.engagementHealthPercent <= 50 or nil
end

function W.Start(playerGUID, info)
    if not W.Enabled() or not InOpenWorld() or (DP.HasActiveDuel and DP.HasActiveDuel()) then return nil end
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    local session = {
        worldPvP = true,
        playerGUID = playerGUID,
        playerName = playerName,
        playerClass = playerClass,
        playerLevel = UnitLevel and UnitLevel("player") or nil,
        startedAt = time(),
        startedElapsed = GetTime(),
        lastActivity = GetTime(),
        friendlies = {},
        enemies = {},
        participants = {},
        positions = {},
        peakFriendly = 1,
        peakEnemy = 0,
        friendlyContributionModelVersion = 1,
        contestingEnemyCount = 0,
        peakContestingEnemies = 0,
        honorableKills = 0,
        killingBlows = 0,
        combatSuspensions = {},
    }
    W.CaptureEngagementHealth(session, info)
    local player = AddParticipant(session, "friendlies", playerGUID, playerName, COMBATLOG_OBJECT_AFFILIATION_MINE)
    session.participants[playerGUID] = player
    AddPosition(session)
    W.active = session
    if C_Timer and C_Timer.NewTicker then
        W.ticker = C_Timer.NewTicker(2, function()
            local active = W.active
            if not active then return end
            local now = GetTime()
            ScanVisibleEnemyBuffs(active)
            local quiet = now - (active.lastActivity or now)
            if W.CompletedEnemyGrace(active, now) then W.Finish("all-enemies-dead"); return end
            local allEnemiesDead, enemyCount = true, 0
            for _, enemy in pairs(active.enemies or {}) do
                enemyCount = enemyCount + 1
                if not enemy.died then allEnemiesDead = false end
            end
            if active.outOfCombatAt and now - active.outOfCombatAt >= CFG.COMBAT_END_GRACE and
                    now >= (tonumber(active.mindControlGraceUntil) or 0) and not W.CombatSuspensionActive(active, now) then
                W.Finish("combat-ended")
            elseif enemyCount > 0 and (active.playerDied or allEnemiesDead) and quiet >= CFG.ALL_ENEMIES_DEAD_GRACE then
                W.Finish(active.playerDied and "player-death" or "all-enemies-dead")
            elseif quiet >= CFG.INACTIVITY_TIMEOUT then
                W.Finish("inactivity")
            end
        end)
    end
    return session
end

-- NPC guards and corpse aura removals must not postpone a completed PvP fight.
-- Allow the existing six-second grace for resurrection before sealing it.
function W.CompletedEnemyGrace(session, now)
    local latest, total = 0, 0
    for _, enemy in pairs(session.enemies or {}) do
        if not enemy.died or not enemy.killedAt then return false end
        total = total + 1
        latest = math.max(latest, enemy.killedAt)
    end
    return total > 0 and not session.playerDied and
        now - session.startedElapsed - latest >= CFG.ALL_ENEMIES_DEAD_GRACE
end

function W.ObserveEnemyRevival(session, info)
    local event = info[2]
    local revived = event == "SPELL_RESURRECT" and session.enemies[info[8]] or
        event == "SPELL_CAST_SUCCESS" and session.enemies[info[4]] or
        (event == "SWING_DAMAGE" or event == "SWING_MISSED") and session.enemies[info[4]]
    if revived and revived.died then
        revived.died, revived.killedAt, revived.killingBlow = nil, nil, nil
    end
end

local function MarkInteraction(session, info)
    local event = info[2]
    local sourceGUID, sourceName, sourceFlags = info[4], info[5], info[6]
    local destGUID, destName, destFlags = info[8], info[9], info[10]
    local playerGUID = session.playerGUID
    local group = GroupGUIDs(playerGUID)
    local supportEvent = event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" or event == "SPELL_DISPEL" or event == "SPELL_STOLEN"
    local appliedToOther = event == "SPELL_AURA_APPLIED" and sourceGUID ~= destGUID

    local sourcePlayer, destPlayer = IsPlayer(sourceFlags), IsPlayer(destFlags)
    local sourceHostile, destHostile = sourcePlayer and IsHostile(sourceFlags), destPlayer and IsHostile(destFlags)
    local sourceFriendly, destFriendly = sourcePlayer and (sourceGUID == playerGUID or group[sourceGUID] or IsFriendly(sourceFlags)),
        destPlayer and (destGUID == playerGUID or group[destGUID] or IsFriendly(destFlags))

    if sourceHostile and (destGUID == playerGUID or group[destGUID] or session.friendlies[destGUID] or
        ((supportEvent or appliedToOther) and session.enemies[destGUID])) then
        local enemy = AddParticipant(session, "enemies", sourceGUID, sourceName, sourceFlags)
        session.participants[sourceGUID] = enemy
    end
    if destHostile and (sourceGUID == playerGUID or group[sourceGUID] or session.friendlies[sourceGUID]) then
        local enemy = AddParticipant(session, "enemies", destGUID, destName, destFlags)
        session.participants[destGUID] = enemy
    end

    -- Unique enemies are history participants; outnumbered credit is stricter.
    -- An enemy counts as active opposition only after it actually attacks, CCs,
    -- interrupts, dispels or otherwise applies hostile pressure to the player.
    if sourceHostile and (destGUID == playerGUID or session.friendlies[destGUID]) and IsPressureEvent(event) then
        local enemy = session.enemies[sourceGUID] or AddParticipant(session, "enemies", sourceGUID, sourceName, sourceFlags)
        if enemy then
            enemy.pressuredPlayer = true
            enemy.firstPressureAt = enemy.firstPressureAt or GetTime()
            enemy.lastPressureAt = GetTime()
            if destGUID == playerGUID then enemy.pressureEventCount = (enemy.pressureEventCount or 0) + 1 end
            session.participants[sourceGUID] = enemy
        end
    end

    if sourceGUID == playerGUID and session.enemies[destGUID] and IsFriendlyContributionEvent(event) then
        local enemy = session.enemies[destGUID]
        enemy.playerInteractionCount = (enemy.playerInteractionCount or 0) + 1
        local amount
        if event == "SWING_DAMAGE" then amount = tonumber(info[12])
        elseif event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" then amount = tonumber(info[15]) end
        if amount and amount > 0 then enemy.damageFromPlayer = (enemy.damageFromPlayer or 0) + amount end
    end

    -- Friendly NvN headcount is offensive contribution only. A same-faction player
    -- is part of the kill once they damage, CC, interrupt, offensively dispel,
    -- steal/drain, miss an attack against, or land the killing blow on a tracked
    -- enemy. Merely being nearby/targeted, self-healing/bandaging, or healing the
    -- player does not turn a solo kill into 2v1.
    if sourcePlayer and sourceGUID ~= playerGUID and (group[sourceGUID] or sourceFriendly) and
        session.enemies[destGUID] and IsFriendlyContributionEvent(event) then
        local friendly = AddParticipant(session, "friendlies", sourceGUID, sourceName, sourceFlags)
        if friendly then
            friendly.contributedToEnemy = true
            session.participants[sourceGUID] = friendly
        end
    end

    -- NPC participation is deliberately only a disclosure flag; it never
    -- changes the player-vs-player headcount used for outnumbered recognition.
    if not sourcePlayer and sourceGUID and (destGUID == playerGUID or session.enemies[destGUID]) then session.npcAssistance = true end
    if not destPlayer and destGUID and (sourceGUID == playerGUID or session.enemies[sourceGUID]) then session.npcAssistance = true end
    UpdatePeaks(session)
end

local function InferParticipantClassFromCombat(session, guid, spellID, spellName)
    if not session or not guid or not DP.Specs or not DP.Specs.InferClassFromAbility then return nil end
    local identity = session.participants and session.participants[guid]
    if identity and identity.class then return identity.class end
    local class = DP.Specs.InferClassFromAbility(spellID, spellName)
    if not class then return nil end
    if identity then identity.class = class end
    if session.enemies and session.enemies[guid] then session.enemies[guid].class = session.enemies[guid].class or class end
    if session.friendlies and session.friendlies[guid] then session.friendlies[guid].class = session.friendlies[guid].class or class end
    return class
end

local function TrackSpecialEscape(session, info)
    if not session or not info then return end
    local event = info[2]
    if event ~= "SPELL_CAST_SUCCESS" and event ~= "SPELL_AURA_APPLIED" and event ~= "SPELL_AURA_REFRESH" then return end
    local spellID, spellName = CombatSpellInfo(info)
    local elapsed = math.max(0, GetTime() - session.startedElapsed)

    if IsDivineShieldSpell(spellID, spellName) then
        local guid = info[4] or info[8]
        local enemy = guid and session.enemies and session.enemies[guid]
        if not enemy and info[8] then enemy = session.enemies and session.enemies[info[8]] end
        if enemy then
            enemy.lastDivineShieldAt = elapsed
            enemy.class = enemy.class or "PALADIN"
        end
        return
    end

    if event == "SPELL_CAST_SUCCESS" and IsHearthstoneSpell(spellID, spellName) then
        local enemy = session.enemies and session.enemies[info[4]]
        if enemy and enemy.lastDivineShieldAt and elapsed - enemy.lastDivineShieldAt >= 0 and
            elapsed - enemy.lastDivineShieldAt <= CFG.BUBBLE_HEARTH_WINDOW then
            enemy.bubbleHearthed = true
            enemy.bubbleHearthAt = elapsed
            enemy.class = enemy.class or "PALADIN"
            session.bubbleHearthEnemyGUID = enemy.guid
        end
    end
end

local function ScreenshotEnemyDeath(session, enemy, delay)
    if not session or not enemy or not enemy.guid then return end
    session.rivalsScreenshotDeaths = session.rivalsScreenshotDeaths or {}
    if session.rivalsScreenshotDeaths[enemy.guid] then return end

    local guid, name = enemy.guid, enemy.name
    local function Capture()
        if not session.rivalsScreenshotDeaths or session.rivalsScreenshotDeaths[guid] ~= "pending" then return end
        if DP.TakeRivalsScreenshot and DP.TakeRivalsScreenshot("world", name) then
            session.rivalsScreenshotDeaths[guid] = true
        else
            session.rivalsScreenshotDeaths[guid] = nil
        end
    end

    -- Call this only after PARTY_KILL / UNIT_DIED has confirmed death. The short
    -- delay lets the corpse plus Killing Blow/HK combat text settle before
    -- Screenshot() is serviced. Mark it pending immediately so duplicate death
    -- signals cannot schedule a second capture.
    if delay and delay > 0 and C_Timer and C_Timer.After then
        session.rivalsScreenshotDeaths[guid] = "pending"
        C_Timer.After(delay, Capture)
        return
    end

    if DP.TakeRivalsScreenshot and DP.TakeRivalsScreenshot("world", name) then
        session.rivalsScreenshotDeaths[guid] = true
    end
end

-- Damage events are still useful for retaining killing-blow detail, but Classic
-- can occasionally make an overkill payload look lethal across health-form
-- transitions. Only PARTY_KILL / UNIT_DIED is trusted as screenshot confirmation.
local function IsLethalDamageEvent(info)
    if not info then return false end
    local event = info[2]
    local overkill
    if event == "SWING_DAMAGE" then
        overkill = tonumber(info[13])
    elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" or
        event == "DAMAGE_SHIELD" or event == "DAMAGE_SPLIT" then
        overkill = tonumber(info[16])
    elseif event == "ENVIRONMENTAL_DAMAGE" then
        overkill = tonumber(info[14])
    elseif event == "SPELL_INSTAKILL" then
        return true
    end
    return overkill ~= nil and overkill >= 0
end

function W.Combat(playerGUID)
    if not W.Enabled() or not CombatLogGetCurrentEventInfo then return end
    if not InOpenWorld() or (DP.HasActiveDuel and DP.HasActiveDuel()) then
        if W.active then W.Finish("duel-or-instance") end
        return
    end
    local info = {CombatLogGetCurrentEventInfo()}
    local event = info[2]
    local session = W.active
    if session and W.CompletedEnemyGrace(session, GetTime()) then
        W.Finish("all-enemies-dead")
        session = nil
    end
    local boundarySpellID, boundarySpellName = CombatSpellInfo(info)
    if session and W.IsMindControlCapSpell(boundarySpellID, boundarySpellName) then
        session.mindControlGraceUntil = math.max(tonumber(session.mindControlGraceUntil) or 0, GetTime() + CFG.MIND_CONTROL_GRACE)
        session.lastActivity = GetTime()
    end
    if session then W.UpdateCombatSuspension(session, info, boundarySpellID, boundarySpellName) end
    if session and session.outOfCombatAt and PvPInteraction(info, playerGUID) then
        local now = GetTime()
        local hostileGUID = DirectHostileGUID(info, playerGUID)
        local suspended = W.CombatSuspensionActive(session, now)
        if now - session.outOfCombatAt >= CFG.COMBAT_END_GRACE and now >= (tonumber(session.mindControlGraceUntil) or 0) and not suspended then
            -- The grace period elapsed before the next direct PvP event. Even
            -- the same opponent is now a new encounter unless an explicit
            -- suspension mechanic (for example Ice Block) still bridges it.
            W.Finish("combat-ended")
            session = nil
        elseif hostileGUID and not session.enemies[hostileGUID] and not suspended then
            -- A different player starting the next combat after a full combat
            -- drop is normally a new fight. During an active Ice Block, though,
            -- that player is a reinforcement joining the encounter already in
            -- progress, not the start of a fresh encounter.
            W.Finish("new-opponent-after-combat")
            session = nil
        else
            -- Same opponent returned, or a reinforcement arrived while the prior
            -- opponent was in a tracked combat-suspension state. Keep continuity.
            session.outOfCombatAt = nil
        end
    end
    if not session then
        if not PvPInteraction(info, playerGUID) then return end
        session = W.Start(playerGUID, info)
        if not session then return end
        if W.IsMindControlCapSpell(boundarySpellID, boundarySpellName) then
            session.mindControlGraceUntil = GetTime() + CFG.MIND_CONTROL_GRACE
        end
    end

    -- Explicit resurrection, or a dead enemy actively casting again, reopens
    -- that life while the encounter is still unfinished. Periodic damage and
    -- corpse aura removals are not evidence of resurrection.
    W.ObserveEnemyRevival(session, info)
    MarkInteraction(session, info)
    TrackSpecialEscape(session, info)

    -- Keep the lethal damage event for killing-blow detail, but do NOT use it as
    -- screenshot proof. Classic can report an overkill-style damage payload while
    -- a player is still alive during health-form transitions (notably Druids
    -- shifting forms). The screenshot is armed only after PARTY_KILL / UNIT_DIED
    -- confirms the opponent actually died below.
    if IsLethalDamageEvent(info) then
        if info[8]==playerGUID then
            session.playerDeathCause=event=="ENVIRONMENTAL_DAMAGE" and info[12]=="FALLING" and "FALLING" or nil
        end
        local lethalEnemy = session.enemies[info[8]]
        if lethalEnemy and info[4] == playerGUID then
            local lethalSpellID, lethalSpellName = CombatSpellInfo(info)
            local amount, overkill, critical
            if event == "SWING_DAMAGE" then
                amount, overkill, critical = tonumber(info[12]), tonumber(info[13]), info[18] == true
            elseif event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" then
                amount, overkill, critical = tonumber(info[15]), tonumber(info[16]), info[21] == true
            end
            lethalEnemy.killingBlowDetail = {
                t = math.max(0, GetTime() - session.startedElapsed),
                event = event,
                spellID = lethalSpellID,
                spellName = lethalSpellName or (event == "SWING_DAMAGE" and "Melee" or nil),
                amount = amount,
                overkill = overkill and math.max(0, overkill) or nil,
                critical = critical,
            }
        end
    end

    if IsPlayer(info[6]) then
        local spellID, spellName = CombatSpellInfo(info)
        if spellID or spellName then InferParticipantClassFromCombat(session, info[4], spellID, spellName) end
    end
    TrackCombatLogBuff(session, info)
    ScanVisibleEnemyBuffs(session)
    local involvesKnown = session.participants[info[4]] or session.participants[info[8]] or EventTouchesPlayer(info, playerGUID)
    if not involvesKnown then return end

    local pvpPlayers = (IsPlayer(info[6]) and (session.friendlies[info[4]] or session.enemies[info[4]])) or
        (IsPlayer(info[10]) and (session.friendlies[info[8]] or session.enemies[info[8]]))
    if pvpPlayers or event == "UNIT_DIED" or event == "PARTY_KILL" then
        session.lastActivity = GetTime()
        AddPosition(session)
    end

    if event == "PARTY_KILL" then
        local enemy = session.enemies[info[8]]
        if enemy and not IsUnconsciousDeathEvent(info) then
            enemy.level = enemy.level or ResolvePlayerLevel(enemy.guid)
            if not enemy.died then
                local location=PlayerPosition()
                if location then
                    session.killLocations=session.killLocations or {}
                    session.killLocations[#session.killLocations+1]=location
                end
            end
            enemy.died = true; enemy.killedAt = GetTime() - session.startedElapsed
            session.lastKillPosition = PlayerPosition() or session.lastKillPosition
            if info[4] == playerGUID and not enemy.killingBlow then
                session.killingBlows = (session.killingBlows or 0) + 1
                enemy.killingBlow = true
                if DP.MultiKill and DP.MultiKill.OnKillingBlow then DP.MultiKill.OnKillingBlow(enemy.level, session.playerLevel, true) end
            end
            ScreenshotEnemyDeath(session, enemy, CFG.WPVP_SCREENSHOT_KILL_DELAY)
        end
    elseif event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
        -- Feign Death and other unconscious transitions deliberately masquerade
        -- as death in CLEU. They are encounter activity, not a real death: do
        -- not set died/playerDied, advance kill stats, or arm a screenshot.
        if not IsUnconsciousDeathEvent(info) then
            if info[8] == playerGUID then
                session.playerDied = true
                session.playerDiedAt = GetTime() - session.startedElapsed
                session.deathPosition = PlayerPosition() or session.deathPosition
                if DP.MultiKill and DP.MultiKill.Reset then DP.MultiKill.Reset() end
            elseif session.enemies[info[8]] then
                local enemy = session.enemies[info[8]]
                enemy.level = enemy.level or ResolvePlayerLevel(info[8])
                if not enemy.died then
                    local location=PlayerPosition()
                    if location then session.killLocations=session.killLocations or {};session.killLocations[#session.killLocations+1]=location end
                end
                enemy.died = true
                enemy.killedAt = GetTime() - session.startedElapsed
                session.lastKillPosition = PlayerPosition() or session.lastKillPosition
                ScreenshotEnemyDeath(session, enemy, CFG.WPVP_SCREENSHOT_KILL_DELAY)
            elseif session.friendlies[info[8]] then
                local friendly = session.friendlies[info[8]]
                friendly.died = true
                friendly.killedAt = GetTime() - session.startedElapsed
            end
        end
    end
    UpdateEnemyPressure(session)

    AppendWorldLog(session, info)
    if DP.Specs and DP.Specs.ObserveWorldCombat then DP.Specs.ObserveWorldCombat(session, info) end
    if DP.Usage and DP.Usage.WorldObserve then DP.Usage.WorldObserve(session, playerGUID, info) end
end

function W.Honor(message)
    local session = W.active
    if not session or type(message) ~= "string" then return end
    session.honorableKills = (session.honorableKills or 0) + 1
    session.honorMessages = session.honorMessages or {}
    if #session.honorMessages < 16 then session.honorMessages[#session.honorMessages + 1] = message end
    session.lastActivity = GetTime()
end

local function FormatToastResultLabel(record)
    local text = record and (record.resultLabel or record.resultKey) or "World PvP"
    if type(text) ~= "string" then return "World PvP" end
    text = text:gsub("_", " "):lower()
    return (text:gsub("%f[%a]%a", string.upper))
end

local function ToastEnemyNames(record, limit)
    local names = {}
    local enemies = record and record.enemies or {}
    local max = math.min(#enemies, limit or 4)
    for index = 1, max do
        local enemy = enemies[index]
        local name = ShortName(enemy and enemy.name)
        if enemy and enemy.class and DP.Theme and DP.Theme.ClassName then
            names[#names + 1] = DP.Theme.ClassName(name, enemy.class)
        else
            names[#names + 1] = "|cffadb5c2" .. name .. "|r"
        end
    end
    if #enemies > max then names[#names + 1] = "|cff7f8794+" .. tostring(#enemies - max) .. " more|r" end
    return table.concat(names, "   ")
end

local function ToastOpponentStats(enemy)
    if not enemy or not W.BuildMatchups then return nil end
    local key = enemy.guid or enemy.name
    for _, stats in ipairs(W.BuildMatchups().Opponents or {}) do
        if stats.key == key then return stats end
    end
    return nil
end

local function ShowToastOpponentTooltip(button)
    local enemy = button and button.enemy
    if not enemy or not GameTooltip then return end
    local stats = button.stats or ToastOpponentStats(enemy)
    local className = enemy.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[enemy.class]) or enemy.class) or "Unknown class"
    local level = enemy.level and ("Level " .. tostring(enemy.level)) or "Level unknown"
    local record = button.record
    local contested = record and (record.peakContestingEnemies or record.contestingEnemyCount or record.enemyCount or 0) or 0
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText(DP.Theme.ClassName(ShortName(enemy.name), enemy.class))
    GameTooltip:AddLine(level .. " " .. className .. (enemy.spec and enemy.spec.label and (" — " .. enemy.spec.label) or ""), .72, .76, .82)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("This fight", 1, .82, .36)
    if enemy.died then
        GameTooltip:AddLine(enemy.killingBlow and "Killed by you — killing blow" or "Killed by you", 1, .72, .36)
    else
        GameTooltip:AddLine("Survived the encounter", .40, .90, .68)
    end
    if contested and contested > 0 then
        GameTooltip:AddLine(string.format("Part of a %s against you", EncounterHeadcount(record)), .75, .78, .84)
    end
    local world, consumes = CountDetectedBuffs(enemy)
    if world > 0 or consumes > 0 then
        GameTooltip:AddLine(string.format("Detected in fight: %d world buff%s, %d consumable%s",
            world, world == 1 and "" or "s", consumes, consumes == 1 and "" or "s"), .88, .78, .48)
    end
    if stats then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Lifetime", 1, .82, .36)
        GameTooltip:AddLine(string.format("World PvP: %d-%d", stats.kills or 0, stats.deaths or 0), 1, 1, 1)
        GameTooltip:AddLine(string.format("Solo: %d-%d", stats.soloKills or 0, stats.soloDeaths or 0), .75, .78, .84)
        GameTooltip:AddLine(string.format("Recorded encounters: %d", stats.encounters or 0), .75, .78, .84)
        if contested and contested > 1 then
            GameTooltip:AddLine(string.format("Seen in outnumbered fights: %s", EncounterHeadcount(record)), .75, .78, .84)
        end
        if (stats.currentStreak or 0) > 1 or (stats.bestStreak or 0) > 1 then
            GameTooltip:AddLine(string.format("Streaks: %d current • %d best", stats.currentStreak or 0, stats.bestStreak or 0), .75, .78, .84)
        end
    end
    GameTooltip:Show()
end

local function EnsureResultToast()
    if W.resultToast then return W.resultToast end

    local toast = CreateFrame("Frame", "RivalsWorldPvPResultToast", UIParent)
    toast:SetSize(372, 124)
    toast:SetPoint("TOP", UIParent, "TOP", 0, -148)
    toast:SetFrameStrata("DIALOG")
    toast:SetClampedToScreen(true)
    toast:EnableMouse(true)

    -- Fill completely beneath the border so the plaque has no exposed square
    -- corners or dead strips around the edge.
    toast.bg = toast:CreateTexture(nil, "BACKGROUND")
    toast.bg:SetPoint("TOPLEFT", 1, -1)
    toast.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    toast.bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
    toast.bg:SetVertexColor(.095, .10, .125, .995)

    toast.field = toast:CreateTexture(nil, "BORDER")
    toast.field:SetPoint("TOPLEFT", 5, -5)
    toast.field:SetPoint("BOTTOMRIGHT", -5, 5)
    toast.field:SetColorTexture(.010, .018, .029, .965)

    local outer = DP.Theme.Border(toast, 0, 0, 372, 124)
    outer:EnableMouse(false)
    if outer.SetBackdropBorderColor then outer:SetBackdropBorderColor(.94, .72, .33, .98) end
    local inner = DP.Theme.Border(toast, 4, -4, 364, 116)
    inner:EnableMouse(false)
    if inner.SetBackdropBorderColor then inner:SetBackdropBorderColor(.40, .29, .16, .84) end

    -- Use one corner atlas in all four corners and mirror it rather than rotating
    -- it. Rotation on this atlas makes the four corners look subtly different.
    local function Corner(point, x, y, flipX, flipY)
        local tex = toast:CreateTexture(nil, "OVERLAY")
        tex:SetSize(18, 18)
        tex:SetPoint(point, toast, point, x, y)
        if tex.SetAtlas then tex:SetAtlas("UI-CharacterCreate-Metal-Finery-Corner", false)
        else tex:SetTexture("Interface\\Buttons\\UI-Quickslot2") end
        tex:SetTexCoord(flipX and 1 or 0, flipX and 0 or 1, flipY and 1 or 0, flipY and 0 or 1)
        tex:SetVertexColor(.96, .81, .49, .94)
        return tex
    end
    toast.cornerTL = Corner("TOPLEFT", 4, -4, false, false)
    toast.cornerTR = Corner("TOPRIGHT", -4, -4, true, false)
    toast.cornerBL = Corner("BOTTOMLEFT", 4, 4, false, true)
    toast.cornerBR = Corner("BOTTOMRIGHT", -4, 4, true, true)

    toast.brandHeader = toast:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    toast.brandHeader:SetPoint("TOP", toast, "TOP", 0, -7)
    toast.brandHeader:SetText("RIVALS")
    toast.brandHeader:SetTextColor(.88, .74, .44, .9)
    local brandPath, _, brandFlags = toast.brandHeader:GetFont()
    if brandPath then toast.brandHeader:SetFont(brandPath, 8, "OUTLINE") end

    -- Use a crisper in-game timer/plaque asset for the title treatment.
    -- It reads more cleanly than the enlarged banner curls at this size.
    toast.banner = CreateFrame("Frame", nil, toast)
    toast.banner:SetSize(220, 30)
    toast.banner:SetPoint("TOP", toast, "TOP", 0, -26)
    toast.bannerBG = toast.banner:CreateTexture(nil, "ARTWORK", nil, 2)
    toast.bannerBG:SetAllPoints()
    if toast.bannerBG.SetAtlas then
        toast.bannerBG:SetAtlas("challenges-timerbg", true)
    else
        toast.bannerBG:SetColorTexture(.12, .16, .28, .9)
    end

    -- Title text is parented to the banner frame itself so it is guaranteed to
    -- render above the banner artwork.
    toast.titleCount = toast.banner:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    toast.titleCount:SetJustifyH("LEFT")
    toast.titleCount:SetTextColor(1, .92, .58, 1)
    toast.titleCount:SetShadowColor(0, 0, 0, 1)
    toast.titleCount:SetShadowOffset(1, -1)
    toast.titleCount:SetDrawLayer("OVERLAY", 7)

    toast.victoryLetters = {}
    for i = 1, 7 do
        local letter = toast.banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        letter:SetJustifyH("LEFT")
        letter:SetTextColor(1, .84, .38, 1)
        letter:SetShadowColor(0, 0, 0, 1)
        letter:SetShadowOffset(1, -1)
        letter:SetAlpha(0)
        letter:SetDrawLayer("OVERLAY", 7)
        letter.anim = letter:CreateAnimationGroup()
        local alpha = letter.anim:CreateAnimation("Alpha")
        alpha:SetOrder(1); alpha:SetFromAlpha(0); alpha:SetToAlpha(1); alpha:SetDuration(.18); alpha:SetSmoothing("OUT")
        letter.anim:SetScript("OnFinished", function() letter:SetAlpha(1) end)

        letter.glow = toast.banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        letter.glow:SetJustifyH("LEFT")
        letter.glow:SetTextColor(1, 1, .72, 1)
        letter.glow:SetShadowColor(1, .72, .18, .9)
        letter.glow:SetShadowOffset(0, 0)
        letter.glow:SetAlpha(0)
        letter.glow:SetDrawLayer("OVERLAY", 8)
        letter.glowAnim = letter.glow:CreateAnimationGroup()
        local glowIn = letter.glowAnim:CreateAnimation("Alpha")
        glowIn:SetOrder(1); glowIn:SetFromAlpha(0); glowIn:SetToAlpha(1); glowIn:SetDuration(.09)
        local glowOut = letter.glowAnim:CreateAnimation("Alpha")
        glowOut:SetOrder(2); glowOut:SetFromAlpha(1); glowOut:SetToAlpha(0); glowOut:SetDuration(.26); glowOut:SetSmoothing("OUT")
        letter.glowAnim:SetScript("OnFinished", function() letter.glow:SetAlpha(0) end)
        toast.victoryLetters[i] = letter
    end

    -- Crest treatment: no box, just faction crests flanking the victory banner
    -- while remaining fully inside the plaque.
    local function CreateToastCrest(anchorPoint, x, y)
        local holder = CreateFrame("Frame", nil, toast)
        holder:SetSize(52, 52)
        holder:SetPoint(anchorPoint, toast, anchorPoint, x, y)
        holder.base = holder:CreateTexture(nil, "ARTWORK")
        holder.hover = holder:CreateTexture(nil, "ARTWORK")
        holder.selected = holder:CreateTexture(nil, "ARTWORK")
        holder.flash = holder:CreateTexture(nil, "OVERLAY")
        for _, tex in ipairs({holder.base, holder.hover, holder.selected, holder.flash}) do
            tex:SetPoint("CENTER")
            tex:SetSize(48, 48)
        end
        holder.flash:SetBlendMode("ADD")
        holder.flash:SetAlpha(0)
        holder.shine = holder:CreateTexture(nil, "OVERLAY")
        holder.shine:SetTexture("Interface\\Cooldown\\star4")
        holder.shine:SetBlendMode("ADD")
        holder.shine:SetVertexColor(1, .97, .70, 1)
        holder.shine:SetSize(16, 16)
        if anchorPoint == "TOPLEFT" then
            holder.shine:SetPoint("TOPLEFT", holder, "TOPLEFT", 12, -26)
        else
            holder.shine:SetPoint("TOPLEFT", holder, "TOPLEFT", 7, -12)
        end
        holder.shine:SetAlpha(0)
        holder.shineAnim = holder.shine:CreateAnimationGroup()
        local shineIn = holder.shineAnim:CreateAnimation("Alpha")
        shineIn:SetOrder(1); shineIn:SetFromAlpha(0); shineIn:SetToAlpha(1); shineIn:SetDuration(.10)
        local shineGrow = holder.shineAnim:CreateAnimation("Scale")
        shineGrow:SetOrder(1); shineGrow:SetScale(1.45, 1.45); shineGrow:SetOrigin("CENTER", 0, 0); shineGrow:SetDuration(.20); shineGrow:SetSmoothing("OUT")
        local shineSpin = holder.shineAnim:CreateAnimation("Rotation")
        shineSpin:SetOrder(1); shineSpin:SetDegrees(80); shineSpin:SetOrigin("CENTER", 0, 0); shineSpin:SetDuration(.20); shineSpin:SetSmoothing("OUT")
        local shineOut = holder.shineAnim:CreateAnimation("Alpha")
        shineOut:SetOrder(2); shineOut:SetFromAlpha(1); shineOut:SetToAlpha(0); shineOut:SetDuration(.34)
        holder.shineAnim:SetScript("OnFinished", function() holder.shine:SetAlpha(0); holder.shine:SetRotation(0) end)
        return holder
    end
    toast.leftCrest = CreateToastCrest("TOPLEFT", 24, -28)
    toast.rightCrest = CreateToastCrest("TOPRIGHT", -24, -28)
    toast.crestHolders = { toast.leftCrest, toast.rightCrest }

    toast.summaryFrame = CreateFrame("Frame", nil, toast)
    toast.summaryFrame:SetPoint("TOPLEFT", 18, -58)
    toast.summaryFrame:SetPoint("TOPRIGHT", -18, -58)
    toast.summaryFrame:SetHeight(20)

    toast.summary = toast.summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toast.summary:SetAllPoints()
    toast.summary:SetJustifyH("CENTER")
    local summaryFontPath, _, summaryFontFlags = toast.summary:GetFont()
    function toast:SetSummaryFontSize(size)
        if summaryFontPath then self.summary:SetFont(summaryFontPath, size, summaryFontFlags or "") end
    end
    toast:SetSummaryFontSize(15)
    toast.summaryFadeOut = toast.summary:CreateAnimationGroup()
    local summaryOut = toast.summaryFadeOut:CreateAnimation("Alpha")
    summaryOut:SetOrder(1); summaryOut:SetFromAlpha(1); summaryOut:SetToAlpha(0); summaryOut:SetDuration(.16)
    toast.summaryFadeOut:SetScript("OnFinished", function()
        if toast.summarySwapMode == "newrecord" then
            toast.summary:Hide()
            toast.newRecordText:SetScale(1)
            toast.newRecordText:SetAlpha(0)
            toast.newRecordText:Show()
            toast.newRecordSurge:Play()
        else
            toast.summary:SetText(toast.pendingSummaryText or toast.summary:GetText() or "")
            toast.summary:SetAlpha(0)
            toast.summary:Show()
            toast.summaryFadeIn:Play()
        end
    end)
    toast.summaryFadeIn = toast.summary:CreateAnimationGroup()
    local summaryIn = toast.summaryFadeIn:CreateAnimation("Alpha")
    summaryIn:SetOrder(1); summaryIn:SetFromAlpha(0); summaryIn:SetToAlpha(1); summaryIn:SetDuration(.18)
    toast.summaryFadeIn:SetScript("OnFinished", function()
        toast.summary:SetAlpha(1)
        if toast.summarySwapMode == "record" and toast.recordSweep then toast.recordSweep:Play(.06, .72) end
    end)

    toast.newRecordText = toast.summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    toast.newRecordText:SetAllPoints()
    toast.newRecordText:SetJustifyH("CENTER")
    do
        local nrPath, _, nrFlags = toast.newRecordText:GetFont()
        if nrPath then toast.newRecordText:SetFont(nrPath, 13, nrFlags or "") end
    end
    toast.newRecordText:SetTextColor(1, .82, .26, 1)
    toast.newRecordText:SetText("*** NEW RECORD ***")
    toast.newRecordText:Hide()
    toast.newRecordSurge = toast.newRecordText:CreateAnimationGroup()
    local nrAlphaIn = toast.newRecordSurge:CreateAnimation("Alpha")
    nrAlphaIn:SetOrder(1); nrAlphaIn:SetFromAlpha(0); nrAlphaIn:SetToAlpha(1); nrAlphaIn:SetDuration(.20); nrAlphaIn:SetSmoothing("OUT")
    toast.newRecordSurge:SetScript("OnFinished", function()
        toast.newRecordText:SetScale(1)
        toast.newRecordText:SetAlpha(1)
    end)
    toast.newRecordSweepFrame = CreateFrame("Frame", nil, toast.summaryFrame)
    toast.newRecordSweepFrame:SetPoint("CENTER", toast.newRecordText, "CENTER", 0, 0)
    toast.newRecordSweepFrame:SetSize(132, 18)

    toast.newRecordFadeOut = toast.newRecordText:CreateAnimationGroup()
    local nrOut = toast.newRecordFadeOut:CreateAnimation("Alpha")
    nrOut:SetOrder(1); nrOut:SetFromAlpha(1); nrOut:SetToAlpha(0); nrOut:SetDuration(.18)
    toast.newRecordFadeOut:SetScript("OnFinished", function()
        toast.newRecordText:Hide()
        toast.newRecordText:SetAlpha(1)
        toast.summarySwapMode = "record"
        toast:SetSummaryFontSize(18)
        toast.summary:SetText(toast.pendingRecordText or "")
        toast.summary:SetAlpha(0)
        toast.summary:Show()
        if toast.summarySweepFrame and toast.summary.GetStringWidth then
            local sweepWidth = math.max(8, math.floor((toast.summary:GetStringWidth() or 8) + 2))
            toast.summarySweepFrame:SetSize(sweepWidth, 18)
            toast.summarySweepFrame:ClearAllPoints()
            toast.summarySweepFrame:SetPoint("CENTER", toast.summaryFrame, "CENTER", 0, 0)
        end
        toast.summaryFadeIn:Play()
    end)

    toast.summarySweepFrame = CreateFrame("Frame", nil, toast.summaryFrame)
    toast.summarySweepFrame:SetFrameLevel((toast.summaryFrame:GetFrameLevel() or 1) + 1)
    toast.summarySweepFrame:SetPoint("CENTER")
    toast.summarySweepFrame:SetSize(40, 12)

    toast.rule = toast:CreateTexture(nil, "ARTWORK")
    toast.rule:SetPoint("TOPLEFT", 18, -80)
    toast.rule:SetPoint("TOPRIGHT", -18, -80)
    toast.rule:SetHeight(1)
    toast.rule:SetColorTexture(.84, .56, .31, .24)

    toast.nameContainer = CreateFrame("Frame", nil, toast)
    toast.nameContainer:SetPoint("TOPLEFT", 18, -83)
    toast.nameContainer:SetPoint("TOPRIGHT", -18, -83)
    toast.nameContainer:SetHeight(20)
    toast.nameButtons = {}
    for i = 1, 4 do
        local button = CreateFrame("Button", nil, toast.nameContainer)
        button:SetHeight(18)
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        button.text:SetPoint("CENTER")
        button.text:SetJustifyH("CENTER")
        button:SetScript("OnEnter", function(self)
            ShowToastOpponentTooltip(self)
        end)
        button:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        button:Hide()
        toast.nameButtons[i] = button
    end

    toast.footer = toast:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    toast.footer:SetPoint("BOTTOM", 0, 7)
    toast.footer:SetTextColor(.40, .41, .44, .74)
    toast.footer:SetText("WORLD PVP")
    local footerPath, _, footerFlags = toast.footer:GetFont()
    if footerPath then toast.footer:SetFont(footerPath, 7, footerFlags) end

    -- One sweep only, across the complete plaque.
    toast.fullSweep = DP.Theme.LightSweep(toast, toast, {1, .82, .42}, true)
    toast.bannerSweep = DP.Theme.LightSweep(toast.banner, toast.banner, {1, .88, .52}, true)
    toast.recordSweep = DP.Theme.LightSweep(toast.summarySweepFrame, toast.summarySweepFrame, {1, .84, .30}, false)
    toast.recordSweep.minBandWidth = 10
    toast.recordSweep.bandWidthFactor = .75
    toast.newRecordSweep = DP.Theme.LightSweep(toast.newRecordSweepFrame, toast.newRecordSweepFrame, {1, .88, .34}, false)
    toast.newRecordSweep.minBandWidth = 14
    toast.newRecordSweep.bandWidthFactor = .34

    -- Achievement-style trim glints. Their exact positions are randomized per reveal
    -- from a set of trim-friendly anchor points so the plaque feels less scripted.
    toast.sparkleCandidates = {
        {"TOPLEFT", 20, -9}, {"TOPLEFT", 58, -10}, {"TOP", -78, -12}, {"TOP", -28, -11},
        {"TOP", 30, -11}, {"TOP", 82, -12}, {"TOPRIGHT", -22, -10}, {"LEFT", 16, 8},
        {"LEFT", 18, -20}, {"RIGHT", -20, 7}, {"RIGHT", -18, -19}, {"BOTTOMLEFT", 20, 8},
        {"BOTTOM", -82, 9}, {"BOTTOM", -28, 10}, {"BOTTOM", 30, 10}, {"BOTTOM", 84, 9},
        {"BOTTOMRIGHT", -20, 8},
    }
    toast.sparkles = {}
    for i = 1, 6 do
        local star = toast:CreateTexture(nil, "OVERLAY")
        star:SetTexture("Interface\\Cooldown\\star4")
        star:SetBlendMode("ADD")
        star:SetSize(11, 11)
        star:SetVertexColor(1, .88, .48, 1)
        star:SetAlpha(0)
        star.anim = star:CreateAnimationGroup()
        local fadeIn = star.anim:CreateAnimation("Alpha")
        fadeIn:SetOrder(1); fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1); fadeIn:SetDuration(.10)
        local grow = star.anim:CreateAnimation("Scale")
        grow:SetOrder(1); grow:SetScale(1.35, 1.35); grow:SetOrigin("CENTER", 0, 0); grow:SetDuration(.22); grow:SetSmoothing("OUT")
        local fadeOut = star.anim:CreateAnimation("Alpha")
        fadeOut:SetOrder(2); fadeOut:SetFromAlpha(.95); fadeOut:SetToAlpha(0); fadeOut:SetDuration(.34)
        toast.sparkles[i] = star
    end

    toast.intro = toast:CreateAnimationGroup()
    local inAlpha = toast.intro:CreateAnimation("Alpha")
    inAlpha:SetOrder(1); inAlpha:SetFromAlpha(0); inAlpha:SetToAlpha(1); inAlpha:SetDuration(.20)
    inAlpha:SetSmoothing("OUT")
    toast.intro:SetScript("OnFinished", function() toast:SetAlpha(1) end)

    toast.outro = toast:CreateAnimationGroup()
    local outAlpha = toast.outro:CreateAnimation("Alpha")
    outAlpha:SetOrder(1); outAlpha:SetFromAlpha(1); outAlpha:SetToAlpha(0); outAlpha:SetDuration(.28)
    toast.outro:SetScript("OnFinished", function()
        toast:SetAlpha(1)
        toast:Hide()
    end)

    toast.titleCountFlash = toast.titleCount:CreateAnimationGroup()
    local countAlpha = toast.titleCountFlash:CreateAnimation("Alpha")
    countAlpha:SetOrder(1); countAlpha:SetFromAlpha(.58); countAlpha:SetToAlpha(1); countAlpha:SetDuration(.22)
    countAlpha:SetSmoothing("OUT")
    toast.titleCountFlash:SetScript("OnFinished", function() toast.titleCount:SetAlpha(1) end)

    local function CreateCrestAnimSet(holder)
        holder.baseFade = holder.base:CreateAnimationGroup()
        local baseOut = holder.baseFade:CreateAnimation("Alpha")
        baseOut:SetFromAlpha(1); baseOut:SetToAlpha(0); baseOut:SetDuration(.18); baseOut:SetSmoothing("OUT")
        holder.baseFade:SetScript("OnFinished", function() holder.base:SetAlpha(0) end)

        holder.hoverFade = holder.hover:CreateAnimationGroup()
        local hoverIn = holder.hoverFade:CreateAnimation("Alpha")
        hoverIn:SetOrder(1); hoverIn:SetFromAlpha(0); hoverIn:SetToAlpha(1); hoverIn:SetDuration(.16); hoverIn:SetSmoothing("OUT")
        local hoverOut = holder.hoverFade:CreateAnimation("Alpha")
        hoverOut:SetOrder(2); hoverOut:SetFromAlpha(1); hoverOut:SetToAlpha(0); hoverOut:SetDuration(.18); hoverOut:SetSmoothing("IN")
        holder.hoverFade:SetScript("OnFinished", function() holder.hover:SetAlpha(0) end)

        holder.selectedFade = holder.selected:CreateAnimationGroup()
        local selectedIn = holder.selectedFade:CreateAnimation("Alpha")
        selectedIn:SetFromAlpha(0); selectedIn:SetToAlpha(1); selectedIn:SetDuration(.20); selectedIn:SetSmoothing("OUT")
        holder.selectedFade:SetScript("OnFinished", function() holder.selected:SetAlpha(1) end)

        holder.flashAnim = holder.flash:CreateAnimationGroup()
        local flashIn = holder.flashAnim:CreateAnimation("Alpha")
        flashIn:SetOrder(1); flashIn:SetFromAlpha(0); flashIn:SetToAlpha(.42); flashIn:SetDuration(.07)
        local flashScale = holder.flashAnim:CreateAnimation("Scale")
        flashScale:SetOrder(1); flashScale:SetScale(1.02, 1.02); flashScale:SetOrigin("CENTER", 0, 0); flashScale:SetDuration(.12); flashScale:SetSmoothing("OUT")
        local flashOut = holder.flashAnim:CreateAnimation("Alpha")
        flashOut:SetOrder(2); flashOut:SetFromAlpha(.42); flashOut:SetToAlpha(0); flashOut:SetDuration(.18)
        holder.flashAnim:SetScript("OnFinished", function() holder.flash:SetAlpha(0) end)
    end
    for _, holder in ipairs(toast.crestHolders or {}) do CreateCrestAnimSet(holder) end

    -- Large red X: hidden normally, translucent while the toast is hovered,
    -- solid when the X itself is hovered.
    toast.close = CreateFrame("Button", nil, toast, "UIPanelCloseButton")
    toast.close:SetSize(27, 27)
    toast.close:SetPoint("TOPRIGHT", -4, -3)
    toast.close:SetAlpha(0)
    toast.close:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
    toast.close:SetScript("OnLeave", function(self)
        self:SetAlpha((MouseIsOver and MouseIsOver(toast)) and .38 or 0)
    end)
    toast.close:SetScript("OnClick", function()
        W.toastGeneration = (W.toastGeneration or 0) + 1
        toast.dismissAt = nil
        if toast.fullSweep then toast.fullSweep:Stop() end
        if toast.bannerSweep then toast.bannerSweep:Stop() end
        if toast.newRecordSweep then toast.newRecordSweep:Stop() end
        for _, star in ipairs(toast.sparkles or {}) do if star.anim and star.anim:IsPlaying() then star.anim:Stop() end end
        for _, holder in ipairs(toast.crestHolders or {}) do if holder.shineAnim and holder.shineAnim:IsPlaying() then holder.shineAnim:Stop() end end
        if GameTooltip then GameTooltip:Hide() end
        toast:Hide()
    end)

    toast:SetScript("OnEnter", function(self)
        if self.outro and self.outro:IsPlaying() then
            self.outro:Stop()
            self:SetAlpha(1)
        end
        if self.close then self.close:SetAlpha(.38) end
    end)
    toast:SetScript("OnLeave", function(self)
        if self.close and not (MouseIsOver and MouseIsOver(self.close)) then self.close:SetAlpha(0) end
    end)

    -- Dismissal is checked here instead of via one-shot timers. Hovering the
    -- plaque therefore pauses it for as long as the cursor remains over it.
    toast.elapsed = 0
    toast:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < .08 then return end
        self.elapsed = 0
        if not self.dismissAt or not self:IsShown() then return end
        local hovered = MouseIsOver and MouseIsOver(self)
        if hovered then
            if self.close and not (MouseIsOver and MouseIsOver(self.close)) then self.close:SetAlpha(.38) end
            return
        end
        if self.close then self.close:SetAlpha(0) end
        if GetTime and GetTime() >= self.dismissAt then
            self.dismissAt = nil
            if self.outro and not self.outro:IsPlaying() then self.outro:Play() end
        end
    end)

    toast:Hide()
    W.resultToast = toast
    return toast
end

function W.ShouldShowResultToast(record)
    if not record then return false end
    if (record.friendlyCount or 1) ~= 1 or (record.enemyCount or 0) < 2 then return false end
    if record.resultKey == "outnumbered_victory" then return true end
    if record.resultKey == "outnumbered_escape" and not record.playerDied and (record.enemyDeaths or 0) > 0 then return true end
    return false
end

function W.DevPreview1vNToast()
    local record = {
        friendlyCount = 1,
        enemyCount = 3,
        contestingEnemyCount = 3,
        peakContestingEnemies = 3,
        enemyDeaths = 3,
        playerDied = false,
        resultKey = "outnumbered_victory",
        resultLabel = "1v3 VICTORY",
        enemies = {
            {name = "Frostmage", class = "MAGE", level = 60, died = true, killingBlow = true, spec = {label = "Frost"}},
            {name = "Backstabber", class = "ROGUE", level = 60, died = true, killingBlow = true, spec = {label = "Subtlety"}},
            {name = "Shadowpriest", class = "PRIEST", level = 60, died = true, killingBlow = true, spec = {label = "Shadow"}},
        },
    }
    if GameTooltip then GameTooltip:Hide() end
    W.ShowResultToast(record)
end

function W.ShowResultToast(record)
    if not W.ShouldShowResultToast(record) or not UIParent then return end
    local toast = EnsureResultToast()
    W.toastGeneration = (W.toastGeneration or 0) + 1
    local generation = W.toastGeneration

    if GameTooltip then GameTooltip:Hide() end
    if toast.outro:IsPlaying() then toast.outro:Stop() end
    if toast.intro:IsPlaying() then toast.intro:Stop() end
    if toast.fullSweep then toast.fullSweep:Stop() end
    if toast.titleCountFlash and toast.titleCountFlash:IsPlaying() then toast.titleCountFlash:Stop() end
    if toast.summaryFadeOut and toast.summaryFadeOut:IsPlaying() then toast.summaryFadeOut:Stop() end
    if toast.summaryFadeIn and toast.summaryFadeIn:IsPlaying() then toast.summaryFadeIn:Stop() end
    if toast.newRecordSurge and toast.newRecordSurge:IsPlaying() then toast.newRecordSurge:Stop() end
    if toast.newRecordFadeOut and toast.newRecordFadeOut:IsPlaying() then toast.newRecordFadeOut:Stop() end
    if toast.recordSweep then toast.recordSweep:Stop() end
    if toast.newRecordSweep then toast.newRecordSweep:Stop() end
    if toast.newRecordText then toast.newRecordText:Hide(); toast.newRecordText:SetScale(1); toast.newRecordText:SetAlpha(1) end
    for _, letter in ipairs(toast.victoryLetters or {}) do
        if letter.anim and letter.anim:IsPlaying() then letter.anim:Stop() end
        if letter.glowAnim and letter.glowAnim:IsPlaying() then letter.glowAnim:Stop() end
        letter:SetAlpha(0)
        if letter.glow then letter.glow:SetAlpha(0) end
    end
    for _, holder in ipairs(toast.crestHolders or {}) do
        for _, group in ipairs({holder.baseFade, holder.hoverFade, holder.selectedFade, holder.flashAnim}) do
            if group and group:IsPlaying() then group:Stop() end
        end
    end
    for _, star in ipairs(toast.sparkles or {}) do
        if star.anim and star.anim:IsPlaying() then star.anim:Stop() end
        star:SetAlpha(0)
    end

    local faction = UnitFactionGroup and UnitFactionGroup("player") or "Horde"
    local baseAtlas, hoverAtlas, selectedAtlas
    if faction == "Alliance" then
        baseAtlas = "glues-CharacterSelect-icon-faction-alliance"
        hoverAtlas = "glues-CharacterSelect-icon-faction-alliance-hover"
        selectedAtlas = "glues-CharacterSelect-icon-faction-alliance-selected"
    else
        baseAtlas = "glues-CharacterSelect-icon-faction-horde"
        hoverAtlas = "glues-CharacterSelect-icon-faction-horde-hover"
        selectedAtlas = "glues-CharacterSelect-icon-faction-horde-selected"
    end
    for _, holder in ipairs(toast.crestHolders or {}) do
        if holder.base.SetAtlas then
            holder.base:SetAtlas(baseAtlas, false)
            holder.hover:SetAtlas(hoverAtlas, false)
            holder.selected:SetAtlas(selectedAtlas, false)
            holder.flash:SetAtlas(selectedAtlas, false)
        else
            for _, tex in ipairs({holder.base, holder.hover, holder.selected, holder.flash}) do
                tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
                tex:SetTexCoord(0, .25, 0, .25)
            end
        end
        holder.base:SetAlpha(1)
        holder.hover:SetAlpha(0)
        holder.selected:SetAlpha(0)
        holder.flash:SetAlpha(0)
    end

    local function PreviousBestOutnumbered(skipId)
        local best = 0
        for _, prior in ipairs(W.GetEncounters()) do
            if prior ~= record and prior.id ~= skipId and prior.resultKey == "outnumbered_victory" then
                best = math.max(best, prior.completedSoloSweep or prior.peakContestingEnemies or prior.enemyCount or 0)
            end
        end
        return best
    end

    local function QueueNewRecord(delay)
        if not (C_Timer and C_Timer.After) then return end
        C_Timer.After(delay, function()
            if W.toastGeneration ~= generation or not toast:IsShown() then return end
            toast.summarySwapMode = "newrecord"
            if toast.summaryFadeOut and toast.summaryFadeOut:IsPlaying() then toast.summaryFadeOut:Stop() end
            if toast.summaryFadeIn and toast.summaryFadeIn:IsPlaying() then toast.summaryFadeIn:Stop() end
            if toast.newRecordSurge and toast.newRecordSurge:IsPlaying() then toast.newRecordSurge:Stop() end
            if toast.newRecordFadeOut and toast.newRecordFadeOut:IsPlaying() then toast.newRecordFadeOut:Stop() end
            toast.newRecordText:Hide()
            toast.newRecordText:SetAlpha(1)
            toast.newRecordText:SetScale(1)
            toast.summary:Show()
            toast.summaryFadeOut:Play()
        end)
    end

    local function QueueRecordResult(text, delay)
        if not (C_Timer and C_Timer.After) then return end
        C_Timer.After(delay, function()
            if W.toastGeneration ~= generation or not toast:IsShown() then return end
            toast.pendingRecordText = text
            if toast.newRecordFadeOut and toast.newRecordFadeOut:IsPlaying() then toast.newRecordFadeOut:Stop() end
            toast.newRecordFadeOut:Play()
        end)
    end

    local function ScheduleCrestShine(holder)
        if not holder or not holder.shineAnim or not (C_Timer and C_Timer.After) then return end
        local delay = 1.15 + ((math and math.random and math.random()) or 0) * 2.15
        C_Timer.After(delay, function()
            if W.toastGeneration ~= generation or not toast:IsShown() then return end
            if holder.shineAnim:IsPlaying() then holder.shineAnim:Stop() end
            holder.shineAnim:Play()
            ScheduleCrestShine(holder)
        end)
    end

    local enemyCount = math.max(record.completedSoloSweep or record.peakContestingEnemies or record.contestingEnemyCount or record.enemyCount or 2, 2)
    local kills = record.enemyDeaths or 0
    local survival = record.playerDied and "Died" or "Survived"
    local survivalColor = record.playerDied and "|cffff8888" or "|cff65e6ad"
    local resultWord = record.resultKey == "outnumbered_escape" and "ESCAPE" or "VICTORY"
    toast.titleCount:SetText(string.format("1v%d", enemyCount))
    toast.titleCount:SetAlpha(.74)
    for i, letter in ipairs(toast.victoryLetters or {}) do
        local ch = resultWord:sub(i, i)
        letter:SetText(ch)
        letter:SetAlpha(0)
        letter:SetShown(ch ~= "")
        if letter.glow then
            letter.glow:SetText(ch)
            letter.glow:SetAlpha(0)
            letter.glow:SetShown(ch ~= "")
        end
    end
    -- Center the combined "1vN VICTORY" treatment over the banner.
    local countWidth = math.max(36, toast.titleCount:GetStringWidth() or 36)
    local wordWidth = 0
    local letterWidths = {}
    local kernPairs = {VI = -2, IC = -1, CT = -2, TO = -1, OR = -1, RY = -1, ES = -1, SC = -1, CA = -1, AP = -1, PE = -1}
    local prevChar, firstShown = nil, true
    for i, letter in ipairs(toast.victoryLetters or {}) do
        if letter:IsShown() then
            local ch = resultWord:sub(i, i)
            local w = math.max(7, letter:GetStringWidth() or 7)
            letterWidths[i] = w
            if not firstShown then wordWidth = wordWidth + (kernPairs[(prevChar or "") .. ch] or -1) end
            wordWidth = wordWidth + w
            prevChar = ch
            firstShown = false
        end
    end
    local totalTitleWidth = countWidth + 6 + wordWidth

    -- Fit the title plaque to the actual title width while keeping it crisp.
    local plateWidth = math.max(182, math.min(252, totalTitleWidth + 56))
    local plateHeight = 28
    toast.banner:SetSize(plateWidth, plateHeight)
    if toast.bannerBG.SetAtlas then toast.bannerBG:SetAtlas("challenges-timerbg", false) end
    toast.bannerBG:SetAllPoints()

    local startX = -totalTitleWidth / 2
    toast.titleCount:ClearAllPoints()
    toast.titleCount:SetPoint("LEFT", toast.banner, "CENTER", startX, -1)
    local x = startX + countWidth + 6
    prevChar, firstShown = nil, true
    for i, letter in ipairs(toast.victoryLetters or {}) do
        letter:ClearAllPoints()
        if letter:IsShown() then
            local ch = resultWord:sub(i, i)
            if not firstShown then x = x + (kernPairs[(prevChar or "") .. ch] or -1) end
            letter:SetPoint("LEFT", toast.banner, "CENTER", x, -1)
            if letter.glow then
                letter.glow:ClearAllPoints()
                letter.glow:SetPoint("CENTER", letter, "CENTER", 0, 0)
            end
            x = x + (letterWidths[i] or 7)
            prevChar = ch
            firstShown = false
        end
    end
    local defaultSummary = string.format("|cffffffff%d %s|r   —   %s%s|r", kills, kills == 1 and "kill" or "kills", survivalColor, survival)
    toast:SetSummaryFontSize(15)
    toast.summary:SetText(defaultSummary)
    toast.summary:SetAlpha(1)
    toast.summary:Show()
    toast.pendingSummaryText = nil
    toast.pendingRecordText = nil
    toast.summarySwapMode = nil
    local previousBest = PreviousBestOutnumbered(record.id)
    local showNewRecord = record.resultKey == "outnumbered_victory" and enemyCount > previousBest
    local recordSummary = string.format("|cffffd24aSOLO|r |cffffffff1v%d|r", enemyCount)
    toast.footer:SetText("WORLD PVP")

    local enemies = record.enemies or {}
    local matchup = W.BuildMatchups and W.BuildMatchups() or nil
    local statsByKey = {}
    for _, stats in ipairs(matchup and matchup.Opponents or {}) do statsByKey[stats.key] = stats end
    local visible = math.min(#enemies, #toast.nameButtons)
    local widths, total = {}, 0
    local gap = 3
    local available = 320
    local maxPerName = visible > 0 and math.floor((available - math.max(0, visible - 1) * gap) / visible) or 90
    for i, button in ipairs(toast.nameButtons) do
        if i <= visible then
            local enemy = enemies[i]
            button.enemy = enemy
            button.record = record
            button.stats = statsByKey[enemy.guid or enemy.name]
            button.text:SetText(DP.Theme.ClassName(ShortName(enemy.name), enemy.class))
            local natural = button.text.GetStringWidth and button.text:GetStringWidth() or 60
            local w = math.max(48, math.min(maxPerName, natural + 10))
            widths[i] = w
            total = total + w
            button:SetWidth(w)
            button.text:SetWidth(math.max(38, w - 4))
            button:Show()
        else
            button.enemy = nil
            button.record = nil
            button.stats = nil
            button:Hide()
        end
    end
    total = total + math.max(0, visible - 1) * gap
    local x = -total / 2
    for i = 1, visible do
        local button = toast.nameButtons[i]
        button:ClearAllPoints()
        button:SetPoint("CENTER", toast.nameContainer, "CENTER", x + widths[i] / 2, 0)
        x = x + widths[i] + gap
    end

    if math and math.random and toast.sparkleCandidates then
        local pool = {}
        for i, point in ipairs(toast.sparkleCandidates) do pool[i] = point end
        for _, star in ipairs(toast.sparkles or {}) do
            local pick = math.random(1, #pool)
            local pnt = table.remove(pool, pick)
            star:ClearAllPoints()
            star:SetPoint(pnt[1], toast, pnt[1], pnt[2], pnt[3])
            local size = math.random(9, 13)
            star:SetSize(size, size)
            star:SetAlpha(0)
        end
    end
    local toastHold = record.resultKey == "outnumbered_victory" and (showNewRecord and 7.0 or 6.2) or 4.8
    toast.dismissAt = (GetTime and GetTime() or 0) + toastHold
    if toast.close then toast.close:SetAlpha(0) end
    toast:SetAlpha(0)
    toast:Show()
    toast.intro:Play()

    -- Staged achievement reveal: muted crest -> hover -> selected/gold lock-in.
    -- The plaque sweep fires once at lock-in, then trim glints follow around the
    -- frame. No translation or second header sweep is used.
    if C_Timer and C_Timer.After then
        C_Timer.After(.12, function()
            if W.toastGeneration ~= generation or not toast:IsShown() then return end
            for _, holder in ipairs(toast.crestHolders or {}) do
                if holder.baseFade then holder.baseFade:Play() end
                if holder.hoverFade then holder.hoverFade:Play() end
            end
        end)
        C_Timer.After(.36, function()
            if W.toastGeneration ~= generation or not toast:IsShown() then return end
            for _, holder in ipairs(toast.crestHolders or {}) do if holder.selectedFade then holder.selectedFade:Play() end end
        end)
        C_Timer.After(.46, function()
            if W.toastGeneration ~= generation or not toast:IsShown() then return end
            for _, holder in ipairs(toast.crestHolders or {}) do if holder.flashAnim then holder.flashAnim:Play() end end
            toast.titleCountFlash:Play()
            if toast.fullSweep then toast.fullSweep:Play(.08, .92) end
            if toast.bannerSweep then toast.bannerSweep:Play(.12, .88) end
            -- Reveal VICTORY/ESCAPE letter-by-letter immediately after the crest locks gold.
            local shownCount = 0
            for i, letter in ipairs(toast.victoryLetters or {}) do
                if letter:IsShown() and C_Timer and C_Timer.After then
                    shownCount = shownCount + 1
                    C_Timer.After((shownCount - 1) * .06, function()
                        if W.toastGeneration == generation and toast:IsShown() then
                            if letter.anim then letter.anim:Play() end
                            if letter.glowAnim then letter.glowAnim:Play() end
                        end
                    end)
                end
            end
            if shownCount > 0 then
                C_Timer.After((shownCount - 1) * .06 + .14, function()
                    if W.toastGeneration ~= generation or not toast:IsShown() then return end
                    for _, pulseLetter in ipairs(toast.victoryLetters or {}) do
                        if pulseLetter:IsShown() and pulseLetter.glowAnim then
                            pulseLetter.glowAnim:Stop()
                            pulseLetter.glowAnim:Play()
                        end
                    end
                end)
            end
            for _, holder in ipairs(toast.crestHolders or {}) do ScheduleCrestShine(holder) end
            if showNewRecord then
                QueueNewRecord(1.50)
                QueueRecordResult(recordSummary, 3.00)
            end
        end)
        for _, star in ipairs(toast.sparkles or {}) do
            local delay = .46 + (math and math.random and (math.random() * .70) or 0)
            C_Timer.After(delay, function()
                if W.toastGeneration == generation and toast:IsShown() and star.anim then star.anim:Play() end
            end)
        end
    end
end

function W.Finish(reason)
    local session = W.active
    if not session then return end
    W.active = nil
    if W.ticker then W.ticker:Cancel(); W.ticker = nil end
    if Count(session.enemies) == 0 then return end
    local record = BuildRecord(session, reason)
    -- Full solo sweeps may involve staggered pressure, but every opponent must
    -- fight back and be killed by this player on the same surviving life.
    if reason == "all-enemies-dead" and not record.playerDied and record.friendlyCount == 1 and
            record.enemyCount >= 2 and record.contestingEnemyDeaths == record.enemyCount then
        local sweep = true
        for _, enemy in ipairs(record.enemies) do if not enemy.killingBlow then sweep = false end end
        if sweep then
            record.completedSoloSweep = record.enemyCount
            record.resultLabel, record.resultKey = W.CompactEncounterLabel(record, "outnumbered_victory"), "outnumbered_victory"
        end
    end
    local store = W.observer.worldPvP
    record.id = store.nextSequence
    store.nextSequence = store.nextSequence + 1
    store.encounters[#store.encounters + 1] = record
    if DP.RecordMedal and (record.resultKey == "outnumbered_victory" or record.resultKey == "outnumbered_escape") then
        DP.RecordMedal(record.resultKey .. "_1v" .. tostring(record.completedSoloSweep or record.peakContestingEnemies or 2))
    end
    TrimEncounterStore(store)
    W.ShowResultToast(record)
    if W.callbacks and W.callbacks.saved then W.callbacks.saved(record) end
    if W.callbacks and W.callbacks.changed then W.callbacks.changed() end
end

function W.Event(event, ...)
    if W.active and event == "PLAYER_DEAD" and W.CompletedEnemyGrace(W.active, GetTime()) then
        W.Finish("all-enemies-dead")
    end
    if W.active and event == "GROUP_ROSTER_UPDATE" then W.RefreshFriendlyLevels(W.active) end
    if W.active and UnitGUID and (event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_AURA" or event == "UNIT_LEVEL") then
        local unit = (event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_AURA" or event == "UNIT_LEVEL") and (...) or event == "UPDATE_MOUSEOVER_UNIT" and "mouseover" or "target"
        local guid = unit and UnitGUID(unit)
        local friendly = guid and W.active.friendlies and W.active.friendlies[guid]
        if friendly and (not tonumber(friendly.level) or tonumber(friendly.level) <= 0) then
            -- Read the actual event token, including high-numbered nameplates.
            local level = UnitLevel and UnitLevel(unit)
            if type(level) == "number" and level > 0 then friendly.level = level end
        end
        local enemy = guid and W.active.enemies and W.active.enemies[guid]
        if enemy then
            enemy.level = enemy.level or ResolvePlayerLevel(guid)
            W.CaptureOpponentPVPRank(enemy, unit)
            W.CaptureOpponentPortrait(enemy, unit)
            ScanEnemyUnitBuffs(W.active, unit)
        else
            ScanVisibleEnemyBuffs(W.active, true)
        end
    end
    if event == "CHAT_MSG_COMBAT_HONOR_GAIN" then W.Honor((...)); return end
    if event == "PLAYER_REGEN_ENABLED" then
        if W.active then W.active.outOfCombatAt = GetTime() end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then return end
    if event == "PLAYER_ENTERING_WORLD" then if W.active then W.Finish("world-change") end; return end
    if event == "PLAYER_LOGOUT" then if W.active then W.Finish("logout") end; return end
    if event == "PLAYER_DEAD" and W.active then
        W.active.playerDied = true
        W.active.playerDiedAt = GetTime() - W.active.startedElapsed
        W.active.lastActivity = GetTime()
        return
    end
end

function W.History(duelRecords, source)
    local result = {}
    source = source or "all"
    if source == "starred" then
        for _, record in ipairs(duelRecords or {}) do if record.starred then result[#result + 1] = record end end
        for _, record in ipairs(W.GetEncounters()) do if record.starred then result[#result + 1] = record end end
    else
        if source ~= "world" then
            for _, record in ipairs(duelRecords or {}) do result[#result + 1] = record end
        end
        if source ~= "duels" then
            for _, record in ipairs(W.GetEncounters()) do result[#result + 1] = record end
        end
    end
    table.sort(result, function(a, b)
        if (a.timestamp or 0) ~= (b.timestamp or 0) then return (a.timestamp or 0) > (b.timestamp or 0) end
        return (a.id or 0) > (b.id or 0)
    end)
    return result
end

local function CommaOverviewNumber(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    local text = tostring(value)
    local chunks = {}
    while #text > 3 do
        table.insert(chunks, 1, text:sub(-3))
        text = text:sub(1, -4)
    end
    table.insert(chunks, 1, text)
    return table.concat(chunks, ",")
end

local function EnemyGoldText(copper, partial, compact)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local coin = copper % 100
    local prefix = "" -- unpriced rows are disclosed in the tooltip; never put an approximation tilde on the plaque
    local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
    local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
    local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
    if compact then
        if gold > 0 then
            local text = CommaOverviewNumber(gold) .. goldIcon
            if gold < 1000 and silver > 0 then text = text .. " " .. tostring(silver) .. silverIcon end
            return prefix .. text
        end
        if silver > 0 then return prefix .. tostring(silver) .. silverIcon .. " " .. tostring(coin) .. copperIcon end
        return prefix .. tostring(coin) .. copperIcon
    end
    local parts = {}
    if gold > 0 then parts[#parts + 1] = CommaOverviewNumber(gold) .. goldIcon end
    if gold > 0 or silver > 0 then parts[#parts + 1] = tostring(silver) .. silverIcon end
    parts[#parts + 1] = tostring(coin) .. copperIcon
    return prefix .. table.concat(parts, " ")
end

function W.Summary()
    local store = W.observer and W.observer.worldPvP or nil
    local summary = {kills = 0, deaths = 0, soloWins = 0, soloLosses = 0, outnumberedVictories = 0,
        honorableKills = 0, ganks = 0, lowbieGanks = 0, longestOutnumbered = 0, encounters = 0, rivals = 0,
        currentStreak = 0, longestStreak = 0, outnumberedBySize = {}, favoriteZone = nil, favoriteZoneKills = 0,
        mostKilledName = nil, mostKilledClass = nil, mostKilledKills = 0, mostKilledDeaths = 0,
        mostKilledSoloKills = 0, mostKilledSoloDeaths = 0, mostKilledEncounters = 0,
        nemesisName = nil, nemesisClass = nil, nemesisDeaths = 0, nemesisKills = 0,
        nemesisSoloKills = 0, nemesisSoloDeaths = 0, nemesisEncounters = 0,
        enemyGoldSpentCopper = math.max(0, tonumber(store and store.enemyGoldArchivedCopper) or 0),
        enemyGoldSpentPartial = store and store.enemyGoldArchivedPartial and true or false,
        enemyGoldPricedCount = math.max(0, tonumber(store and store.enemyGoldArchivedPricedCount) or 0),
        enemyGoldUnpricedCount = math.max(0, tonumber(store and store.enemyGoldArchivedUnpricedCount) or 0)}
    local streak, rivals, zones, rivalStats = 0, {}, {}, {}
    summary.worldBuffsRemoved,summary.worldBuffRemovalCount={},0
    for id,name in pairs(WORLD_BUFFS) do
        local existing=summary.worldBuffsRemoved[name]
        if not existing or id<existing.spellID then summary.worldBuffsRemoved[name]={name=name,spellID=id,count=0} end
    end
    summary.enemyGoldCategories = {}
    DP.SpendChart.Merge(summary.enemyGoldCategories, store and store.enemyGoldArchivedCategories)
    local archivedCategorized = 0
    for _, copper in pairs(summary.enemyGoldCategories) do archivedCategorized = archivedCategorized + copper end
    summary.enemyGoldCategories.other = (summary.enemyGoldCategories.other or 0) +
        math.max(0, summary.enemyGoldSpentCopper - archivedCategorized)
    for _, record in ipairs(DP.OverviewArchive.Records(store)) do
        if not record.overviewArchived then
            local enemyCopper, enemyPartial, enemyPriced, enemyUnpriced, categories = EnemyConsumableSpend(record)
            DP.SpendChart.Merge(summary.enemyGoldCategories, categories)
            summary.enemyGoldSpentCopper = summary.enemyGoldSpentCopper + enemyCopper
            summary.enemyGoldPricedCount = summary.enemyGoldPricedCount + enemyPriced
            summary.enemyGoldUnpricedCount = summary.enemyGoldUnpricedCount + enemyUnpriced
            if enemyPartial then summary.enemyGoldSpentPartial = true end
        end
        DP.OverviewCharts.AddBuffs(summary,record,WORLD_BUFFS)
        summary.encounters = summary.encounters + 1
        local recordKills = record.enemyDeaths or 0
        summary.kills = summary.kills + recordKills
        local zone = SummaryZoneName(record.location)
        if recordKills > 0 and zone and zone ~= "" and zone ~= "Unknown" then
            local z = zones[zone] or {name=zone,kills=0,encounters=0,points={}}
            z.kills = z.kills + recordKills
            z.encounters = z.encounters + 1
            local locations=record.killLocations or {record.location}
            for _,location in ipairs(locations) do
                if location and location.mapID and location.x and location.y then z.points[#z.points+1]=location end
            end
            zones[zone] = z
        end
        if record.playerDied then summary.deaths = summary.deaths + 1 end
        summary.honorableKills = summary.honorableKills + (record.honorableKills or 0)
        local ganks, lowbies = CountGanks(record)
        summary.ganks = summary.ganks + ganks
        summary.lowbieGanks = summary.lowbieGanks + lowbies
        for _, enemy in ipairs(record.enemies or {}) do
            local rivalKey = enemy.guid or enemy.name
            if rivalKey then
                rivals[rivalKey] = true
                local r = rivalStats[rivalKey]
                if not r then
                    r = {name = ShortName(enemy.name), class = enemy.class, kills = 0, deaths = 0,
                        soloKills = 0, soloDeaths = 0, encounters = 0, lastAt = 0}
                    rivalStats[rivalKey] = r
                end
                r.name = r.name or ShortName(enemy.name)
                r.class = r.class or enemy.class
                r.encounters = r.encounters + 1
                r.lastAt = math.max(r.lastAt or 0, record.timestamp or 0)
                if enemy.died then r.kills = r.kills + 1 end
                -- World PvP does not always expose the exact killing blow on the
                -- player. Matchup death credit therefore means the rival was an
                -- enemy participant in an encounter where you died, consistent
                -- with the existing World matchup record.
                if record.playerDied and record.resultKey~="fall_damage" then r.deaths = r.deaths + 1 end
                local soloContested = record.friendlyCount == 1 and record.enemyCount == 1 and
                    (record.pressureModelVersion ~= 1 or enemy.pressuredPlayer == true) and not GankKind(record, enemy)
                if soloContested then
                    if enemy.died then r.soloKills = r.soloKills + 1 end
                    if record.playerDied and record.resultKey ~= "fall_damage" and record.resultKey ~= "low_health_death" then r.soloDeaths = r.soloDeaths + 1 end
                end
            end
        end
        local contesting = record.contestingEnemyCount
        if contesting == nil then contesting = record.enemyCount or 0 end -- legacy records
        if record.friendlyCount == 1 and contesting == 1 then
            if record.resultKey == "victory" then summary.soloWins = summary.soloWins + 1
            elseif record.playerDied and record.resultKey ~= "fall_damage" and record.resultKey ~= "low_health_death" then summary.soloLosses = summary.soloLosses + 1 end
        end
        if record.resultKey == "outnumbered_victory" then
            summary.outnumberedVictories = summary.outnumberedVictories + 1
            local multikillSize = math.max(2, tonumber(record.completedSoloSweep or record.peakContestingEnemies or record.enemyCount) or 2)
            summary.longestOutnumbered = math.max(summary.longestOutnumbered, multikillSize)
            summary.outnumberedBySize[multikillSize] = (summary.outnumberedBySize[multikillSize] or 0) + 1
        end
        -- Streak is a kill streak, not an encounter streak. Disengaging from a
        -- fight without dying does not erase it; only a recorded player death
        -- resets it. This keeps Overview consistent with the headline kill
        -- count (e.g. 79 kills / 0 deaths => a current streak of 79).
        if recordKills > 0 then
            streak = streak + recordKills
            summary.longestStreak = math.max(summary.longestStreak, streak)
        end
        if record.playerDied then streak = 0 end
    end
    summary.currentStreak = streak
    summary.rivals = Count(rivals)
    summary.topZones=DP.OverviewCharts.RankZones(zones)
    local bestZone, best
    for zone, stats in pairs(zones) do
        if not best or stats.kills > best.kills or
            (stats.kills == best.kills and stats.encounters > best.encounters) or
            (stats.kills == best.kills and stats.encounters == best.encounters and zone < bestZone) then
            bestZone, best = zone, stats
        end
    end
    if bestZone and best then
        summary.favoriteZone = bestZone
        summary.favoriteZoneKills = best.kills
    end

    summary.topMostKilled,summary.topNemeses=DP.RivalChart.Rank(rivalStats)
    local mostKilled,nemesis=summary.topMostKilled[1],summary.topNemeses[1]
    if mostKilled then
        summary.mostKilledName, summary.mostKilledClass = mostKilled.name, mostKilled.class
        summary.mostKilledKills, summary.mostKilledDeaths = mostKilled.kills, mostKilled.deaths
        summary.mostKilledSoloKills, summary.mostKilledSoloDeaths = mostKilled.soloKills, mostKilled.soloDeaths
        summary.mostKilledEncounters = mostKilled.encounters
    end
    if nemesis then
        summary.nemesisName, summary.nemesisClass = nemesis.name, nemesis.class
        summary.nemesisDeaths, summary.nemesisKills = nemesis.deaths, nemesis.kills
        summary.nemesisSoloKills, summary.nemesisSoloDeaths = nemesis.soloKills, nemesis.soloDeaths
        summary.nemesisEncounters = nemesis.encounters
    end
    return summary
end

function W.BuildMatchups()
    local data = {Opponents = {}, Classes = {}, byOpponent = {}, byClass = {}}
    local opponents, classes = {}, {}
    for _, record in ipairs(W.GetEncounters()) do
        for _, enemy in ipairs(record.enemies or {}) do
            local key = enemy.guid or enemy.name
            local entry = opponents[key]
            if not entry then
                entry = {key = key, name = enemy.name, class = enemy.class, level = enemy.level, kills = 0, deaths = 0, soloKills = 0, soloDeaths = 0,
                    encounters = 0, lastAt = 0}
                opponents[key] = entry
            end
            entry.encounters = entry.encounters + 1
            if enemy.level and (record.timestamp or 0) >= (entry.lastAt or 0) then entry.level = enemy.level end
            if enemy.spec and enemy.spec.label and (record.timestamp or 0) >= (entry.lastAt or 0) then entry.spec = enemy.spec.label end
            entry.lastAt = math.max(entry.lastAt, record.timestamp or 0)
            if enemy.died then entry.kills = entry.kills + 1 end
            if record.playerDied and record.resultKey~="fall_damage" then entry.deaths = entry.deaths + 1 end
            local soloContested = record.friendlyCount == 1 and record.enemyCount == 1 and
                (record.pressureModelVersion ~= 1 or enemy.pressuredPlayer == true) and not GankKind(record, enemy)
            if soloContested then
                if enemy.died then entry.soloKills = entry.soloKills + 1 end
                if record.playerDied and record.resultKey ~= "fall_damage" and record.resultKey ~= "low_health_death" then entry.soloDeaths = entry.soloDeaths + 1 end
            end
            data.byOpponent[key] = data.byOpponent[key] or {}
            data.byOpponent[key][#data.byOpponent[key] + 1] = record

            local classKey = enemy.class or "UNKNOWN"
            local class = classes[classKey]
            if not class then class = {key = classKey, kills = 0, deaths = 0, encounters = 0, rivals = {}}; classes[classKey] = class end
            class.encounters = class.encounters + 1
            class.rivals[key] = true
            if enemy.died then class.kills = class.kills + 1 end
            if record.playerDied and record.resultKey~="fall_damage" then class.deaths = class.deaths + 1 end
            data.byClass[classKey] = data.byClass[classKey] or {}
            data.byClass[classKey][#data.byClass[classKey] + 1] = record
        end
    end
    for _, entry in pairs(opponents) do data.Opponents[#data.Opponents + 1] = entry end
    table.sort(data.Opponents, function(a, b) if a.lastAt ~= b.lastAt then return a.lastAt > b.lastAt end return a.name < b.name end)
    for _, class in pairs(classes) do
        class.distinct = Count(class.rivals); class.rivals = nil
        data.Classes[#data.Classes + 1] = class
    end
    table.sort(data.Classes, function(a, b) return a.key < b.key end)
    return data
end

-- Map rendering ---------------------------------------------------------------
local function EnsureTile(map, index)
    map.tiles = map.tiles or {}
    local texture = map.tiles[index]
    if not texture then
        texture = map.canvas:CreateTexture(nil, "ARTWORK")
        map.tiles[index] = texture
    end
    return texture
end

local function EnsureExplorationTile(map, index)
    map.explorationTiles = map.explorationTiles or {}
    local texture = map.explorationTiles[index]
    if not texture then
        -- Blizzard's zone map is the fogged base layer plus discovered-area
        -- overlays. Keep these above the base art but under our encounter pin.
        texture = map.canvas:CreateTexture(nil, "ARTWORK", nil, 2)
        map.explorationTiles[index] = texture
    end
    return texture
end

local function HideExplorationTiles(map, first)
    for index = first or 1, #(map.explorationTiles or {}) do
        map.explorationTiles[index]:Hide()
    end
end

function W.CreateMapThumbnail(parent, width, height)
    -- A ScrollFrame gives us reliable hard clipping for the aspect-preserving
    -- encounter crop. The map art itself can be larger than the visible card,
    -- but nothing is allowed to bleed past the thumbnail border.
    local map = CreateFrame("ScrollFrame", nil, parent)
    map:SetSize(width, height)
    map.bg = map:CreateTexture(nil, "BACKGROUND"); map.bg:SetAllPoints(); map.bg:SetColorTexture(.02, .025, .032, 1)
    map.canvas = CreateFrame("Frame", nil, map); map.canvas:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0); map.canvas:SetSize(width, height)
    map:SetScrollChild(map.canvas)

    -- Keep the kill marker in a fixed child frame of the ScrollFrame, but NOT in
    -- the scroll child. That makes it viewport-relative and guarantees it stays
    -- above both base-map and exploration textures while the canvas pans below.
    map.markerFrame = CreateFrame("Frame", nil, map)
    map.markerFrame:SetAllPoints(map)
    map.markerFrame:SetFrameLevel(map:GetFrameLevel() + 80)
    map.markerFrame:EnableMouse(false)
    if map.markerFrame.SetClipsChildren then map.markerFrame:SetClipsChildren(true) end
    local markerSize = width <= 100 and 13 or 20
    map.markerShadow = map.markerFrame:CreateTexture(nil, "ARTWORK", nil, 7); map.markerShadow:SetSize(markerSize, markerSize)
    map.marker = map.markerFrame:CreateTexture(nil, "OVERLAY", nil, 7); map.marker:SetSize(markerSize, markerSize)
    local function SetMarker(texture, icon)
        -- Set the sheet explicitly before calling Blizzard's helper. Some Classic
        -- clients only apply texcoords in the helper, which left our prior marker
        -- with no visible texture even though its geometry was correct.
        texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        if SetRaidTargetIconTexture then SetRaidTargetIconTexture(texture, icon or 7)
        elseif (icon or 7) == 8 then texture:SetTexCoord(.75, 1, .5, 1)
        else texture:SetTexCoord(.5, .75, .5, 1) end
        texture:SetAlpha(1)
        texture:SetBlendMode("BLEND")
    end
    map.SetMarkerIcon = function(_, icon)
        SetMarker(map.markerShadow, icon); map.markerShadow:SetVertexColor(0, 0, 0, .95)
        SetMarker(map.marker, icon)
        if icon == 8 then map.marker:SetVertexColor(.96, .93, .88, 1)
        else map.marker:SetVertexColor(1, 1, 1, 1) end
    end
    map:SetMarkerIcon(7)
    map.label = map:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); map.label:SetPoint("CENTER"); map.label:SetWidth(width - 8); map.label:SetJustifyH("CENTER")
    map:SetScript("OnShow", function() if map.markerFrame then map.markerFrame:Show() end end)
    map:SetScript("OnHide", function() map.record = nil; if map.markerFrame then map.markerFrame:Hide() end end)
    return map
end

function W.SetMapRecord(map, record)
    map.record = record
    local location = record and record.location
    local mapID = location and location.mapID
    if not mapID or not C_Map or not C_Map.GetMapArtLayers or not C_Map.GetMapArtLayerTextures then
        for _, tile in ipairs(map.tiles or {}) do tile:Hide() end
        HideExplorationTiles(map)
        if map.SetHorizontalScroll then map:SetHorizontalScroll(0) end
        if map.SetVerticalScroll then map:SetVerticalScroll(0) end
        map.marker:Hide(); map.markerShadow:Hide(); map.label:SetText(location and location.zone or "Location unavailable"); map.label:Show(); return
    end
    local layers = C_Map.GetMapArtLayers(mapID)
    local layer = layers and layers[1]
    local textures = layer and C_Map.GetMapArtLayerTextures(mapID, 1)
    if not layer or not textures or #textures == 0 then
        for _, tile in ipairs(map.tiles or {}) do tile:Hide() end
        HideExplorationTiles(map)
        if map.SetHorizontalScroll then map:SetHorizontalScroll(0) end
        if map.SetVerticalScroll then map:SetVerticalScroll(0) end
        map.marker:Hide(); map.markerShadow:Hide(); map.label:SetText(location.zone or "Map unavailable"); map.label:Show(); return
    end
    map.label:Hide()
    if map.SetMarkerIcon then map:SetMarkerIcon(record and record.playerDied and 8 or 7) end
    local width, height = map:GetWidth(), map:GetHeight()
    -- Treat this as a location snapshot, not a miniature full-zone atlas. Fill
    -- the card without distortion/letterboxing, preserve the Blizzard map art's
    -- aspect ratio, and pan the crop toward the recorded fight location.
    -- Fixed local zoom: every History card and Details map shows roughly the
    -- same fraction of its zone around the encounter instead of a miniature
    -- full-zone atlas. 3.25x keeps the location legible while retaining enough
    -- roads/terrain to recognize the spot.
    local scale = math.max(width / layer.layerWidth, height / layer.layerHeight) * 3.25
    local canvasW, canvasH = layer.layerWidth * scale, layer.layerHeight * scale
    map.canvas:SetSize(canvasW, canvasH)
    local columns = math.ceil(layer.layerWidth / layer.tileWidth)
    local rows = math.ceil(layer.layerHeight / layer.tileHeight)
    local used = 0
    for row = 1, rows do
        for column = 1, columns do
            used = used + 1
            local fileID = textures[used]
            local tile = EnsureTile(map, used)
            if fileID then
                local x = (column - 1) * layer.tileWidth
                local y = (row - 1) * layer.tileHeight
                local remainingW = math.min(layer.tileWidth, layer.layerWidth - x)
                local remainingH = math.min(layer.tileHeight, layer.layerHeight - y)
                tile:SetTexture(fileID)
                tile:ClearAllPoints(); tile:SetPoint("TOPLEFT", map.canvas, "TOPLEFT", x * scale, -y * scale)
                tile:SetSize(remainingW * scale, remainingH * scale)
                tile:SetTexCoord(0, remainingW / layer.tileWidth, 0, remainingH / layer.tileHeight)
                tile:Show()
            else tile:Hide() end
        end
    end
    for index = used + 1, #(map.tiles or {}) do map.tiles[index]:Hide() end

    -- GetMapArtLayerTextures() is intentionally only the underlying/fogged
    -- zone art. The stock World Map reveals discovered subzones by painting
    -- C_MapExplorationInfo overlays on top. Reproduce Blizzard's exploration
    -- tiling rules here instead of assuming every overlay file is a 256x256
    -- image. Classic exploration edge tiles are frequently stored in smaller
    -- power-of-two files; using the logical tile size as their file size makes
    -- those edge pieces stretch into large rectangular chunks of the wrong
    -- terrain (the broken "map capture" look seen around Booty Bay).
    local overlayUsed = 0
    local getExplored = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
    local explored = getExplored and getExplored(mapID) or nil
    local overlayTileW = tonumber(layer.tileWidth) or 256
    local overlayTileH = tonumber(layer.tileHeight) or 256

    local function EdgeFileSize(pixelSize)
        local fileSize = 16
        while fileSize < pixelSize do fileSize = fileSize * 2 end
        return fileSize
    end

    for _, overlay in ipairs(explored or {}) do
        -- Blizzard marks a few exploration regions as mouse-over-only. Rivals'
        -- encounter map is a static snapshot, so drawing those permanently would
        -- show art the stock map itself keeps hidden until hovered.
        if not overlay.isShownByMouseOver then
            local overlayWidth = tonumber(overlay.textureWidth) or 0
            local overlayHeight = tonumber(overlay.textureHeight) or 0
            local offsetX = tonumber(overlay.offsetX) or 0
            local offsetY = tonumber(overlay.offsetY) or 0
            local fileIDs = overlay.fileDataIDs or {}
            if overlayWidth > 0 and overlayHeight > 0 and #fileIDs > 0 then
                local overlayColumns = math.ceil(overlayWidth / overlayTileW)
                local overlayRows = math.ceil(overlayHeight / overlayTileH)
                for overlayRow = 1, overlayRows do
                    local pixelH = overlayRow < overlayRows and overlayTileH or (overlayHeight % overlayTileH)
                    if pixelH == 0 then pixelH = overlayTileH end
                    local fileH = overlayRow < overlayRows and overlayTileH or EdgeFileSize(pixelH)

                    for overlayColumn = 1, overlayColumns do
                        local fileIndex = ((overlayRow - 1) * overlayColumns) + overlayColumn
                        local fileID = fileIDs[fileIndex]
                        if fileID then
                            local pixelW = overlayColumn < overlayColumns and overlayTileW or (overlayWidth % overlayTileW)
                            if pixelW == 0 then pixelW = overlayTileW end
                            local fileW = overlayColumn < overlayColumns and overlayTileW or EdgeFileSize(pixelW)

                            overlayUsed = overlayUsed + 1
                            local tile = EnsureExplorationTile(map, overlayUsed)
                            local localX = (overlayColumn - 1) * overlayTileW
                            local localY = (overlayRow - 1) * overlayTileH
                            tile:SetTexture(fileID)
                            tile:SetDrawLayer("ARTWORK", overlay.isDrawOnTopLayer and 3 or 2)
                            tile:ClearAllPoints()
                            tile:SetPoint("TOPLEFT", map.canvas, "TOPLEFT", (offsetX + localX) * scale, -(offsetY + localY) * scale)
                            tile:SetSize(pixelW * scale, pixelH * scale)
                            tile:SetTexCoord(0, pixelW / fileW, 0, pixelH / fileH)
                            tile:Show()
                        end
                    end
                end
            end
        end
    end
    HideExplorationTiles(map, overlayUsed + 1)

    local cropX, cropY = 0, 0
    if location.x and location.y then
        local markerX, markerY = location.x * canvasW, location.y * canvasH
        cropX = math.max(0, math.min(math.max(0, canvasW - width), markerX - width * .5))
        cropY = math.max(0, math.min(math.max(0, canvasH - height), markerY - height * .5))
        -- The marker is viewport-relative after scrolling: recorded map point
        -- minus the crop origin. This keeps the red raid X above every map layer.
        local half = (map.marker and map.marker.GetWidth and map.marker:GetWidth() or 18) * .5
        local vx = math.max(half, math.min(width - half, markerX - cropX))
        local vy = math.max(half, math.min(height - half, markerY - cropY))
        map.marker:ClearAllPoints(); map.markerShadow:ClearAllPoints()
        map.marker:SetPoint("CENTER", map.markerFrame, "TOPLEFT", vx, -vy)
        map.markerShadow:SetPoint("CENTER", map.markerFrame, "TOPLEFT", vx + 1.5, -(vy + 1.5))
        map.markerShadow:Show(); map.marker:Show()
    else
        -- No exact position: center the art crop instead of favoring an edge.
        cropX = math.max(0, (canvasW - width) * .5)
        cropY = math.max(0, (canvasH - height) * .5)
        map.marker:Hide(); map.markerShadow:Hide()
    end
    if map.SetHorizontalScroll then map:SetHorizontalScroll(cropX) end
    if map.SetVerticalScroll then map:SetVerticalScroll(cropY) end
end

-- Overview -------------------------------------------------------------------
local OVERVIEW_SWIPE_TIME = .22
local OVERVIEW_DESIGN_WIDTH = 352

local function PositionOverviewPage(page, canvas, offset)
    if not page or not canvas then return end
    local x = (offset or 0) + ((canvas:GetWidth() or OVERVIEW_DESIGN_WIDTH) - OVERVIEW_DESIGN_WIDTH) / 2
    page:ClearAllPoints()
    page:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, 0)
    page:SetSize(OVERVIEW_DESIGN_WIDTH, canvas:GetHeight())
end

local OVERVIEW_CLIP_LEFT = 16
local OVERVIEW_CLIP_RIGHT = 20

local function OverviewWidth()
    local host = W.overviewHost
    local width = host and host.GetWidth and host:GetWidth() or 0
    return width and width > 40 and width or 352
end

local function SyncOverviewViewport()
    local viewport, canvas, host = W.overviewViewport, W.overviewCanvas, W.overviewHost
    if not viewport or not canvas or not host then return end
    local width = host.GetWidth and host:GetWidth() or 0
    local height = host.GetHeight and host:GetHeight() or 0
    if not width or width < 40 then width = 352 end
    if not height or height < 100 then height = 430 end
    -- Inset the viewport inside the stone frame and center the fixed-width
    -- page artwork in those bounds. Use one coordinate transform: scroll-child
    -- anchoring plus a horizontal scroll previously introduced client drift.
    -- Classic's 384px frame includes transparent padding to the right of its
    -- 352px visible chrome; that padding is not usable carousel space.
    local clipWidth = math.max(1, math.min(width, OVERVIEW_DESIGN_WIDTH) - OVERVIEW_CLIP_LEFT - OVERVIEW_CLIP_RIGHT)
    viewport:ClearAllPoints()
    viewport:SetPoint("TOPLEFT", host, "TOPLEFT", OVERVIEW_CLIP_LEFT, 0)
    viewport:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", OVERVIEW_CLIP_LEFT, 0)
    viewport:SetWidth(clipWidth)
    canvas:ClearAllPoints(); canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
    canvas:SetSize(clipWidth, height)
    if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
    if viewport.SetHorizontalScroll then viewport:SetHorizontalScroll(0) end
end

local function StyleOverviewDot(button, selected)
    if not button or not button.dot then return end
    -- Never change glyph size between states: changing font metrics made the
    -- highlighted dot visibly jump off the inactive dot's baseline. Illuminate
    -- with color/glow only so both paginator dots stay on one plane.
    button.dot:SetTextColor(selected and 1.00 or .34, selected and .78 or .29,
        selected and .24 or .19, 1)
    if button.glow then
        button.glow:SetAlpha(selected and .38 or 0)
        if selected then button.glow:Show() else button.glow:Hide() end
    end
end

local function UpdateOverviewDots()
    if not W.duelDot or not W.worldDot then return end
    local duelSelected = W.overviewMode ~= "world"
    StyleOverviewDot(W.duelDot, duelSelected)
    StyleOverviewDot(W.worldDot, not duelSelected)
end

local function CreateSlabDivider(parent, x, y, h)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOP", parent, "TOPLEFT", x, y)
    tex:SetSize(16, h or 56)
    if tex.SetAtlas then
        tex:SetAtlas("BattleBar-ButtonBG-Divider", true)
    else
        tex:SetColorTexture(.38, .30, .18, .55)
        tex:SetWidth(2)
    end
    tex:SetAlpha(.72)
    return tex
end

local function FinishOverviewSwipe()
    if not W.overviewHost then return end
    W.overviewHost:SetScript("OnUpdate", nil)
    W.swipe = nil
    if W.swipeShield then W.swipeShield:Hide() end
    SyncOverviewViewport()
    local world = W.overviewMode == "world"
    local canvas = W.overviewCanvas or W.overviewHost
    -- Keep the hierarchy stable across swipes; backdrop regions must retain
    -- the same parent, clipping surface and frame levels at rest and in motion.
    PositionOverviewPage(W.duelOverviewFrame, canvas, 0)
    PositionOverviewPage(W.overviewFrame, canvas, 0)
    if W.duelOverviewFrame then W.duelOverviewFrame:SetAlpha(1); W.duelOverviewFrame:SetShown(not world) end
    if W.overviewFrame then W.overviewFrame:SetAlpha(1); W.overviewFrame:SetShown(world) end
    UpdateOverviewDots()
    if world then W.RefreshOverview() elseif DP.RefreshProgress then DP.RefreshProgress() end
end

local function CreateOverviewDot(parent, x, mode)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(10, 10)
    button:SetPoint("CENTER", parent, "CENTER", x, 0)
    button.glow = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    button.glow:SetAllPoints(button)
    button.glow:SetJustifyH("CENTER"); button.glow:SetJustifyV("MIDDLE")
    button.glow:SetText("•")
    button.glow:SetTextColor(1, .72, .18, .22)
    local glowFont, _, glowFlags = button.glow.GetFont and button.glow:GetFont()
    if glowFont and button.glow.SetFont then button.glow:SetFont(glowFont, 12, glowFlags) end
    button.dot = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.dot:SetAllPoints(button)
    button.dot:SetJustifyH("CENTER"); button.dot:SetJustifyV("MIDDLE")
    button.dot:SetText("•")
    local dotFont, _, dotFlags = button.dot.GetFont and button.dot:GetFont()
    if dotFont and button.dot.SetFont then button.dot:SetFont(dotFont, 12, dotFlags) end
    button:SetScript("OnClick", function()
        if W.swipe then return end
        -- The dots are pagination controls rather than radio buttons. Clicking
        -- the illuminated/current dot advances to the other page; clicking the
        -- unlit dot selects that page. Repeated clicks on either physical dot
        -- therefore keep cycling the carousel.
        local current = W.overviewMode == "world" and "world" or "duels"
        local target = mode
        if current == mode then target = mode == "world" and "duels" or "world" end
        W.SetOverviewMode(target)
    end)
    -- Deliberately no hover tooltip: the two-dot paginator is meant to read as
    -- a quiet page indicator, not another pair of labeled controls.
    return button
end

function W.InstallOverview(overview, duelPage)
    if W.overviewFrame or not overview or not duelPage then return end
    W.overviewHost, W.duelOverviewFrame = overview, duelPage

    -- ScrollFrame provides reliable clipping in Classic Era. SetClipsChildren
    -- alone was not sufficient for moving font strings/buttons on all clients.
    local viewport = CreateFrame("ScrollFrame", nil, overview)
    viewport:SetFrameLevel(duelPage:GetFrameLevel())
    local canvas = CreateFrame("Frame", nil, viewport)
    canvas:SetSize(352, 430)
    viewport:SetScrollChild(canvas)
    W.overviewViewport, W.overviewCanvas = viewport, canvas
    duelPage:SetParent(canvas)
    SyncOverviewViewport()

    -- World PvP is a sibling page inside the same clipped carousel canvas.
    local world = CreateFrame("Frame", nil, canvas)
    world:SetAllPoints(canvas)
    world:SetFrameLevel(duelPage:GetFrameLevel())
    world:Hide()
    W.overviewFrame = world

    -- Mirror the Duel Rating card exactly.
    for i = 0, 45 do
        local glow = math.sin((i / 45) * math.pi)
        DP.Theme.Fill(world, 28, -132 - i * 2, 296, 2,
            .035 + glow * .035, .055 + glow * .055, .09 + glow * .08)
    end
    local card = DP.Theme.Border(world, 26, -130, 300, 96)
    DP.Theme.Border(world, 29, -133, 294, 90)
    local header = DP.Theme.RatingHeader(world, card)
    header.text:SetText("World PvP")
    W.overviewHeader = header
    W.overviewSweep = DP.Theme.LightSweep(world, card, {1, .82, .42}, true)
    function W.PlayOverviewSweep()
        if W.overviewSweep and world:IsShown() then W.overviewSweep:Play(0, .40) end
    end

    local headline = world:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    headline:SetPoint("TOPLEFT", 26, -146); headline:SetWidth(300); headline:SetJustifyH("CENTER")
    W.overviewHeadline = headline
    -- With HKs/ganks moved to hover, use the lower half of the plaque for the
    -- two streak numbers that actually define the current run. The separate
    -- value/label strings create hierarchy without increasing the card height.
    local currentStreak = world:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentStreak:SetPoint("TOPLEFT", 38, -179); currentStreak:SetWidth(124); currentStreak:SetJustifyH("CENTER")
    local currentStreakLabel = world:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    currentStreakLabel:SetPoint("TOPLEFT", 38, -198); currentStreakLabel:SetWidth(124); currentStreakLabel:SetJustifyH("CENTER")
    currentStreakLabel:SetText("CURRENT STREAK")
    currentStreakLabel:SetTextColor(.58, .61, .66)
    local bestStreak = world:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bestStreak:SetPoint("TOPLEFT", 190, -179); bestStreak:SetWidth(124); bestStreak:SetJustifyH("CENTER")
    local bestStreakLabel = world:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bestStreakLabel:SetPoint("TOPLEFT", 190, -198); bestStreakLabel:SetWidth(124); bestStreakLabel:SetJustifyH("CENTER")
    bestStreakLabel:SetText("BEST STREAK")
    bestStreakLabel:SetTextColor(.58, .61, .66)
    W.overviewSubtitle = nil
    W.overviewCurrentStreak, W.overviewBestStreak = currentStreak, bestStreak
    W.overviewCurrentStreakLabel, W.overviewBestStreakLabel = currentStreakLabel, bestStreakLabel

    do
        local function CreateHeadlineFlourish(mirrored)
            local flourish = world:CreateTexture(nil, "OVERLAY")
            local shadow = world:CreateTexture(nil, "ARTWORK")
            flourish:SetVertexColor(.93, .72, .44, .98)
            shadow:SetVertexColor(0, 0, 0, .35)
            if flourish.SetAtlas then
                flourish:SetAtlas("PetJournal-PetBattleAchievementBG", true)
                shadow:SetAtlas("PetJournal-PetBattleAchievementBG", true)
                local w, h = flourish:GetWidth(), flourish:GetHeight()
                if not w or w <= 0 or not h or h <= 0 then w, h = 18, 18 end
                local scale = 13 / h
                local fw, fh = math.max(11, w * scale), 13
                flourish:SetSize(fw, fh)
                shadow:SetSize(fw, fh)
            else
                flourish:SetTexture("Interface\\Buttons\\WHITE8X8")
                shadow:SetTexture("Interface\\Buttons\\WHITE8X8")
                flourish:SetSize(13, 13)
                shadow:SetSize(13, 13)
            end
            if mirrored then
                flourish:SetTexCoord(1, 0, 0, 1)
                shadow:SetTexCoord(1, 0, 0, 1)
            end
            shadow:SetPoint("CENTER", flourish, "CENTER", 1, -1)
            flourish.shadow = shadow
            flourish:Hide()
            shadow:Hide()
            return flourish
        end
        W.overviewHeadlineFiligree = nil
        W.overviewHeadlineFlourishLeft = CreateHeadlineFlourish(false)
        W.overviewHeadlineFlourishRight = CreateHeadlineFlourish(true)
    end

    local left = DP.Theme.StatSlab(world, 26, -240, 140, 58, false)
    local right = DP.Theme.StatSlab(world, 186, -240, 140, 58, true)
    W.overviewSlabDivider = DP.Theme.StatDivider(world, 176, -269, 46)
    if W.overviewSlabDivider and W.overviewSlabDivider.SetVertexColor then
        W.overviewSlabDivider:SetVertexColor(.93, .72, .44, .96)
    end
    local soloTop = left:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    soloTop:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -8); soloTop:SetPoint("TOPRIGHT", left, "TOPRIGHT", -8, -8); soloTop:SetJustifyH("CENTER")
    local soloMid = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soloMid:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -24); soloMid:SetPoint("TOPRIGHT", left, "TOPRIGHT", -8, -24); soloMid:SetJustifyH("CENTER")
    local soloBot = left:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    soloBot:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -40); soloBot:SetPoint("TOPRIGHT", left, "TOPRIGHT", -8, -40); soloBot:SetJustifyH("CENTER"); soloBot:SetTextColor(.58, .61, .66)
    W.overviewSoloTop, W.overviewSoloMid, W.overviewSoloBot = soloTop, soloMid, soloBot

    local outTop = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    outTop:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -8); outTop:SetPoint("TOPRIGHT", right, "TOPRIGHT", -8, -8); outTop:SetJustifyH("CENTER")
    local outMid = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    outMid:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -24); outMid:SetPoint("TOPRIGHT", right, "TOPRIGHT", -8, -24); outMid:SetJustifyH("CENTER")
    local outBot = right:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    outBot:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -40); outBot:SetPoint("TOPRIGHT", right, "TOPRIGHT", -8, -40); outBot:SetJustifyH("CENTER"); outBot:SetTextColor(.58, .61, .66)
    W.overviewOutTop, W.overviewOutMid, W.overviewOutBot = outTop, outMid, outBot

    local function SlabTooltip(frame, title, build)
        frame:EnableMouse(true)
        frame:SetScript("OnEnter", function(self)
            local summary = W.Summary()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title)
            build(summary)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local function InstallOverviewGreyHover(frame, ...)
        local targets = {...}
        frame:HookScript("OnEnter", function()
            for _, target in ipairs(targets) do
                if target and target.SetTextColor then target:SetTextColor(.40, .90, .68) end
            end
        end)
        frame:HookScript("OnLeave", function()
            for _, target in ipairs(targets) do
                if target and target.SetTextColor then target:SetTextColor(.58, .61, .66) end
            end
        end)
    end

    SlabTooltip(left, "Solo 1v1", function(summary)
        GameTooltip:AddLine("Unassisted fights where one opponent contested you.", 1, 1, 1, true)
        GameTooltip:AddLine("Low-health deaths (engaged at 50% health or less) are excluded from solo losses.", .75, .78, .84, true)
        GameTooltip:AddLine(string.format("Record: %d-%d", summary.soloWins or 0, summary.soloLosses or 0), .4, .9, .68)
    end)
    SlabTooltip(right, "Solo Multikills", function(summary)
        local best = (summary.longestOutnumbered or 0) >= 2 and ("1v" .. tostring(summary.longestOutnumbered)) or "—"
        GameTooltip:AddLine("Unassisted victories where multiple enemies applied overlapping pressure to you.", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Victories", tostring(summary.outnumberedVictories or 0), .75, .78, .84, 1, .82, .42)
        GameTooltip:AddDoubleLine("Largest solo sweep", best, .75, .78, .84, .4, .9, .68)
        local breakdown = summary.outnumberedBySize or {}
        local sizes = {}
        for size, count in pairs(breakdown) do
            if count and count > 0 then sizes[#sizes + 1] = tonumber(size) or size end
        end
        table.sort(sizes, function(a, b) return tonumber(a) < tonumber(b) end)
        if #sizes > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("VICTORIES BY SIZE", 1, .82, .42)
            for _, size in ipairs(sizes) do
                GameTooltip:AddDoubleLine("1v" .. tostring(size), tostring(breakdown[size] or 0), .75, .78, .84, 1, 1, 1)
            end
        else
            GameTooltip:AddLine("Your first solo 1v2+ victory will start this record.", .60, .66, .74, true)
        end
    end)
    InstallOverviewGreyHover(left, soloBot)
    InstallOverviewGreyHover(right, outBot)

    -- Full-width secondary 2x2 plaque. Keep a single bronze frame here so the
    -- double-border treatment remains unique to the main headline plaque.
    local lowerCard = CreateFrame("Frame", nil, world)
    lowerCard:SetPoint("TOPLEFT", 26, -304); lowerCard:SetSize(300, 78)
    for row = 0, 75 do
        local glow = math.sin((row / 75) * math.pi)
        DP.Theme.Fill(lowerCard, 2, -2 - row, 296, 1,
            .035 + glow * .014, .048 + glow * .019, .065 + glow * .026, .98)
    end
    local lowerOuter = DP.Theme.Border(lowerCard, 0, 0, 300, 78)
    lowerOuter:EnableMouse(false)
    local bottom = CreateFrame("Frame", nil, lowerCard)
    bottom:SetPoint("TOPLEFT", lowerCard, "TOPLEFT", 2, -2)
    bottom:SetSize(296, 74)

    -- Replace the flat one-pixel rules with Blizzard metal-frame art so the
    -- quadrant split looks like a deliberate cross instead of drawn lines.
    do
        local bronze = {.93, .72, .44, .98}
        local hThickness, vThickness = 6, 6
        local endpointW, endpointH = 10, 8
        local hInset, vInset = 12, 8

        local function Unsnap(tex)
            if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
            if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        end

        -- Keep the working battlefield-minimap trim, but give it enough native
        -- height to show its bronze highlights. A faint additive duplicate
        -- lifts the dark source pixels without changing the cross geometry.
        local hBar = bottom:CreateTexture(nil, "BORDER")
        if hBar.SetAtlas then
            hBar:SetAtlas("battlefieldminimap-border-bottom", false)
        else
            hBar:SetTexture("Interface\\Buttons\\WHITE8X8")
        end
        Unsnap(hBar)
        hBar:SetVertexColor(.97, .77, .49, 1)
        hBar:SetPoint("LEFT", bottom, "LEFT", hInset, 0)
        hBar:SetPoint("RIGHT", bottom, "RIGHT", -hInset, 0)
        hBar:SetHeight(hThickness)

        local hGlow = bottom:CreateTexture(nil, "ARTWORK")
        if hGlow.SetAtlas then
            hGlow:SetAtlas("battlefieldminimap-border-bottom", false)
        else
            hGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
        end
        Unsnap(hGlow)
        hGlow:SetVertexColor(.98, .76, .48, .42)
        if hGlow.SetBlendMode then hGlow:SetBlendMode("ADD") end
        hGlow:SetPoint("LEFT", hBar, "LEFT", 0, 0)
        hGlow:SetPoint("RIGHT", hBar, "RIGHT", 0, 0)
        hGlow:SetHeight(hThickness)

        local vBar = bottom:CreateTexture(nil, "BORDER")
        if vBar.SetAtlas then
            vBar:SetAtlas("battlefieldminimap-border-right", false)
        else
            vBar:SetTexture("Interface\\Buttons\\WHITE8X8")
        end
        Unsnap(vBar)
        vBar:SetVertexColor(bronze[1], bronze[2], bronze[3], bronze[4])
        vBar:SetPoint("TOP", bottom, "TOP", 0, -vInset)
        vBar:SetPoint("BOTTOM", bottom, "BOTTOM", 0, vInset)
        vBar:SetWidth(vThickness)

        local function Endpoint(relativeTo, relativePoint, dx, dy, rotation)
            local tex = bottom:CreateTexture(nil, "OVERLAY")
            if tex.SetAtlas then
                tex:SetAtlas("GarrMission_EncounterBar-End", false)
            else
                tex:SetTexture("Interface\\Buttons\\WHITE8X8")
            end
            Unsnap(tex)
            tex:SetVertexColor(bronze[1], bronze[2], bronze[3], bronze[4])
            tex:SetSize(endpointW, endpointH)
            tex:SetPoint("CENTER", relativeTo, relativePoint, dx or 0, dy or 0)
            if rotation and tex.SetRotation then tex:SetRotation(rotation) end
            return tex
        end

        local overlap = 2
        local topEndpointX = .5
        local bottomEndpointX = 0
        Endpoint(hBar, "LEFT", overlap, 0, 0)
        Endpoint(hBar, "RIGHT", -overlap, 0, math.pi)
        Endpoint(vBar, "TOP", topEndpointX, -overlap, math.pi * .5)
        Endpoint(vBar, "BOTTOM", bottomEndpointX, overlap, -math.pi * .5)
    end

    local function quadrant(x, y)
        local holder = CreateFrame("Frame", nil, bottom)
        holder:SetPoint("TOPLEFT", bottom, "TOPLEFT", x, y)
        holder:SetSize(148, 37)
        local label = holder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetPoint("CENTER", holder, "CENTER", 0, 8); label:SetWidth(132); label:SetJustifyH("CENTER"); label:SetTextColor(.58, .61, .66)
        local value = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("CENTER", holder, "CENTER", 0, -6); value:SetWidth(132); value:SetJustifyH("CENTER")
        holder:EnableMouse(true)
        return holder, label, value
    end
    local hkBox, hkL, hkV = quadrant(148, 0)
    local gankBox, gankL, gankV = quadrant(0, -37)
    local mostBox, mostL, mostV = quadrant(0, 0)
    local goldBox, goldL, goldV = quadrant(148, -37)
    W.overviewStatLabels = {hkL=hkL, hkV=hkV, gankL=gankL, gankV=gankV,
        mostL=mostL, mostV=mostV, goldL=goldL, goldV=goldV}
    W.overviewStatBoxes = {hk=hkBox, gank=gankBox, most=mostBox, gold=goldBox}

    local function StatTooltip(box, title, build, titleR, titleG, titleB)
        box:SetScript("OnEnter", function(self)
            local summary = W.Summary()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if titleR then GameTooltip:SetText(title, titleR, titleG, titleB) else GameTooltip:SetText(title) end
            build(summary)
            GameTooltip:Show()
        end)
        box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    hkBox:SetScript("OnEnter",function(self) GameTooltip:Hide();DP.OverviewCharts.ShowBuffs(self,W.Summary()) end)
    hkBox:SetScript("OnLeave",DP.OverviewCharts.HideBuffs);hkBox:SetScript("OnHide",DP.OverviewCharts.HideBuffs)
    gankBox:SetScript("OnEnter",function(self) GameTooltip:Hide();DP.OverviewCharts.ShowZones(self,W.Summary()) end)
    gankBox:SetScript("OnLeave",DP.OverviewCharts.HideZones);gankBox:SetScript("OnHide",DP.OverviewCharts.HideZones)
    mostBox:SetScript("OnEnter",function(self)
        GameTooltip:Hide();DP.RivalChart.Show(self,W.Summary())
    end)
    mostBox:SetScript("OnLeave",DP.RivalChart.Hide)
    mostBox:SetScript("OnHide",DP.RivalChart.Hide)
    goldBox:SetScript("OnEnter", function(self)
        GameTooltip:Hide()
        local summary = W.Summary()
        DP.SpendChart.Show(self, summary.enemyGoldCategories, summary.enemyGoldSpentCopper)
    end)
    goldBox:SetScript("OnLeave", DP.SpendChart.Hide)
    goldBox:SetScript("OnHide", DP.SpendChart.Hide)
    InstallOverviewGreyHover(mostBox, mostL)
    InstallOverviewGreyHover(hkBox, hkL)
    InstallOverviewGreyHover(gankBox, gankL)
    InstallOverviewGreyHover(goldBox, goldL)
    W.overviewLowerCard = lowerCard

    local note = world:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 26, -390); note:SetWidth(300); note:SetJustifyH("CENTER")
    note:SetText("Open-world encounters • no Duel Rating impact")

    -- Deaths and K/D are useful history, but not the identity of this page. Keep
    -- them one hover away rather than making them the headline.
    local function ShowRecordTooltip(owner)
        local summary = W.Summary()
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText("World PvP record")
        GameTooltip:AddDoubleLine("Kills", tostring(summary.kills or 0), .75, .78, .84, .4, .9, .68)
        GameTooltip:AddDoubleLine("Deaths", tostring(summary.deaths or 0), .75, .78, .84, 1, .45, .45)
        GameTooltip:AddDoubleLine("K/D", string.format("%.2f", (summary.kills or 0) / math.max(1, summary.deaths or 0)), .75, .78, .84, 1, .82, .42)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Honorable kills", tostring(summary.honorableKills or 0), .75, .78, .84, 1, .82, .42)
        GameTooltip:AddDoubleLine("Ganks", tostring(summary.ganks or 0), .75, .78, .84, 1, .68, .40)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Fights recorded", tostring(summary.encounters or 0), .75, .78, .84, 1, 1, 1)
        GameTooltip:Show()
    end

    local cardHover = CreateFrame("Button", nil, world)
    cardHover:SetSize(300, 96); cardHover:SetPoint("TOPLEFT", 26, -130)
    cardHover:SetFrameLevel(world:GetFrameLevel() + 8)
    cardHover:SetScript("OnEnter", function(self) ShowRecordTooltip(self) end)
    cardHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    W.overviewCardHover = cardHover

    -- Give the two streak fields independent hover zones above the broad card
    -- hover so each grey label can react on its own.
    local currentStreakHover = CreateFrame("Button", nil, world)
    currentStreakHover:SetPoint("TOPLEFT", 38, -176)
    currentStreakHover:SetSize(124, 39)
    currentStreakHover:SetFrameLevel(world:GetFrameLevel() + 9)
    currentStreakHover:SetScript("OnEnter", function(self)
        currentStreakLabel:SetTextColor(.40, .90, .68)
        ShowRecordTooltip(self)
    end)
    currentStreakHover:SetScript("OnLeave", function()
        currentStreakLabel:SetTextColor(.58, .61, .66)
        GameTooltip:Hide()
    end)

    local bestStreakHover = CreateFrame("Button", nil, world)
    bestStreakHover:SetPoint("TOPLEFT", 190, -176)
    bestStreakHover:SetSize(124, 39)
    bestStreakHover:SetFrameLevel(world:GetFrameLevel() + 9)
    bestStreakHover:SetScript("OnEnter", function(self)
        bestStreakLabel:SetTextColor(.40, .90, .68)
        ShowRecordTooltip(self)
    end)
    bestStreakHover:SetScript("OnLeave", function()
        bestStreakLabel:SetTextColor(.58, .61, .66)
        GameTooltip:Hide()
    end)
    W.overviewCurrentStreakHover = currentStreakHover
    W.overviewBestStreakHover = bestStreakHover

    -- History already has a first-class top navigation tab. Keep Overview's
    -- footer for an action unique to this page instead of a redundant shortcut.
    local manage = DP.Theme.Button(world, "Manage", 105, -403, 142, function()
        if DP.SelectDuelView then DP.SelectDuelView("Manage") end
    end)
    W.overviewHistoryButton, W.overviewManageButton = nil, manage

    -- Stationary pagination in the exact gutter between the main card and the
    -- two stat slabs. It never moves with either page.
    local dots = CreateFrame("Frame", nil, overview)
    dots:SetSize(22, 8)
    -- Center against the actual 292px rating-card column, not the wider
    -- Overview frame. Keep the anchor on the stationary Overview host rather
    -- than either moving page so the paginator itself never joins the swipe.
    -- Card bounds are x=30..322, so the visual center is x=176.
    dots:SetPoint("TOP", viewport, "TOP", 0, -227)
    dots:SetFrameLevel(math.max(duelPage:GetFrameLevel(), world:GetFrameLevel()) + 20)
    W.overviewDots = dots
    W.duelDot = CreateOverviewDot(dots, -4, "duels")
    W.worldDot = CreateOverviewDot(dots, 4, "world")

    -- Mouse shield prevents outgoing/incoming page controls from being clicked
    -- halfway through a swipe. Dots remain above it but ignore clicks while busy.
    local shield = CreateFrame("Button", nil, overview)
    shield:SetAllPoints(viewport); shield:EnableMouse(true)
    shield:SetFrameLevel(dots:GetFrameLevel() - 1)
    shield:Hide()
    W.swipeShield = shield

    if overview.HookScript then
        overview:HookScript("OnShow", function()
            SyncOverviewViewport()
            -- Opening Overview should animate only the page that is actually
            -- selected. Child OnShow events are intentionally ignored during
            -- swipes so the bright sweep never crosses two moving pages.
            if W.swipe then return end
            if W.overviewMode == "world" then
                if W.PlayOverviewSweep then W.PlayOverviewSweep() end
            elseif DP.PlayOverviewSweep then DP.PlayOverviewSweep() end
        end)
    end

    local saved = W.db and W.db.worldPvPOverviewMode or "duels"
    W.overviewMode = saved == "world" and "world" or "duels"
    W.SetOverviewMode(W.overviewMode, true)
end

function W.GetOverviewMode()
    return W.overviewMode == "world" and "world" or "duels"
end

function W.SetOverviewMode(mode, immediate)
    if W.swipe and not immediate then return end
    if CloseDropDownMenus then CloseDropDownMenus() end
    if GameTooltip then GameTooltip:Hide() end
    local target = mode == "world" and "world" or "duels"
    local old = W.overviewMode or (W.db and W.db.worldPvPOverviewMode) or "duels"
    W.overviewMode = target
    if W.db then W.db.worldPvPOverviewMode = target end
    if DP.RefreshRivalsCharacterTabLabel then DP.RefreshRivalsCharacterTabLabel() end

    if not W.overviewHost or not W.overviewFrame or not W.duelOverviewFrame then return end
    SyncOverviewViewport()
    if target == "world" then W.RefreshOverview() end

    if old == target or immediate or not W.overviewHost:IsShown() then
        UpdateOverviewDots()
        FinishOverviewSwipe()
        if W.overviewHost:IsShown() then
            if target == "world" and W.PlayOverviewSweep then W.PlayOverviewSweep()
            elseif target == "duels" and DP.PlayOverviewSweep then DP.PlayOverviewSweep() end
        end
        return
    end

    -- Duels live to the left of World PvP: moving toward World PvP swipes left;
    -- returning to Duels swipes right. The ScrollFrame clips both pages cleanly.
    W.overviewHost:SetScript("OnUpdate", nil)
    local incoming = target == "world" and W.overviewFrame or W.duelOverviewFrame
    local outgoing = target == "world" and W.duelOverviewFrame or W.overviewFrame
    local canvas = W.overviewCanvas or W.overviewHost
    local width = OverviewWidth()
    local incomingStart = target == "world" and width or -width
    local outgoingEnd = target == "world" and -width or width
    PositionOverviewPage(outgoing, canvas, 0)
    PositionOverviewPage(incoming, canvas, incomingStart)
    outgoing:Show(); incoming:Show()
    if W.swipeShield then W.swipeShield:Show() end
    local elapsed, dotSwitched = 0, false
    incoming:SetAlpha(1); outgoing:SetAlpha(1)
    W.swipe = {incoming = incoming, outgoing = outgoing}
    W.overviewHost:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        local t = math.min(1, elapsed / OVERVIEW_SWIPE_TIME)
        if not dotSwitched and t >= .5 then dotSwitched = true; UpdateOverviewDots() end
        -- Smoothstep keeps the pages on the same visual plane: a gentle launch,
        -- quick middle travel, then a clean settle. The old cubic ease-out moved
        -- almost the entire page in the first few frames and looked like a snap.
        local eased = t * t * (3 - 2 * t)
        PositionOverviewPage(outgoing, canvas, outgoingEnd * eased)
        PositionOverviewPage(incoming, canvas, incomingStart * (1 - eased))
        -- Keep both pages fully opaque during the push. Cross-fading made text
        -- look muddy at mid-swipe; the clipped, eased motion is enough.
        incoming:SetAlpha(1)
        outgoing:SetAlpha(1)
        if t >= 1 then
            FinishOverviewSwipe()
            local function SweepAfterSettle()
                if W.overviewMode ~= target or not W.overviewHost or not W.overviewHost:IsShown() then return end
                if target == "world" then
                    if W.PlayOverviewSweep then W.PlayOverviewSweep() end
                elseif DP.PlayOverviewSweep then DP.PlayOverviewSweep() end
            end
            if C_Timer and C_Timer.After then C_Timer.After(.06, SweepAfterSettle) else SweepAfterSettle() end
        end
    end)
end

function W.RefreshOverview()
    if not W.overviewFrame then return end
    local s = W.Summary()
    W.overviewHeadline:SetText(string.format("|cff65e6ad%d KILLS|r", s.kills or 0))
    do
        local left = W.overviewHeadlineFlourishLeft
        local right = W.overviewHeadlineFlourishRight
        if left and right and W.overviewHeadline then
            local width = W.overviewHeadline.GetStringWidth and W.overviewHeadline:GetStringWidth() or 0
            local half = math.max(0, width * 0.5)
            local pad = 8
            left:ClearAllPoints()
            left:SetPoint("RIGHT", W.overviewHeadline, "CENTER", -(half + pad), -2)
            right:ClearAllPoints()
            right:SetPoint("LEFT", W.overviewHeadline, "CENTER", half + pad, -2)
            left:Show()
            right:Show()
            if left.shadow then left.shadow:Show() end
            if right.shadow then right.shadow:Show() end
        end
    end
    if W.overviewCurrentStreak then W.overviewCurrentStreak:SetText(string.format("|cffffce70%d|r", s.currentStreak or 0)) end
    if W.overviewBestStreak then W.overviewBestStreak:SetText(string.format("|cffffce70%d|r", s.longestStreak or 0)) end

    if W.overviewSoloTop then W.overviewSoloTop:SetText(string.format("|cff65e6ad%d|r—|cffff8888%d|r", s.soloWins or 0, s.soloLosses or 0)) end
    if W.overviewSoloMid then W.overviewSoloMid:SetText("Solo 1v1") end
    if W.overviewSoloBot then
        local wins = s.soloWins or 0
        W.overviewSoloBot:SetText(string.format("%d %s", wins, wins == 1 and "victory" or "victories"))
    end

    local largest = (s.longestOutnumbered or 0) >= 2 and ("1v" .. tostring(s.longestOutnumbered)) or "—"
    if W.overviewOutTop then W.overviewOutTop:SetText(string.format("|cffffce70%d|r", s.outnumberedVictories or 0)) end
    if W.overviewOutMid then W.overviewOutMid:SetText("Solo Multikills") end
    if W.overviewOutBot then W.overviewOutBot:SetText("Best " .. largest) end

    local L = W.overviewStatLabels or {}
    for _,key in ipairs({"hkL","mostL","gankL","goldL"}) do
        local label=L[key]
        if label then
            local font,_,flags=label:GetFont()
            label:SetFont(font,9,flags);label:SetWordWrap(false)
        end
    end
    if L.hkL then L.hkL:SetText("WORLD BUFFS REMOVED") end
    if L.hkV then L.hkV:SetText(string.format("|cffffce70%d|r", s.worldBuffRemovalCount or 0)) end
    if L.gankL then L.gankL:SetText("FAVORITE ZONE") end
    if L.gankV then L.gankV:SetText(s.favoriteZone or "—") end
    if L.mostL then L.mostL:SetText("MOST KILLED") end
    if L.mostV then
        local value = s.mostKilledName and DP.Theme.ClassName(s.mostKilledName, s.mostKilledClass) or "—"
        L.mostV:SetText(value)
    end
    if L.goldL then L.goldL:SetText("ENEMY GOLD SPENT") end
    if L.goldV then
        L.goldV:SetText(string.format("|cffffce70%s|r", EnemyGoldText(s.enemyGoldSpentCopper, s.enemyGoldSpentPartial, true)))
    end
end

-- Details window --------------------------------------------------------------
local function LinkForEntry(entry)
    if not entry then return nil end
    if entry.itemID then
        local get = C_Item and C_Item.GetItemInfo or GetItemInfo
        local _, link = get and get(entry.itemID)
        return link or ("item:" .. tostring(entry.itemID))
    end
    if entry.spellID then
        if C_Spell and C_Spell.GetSpellLink then return C_Spell.GetSpellLink(entry.spellID) end
        if GetSpellLink then return GetSpellLink(entry.spellID) end
    end
end

local function InsertLink(entry)
    if not IsShiftKeyDown or not IsShiftKeyDown() then return end
    local link = LinkForEntry(entry)
    if not link then return end
    if ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
end

local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function ConfigureSmoothWheelScroll(scroll, body, step, topHint, bottomHint)
    if not scroll then return end
    step = step or 28
    scroll.smoothTarget = 0
    local function Range(self)
        return math.max(0, (body and body.GetHeight and body:GetHeight() or 0) - (self:GetHeight() or 0))
    end
    function scroll:UpdateScrollHints()
        local range = Range(self)
        local current = self:GetVerticalScroll() or 0
        if topHint then topHint:SetShown(range > 1 and current > 1) end
        if bottomHint then bottomHint:SetShown(range > 1 and current < range - 1) end
    end
    function scroll:ScrollTo(value)
        self.smoothTarget = Clamp(value, 0, Range(self))
        if self.smoothScrolling then return end
        self.smoothScrolling = true
        self:SetScript("OnUpdate", function(frame, elapsed)
            local target = Clamp(frame.smoothTarget or 0, 0, Range(frame))
            local current = frame:GetVerticalScroll() or 0
            local difference = target - current
            if math.abs(difference) < .35 then
                frame:SetVerticalScroll(target)
                frame.smoothScrolling = false
                frame:SetScript("OnUpdate", nil)
                frame:UpdateScrollHints()
                return
            end
            local amount = 1 - math.exp(-10 * math.max(0, elapsed or 0))
            frame:SetVerticalScroll(current + difference * amount)
            frame:UpdateScrollHints()
        end)
    end
    function scroll:ScrollByWheel(delta)
        -- Only accumulate against a destination while its animation is active.
        -- A direct reset/scrollbar move may have changed the visible position.
        local base = self.smoothScrolling and self.smoothTarget or nil
        if base == nil then base = self:GetVerticalScroll() or 0 end
        self:ScrollTo(base - delta * step)
    end
    function scroll:ResetScroll(value)
        self.smoothScrolling = false
        self:SetScript("OnUpdate", nil)
        self.smoothTarget = Clamp(tonumber(value) or 0, 0, Range(self))
        self:SetVerticalScroll(self.smoothTarget)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta) self:ScrollByWheel(delta) end)
    scroll:UpdateScrollHints()
end

local function DetailTooltip(frame, title, build, anchor)
    if not frame then return end
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        local record = W.details and W.details.record
        if not record then return end
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        local heading = type(title) == "function" and title(self, record) or title
        if heading and heading ~= "" then GameTooltip:SetText(heading) end
        if build then build(self, record) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end


local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"

local function CommaNumber(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    if BreakUpLargeNumbers then
        local ok, result = pcall(BreakUpLargeNumbers, value)
        if ok and result then return tostring(result) end
    end
    local text = tostring(value)
    local chunks = {}
    while #text > 3 do
        table.insert(chunks, 1, text:sub(-3))
        text = text:sub(1, -4)
    end
    table.insert(chunks, 1, text)
    return table.concat(chunks, ",")
end

local function FormatMoneyIcons(copper, approximate)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local coin = copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = CommaNumber(gold) .. GOLD_ICON end
    if gold > 0 or silver > 0 then parts[#parts + 1] = tostring(silver) .. SILVER_ICON end
    parts[#parts + 1] = tostring(coin) .. COPPER_ICON
    return (approximate and "~" or "") .. table.concat(parts, " ")
end

local function PlainMoney(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local coin = copper % 100
    if gold > 0 then return string.format("%sg %ds %dc", CommaNumber(gold), silver, coin) end
    if silver > 0 then return string.format("%ds %dc", silver, coin) end
    return string.format("%dc", coin)
end

local function PriceSourceText(snapshot)
    local seen, list = {}, {}
    for _, actor in ipairs(snapshot and snapshot.actors or {}) do
        for _, item in ipairs(actor.items or {}) do
            if item.priceSource and not seen[item.priceSource] then
                seen[item.priceSource] = true
                list[#list + 1] = item.priceSource == "TradeSkillMaster" and "TSM DBMarket" or
                    item.priceSource == "Vendor" and "Vendor" or item.priceSource
            end
        end
    end
    if #list == 0 then return nil end
    return table.concat(list, " / ")
end

local TOOLTIP_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4},
}

local function EnsureConsumableCostTooltip(window)
    if window.consumableCostTooltip then return window.consumableCostTooltip end
    local tip = CreateFrame("Frame", nil, window, BackdropTemplateMixin and "BackdropTemplate" or nil)
    tip:SetSize(340, 80)
    if tip.SetFrameStrata then tip:SetFrameStrata("TOOLTIP") end
    if tip.SetFrameLevel and window.GetFrameLevel then tip:SetFrameLevel(window:GetFrameLevel() + 30) end
    -- UI-Tooltip-Background itself contains transparency. Put an explicit
    -- solid black layer behind the Blizzard tooltip artwork so the ledger is
    -- completely opaque over the busy world/UI beneath it.
    tip.opaqueBg = tip:CreateTexture(nil, "BACKGROUND")
    tip.opaqueBg:SetPoint("TOPLEFT", 3, -3)
    tip.opaqueBg:SetPoint("BOTTOMRIGHT", -3, 3)
    tip.opaqueBg:SetColorTexture(0, 0, 0, 1)
    if tip.SetBackdrop then
        tip:SetBackdrop(TOOLTIP_BACKDROP)
        tip:SetBackdropColor(0, 0, 0, 1)
        tip:SetBackdropBorderColor(.78, .78, .78, 1)
    else
        tip.bg = tip:CreateTexture(nil, "BACKGROUND")
        tip.bg:SetAllPoints(); tip.bg:SetColorTexture(0, 0, 0, 1)
    end
    tip.title = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    tip.title:SetPoint("TOPLEFT", 10, -9); tip.title:SetJustifyH("LEFT")
    tip.subtitle = tip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tip.subtitle:SetPoint("TOPLEFT", 10, -28); tip.subtitle:SetJustifyH("LEFT")
    tip.rows = {}
    tip.footer = tip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tip.footer:SetJustifyH("LEFT"); tip.footer:SetJustifyV("TOP"); tip.footer:SetWordWrap(true)

    -- Unconstrained measuring strings let the ledger size itself to real font
    -- metrics instead of guessing from character counts or clipping at the
    -- previous tooltip width.
    tip.measureLeft = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tip.measureLeft:Hide()
    tip.measureCost = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tip.measureCost:Hide()

    tip:Hide()
    window.consumableCostTooltip = tip
    return tip
end

local function EnsureCostRow(tip, index)
    local row = tip.rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, tip)
    row:SetHeight(18)
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.left:SetPoint("LEFT", 7, 0); row.left:SetJustifyH("LEFT"); row.left:SetWordWrap(false)
    row.qty = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.qty:SetJustifyH("RIGHT"); row.qty:SetWordWrap(false)
    row.cost = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.cost:SetPoint("RIGHT", -7, 0); row.cost:SetJustifyH("RIGHT"); row.cost:SetWordWrap(false)
    tip.rows[index] = row
    return row
end

local function ApproxTextWidth(text)
    text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", "  ")
    return #text * 7
end

local function MeasureTextWidth(fontString, text)
    if fontString and fontString.SetText then
        fontString:SetText(text or "")
        local width
        if fontString.GetUnboundedStringWidth then
            local ok, measured = pcall(fontString.GetUnboundedStringWidth, fontString)
            if ok then width = tonumber(measured) end
        end
        if (not width or width <= 0) and fontString.GetStringWidth then
            local ok, measured = pcall(fontString.GetStringWidth, fontString)
            if ok then width = tonumber(measured) end
        end
        if width and width > 0 then return math.ceil(width) end
    end
    return math.ceil(ApproxTextWidth(text))
end

local COST_TIP_MARGIN = 10
local COST_ROW_PAD = 8
local COST_COLUMN_GAP = 12

local function ResizeConsumableTooltip(tip, width, costWidth)
    width = math.max(270, math.floor(width or 320))
    if UIParent and UIParent.GetWidth then
        local ok, screenWidth = pcall(UIParent.GetWidth, UIParent)
        if ok and tonumber(screenWidth) and screenWidth > 0 then
            width = math.min(width, math.max(270, math.floor(screenWidth - 30)))
        end
    end

    local inner = width - (COST_TIP_MARGIN * 2)
    costWidth = math.max(58, math.floor(costWidth or 90))

    tip:SetWidth(width)
    tip.title:SetWidth(inner)
    tip.subtitle:SetWidth(inner)
    tip.footer:SetWidth(inner)

    for _, row in ipairs(tip.rows) do
        row:SetWidth(inner)
        row.left:ClearAllPoints()
        row.left:SetPoint("LEFT", COST_ROW_PAD, 0)

        row.cost:ClearAllPoints()
        row.cost:SetPoint("RIGHT", -COST_ROW_PAD, 0)
        row.cost:SetWidth(costWidth)

        -- Quantity is part of the item label ("x1", "x2", ...), so there is
        -- no detached middle column.
        row.qty:ClearAllPoints()
        row.qty:SetPoint("RIGHT", row.cost, "LEFT", -2, 0)
        row.qty:SetWidth(1)

        row.left:SetWidth(math.max(
            120,
            inner - (COST_ROW_PAD * 2) - COST_COLUMN_GAP - costWidth
        ))
    end
    return width, inner
end

local function ProxyDisplayName(item)
    local proxyID = tonumber(item and item.priceProxyItemID)
    if not proxyID or proxyID == tonumber(item.itemID) then return nil end
    local name = item.priceProxyItemName
    if (not name or name == "") and GetItemInfo then name = GetItemInfo(proxyID) end
    if (not name or name == "") and item.priceSourceKey then
        name = item.priceSourceKey:match("1x (.+)$")
    end
    return name
end

local function LedgerItemName(item)
    local name = tostring(item and item.name or "Unknown consumable")
    local proxy = ProxyDisplayName(item)
    if proxy and proxy ~= "" then return name .. " (" .. proxy .. ")" end
    return name
end

local function ConsumableCostValue(item)
    if not item or item.unpriced then return -1 end
    return tonumber(item.totalCopper) or 0
end

local function SortedConsumableItems(actor)
    local items = {}
    for _, item in ipairs(actor and actor.items or {}) do items[#items + 1] = item end
    table.sort(items, function(a, b)
        local av, bv = ConsumableCostValue(a), ConsumableCostValue(b)
        if av ~= bv then return av > bv end
        local ac, bc = tonumber(a.count) or 0, tonumber(b.count) or 0
        if ac ~= bc then return ac > bc end
        return LedgerItemName(a) < LedgerItemName(b)
    end)
    return items
end

local function SortedConsumableActors(snapshot, record)
    local actors = {}
    for _, actor in ipairs(snapshot and snapshot.actors or {}) do actors[#actors + 1] = actor end
    table.sort(actors, function(a, b)
        local av, bv = tonumber(a.totalCopper) or 0, tonumber(b.totalCopper) or 0
        if av ~= bv then return av > bv end
        local au, bu = tonumber(a.unpricedCount) or 0, tonumber(b.unpricedCount) or 0
        if au ~= bu then return au < bu end
        -- Cost is the hierarchy. Stable identity ordering only breaks exact ties.
        local an = a.guid == (record and record.playerGUID) and "You" or ShortName(a.name)
        local bn = b.guid == (record and record.playerGUID) and "You" or ShortName(b.name)
        return tostring(an or "") < tostring(bn or "")
    end)
    return actors
end

local function PopulateConsumableCostTooltip(window, owner, record)
    local tip = EnsureConsumableCostTooltip(window)
    local snapshot = record and record.consumableCost
    for _, row in ipairs(tip.rows) do row:Hide() end
    tip:ClearAllPoints(); tip:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", -4, 0)
    tip.title:SetText("Consumable Cost")
    if not snapshot then
        tip.subtitle:Show()
        ResizeConsumableTooltip(tip, 245)
        tip.subtitle:SetText("No consumables recorded.")
        tip.footer:SetText("")
        tip:SetHeight(52); tip:Show(); return
    end

    local total = snapshot.totalCopper or 0
    local partial = snapshot.partial
    local unavailableLegacy = snapshot.backfilled and snapshot.legacyReconstructedFrom == "no-retained-events"
    local estimateText = unavailableLegacy and "|cff888f99—|r" or
        ((snapshot.pricedCount or 0) == 0 and (snapshot.unpricedCount or 0) > 0 and "|cff888f99—|r" or FormatMoneyIcons(total, partial))
    local actorCount = #(snapshot.actors or {})
    local sortedActors = SortedConsumableActors(snapshot, record)
    if actorCount == 0 then
        tip.subtitle:Show()
        ResizeConsumableTooltip(tip, 245)
        tip.subtitle:SetText("No consumables recorded.")
        tip.footer:SetText("")
        tip:SetHeight(52); tip:Show(); return
    end

    -- The ledger itself is the context; the old "Legacy encounter • current-price
    -- snapshot" sub-header repeated information already conveyed by the footer.
    tip.subtitle:SetText("")
    tip.subtitle:Hide()

    local sourceText = PriceSourceText(snapshot)
    local footerParts = {}
    -- Price snapshots are intentionally immutable; that behavior does not need
    -- to be repeated in every tooltip footer. Keep the footer to useful provenance.
    if sourceText then footerParts[#footerParts + 1] = sourceText end
    local inferred = tonumber(snapshot.buffInferredCount) or tonumber(snapshot.legacyAuraInferredCount) or 0
    if inferred > 0 then footerParts[#footerParts + 1] = tostring(inferred) .. " buff-inferred" end
    if (snapshot.unpricedCount or 0) > 0 then footerParts[#footerParts + 1] = tostring(snapshot.unpricedCount) .. " unpriced" end
    local footerText = table.concat(footerParts, "  •  ")

    -- Measure the two visible ledger columns independently. This keeps short
    -- ledgers compact while letting long item names expand the tooltip instead
    -- of being ellipsized.
    local maxLeft = MeasureTextWidth(tip.measureLeft, "Total consumable cost")
    local maxCost = MeasureTextWidth(tip.measureCost, estimateText)
    for _, actor in ipairs(sortedActors) do
        local actorName = actor.guid == record.playerGUID and "You" or ShortName(actor.name)
        maxLeft = math.max(maxLeft, MeasureTextWidth(tip.measureLeft, actorName))
        maxCost = math.max(maxCost, MeasureTextWidth(tip.measureCost,
            FormatMoneyIcons(actor.totalCopper or 0, (actor.unpricedCount or 0) > 0)))
        for _, item in ipairs(SortedConsumableItems(actor)) do
            local inline = LedgerItemName(item) .. " x" .. tostring(item.count or 1)
            maxLeft = math.max(maxLeft, MeasureTextWidth(tip.measureLeft, inline))
            local costText = item.unpriced and "unpriced" or PlainMoney(item.totalCopper or 0)
            maxCost = math.max(maxCost, MeasureTextWidth(tip.measureCost, costText))
        end
    end

    local desired = (COST_TIP_MARGIN * 2) + (COST_ROW_PAD * 2) +
        COST_COLUMN_GAP + maxLeft + maxCost + 6
    local _, inner = ResizeConsumableTooltip(tip, desired, maxCost + 2)

    local y, rowIndex, stripe = 31, 0, 0
    for _, actor in ipairs(sortedActors) do
        rowIndex = rowIndex + 1
        local header = EnsureCostRow(tip, rowIndex)
        ResizeConsumableTooltip(tip, tip.GetWidth and tip:GetWidth() or desired, maxCost + 2)
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", COST_TIP_MARGIN, -y); header:SetHeight(20)
        header.bg:SetColorTexture(.09, .07, .035, .96)
        local actorName = ShortName(actor.name)
        if actor.guid == record.playerGUID then actorName = "You" end
        header.left:SetText(DP.Theme.ClassName(actorName, actor.class))
        header.qty:SetText("")
        header.cost:SetText(FormatMoneyIcons(actor.totalCopper or 0, (actor.unpricedCount or 0) > 0))
        header:Show(); y = y + 20
        for _, item in ipairs(SortedConsumableItems(actor)) do
            rowIndex = rowIndex + 1; stripe = stripe + 1
            local row = EnsureCostRow(tip, rowIndex)
            ResizeConsumableTooltip(tip, tip.GetWidth and tip:GetWidth() or desired, maxCost + 2)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", COST_TIP_MARGIN, -y); row:SetHeight(18)
            if stripe % 2 == 0 then row.bg:SetColorTexture(.085, .085, .085, .72)
            else row.bg:SetColorTexture(.035, .035, .035, .88) end
            row.left:SetText(LedgerItemName(item) .. " |cff8f969fx" .. tostring(item.count or 1) .. "|r")
            row.qty:SetText("")
            row.cost:SetText(item.unpriced and "|cff888f99unpriced|r" or PlainMoney(item.totalCopper or 0))
            row:Show(); y = y + 18
        end
    end

    rowIndex = rowIndex + 1
    local totalRow = EnsureCostRow(tip, rowIndex)
    ResizeConsumableTooltip(tip, tip.GetWidth and tip:GetWidth() or desired, maxCost + 2)
    totalRow:ClearAllPoints(); totalRow:SetPoint("TOPLEFT", COST_TIP_MARGIN, -(y + 3)); totalRow:SetHeight(22)
    totalRow.bg:SetColorTexture(.055, .055, .055, .96)
    totalRow.left:SetText("|cffffd15cTotal consumable cost|r")
    totalRow.qty:SetText("")
    totalRow.cost:SetText(estimateText)
    totalRow:Show(); y = y + 28

    tip.footer:ClearAllPoints(); tip.footer:SetPoint("TOPLEFT", COST_TIP_MARGIN, -(y + 5)); tip.footer:SetText(footerText)
    local footerHeight = 12
    if tip.footer.GetStringHeight then
        local measured = tonumber(tip.footer:GetStringHeight())
        if measured and measured > 0 then footerHeight = math.ceil(measured) end
    end
    -- Balance the footer against the title/ledger spacing and leave enough
    -- breathing room above the Blizzard tooltip bottom border.
    tip:SetHeight(y + 5 + footerHeight + 9)
    tip:Show()
end

local function InstallConsumableCostTooltip(tile, window)
    tile:EnableMouse(true)
    tile:SetScript("OnEnter", function(self)
        if self.hoverLabel then self.hoverLabel:SetTextColor(1, .82, .42) end
        if self.hoverValue then self.hoverValue:SetTextColor(1, .94, .58) end
        local record = W.details and W.details.record
        if record then PopulateConsumableCostTooltip(window, self, record) end
    end)
    tile:SetScript("OnLeave", function(self)
        if self.hoverLabel then self.hoverLabel:SetTextColor(.50, .50, .50) end
        if self.hoverValue then self.hoverValue:SetTextColor(1, 1, 1) end
        if window.consumableCostTooltip then window.consumableCostTooltip:Hide() end
    end)
end

local function OpponentStatsFor(enemy)
    if not enemy then return nil end
    local key = enemy.guid or enemy.name
    for _, stats in ipairs((W.BuildMatchups and W.BuildMatchups().Opponents) or {}) do
        if stats.key == key then return stats end
    end
    return nil
end

local function OpponentFightStats(record, enemy)
    local result = {damageToYou = 0, damageFromYou = 0, healing = 0, casts = 0, interrupts = 0, dispels = 0}
    if not record or not enemy then return result end
    local playerGUID = record.playerGUID
    for _, entry in ipairs(record.session and record.session.worldCombatLog or {}) do
        local event = entry.event
        if entry.sourceGUID == enemy.guid then
            if event == "SPELL_CAST_SUCCESS" then result.casts = result.casts + 1 end
            if event == "SPELL_INTERRUPT" then result.interrupts = result.interrupts + 1 end
            if event == "SPELL_DISPEL" or event == "SPELL_STOLEN" then result.dispels = result.dispels + 1 end
            if event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then result.healing = result.healing + (tonumber(entry.amount) or 0) end
            if entry.destGUID == playerGUID and (event == "SWING_DAMAGE" or event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE") then
                result.damageToYou = result.damageToYou + (tonumber(entry.amount) or 0)
            end
        end
        if entry.sourceGUID == playerGUID and entry.destGUID == enemy.guid and
            (event == "SWING_DAMAGE" or event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE") then
            result.damageFromYou = result.damageFromYou + (tonumber(entry.amount) or 0)
        end
    end
    return result
end

local function IsDamageExchangeEvent(event)
    return event == "SWING_DAMAGE" or event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE"
end

local function IsHealingExchangeEvent(event)
    return event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL"
end

local function IsNPCCombatGUID(guid)
    if type(guid) ~= "string" then return false end
    return guid:match("^Creature%-") ~= nil or guid:match("^Vehicle%-") ~= nil
end

local function EffectiveHealingAmount(entry)
    if not entry then return 0 end
    local effective = tonumber(entry.effectiveAmount)
    if effective ~= nil then return math.max(0, effective) end
    local amount = tonumber(entry.amount) or 0
    local overhealing = tonumber(entry.overhealing)
    if overhealing ~= nil then return math.max(0, amount - overhealing) end
    -- Older Rivals records predate overheal retention. Their stored amount is
    -- still the best evidence available, so keep it rather than dropping the
    -- recovery entirely.
    return math.max(0, amount)
end

local function CombatAbilityName(entry)
    if not entry then return "Unknown" end
    if entry.event == "SWING_DAMAGE" then return "Melee" end
    if type(entry.spellName) == "string" and entry.spellName ~= "" then return entry.spellName end
    if tonumber(entry.spellID) then return "Spell " .. tostring(entry.spellID) end
    return "Unknown"
end

local function RecordIdentity(record, guid, fallback)
    local session = record and record.session
    local identity = session and session.participants and session.participants[guid]
    if identity then return identity end
    for _, enemy in ipairs(record and record.enemies or {}) do
        if enemy.guid == guid then return enemy end
    end
    for _, friendly in ipairs(record and record.friendlies or {}) do
        if friendly.guid == guid then return friendly end
    end
    return {guid = guid, name = fallback or "Unknown"}
end

local function AddExchangeAmount(bucket, guid, name, class, amount, ability, critical)
    if not guid or not amount or amount <= 0 then return end
    local row = bucket[guid]
    if not row then
        row = {guid = guid, name = ShortName(name or "Unknown"), class = class, total = 0, abilities = {},
            isNPC = IsNPCCombatGUID(guid)}
        bucket[guid] = row
    end
    row.total = (row.total or 0) + amount
    ability = ability or "Unknown"
    if critical == true then ability = ability .. " (Critical)" end
    row.abilities[ability] = (row.abilities[ability] or 0) + amount
end

local function RecoveryAbilityDisplayName(ability, critical)
    ability = tostring(ability or "Healing")
    if ability == "Holy Strength" then ability = "Holy Strength (Crusader)" end
    if critical == true then ability = ability .. " (Critical)" end
    return ability
end

local function AddRecoveryAmount(bucket, targetGUID, targetName, targetClass, sourceGUID, sourceName, sourceClass,
    effectiveAmount, ability, rawAmount, overhealing, critical)
    if not targetGUID or not effectiveAmount or effectiveAmount <= 0 then return end
    local target = bucket[targetGUID]
    if not target then
        target = {guid = targetGUID, name = ShortName(targetName or "Unknown"), class = targetClass,
            total = 0, rawTotal = 0, overhealing = 0, overhealKnown = false, entries = {}}
        bucket[targetGUID] = target
    end
    rawAmount = math.max(effectiveAmount, tonumber(rawAmount) or effectiveAmount)
    local knownOverheal = tonumber(overhealing)
    if knownOverheal ~= nil then knownOverheal = math.max(0, knownOverheal) end
    target.total = target.total + effectiveAmount
    target.rawTotal = (target.rawTotal or 0) + rawAmount
    if knownOverheal ~= nil then
        target.overhealing = (target.overhealing or 0) + knownOverheal
        target.overhealKnown = true
    end

    local displayAbility = RecoveryAbilityDisplayName(ability, critical)
    local key = tostring(sourceGUID or sourceName or "Unknown") .. "\031" .. tostring(displayAbility or "Healing")
    local row = target.entries[key]
    if not row then
        row = {sourceGUID = sourceGUID, sourceName = ShortName(sourceName or "Unknown"), sourceClass = sourceClass,
            ability = displayAbility or "Healing", total = 0, rawTotal = 0, overhealing = 0,
            overhealKnown = false, count = 0}
        target.entries[key] = row
    end
    row.total = row.total + effectiveAmount
    row.rawTotal = (row.rawTotal or 0) + rawAmount
    if knownOverheal ~= nil then
        row.overhealing = (row.overhealing or 0) + knownOverheal
        row.overhealKnown = true
    end
    row.count = (row.count or 0) + 1
end

local function EscapeLuaPattern(text)
    return (tostring(text or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function SameCombatant(entryGUID, entryName, guid, name)
    if entryGUID and guid and entryGUID == guid then return true end
    local a = ShortName(entryName)
    local b = ShortName(name)
    return a and b and a ~= "Unknown" and b ~= "Unknown" and a == b
end

local function LegacyLogDamage(entry, sourceName, destName)
    if type(entry) ~= "table" or tonumber(entry.amount) then return nil end
    local text = tostring(entry.text or "")
    if text == "" or not sourceName or not destName then return nil end
    local src, dst = EscapeLuaPattern(ShortName(sourceName)), EscapeLuaPattern(ShortName(destName))
    local amount = text:match("^" .. src .. " hit " .. dst .. " for (%d+)")
    if amount then return tonumber(amount), "Melee" end
    local ability, spellAmount = text:match("^" .. src .. "'s (.-) hit " .. dst .. " for (%d+)")
    if spellAmount then return tonumber(spellAmount), ability end
    return nil
end

local function LegacyLogHealing(entry, sourceName, destName)
    if type(entry) ~= "table" or tonumber(entry.amount) then return nil end
    local text = tostring(entry.text or "")
    if text == "" or not sourceName or not destName then return nil end
    local src, dst = EscapeLuaPattern(ShortName(sourceName)), EscapeLuaPattern(ShortName(destName))
    local ability, amount = text:match("^" .. src .. "'s (.-) healed " .. dst .. " for (%d+)")
    if amount then return tonumber(amount), ability end
    return nil
end

local function BuildDamageExchange(record)
    local result = {
        dealt = 0, taken = 0, enemyRecovery = 0, playerRecovery = 0,
        enemyOverhealing = 0, playerOverhealing = 0,
        outgoing = {}, incoming = {}, enemyRecoveryByTarget = {}, playerRecoveryByTarget = {},
    }
    if not record then return result end
    local playerGUID, playerName = record.playerGUID, record.playerName or "You"
    local enemyByGUID, enemyByName = {}, {}
    for _, enemy in ipairs(record.enemies or {}) do
        if enemy.guid then enemyByGUID[enemy.guid] = enemy end
        if enemy.name then enemyByName[ShortName(enemy.name)] = enemy end
    end

    local log = record.session and record.session.worldCombatLog or {}
    for _, entry in ipairs(log) do
        local event = entry.event
        if IsDamageExchangeEvent(event) then
            local amount = math.max(0, tonumber(entry.amount) or 0)
            local sourceIsPlayer = SameCombatant(entry.sourceGUID, entry.sourceName, playerGUID, playerName)
            local destIsPlayer = SameCombatant(entry.destGUID, entry.destName, playerGUID, playerName)
            local target = enemyByGUID[entry.destGUID] or enemyByName[ShortName(entry.destName)]
            local source = enemyByGUID[entry.sourceGUID] or enemyByName[ShortName(entry.sourceName)]

            if amount <= 0 and sourceIsPlayer and target then
                amount = LegacyLogDamage(entry, playerName, target.name) or 0
            elseif amount <= 0 and destIsPlayer and source then
                amount = LegacyLogDamage(entry, source.name, playerName) or 0
            end

            if amount > 0 and sourceIsPlayer and target then
                result.dealt = result.dealt + amount
                local _, legacyAbility = LegacyLogDamage(entry, playerName, target.name)
                AddExchangeAmount(result.outgoing, target.guid or entry.destGUID or target.name,
                    target.name or entry.destName, target.class, amount, legacyAbility or CombatAbilityName(entry), entry.critical)
            elseif amount > 0 and destIsPlayer and not sourceIsPlayer then
                local identity = source or (IsNPCCombatGUID(entry.sourceGUID) and RecordIdentity(record, entry.sourceGUID, entry.sourceName))
                if identity then
                    result.taken = result.taken + amount
                    local _, legacyAbility = LegacyLogDamage(entry, identity.name or entry.sourceName, playerName)
                    AddExchangeAmount(result.incoming, identity.guid or entry.sourceGUID or identity.name,
                        identity.name or entry.sourceName, identity.class, amount, legacyAbility or CombatAbilityName(entry), entry.critical)
                end
            end
        elseif IsHealingExchangeEvent(event) then
            local amount = EffectiveHealingAmount(entry)
            local destIsPlayer = SameCombatant(entry.destGUID, entry.destName, playerGUID, playerName)
            local target = enemyByGUID[entry.destGUID] or enemyByName[ShortName(entry.destName)]
            if amount <= 0 and destIsPlayer then
                amount = LegacyLogHealing(entry, entry.sourceName or playerName, playerName) or 0
            elseif amount <= 0 and target then
                amount = LegacyLogHealing(entry, entry.sourceName or target.name, target.name) or 0
            end
            if amount > 0 and destIsPlayer then
                local sourceIdentity = RecordIdentity(record, entry.sourceGUID, entry.sourceName)
                local playerIdentity = RecordIdentity(record, playerGUID, playerName)
                local rawAmount = math.max(amount, tonumber(entry.amount) or amount)
                local overhealing = tonumber(entry.overhealing)
                result.playerRecovery = result.playerRecovery + amount
                if overhealing ~= nil then result.playerOverhealing = result.playerOverhealing + math.max(0, overhealing) end
                AddRecoveryAmount(result.playerRecoveryByTarget, playerGUID or playerName, playerIdentity.name or playerName,
                    playerIdentity.class or record.playerClass, entry.sourceGUID, sourceIdentity.name or entry.sourceName,
                    sourceIdentity.class, amount, CombatAbilityName(entry), rawAmount, overhealing, entry.critical)
            elseif amount > 0 and target then
                local sourceIdentity = RecordIdentity(record, entry.sourceGUID, entry.sourceName)
                local rawAmount = math.max(amount, tonumber(entry.amount) or amount)
                local overhealing = tonumber(entry.overhealing)
                result.enemyRecovery = result.enemyRecovery + amount
                if overhealing ~= nil then result.enemyOverhealing = result.enemyOverhealing + math.max(0, overhealing) end
                AddRecoveryAmount(result.enemyRecoveryByTarget, target.guid or entry.destGUID or target.name, target.name or entry.destName,
                    target.class, entry.sourceGUID, sourceIdentity.name or entry.sourceName, sourceIdentity.class,
                    amount, CombatAbilityName(entry), rawAmount, overhealing, entry.critical)
            end
        end
    end

    -- Some early World PvP records retained aggregate player->enemy damage on
    -- the opponent object even when their combat-log rows were text-only or
    -- truncated. Use that aggregate only when no outgoing damage could otherwise
    -- be reconstructed; never stack it on top of a real log total.
    if result.dealt <= 0 then
        for _, enemy in ipairs(record.enemies or {}) do
            local amount = math.max(0, tonumber(enemy.damageFromPlayer) or 0)
            if amount > 0 then
                result.dealt = result.dealt + amount
                AddExchangeAmount(result.outgoing, enemy.guid or enemy.name, enemy.name, enemy.class, amount, "Recorded damage")
            end
        end
    end
    return result
end

local function SortedExchangeRows(bucket)
    local rows = {}
    for _, row in pairs(bucket or {}) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b)
        if (a.total or 0) ~= (b.total or 0) then return (a.total or 0) > (b.total or 0) end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    return rows
end

local function SortedAbilityRows(bucket)
    local rows = {}
    for name, amount in pairs(bucket or {}) do rows[#rows + 1] = {name = name, total = amount} end
    table.sort(rows, function(a, b)
        if (a.total or 0) ~= (b.total or 0) then return (a.total or 0) > (b.total or 0) end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    return rows
end

local function SortedRecoveryEntries(entries)
    local rows = {}
    for _, row in pairs(entries or {}) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b)
        if (a.total or 0) ~= (b.total or 0) then return (a.total or 0) > (b.total or 0) end
        return tostring(a.ability or "") < tostring(b.ability or "")
    end)
    return rows
end

local function CompactCombatNumber(value)
    value = math.max(0, tonumber(value) or 0)
    if value >= 1000000 then
        local text = string.format("%.1fm", value / 1000000)
        return text:gsub("%.0m$", "m")
    elseif value >= 1000 then
        local text = string.format("%.1fk", value / 1000)
        return text:gsub("%.0k$", "k")
    end
    return tostring(math.floor(value + .5))
end

local function ExchangeDisplayName(row)
    if not row then return "Unknown" end
    if row.class then return DP.Theme.ClassName(ShortName(row.name), row.class) end
    return ShortName(row.name or "Unknown")
end

local DAMAGE_TIP_MARGIN = 10

local function EnsureDamageExchangeTooltip(window)
    if window.damageExchangeTooltip then return window.damageExchangeTooltip end
    local tip = CreateFrame("Frame", nil, window, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if tip.SetFrameStrata then tip:SetFrameStrata("TOOLTIP") end
    if tip.SetFrameLevel and window.GetFrameLevel then tip:SetFrameLevel(window:GetFrameLevel() + 31) end
    tip.opaqueBg = tip:CreateTexture(nil, "BACKGROUND")
    tip.opaqueBg:SetPoint("TOPLEFT", 3, -3); tip.opaqueBg:SetPoint("BOTTOMRIGHT", -3, 3)
    tip.opaqueBg:SetColorTexture(0, 0, 0, 1)
    if tip.SetBackdrop then
        tip:SetBackdrop(TOOLTIP_BACKDROP); tip:SetBackdropColor(0, 0, 0, 1); tip:SetBackdropBorderColor(.78, .78, .78, 1)
    end
    tip.title = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    tip.title:SetPoint("TOPLEFT", DAMAGE_TIP_MARGIN, -8); tip.title:SetJustifyH("LEFT")
    tip.rows = {}
    tip:Hide(); window.damageExchangeTooltip = tip
    return tip
end

local function EnsureDamageTipRow(tip, index)
    local row = tip.rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, tip); row:SetHeight(18)
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.left:SetPoint("LEFT", 7, 0); row.left:SetJustifyH("LEFT"); row.left:SetWordWrap(false)
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT", -7, 0); row.right:SetJustifyH("RIGHT"); row.right:SetWordWrap(false)
    tip.rows[index] = row
    return row
end

local function BuildDamageTooltipRows(record, exchange, mode)
    local gross = mode == "dealt" and exchange.dealt or exchange.taken
    local recovery = mode == "dealt" and exchange.enemyRecovery or exchange.playerRecovery
    local overhealing = mode == "dealt" and exchange.enemyOverhealing or exchange.playerOverhealing
    local net = math.max(0, gross - recovery)
    local detailBucket = mode == "dealt" and exchange.outgoing or exchange.incoming
    local recoveryBucket = mode == "dealt" and exchange.enemyRecoveryByTarget or exchange.playerRecoveryByTarget
    local rows = {}
    local function Add(left, right, kind, extra)
        rows[#rows + 1] = {left=left, right=right, kind=kind, extra=extra}
    end

    if recovery > 0 then Add("Effective recovery", CompactCombatNumber(recovery), "recoveryStat") end
    if overhealing > 0 then Add("Overhealing", CompactCombatNumber(overhealing), "overhealStat") end
    if recovery > 0 then Add("Net pressure", CompactCombatNumber(net), "net") end

    local actors = SortedExchangeRows(detailBucket)
    if #actors > 0 then
        Add(mode == "dealt" and "BY TARGET" or "BY SOURCE", "", "section")
        local npcTotal, npcCount, npcByName = 0, 0, {}
        local playerActors = {}
        for _, actor in ipairs(actors) do
            if actor.isNPC then
                npcTotal = npcTotal + (actor.total or 0)
                npcCount = npcCount + 1
                local name = ShortName(actor.name or "NPC")
                local key = string.lower(name)
                local grouped = npcByName[key]
                if not grouped then grouped = {name=name, total=0, count=0}; npcByName[key] = grouped end
                grouped.total = grouped.total + (actor.total or 0)
                grouped.count = grouped.count + 1
            else
                playerActors[#playerActors + 1] = actor
            end
        end
        for _, actor in ipairs(playerActors) do
            Add(ExchangeDisplayName(actor), CommaNumber(actor.total or 0), "actor")
            for _, ability in ipairs(SortedAbilityRows(actor.abilities)) do
                Add("   " .. tostring(ability.name), CommaNumber(ability.total or 0), "damageDetail")
            end
        end
        if npcTotal > 0 then
            Add("NPC interference" .. (npcCount > 1 and (" • " .. tostring(npcCount) .. " NPCs") or ""), CommaNumber(npcTotal), "npcActor")
            local npcRows = {}
            for _, npc in pairs(npcByName) do npcRows[#npcRows + 1] = npc end
            table.sort(npcRows, function(a, b)
                if (a.total or 0) ~= (b.total or 0) then return (a.total or 0) > (b.total or 0) end
                return tostring(a.name or "") < tostring(b.name or "")
            end)
            for _, npc in ipairs(npcRows) do
                local label = "   " .. tostring(npc.name or "NPC") .. ((npc.count or 0) > 1 and (" ×" .. tostring(npc.count)) or "")
                Add(label, CommaNumber(npc.total or 0), "damageDetail")
            end
        end
    end

    local recoveryTargets = SortedExchangeRows(recoveryBucket)
    if #recoveryTargets > 0 then
        Add(mode == "dealt" and "RECOVERY BY OPPONENT" or "YOUR RECOVERY", "", "section")
        for _, target in ipairs(recoveryTargets) do
            if mode == "dealt" then Add(ExchangeDisplayName(target), CommaNumber(target.total or 0), "recoveryActor") end
            for _, heal in ipairs(SortedRecoveryEntries(target.entries)) do
                local label = tostring(heal.ability or "Healing")
                if (heal.count or 0) > 1 then label = label .. " ×" .. tostring(heal.count) end
                local targetName = ShortName(target.name)
                local sourceName = ShortName(heal.sourceName)
                if sourceName and sourceName ~= "Unknown" and targetName and sourceName ~= targetName then
                    label = sourceName .. " • " .. label
                end
                local value = CommaNumber(heal.total or 0)
                if heal.overhealKnown and (heal.overhealing or 0) > 0 then
                    value = value .. "  +" .. CommaNumber(heal.overhealing or 0) .. " OH"
                end
                Add("   " .. label, value, "recoveryDetail", {overhealing=heal.overhealing or 0})
            end
        end
    end
    return gross, rows
end

local function DamageTooltipSharedWidth(tip, record, exchange)
    local measureLeft = tip.measureLeft or tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local measureRight = tip.measureRight or tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local measureTitle = tip.measureTitle or tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    tip.measureLeft, tip.measureRight, tip.measureTitle = measureLeft, measureRight, measureTitle
    measureLeft:Hide(); measureRight:Hide(); measureTitle:Hide()
    local maxLeft, maxRight, maxTitle = 125, 65, 0
    for _, mode in ipairs({"dealt", "taken"}) do
        local gross, rows = BuildDamageTooltipRows(record, exchange, mode)
        local title = (mode == "dealt" and "Damage Dealt" or "Damage Taken") .. "  " .. CommaNumber(gross)
        maxTitle = math.max(maxTitle, MeasureTextWidth(measureTitle, title))
        for _, data in ipairs(rows) do
            maxLeft = math.max(maxLeft, MeasureTextWidth(measureLeft, data.left))
            maxRight = math.max(maxRight, MeasureTextWidth(measureRight, data.right))
        end
    end
    local screenWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1200
    local contentWidth = math.max(maxTitle + DAMAGE_TIP_MARGIN * 2 + 8, maxLeft + maxRight + 48)
    return math.min(math.max(286, contentWidth), math.max(286, screenWidth - 16)), maxRight
end

local function PopulateDamageExchangeTooltip(owner, record, mode)
    local window = W.details
    if not owner or not record or not window then return end
    local tip = EnsureDamageExchangeTooltip(window)
    if tip.SetClampedToScreen then tip:SetClampedToScreen(true) end
    for _, row in ipairs(tip.rows) do row:Hide() end
    local exchange = BuildDamageExchange(record)
    local gross, rows = BuildDamageTooltipRows(record, exchange, mode)

    tip.title:SetText((mode == "dealt" and "Damage Dealt" or "Damage Taken") .. "  " .. CommaNumber(gross))
    if mode == "dealt" then
        tip.title:SetTextColor(1, .82, .42)
    else
        tip.title:SetTextColor(1, .34, .32)
    end

    local width, maxRight = DamageTooltipSharedWidth(tip, record, exchange)
    tip:SetWidth(width); tip.title:SetWidth(width - DAMAGE_TIP_MARGIN * 2)
    local rightWidth = math.max(78, maxRight + 4)
    local y, stripe = 29, 0
    for index, data in ipairs(rows) do
        local row = EnsureDamageTipRow(tip, index)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", DAMAGE_TIP_MARGIN, -y); row:SetWidth(width - DAMAGE_TIP_MARGIN * 2)
        row.left:SetWidth(width - rightWidth - 26); row.right:SetWidth(rightWidth)
        if data.kind == "section" then
            y = y + 3; row:ClearAllPoints(); row:SetPoint("TOPLEFT", DAMAGE_TIP_MARGIN, -y)
            row:SetHeight(18); row.bg:SetColorTexture(.08, .065, .03, 1)
            row.left:SetText("|cffffd15c" .. data.left .. "|r"); row.right:SetText("")
        elseif data.kind == "actor" then
            row:SetHeight(18); row.bg:SetColorTexture(.055, .055, .055, 1)
            local valueColor = mode == "dealt" and "|cffffd15c" or "|cffff5a52"
            row.left:SetText(data.left); row.right:SetText(valueColor .. data.right .. "|r")
        elseif data.kind == "npcActor" then
            row:SetHeight(18); row.bg:SetColorTexture(.075, .055, .035, 1)
            row.left:SetText("|cffffad66" .. data.left .. "|r")
            row.right:SetText((mode == "dealt" and "|cffffd15c" or "|cffff5a52") .. data.right .. "|r")
        elseif data.kind == "recoveryActor" then
            row:SetHeight(18); row.bg:SetColorTexture(.04, .07, .05, 1)
            row.left:SetText(data.left); row.right:SetText("|cff65e6ad" .. data.right .. "|r")
        elseif data.kind == "recoveryStat" then
            row:SetHeight(18); row.bg:SetColorTexture(.035, .06, .045, 1)
            row.left:SetText("|cff9aa3ad" .. data.left .. "|r"); row.right:SetText("|cff65e6ad" .. data.right .. "|r")
        elseif data.kind == "overhealStat" then
            row:SetHeight(17); row.bg:SetColorTexture(.03, .03, .03, 1)
            row.left:SetText("|cff8f969f" .. data.left .. "|r"); row.right:SetText("|cff8f969f" .. data.right .. "|r")
        elseif data.kind == "recoveryDetail" then
            stripe = stripe + 1; row:SetHeight(17); row.bg:SetColorTexture(.02, .05, .03, 1)
            row.left:SetText(data.left)
            if data.extra and (data.extra.overhealing or 0) > 0 then
                local effective, oh = data.right:match("^(.-)%s+%+(.-)%s+OH$")
                if effective then
                    row.right:SetText("|cff65e6ad" .. effective .. "|r  |cff8f969f+" .. oh .. " OH|r")
                else row.right:SetText("|cff65e6ad" .. data.right .. "|r") end
            else
                row.right:SetText("|cff65e6ad" .. data.right .. "|r")
            end
        elseif data.kind == "net" then
            row:SetHeight(19); row.bg:SetColorTexture(.07, .07, .07, 1)
            row.left:SetText("|cffffffff" .. data.left .. "|r")
            row.right:SetText(mode == "dealt" and ("|cffffd15c" .. data.right .. "|r") or ("|cffff5a52" .. data.right .. "|r"))
        else
            stripe = stripe + 1; row:SetHeight(17)
            local shade = stripe % 2 == 0 and .045 or .025
            row.bg:SetColorTexture(shade, shade, shade, 1)
            row.left:SetText(data.left)
            row.right:SetText((mode == "dealt" and "|cffffd15c" or "|cffff5a52") .. data.right .. "|r")
        end
        row:Show(); y = y + row:GetHeight()
    end
    local tipHeight = y + 8
    tip:SetHeight(tipHeight)

    tip:ClearAllPoints()
    local screenWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1200
    local screenHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
    local ownerLeft = owner.GetLeft and owner:GetLeft() or 0
    local ownerRight = owner.GetRight and owner:GetRight() or 0
    local ownerBottom = owner.GetBottom and owner:GetBottom() or (screenHeight * .5)
    local x
    if ownerRight + width + 6 <= screenWidth - 8 then x = ownerRight + 4
    else x = math.max(8, ownerLeft - width - 4) end
    x = math.max(8, math.min(x, math.max(8, screenWidth - width - 8)))
    local bottomY = math.max(8, math.min(ownerBottom - 2, math.max(8, screenHeight - tipHeight - 8)))
    tip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, bottomY)
    tip:Show()
end

local function ShowDamageExchangeTooltip(owner, record, mode)
    PopulateDamageExchangeTooltip(owner, record, mode)
end

local function EncounterNPCs(record)
    local npcs, enemyByGUID = {}, {}
    for _, enemy in ipairs(record and record.enemies or {}) do enemyByGUID[enemy.guid] = true end
    local playerGUID = record and record.playerGUID
    local function NPC(guid, name)
        if not IsNPCCombatGUID(guid) then return nil end
        local row = npcs[guid]
        if not row then
            row = {guid = guid, name = ShortName(name or "Unknown NPC"), damageToPlayer = 0, damageToEnemies = 0,
                damageFromPlayer = 0, healingToPlayer = 0, healingToEnemies = 0, events = 0}
            npcs[guid] = row
        end
        return row
    end
    for _, entry in ipairs(record and record.session and record.session.worldCombatLog or {}) do
        local amount = tonumber(entry.amount) or 0
        if IsDamageExchangeEvent(entry.event) then
            local sourceNPC = NPC(entry.sourceGUID, entry.sourceName)
            local destNPC = NPC(entry.destGUID, entry.destName)
            if sourceNPC then
                sourceNPC.events = sourceNPC.events + 1
                if entry.destGUID == playerGUID then sourceNPC.damageToPlayer = sourceNPC.damageToPlayer + amount
                elseif enemyByGUID[entry.destGUID] then sourceNPC.damageToEnemies = sourceNPC.damageToEnemies + amount end
            end
            if destNPC and entry.sourceGUID == playerGUID then
                destNPC.events = destNPC.events + 1
                destNPC.damageFromPlayer = destNPC.damageFromPlayer + amount
            end
        elseif IsHealingExchangeEvent(entry.event) then
            local sourceNPC = NPC(entry.sourceGUID, entry.sourceName)
            if sourceNPC then
                local effective = EffectiveHealingAmount(entry)
                sourceNPC.events = sourceNPC.events + 1
                if entry.destGUID == playerGUID then sourceNPC.healingToPlayer = sourceNPC.healingToPlayer + effective
                elseif enemyByGUID[entry.destGUID] then sourceNPC.healingToEnemies = sourceNPC.healingToEnemies + effective end
            end
        end
    end

    -- Multiple creatures with the same visible name are one encounter-context
    -- concept to the user. Merge them into one plaque and preserve the count.
    local grouped = {}
    for _, npc in pairs(npcs) do
        if npc.events > 0 and (npc.damageToPlayer > 0 or npc.damageToEnemies > 0 or npc.damageFromPlayer > 0 or npc.healingToPlayer > 0 or npc.healingToEnemies > 0) then
            local name = ShortName(npc.name or "Unknown NPC")
            local key = string.lower(name)
            local row = grouped[key]
            if not row then
                row = {name=name, count=0, damageToPlayer=0, damageToEnemies=0, damageFromPlayer=0,
                    healingToPlayer=0, healingToEnemies=0, events=0}
                grouped[key] = row
            end
            row.count = row.count + 1
            row.events = row.events + (npc.events or 0)
            row.damageToPlayer = row.damageToPlayer + (npc.damageToPlayer or 0)
            row.damageToEnemies = row.damageToEnemies + (npc.damageToEnemies or 0)
            row.damageFromPlayer = row.damageFromPlayer + (npc.damageFromPlayer or 0)
            row.healingToPlayer = row.healingToPlayer + (npc.healingToPlayer or 0)
            row.healingToEnemies = row.healingToEnemies + (npc.healingToEnemies or 0)
        end
    end

    local rows = {}
    for _, npc in pairs(grouped) do rows[#rows + 1] = npc end
    table.sort(rows, function(a, b)
        local av = (a.damageToPlayer or 0) + (a.damageToEnemies or 0) + (a.damageFromPlayer or 0) + (a.healingToPlayer or 0) + (a.healingToEnemies or 0)
        local bv = (b.damageToPlayer or 0) + (b.damageToEnemies or 0) + (b.damageFromPlayer or 0) + (b.healingToPlayer or 0) + (b.healingToEnemies or 0)
        if av ~= bv then return av > bv end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    return rows
end

local function AddNPCRecordTooltip(npc)
    if not npc then return end
    local npcTitle = tostring(npc.name or "NPC") .. (((npc.count or 0) > 1) and (" ×" .. tostring(npc.count)) or "")
    GameTooltip:SetText(npcTitle, 1, .68, .4)
    GameTooltip:AddLine("NPC PARTICIPATION", 1, .82, .42)
    if (npc.damageToPlayer or 0) > 0 then GameTooltip:AddDoubleLine("Damage to you", CommaNumber(npc.damageToPlayer), .75, .78, .84, 1, .45, .45) end
    if (npc.damageToEnemies or 0) > 0 then GameTooltip:AddDoubleLine("Damage to enemy players", CommaNumber(npc.damageToEnemies), .75, .78, .84, .4, .9, .68) end
    if (npc.damageFromPlayer or 0) > 0 then GameTooltip:AddDoubleLine("Damage from you", CommaNumber(npc.damageFromPlayer), .75, .78, .84, 1, .82, .42) end
    if (npc.healingToPlayer or 0) > 0 then GameTooltip:AddDoubleLine("Healing to you", CommaNumber(npc.healingToPlayer), .75, .78, .84, .4, .9, .68) end
    if (npc.healingToEnemies or 0) > 0 then GameTooltip:AddDoubleLine("Healing to enemy players", CommaNumber(npc.healingToEnemies), .75, .78, .84, .4, .9, .68) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Encounter context • excluded from NvN", .55, .6, .68, true)
end

W.BuildDamageExchange = BuildDamageExchange
W.EncounterNPCs = EncounterNPCs

local function AddTooltipEnemyList(record, predicate, emptyText)
    local added = 0
    for _, enemy in ipairs(record.enemies or {}) do
        if not predicate or predicate(enemy) then
            local state = enemy.died and "Killed" or "Survived"
            local suffix = enemy.killingBlow and "  |cffffce70KB|r" or ""
            GameTooltip:AddDoubleLine(DP.Theme.ClassName(ShortName(enemy.name), enemy.class), state .. suffix,
                1, 1, 1, enemy.died and 1 or .4, enemy.died and .45 or .9, enemy.died and .45 or .68)
            added = added + 1
            if added >= 7 then break end
        end
    end
    if added == 0 and emptyText then GameTooltip:AddLine(emptyText, .65, .7, .76, true) end
end

local function DetailEncounterLabel(record)
    local friendly = math.max(1, record.friendlyCount or 1)
    local hostile = math.max(1, record.peakContestingEnemies or 0, record.contestingEnemyCount or 0, record.enemyCount or 0)
    if friendly == 1 then return "Solo 1v" .. tostring(hostile) end
    return tostring(friendly) .. "v" .. tostring(hostile)
end

function W.EncounterCombatantLevel(level, playerLevel)
    level, playerLevel = tonumber(level), tonumber(playerLevel)
    if not level or level <= 0 then return "|cffadb5c2Lv ??|r" end
    local color = "ffadb5c2"
    if playerLevel and playerLevel > 0 then
        local delta = level - playerLevel
        -- Classic gray-level boundary, using the encounter's recorded player
        -- level so leveling later cannot change the meaning of old encounters.
        local gray = playerLevel <= 5 and 0 or playerLevel <= 39 and
            (playerLevel - math.floor(playerLevel / 10) - 5) or
            (playerLevel - math.floor(playerLevel / 5) - 1)
        color = delta >= 5 and "ffff2020" or delta >= 3 and "ffff8040" or
            delta >= -2 and "ffffff00" or level > gray and "ff40c040" or "ff808080"
    end
    return "|c" .. color .. "Lv " .. tostring(level) .. "|r"
end

function W.AddEncounterCombatantsTooltip(record)
    local evidence, deaths = {}, {}
    for _, entry in ipairs(record.session and record.session.worldCombatLog or {}) do
        local key = entry.destGUID or entry.destName
        if key and (entry.event == "UNIT_DIED" or entry.event == "UNIT_DESTROYED" or entry.event == "PARTY_KILL") and
                not entry.unconscious and not (entry.text and entry.text:find("became unconscious", 1, true)) then
            deaths[key] = true
        end
        if entry.sourceGUID and type(entry.spellName) == "string" then
            local seen = evidence[entry.sourceGUID] or {}
            evidence[entry.sourceGUID] = seen
            seen[string.lower(entry.spellName)] = true
        end
    end
    local player
    for _, friendly in ipairs(record.friendlies or {}) do
        if SameCombatant(friendly.guid, friendly.name, record.playerGUID, record.playerName) then player = friendly; break end
    end
    player = player or {guid=record.playerGUID, name=record.playerName or "You", class=record.playerClass}
    local function Add(combatant, isPlayer)
        local class = combatant.class or (isPlayer and record.playerClass)
        local spec = type(combatant.spec) == "table" and combatant.spec.label or
            type(combatant.spec) == "string" and combatant.spec or nil
        if not spec and DP.Specs and DP.Specs.InferCombat and evidence[combatant.guid] then
            spec = DP.Specs.InferCombat(class, evidence[combatant.guid])
        end
        local name = DP.Theme.ClassName(ShortName(combatant.name or "Unknown"), class)
        local died = combatant.died or deaths[combatant.guid or combatant.name] or (isPlayer and record.playerDied)
        local status = died and "|cffff8888Died|r" or "|cff65e6adSurvived|r"
        local specText = type(spec) == "string" and spec ~= "" and ("|cffadb5c2" .. spec .. "|r  ") or ""
        -- Put the inferred/known spec before the outcome so every green/red
        -- Survived/Died label terminates at the same right edge.
        GameTooltip:AddDoubleLine(name, specText .. status, 1, 1, 1, 1, 1, 1)
    end
    Add(player, true)
    local seen = {}
    if player.guid then seen[player.guid] = true end
    for _, friendly in ipairs(record.friendlies or {}) do
        if friendly ~= player and not SameCombatant(friendly.guid, friendly.name, record.playerGUID, record.playerName) and
                not seen[friendly.guid or friendly.name] then
            Add(friendly, false)
            if friendly.guid or friendly.name then seen[friendly.guid or friendly.name] = true end
        end
    end
    GameTooltip:AddLine("vs.", .65, .7, .76)
    GameTooltip:AddLine(#(record.enemies or {}) == 1 and "OPPONENT" or "OPPONENTS", 1, .45, .45)
    for _, enemy in ipairs(record.enemies or {}) do Add(enemy, false) end
    if not record.enemies or #record.enemies == 0 then GameTooltip:AddLine("No combatant details retained", .65, .7, .76) end
end

local function FriendlyEndReason(reason)
    local labels = {
        ["combat-ended"] = "Combat ended",
        ["player-death"] = "Player death",
        ["all-enemies-dead"] = "All tracked enemies dead",
        ["inactivity"] = "Combat-log inactivity timeout",
        ["new-opponent-after-combat"] = "New fight began after combat ended",
        ["world-change"] = "World/zone changed",
        ["duel-or-instance"] = "Duel or instance transition",
        ["tracking-disabled"] = "World PvP tracking disabled",
        ["logout"] = "Logout",
    }
    return labels[reason] or reason
end

local function AddEncounterOpponentTooltip(enemy, record)
    if not enemy then return end
    local className = enemy.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[enemy.class]) or enemy.class) or "Unknown class"
    local level = enemy.level and ("Level " .. tostring(enemy.level)) or "Level unknown"
    GameTooltip:SetText(DP.Theme.ClassName(ShortName(enemy.name), enemy.class))
    GameTooltip:AddLine(level .. " " .. className .. (enemy.spec and enemy.spec.label and (" — " .. enemy.spec.label) or ""), .72, .76, .82)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("THIS ENCOUNTER", 1, .82, .42)
    local bubbleHearth = enemy.bubbleHearthed or (record and record.bubbleHearthEnemyGUID == enemy.guid)
    local state = bubbleHearth and "Escaped via Divine Shield + Hearthstone" or enemy.died and "Killed" or "Survived"
    if enemy.killingBlow then state = state .. " — your killing blow" end
    GameTooltip:AddLine(state, enemy.died and 1 or .4, enemy.died and .45 or .9, enemy.died and .45 or .68)
    if enemy.pressuredPlayer ~= nil then
        GameTooltip:AddLine(enemy.pressuredPlayer and "Directly pressured you" or "No direct pressure on you observed", .72, .76, .82)
    end
    local fight = OpponentFightStats(record, enemy)
    if fight.damageToYou > 0 or fight.damageFromYou > 0 then
        GameTooltip:AddDoubleLine("Damage to you", tostring(math.floor(fight.damageToYou + .5)), .75, .78, .84, 1, .45, .45)
        GameTooltip:AddDoubleLine("Damage from you", tostring(math.floor(fight.damageFromYou + .5)), .75, .78, .84, .4, .9, .68)
    end
    if fight.healing > 0 then
        GameTooltip:AddDoubleLine("Healing observed", tostring(math.floor(fight.healing + .5)), .75, .78, .84, .4, .9, .68)
    end
    if fight.casts > 0 or fight.interrupts > 0 or fight.dispels > 0 then
        GameTooltip:AddLine(string.format("Observed: %d casts%s%s", fight.casts,
            fight.interrupts > 0 and (", " .. fight.interrupts .. " interrupt" .. (fight.interrupts == 1 and "" or "s")) or "",
            fight.dispels > 0 and (", " .. fight.dispels .. " dispel/steal" .. (fight.dispels == 1 and "" or "s")) or ""), .72, .76, .82)
    end
    local world, consumes = CountDetectedBuffs(enemy)
    if world > 0 or consumes > 0 then
        GameTooltip:AddLine(string.format("Detected buffs: %d world, %d consumable", world, consumes), .88, .78, .48)
    end
    if record and record.npcAssistance then GameTooltip:AddLine("NPC interference was detected in this encounter.", 1, .68, .4, true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Lifetime history is shown in Opponent Records.", .55, .6, .68, true)
end

local function AddOpponentRecordTooltip(enemy, stats, record)
    if not enemy then return end
    local className = enemy.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[enemy.class]) or enemy.class) or "Unknown class"
    local level = enemy.level and ("Level " .. tostring(enemy.level)) or "Level unknown"
    GameTooltip:SetText(DP.Theme.ClassName(ShortName(enemy.name), enemy.class))
    GameTooltip:AddLine(level .. " " .. className .. (enemy.spec and enemy.spec.label and (" — " .. enemy.spec.label) or ""), .72, .76, .82)
    stats = stats or OpponentStatsFor(enemy)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("YOUR RECORDED HISTORY", 1, .82, .42)
    if stats then
        GameTooltip:AddDoubleLine("World PvP", string.format("%d-%d", stats.kills or 0, stats.deaths or 0), .75, .78, .84, 1, 1, 1)
        GameTooltip:AddDoubleLine("Solo 1v1", string.format("%d-%d", stats.soloKills or 0, stats.soloDeaths or 0), .75, .78, .84, 1, 1, 1)
        GameTooltip:AddDoubleLine("Recorded encounters", tostring(stats.encounters or 0), .75, .78, .84, 1, .82, .42)
        if stats.lastAt and stats.lastAt > 0 then GameTooltip:AddLine("Last seen: " .. date("%m/%d %H:%M", stats.lastAt), .65, .7, .76) end
    else
        GameTooltip:AddLine("No prior matchup history was retained.", .65, .7, .76)
    end
end
local function FindKillingBlowDetail(record, enemy)
    if not record or not enemy then return nil end
    if type(enemy.killingBlowDetail) == "table" then return enemy.killingBlowDetail end
    local log = record.session and record.session.worldCombatLog or {}
    local fallback
    for i = #log, 1, -1 do
        local entry = log[i]
        if IsDamageExchangeEvent(entry.event) and
            SameCombatant(entry.sourceGUID, entry.sourceName, record.playerGUID, record.playerName) and
            SameCombatant(entry.destGUID, entry.destName, enemy.guid, enemy.name) then
            if tonumber(entry.overkill) and tonumber(entry.overkill) >= 0 then return entry end
            if not fallback and (not enemy.killedAt or not entry.t or math.abs((tonumber(enemy.killedAt) or 0) - (tonumber(entry.t) or 0)) <= 3) then
                fallback = entry
            end
        end
    end
    return fallback
end

local function AddKillingBlowTooltip(record)
    local found = 0
    for _, enemy in ipairs(record and record.enemies or {}) do
        if enemy.killingBlow then
            found = found + 1
            if found > 1 then GameTooltip:AddLine(" ") end
            GameTooltip:AddDoubleLine(DP.Theme.ClassName(ShortName(enemy.name), enemy.class), "|cffffce70KB|r", 1, 1, 1, 1, .82, .42)
            local detail = FindKillingBlowDetail(record, enemy)
            if detail then
                local ability = CombatAbilityName(detail)
                local damage = tonumber(detail.amount)
                local overkill = math.max(0, tonumber(detail.overkill) or 0)
                GameTooltip:AddDoubleLine(ability, damage and (CommaNumber(damage) .. " damage") or "", 1, .95, .75, 1, .82, .42)
                local hitLabel
                if detail.critical == true then hitLabel = "Critical hit"
                elseif detail.critical == false then hitLabel = "Hit" end
                if hitLabel or overkill > 0 then
                    GameTooltip:AddDoubleLine(hitLabel or "", overkill > 0 and (CommaNumber(overkill) .. " overkill") or "",
                        detail.critical == true and 1 or .78, detail.critical == true and .55 or .78, detail.critical == true and .2 or .78,
                        1, .42, .42)
                elseif detail.critical == nil then
                    GameTooltip:AddLine("Hit type not retained", .55, .6, .68)
                end
            else
                GameTooltip:AddLine("Lethal-hit details were not retained for this older encounter.", .55, .6, .68, true)
            end
        end
    end
    if found == 0 then GameTooltip:AddLine("No direct killing blows were recorded.", .65, .7, .76, true) end
end

W.FindKillingBlowDetail = FindKillingBlowDetail

local function BuffLevelColor(level)
    level = tonumber(level)
    if not level then return "ffadb5c2" end

    -- Prefer Blizzard's own con-color calculation so the selector reads the same
    -- way the unit's level would to the local player (equal level = yellow, etc.).
    local color
    if GetQuestDifficultyColor then
        color = GetQuestDifficultyColor(level)
    elseif GetCreatureDifficultyColor then
        color = GetCreatureDifficultyColor(level)
    end
    if color and color.r and color.g and color.b then
        local r = math.max(0, math.min(255, math.floor(color.r * 255 + .5)))
        local g = math.max(0, math.min(255, math.floor(color.g * 255 + .5)))
        local b = math.max(0, math.min(255, math.floor(color.b * 255 + .5)))
        return string.format("ff%02x%02x%02x", r, g, b)
    end

    -- Fallback for clients that do not expose the helper in this context.
    local playerLevel = UnitLevel and tonumber(UnitLevel("player")) or level
    local delta = level - playerLevel
    if delta >= 5 then return "ffff2020" end
    if delta >= 3 then return "ffff8040" end
    if delta >= -2 then return "ffffff00" end
    if delta >= -5 then return "ff40c040" end
    return "ff808080"
end

local function BuffSelectorEnemyParts(enemy)
    if not enemy then return "Opponent", "" end
    -- Older encounters may not have retained every identity field. Resolve what
    -- the client still knows so the selector can stay informative.
    if enemy.guid and GetPlayerInfoByGUID and (not enemy.class or not enemy.race) then
        local _, class, localizedRace, englishRace = GetPlayerInfoByGUID(enemy.guid)
        enemy.class = enemy.class or class
        enemy.race = enemy.race or localizedRace or englishRace
    end
    if not enemy.level and enemy.guid then enemy.level = ResolvePlayerLevel(enemy.guid) end

    local name = DP.Theme.ClassName(ShortName(enemy.name), enemy.class)
    local level = enemy.level and tostring(enemy.level) or "?"
    local race = tostring(enemy.race or "?")
    local levelColor = BuffLevelColor(enemy.level)
    return name, string.format("|c%s%s|r |cffadb5c2%s|r", levelColor, level, race)
end

local function DefaultHeaderBuffEnemy(record)
    local enemies = record and record.enemies or {}
    local primary = PrimaryOpponent(record)
    -- Prefer the fight's primary opponent when that player actually has retained
    -- buffs. If not, favor a buffed kill/death before any other buffed opponent so
    -- opening the detail pane shows useful aura data instead of an empty card.
    if primary and #SortedOpponentBuffs(primary) > 0 then return primary end
    local deadBuffed, anyBuffed
    for _, enemy in ipairs(enemies) do
        if #SortedOpponentBuffs(enemy) > 0 then
            if enemy.killingBlow then return enemy end
            if enemy.died and not deadBuffed then deadBuffed = enemy end
            anyBuffed = anyBuffed or enemy
        end
    end
    return deadBuffed or anyBuffed or primary or enemies[1]
end

local function SetSummaryCardHitArea(card, expanded)
    if not card or not card.SetHitRectInsets then return end
    -- The visible plaque no longer changes its bounds on hover, so there is no
    -- invisible expansion reserve to enter/leave.  A stable hit rectangle also
    -- eliminates the edge chatter that forced the old oversized hover area.
    card:SetHitRectInsets(-5, -5, -4, -4)
end

local SUMMARY_RIVAL_ROW_STEP = 56
local DETAIL_PAGE_HEIGHT = 480

local function EnsureDetails()
    if W.details then return W.details end
    local window = CreateFrame("Frame", "RivalsWorldPvPDetails", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    window:SetSize(650, 600); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG"); window:SetMovable(true); window:EnableMouse(true)
    if window.SetClampedToScreen then window:SetClampedToScreen(true) end
    window.bg = window:CreateTexture(nil, "BACKGROUND"); window.bg:SetPoint("TOPLEFT", 1, -1); window.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    window.bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock"); window.bg:SetVertexColor(.28, .30, .33, .97)
    local border = DP.Theme.Border(window, 0, 0, 650, 600); border:ClearAllPoints(); border:SetAllPoints(window); border:EnableMouse(false)
    local header = DP.Theme.PlaqueHeader(window, 360, "World PvP", "GameFontNormal")
    header:SetPoint("BOTTOM", window, "TOP", 0, -4); header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:StartMoving() end); header:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2); close:SetScript("OnClick", function() window:Hide() end)
    -- Preserve the selected detail tab only while the detail pane stays open.
    -- Moving directly from one encounter to another should keep the user's tab,
    -- but closing the pane starts the next detail view back on Summary.
    window:SetScript("OnHide", function(self)
        self.activeTab = "summary"
        self._portraitRecord = nil
        for _, card in ipairs(self.summaryRivalCards or {}) do
            if DP.Portraits and DP.Portraits.ReleaseBody then DP.Portraits.ReleaseBody(card) end
            card._portraitViewportActive = false
            card._portraitCommittedKey = nil
            card._portraitCommittedEnemy = nil
        end
    end)
    window.starButton = CreateFrame("Button", nil, window)
    window.starButton:SetSize(12, 12)
    window.starButton:SetPoint("TOPLEFT", 24, -50)
    window.starButton.icon = window.starButton:CreateTexture(nil, "OVERLAY")
    window.starButton.icon:SetPoint("CENTER")
    window.starButton.icon:SetSize(6, 6)
    window.starButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if W.IsStarred(window.record) then
            GameTooltip:SetText("Starred encounter")
            GameTooltip:AddLine("Retained beyond the 250 recent World PvP cap.", .85, .85, .85, true)
            GameTooltip:AddLine("Click to remove from the starred archive.", .55, .6, .68, true)
        else
            GameTooltip:SetText("Star this encounter")
            GameTooltip:AddLine("Retain this World PvP encounter even after it ages out of the recent 250.", .85, .85, .85, true)
        end
        GameTooltip:Show()
    end)
    window.starButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    window.starButton:SetScript("OnClick", function()
        if not window.record then return end
        W.SetStarred(window.record, not W.IsStarred(window.record))
        if W.RefreshDetailContent then W.RefreshDetailContent() end
    end)

    window.map = W.CreateMapThumbnail(window, 230, 142); window.map:SetPoint("TOPLEFT", 20, -34)
    window.starButton:ClearAllPoints(); window.starButton:SetPoint("TOPLEFT", window.map, "TOPLEFT", 8, -8)
    DP.Theme.Border(window.map, 0, 0, 230, 142)

    -- Treat the encounter header as three deliberate columns: map, result, and
    -- encounter intel. The subtle cards fill the old dead space without making
    -- the top of the window busier than the actual record below it.
    window.resultBox = CreateFrame("Frame", nil, window)
    window.resultBox:SetPoint("TOPLEFT", 260, -34); window.resultBox:SetSize(164, 142)
    window.resultBox.bg = window.resultBox:CreateTexture(nil, "BACKGROUND"); window.resultBox.bg:SetAllPoints(); window.resultBox.bg:SetColorTexture(.03, .036, .045, .58)
    DP.Theme.Border(window.resultBox, 0, 0, 164, 142)
    window.resultLabel = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); window.resultLabel:SetPoint("TOPLEFT", 10, -8); window.resultLabel:SetWidth(144); window.resultLabel:SetJustifyH("LEFT"); window.resultLabel:SetText("LOCATION")
    window.location = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); window.location:SetPoint("TOPLEFT", 10, -25); window.location:SetWidth(144); window.location:SetHeight(52); window.location:SetJustifyH("LEFT"); window.location:SetJustifyV("TOP"); window.location:SetWordWrap(true)
    window.resultRule = window.resultBox:CreateTexture(nil, "ARTWORK"); window.resultRule:SetColorTexture(.84, .56, .31, .22); window.resultRule:SetPoint("TOPLEFT", 10, -55); window.resultRule:SetSize(144, 1)
    window.locationLabel = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); window.locationLabel:SetPoint("TOPLEFT", 10, -63); window.locationLabel:SetWidth(144); window.locationLabel:SetJustifyH("LEFT"); window.locationLabel:SetText("ENCOUNTER")
    window.headcount = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.headcount:SetWidth(144); window.headcount:SetHeight(24); window.headcount:SetJustifyH("LEFT"); window.headcount:SetJustifyV("TOP"); window.headcount:SetWordWrap(false)
    window.outcome = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.outcome:SetWidth(144); window.outcome:SetHeight(30); window.outcome:SetJustifyH("LEFT"); window.outcome:SetJustifyV("TOP"); window.outcome:SetWordWrap(true)
    window.result = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); window.result:Hide()
    window.locationHover = CreateFrame("Frame", nil, window.resultBox); window.locationHover:SetPoint("TOPLEFT", 7, -21); window.locationHover:SetSize(150, 58)
    window.encounterHover = CreateFrame("Frame", nil, window.resultBox)
    DetailTooltip(window.encounterHover, "Encounter combatants", function(_, record)
        W.AddEncounterCombatantsTooltip(record)
    end)
    window.encounterHover:SetScript("OnHide", function(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)

    -- Opponent buffs replace the redundant top-right opponent list. The card is
    -- permanently aligned with ENCOUNTER. A compact selector lives in the BUFFS
    -- header only when a multi-enemy encounter has retained aura data; icons flow left-to-right beneath it.
    window.buffBox = CreateFrame("Frame", nil, window)
    window.buffBox:SetPoint("TOPLEFT", 434, -34); window.buffBox:SetSize(196, 142)
    window.buffBox.bg = window.buffBox:CreateTexture(nil, "BACKGROUND"); window.buffBox.bg:SetAllPoints(); window.buffBox.bg:SetColorTexture(.03, .036, .045, .58)
    window.buffBorder = DP.Theme.Border(window.buffBox, 0, 0, 196, 142)
    window.buffBorder:ClearAllPoints(); window.buffBorder:SetAllPoints(window.buffBox); window.buffBorder:EnableMouse(false)
    window.buffTitle = window.buffBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    window.buffTitle:SetPoint("TOPLEFT", 8, -8); window.buffTitle:SetWidth(180); window.buffTitle:SetJustifyH("LEFT"); window.buffTitle:SetText("ENEMY BUFFS")
    window.buffIcons = {}
    window.buffEmpty = window.buffBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.buffEmpty:SetPoint("CENTER", 0, -10); window.buffEmpty:SetWidth(180); window.buffEmpty:SetJustifyH("CENTER"); window.buffEmpty:SetText("No buffs observed")

    -- Buffs use a compact Rivals-owned scroll viewport. Two five-icon rows remain
    -- visible at the normal header height; larger aura sets scroll vertically using
    -- the same Blizzard track/thumb treatment as the OPPONENTS list.
    window.buffScroll = CreateFrame("ScrollFrame", nil, window.buffBox)
    window.buffScroll:SetPoint("TOPLEFT", 8, -29); window.buffScroll:SetPoint("BOTTOMRIGHT", -8, 8)
    if window.buffScroll.SetClipsChildren then window.buffScroll:SetClipsChildren(true) end
    window.buffBody = CreateFrame("Frame", nil, window.buffScroll)
    window.buffBody:SetSize(180, 105); window.buffScroll:SetScrollChild(window.buffBody)
    window.buffScrollbar = DP.Theme.ScrollBar(window.buffBox, 30)
    window.buffScrollbar:SetPoint("TOPRIGHT", -1, -35); window.buffScrollbar:SetPoint("BOTTOMRIGHT", -1, 8)
    window.buffScrollbar:SetWidth(18)
    window.buffScrollbar:SetObeyStepOnDrag(false)
    window.buffScrollbar:SetMinMaxValues(0, 0); window.buffScrollbar:SetValue(0); window.buffScrollbar:Hide()
    ConfigureSmoothWheelScroll(window.buffScroll, window.buffBody, 30)
    local baseBuffScrollUpdate = window.buffScroll.UpdateScrollHints
    function window.buffScroll:UpdateScrollHints()
        if baseBuffScrollUpdate then baseBuffScrollUpdate(self) end
        local range = math.max(0, (window.buffBody:GetHeight() or 0) - (self:GetHeight() or 0))
        local current = Clamp(self:GetVerticalScroll() or 0, 0, range)
        local token = window.buffScrollbar
        token._syncing = true
        token:SetMinMaxValues(0, range)
        token:SetValue(current)
        token._syncing = false
        token:SetShown((window._headerBuffCount or 0) > 10 and range > 1)
    end
    window.buffScrollbar:SetOnValueChanged(function(self, value)
        if self._syncing then return end
        local range = math.max(0, (window.buffBody:GetHeight() or 0) - (window.buffScroll:GetHeight() or 0))
        value = Clamp(value or 0, 0, range)
        window.buffScroll.smoothTarget = value
        window.buffScroll:SetVerticalScroll(value)
    end)
    local function BuffSelectorOptions()
        local options = {}
        for _, enemy in ipairs(window.record and window.record.enemies or {}) do
            local nameText, metaText = BuffSelectorEnemyParts(enemy)
            options[#options + 1] = {nameText = nameText, metaText = metaText, value = enemy.guid or enemy.name, enemy = enemy}
        end
        return options
    end
    local function ApplyBuffDropChrome(frame, backgroundAlpha)
        -- Use Blizzard's compact slider border as a native, continuous thin edge.
        -- This avoids the hand-drawn outline and the dark tiled seams seen in the
        -- previous two dropdown treatments.
        if frame.SetBackdrop then
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
                edgeSize = 8,
                insets = {left = 2, right = 2, top = 2, bottom = 2},
            })
            frame:SetBackdropColor(.025, .03, .04, backgroundAlpha or .97)
            frame:SetBackdropBorderColor(1, .82, .42, .92)
        else
            local bg = frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(); bg:SetColorTexture(.025, .03, .04, backgroundAlpha or .97)
        end
    end


    local function CreateBuffStyleDropDown(parent, menuParent, width, getOptions, onSelect)
        local control = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        control:SetSize(width, 26)
        ApplyBuffDropChrome(control, .98)

        control.textLabel = control:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        control.textLabel:SetPoint("LEFT", 7, 0)
        control.textLabel:SetPoint("RIGHT", -22, 0)
        control.textLabel:SetJustifyH("CENTER"); control.textLabel:SetWordWrap(false)

        control.arrow = CreateFrame("Button", nil, control)
        control.arrow:SetSize(18, 18); control.arrow:SetPoint("RIGHT", 1, 0)
        control.arrow:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        control.arrow:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
        control.arrow:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight", "ADD")
        control.arrowActive = control.arrow:CreateTexture(nil, "OVERLAY")
        control.arrowActive:SetAllPoints(control.arrow)
        control.arrowActive:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight")
        control.arrowActive:SetBlendMode("ADD"); control.arrowActive:Hide()

        local function SetArrowHighlight(active)
            active = active and true or false
            control.arrowActive:SetShown(active)
            local normal = control.arrow.GetNormalTexture and control.arrow:GetNormalTexture()
            if normal and normal.SetVertexColor then
                if active then normal:SetVertexColor(1, .90, .35, 1) else normal:SetVertexColor(1, 1, 1, 1) end
            end
        end

        control.menu = CreateFrame("Frame", nil, menuParent or parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        control.menu:SetWidth(width)
        control.menu:SetPoint("TOPLEFT", control, "BOTTOMLEFT", 0, 0)
        if control.menu.SetFrameLevel and menuParent and menuParent.GetFrameLevel then control.menu:SetFrameLevel(menuParent:GetFrameLevel() + 40) end
        if control.menu.SetClipsChildren then control.menu:SetClipsChildren(true) end
        ApplyBuffDropChrome(control.menu, .99)
        control.menuRows = {}; control.menu:Hide()

        control.openChrome = CreateFrame("Frame", nil, menuParent or parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        control.openChrome:SetPoint("TOPLEFT", control, "TOPLEFT", 0, 0)
        control.openChrome:SetPoint("BOTTOMRIGHT", control.menu, "BOTTOMRIGHT", 0, 0)
        if control.openChrome.SetFrameLevel and menuParent and menuParent.GetFrameLevel then control.openChrome:SetFrameLevel(menuParent:GetFrameLevel() + 42) end
        if control.openChrome.EnableMouse then control.openChrome:EnableMouse(false) end
        if control.openChrome.SetBackdrop then
            control.openChrome:SetBackdrop({edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", edgeSize = 8,
                insets = {left = 2, right = 2, top = 2, bottom = 2}})
            control.openChrome:SetBackdropBorderColor(1, .82, .42, .92)
        end
        control.openChrome:Hide()

        local function SetMergedChrome(open)
            if control.SetBackdropBorderColor then control:SetBackdropBorderColor(1, .82, .42, open and 0 or .92) end
            if control.menu.SetBackdropBorderColor then control.menu:SetBackdropBorderColor(1, .82, .42, open and 0 or .92) end
            control.openChrome:SetShown(open)
        end
        function control:SetSelectedValue(value, text)
            self.selectedValue = value
            if not text then
                for _, option in ipairs((getOptions and getOptions()) or {}) do
                    if option.value == value then text = option.text; break end
                end
            end
            self.textLabel:SetText(text or tostring(value or ""))
        end
        function control:SelectValue(value)
            local text
            for _, option in ipairs((getOptions and getOptions()) or {}) do
                if option.value == value then text = option.text; break end
            end
            self:SetSelectedValue(value, text)
            self.menu:Hide()
            if onSelect then onSelect(value) end
        end
        function control:RefreshMenu()
            local allOptions = (getOptions and getOptions()) or {}
            -- The value already displayed in the selector is not an action. Hide it
            -- from the opened menu so every visible row actually changes the filter.
            local options = {}
            for _, option in ipairs(allOptions) do
                if option.value ~= self.selectedValue then options[#options + 1] = option end
            end
            local rowHeight, pad = 20, 2
            self.menu:SetHeight(math.max(8, #options * rowHeight + pad * 2))
            for index, option in ipairs(options) do
                local row = self.menuRows[index]
                if not row then
                    row = CreateFrame("Button", nil, self.menu)
                    row:SetHeight(rowHeight)
                    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
                    row.highlight:SetPoint("TOPLEFT", 1, -1); row.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
                    row.highlight:SetColorTexture(1, .72, .18, .14)
                    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.label:SetPoint("LEFT", 6, 0); row.label:SetPoint("RIGHT", -6, 0)
                    row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(false)
                    self.menuRows[index] = row
                end
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", pad, -(pad + (index - 1) * rowHeight)); row:SetPoint("TOPRIGHT", -pad, -(pad + (index - 1) * rowHeight))
                row.value = option.value; row.label:SetText(option.text or tostring(option.value or ""))
                row:SetScript("OnClick", function(clicked) control:SelectValue(clicked.value) end)
                row:Show()
            end
            for index = #options + 1, #self.menuRows do self.menuRows[index]:Hide() end
        end
        control:SetScript("OnClick", function(self)
            if self.menu:IsShown() then self.menu:Hide() else self:RefreshMenu(); self.menu:Show() end
        end)
        control:SetScript("OnEnter", function(self) self._mouseOver = true; SetArrowHighlight(true) end)
        control:SetScript("OnLeave", function(self) self._mouseOver = false; if not self.menu:IsShown() then SetArrowHighlight(false) end end)
        control.menu:SetScript("OnShow", function() SetMergedChrome(true); SetArrowHighlight(true) end)
        control.menu:SetScript("OnHide", function() SetMergedChrome(false); if not control._mouseOver then SetArrowHighlight(false) end end)
        control.arrow:SetScript("OnEnter", function() SetArrowHighlight(true) end)
        control.arrow:SetScript("OnLeave", function() if not control._mouseOver and not control.menu:IsShown() then SetArrowHighlight(false) end end)
        control.arrow:SetScript("OnClick", function() control:Click() end)
        control:SetScript("OnHide", function(self) if self.menu then self.menu:Hide() end end)
        return control
    end

    window.buffSelector = CreateFrame("Button", nil, window.buffBox, BackdropTemplateMixin and "BackdropTemplate" or nil)
    window.buffSelector:SetSize(180, 26)
    window.buffSelector:SetPoint("TOPLEFT", 8, -20)
    ApplyBuffDropChrome(window.buffSelector, .98)

    -- Keep identity and metadata on opposite edges so long race text does not
    -- push the class-colored name around.
    window.buffSelector.metaLabel = window.buffSelector:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.buffSelector.metaLabel:SetPoint("RIGHT", -20, 0)
    window.buffSelector.metaLabel:SetJustifyH("RIGHT"); window.buffSelector.metaLabel:SetWordWrap(false)
    window.buffSelector.textLabel = window.buffSelector:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.buffSelector.textLabel:SetPoint("LEFT", 7, 0)
    window.buffSelector.textLabel:SetPoint("RIGHT", window.buffSelector.metaLabel, "LEFT", -5, 0)
    window.buffSelector.textLabel:SetJustifyH("LEFT"); window.buffSelector.textLabel:SetWordWrap(false)

    -- Use Blizzard's standard scrollbar arrow states. Unlike the previous chat
    -- arrow texture, this asset has an obvious native highlight state.
    window.buffSelector.arrow = CreateFrame("Button", nil, window.buffSelector)
    window.buffSelector.arrow:SetSize(18, 18)
    window.buffSelector.arrow:SetPoint("RIGHT", 1, 0)
    window.buffSelector.arrow:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    window.buffSelector.arrow:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
    window.buffSelector.arrow:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight", "ADD")
    window.buffSelector.arrowActive = window.buffSelector.arrow:CreateTexture(nil, "OVERLAY")
    window.buffSelector.arrowActive:SetAllPoints(window.buffSelector.arrow)
    window.buffSelector.arrowActive:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight")
    window.buffSelector.arrowActive:SetBlendMode("ADD")
    window.buffSelector.arrowActive:Hide()
    local function SetBuffSelectorArrowHighlight(active)
        active = active and true or false
        window.buffSelector.arrowActive:SetShown(active)
        local highlight = window.buffSelector.arrow.GetHighlightTexture and window.buffSelector.arrow:GetHighlightTexture()
        if highlight and highlight.SetAlpha then highlight:SetAlpha(active and 1 or .95) end
        local normal = window.buffSelector.arrow.GetNormalTexture and window.buffSelector.arrow:GetNormalTexture()
        if normal and normal.SetVertexColor then
            if active then normal:SetVertexColor(1, .90, .35, 1)
            else normal:SetVertexColor(1, 1, 1, 1) end
        end
    end

    -- A compact Rivals-owned menu lets the opened list line up exactly with the
    -- selector and use the same clean bronze-rule treatment instead of the much
    -- chunkier global UIDropDownMenu list frame.
    window.buffSelector.menu = CreateFrame("Frame", nil, window, BackdropTemplateMixin and "BackdropTemplate" or nil)
    window.buffSelector.menu:SetWidth(180)
    window.buffSelector.menu:SetPoint("TOPLEFT", window.buffSelector, "BOTTOMLEFT", 0, 0)
    if window.buffSelector.menu.SetFrameLevel then window.buffSelector.menu:SetFrameLevel(window:GetFrameLevel() + 40) end
    if window.buffSelector.menu.SetClipsChildren then window.buffSelector.menu:SetClipsChildren(true) end
    ApplyBuffDropChrome(window.buffSelector.menu, .99)
    window.buffSelector.menuRows = {}
    window.buffSelector.menu:Hide()

    -- While open, selector + menu should read as one native bordered control,
    -- not two stacked boxes with a doubled seam between them. The individual
    -- borders go transparent and this single edge wraps the combined footprint.
    window.buffSelector.openChrome = CreateFrame("Frame", nil, window, BackdropTemplateMixin and "BackdropTemplate" or nil)
    window.buffSelector.openChrome:SetPoint("TOPLEFT", window.buffSelector, "TOPLEFT", 0, 0)
    window.buffSelector.openChrome:SetPoint("BOTTOMRIGHT", window.buffSelector.menu, "BOTTOMRIGHT", 0, 0)
    if window.buffSelector.openChrome.SetFrameLevel then window.buffSelector.openChrome:SetFrameLevel(window:GetFrameLevel() + 42) end
    if window.buffSelector.openChrome.EnableMouse then window.buffSelector.openChrome:EnableMouse(false) end
    if window.buffSelector.openChrome.SetBackdrop then
        window.buffSelector.openChrome:SetBackdrop({
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            edgeSize = 8,
            insets = {left = 2, right = 2, top = 2, bottom = 2},
        })
        window.buffSelector.openChrome:SetBackdropBorderColor(1, .82, .42, .92)
    end
    window.buffSelector.openChrome:Hide()

    local function SetBuffSelectorMergedChrome(open)
        open = open and true or false
        if window.buffSelector.SetBackdropBorderColor then
            window.buffSelector:SetBackdropBorderColor(1, .82, .42, open and 0 or .92)
        end
        if window.buffSelector.menu.SetBackdropBorderColor then
            window.buffSelector.menu:SetBackdropBorderColor(1, .82, .42, open and 0 or .92)
        end
        window.buffSelector.openChrome:SetShown(open)
    end

    function window.buffSelector:SetSelectedValue(value)
        self.selectedValue = value
        local nameText, metaText = "Opponent", ""
        for _, option in ipairs(BuffSelectorOptions()) do
            if option.value == value then
                nameText, metaText = option.nameText, option.metaText
                break
            end
        end
        self.textLabel:SetText(nameText or "Opponent")
        self.metaLabel:SetText(metaText or "")
    end
    function window.buffSelector:SelectValue(value)
        self:SetSelectedValue(value)
        window.buffOpponentGUID = value
        self.menu:Hide()
        if W.RefreshHeaderBuffs then W.RefreshHeaderBuffs() end
    end
    function window.buffSelector:RefreshMenu()
        local allOptions = BuffSelectorOptions()
        local options = {}
        -- Match the Items & Abilities selector: the currently displayed enemy is
        -- omitted from the menu, leaving only enemies the user can switch to.
        for _, option in ipairs(allOptions) do
            if option.value ~= self.selectedValue then options[#options + 1] = option end
        end
        local rowHeight, pad = 20, 2
        self.menu:SetHeight(math.max(8, #options * rowHeight + pad * 2))
        for index, option in ipairs(options) do
            local row = self.menuRows[index]
            if not row then
                row = CreateFrame("Button", nil, self.menu)
                row:SetHeight(rowHeight)
                row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
                -- The stock quest highlight has a soft glow that extends beyond
                -- the button rectangle. Use an inset native-looking fill instead
                -- so hover never bleeds into the next row or outside the menu.
                row.highlight:SetPoint("TOPLEFT", 1, -1)
                row.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
                row.highlight:SetColorTexture(1, .72, .18, .14)
                row.metaLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.metaLabel:SetPoint("RIGHT", -6, 0); row.metaLabel:SetJustifyH("RIGHT"); row.metaLabel:SetWordWrap(false)
                row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.nameLabel:SetPoint("LEFT", 6, 0); row.nameLabel:SetPoint("RIGHT", row.metaLabel, "LEFT", -5, 0)
                row.nameLabel:SetJustifyH("LEFT"); row.nameLabel:SetWordWrap(false)
                self.menuRows[index] = row
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", pad, -(pad + (index - 1) * rowHeight)); row:SetPoint("TOPRIGHT", -pad, -(pad + (index - 1) * rowHeight))
            row.value = option.value
            row.nameLabel:SetText(option.nameText)
            row.metaLabel:SetText(option.metaText)
            row:SetScript("OnClick", function(clicked) window.buffSelector:SelectValue(clicked.value) end)
            row:Show()
        end
        for index = #options + 1, #self.menuRows do self.menuRows[index]:Hide() end
    end
    window.buffSelector:SetScript("OnClick", function(self)
        if self.menu:IsShown() then self.menu:Hide() else self:RefreshMenu(); self.menu:Show() end
    end)
    window.buffSelector:SetScript("OnEnter", function(self)
        self._mouseOver = true
        SetBuffSelectorArrowHighlight(true)
    end)
    window.buffSelector:SetScript("OnLeave", function(self)
        self._mouseOver = false
        if not self.menu:IsShown() then SetBuffSelectorArrowHighlight(false) end
    end)
    window.buffSelector.menu:SetScript("OnShow", function()
        SetBuffSelectorMergedChrome(true)
        SetBuffSelectorArrowHighlight(true)
    end)
    window.buffSelector.menu:SetScript("OnHide", function()
        SetBuffSelectorMergedChrome(false)
        if not window.buffSelector._mouseOver then SetBuffSelectorArrowHighlight(false) end
    end)
    window.buffSelector.arrow:SetScript("OnEnter", function() SetBuffSelectorArrowHighlight(true) end)
    window.buffSelector.arrow:SetScript("OnLeave", function()
        if not window.buffSelector._mouseOver and not window.buffSelector.menu:IsShown() then SetBuffSelectorArrowHighlight(false) end
    end)
    window.buffSelector.arrow:SetScript("OnClick", function() window.buffSelector:Click() end)
    window.buffSelector:Hide()

    window.summaryTab = DP.Theme.DataTab(window, "Summary", 20, -191, 110, function() W.SelectDetailTab("summary") end)
    window.usageTab = DP.Theme.DataTab(window, "Items & Abilities", 131, -191, 150, function() W.SelectDetailTab("usage") end)
    window.logTab = DP.Theme.DataTab(window, "Combat Log", 282, -191, 120, function() W.SelectDetailTab("log") end)

    window.content = CreateFrame("Frame", nil, window); window.content:SetPoint("TOPLEFT", 20, -221); window.content:SetPoint("BOTTOMRIGHT", -20, 18)
    if window.content.SetClipsChildren then window.content:SetClipsChildren(false) end

    -- Summary is intentionally asymmetric: a compact encounter-stats column
    -- on the left and a wider participant roster on the right. The stats card
    -- carries only high-value encounter information; context that belongs to a
    -- person/NPC lives on that participant's plaque instead of in a separate
    -- paragraph box.
    window.summaryStatsTitle = window.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.summaryStatsTitle:SetPoint("TOPLEFT", 0, -4); window.summaryStatsTitle:SetWidth(220); window.summaryStatsTitle:SetJustifyH("LEFT"); window.summaryStatsTitle:SetText("ENCOUNTER STATS")
    window.summaryStatsBox = CreateFrame("Frame", nil, window.content)
    window.summaryStatsBox:SetPoint("TOPLEFT", 0, -24); window.summaryStatsBox:SetSize(220, 206)
    window.summaryStatsBox.bg = window.summaryStatsBox:CreateTexture(nil, "BACKGROUND"); window.summaryStatsBox.bg:SetAllPoints(); window.summaryStatsBox.bg:SetColorTexture(.035, .045, .06, .78)
    DP.Theme.Border(window.summaryStatsBox, 0, 0, 220, 206)

    -- Kills / killing blows are compact counters sharing the top row.
    window.summaryKillsHit = CreateFrame("Frame", nil, window.summaryStatsBox); window.summaryKillsHit:SetPoint("TOPLEFT", 4, -4); window.summaryKillsHit:SetSize(106, 42); window.summaryKillsHit:EnableMouse(true)
    window.summaryKillsValue = window.summaryKillsHit:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); window.summaryKillsValue:SetPoint("TOP", 0, -4); window.summaryKillsValue:SetText("0"); window.summaryKillsValue:SetTextColor(.40, .90, .68)
    window.summaryKillsLabel = window.summaryKillsHit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); window.summaryKillsLabel:SetPoint("TOP", 0, -24); window.summaryKillsLabel:SetText("Kills")
    window.summaryKBHit = CreateFrame("Frame", nil, window.summaryStatsBox); window.summaryKBHit:SetPoint("TOPRIGHT", -4, -4); window.summaryKBHit:SetSize(106, 42); window.summaryKBHit:EnableMouse(true)
    window.summaryKBValue = window.summaryKBHit:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); window.summaryKBValue:SetPoint("TOP", 0, -4); window.summaryKBValue:SetText("0"); window.summaryKBValue:SetTextColor(.40, .90, .68)
    window.summaryKBLabel = window.summaryKBHit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); window.summaryKBLabel:SetPoint("TOP", 0, -24); window.summaryKBLabel:SetText("Killing blows")
    local topDivider = window.summaryStatsBox:CreateTexture(nil, "ARTWORK"); topDivider:SetPoint("TOP", 0, -7); topDivider:SetSize(1, 34); topDivider:SetColorTexture(.42, .30, .18, .65)
    local statsRule1 = window.summaryStatsBox:CreateTexture(nil, "ARTWORK"); statsRule1:SetPoint("TOPLEFT", 9, -48); statsRule1:SetPoint("TOPRIGHT", -9, -48); statsRule1:SetHeight(1); statsRule1:SetColorTexture(.34, .26, .18, .65)
    local killsBg = window.summaryKillsHit:CreateTexture(nil, "BACKGROUND"); killsBg:SetAllPoints(); killsBg:SetColorTexture(.025, .03, .04, .72)
    local kbBg = window.summaryKBHit:CreateTexture(nil, "BACKGROUND"); kbBg:SetAllPoints(); kbBg:SetColorTexture(.04, .045, .055, .72)
    DetailTooltip(window.summaryKillsHit, "Kills", function(_, record)
        local kills = record.enemyDeaths or 0
        if kills <= 0 then
            GameTooltip:AddLine("No enemy players died during this encounter.", .65, .7, .76, true)
            return
        end
        GameTooltip:AddLine(kills == 1 and "Defeated opponent" or "Defeated opponents", 1, 1, 1)
        for _, enemy in ipairs(record.enemies or {}) do
            if enemy.died then
                local right = enemy.killingBlow and "|cffffce70KB|r" or "|cff65e6adKilled|r"
                GameTooltip:AddDoubleLine(DP.Theme.ClassName(ShortName(enemy.name), enemy.class), right, 1, 1, 1, 1, 1, 1)
            end
        end
    end)
    DetailTooltip(window.summaryKBHit, "Killing Blows", function(_, record)
        AddKillingBlowTooltip(record)
    end)
    local function InstallCounterHover(frame, label, value)
        frame:HookScript("OnEnter", function()
            label:SetTextColor(1, .82, .42); value:SetTextColor(.55, 1, .78)
        end)
        frame:HookScript("OnLeave", function()
            label:SetTextColor(.50, .50, .50); value:SetTextColor(.40, .90, .68)
        end)
    end
    InstallCounterHover(window.summaryKillsHit, window.summaryKillsLabel, window.summaryKillsValue)
    InstallCounterHover(window.summaryKBHit, window.summaryKBLabel, window.summaryKBValue)

    window.summaryDamageTitle = window.summaryStatsBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    window.summaryDamageTitle:SetPoint("TOPLEFT", 10, -57); window.summaryDamageTitle:SetText("DAMAGE EXCHANGE")

    local function CreateExchangeStat(parent, y, mode)
        local row = CreateFrame("Frame", nil, parent); row:SetPoint("TOPLEFT", 10, y); row:SetSize(200, 42); row:EnableMouse(true)
        row.mainBg = row:CreateTexture(nil, "BACKGROUND"); row.mainBg:SetPoint("TOPLEFT", -2, 2); row.mainBg:SetPoint("TOPRIGHT", 2, 2); row.mainBg:SetHeight(21); row.mainBg:SetColorTexture(.025, .03, .04, .72)
        row.recoveryBg = row:CreateTexture(nil, "BACKGROUND"); row.recoveryBg:SetPoint("TOPLEFT", -2, -21); row.recoveryBg:SetPoint("TOPRIGHT", 2, -21); row.recoveryBg:SetHeight(19); row.recoveryBg:SetColorTexture(.04, .045, .055, .72)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("TOPLEFT", 0, -1); row.label:SetWidth(92); row.label:SetJustifyH("LEFT")
        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        row.value:SetPoint("TOPRIGHT", 0, 1); row.value:SetWidth(102); row.value:SetJustifyH("RIGHT")
        row.recoveryLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.recoveryLabel:SetPoint("TOPLEFT", 0, -24); row.recoveryLabel:SetWidth(125); row.recoveryLabel:SetJustifyH("LEFT")
        row.recoveryValue = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.recoveryValue:SetPoint("TOPRIGHT", 0, -23); row.recoveryValue:SetWidth(72); row.recoveryValue:SetJustifyH("RIGHT")
        row.mode = mode
        if mode == "dealt" then
            row.label:SetText("Dealt")
            row.label:SetTextColor(1, .82, .42)
            row.value:SetTextColor(1, .82, .42)
        else
            row.label:SetText("Taken")
            row.label:SetTextColor(1, .34, .32)
            row.value:SetTextColor(1, .34, .32)
        end
        -- The context is already established by Dealt/Taken directly above it.
        -- Use one quiet, neutral recovery label on both rows so the small green
        -- number carries the healing meaning without introducing a second color
        -- language for each combatant.
        row.recoveryLabel:SetText("Recovery")
        -- Both recovery rows share the same neutral resting treatment.  The
        -- recovery color only appears while the corresponding Dealt/Taken row
        -- is hovered, so neither combatant gets a different visual language.
        row.recoveryLabel:SetTextColor(.58, .61, .66)
        row.recoveryValue:SetTextColor(.58, .61, .66)
        row:SetScript("OnEnter", function(self)
            if self.mode == "dealt" then
                self.label:SetTextColor(1, .94, .58); self.value:SetTextColor(1, .94, .58)
            else
                self.label:SetTextColor(1, .48, .44); self.value:SetTextColor(1, .48, .44)
            end
            self.recoveryLabel:SetTextColor(.40, .90, .68)
            self.recoveryValue:SetTextColor(.40, .90, .68)
            local record = W.details and W.details.record
            if record then ShowDamageExchangeTooltip(self, record, self.mode) end
        end)
        row:SetScript("OnLeave", function(self)
            if self.mode == "dealt" then
                self.label:SetTextColor(1, .82, .42); self.value:SetTextColor(1, .82, .42)
            else
                self.label:SetTextColor(1, .34, .32); self.value:SetTextColor(1, .34, .32)
            end
            self.recoveryLabel:SetTextColor(.58, .61, .66)
            self.recoveryValue:SetTextColor(.58, .61, .66)
            if W.details and W.details.damageExchangeTooltip then W.details.damageExchangeTooltip:Hide() end
            GameTooltip:Hide()
        end)
        return row
    end
    window.summaryDamageDealt = CreateExchangeStat(window.summaryStatsBox, -72, "dealt")
    window.summaryDamageTaken = CreateExchangeStat(window.summaryStatsBox, -116, "taken")

    -- Restore the visual break between combat exchange and spend, but keep
    -- equal breathing room on both sides so it does not crowd either section.
    local statsRule2 = window.summaryStatsBox:CreateTexture(nil, "ARTWORK")
    statsRule2:SetPoint("TOPLEFT", 9, -158)
    statsRule2:SetPoint("TOPRIGHT", -9, -158)
    statsRule2:SetHeight(1)
    statsRule2:SetColorTexture(.34, .26, .18, .65)

    window.summaryConsumedHit = CreateFrame("Frame", nil, window.summaryStatsBox); window.summaryConsumedHit:SetPoint("TOPLEFT", 4, -164); window.summaryConsumedHit:SetPoint("BOTTOMRIGHT", -4, 4); window.summaryConsumedHit:EnableMouse(true)
    window.summaryConsumedBg = window.summaryConsumedHit:CreateTexture(nil, "BACKGROUND"); window.summaryConsumedBg:SetAllPoints(); window.summaryConsumedBg:SetColorTexture(.025, .03, .04, .72)
    window.summaryConsumedLabel = window.summaryConsumedHit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); window.summaryConsumedLabel:SetPoint("LEFT", 10, 0); window.summaryConsumedLabel:SetText("Consumed")
    window.summaryConsumedValue = window.summaryConsumedHit:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); window.summaryConsumedValue:SetPoint("RIGHT", -9, 0); window.summaryConsumedValue:SetWidth(135); window.summaryConsumedValue:SetJustifyH("RIGHT"); window.summaryConsumedValue:SetWordWrap(false)
    window.summaryConsumedHit.hoverLabel = window.summaryConsumedLabel
    window.summaryConsumedHit.hoverValue = window.summaryConsumedValue
    InstallConsumableCostTooltip(window.summaryConsumedHit, window)

    window.summaryRivalsTitle = window.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.summaryRivalsTitle:SetPoint("TOPLEFT", 236, -4); window.summaryRivalsTitle:SetWidth(374); window.summaryRivalsTitle:SetJustifyH("LEFT"); window.summaryRivalsTitle:SetText("OPPONENTS")
    window.summaryRivalsBox = CreateFrame("Frame", nil, window.content)
    window.summaryRivalsBox:SetPoint("TOPLEFT", 236, -24); window.summaryRivalsBox:SetSize(374, 206)
    window.summaryRivalsBox.bg = window.summaryRivalsBox:CreateTexture(nil, "BACKGROUND"); window.summaryRivalsBox.bg:SetAllPoints(); window.summaryRivalsBox.bg:SetColorTexture(.035, .045, .06, .72)
    DP.Theme.Border(window.summaryRivalsBox, 0, 0, 374, 206)
    window.summaryRivalsScroll = CreateFrame("ScrollFrame", nil, window.summaryRivalsBox)
    if window.summaryRivalsScroll.SetClipsChildren then window.summaryRivalsScroll:SetClipsChildren(true) end
    window.summaryRivalsScroll:SetPoint("TOPLEFT", 5, -5); window.summaryRivalsScroll:SetPoint("BOTTOMRIGHT", -18, 5)
    window.summaryRivalsBody = CreateFrame("Frame", nil, window.summaryRivalsScroll); window.summaryRivalsBody:SetSize(346, 196); window.summaryRivalsScroll:SetScrollChild(window.summaryRivalsBody)
    window.summaryRivalCards = {}
    window.summaryRivalsScrollbar = DP.Theme.ScrollBar(window.summaryRivalsBox, 30)
    window.summaryRivalsScrollbar:SetPoint("TOPRIGHT", -1, -8); window.summaryRivalsScrollbar:SetSize(18, 190)
    window.summaryRivalsScrollbar:SetObeyStepOnDrag(false)
    window.summaryRivalsScrollbar:SetMinMaxValues(0, 0); window.summaryRivalsScrollbar:SetValue(0); window.summaryRivalsScrollbar:Hide()
    ConfigureSmoothWheelScroll(window.summaryRivalsScroll, window.summaryRivalsBody, 30)
    local baseOpponentScrollUpdate = window.summaryRivalsScroll.UpdateScrollHints
    function window.summaryRivalsScroll:UpdateScrollHints()
        if baseOpponentScrollUpdate then baseOpponentScrollUpdate(self) end
        local range = math.max(0, (window.summaryRivalsBody:GetHeight() or 0) - (self:GetHeight() or 0))
        local current = Clamp(self:GetVerticalScroll() or 0, 0, range)
        local needsScroll = range > 1
        local boxWidth = window.summaryRivalsBox:GetWidth()
        if not boxWidth or boxWidth <= 0 then boxWidth = 374 end
        local contentWidth = math.max(1, boxWidth - 5 - (needsScroll and 14 or 5))

        -- Do not reserve an empty scrollbar gutter for short opponent lists.
        -- When scrolling is unnecessary the viewport and plaques expand across
        -- the full interior width of the OPPONENTS box.
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", window.summaryRivalsBox, "TOPLEFT", 5, -5)
        self:SetPoint("BOTTOMRIGHT", window.summaryRivalsBox, "BOTTOMRIGHT", needsScroll and -14 or -5, 5)
        window.summaryRivalsBody:SetWidth(contentWidth)
        if window.summaryRivalsEmpty then window.summaryRivalsEmpty:SetWidth(contentWidth - 10) end
        for _, card in ipairs(window.summaryRivalCards or {}) do
            -- NPC plaques use a literal 5px card gutter on each side. The
            -- medallion artwork has ~3px of transparent outer padding, so player
            -- rows reach 3px farther left while keeping the exact same right
            -- guide. That makes the *visible* medallion-to-box and plaque-to-box
            -- spacing match instead of making portrait rows look narrower.
            local rowWidth = math.max(1, contentWidth - (card.kind == "player" and 7 or 10))
            card._plaqueBaseWidth = rowWidth
            card:SetWidth(rowWidth)
            SetSummaryCardHitArea(card, false)
            W.SetSummaryCardPortraitMode(card, card.kind == "player", rowWidth)
        end

        local token = window.summaryRivalsScrollbar
        token._syncing = true
        token:SetMinMaxValues(0, math.max(0, range))
        token:SetValue(current)
        token._syncing = false
        token:SetShown(needsScroll)
        if W.RefreshVisibleOpponentPortraits then W.RefreshVisibleOpponentPortraits(window) end
    end
    window.summaryRivalsScrollbar:SetOnValueChanged(function(self, value)
        if self._syncing then return end
        local range = math.max(0, (window.summaryRivalsBody:GetHeight() or 0) - (window.summaryRivalsScroll:GetHeight() or 0))
        value = Clamp(value or 0, 0, range)
        window.summaryRivalsScroll.smoothTarget = value
        window.summaryRivalsScroll:SetVerticalScroll(value)
        if window.summaryRivalsScroll.UpdateScrollHints then window.summaryRivalsScroll:UpdateScrollHints() end
    end)
    window.summaryRivalsEmpty = window.summaryRivalsBody:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.summaryRivalsEmpty:SetPoint("TOPLEFT", 5, -5); window.summaryRivalsEmpty:SetWidth(324); window.summaryRivalsEmpty:SetJustifyH("LEFT"); window.summaryRivalsEmpty:SetJustifyV("TOP"); window.summaryRivalsEmpty:Hide()

    window.filter = CreateBuffStyleDropDown(window.content, window, 180, function()
        local options = {{text = "All participants", value = "all"}}
        local record = window.record
        if record then
            options[#options + 1] = {text = DP.Theme.ClassName("You", record.playerClass), value = record.playerGUID}
            for _, enemy in ipairs(record.enemies or {}) do
                options[#options + 1] = {text = DP.Theme.ClassName(ShortName(enemy.name), enemy.class), value = enemy.guid}
            end
            for _, friendly in ipairs(record.friendlies or {}) do
                if friendly.guid ~= record.playerGUID then
                    options[#options + 1] = {text = DP.Theme.ClassName(ShortName(friendly.name), friendly.class), value = friendly.guid}
                end
            end
        end
        return options
    end, function(value) window.participantFilter = value or "all"; W.RefreshDetailContent() end)
    -- Put the participant filter on the same horizontal plane as the detail tabs.
    -- Its right edge matches the ENEMY BUFFS selector above (window x=622), so the
    -- two compact dropdowns read as one vertical guide instead of drifting apart.
    window.filter:SetPoint("TOPRIGHT", window, "TOPRIGHT", -28, -191)

    -- The content area is 610px wide. When scrolling is required the dataframe
    -- gives the scrollbar its full 18px lane (592 + 18 = 610). When it is not
    -- required, reclaim that lane so the table ends on the same 20px outer guide
    -- as its left edge instead of leaving an empty strip on the right.
    window.usageTableWidth = 592
    window.usageHeader = CreateFrame("Frame", nil, window.content); window.usageHeader:SetPoint("TOPLEFT", 0, -8); window.usageHeader:SetSize(window.usageTableWidth, 24)
    window.usageHeader.bg = window.usageHeader:CreateTexture(nil, "BACKGROUND"); window.usageHeader.bg:SetAllPoints(); window.usageHeader.bg:SetColorTexture(.08, .09, .11, .95)
    window.usageHeaderLabels = {}
    local headers = {{"Time", 0, 54}, {"Player", 54, 118}, {"Used", 172, 295}, {"Target", 467, 125}}
    for index, h in ipairs(headers) do
        local text = window.usageHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); text:SetPoint("TOPLEFT", h[2] + 6, -6); text:SetWidth(h[3] - 10); text:SetJustifyH("LEFT"); text:SetText(h[1])
        window.usageHeaderLabels[index] = text
    end
    window.usageScroll = CreateFrame("ScrollFrame", nil, window.content)
    window.usageScroll:SetPoint("TOPLEFT", 0, -32); window.usageScroll:SetPoint("BOTTOMRIGHT", -18, 8)
    if window.usageScroll.SetClipsChildren then window.usageScroll:SetClipsChildren(true) end
    window.usageBody = CreateFrame("Frame", nil, window.usageScroll); window.usageBody:SetSize(window.usageTableWidth, 1); window.usageScroll:SetScrollChild(window.usageBody)
    window.usageRows = {}
    window.usageScrollbar = DP.Theme.ScrollBar(window.content, 30)
    window.usageScrollbar:SetPoint("TOPRIGHT", window.content, "TOPRIGHT", 0, -32)
    window.usageScrollbar:SetPoint("BOTTOMRIGHT", window.content, "BOTTOMRIGHT", 0, 8)
    ConfigureSmoothWheelScroll(window.usageScroll, window.usageBody, 30)
    local baseUsageScrollUpdate = window.usageScroll.UpdateScrollHints
    function window.usageScroll:UpdateScrollHints()
        if baseUsageScrollUpdate then baseUsageScrollUpdate(self) end
        local range = math.max(0, (window.usageBody:GetHeight() or 0) - (self:GetHeight() or 0))
        local current = Clamp(self:GetVerticalScroll() or 0, 0, range)
        local needsScroll = range > 1
        local tableWidth = needsScroll and 592 or 610
        window.usageTableWidth = tableWidth

        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", window.content, "TOPLEFT", 0, -32)
        self:SetPoint("BOTTOMRIGHT", window.content, "BOTTOMRIGHT", needsScroll and -18 or 0, 8)
        window.usageHeader:SetWidth(tableWidth)
        window.usageBody:SetWidth(tableWidth)
        if window.usageHeaderLabels and window.usageHeaderLabels[4] then
            window.usageHeaderLabels[4]:SetWidth((tableWidth - 467) - 10)
        end
        for _, row in ipairs(window.usageRows or {}) do
            row:SetWidth(tableWidth)
            if row.categoryBorder then row.categoryBorder:ClearAllPoints(); row.categoryBorder:SetAllPoints(row) end
            if row.label then row.label:SetWidth(tableWidth - 20) end
            if row.target then row.target:SetWidth(math.max(40, tableWidth - 479)) end
        end

        local token = window.usageScrollbar
        token._syncing = true
        token:SetMinMaxValues(0, range); token:SetValue(current)
        token._syncing = false
        token:SetShown(needsScroll)
    end
    window.usageScrollbar:SetOnValueChanged(function(self, value)
        if self._syncing then return end
        local range = math.max(0, (window.usageBody:GetHeight() or 0) - (window.usageScroll:GetHeight() or 0))
        value = Clamp(value or 0, 0, range)
        window.usageScroll.smoothTarget = value
        window.usageScroll:SetVerticalScroll(value)
    end)

    window.logBox = CreateFrame("Frame", nil, window.content)
    window.logBox:SetPoint("TOPLEFT", 0, -8); window.logBox:SetPoint("BOTTOMRIGHT", 0, 8)
    window.logBox.bg = window.logBox:CreateTexture(nil, "BACKGROUND"); window.logBox.bg:SetAllPoints(); window.logBox.bg:SetColorTexture(.025, .032, .043, .78)
    local logBorder = DP.Theme.Border(window.logBox, 0, 0, 598, 322)
    logBorder:ClearAllPoints(); logBorder:SetAllPoints(window.logBox); logBorder:EnableMouse(false)
    window.logScroll = CreateFrame("ScrollFrame", nil, window.logBox)
    window.logScroll:SetPoint("TOPLEFT", 10, -10); window.logScroll:SetPoint("BOTTOMRIGHT", -17, 10)
    window.logBody = CreateFrame("Frame", nil, window.logScroll); window.logBody:SetSize(583, 1); window.logScroll:SetScrollChild(window.logBody)
    -- Use a multiline EditBox instead of a FontString so combat-log text can be
    -- mouse-selected and copied with the normal Ctrl+A / Ctrl+C shortcuts.
    -- Edits are display-only and are replaced whenever the log is refreshed.
    window.logText = CreateFrame("EditBox", nil, window.logBody)
    window.logText:SetPoint("TOPLEFT", 4, -4); window.logText:SetWidth(575); window.logText:SetHeight(1)
    window.logText:SetMultiLine(true); window.logText:SetAutoFocus(false); window.logText:SetFontObject(GameFontHighlightSmall)
    window.logText:SetJustifyH("LEFT"); window.logText:SetJustifyV("TOP"); window.logText:SetTextInsets(0, 0, 0, 0)
    window.logText:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if DP.Theme.ConfigureReadOnlyCombatLog then DP.Theme.ConfigureReadOnlyCombatLog(window.logText) end
    if DP.Theme.CreateCombatLogCopyButton then
        window.logCopyButton = DP.Theme.CreateCombatLogCopyButton(window.logBox, window.logText, function()
            return window.logPlainText or (DP.Theme.PlainCombatLogText and DP.Theme.PlainCombatLogText(window.logText._rivalsLockedText or "")) or ""
        end)
    end
    window.logMeasure = window.logBody:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    window.logMeasure:SetPoint("TOPLEFT", 4, -4); window.logMeasure:SetWidth(575); window.logMeasure:SetJustifyH("LEFT"); window.logMeasure:SetJustifyV("TOP"); window.logMeasure:SetWordWrap(true); window.logMeasure:SetAlpha(0)
    window.logScrollbar = DP.Theme.ScrollBar(window.logBox, 30)
    window.logScrollbar:SetPoint("TOPRIGHT", window.logBox, "TOPRIGHT", -4, -8)
    window.logScrollbar:SetPoint("BOTTOMRIGHT", window.logBox, "BOTTOMRIGHT", -4, 8)
    ConfigureSmoothWheelScroll(window.logScroll, window.logBody, 30)
    local baseLogScrollUpdate = window.logScroll.UpdateScrollHints
    function window.logScroll:UpdateScrollHints()
        if baseLogScrollUpdate then baseLogScrollUpdate(self) end
        local range = math.max(0, (window.logBody:GetHeight() or 0) - (self:GetHeight() or 0))
        local current = Clamp(self:GetVerticalScroll() or 0, 0, range)
        local token = window.logScrollbar
        token._syncing = true; token:SetMinMaxValues(0, range); token:SetValue(current); token._syncing = false
        token:SetShown(range > 1)
    end
    window.logScrollbar:SetOnValueChanged(function(self, value)
        if self._syncing then return end
        local range = math.max(0, (window.logBody:GetHeight() or 0) - (window.logScroll:GetHeight() or 0))
        value = Clamp(value or 0, 0, range)
        window.logScroll.smoothTarget = value; window.logScroll:SetVerticalScroll(value)
    end)

    DetailTooltip(window.map, "Encounter location", function(_, record)
        local loc = record.location or {}
        local zone = SummaryZoneName(loc) or loc.zone or "Unknown location"
        local subzone = loc.subzone and loc.subzone ~= "" and loc.subzone ~= zone and loc.subzone or nil
        GameTooltip:AddLine(subzone and (zone .. " — " .. subzone) or zone, 1, 1, 1, true)
        if loc.x and loc.y then GameTooltip:AddLine(string.format("Map position: %.1f, %.1f", loc.x * 100, loc.y * 100), .72, .76, .82) end
        GameTooltip:AddLine(record.playerDied and "The skull marks where your death was recorded." or "The X marks the recorded encounter location.", .65, .7, .76, true)
    end)
    DetailTooltip(window.locationHover, "Location", function(_, record)
        local loc = record.location or {}
        local zone = SummaryZoneName(loc) or loc.zone or "Unknown location"
        local subzone = loc.subzone and loc.subzone ~= "" and loc.subzone ~= zone and loc.subzone or nil
        GameTooltip:AddLine(zone, 1, 1, 1, true)
        if subzone then GameTooltip:AddLine(subzone, .72, .76, .82, true) end
        if loc.x and loc.y then GameTooltip:AddLine(string.format("Recorded at %.1f, %.1f", loc.x * 100, loc.y * 100), .65, .7, .76) end
        local encounters, kills = 0, 0
        for _, prior in ipairs(W.GetEncounters()) do
            local priorZone = SummaryZoneName(prior.location or {}) or (prior.location and prior.location.zone)
            if priorZone == zone then encounters = encounters + 1; kills = kills + (prior.enemyDeaths or 0) end
        end
        if encounters > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("YOUR RECORDED HISTORY HERE", 1, .82, .42)
            GameTooltip:AddLine(string.format("%d %s • %d %s", encounters, encounters == 1 and "encounter" or "encounters", kills, kills == 1 and "kill" or "kills"), .75, .78, .84)
        end
    end)

    UISpecialFrames[#UISpecialFrames + 1] = "RivalsWorldPvPDetails"
    W.details = window
    return window
end

local function UsageEvents(record, filter)
    local events = record.session and record.session.worldUsage and record.session.worldUsage.events or {}
    local result, normalKeys, lastItemUse = {}, {}, {}
    local function Push(entry)
        if not entry or not (filter == "all" or entry.guid == filter) then return false end
        -- 349981 is the persistent Supercharged Chronoboon aura, not an item-use
        -- event. Older builds saved it as a fake Chronoboon row; hide that stale
        -- evidence from Items & Abilities even before the record migration runs.
        local usageSpellID = tonumber(entry.spellID or entry.sourceSpellID)
        if usageSpellID == 349981 then return false end
        if entry.itemID and entry.guid then
            local key = tostring(entry.guid) .. ":" .. tostring(entry.itemID)
            local at = tonumber(entry.t) or 0
            local prior = lastItemUse[key]
            if prior ~= nil and math.abs(at - prior) <= .75 then return false end
            lastItemUse[key] = at
        end
        result[#result + 1] = entry
        normalKeys[tostring(entry.guid or "") .. ":" .. tostring(entry.spellID or "")] = true
        return true
    end
    for _, entry in ipairs(events) do Push(entry) end

    -- Older records can contain only the NPC-sourced 13181 charm aura from a
    -- Mind Control Cap backfire. Recover the gadget row directly from the saved
    -- combat log and attribute it to the tracked participant the aura landed on.
    local participants = record.session and record.session.participants or {}
    for _, logEntry in ipairs(record.session and record.session.worldCombatLog or {}) do
        local logEvent = tostring(logEntry.event or "")
        if W.IsMindControlCapSpell(logEntry.spellID, logEntry.spellName) and
                (logEvent == "SPELL_CAST_SUCCESS" or logEvent == "SPELL_AURA_APPLIED" or logEvent == "SPELL_AURA_REFRESH") then
            local actorGUID, actorName, backfire = W.MindControlUseInfo(logEntry, participants)
            if actorGUID then
                Push({t=logEntry.t, guid=actorGUID, actorName=actorName, sourceName=actorName,
                    targetGUID=backfire and nil or logEntry.destGUID, targetName=backfire and nil or logEntry.destName,
                    spellID=tonumber(logEntry.spellID) or 13180, name="Gnomish Mind Control Cap",
                    itemID=10726, itemName="Gnomish Mind Control Cap", quality=2, kind="item", category="engineering",
                    backfire=backfire and true or nil, legacySource="worldCombatLog"})
            end
        end
    end

    -- Older encounters often retained a useful CLEU cast/aura but not the
    -- corresponding worldUsage row. Reuse the consumable reconstruction pass to
    -- surface only those missing combat-log item uses in Items & Abilities.
    -- The same 0.75-sec item guard also repairs old duplicate FAP/item signals.
    if DP.Usage and DP.Usage.ReconstructLegacyWorldUsage then
        local rebuilt = DP.Usage.ReconstructLegacyWorldUsage(record, record.session or {})
        for _, entry in ipairs(rebuilt and rebuilt.events or {}) do
            if entry.legacySource == "worldCombatLog" then Push(entry) end
        end
    end
    -- Long-lived enemy buffs have a dedicated visual viewer in the encounter
    -- header. Only short-duration consumable auras (FAP/LIP-style effects) are
    -- supplemented here when Rivals observed them already active rather than
    -- seeing the item use itself.
    for _, enemy in ipairs(record.enemies or {}) do
        if filter == "all" or filter == enemy.guid then
            for _, buff in ipairs(SortedDetectedBuffs(enemy, "consumables")) do
                local detected = enemy.detectedBuffs and enemy.detectedBuffs.all
                local full = detected and detected[tostring(buff.spellID or buff.name or "unknown")] or buff
                if IsShortTermConsumableAura(full) then
                    local key = tostring(enemy.guid or "") .. ":" .. tostring(buff.spellID or "")
                    if not (buff.gainedDuringFight and normalKeys[key]) then
                        Push({t = buff.firstSeenAt or 0, guid = enemy.guid, actorName = enemy.name,
                            spellID = buff.spellID, itemID = buff.itemID, name = buff.name, buffCategory = "consumablebuffs",
                            displayTarget = buff.activeAtEngagement and "At pull" or buff.gainedDuringFight and "Gained" or "Observed"})
                    end
                end
            end
        end
    end
    return result
end

local CATEGORY_ORDER = {worldbuffs = 0, consumablebuffs = 1, potions = 2, engineering = 3, equipment = 4, cooldowns = 5, racials = 6}
local CATEGORY_LABEL = {worldbuffs = "WORLD BUFFS", consumablebuffs = "CONSUMABLE BUFFS", potions = "POTIONS/CONSUMABLES", engineering = "ENGINEERING GADGETS", equipment = "EQUIPMENT", cooldowns = "COOLDOWNS (≥3 MIN)", racials = "RACIALS"}
local CATEGORY_TOOLTIP = {
    worldbuffs = "World buffs observed on an opponent during the encounter.",
    consumablebuffs = "Short-duration consumable effects observed on an opponent, including potion-style buffs that may not have a separate retained use event.",
    potions = "Potions, bandages, healthstones, Chronoboon activations, and other directly used consumables. Reagent costs are kept only in Consumable Cost.",
    engineering = "Engineering devices and gadgets used during the encounter, such as grenades, reflectors, nets, and Mind Control Cap.",
    equipment = "Activated gear and item procs attributable to equipped weapons, armor, trinkets, or other equipment.",
    cooldowns = "Class abilities with cooldowns of at least three minutes.",
    racials = "Racial abilities used during the encounter.",
}

local function DescribeWorldUsage(entry, record)
    if entry.buffCategory then
        return {text = entry.name or "Unknown buff", category = entry.buffCategory, itemID = entry.itemID, spellID = entry.spellID}
    end
    if DP.Usage and DP.Usage.Describe then
        local display = DP.Usage.Describe(entry, record)
        if type(display) == "table" then return display end
    end
    return {
        text = entry.name or ("Spell " .. tostring(entry.spellID)),
        category = entry.category or "cooldowns",
        itemID = entry.itemID,
        spellID = entry.spellID,
    }
end

local function EnsureUsageRow(window, index, kind)
    local width = window.usageTableWidth or 592
    local row = window.usageRows[index]
    if row and row.kind == kind then
        row:SetWidth(width)
        if row.categoryBorder then row.categoryBorder:ClearAllPoints(); row.categoryBorder:SetAllPoints(row) end
        if row.label then row.label:SetWidth(width - 20) end
        return row
    end
    if row then row:Hide() end
    row = CreateFrame("Button", nil, window.usageBody); row.kind = kind; row:SetSize(width, kind == "category" and 26 or 22)
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
    if kind == "category" then
        -- Category dividers read as inset plaques rather than another flat table
        -- stripe. UI-Background-Rock is native Blizzard stone texture; the dark
        -- tint keeps it behind the centered gold label.
        row.bg:SetColorTexture(.022, .018, .014, .98)
        row.rock = row:CreateTexture(nil, "BACKGROUND")
        row.rock:SetPoint("TOPLEFT", 3, -3); row.rock:SetPoint("BOTTOMRIGHT", -3, 3)
        row.rock:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
        -- Keep the stone present but quiet; the header copy should dominate.
        row.rock:SetVertexColor(.22, .18, .12, .54)
        row.categoryShade = row:CreateTexture(nil, "BACKGROUND")
        row.categoryShade:SetPoint("TOPLEFT", 4, -4); row.categoryShade:SetPoint("BOTTOMRIGHT", -4, 4)
        row.categoryShade:SetColorTexture(0, 0, 0, .24)
        -- Use a heavier native tooltip edge here than the ordinary opponent
        -- plaques so category dividers read as section headers at a glance.
        row.categoryBorder = DP.Theme.PlaqueBorder(row, width, 26, 12)
        row.categoryBorder:ClearAllPoints(); row.categoryBorder:SetAllPoints(row); row.categoryBorder:EnableMouse(false)
        row.label = row.categoryBorder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("CENTER", row.categoryBorder, "CENTER", 0, 0)
        row.label:SetWidth(width - 20); row.label:SetJustifyH("CENTER"); row.label:SetJustifyV("MIDDLE")
        local fontPath, fontSize = row.label:GetFont()
        if fontPath and fontSize then row.label:SetFont(fontPath, fontSize, "OUTLINE") end
        row.label:SetShadowColor(0, 0, 0, 1); row.label:SetShadowOffset(1, -2)
        row:SetScript("OnEnter", function(self)
            local category = self.categoryKey
            local description = category and CATEGORY_TOOLTIP[category]
            if not description then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(CATEGORY_LABEL[category] or category, 1, .82, .36)
            GameTooltip:AddLine(description, .9, .9, .9, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        row.time = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); row.time:SetPoint("TOPLEFT", 6, -5); row.time:SetWidth(48); row.time:SetJustifyH("LEFT")
        row.player = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.player:SetPoint("TOPLEFT", 60, -5); row.player:SetWidth(106); row.player:SetJustifyH("LEFT"); row.player:SetWordWrap(false)
        row.used = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.used:SetPoint("TOPLEFT", 178, -5); row.used:SetWidth(281); row.used:SetJustifyH("LEFT"); row.used:SetWordWrap(false)
        row.target = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); row.target:SetPoint("TOPLEFT", 473, -5); row.target:SetWidth(113); row.target:SetJustifyH("LEFT"); row.target:SetWordWrap(false)
        row:SetScript("OnEnter", function(self)
            if not self.entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.entry.itemID then
                GameTooltip:SetHyperlink("item:" .. tostring(self.entry.itemID))
            elseif self.entry.spellID and GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(self.entry.spellID)
            elseif self.entry.spellID and GetSpellLink then
                local link = GetSpellLink(self.entry.spellID)
                if link then GameTooltip:SetHyperlink(link) end
            else
                GameTooltip:SetText(self.used and self.used:GetText() or "Ability")
            end
            GameTooltip:AddLine("Shift-click to link in chat", .55, .6, .68, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self) InsertLink(self.entry) end)
    end
    window.usageRows[index] = row
    return row
end

W.RACE_KEY_BY_NAME = {
    ["Human"]="Human", ["Orc"]="Orc", ["Dwarf"]="Dwarf", ["Night Elf"]="NightElf", ["NightElf"]="NightElf",
    ["Undead"]="Scourge", ["Scourge"]="Scourge", ["Tauren"]="Tauren", ["Gnome"]="Gnome", ["Troll"]="Troll",
}
W.CLASS_RACE_PORTRAIT_DISPLAY_IDS = {
    -- Actual Classic race/class characters (primarily class trainers), used only
    -- when an encounter has no retained live display. Multiple entries give
    -- legacy records stable variation without substituting generic race art.
    ["Dwarf:WARRIOR"]={3053},
    ["Dwarf:PALADIN"]={3087},
    ["Dwarf:HUNTER"]={3073},
    ["Dwarf:ROGUE"]={3101},
    ["Dwarf:PRIEST"]={3429},

    ["Gnome:WARRIOR"]={3055},
    ["Gnome:ROGUE"]={3113},
    ["Gnome:MAGE"]={3108},
    ["Gnome:WARLOCK"]={1930},

    ["NightElf:WARRIOR"]={1721,2196},
    ["NightElf:HUNTER"]={1723,2206},
    ["NightElf:ROGUE"]={1704,2243,2252},
    ["NightElf:PRIEST"]={2200},
    ["NightElf:DRUID"]={1706,2250},

    ["Human:WARRIOR"]={1504,3287,3280},
    ["Human:PALADIN"]={3284},
    ["Human:ROGUE"]={3351},
    ["Human:PRIEST"]={1495,1295},
    -- 3293 was not a Human mage display and could render as a Blood Elf in
    -- Classic Era. These are actual Human mage/portal-trainer displays. Keep
    -- sex metadata so legacy portraits can also respect a retained player sex.
    ["Human:MAGE"]={
        {id=1294, sex=2}, -- Zaldimar Wefhellt
        {id=1484, sex=2}, -- Maginor Dumas
        {id=5001, sex=2}, -- Khelden Bremen
        {id=5076, sex=2}, -- High Sorcerer Andromath
        {id=3292, sex=3}, -- Jennea Cannon
        {id=1470, sex=3}, -- Larimaine Purdue
    },
    ["Human:WARLOCK"]={3286,3345,3271},

    -- Horde legacy portrait backfills. These are real Classic humanoid display
    -- IDs chosen from race-appropriate class trainers/representative class NPCs.
    -- Multiple displays where available keep old records from collapsing into a
    -- single repeated face; PortraitChoiceIndex keeps the choice stable per rival.
    ["Orc:WARRIOR"]={1374,1375,3743,1880},       -- Grezz, Sorek, Tarshaw, Frang
    ["Orc:HUNTER"]={1373},                       -- Ormak Grimshot
    ["Orc:ROGUE"]={1327,1886},                   -- Gest, Rwag
    ["Orc:SHAMAN"]={1360,1878},                  -- Kardris Dreamseeker, Shikrik
    ["Orc:WARLOCK"]={1324,4492,1884},            -- Grol'dar, Gan'rul Bloodeye, Nartok

    ["Tauren:WARRIOR"]={3793,3794,2103,2113},    -- Harutt, Krang, Torm, Ker
    ["Tauren:HUNTER"]={3811,2087,2112,2105},     -- Yaw, Holt, Kary, Urek
    ["Tauren:SHAMAN"]={10180,3816,2082},         -- Meela, Narm, Beram
    ["Tauren:DRUID"]={3820,2106,2121,2115},      -- Gennia, Turak, Sheal, Kym

    ["Troll:WARRIOR"]={4242},                    -- Zel'mak
    ["Troll:HUNTER"]={4239,4241},                -- Xor'juul, Sian'dur
    ["Troll:ROGUE"]={4360,4361},                 -- Shenthul, Zando'zan
    ["Troll:PRIEST"]={1897,4711},                -- Tai'jin, Ur'kyo
    ["Troll:SHAMAN"]={4231},                     -- Sian'tsu
    ["Troll:MAGE"]={6060,4522,4523,4524},        -- Uthel'nay, Enyo, Deino, Pephredo

    ["Scourge:WARRIOR"]={1599,2620,2658,2614},   -- Austil, Christoph, Angela, Baltus
    ["Scourge:ROGUE"]={1580,2639,2631},          -- David Trias, Miles Dexter, Gregory Charles
    ["Scourge:PRIEST"]={2626,10723,1579,1602},   -- Father Lankester, Aelthalyste, Duesten, Beryl
    ["Scourge:MAGE"]={1592,2657,10733,2644},     -- Isabella, Anastasia, Kaelystia, Pierce
    ["Scourge:WARLOCK"]={1581,1604,2675,2637},   -- Maximillion, Rupert, Kaal, Luther
}

function W.PortraitChoiceIndex(enemy, count)
    count = math.max(1, tonumber(count) or 1)
    local key = tostring(enemy and (enemy.guid or enemy.name) or "Rivals")
    local hash = tonumber(enemy and enemy.portraitFallbackVariant) or 0
    for index = 1, #key do hash = (hash * 33 + string.byte(key, index)) % 104729 end
    return (hash % count) + 1
end

function W.PortraitDisplayChoices(enemy, choices)
    local filtered, all = {}, {}
    local wantedSex = tonumber(enemy and (enemy.portraitSex or enemy.sex))
    for _, choice in ipairs(choices or {}) do
        local id, sex
        if type(choice) == "table" then
            id = tonumber(choice.id or choice[1])
            sex = tonumber(choice.sex)
        else
            id = tonumber(choice)
        end
        if id then
            all[#all + 1] = id
            if not wantedSex or not sex or sex == wantedSex then filtered[#filtered + 1] = id end
        end
    end
    -- If a curated set lacks a matching sex, preserving the correct race/class is
    -- more important than dropping all the way to a generic class icon.
    return #filtered > 0 and filtered or all
end

local function HidePortraitSpinner(card, keepWanted)
    if card and card.portraitSpinnerFrame then
        card.portraitSpinnerFrame:Hide()
        card.portraitSpinnerFrame._phase = 0
    end
    if card then
        card._portraitLoading = nil
        if not keepWanted and DP.Portraits and DP.Portraits.ReleaseWanted then DP.Portraits.ReleaseWanted(card) end
    end
end

local function ShowPortraitSpinner(card)
    if not card then return false end
    if card.portrait then card.portrait:Hide() end
    if card.portraitModel then card.portraitModel:Hide() end
    if card.portraitSpinnerFrame then
        card.portraitSpinnerFrame._phase = 0
        card.portraitSpinnerFrame:Show()
        card._portraitLoading = true
        return true
    end
    return false
end


function W.QueuePortraitLoadRetry(card, enemy, commitKey)
    if not (card and enemy and C_Timer and C_Timer.After and DP.Portraits) then return end
    card._portraitLoadRetryGeneration = (tonumber(card._portraitLoadRetryGeneration) or 0) + 1
    local generation = card._portraitLoadRetryGeneration
    local startedAt = GetTime and GetTime() or 0
    local function Retry()
        if card._portraitLoadRetryGeneration ~= generation or not card._portraitViewportActive or
                card.enemy ~= enemy or card._portraitCommittedKey ~= commitKey or
                not (card._portraitLoading or card._portraitTemporaryFallback) then return end
        local elapsed = (GetTime and GetTime() or 0) - startedAt
        card._portraitHideStaticOnReveal = card._portraitTemporaryFallback and true or nil
        if DP.Portraits.IsPrepared and DP.Portraits.IsPrepared(enemy) and DP.Portraits.ApplyPrepared and
                DP.Portraits.ApplyPrepared(card, enemy) then
            card._portraitFallback = false
            card._portraitTemporaryFallback = nil
            return
        end
        if DP.Portraits.WantPrepared then DP.Portraits.WantPrepared(card, enemy) end
        if DP.Portraits.PrepareImmediate then DP.Portraits.PrepareImmediate(enemy, true)
        elseif DP.Portraits.PreloadIdentities then DP.Portraits.PreloadIdentities({enemy}, 1, true) end
        C_Timer.After(elapsed < 3 and .10 or .5, Retry)
    end
    if DP.Portraits.WantPrepared then DP.Portraits.WantPrepared(card, enemy) end
    if DP.Portraits.PrepareImmediate then DP.Portraits.PrepareImmediate(enemy, true)
    elseif DP.Portraits.PreloadIdentities then DP.Portraits.PreloadIdentities({enemy}, 1, true) end
    C_Timer.After(.01, Retry)
end

local function ShowRaceClassPortraitFallback(card, enemy, temporary)
    if not (card and card.portrait and enemy) then return false end
    if SetPortraitTextureFromCreatureDisplayID then
        local raceKey = enemy.raceFile or W.RACE_KEY_BY_NAME[tostring(enemy.race or "")]
        local choices = raceKey and enemy.class and W.CLASS_RACE_PORTRAIT_DISPLAY_IDS[raceKey .. ":" .. tostring(enemy.class)]
        choices = W.PortraitDisplayChoices(enemy, choices)
        if choices and #choices > 0 then
            local displayID = choices[W.PortraitChoiceIndex(enemy, #choices)]
            local ok = pcall(SetPortraitTextureFromCreatureDisplayID, card.portrait, displayID)
            if ok then
                card.portrait:SetTexCoord(0, 1, 0, 1)
                card.portrait:Show()
                card._portraitFallback = true
                card._portraitTemporaryFallback = temporary and true or nil
                return true
            end
        end
    end
    return false
end

W.ShowRaceClassPortraitFallback=ShowRaceClassPortraitFallback

function W.RecordPortraitsReady(record)
    if not record then return true end
    for _, enemy in ipairs(record.enemies or {}) do
        local snapshot = enemy and enemy.portraitAppearance
        if snapshot and snapshot.slotCount and snapshot.slotCount > 0 then
            local holder = W._portraitCaptureFrames and W._portraitCaptureFrames[enemy]
            if not (holder and holder.captured) then
                if not (DP.Portraits and DP.Portraits.IsPrepared and DP.Portraits.IsPrepared(enemy)) then
                    return false
                end
            end
        end
    end
    return true
end

function W.ApplyOpponentPortrait(card, enemy)
    if not card or not card.portrait then return end
    local commitKey = DP.Portraits and DP.Portraits.CacheKey and DP.Portraits.CacheKey(enemy) or
        tostring(enemy and (enemy.guid or enemy.name) or "?")

    -- Re-clicking the same History encounter, switching away from Summary and
    -- back, or refreshing surrounding text must not rebuild a portrait that is
    -- already committed to this plaque. Reassert the pause and leave every
    -- render object exactly where it is.
    local committedVisualStillResident = card._portraitBodyEntry or card._snapshotHolder or
        (card.portrait.IsShown and card.portrait:IsShown()) or
        (card.portraitSpinnerFrame and card.portraitSpinnerFrame.IsShown and card.portraitSpinnerFrame:IsShown())
    if card._portraitCommittedKey == commitKey and card._portraitCommittedEnemy == enemy and committedVisualStillResident then
        card._portraitViewportActive = true
        -- A prepared 3D portrait is a true no-op on repeated encounter clicks.
        -- A fallback, however, may have been committed only because the hidden
        -- preloader lost the startup race. Upgrade it in place once preparation
        -- finishes instead of requiring the user to close/reopen Rivals.
        if (card._portraitFallback or card._portraitLoading) and DP.Portraits and DP.Portraits.IsPrepared and
                DP.Portraits.IsPrepared(enemy) and DP.Portraits.ApplyPrepared then
            card._portraitHideStaticOnReveal = card._portraitFallback and true or nil
            if DP.Portraits.ApplyPrepared(card, enemy) then
                card._portraitFallback = false
                card._portraitTemporaryFallback = nil
                return
            end
            card._portraitHideStaticOnReveal = nil
        end
        -- Deliberately touch nothing else. Even calling SetAnimation again on an
        -- already-paused actor can expose a one-frame pose reset on Classic.
        return
    end

    card._portraitViewportActive = true
    card._portraitLoadRetryGeneration = (tonumber(card._portraitLoadRetryGeneration) or 0) + 1
    card._rivalsPortraitReady = nil
    card._portraitTemporaryFallback = nil
    HidePortraitSpinner(card)
    -- Real opponent cards borrow retained session race/sex bodies, but visible
    -- cards only attach actors that were already dressed and frozen off-screen.
    card._rivalsUsePortraitBodyPool = true
    if DP.Portraits then
        if DP.Portraits.ResetCard then DP.Portraits.ResetCard(card)
        else DP.Portraits.Reset(card.portraitModel) end
    end
    card._portraitCommittedKey = nil
    card._portraitCommittedEnemy = nil
    card._portraitReconstructed = false
    if card._snapshotHolder then
        local holder = card._snapshotHolder
        holder.tex:Hide()
        if card.portraitMask and holder.tex.RemoveMaskTexture then holder.tex:RemoveMaskTexture(card.portraitMask) end
        holder.tex:SetParent(holder)
        holder.tex:ClearAllPoints(); holder.tex:SetAllPoints(holder)
        card._snapshotHolder = nil
    end
    card.portrait:SetTexture(nil)
    card.portrait:SetTexCoord(0, 1, 0, 1)
    card.portrait:Hide()
    if card.portraitModel then card.portraitModel:Hide() end
    if card.portraitRing then card.portraitRing:SetVertexColor(1, 1, 1, 1) end
    card._portraitFallback = false
    local applied = false

    -- Keep the actual render texture alive. RTPortrait handles returned by
    -- GetTexture are not portable image files and must not be replayed.
    local holder = enemy and W._portraitCaptureFrames and W._portraitCaptureFrames[enemy]
    if holder and holder.captured then
        holder.tex:SetParent(card.portraitFrame)
        holder.tex:ClearAllPoints(); holder.tex:SetPoint("CENTER"); holder.tex:SetSize(46, 46)
        if card.portraitMask and holder.tex.AddMaskTexture then holder.tex:AddMaskTexture(card.portraitMask) end
        holder.tex:Show()
        card._snapshotHolder = holder
        HidePortraitSpinner(card)
        applied = true
    end

    -- Persisted SetPortraitTexture backing handles are intentionally ignored.
    -- Current-session exact portraits live in _portraitCaptureFrames above;
    -- saved encounters reconstruct from their serialized appearance below.

    local reconstructable = enemy and enemy.portraitAppearance and enemy.portraitAppearance.slotCount and
        enemy.portraitAppearance.slotCount > 0
    -- After reload, never construct a ModelScene on a visible plaque. Only a
    -- portrait that was fully dressed, framed, and frozen off-screen is eligible
    -- to attach here. A cache miss starts only this visible opponent's work and
    -- upgrades the medallion as soon as the hidden preparation finishes.
    if not applied and enemy and DP.Portraits and card.portraitModel then
        local reconstructed = DP.Portraits.ApplyPrepared and DP.Portraits.ApplyPrepared(card, enemy) and true or false
        if reconstructed then
            applied = true
            card._portraitFallback = false
            card._portraitTemporaryFallback = nil
        elseif DP.Portraits.PrepareImmediate then
            DP.Portraits.PrepareImmediate(enemy, true)
        elseif DP.Portraits.PreloadIdentities then
            DP.Portraits.PreloadIdentities({enemy}, 1, true)
        end
    end


    -- Saved portraits show only the spinner until their reconstructed actor
    -- is ready. There is no timed class-icon replacement.
    if not applied and reconstructable then
        if DP.Portraits and DP.Portraits.WantPrepared then DP.Portraits.WantPrepared(card, enemy) end
        applied = ShowPortraitSpinner(card) and true or false
    end

    -- Records with no reconstructable outfit can still use Blizzard's display-ID
    -- portrait or the stable race/class legacy backfill.
    if not applied and not reconstructable and enemy and tonumber(enemy.portraitDisplayID) and SetPortraitTextureFromCreatureDisplayID then
        local ok = pcall(SetPortraitTextureFromCreatureDisplayID, card.portrait, tonumber(enemy.portraitDisplayID))
        if ok then
            card.portrait:SetTexCoord(0, 1, 0, 1)
            card.portrait:Show()
            HidePortraitSpinner(card)
            applied = true
        end
    end
    if not applied and not reconstructable and enemy then
        applied = ShowRaceClassPortraitFallback(card, enemy, false) and true or false
        if applied then HidePortraitSpinner(card) end
    end
    if not applied then
        card.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        card.portrait:SetTexCoord(.08, .92, .08, .92)
        card.portrait:Show()
        card._portraitFallback = true
    end
    card._portraitCommittedKey = commitKey
    card._portraitCommittedEnemy = enemy
    if card._portraitLoading then W.QueuePortraitLoadRetry(card, enemy, commitKey) end
end

-- Hidden preparation can finish while a detail pane is already open (mainly
-- during the first second after /reload). Upgrade only the matching fallback
-- card, with the old static texture left visible until the frozen ModelScene is
-- ready to reveal. This is a seamless swap: no blank medallion, no pane reload,
-- and no user click is required.
function W.OnOpponentPortraitPrepared(enemy, preparedKey)
    local detail = window
    if not (enemy and detail and detail.IsShown and detail:IsShown()) then return end
    local expectedKey = DP.Portraits and DP.Portraits.CacheKey and DP.Portraits.CacheKey(enemy) or nil
    if preparedKey and expectedKey and preparedKey ~= expectedKey then return end
    if DP.Portraits and DP.Portraits.TraceLoad then DP.Portraits.TraceLoad("callback", expectedKey) end
    for _, card in ipairs(detail.summaryRivalCards or {}) do
        local cardKey = card._portraitCommittedKey or
            (card.enemy and DP.Portraits and DP.Portraits.CacheKey and DP.Portraits.CacheKey(card.enemy))
        if card._portraitViewportActive and (card._portraitFallback or card._portraitLoading) and
                cardKey and expectedKey and cardKey == expectedKey and
                card.enemy and DP.Portraits and DP.Portraits.ApplyPrepared then
            card._portraitHideStaticOnReveal = card._portraitFallback and true or nil
            if DP.Portraits.ApplyPrepared(card, card.enemy) then
                card._portraitFallback = false
                card._portraitTemporaryFallback = nil
                card._portraitCommittedKey = expectedKey
                card._portraitCommittedEnemy = card.enemy
            else
                card._portraitHideStaticOnReveal = nil
            end
        end
    end
end

-- Only rows that are materially visible in the clipped OPPONENTS viewport keep a
-- borrowed 3D body. The ScrollFrame creates every encounter row at once, so
-- without this a long encounter can strand pooled bodies on cards the player
-- cannot even see and exhaust a race/sex cache unnecessarily.
function W.RefreshVisibleOpponentPortraits(detailWindow)
    local win = detailWindow or window
    if not (win and win.summaryRivalsScroll and win.summaryRivalCards) then return end
    local scroll = win.summaryRivalsScroll
    local viewTop = scroll:GetVerticalScroll() or 0
    local viewHeight = scroll:GetHeight() or 0
    local viewBottom = viewTop + viewHeight
    local minimumVisible = 10 -- avoids leasing both edge rows for a 1px overlap

    local visible = {}
    -- Release every outgoing lease before requesting incoming rows, including
    -- when scrolling upward. Otherwise the earlier rows can see a full pool.
    for _, card in ipairs(win.summaryRivalCards) do
        local shouldLease = false
        if card.kind == "player" and card.enemy and card:IsShown() then
            local rowTop = tonumber(card.summaryRowTop) or 0
            local rowBottom = rowTop + (card:GetHeight() or 47)
            local overlap = math.max(0, math.min(rowBottom, viewBottom) - math.max(rowTop, viewTop))
            shouldLease = (not win.activeTab or win.activeTab == "summary") and
                (not win.IsShown or win:IsShown()) and overlap >= minimumVisible
        end
        if shouldLease then
            visible[#visible + 1] = card
        elseif card._portraitViewportActive then
            if DP.Portraits and DP.Portraits.ReleaseBody then DP.Portraits.ReleaseBody(card) end
            if card.portraitScene then card.portraitScene:Hide() end
            card._portraitViewportActive = false
        end
    end
    for _, card in ipairs(visible) do
        local key = DP.Portraits and DP.Portraits.CacheKey and DP.Portraits.CacheKey(card.enemy)
        if not card._portraitViewportActive or (key and card._portraitCommittedKey ~= key) then
            W.ApplyOpponentPortrait(card, card.enemy)
        end
    end
end

function W.SetSummaryCardPortraitMode(card, enabled, contentWidth)
    if not card then return end
    local inset = enabled and 58 or 8
    card._portraitEnabled = enabled and true or false
    if card.portraitFrame then card.portraitFrame:SetShown(enabled) end
    local anchor = card.visual or card
    local textAnchor = card.content or anchor
    contentWidth = contentWidth or card._plaqueBaseWidth or card:GetWidth() or 334
    local progress = tonumber(card._hoverProgress) or 0
    local uiScale = card.GetEffectiveScale and card:GetEffectiveScale() or 1
    local function Pixel(value) return math.floor(value * uiScale + .5) / uiScale end

    -- The row itself never scales. All rows remain locked to the same right-hand
    -- guide so the hover treatment cannot make the border grow or wander.
    if card.visual then
        card.visual:ClearAllPoints()
        card.visual:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
        card.visual:SetSize(Pixel(contentWidth), 47)
    end
    if card.content then
        card.content:SetScale(1)
        card.content:SetSize(contentWidth, 47)
        card.content:ClearAllPoints()
        card.content:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    end

    -- Portrait rows keep the normal rounded Blizzard border, but move only its
    -- LEFT rounded end well outside the row's clip. That leaves the top/bottom
    -- rails physically continuing underneath the portrait instead of chopping
    -- them off at a rectangular clip edge. A narrow matte plus the circular
    -- portrait matte cover the hidden rail segment, so no square cap or left
    -- corner can ever be visible beside the medallion.
    if card.borderClip and card.border then
        card.borderClip:ClearAllPoints()
        card.border:ClearAllPoints()
        card.borderClip:SetAllPoints(anchor)
        if enabled then
            local hiddenExtension = Pixel(18)
            card.border:SetPoint("TOPLEFT", card.borderClip, "TOPLEFT", -hiddenExtension, 0)
            card.border:SetPoint("BOTTOMRIGHT", card.borderClip, "BOTTOMRIGHT", 0, 0)
        else
            card.border:SetAllPoints(card.borderClip)
        end
        if card.border.UpdatePixelSize then card.border:UpdatePixelSize() end
    elseif card.border then
        card.border:ClearAllPoints(); card.border:SetAllPoints(anchor)
        if card.border.UpdatePixelSize then card.border:UpdatePixelSize() end
    end

    if card.bg then
        card.bg:ClearAllPoints()
        card.bg:SetPoint("TOPLEFT", anchor, "TOPLEFT", 2, -2)
        card.bg:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -2, 2)
    end
    if card.hoverWash then
        card.hoverWash:ClearAllPoints()
        card.hoverWash:SetPoint("TOPLEFT", anchor, "TOPLEFT", 3, -3)
        card.hoverWash:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -3, 3)
        card.hoverWash:SetAlpha(.72 * progress)
    end
    if card.portraitBorderMatteTop and card.portraitBorderMatteBottom then
        -- Only hide the exposed TOP/BOTTOM rail segments to the left of the
        -- circular medallion.  A full-height matte fixed the rail escape but also
        -- sat over the 46px portrait opening and visibly shaved off its left side.
        -- These two shallow occluders cover the tooltip border only; the portrait
        -- viewport/camera/mask remain completely untouched.
        local railMatteWidth = Pixel(16)
        local railMatteHeight = Pixel(6)

        card.portraitBorderMatteTop:ClearAllPoints()
        card.portraitBorderMatteTop:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        card.portraitBorderMatteTop:SetSize(railMatteWidth, railMatteHeight)
        card.portraitBorderMatteTop:SetShown(enabled)

        card.portraitBorderMatteBottom:ClearAllPoints()
        card.portraitBorderMatteBottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
        card.portraitBorderMatteBottom:SetSize(railMatteWidth, railMatteHeight)
        card.portraitBorderMatteBottom:SetShown(enabled)
    end

    -- Hover feedback stays on the portrait/copy. The circular occluder is a child
    -- of portraitFrame, so it follows the exact same tiny shift/scale. It is
    -- deliberately smaller than the 56px ring: the plaque rails are supposed to
    -- continue underneath the outer medallion and visually meet its rim, while
    -- the inner portrait area still blocks the rail from showing through.
    local nudge = Pixel(2 * progress)
    card.name:ClearAllPoints(); card.name:SetPoint("TOPLEFT", textAnchor, "TOPLEFT", inset - nudge, -4)
    card.status:ClearAllPoints(); card.status:SetPoint("TOPLEFT", textAnchor, "TOPLEFT", inset - nudge, -17)
    card.record:ClearAllPoints(); card.record:SetPoint("TOPLEFT", textAnchor, "TOPLEFT", inset - nudge, -30)
    if card.state then
        card.state:ClearAllPoints(); card.state:SetPoint("TOPRIGHT", textAnchor, "TOPRIGHT", -8 - nudge, -4)
    end
    if card.portraitFrame then
        card.portraitFrame:ClearAllPoints()
        card.portraitFrame:SetPoint("LEFT", textAnchor, "LEFT", -Pixel(progress), 0)
        card.portraitFrame:SetScale(1 + .035 * progress)
    end

    card.name:SetWidth(math.max(92, contentWidth - inset - 150))
    card.status:SetWidth(math.max(100, contentWidth - inset - 8))
    card.record:SetWidth(math.max(100, contentWidth - inset - 8))
end

local function SetSummaryCardLift(card, active)
    if not card or not card.visual then return end
    card._hoverTarget = active and 1 or 0
    SetSummaryCardHitArea(card, active)

    local window = W.details
    local scroll = window and window.summaryRivalsScroll
    if active and scroll and card.summaryRowTop then
        local height = scroll:GetHeight() or 0
        local current = scroll:GetVerticalScroll() or 0
        local range = math.max(0, (window.summaryRivalsBody:GetHeight() or 0) - height)
        local top = card.summaryRowTop - 8
        local bottom = card.summaryRowTop + card:GetHeight() + 8
        local target = current
        if bottom > current + height then target = bottom - height end
        if top < target then target = top end
        target = Clamp(target, 0, range)
        if height > 0 and target ~= current then
            scroll:ScrollTo(target)
        end
    end

    if card:GetScript("OnUpdate") then return end
    card:SetScript("OnUpdate", function(self, elapsed)
        local current = tonumber(self._hoverProgress) or 0
        local target = tonumber(self._hoverTarget) or 0
        local duration = target > current and .045 or .060
        local delta = math.max(.001, tonumber(elapsed) or 0) / duration
        if target > current then current = math.min(target, current + delta)
        else current = math.max(target, current - delta) end
        self._hoverProgress = current

        -- Hover feedback lives inside the row now; the border itself never
        -- changes geometry, so it cannot thicken or flicker during the bump.
        W.SetSummaryCardPortraitMode(self, self._portraitEnabled, self._plaqueBaseWidth or self:GetWidth())

        if current == target then
            if target == 0 then SetSummaryCardHitArea(self, false) end
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function W.OpenOpponentMatchup(enemy)
    if not enemy or not DP.SelectDuelView then return end
    if DP.ShowRivalsCharacterPanel and DP.ShowRivalsCharacterPanel() == false then return end
    if DP.SetMatchupSource then DP.SetMatchupSource("world") end
    DP.SelectDuelView("MatchupDetail", {kind="opponent", key=enemy.guid or enemy.name, world=true}, enemy.name, "Opponents")
    if GameTooltip then GameTooltip:Hide() end
end

local function EnsureSummaryRivalCard(window, index)
    local card = window.summaryRivalCards[index]
    if card then return card end
    card = CreateFrame("Frame", nil, window.summaryRivalsBody)
    card:SetSize(334, 47)
    card.visual = CreateFrame("Frame", nil, card)
    card.visual:SetAllPoints(card)
    card.visual:SetFrameLevel(card:GetFrameLevel())

    -- Border clipping is separate from the portrait/content hierarchy. Portrait
    -- rows shift the native rounded border's left corners outside this clip while
    -- leaving its horizontal rails running underneath the medallion.
    card.borderClip = CreateFrame("Frame", nil, card.visual)
    card.borderClip:SetAllPoints(card.visual)
    card.borderClip:SetFrameLevel(card.visual:GetFrameLevel())
    if card.borderClip.SetClipsChildren then card.borderClip:SetClipsChildren(true) end
    card.border = DP.Theme.PlaqueBorder(card.borderClip, 334, 47)
    card.border:SetAllPoints(card.borderClip)
    card.bg = card.visual:CreateTexture(nil, "BACKGROUND"); card.bg:SetAllPoints(card.visual); card.bg:SetColorTexture(.045, .055, .07, .92)
    card.bg:SetDrawLayer("BACKGROUND", -8)
    card.hoverWash = card.visual:CreateTexture(nil, "BACKGROUND")
    card.hoverWash:SetPoint("TOPLEFT", card.border, "TOPLEFT", 3, -3)
    card.hoverWash:SetPoint("BOTTOMRIGHT", card.border, "BOTTOMRIGHT", -3, 3)
    card.hoverWash:SetColorTexture(.48, .34, .18, .10)
    card.hoverWash:SetDrawLayer("BACKGROUND", -7)
    card.hoverWash:SetAlpha(0)
    card.content = CreateFrame("Frame", nil, card.visual)
    card.content:SetPoint("CENTER", card.visual, "CENTER", 0, 0)
    card.content:SetSize(334, 47)
    card.content:SetFrameLevel(card.border:GetFrameLevel() + 2)

    -- This matte covers the tiny rail segment that lies to the LEFT of the
    -- portrait circle. The rounded border itself still continues underneath the
    -- portrait; we are only hiding the part that would otherwise look like a
    -- square-ended top/bottom corner beside the medallion.
    card.portraitBorderMatteFrame = CreateFrame("Frame", nil, card.visual)
    card.portraitBorderMatteFrame:SetFrameLevel(card.border:GetFrameLevel() + 1)
    card.portraitBorderMatteFrame:SetAllPoints(card.visual)

    -- Two shallow rail mattes instead of one full-height left strip.  The native
    -- rounded border is extended left so its actual corners remain outside the
    -- row clip; these mattes hide only the short horizontal rails that would be
    -- visible in the crescent outside the medallion.  Because neither matte spans
    -- the portrait's vertical opening, they cannot crop the 3D portrait.
    card.portraitBorderMatteTop = card.portraitBorderMatteFrame:CreateTexture(nil, "BACKGROUND")
    card.portraitBorderMatteTop:SetColorTexture(.045, .055, .07, 1)
    card.portraitBorderMatteTop:Hide()
    card.portraitBorderMatteBottom = card.portraitBorderMatteFrame:CreateTexture(nil, "BACKGROUND")
    card.portraitBorderMatteBottom:SetColorTexture(.045, .055, .07, 1)
    card.portraitBorderMatteBottom:Hide()

    card.portraitFrame = CreateFrame("Frame", nil, card.content)
    card.portraitFrame:SetSize(56, 56); card.portraitFrame:SetPoint("LEFT", card.content, "LEFT", 0, 0)
    card.portraitFrame:SetFrameLevel(card.content:GetFrameLevel() + 1)

    -- ModelScene actors cannot use a Texture mask directly. The 46px viewport
    -- fills the medallion opening; the opaque cover above the model hides its
    -- square corners. Camera FOV compensates for viewport size so calibration
    -- retains the same face magnification while exposing more around its edges.
    card.portraitViewport = CreateFrame("Frame", nil, card.portraitFrame)
    card.portraitViewport:SetSize(46, 46); card.portraitViewport:SetPoint("CENTER", 0, 0)
    card.portraitViewport:SetFrameLevel(card.portraitFrame:GetFrameLevel() + 1)
    if card.portraitViewport.SetClipsChildren then card.portraitViewport:SetClipsChildren(true) end

    -- Opaque circular matte behind the *inner* portrait, not the whole 56px ring.
    -- Leaving the outer 4px of the medallion unoccluded lets the plaque's top and
    -- bottom rails visibly travel beneath the ring instead of stopping short.
    card.portraitOccluder = card.portraitFrame:CreateTexture(nil, "BACKGROUND")
    card.portraitOccluder:SetSize(48, 48); card.portraitOccluder:SetPoint("CENTER")
    card.portraitOccluder:SetColorTexture(.045, .055, .07, 1)
    if card.portraitOccluder.AddMaskTexture and card.portraitFrame.CreateMaskTexture then
        card.portraitOccluderMask = card.portraitFrame:CreateMaskTexture()
        card.portraitOccluderMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        card.portraitOccluderMask:SetSize(48, 48); card.portraitOccluderMask:SetPoint("CENTER")
        card.portraitOccluder:AddMaskTexture(card.portraitOccluderMask)
    end

    card.portrait = card.portraitFrame:CreateTexture(nil, "ARTWORK")
    card.portrait:SetSize(46, 46); card.portrait:SetPoint("CENTER")
    if card.portrait.AddMaskTexture and card.portraitFrame.CreateMaskTexture then
        card.portraitMask = card.portraitFrame:CreateMaskTexture()
        card.portraitMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        card.portraitMask:SetSize(46, 46); card.portraitMask:SetPoint("CENTER")
        card.portrait:AddMaskTexture(card.portraitMask)
    end
    card.portraitModel = CreateFrame("DressUpModel", nil, card.portraitViewport)
    card.portraitModel:SetPoint("CENTER", 0, 0); card.portraitModel:SetSize(46, 46)
    card.portraitModel:SetFrameLevel(card.portraitFrame:GetFrameLevel() + 1)
    if card.portraitModel.SetKeepModelOnHide then card.portraitModel:SetKeepModelOnHide(true) end
    card.portraitModel:SetScript("OnModelLoaded", function(self)
        if self.SetPortraitZoom then pcall(self.SetPortraitZoom, self, 1) end
        if self.SetCamDistanceScale then pcall(self.SetCamDistanceScale, self, .88) end
        if self._rivalsHeadItem then
            if self.SetItem then pcall(self.SetItem, self, self._rivalsHeadItem)
            elseif self.TryOn then pcall(self.TryOn, self, self._rivalsHeadItem) end
        end
    end)
    card.portraitModel:Hide()

    -- Loading indicator: keep its own 46px coordinate system explicitly centered
    -- on the 56px medallion, rather than inheriting any viewport offsets. The dots
    -- use a circular alpha texture and a continuously interpolated tail so there
    -- are no square blocks or stepwise size jumps.
    card.portraitSpinnerFrame = CreateFrame("Frame", nil, card.portraitFrame)
    card.portraitSpinnerFrame:SetSize(46, 46)
    card.portraitSpinnerFrame:SetPoint("CENTER", card.portraitFrame, "CENTER", -1, 1)
    card.portraitSpinnerFrame:SetFrameLevel(card.portraitFrame:GetFrameLevel() + 19)
    card.portraitSpinnerFrame.dots = {}
    local spinnerRadius = 7.1
    local spinnerDots = 10
    for i = 1, spinnerDots do
        local dot = card.portraitSpinnerFrame:CreateTexture(nil, "OVERLAY")
        dot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        dot:SetTexCoord(0, 1, 0, 1)
        local angle = (math.pi / 2) - ((i - 1) / spinnerDots) * (math.pi * 2)
        dot:SetPoint("CENTER", card.portraitSpinnerFrame, "CENTER", math.cos(angle) * spinnerRadius, math.sin(angle) * spinnerRadius)
        dot:SetSize(2.6, 2.6)
        dot:SetVertexColor(1, .82, .42, 1)
        dot:SetAlpha(.09)
        card.portraitSpinnerFrame.dots[i] = dot
    end
    card.portraitSpinnerFrame:SetScript("OnShow", function(self)
        self._phase = 0
    end)
    card.portraitSpinnerFrame:SetScript("OnUpdate", function(self, elapsed)
        self._phase = ((self._phase or 0) + elapsed * 6.5) % spinnerDots
        for idx, dot in ipairs(self.dots or {}) do
            local behind = (self._phase - (idx - 1)) % spinnerDots
            local strength = math.exp(-behind * 1.2)
            local size = 1.1 + strength * 2.7
            dot:SetSize(size, size)
            dot:SetAlpha(.06 + strength * .42)
        end
    end)
    card.portraitSpinnerFrame:Hide()

    -- Keep the circular ModelScene occluder on its own layer.  The cover exists
    -- only to hide the square 3D render target outside the medallion opening; it
    -- must not also erase the plaque rails that visually continue underneath the
    -- gold ring.  The previous build parented this cover to portraitRingFrame,
    -- putting it above the plaque border and recreating the detached-border gap.
    card.portraitCoverFrame = CreateFrame("Frame", nil, card.portraitFrame)
    card.portraitCoverFrame:SetAllPoints(card.portraitFrame)
    card.portraitCoverFrame:SetFrameLevel(card.portraitFrame:GetFrameLevel() + 10)
    if DP.Portraits and DP.Portraits.AddPortraitCover then
        card.portraitRoundCover = DP.Portraits.AddPortraitCover(card.portraitCoverFrame)
    end

    -- Layer the plaque edge between the portrait cover and the visible gold ring.
    -- This preserves the working portrait crop, lets the top/bottom rails pass
    -- beneath the medallion, and keeps the shifted/clipped left tooltip corners
    -- hidden exactly as SetSummaryCardPortraitMode already intends.
    local plaqueBridgeLevel = card.portraitCoverFrame:GetFrameLevel() + 1
    if card.borderClip and card.borderClip.SetFrameLevel then
        card.borderClip:SetFrameLevel(plaqueBridgeLevel)
    end
    if card.border and card.border.SetFrameLevel then
        card.border:SetFrameLevel(plaqueBridgeLevel)
    end
    if card.portraitBorderMatteFrame and card.portraitBorderMatteFrame.SetFrameLevel then
        card.portraitBorderMatteFrame:SetFrameLevel(plaqueBridgeLevel + 1)
    end

    card.portraitRingFrame = CreateFrame("Frame", nil, card.portraitFrame)
    card.portraitRingFrame:SetAllPoints(card.portraitFrame)
    card.portraitRingFrame:SetFrameLevel(card.portraitFrame:GetFrameLevel() + 20)
    card.portraitRing = card.portraitRingFrame:CreateTexture(nil, "OVERLAY")
    card.portraitRing:SetPoint("CENTER"); card.portraitRing:SetSize(56, 56)
    local ringOK = card.portraitRing.SetAtlas and pcall(card.portraitRing.SetAtlas, card.portraitRing, "AdventureMap-combatally-ring", false)
    if not ringOK then
        card.portraitRing:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        card.portraitRing:SetTexCoord(0, 1, 0, 1)
    end
    card.portraitFrame:Hide()

    card.name = card.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); card.name:SetPoint("TOPLEFT", 8, -4); card.name:SetWidth(164); card.name:SetJustifyH("LEFT"); card.name:SetWordWrap(false)
    card.state = card.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); card.state:SetPoint("TOPRIGHT", -8, -4); card.state:SetWidth(142); card.state:SetJustifyH("RIGHT"); card.state:SetWordWrap(false)
    card.status = card.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); card.status:SetPoint("TOPLEFT", 8, -17); card.status:SetWidth(318); card.status:SetJustifyH("LEFT"); card.status:SetWordWrap(false)
    card.record = card.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); card.record:SetPoint("TOPLEFT", 8, -30); card.record:SetWidth(318); card.record:SetJustifyH("LEFT"); card.record:SetWordWrap(false)
    card:EnableMouse(true); card:EnableMouseWheel(true)
    card:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.kind == "player" then W.OpenOpponentMatchup(self.enemy) end
    end)
    if card.SetHitRectInsets then card:SetHitRectInsets(-5, -5, -4, -4) end
    card:SetScript("OnMouseWheel", function(_, delta) if window.summaryRivalsScroll and window.summaryRivalsScroll.ScrollByWheel then window.summaryRivalsScroll:ScrollByWheel(delta) end end)
    card:SetScript("OnEnter", function(self)
        SetSummaryCardLift(self, true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.kind == "npc" then
            AddNPCRecordTooltip(self.npc)
        elseif self.enemy then
            AddOpponentRecordTooltip(self.enemy, self.stats, window.record)
        else
            return
        end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function(self)
        SetSummaryCardLift(self, false)
        GameTooltip:Hide()
    end)
    window.summaryRivalCards[index] = card
    return card
end

local function UpdateSummaryExchangeStat(row, gross, recovery)
    if not row then return end
    gross = math.max(0, tonumber(gross) or 0)
    recovery = math.max(0, tonumber(recovery) or 0)
    row.value:SetText(CompactCombatNumber(gross))
    row.recoveryValue:SetText(CompactCombatNumber(recovery))
    -- Keep both recovery rows visually identical at rest. Hover supplies the
    -- green emphasis; zero vs. nonzero is communicated by the number itself.
    row.recoveryLabel:SetAlpha(1)
    row.recoveryValue:SetAlpha(1)
end

local function RepairLegacyConsumableCostOnDemand(record)
    if type(record) ~= "table" or not DP.Usage then return false end
    local changed = DP.Usage.SanitizeConsumableCostSnapshot and DP.Usage.SanitizeConsumableCostSnapshot(record) or false

    -- 0.21.154 expands current-encounter capture to include retained opponent
    -- consumable buffs and repairs duplicate item-use signals. Rebuild affected
    -- non-legacy snapshots once from their saved encounter evidence, then freeze
    -- the new result normally.
    local currentCost = record.consumableCost
    if type(currentCost) == "table" and not currentCost.backfilled and
            (tonumber(currentCost.captureModelVersion) or 0) < 2 and
            record.session and DP.Usage.CaptureWorldConsumableCost then
        local rebuilt = DP.Usage.CaptureWorldConsumableCost(record.session, {
            capturedAt = tonumber(currentCost.capturedAt) or (time and time() or 0),
        })
        if rebuilt then
            record.consumableCost = rebuilt
            currentCost = rebuilt
            changed = true
        end
    end

    if not DP.Usage.CaptureLegacyWorldConsumableCost then
        if changed and W.callbacks and W.callbacks.changed then W.callbacks.changed() end
        return changed
    end
    local needs = DP.Usage.NeedsLegacyConsumableBackfill and DP.Usage.NeedsLegacyConsumableBackfill(record)
    if not needs then
        if changed and W.callbacks and W.callbacks.changed then W.callbacks.changed() end
        return changed
    end

    -- Details are opened well after PLAYER_LOGIN, so TSM/Auctionator are normally
    -- fully initialized here. Repairing from the exact same retained encounter
    -- evidence used by Items & Abilities closes the gap left by a missed startup
    -- migration and then freezes this replacement snapshot normally.
    local snapshot = DP.Usage.CaptureLegacyWorldConsumableCost(record, time and time() or 0, {}, true)
    if not snapshot then return false end
    snapshot.legacyBackfillAttempt = math.max(3, tonumber(snapshot.legacyBackfillAttempt) or 0)
    record.consumableCost = snapshot
    if W.callbacks and W.callbacks.changed then W.callbacks.changed() end
    return true
end

function W.RefreshDetailContent()
    local window = W.details
    local record = window and window.record
    if not window or not record then return end
    RepairLegacyConsumableCostOnDemand(record)
    if window.consumableCostTooltip then window.consumableCostTooltip:Hide() end
    if window.damageExchangeTooltip then window.damageExchangeTooltip:Hide() end
    local tab = window.activeTab or "summary"
    window.summaryStatsTitle:SetShown(tab == "summary")
    window.summaryStatsBox:SetShown(tab == "summary")
    window.summaryRivalsTitle:SetShown(tab == "summary")
    window.summaryRivalsBox:SetShown(tab == "summary")
    window.summaryRivalsScroll:SetShown(tab == "summary")
    if tab ~= "summary" then
        for _, card in ipairs(window.summaryRivalCards or {}) do
            if DP.Portraits and DP.Portraits.ReleaseBody then DP.Portraits.ReleaseBody(card) end
            card._portraitViewportActive = false
        end
    end
    if tab ~= "summary" and window.summaryRivalsScrollbar then window.summaryRivalsScrollbar:Hide() end
    window.filter:SetShown(tab == "usage")
    window.usageHeader:SetShown(tab == "usage")
    window.usageScroll:SetShown(tab == "usage")
    if tab ~= "usage" and window.usageScrollbar then window.usageScrollbar:Hide() end
    window.logBox:SetShown(tab == "log")
    window.logScroll:SetShown(tab == "log")
    if tab ~= "log" and window.logScrollbar then window.logScrollbar:Hide() end

    if tab == "summary" then
        window:SetHeight(DETAIL_PAGE_HEIGHT)
        local cost = record.consumableCost
        local costText = cost and (cost.backfilled and cost.legacyReconstructedFrom == "no-retained-events" and "|cff888f99—|r" or
            ((cost.pricedCount or 0) == 0 and (cost.unpricedCount or 0) > 0 and "|cff888f99—|r" or FormatMoneyIcons(cost.totalCopper or 0, cost.partial))) or "|cff888f99—|r"
        window.summaryKillsValue:SetText(tostring(record.enemyDeaths or 0))
        window.summaryKBValue:SetText(tostring(record.killingBlows or 0))
        window.summaryConsumedValue:SetText(costText:gsub(":12:12:", ":13:13:"))

        local exchange = BuildDamageExchange(record)
        UpdateSummaryExchangeStat(window.summaryDamageDealt, exchange.dealt, exchange.enemyRecovery)
        UpdateSummaryExchangeStat(window.summaryDamageTaken, exchange.taken, exchange.playerRecovery)

        local matchupData = W.BuildMatchups()
        local opponentStats = {}
        for _, stats in ipairs(matchupData.Opponents or {}) do opponentStats[stats.key] = stats end
        local enemies = record.enemies or {}
        local npcs = EncounterNPCs(record)
        local totalCards = #enemies + #npcs
        local preservePortraits = window._portraitRecord == record
        for _, card in ipairs(window.summaryRivalCards or {}) do
            if not preservePortraits then
                if DP.Portraits and DP.Portraits.ReleaseBody then DP.Portraits.ReleaseBody(card) end
                card._portraitViewportActive = false
                card._portraitCommittedKey = nil
                card._portraitCommittedEnemy = nil
            end
            if card.visual and card.visual:GetParent() ~= card then
                card._hoverTarget, card._hoverProgress = 0, 0
                card:SetScript("OnUpdate", nil)
                card.visual:SetScale(1)
                card.visual:SetParent(card)
                card.visual:ClearAllPoints(); card.visual:SetAllPoints(card)
                card.visual:SetFrameLevel(card:GetFrameLevel())
            end
            if not preservePortraits then card:Hide() end
        end
        if window.summaryRivalsEmpty then window.summaryRivalsEmpty:Hide() end
        window.summaryRivalsScroll.smoothTarget = 0
        window.summaryRivalsScroll:SetVerticalScroll(0)

        local cardIndex = 0
        for _, enemy in ipairs(enemies) do
            cardIndex = cardIndex + 1
            local card = EnsureSummaryRivalCard(window, cardIndex)
            card.summaryRowTop = 8 + ((cardIndex - 1) * SUMMARY_RIVAL_ROW_STEP)
            card:ClearAllPoints(); card:SetPoint("TOPRIGHT", window.summaryRivalsBody, "TOPRIGHT", -5, -card.summaryRowTop)
            local key = enemy.guid or enemy.name
            local stats = opponentStats[key] or {}
            local className = enemy.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[enemy.class]) or enemy.class) or "Unknown"
            local levelText = enemy.level and ("Lv " .. tostring(enemy.level)) or "Lv ?"
            local raceText = enemy.race and tostring(enemy.race) or "Unknown race"
            local spec = enemy.spec and enemy.spec.label
            card.kind, card.npc = "player", nil
            card.enemy, card.stats = enemy, stats
            card.bg:SetColorTexture(.045, .055, .07, .92)
            W.SetSummaryCardPortraitMode(card, true, card._plaqueBaseWidth or card:GetWidth())
            -- Portraits are requested by RefreshVisibleOpponentPortraits after layout.
            card.name:SetText(DP.Theme.ClassName(ShortName(enemy.name), enemy.class))
            local gank = enemy.died and GankKind(record, enemy)
            local bubbleHearth = enemy.bubbleHearthed or (record.bubbleHearthEnemyGUID and record.bubbleHearthEnemyGUID == enemy.guid)
            local state = bubbleHearth and "|cffffce70Bubble Hearthed|r" or gank == "lowbie" and "|cffff8888Lowbie gank|r" or gank == "gank" and "|cffffad66Gank|r" or enemy.died and "|cffff8888Dead|r" or "|cff65e6adSurvived|r"
            if enemy.killingBlow then state = state .. "  |cffffce70KB|r" end
            card.state:SetText(state)
            card.status:SetText(levelText .. " " .. raceText .. " " .. className .. (spec and (" • " .. spec) or ""))
            card.record:SetText(string.format("W |cff65e6ad%d|r-|cffff8888%d|r  •  S |cff65e6ad%d|r-|cffff8888%d|r  •  %d enc",
                stats.kills or 0, stats.deaths or 0, stats.soloKills or 0, stats.soloDeaths or 0,
                stats.encounters or 0))
            card:Show()
        end

        for _, npc in ipairs(npcs) do
            cardIndex = cardIndex + 1
            local card = EnsureSummaryRivalCard(window, cardIndex)
            card.summaryRowTop = 8 + ((cardIndex - 1) * SUMMARY_RIVAL_ROW_STEP)
            card:ClearAllPoints(); card:SetPoint("TOPRIGHT", window.summaryRivalsBody, "TOPRIGHT", -5, -card.summaryRowTop)
            card.kind, card.npc = "npc", npc
            card.enemy, card.stats = nil, nil
            card._portraitViewportActive = false
            W.SetSummaryCardPortraitMode(card, false, card._plaqueBaseWidth or card:GetWidth())
            card.bg:SetColorTexture(.075, .055, .035, .94)
            local npcName = tostring(npc.name or "NPC") .. (((npc.count or 0) > 1) and (" ×" .. tostring(npc.count)) or "")
            card.name:SetText("|cffffad66" .. npcName .. "|r")
            local interfered = (npc.damageToPlayer or 0) > 0 or (npc.healingToEnemies or 0) > 0
            local assisted = (npc.damageToEnemies or 0) > 0 or (npc.healingToPlayer or 0) > 0
            card.state:SetText(interfered and "|cffffad66NPC interference|r" or assisted and "|cff65e6adNPC assistance|r" or "|cffffce70NPC involved|r")
            if (npc.damageToPlayer or 0) > 0 then
                card.status:SetText("NPC • " .. CompactCombatNumber(npc.damageToPlayer) .. " damage to you")
            elseif (npc.damageToEnemies or 0) > 0 then
                card.status:SetText("NPC • " .. CompactCombatNumber(npc.damageToEnemies) .. " damage to enemy players")
            elseif (npc.healingToEnemies or 0) > 0 then
                card.status:SetText("NPC • " .. CompactCombatNumber(npc.healingToEnemies) .. " healing to enemy players")
            elseif (npc.healingToPlayer or 0) > 0 then
                card.status:SetText("NPC • " .. CompactCombatNumber(npc.healingToPlayer) .. " healing to you")
            else
                card.status:SetText("NPC participant")
            end
            card.record:SetText(((npc.count or 0) > 1 and (tostring(npc.count) .. " NPCs • ") or "") .. "not counted in NvN")
            card:Show()
        end

        if totalCards == 0 and window.summaryRivalsEmpty then
            window.summaryRivalsEmpty:SetText("|cffadb5c2No opponent or NPC identity was retained for this encounter.|r")
            window.summaryRivalsEmpty:Show()
        end
        for index = totalCards + 1, #window.summaryRivalCards do
            local card = window.summaryRivalCards[index]
            if DP.Portraits and DP.Portraits.ReleaseBody then DP.Portraits.ReleaseBody(card) end
            card._portraitViewportActive = false
            card._portraitCommittedKey = nil
            card._portraitCommittedEnemy = nil
            card:Hide()
        end
        window.summaryRivalsBody:SetHeight(math.max(196, 16 + totalCards * SUMMARY_RIVAL_ROW_STEP))
        window.summaryRivalsScroll.smoothTarget = 0
        window.summaryRivalsScroll:SetVerticalScroll(0)
        if window.summaryRivalsScroll.UpdateScrollHints then window.summaryRivalsScroll:UpdateScrollHints() end
        W.RefreshVisibleOpponentPortraits(window)
        window._portraitRecord = record
    elseif tab == "usage" then
        local filter = window.participantFilter or "all"
        -- Let the dropdown resolve its own display text so participant names keep
        -- their class coloring in both the closed selector and the opened menu.
        window.filter:SetSelectedValue(filter)
        local events = UsageEvents(record, filter)
        -- Resolve the display/category *before* sorting. Some retained events are
        -- recorded under their raw spell category and only later resolve to a
        -- different UI category (PvP Insignias are the obvious example: the raw
        -- activation looks like a long cooldown, but the UI correctly renders it
        -- as EQUIPMENT). Sorting the raw events first could therefore create two
        -- EQUIPMENT or two COOLDOWNS plaques for different participants. Build a
        -- normalized render list so each category appears exactly once.
        local renderedEvents = {}
        for _, entry in ipairs(events) do
            local display = DescribeWorldUsage(entry, record)
            local category = display.category or entry.category or "cooldowns"
            -- Reagents are cost inputs, not encounter actions. Keep their gold
            -- contribution in Consumable Cost without duplicating them as rows in
            -- Items & Abilities.
            if category ~= "reagents" then
                renderedEvents[#renderedEvents + 1] = {
                    entry = entry,
                    display = display,
                    category = category,
                }
            end
        end
        table.sort(renderedEvents, function(a, b)
            local ao, bo = CATEGORY_ORDER[a.category] or 99, CATEGORY_ORDER[b.category] or 99
            if ao ~= bo then return ao < bo end
            local at, bt = tonumber(a.entry.t) or 0, tonumber(b.entry.t) or 0
            if at ~= bt then return at < bt end
            return tostring(a.entry.guid or "") < tostring(b.entry.guid or "")
        end)
        local y, rowIndex, dataRowIndex, lastCategory = 0, 0, 0
        for _, rendered in ipairs(renderedEvents) do
            local entry = rendered.entry
            local display = rendered.display
            local category = rendered.category
            if category ~= lastCategory then
                rowIndex = rowIndex + 1
                local header = EnsureUsageRow(window, rowIndex, "category")
                header.categoryKey = category
                header:ClearAllPoints(); header:SetPoint("TOPLEFT", 0, -y); header.bg:SetColorTexture(.09, .07, .035, .92)
                header.label:SetText("|cffffd86a" .. (CATEGORY_LABEL[category] or category) .. "|r"); header:Show(); y = y + 26
                lastCategory = category
            end
            rowIndex = rowIndex + 1
            dataRowIndex = dataRowIndex + 1
            local row = EnsureUsageRow(window, rowIndex, "entry")
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y)
            if dataRowIndex % 2 == 0 then row.bg:SetColorTexture(.085, .085, .085, .72)
            else row.bg:SetColorTexture(.035, .035, .035, .82) end
            row.time:SetText(string.format("%05.1f", entry.t or 0))
            local identity = record.session and record.session.participants and record.session.participants[entry.guid]
            local playerName = entry.guid == record.playerGUID and "You" or ShortName((identity and identity.name) or entry.sourceName or entry.actorName or entry.name)
            row.player:SetText(DP.Theme.ClassName(playerName, identity and identity.class))
            row.used:SetText(display.text or entry.name or "Unknown")
            row.target:SetText(entry.displayTarget or (entry.targetName and ShortName(entry.targetName)) or "—")
            row.entry = {itemID = display.itemID or entry.itemID, spellID = display.spellID or entry.spellID}
            row:Show(); y = y + 22
        end
        if #renderedEvents == 0 then
            rowIndex = 1
            local row = EnsureUsageRow(window, rowIndex, "category")
            row.categoryKey = nil
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, 0)
            row.bg:SetColorTexture(.045, .055, .07, .6)
            row.label:SetText("|cffadb5c2No tracked item, engineering, racial, or ≥3 minute cooldown use for this filter.|r")
            row:Show()
            y = 26
        end
        for index = rowIndex + 1, #window.usageRows do window.usageRows[index]:Hide() end

        -- Body height describes only visible rows. The Items & Abilities page now
        -- uses the exact same outer window height and 20px side guides as Summary;
        -- long lists scroll inside that footprint instead of making the detail
        -- window grow taller than the other tabs.
        window.usageBody:SetHeight(math.max(1, y))
        window:SetHeight(DETAIL_PAGE_HEIGHT)
        if window.usageScroll.UpdateScrollHints then window.usageScroll:UpdateScrollHints() end
    elseif tab == "log" then
        local participants = record.session and record.session.participants or {}
        local logEntries = record.session and record.session.worldCombatLog or {}
        local inferredClassByGUID, inferredClassByName = {}, {}
        if record.playerGUID and record.playerClass then inferredClassByGUID[record.playerGUID] = record.playerClass end
        if record.session and record.session.playerGUID and record.playerClass then inferredClassByGUID[record.session.playerGUID] = record.playerClass end
        for guid, identity in pairs(participants) do
            if identity and identity.class then
                inferredClassByGUID[guid] = identity.class
                local short = ShortName(identity.name)
                if short and short ~= "Unknown" then inferredClassByName[short] = identity.class end
            end
        end
        -- Old/current records may have missed UnitClass/GetPlayerInfoByGUID while
        -- the fight was happening. Scan the retained log for class-exclusive
        -- abilities and recover the class before rendering any names.
        if DP.Specs and DP.Specs.InferClassFromAbility then
            for _, logEntry in ipairs(logEntries) do
                local class = logEntry.sourceGUID and inferredClassByGUID[logEntry.sourceGUID] or nil
                if not class and type(logEntry.event) == "string" and
                    (logEntry.event:match("^SPELL_") or logEntry.event:match("^RANGE_")) then
                    local spellID = tonumber(logEntry.spellID)
                    local spellName = type(logEntry.spellName) == "string" and logEntry.spellName or nil
                    if spellID or spellName then class = DP.Specs.InferClassFromAbility(spellID, spellName) end
                end
                if class and logEntry.sourceGUID then
                    inferredClassByGUID[logEntry.sourceGUID] = class
                    local identity = participants[logEntry.sourceGUID]
                    if identity and not identity.class then identity.class = class end
                end
                local short = ShortName(logEntry.sourceName)
                if class and short and short ~= "Unknown" then inferredClassByName[short] = class end
            end
        end
        local function ParticipantText(guid, fallback)
            local identity = participants[guid]
            local name = ShortName(fallback or (identity and identity.name) or "")
            if not name or name == "" or name == "Unknown" then
                name = guid and "Unidentified" or "target"
            end
            local class = (identity and identity.class) or inferredClassByGUID[guid] or inferredClassByName[name]
            return class and DP.Theme.ClassName(name, class) or name
        end
        local function AmountText(amount, heal)
            if not amount then return "" end
            return heal and ("|cff65e6ad" .. tostring(math.floor(amount + .5)) .. "|r") or ("|cffff8888" .. tostring(math.floor(amount + .5)) .. "|r")
        end
        local function SpellKey(entry)
            if not entry then return nil end
            local name = type(entry.spellName) == "string" and entry.spellName:lower() or nil
            if name and name ~= "" then return "name:" .. name end
            local id = tonumber(entry.spellID)
            return id and ("id:" .. tostring(id)) or nil
        end
        local castBySourceSpell = {}
        local recentOwnerBySpell = {}
        local resolvedSourceByEntry = setmetatable({}, {__mode = "k"})
        local reflectedCastByEntry = setmetatable({}, {__mode = "k"})
        local reflectedMissByEntry = setmetatable({}, {__mode = "k"})
        local recentCastEntryBySourceSpell = {}
        local activeReflectionBySourceSpell = {}
        local activeReflectorByGUID = {}
        local castReflectorByEntry = setmetatable({}, {__mode = "k"})
        local reflectedAuraOwnerByKey = {}
        local selfAuraTimesBySourceSpell = {}
        local selfCastByEntry = setmetatable({}, {__mode = "k"})

        local function IsReflectorAuraName(name)
            name = type(name) == "string" and name:lower() or ""
            return name:find("reflector", 1, true) ~= nil
        end
        local function IsPhysicalSchool(school)
            school = tonumber(school)
            return school ~= nil and HasFlag(school, 0x1) and not HasFlag(school, 0x7E)
        end

        -- Build a tiny self-aura index first. CLEU often gives item/stance/self-buff
        -- casts an opaque destination GUID even though the effect immediately
        -- applies to the caster. This lets the renderer show "on <self>" instead
        -- of inventing an Unidentified target.
        for _, auraEntry in ipairs(logEntries) do
            local auraEvent = tostring(auraEntry.event or "")
            if (auraEvent == "SPELL_AURA_APPLIED" or auraEvent == "SPELL_AURA_REFRESH") and
                    auraEntry.sourceGUID and auraEntry.destGUID == auraEntry.sourceGUID then
                local auraKey = SpellKey(auraEntry)
                if auraKey then
                    local sourceAuraKey = tostring(auraEntry.sourceGUID) .. "|" .. auraKey
                    local rows = selfAuraTimesBySourceSpell[sourceAuraKey]
                    if not rows then rows = {}; selfAuraTimesBySourceSpell[sourceAuraKey] = rows end
                    rows[#rows + 1] = tonumber(auraEntry.t) or 0
                end
            end
        end

        for _, logEntry in ipairs(logEntries) do
            local key = SpellKey(logEntry)
            local event = tostring(logEntry.event or "")
            local sourceClass = inferredClassByGUID[logEntry.sourceGUID] or inferredClassByName[ShortName(logEntry.sourceName)]
            local abilityClass = DP.Specs and DP.Specs.InferClassFromAbility and
                DP.Specs.InferClassFromAbility(tonumber(logEntry.spellID), logEntry.spellName) or nil
            local sourceSpellKey = key and logEntry.sourceGUID and (tostring(logEntry.sourceGUID) .. "|" .. key) or nil
            if sourceSpellKey and event == "SPELL_CAST_SUCCESS" then
                castBySourceSpell[sourceSpellKey] = true
                recentCastEntryBySourceSpell[sourceSpellKey] = logEntry
                if logEntry.destGUID and logEntry.destGUID ~= logEntry.sourceGUID and activeReflectorByGUID[logEntry.destGUID] then
                    castReflectorByEntry[logEntry] = activeReflectorByGUID[logEntry.destGUID]
                end
                local selfAuraTimes = selfAuraTimesBySourceSpell[sourceSpellKey]
                if selfAuraTimes then
                    local castTime = tonumber(logEntry.t) or 0
                    for _, auraTime in ipairs(selfAuraTimes) do
                        if math.abs(auraTime - castTime) <= .75 then selfCastByEntry[logEntry] = true; break end
                    end
                end
            end

            -- Track engineering reflector uptime separately from reflected spell
            -- ownership. Inferred reflection is only allowed when the intended
            -- target actually had a reflector aura active at cast time.
            if IsReflectorAuraName(logEntry.spellName) and logEntry.destGUID then
                if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
                    activeReflectorByGUID[logEntry.destGUID] = {name = logEntry.spellName, t = tonumber(logEntry.t) or 0}
                elseif event == "SPELL_AURA_REMOVED" then
                    activeReflectorByGUID[logEntry.destGUID] = nil
                end
            end

            -- Blizzard usually reports a reflected spell as a REFLECT miss against
            -- the intended victim, then may attribute the returned damage/aura to the
            -- original caster in later CLEU rows. Preserve the cast itself but mark
            -- it REFLECTED and display the reflector as the owner of the returned
            -- hostile effect.
            if sourceSpellKey and (event == "SPELL_MISSED" or event == "RANGE_MISSED") and
                    tostring(logEntry.missType or ""):upper() == "REFLECT" then
                local castEntry = recentCastEntryBySourceSpell[sourceSpellKey]
                if castEntry and math.abs((tonumber(logEntry.t) or 0) - (tonumber(castEntry.t) or 0)) <= 2.0 then
                    reflectedCastByEntry[castEntry] = true
                    reflectedMissByEntry[logEntry] = true
                end
                activeReflectionBySourceSpell[sourceSpellKey] = {
                    t = tonumber(logEntry.t) or 0,
                    casterGUID = logEntry.sourceGUID,
                    casterName = logEntry.sourceName,
                    reflectorGUID = logEntry.destGUID,
                    reflectorName = logEntry.destName,
                }
            elseif sourceSpellKey and event ~= "SPELL_CAST_SUCCESS" then
                local reflection = activeReflectionBySourceSpell[sourceSpellKey]

                -- Some Classic combat-log sequences omit the SPELL_MISSED/REFLECT
                -- row entirely. Infer the reflection when an offensive spell was
                -- just cast at another player but its harmful result immediately
                -- lands back on the original caster. This matches cases such as a
                -- Shadow Reflector returning Death Coil: cast at Zurker, then the
                -- damage/aura is logged as Cpayne -> Cpayne. The cast destination
                -- is the reflector, so use that player as the returned spell owner.
                local harmfulReturnedEvent = event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or
                    event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH"
                if not reflection and harmfulReturnedEvent and logEntry.sourceGUID and
                        logEntry.destGUID == logEntry.sourceGUID then
                    local castEntry = recentCastEntryBySourceSpell[sourceSpellKey]
                    local activeReflector = castEntry and castReflectorByEntry[castEntry] or nil
                    if castEntry and activeReflector and castEntry.destGUID and castEntry.destGUID ~= castEntry.sourceGUID and
                            not IsPhysicalSchool(castEntry.spellSchool) and
                            math.abs((tonumber(logEntry.t) or 0) - (tonumber(castEntry.t) or 0)) <= 2.0 then
                        reflectedCastByEntry[castEntry] = true
                        reflection = {
                            t = tonumber(castEntry.t) or 0,
                            casterGUID = castEntry.sourceGUID,
                            casterName = castEntry.sourceName,
                            reflectorGUID = castEntry.destGUID,
                            reflectorName = castEntry.destName,
                            inferred = true,
                        }
                        activeReflectionBySourceSpell[sourceSpellKey] = reflection
                    end
                end

                local reflectedAuraKey = sourceSpellKey and logEntry.destGUID and
                    (sourceSpellKey .. "|" .. tostring(logEntry.destGUID)) or nil
                local persistentOwner = reflectedAuraKey and reflectedAuraOwnerByKey[reflectedAuraKey] or nil
                if persistentOwner and (event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_REFRESH") then
                    resolvedSourceByEntry[logEntry] = persistentOwner
                    if event == "SPELL_AURA_REMOVED" then reflectedAuraOwnerByKey[reflectedAuraKey] = nil end
                elseif reflection and (tonumber(logEntry.t) or 0) - reflection.t <= 3.0 and
                        logEntry.destGUID == reflection.casterGUID and
                        (event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or
                         event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_REMOVED") then
                    local owner = {
                        guid = reflection.reflectorGUID,
                        name = reflection.reflectorName,
                        class = inferredClassByGUID[reflection.reflectorGUID] or inferredClassByName[ShortName(reflection.reflectorName)],
                        t = logEntry.t,
                        reflected = true,
                    }
                    resolvedSourceByEntry[logEntry] = owner
                    if reflectedAuraKey and (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH") then
                        reflectedAuraOwnerByKey[reflectedAuraKey] = owner
                    elseif reflectedAuraKey and event == "SPELL_AURA_REMOVED" then
                        reflectedAuraOwnerByKey[reflectedAuraKey] = nil
                    end
                end
            end

            if key and abilityClass and sourceClass and sourceClass ~= abilityClass and
                    (event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_REFRESH") and
                    not resolvedSourceByEntry[logEntry] then
                local owner = recentOwnerBySpell[key]
                if owner and owner.class == abilityClass and
                        math.abs((tonumber(logEntry.t) or 0) - (tonumber(owner.t) or 0)) <= 30 then
                    resolvedSourceByEntry[logEntry] = owner
                end
            end
            if key and logEntry.sourceGUID and
                    (event == "SPELL_CAST_SUCCESS" or event == "SPELL_AURA_APPLIED" or event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE") and
                    (not abilityClass or not sourceClass or sourceClass == abilityClass) then
                recentOwnerBySpell[key] = {
                    guid = logEntry.sourceGUID,
                    name = logEntry.sourceName,
                    class = sourceClass or abilityClass,
                    t = logEntry.t,
                }
            end
        end
        local function IsSpecialProcEffect(entry)
            if not entry or type(entry.sourceGUID) ~= "string" or not entry.sourceGUID:match("^Player%-") then return false end
            -- Classification is evidence-based for every class. Missing casts,
            -- incomplete class inference, and shared names do not imply a proc.
            if DP.Usage and DP.Usage.IsKnownProcEffect and
                    DP.Usage.IsKnownProcEffect(entry.spellID, entry.spellName, entry.sourceGUID) then return true end
            return tonumber(entry.spellID) == 20007 -- Crusader's Holy Strength
        end
        local function SpellText(entry)
            local name = entry and entry.spellName
            local spellID = entry and tonumber(entry.spellID)
            if (type(name) ~= "string" or name == "") and spellID then name = "Spell " .. tostring(spellID) end
            if type(name) ~= "string" or name == "" then name = "Ability" end
            -- Normal abilities stay white. Item/weapon-style proc effects use the
            -- same lavender accent as before, but the bracketed ability itself is
            -- colored rather than adding a redundant PROC label.
            local color = IsSpecialProcEffect(entry) and "|cffc7a0ff" or "|cffffffff"
            if DP.Theme.SpellTextLink then return DP.Theme.SpellTextLink(spellID, name, color) end
            return color .. "[" .. name .. "]|r"
        end
        local function ItemUseInfo(entry)
            if not entry then return nil end
            local itemID = tonumber(entry.itemID)
            local known = tonumber(entry.spellID) and DP.UsageCatalog and DP.UsageCatalog[tonumber(entry.spellID)] or nil
            if not itemID and known and tonumber(known.itemID) then itemID = tonumber(known.itemID) end
            if not itemID then return nil end
            return {
                itemID = itemID,
                name = entry.itemName or (known and known.name),
                quality = entry.itemQuality or (known and known.quality),
            }
        end
        local function ProcItemInfo(entry)
            if not entry or not (DP.Usage and DP.Usage.ResolveProcItem) then return nil end
            -- Revalidate old metadata as well: previous builds could persist a
            -- name-based item attribution on ordinary spells or NPC attacks.
            local resolved = DP.Usage.ResolveProcItem(entry.spellID, entry.spellName, nil, entry.sourceGUID, record)
            if not resolved then return nil end
            return {itemID=resolved.itemID, name=resolved.name, quality=resolved.quality}
        end
        local function ItemText(item)
            if not item then return nil end
            if DP.Theme.ItemTextLink then return DP.Theme.ItemTextLink(item.itemID, item.name, item.quality) end
            return "[" .. tostring(item.name or ("Item " .. tostring(item.itemID))) .. "]"
        end

        local function SourceText(entry)
            local corrected = resolvedSourceByEntry[entry]
            if corrected then return ParticipantText(corrected.guid, corrected.name) end
            return ParticipantText(entry.sourceGUID, entry.sourceName)
        end
        local function IsSelfOnlyReflectorCast(entry)
            if not entry or tostring(entry.event or "") ~= "SPELL_CAST_SUCCESS" then return false end
            local name = type(entry.spellName) == "string" and entry.spellName:lower() or ""
            -- Classic engineering reflectors are self-use activations. CLEU can
            -- provide an unrelated/opaque destination GUID for the item-use cast,
            -- which previously rendered as "Unidentified". The associated aura
            -- correctly lands on the user, so normalize the cast target as self.
            return name:find("reflector", 1, true) ~= nil
        end
        local function IsPlayerKillingBlow(entry)
            if not entry then return false end
            if entry.killingBlow then return true end
            local overkill = tonumber(entry.overkill)
            if overkill == nil or overkill < 0 then return false end
            local playerGUID = record.session and record.session.playerGUID
            local sourceIsPlayer = entry.sourceGUID == playerGUID or participants[entry.sourceGUID] ~= nil
            local destIsPlayer = entry.destGUID == playerGUID or participants[entry.destGUID] ~= nil
            return sourceIsPlayer and destIsPlayer and entry.sourceGUID ~= entry.destGUID
        end
        local function EscapePattern(text)
            return (tostring(text or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
        end
        local function ColorLegacyText(entry)
            local text = entry.text or ""
            text = text:gsub(" on Unknown", ""):gsub(" to Unknown", ""):gsub(" from Unknown", ""):gsub(" Unknown", " target")
            for guid, identity in pairs(participants) do
                local name = ShortName(identity and identity.name)
                local class = (identity and identity.class) or inferredClassByGUID[guid] or inferredClassByName[name]
                if name and name ~= "Unknown" and name ~= "" and class then
                    text = text:gsub(EscapePattern(name), DP.Theme.ClassName(name, class))
                end
            end
            for name, class in pairs(inferredClassByName) do
                if name and name ~= "Unknown" and name ~= "" and class then
                    text = text:gsub(EscapePattern(name), DP.Theme.ClassName(name, class))
                end
            end
            if entry.event == "SPELL_HEAL" or entry.event == "SPELL_PERIODIC_HEAL" then
                text = text:gsub(" healed ", " |cff65e6adhealed|r ", 1)
                text = text:gsub(" for (%d+)", " for |cff65e6ad%1|r", 1)
            elseif entry.event == "SWING_DAMAGE" or entry.event == "SPELL_DAMAGE" or entry.event == "RANGE_DAMAGE" or entry.event == "SPELL_PERIODIC_DAMAGE" then
                text = text:gsub(" hit ", " hit ", 1)
                text = text:gsub(" for (%d+)", " for |cffff8888%1|r", 1)
            elseif entry.event == "SPELL_CAST_SUCCESS" then
                text = text:gsub(" cast ", " cast ", 1)
            elseif entry.event == "SPELL_INTERRUPT" then
                text = text:gsub(" interrupted ", " interrupted ", 1)
            elseif entry.event == "PARTY_KILL" or entry.event == "UNIT_DIED" then
                text = "|cffff8888" .. text .. "|r"
            end
            return text
        end
        local function FormatLogEntry(entry)
            local event = entry.event
            -- Records made before 0.21.48 only stored the already-rendered text.
            -- Do not manufacture blank spells/amounts for them; colorize that
            -- original text instead.
            local needsSpell = event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or
                event == "SPELL_MISSED" or event == "RANGE_MISSED" or event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" or
                event == "SPELL_CAST_SUCCESS" or event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED" or
                event == "SPELL_AURA_REFRESH" or event == "SPELL_INTERRUPT"
            local needsAmount = event == "SWING_DAMAGE" or event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or
                event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL"
            local hasSpellName = type(entry.spellName) == "string" and entry.spellName ~= ""
            local numericSpellID = tonumber(entry.spellID)
            if (needsSpell and not hasSpellName and not numericSpellID) or (needsAmount and not entry.amount) then
                return ColorLegacyText(entry)
            end
            local source = SourceText(entry)
            local dest = ParticipantText(entry.destGUID, entry.destName)
            local spell = needsSpell and SpellText(entry) or ""
            local mindControlUserGUID, mindControlUserName, inferredMindControlBackfire = W.MindControlUseInfo(entry, participants)
            if mindControlUserGUID then
                local item = ItemUseInfo(entry) or {itemID=10726, name="Gnomish Mind Control Cap", quality=2}
                if tonumber(item.itemID) ~= 10726 then item = {itemID=10726, name="Gnomish Mind Control Cap", quality=2} end
                local user = ParticipantText(mindControlUserGUID, mindControlUserName)
                local suffix = (entry.mindControlBackfire or inferredMindControlBackfire) and "  |cffffad66(BACKFIRED)|r" or ""
                return string.format("%s used %s%s", user, ItemText(item), suffix)
            elseif event == "SWING_DAMAGE" then
                local kb = IsPlayerKillingBlow(entry) and "  |cffffce70KILLING BLOW|r" or ""
                return string.format("%s hit %s for %s%s", source, dest, AmountText(entry.amount, false), kb)
            elseif event == "SWING_MISSED" then
                return string.format("%s missed %s |cffadb5c2(%s)|r", source, dest, tostring(entry.missType or "miss"))
            elseif event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" then
                local kb = IsPlayerKillingBlow(entry) and "  |cffffce70KILLING BLOW|r" or ""
                local procItem = ProcItemInfo(entry)
                if procItem then
                    return string.format("%s's %s hit %s with %s for %s%s", source, ItemText(procItem), dest, spell, AmountText(entry.amount, false), kb)
                end
                return string.format("%s's %s hit %s for %s%s", source, spell, dest, AmountText(entry.amount, false), kb)
            elseif event == "SPELL_MISSED" or event == "RANGE_MISSED" then
                local missType = tostring(entry.missType or "MISS")
                local missed = tonumber(entry.amountMissed)
                local procItem = ProcItemInfo(entry)
                local owner = procItem and (source .. "'s " .. ItemText(procItem) .. " " .. spell) or (source .. "'s " .. spell)
                if missType == "ABSORB" then
                    return string.format("%s was |cff9dc7ffabsorbed|r by %s%s", owner, dest,
                        missed and (" for |cff9dc7ff" .. tostring(math.floor(missed + .5)) .. "|r") or "")
                elseif missType == "RESIST" then
                    return string.format("%s |cffadb5c2resisted|r %s%s", dest, owner,
                        missed and (" |cffadb5c2(" .. tostring(math.floor(missed + .5)) .. ")|r") or "")
                elseif missType == "IMMUNE" then
                    return string.format("%s was |cffadb5c2immune|r to %s", dest, owner)
                end
                return string.format("%s missed %s |cffadb5c2(%s)|r", owner, dest, missType)
            elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
                local procItem = ProcItemInfo(entry)
                if procItem then
                    return string.format("%s's %s |cff65e6adhealed|r %s with %s for %s", source, ItemText(procItem), dest, spell, AmountText(entry.amount, true))
                end
                return string.format("%s's %s |cff65e6adhealed|r %s for %s", source, spell, dest, AmountText(entry.amount, true))
            elseif event == "SPELL_CAST_SUCCESS" then
                local item = ItemUseInfo(entry)
                if item then
                    local targetText = ""
                    if entry.destGUID and entry.destGUID ~= entry.sourceGUID and dest ~= "Unidentified" and dest ~= "target" then
                        targetText = " on " .. dest
                    end
                    return string.format("%s used %s%s", source, ItemText(item), targetText)
                end
                local reflected = reflectedCastByEntry[entry] and "  |cffc7a0ff(REFLECTED)|r" or ""
                local targetText = ""
                if IsSelfOnlyReflectorCast(entry) or selfCastByEntry[entry] then
                    targetText = " on " .. source
                elseif entry.destGUID and entry.destGUID ~= entry.sourceGUID and dest ~= "Unidentified" and dest ~= "target" then
                    targetText = " on " .. dest
                end
                return string.format("%s cast %s%s%s", source, spell, targetText, reflected)
            elseif event == "SPELL_AURA_APPLIED" then
                if entry.mindControlBackfire then
                    local item = ItemUseInfo(entry)
                    local user = ParticipantText(entry.itemUserGUID or entry.destGUID, entry.itemUserName or entry.destName)
                    return string.format("%s used %s  |cffffad66(BACKFIRED)|r", user, item and ItemText(item) or spell)
                end
                local procItem = ProcItemInfo(entry)
                if procItem then
                    return string.format("%s's %s applied %s to %s", source, ItemText(procItem), spell, dest)
                end
                return string.format("%s applied %s to %s", source, spell, dest)
            elseif event == "SPELL_AURA_REMOVED" then
                return string.format("%s's %s faded from %s", source, spell, dest)
            elseif event == "SPELL_AURA_REFRESH" then
                if entry.mindControlBackfire then
                    local item = ItemUseInfo(entry)
                    local user = ParticipantText(entry.itemUserGUID or entry.destGUID, entry.itemUserName or entry.destName)
                    return string.format("%s used %s  |cffffad66(BACKFIRED)|r", user, item and ItemText(item) or spell)
                end
                local procItem = ProcItemInfo(entry)
                if procItem then
                    return string.format("%s's %s refreshed %s on %s", source, ItemText(procItem), spell, dest)
                end
                return string.format("%s refreshed %s on %s", source, spell, dest)
            elseif event == "SPELL_INTERRUPT" then
                return string.format("%s's %s interrupted %s", source, spell, dest)
            elseif event == "PARTY_KILL" then
                return string.format("|cffff8888%s killed %s|r", source, dest)
            elseif event == "UNIT_DIED" then
                return string.format("|cffff8888%s died|r", dest)
            end
            return ColorLegacyText(entry)
        end
        -- CLEU may report an item's result before SPELL_CAST_SUCCESS: reflectors
        -- can apply their aura first, and Healthstones can report the heal first.
        -- Render the causal order (used item -> resulting effect) without mutating
        -- the saved event stream. Match by catalog item identity first, then by
        -- spell ID/name for clients whose item-use spell aliases differ.
        local displayEntries = {}
        local recentMindControlByUser = {}
        for _, entry in ipairs(logEntries) do
            local actorGUID, _, backfire = W.MindControlUseInfo(entry, participants)
            if actorGUID then
                local prior = recentMindControlByUser[actorGUID]
                local at = tonumber(entry.t) or 0
                if prior and math.abs(at - prior.t) <= 1.25 then
                    -- Prefer the NPC-sourced aura when it proves the activation
                    -- backfired; otherwise keep whichever signal arrived first.
                    if backfire and not prior.backfire then
                        displayEntries[prior.index] = entry
                        prior.t, prior.backfire = at, true
                    end
                else
                    displayEntries[#displayEntries + 1] = entry
                    recentMindControlByUser[actorGUID] = {index=#displayEntries, t=at, backfire=backfire and true or false}
                end
            else
                displayEntries[#displayEntries + 1] = entry
            end
        end
        local function SameItemActivation(useEntry, effectEntry)
            if not (useEntry and effectEntry and useEntry.sourceGUID == effectEntry.sourceGUID) then return false end
            local used = ItemUseInfo(useEntry)
            local effect = ItemUseInfo(effectEntry)
            if used and effect and tonumber(used.itemID) and tonumber(effect.itemID) and
                    tonumber(used.itemID) == tonumber(effect.itemID) then return true end
            local useSpellID, effectSpellID = tonumber(useEntry.spellID), tonumber(effectEntry.spellID)
            if useSpellID and effectSpellID and useSpellID == effectSpellID then return true end
            local useName = type(useEntry.spellName) == "string" and useEntry.spellName:lower() or nil
            local effectName = type(effectEntry.spellName) == "string" and effectEntry.spellName:lower() or nil
            return useName and effectName and useName ~= "" and useName == effectName
        end
        local itemResultEvents = {
            SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true,
            SPELL_HEAL = true, SPELL_DAMAGE = true, SPELL_PERIODIC_HEAL = true,
            SPELL_PERIODIC_DAMAGE = true, SPELL_MISSED = true,
        }
        for index = 2, #displayEntries do
            local entry = displayEntries[index]
            if entry and entry.event == "SPELL_CAST_SUCCESS" and ItemUseInfo(entry) then
                local insertAt = index
                local itemTime = tonumber(entry.t) or 0
                for priorIndex = index - 1, 1, -1 do
                    local prior = displayEntries[priorIndex]
                    local priorTime = tonumber(prior and prior.t) or itemTime
                    local delta = itemTime - priorTime
                    if delta > .20 then break end
                    if delta >= 0 and prior and itemResultEvents[tostring(prior.event or "")] and
                            SameItemActivation(entry, prior) then
                        insertAt = priorIndex
                    end
                end
                if insertAt < index then
                    table.remove(displayEntries, index)
                    table.insert(displayEntries, insertAt, entry)
                end
            end
        end

        local lines = {}
        local synthesizedDeathAt = {}
        for index, entry in ipairs(displayEntries) do
            local suppressDeath = false
            if (entry.event == "UNIT_DIED" or entry.event == "PARTY_KILL") and entry.destGUID then
                local synthesizedAt = synthesizedDeathAt[entry.destGUID]
                if synthesizedAt and math.abs((tonumber(entry.t) or 0) - synthesizedAt) <= 1.0 then suppressDeath = true end
            end
            local suppressReflectedMiss = reflectedMissByEntry[entry] and true or false
            if not suppressDeath and not suppressReflectedMiss then
                lines[#lines + 1] = string.format("|cff8f98a6+%05.1fs|r  %s", entry.t or 0, FormatLogEntry(entry))
                if IsPlayerKillingBlow(entry) and entry.destGUID then
                    local nextEntry = displayEntries[index + 1]
                    local nextIsDeath = nextEntry and nextEntry.event == "UNIT_DIED" and nextEntry.destGUID == entry.destGUID
                    if not nextIsDeath then
                        local died = string.format("|cffff8888%s died|r", ParticipantText(entry.destGUID, entry.destName))
                        lines[#lines + 1] = string.format("|cff8f98a6+%05.1fs|r  %s", entry.t or 0, died)
                        synthesizedDeathAt[entry.destGUID] = tonumber(entry.t) or 0
                    end
                end
            end
        end
        if record.session and record.session.worldCombatTruncated then lines[#lines + 1] = "|cff8f98a6… additional events were omitted.|r" end
        if #lines == 0 then lines[1] = "|cffadb5c2No combat events recorded.|r" end
        local logText = table.concat(lines, "\n")
        window.logPlainText = DP.Theme.PlainCombatLogText and DP.Theme.PlainCombatLogText(logText) or logText
        local changedRecord = window._combatLogCursorRecord ~= record
        if DP.Theme.SetLockedEditBoxText then DP.Theme.SetLockedEditBoxText(window.logText, logText) else window.logText:SetText(logText) end
        if changedRecord then
            window._combatLogCursorRecord = record
            if window.logText.HighlightText then window.logText:HighlightText(0, 0) end
            if window.logText.SetCursorPosition then window.logText:SetCursorPosition(0) end
            -- Clear the prior encounter's animation destination as well as the
            -- visible offset; otherwise one wheel tick resumes near its bottom.
            if window.logScroll and window.logScroll.ResetScroll then window.logScroll:ResetScroll(0) end
        end
        window.logMeasure:SetText(logText)
        local logHeight = math.max(1, (window.logMeasure:GetStringHeight() or 0) + 12)
        window.logText:SetHeight(logHeight)
        window.logBody:SetHeight(logHeight)
        window:SetHeight(DETAIL_PAGE_HEIGHT)
        if window.logScroll.UpdateScrollHints then window.logScroll:UpdateScrollHints() end
    end
end

function W.RefreshDetailStar()
    local window = W.details
    if not window or not window.starButton then return end
    W.StyleStarTexture(window.starButton.icon, W.IsStarred(window.record))
end

function W.SelectDetailTab(tab)
    local window = EnsureDetails()
    window.activeTab = tab
    DP.Theme.SelectDataTab(window.summaryTab, tab == "summary", "Summary")
    DP.Theme.SelectDataTab(window.usageTab, tab == "usage", "Items & Abilities")
    DP.Theme.SelectDataTab(window.logTab, tab == "log", "Combat Log")
    W.RefreshDetailContent()
end

function W.EnsureHeaderBuffIcon(window, index)
    window.buffIcons = window.buffIcons or {}
    local button = window.buffIcons[index]
    if button then return button end
    button = CreateFrame("Button", nil, window.buffBody or window.buffBox)
    button:SetSize(20, 20)

    -- Let the icon art run underneath the border all the way to the button edge.
    -- The chrome is an overlay, so there is no dead inset between artwork and frame.
    button.iconFrame = CreateFrame("Frame", nil, button)
    button.iconFrame:SetAllPoints(button)
    if button.iconFrame.SetClipsChildren then button.iconFrame:SetClipsChildren(true) end
    button.icon = button.iconFrame:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button.iconFrame)
    button.icon:SetTexCoord(.04, .96, .04, .96)
    if button.iconFrame.CreateMaskTexture and button.icon.AddMaskTexture then
        button.mask = button.iconFrame:CreateMaskTexture()
        button.mask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        button.mask:SetAllPoints(button.iconFrame)
        button.icon:AddMaskTexture(button.mask)
    end
    button.chrome = CreateFrame("Frame", nil, button, BackdropTemplateMixin and "BackdropTemplate" or nil)
    -- Give the ENEMY BUFFS chrome a 1px outside rail so the tooltip-style
    -- border does not visually crowd or clip the icon artwork. The clickable
    -- icon/grid footprint stays unchanged; only the decorative box grows.
    button.chrome:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    button.chrome:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    if button.chrome.SetFrameLevel then button.chrome:SetFrameLevel(button:GetFrameLevel() + 4) end
    if button.chrome.SetBackdrop then
        button.chrome:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 6,
            insets = {left = 1, right = 1, top = 1, bottom = 1}})
        button.chrome:SetBackdropBorderColor(.84, .56, .31, .92)
    else
        local border = DP.Theme.Border(button.chrome, 0, 0, 20, 20)
        border:ClearAllPoints(); border:SetAllPoints(button.chrome); border:EnableMouse(false)
    end
    button.chrome:EnableMouse(false)

    button.sheen = DP.Theme and DP.Theme.LightSweep and DP.Theme.LightSweep(button.iconFrame, button.iconFrame, {1, .90, .64}, true) or nil
    if button.sheen then button.sheen.minBandWidth = 7; button.sheen.bandWidthFactor = .31 end
    button:SetScript("OnEnter", function(self)
        -- Once triggered, let the sweep complete even if the cursor moves to a
        -- neighboring buff. Each icon owns its own independent animation.
        if self.sheen then self.sheen:Play(0, .34) end
        local entry = self.entry
        if not entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if entry.itemID then
            GameTooltip:SetHyperlink("item:" .. tostring(entry.itemID))
        elseif entry.spellID and GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(entry.spellID)
        elseif entry.spellID and GetSpellLink then
            local link = GetSpellLink(entry.spellID)
            if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(entry.name or "Buff") end
        else
            GameTooltip:SetText(entry.name or "Buff")
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:EnableMouseWheel(true)
    button:SetScript("OnMouseWheel", function(_, delta)
        if window.buffScroll and window.buffScroll.ScrollByWheel then window.buffScroll:ScrollByWheel(delta) end
    end)
    window.buffIcons[index] = button
    return button
end

function W.HeaderBuffEnemy(record, key)
    local enemies = record and record.enemies or {}
    for _, enemy in ipairs(enemies) do
        if (enemy.guid or enemy.name) == key then return enemy end
    end
    return nil
end

function W.RefreshHeaderBuffs()
    local window = W.details
    local record = window and window.record
    if not window or not record or not window.buffBox then return end
    local enemies = record.enemies or {}
    local enemy = W.HeaderBuffEnemy(record, window.buffOpponentGUID)
    if not enemy then enemy = DefaultHeaderBuffEnemy(record) end
    if enemy then window.buffOpponentGUID = enemy.guid or enemy.name end

    -- Keep the card fixed so its top and bottom edges always match ENCOUNTER.
    window.buffBox:ClearAllPoints(); window.buffBox:SetPoint("TOPLEFT", 434, -34); window.buffBox:SetSize(196, 142)
    local buffs = SortedOpponentBuffs(enemy)
    local buffsRemoved = enemy and enemy.killingBlow and #buffs > 0
    window.buffTitle:SetText(buffsRemoved and "ENEMY BUFFS REMOVED" or "ENEMY BUFFS")

    -- A selector is useful only when this encounter actually retained aura data
    -- for at least one enemy. Multi-enemy fights with no observed buffs stay clean.
    local anyEncounterBuffs = false
    for _, candidate in ipairs(enemies) do
        if #SortedOpponentBuffs(candidate) > 0 then anyEncounterBuffs = true; break end
    end
    local showSelector = #enemies > 1 and anyEncounterBuffs
    if showSelector then
        window.buffSelector:Show()
        window.buffSelector:SetSelectedValue(window.buffOpponentGUID)
    else
        window.buffSelector.menu:Hide()
        window.buffSelector:Hide()
    end

    local columns = 5
    local rows = math.max(1, math.ceil(#buffs / columns))
    local rowGap = 4
    local columnGap = 3
    local iconTop = showSelector and 50 or 29
    window._headerBuffCount = #buffs

    -- Keep the title, selector and first buff on the same 8px left rail. When a
    -- third buff row is needed, reserve room for the History-style scroll token
    -- instead of shrinking every icon to make the whole set fit at once.
    window.buffScroll:ClearAllPoints()
    window.buffScroll:SetPoint("TOPLEFT", window.buffBox, "TOPLEFT", 8, -iconTop)
    window.buffScroll:SetPoint("BOTTOMRIGHT", window.buffBox, "BOTTOMRIGHT", #buffs > 10 and -14 or -8, 8)
    window.buffScrollbar:ClearAllPoints()
    window.buffScrollbar:SetPoint("TOPRIGHT", window.buffBox, "TOPRIGHT", -1, -(iconTop + 2))
    window.buffScrollbar:SetPoint("BOTTOMRIGHT", window.buffBox, "BOTTOMRIGHT", -1, 8)

    local contentWidth = #buffs > 10 and 174 or 180
    local iconSize = math.max(24, math.floor((contentWidth - columnGap * (columns - 1)) / columns))
    local viewportHeight = math.max(28, 142 - iconTop - 8)
    local bodyHeight = math.max(viewportHeight, rows * iconSize + math.max(0, rows - 1) * rowGap)
    window.buffBody:SetWidth(contentWidth)
    window.buffBody:SetHeight(bodyHeight)

    window.buffEmpty:ClearAllPoints()
    window.buffEmpty:SetPoint("CENTER", window.buffScroll, "CENTER", 0, 0)
    for index, entry in ipairs(buffs) do
        local icon = W.EnsureHeaderBuffIcon(window, index)
        local zero = index - 1
        local col, row = zero % columns, math.floor(zero / columns)
        icon:SetSize(iconSize, iconSize)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", window.buffBody, "TOPLEFT", col * (iconSize + columnGap), -row * (iconSize + rowGap))
        icon.entry = entry
        icon.icon:SetTexture(W.OpponentBuffIcon(entry))
        icon:Show()
    end
    for index = #buffs + 1, #(window.buffIcons or {}) do
        window.buffIcons[index].entry = nil
        window.buffIcons[index]:Hide()
    end
    window.buffEmpty:SetShown(#buffs == 0)

    if window._lastBuffScrollGUID ~= window.buffOpponentGUID then
        window._lastBuffScrollGUID = window.buffOpponentGUID
        window.buffScroll.smoothTarget = 0
        window.buffScroll:SetVerticalScroll(0)
    end
    if window.buffScroll.UpdateScrollHints then window.buffScroll:UpdateScrollHints() end
end

function W.FitWrappedHeaderText(fontString, fontObject, width, maxHeight, maxSize, minSize)
    if not fontString then return minSize or 8 end
    fontString:SetFontObject(fontObject)
    fontString:SetWidth(width)
    fontString:SetWordWrap(true)
    fontString:SetHeight(maxHeight)
    local font, size, flags = fontObject and fontObject.GetFont and fontObject:GetFont()
    size = math.min(tonumber(size) or maxSize or 10, maxSize or 99)
    local floor = minSize or 7
    if font and fontString.SetFont then
        fontString:SetFont(font, size, flags)
        while size > floor and fontString.GetStringHeight and (fontString:GetStringHeight() or 0) > maxHeight do
            size = size - 1
            fontString:SetFont(font, size, flags)
        end
    end
    return size
end

function W.LayoutEncounterHeader(window, record)
    local loc = record.location or {}
    local zone = SummaryZoneName(loc) or loc.zone or "Unknown location"
    local subzone = loc.subzone and loc.subzone ~= "" and loc.subzone ~= zone and not IsGenericWorldZone(loc.subzone) and loc.subzone or nil
    local locationText = subzone and (zone .. "\n" .. subzone) or zone
    window.location:SetText(locationText)
    W.FitWrappedHeaderText(window.location, GameFontHighlight, 144, 34, 12, 8)
    local locationHeight = window.location.GetStringHeight and (window.location:GetStringHeight() or 16) or 16
    locationHeight = math.max(15, math.min(34, locationHeight))

    local ruleY = math.min(78, 25 + locationHeight + 7)
    window.resultRule:ClearAllPoints(); window.resultRule:SetPoint("TOPLEFT", 10, -ruleY)
    window.locationLabel:ClearAllPoints(); window.locationLabel:SetPoint("TOPLEFT", 10, -(ruleY + 8))
    local encounterTop = ruleY + 25
    local encounterHeight = math.max(34, 134 - encounterTop)
    window.headcount:ClearAllPoints(); window.headcount:SetPoint("TOPLEFT", 10, -encounterTop)
    window.outcome:ClearAllPoints(); window.outcome:SetPoint("TOPLEFT", 10, -(encounterTop + 25)); window.outcome:SetHeight(math.max(16, encounterHeight - 25))

    local friendlies = math.max(1, tonumber(record.friendlyCount) or 1)
    local meaningfulEnemies = math.max(0, MeaningfulEnemyCount(record))
    local nvn = string.format("%d vs %d", friendlies, meaningfulEnemies)
    window.headcount:SetText("|cffffce70" .. nvn .. "|r")
    local headFont, _, headFlags = GameFontNormalLarge and GameFontNormalLarge.GetFont and GameFontNormalLarge:GetFont()
    if headFont and window.headcount.SetFont then window.headcount:SetFont(headFont, 17, headFlags) end

    local mixedLabel = EncounterComposition(record)
    local resultLabel = mixedLabel or HeaderOutcomeText(record)
    local duration = HeaderCompactDurationText(record.duration)
    local synopsis = ResultColor(record.resultKey) .. resultLabel .. "|r  |cff7f8794•|r  " .. HeaderSurvivalText(record) .. " |cffadb5c2" .. duration .. "|r"
    window.outcome:SetText(synopsis)
    W.FitWrappedHeaderText(window.outcome, GameFontHighlightSmall, 144, math.max(16, encounterHeight - 25), 10, 8)

    window.locationHover:ClearAllPoints(); window.locationHover:SetPoint("TOPLEFT", 7, -21); window.locationHover:SetSize(150, math.min(58, locationHeight + 10))
    window.encounterHover:ClearAllPoints()
    window.encounterHover:SetPoint("TOPLEFT", 7, -(ruleY + 4))
    window.encounterHover:SetPoint("BOTTOMRIGHT", window.resultBox, "BOTTOMRIGHT", -7, 5)
end

function W.OpenDetails(record)
    if DP.Usage and DP.Usage.window and DP.Usage.window:IsShown() then
        DP.Usage.window:Hide()
    end
    local detail = EnsureDetails()
    if detail.record == record and detail:IsShown() then
        -- Repeated clicks on the selected History tile are a complete no-op for
        -- portrait widgets. Do not reparent, redress, Show(), or restart anything.
        if detail.Raise then detail:Raise() end
        return
    end

    local selectedTab = detail.activeTab or "summary"
    detail._portraitOpenGeneration = (tonumber(detail._portraitOpenGeneration) or 0) + 1
    detail._portraitPendingRecord = nil

    -- Release the previous encounter's leased bodies before asking the pool for
    -- the newly selected record. Otherwise an off-screen Rival can occupy one of
    -- the four race/sex actors while the portrait the user actually clicked waits.
    if DP.Portraits then
        for _, card in ipairs(detail.summaryRivalCards or {}) do
            if DP.Portraits.ReleaseWanted then DP.Portraits.ReleaseWanted(card) end
            if card._portraitViewportActive and DP.Portraits.ReleaseBody then DP.Portraits.ReleaseBody(card) end
            card._portraitViewportActive = false
        end
    end

    -- Visible cards request their portraits after layout. Off-screen opponents
    -- and other History records never enter the foreground queue.
    SortEnemiesByRelevance(record)

    detail.record = record
    detail.participantFilter = "all"
    local primary = PrimaryOpponent(record)
    local buffDefault = DefaultHeaderBuffEnemy(record)
    detail.buffOpponentGUID = buffDefault and (buffDefault.guid or buffDefault.name) or
        (primary and (primary.guid or primary.name) or nil)
    W.SetMapRecord(detail.map, record)
    W.LayoutEncounterHeader(detail, record)
    detail.result:SetText("")
    W.RefreshHeaderBuffs()
    W.RefreshDetailStar()

    -- No encounter-level fade/blanking. Prepared portraits now carry actor-level
    -- pause across reparenting, so the selected record can update synchronously.
    if detail.SetAlpha then detail:SetAlpha(1) end
    detail:Show()
    W.SelectDetailTab(selectedTab)

    -- Catch any client-side pause-state wobble after SetParent without touching
    -- animation state. These are invisible no-op holds when the actor stayed paused.
    if C_Timer and C_Timer.After and DP.Portraits and DP.Portraits.ReassertFrozen then
        local generation = detail._portraitOpenGeneration
        local function Reassert()
            if detail._portraitOpenGeneration ~= generation or detail.record ~= record then return end
            for _, card in ipairs(detail.summaryRivalCards or {}) do
                if card:IsShown() and card._portraitBodyEntry then DP.Portraits.ReassertFrozen(card) end
            end
        end
        C_Timer.After(.03, Reassert)
        C_Timer.After(.10, Reassert)
        C_Timer.After(.22, Reassert)
    end
end

function W.ClassLabel(class)
    if not class then return "Unknown class" end
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

function W.HistoryOutcomeLabel(record)
    local mixed = EncounterComposition(record)
    local label = mixed or (record and record.resultLabel) or "WORLD PVP"
    local kills = tonumber(record and record.enemyDeaths) or 0
    if kills < 2 then return label end
    local ganks, lowbies = CountGanks(record)
    if lowbies >= kills then
        return string.format("%d LOWBIE GANKS", kills)
    end
    if ganks >= kills then
        return string.format("%d GANKS", kills)
    end
    return label
end

function W.HistoryHeadcount(record)
    local enemies = tonumber(record and record.enemyCount) or 0
    if enemies <= 0 then return EncounterHeadcount(record) end
    local ganks, lowbies = CountGanks(record)
    if lowbies >= enemies then
        return string.format("%d %s", enemies, enemies == 1 and "lowbie" or "lowbies")
    end
    if ganks >= enemies then
        return string.format("%d %s", enemies, enemies == 1 and "lower-level enemy" or "lower-level enemies")
    end
    return EncounterHeadcount(record)
end

function W.HistoryOpponentLine(record, selectedOpponentKey)
    local enemies = record and record.enemies or {}
    if #enemies == 0 then return "Unknown opponent" end
    local names = {}
    -- Display ordering only: preserve the encounter's participant ordering.
    if selectedOpponentKey then
        for _, enemy in ipairs(enemies) do
            if (enemy.guid or enemy.name) == selectedOpponentKey then
                names[#names + 1] = DP.Theme.ClassName(ShortName(enemy.name), enemy.class)
            end
        end
    end
    for _, enemy in ipairs(enemies) do
        if (enemy.guid or enemy.name) ~= selectedOpponentKey then
            names[#names + 1] = DP.Theme.ClassName(ShortName(enemy.name), enemy.class)
        end
    end
    return table.concat(names, "|cffadb5c2, |r")
end

function W.HistoryNvN(record)
    local friendlies = math.max(1, tonumber(record and record.friendlyCount) or 1)
    local enemies = math.max(0, tonumber(record and record.enemyCount) or #(record and record.enemies or {}))
    return string.format("%d vs %d", friendlies, enemies)
end

function W.HistoryResultLine(record)
    local color = ResultColor(record and record.resultKey)
    local label = W.HistoryOutcomeLabel(record)
    local killingBlows = math.max(0, tonumber(record and record.killingBlows) or 0)
    local detail = killingBlows > 0 and string.format("%d KB%s", killingBlows, killingBlows == 1 and "" or "s") or
        (record and record.playerDied and "Died" or "Survived")
    return string.format("%s%s|r  |cffadb5c2•  %s|r", color, label, detail)
end

function W.HistoryMeta(record)
    local loc = record.location or {}
    return {
        title = W.HistoryOutcomeLabel(record),
        subtitle = string.format("%s • %d %s • %s", W.HistoryHeadcount(record), record.enemyDeaths or 0,
            (record.enemyDeaths or 0) == 1 and "kill" or "kills", SurvivalText(record)),
        footer = string.format("%s%s", loc.zone or "Unknown", record.npcAssistance and " • NPC interference" or ""),
    }
end

function W.ShowHistoryTooltip(owner, record)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText((ResultColor(record.resultKey) .. W.HistoryOutcomeLabel(record) .. "|r"))
    if record.lowHealthEngagement and record.engagementHealthPercent then
        GameTooltip:AddLine(string.format("Enemy engaged you at approximately %.0f%% health.", record.engagementHealthPercent), 1, .68, .4, true)
        if record.resultKey == "low_health_death" then GameTooltip:AddLine("Excluded from solo-loss records.", .75, .78, .84, true) end
    end
    GameTooltip:AddLine(string.format("%s • %d %s • %s", W.HistoryHeadcount(record), record.enemyDeaths or 0,
        (record.enemyDeaths or 0) == 1 and "kill" or "kills", SurvivalText(record)), 1, 1, 1)
    if record.location then GameTooltip:AddLine((record.location.zone or "Unknown") .. (record.location.subzone and record.location.subzone ~= "" and (" • " .. record.location.subzone) or ""), .7, .75, .82) end
    for index, enemy in ipairs(record.enemies or {}) do
        if index > 6 then break end
        local level = enemy.level and ("Lv " .. tostring(enemy.level)) or "Lv ?"
        local kind = enemy.died and GankKind(record, enemy)
        local suffix = kind == "lowbie" and "  |cffff8888LOWBIE GANK|r" or kind == "gank" and "  |cffffad66GANK|r" or ""
        GameTooltip:AddLine(DP.Theme.ClassName(ShortName(enemy.name), enemy.class) .. "  |cffadb5c2" .. level .. " " .. W.ClassLabel(enemy.class) .. "|r" .. suffix, 1, 1, 1, true)
    end
    if record.npcAssistance then GameTooltip:AddLine("NPC assistance/interference detected", 1, .68, .4, true) end
    GameTooltip:AddLine("Click for encounter details", .55, .6, .68, true)
    GameTooltip:Show()
end

return W
