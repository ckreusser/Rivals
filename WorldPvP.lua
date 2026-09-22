local _, DP = ...

local W = {}
DP.WorldPvP = W

-- PLAYER_REGEN_ENABLED is the primary encounter boundary. Keep a short grace
-- period for Classic quirks (Vanish/Feign/CC/combat-drop flicker), but do not
-- let unrelated players arriving during the old 60-second inactivity window
-- accumulate into one giant encounter. The 60-second timer remains only as a
-- hard safety net for cases where combat-state events are missed.
local COMBAT_END_GRACE = 10
local INACTIVITY_TIMEOUT = 60
local ALL_ENEMIES_DEAD_GRACE = 6
local ENEMY_PRESSURE_WINDOW = 12
local MAX_ENCOUNTERS = 250
local MAX_WORLD_LOG = 160
local BAND = bit and bit.band or bit32 and bit32.band


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
    [1278762] = "Unrelenting Rallying Cry of the Dragonslayer",
}
local WORLD_BUFF_NAMES = {}
for _, name in pairs(WORLD_BUFFS) do WORLD_BUFF_NAMES[name] = true end

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

local function BuffBucket(enemy, category)
    enemy.detectedBuffs = enemy.detectedBuffs or {world = {}, consumables = {}, scanned = false}
    return category == "world" and enemy.detectedBuffs.world or enemy.detectedBuffs.consumables
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
        if ok and aura then return aura.name, aura.spellId, aura.duration, aura.expirationTime end
    end
    local reader = UnitBuff or UnitAura
    if not reader then return nil end
    local ok, name, _, _, _, duration, expirationTime, _, _, _, spellID = pcall(reader, unit, index, "HELPFUL")
    if not ok then return nil end
    return name, spellID, duration, expirationTime
end

local function ScanEnemyUnitBuffs(session, unit)
    if not session or not unit or not UnitGUID then return end
    local guid = UnitGUID(unit)
    local enemy = guid and session.enemies and session.enemies[guid]
    if not enemy then return end
    enemy.detectedBuffs = enemy.detectedBuffs or {world = {}, consumables = {}, scanned = false}
    enemy.detectedBuffs.scanned = true
    enemy.detectedBuffs.firstScanAt = enemy.detectedBuffs.firstScanAt or math.max(0, GetTime() - session.startedElapsed)
    for index = 1, 80 do
        local name, spellID = ReadHelpfulAura(unit, index)
        if not name then break end
        local category, canonical, itemID = TrackedBuffMeta(spellID, name)
        if category then RecordEnemyBuff(session, enemy, category, spellID, canonical or name, itemID, "snapshot", "present") end
    end
end

local function ScanVisibleEnemyBuffs(session, force)
    if not session or not UnitGUID then return end
    local now = GetTime()
    if not force and session.lastBuffScanAt and now - session.lastBuffScanAt < .35 then return end
    session.lastBuffScanAt = now
    for _, unit in ipairs({"target", "mouseover", "focus", "targettarget"}) do ScanEnemyUnitBuffs(session, unit) end
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
    local category, canonical, itemID = TrackedBuffMeta(info[12], info[13])
    if not category then return end
    RecordEnemyBuff(session, enemy, category, info[12], canonical or info[13], itemID, "combatlog",
        event == "SPELL_AURA_REMOVED" and "removed" or "applied")
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

local function HasFlag(flags, mask)
    if type(flags) ~= "number" or type(mask) ~= "number" then return false end
    if BAND then return BAND(flags, mask) ~= 0 end
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

local function ResolvePlayerLevel(guid)
    if not guid or not UnitGUID or not UnitLevel then return nil end
    local function Read(unit)
        if unit and UnitGUID(unit) == guid then
            local level = UnitLevel(unit)
            if type(level) == "number" and level > 0 then return level end
        end
    end
    if UnitTokenFromGUID then
        local ok, unit = pcall(UnitTokenFromGUID, guid)
        if ok then
            local level = Read(unit)
            if level then return level end
        end
    end
    for _, unit in ipairs({"target", "mouseover", "focus", "targettarget"}) do
        local level = Read(unit)
        if level then return level end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local unit = plate and (plate.namePlateUnitToken or plate.unitToken)
                local level = Read(unit)
                if level then return level end
            end
        end
    end
    return nil
end

local function CopyIdentity(guid, name, flags)
    local class
    if guid and GetPlayerInfoByGUID then
        local _, englishClass = GetPlayerInfoByGUID(guid)
        class = englishClass
    end
    return {guid = guid, name = name or "Unknown", class = class, level = ResolvePlayerLevel(guid), flags = flags}
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

local function TrimEncounterStore(store)
    local encounters = store and store.encounters
    if not encounters then return end
    while CountUnstarredEncounters(encounters) > MAX_ENCOUNTERS do
        local removed = false
        for index, record in ipairs(encounters) do
            if not record.starred then
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
    if not identity.class and guid and GetPlayerInfoByGUID then
        local _, class = GetPlayerInfoByGUID(guid)
        identity.class = class
    end
    if not identity.level then identity.level = ResolvePlayerLevel(guid) end
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
            if not enemy.died and enemy.lastPressureAt and now - enemy.lastPressureAt <= ENEMY_PRESSURE_WINDOW then
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

local function AppendWorldLog(session, info)
    session.worldCombatLog = session.worldCombatLog or {}
    if #session.worldCombatLog >= MAX_WORLD_LOG then
        session.worldCombatTruncated = true
        return
    end
    local event = info[2]
    local sourceName, destName = ShortName(info[5]), ShortName(info[9])
    local spellID, spellName = info[12], info[13]
    local text
    if event == "SWING_DAMAGE" then
        text = string.format("%s hit %s for %s", sourceName, destName, tostring(math.floor((tonumber(info[12]) or 0) + .5)))
    elseif event == "SWING_MISSED" then
        text = string.format("%s missed %s (%s)", sourceName, destName, tostring(info[12] or "miss"))
    elseif event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" then
        text = string.format("%s's %s hit %s for %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName,
            tostring(math.floor((tonumber(info[15]) or 0) + .5)))
    elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
        text = string.format("%s's %s healed %s for %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName,
            tostring(math.floor((tonumber(info[15]) or 0) + .5)))
    elseif event == "SPELL_CAST_SUCCESS" then
        text = string.format("%s cast %s%s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName ~= "Unknown" and (" on " .. destName) or "")
    elseif event == "SPELL_AURA_APPLIED" then
        text = string.format("%s applied %s to %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName)
    elseif event == "SPELL_AURA_REMOVED" then
        text = string.format("%s's %s faded from %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName)
    elseif event == "SPELL_INTERRUPT" then
        text = string.format("%s's %s interrupted %s", sourceName, spellName or ("Spell " .. tostring(spellID)), destName)
    elseif event == "PARTY_KILL" then
        text = string.format("%s killed %s", sourceName, destName)
    elseif event == "UNIT_DIED" then
        text = destName .. " died"
    end
    if text then
        local amount
        if event == "SWING_DAMAGE" then amount = tonumber(info[12])
        elseif event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or
            event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then amount = tonumber(info[15]) end
        session.worldCombatLog[#session.worldCombatLog + 1] = {
            t = math.max(0, GetTime() - session.startedElapsed),
            text = text,
            sourceGUID = info[4], sourceName = sourceName,
            destGUID = info[8], destName = destName,
            event = event, spellID = spellID, spellName = spellName,
            amount = amount, missType = info[12],
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

local function Outcome(record)
    local enemies = record.enemyCount or 0
    local friendlies = record.friendlyCount or 1
    local kills = record.enemyDeaths or 0
    local survived = not record.playerDied
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

    if outnumbered and survived and contesting > 0 and contestingDeaths >= contesting then return "OUTNUMBERED VICTORY", "outnumbered_victory" end
    if outnumbered and survived and contestingDeaths > 0 then return "OUTNUMBERED ESCAPE", "outnumbered_escape" end
    if outnumbered and record.playerDied and contestingDeaths > 0 then return "OUTNUMBERED FIGHT", "outnumbered_partial" end
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
    return "DISENGAGED", "disengaged"
end

local function EncounterHeadcount(record)
    local friendlies = record.friendlyCount or 1
    local enemies = record.enemyCount or 0
    local contesting = record.contestingEnemyCount
    if contesting == nil then contesting = enemies end
    local peak = record.peakContestingEnemies or contesting
    if friendlies > 1 then return string.format("%d vs %d", friendlies, enemies) end
    if peak >= 2 then return string.format("1 vs %d", peak) end
    if enemies == 1 and contesting == 1 then return "1 vs 1" end
    if enemies == 1 then return "1 enemy" end
    return string.format("%d enemies", enemies)
end

local function SurvivalText(record)
    if record.playerDied then return "death" end
    if record.resultKey == "victory" or record.resultKey == "outnumbered_victory" or record.resultKey == "outnumbered_escape" then return "survived" end
    if (record.enemyDeaths or 0) > 0 then return "survived" end
    return "disengaged"
end

local function HeaderOutcomeText(record)
    local key = record and record.resultKey
    local labels = {
        outnumbered_victory = "Outnumbered Victory",
        outnumbered_escape = "Outnumbered Escape",
        outnumbered_partial = "Outnumbered Fight",
        lowbie_gank = "Lowbie Gank",
        gank = "Gank",
        victory = "Victory",
        trade = "Trade",
        death = "Death",
        disengaged = "Disengaged",
    }
    if key == "kills" then
        local kills = tonumber(record and record.enemyDeaths) or 0
        return string.format("%d %s", kills, kills == 1 and "kill" or "kills")
    end
    return labels[key] or (record and record.resultLabel) or "World PvP"
end

local function HeaderSurvivalText(record)
    if record and record.playerDied then return "|cffff8888Died|r" end
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

local function EnemyNames(record, limit)
    local names = {}
    for _, enemy in ipairs(record.enemies or {}) do
        names[#names + 1] = ShortName(enemy.name)
        if limit and #names >= limit then break end
    end
    return names
end

local function ResultColor(key)
    if key == "outnumbered_victory" then return "|cffffce70" end
    if key == "victory" or key == "outnumbered_escape" then return "|cff65e6ad" end
    if key == "gank" then return "|cffffad66" end
    if key == "lowbie_gank" then return "|cffff8888" end
    if key == "kills" then return "|cffffce70" end
    if key == "death" then return "|cffff8888" end
    if key == "trade" or key == "outnumbered_partial" then return "|cffffad66" end
    return "|cffadb5c2"
end

W.ResultColor = ResultColor
W.EnemyNames = EnemyNames
W.EncounterHeadcount = EncounterHeadcount
W.SurvivalText = SurvivalText
W.GankKind = GankKind
W.CountGanks = CountGanks

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
            if participant and t - lastAt <= ENEMY_PRESSURE_WINDOW and
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
    local enemies = OrderedParticipants(session.enemies)
    local friendlies = OrderedParticipants(session.friendlies)
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
        outcomeModelVersion = 3,
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
        killingBlows = session.killingBlows or 0,
        honorableKills = session.honorableKills or 0,
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
    record.resultLabel, record.resultKey = Outcome(record)
    return record
end

function W.Initialize(observer, db, callbacks)
    W.observer, W.db, W.callbacks = observer, db, callbacks or {}
    observer.worldPvP = observer.worldPvP or {nextSequence = 1, encounters = {}}
    observer.worldPvP.encounters = observer.worldPvP.encounters or {}
    observer.worldPvP.nextSequence = observer.worldPvP.nextSequence or 1
    -- Reclassify older 0.21.x encounters when their saved combat log has
    -- enough evidence to distinguish actual simultaneous opposition from a
    -- sequence of passive victims inside the long encounter timeout.
    for _, record in ipairs(observer.worldPvP.encounters) do
        RebuildPressureEvidence(record)
        RebuildFriendlyContributionEvidence(record)
        if record.outcomeModelVersion ~= 3 then
            record.resultLabel, record.resultKey = Outcome(record)
            record.outcomeModelVersion = 3
        end
    end
    TrimEncounterStore(observer.worldPvP)
    if db.worldPvPEnabled == nil then db.worldPvPEnabled = true end
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
    }
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
            local allEnemiesDead, enemyCount = true, 0
            for _, enemy in pairs(active.enemies or {}) do
                enemyCount = enemyCount + 1
                if not enemy.died then allEnemiesDead = false end
            end
            if active.outOfCombatAt and now - active.outOfCombatAt >= COMBAT_END_GRACE then
                W.Finish("combat-ended")
            elseif enemyCount > 0 and (active.playerDied or allEnemiesDead) and quiet >= ALL_ENEMIES_DEAD_GRACE then
                W.Finish(active.playerDied and "player-death" or "all-enemies-dead")
            elseif quiet >= INACTIVITY_TIMEOUT then
                W.Finish("inactivity")
            end
        end)
    end
    return session
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
            session.participants[sourceGUID] = enemy
        end
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

function W.Combat(playerGUID)
    if not W.Enabled() or not CombatLogGetCurrentEventInfo then return end
    if not InOpenWorld() or (DP.HasActiveDuel and DP.HasActiveDuel()) then
        if W.active then W.Finish("duel-or-instance") end
        return
    end
    local info = {CombatLogGetCurrentEventInfo()}
    local event = info[2]
    local session = W.active
    if session and session.outOfCombatAt and PvPInteraction(info, playerGUID) then
        local now = GetTime()
        local hostileGUID = DirectHostileGUID(info, playerGUID)
        if now - session.outOfCombatAt >= COMBAT_END_GRACE then
            -- The grace period elapsed before the next direct PvP event. Even
            -- the same opponent is now a new encounter.
            W.Finish("combat-ended")
            session = nil
        elseif hostileGUID and not session.enemies[hostileGUID] then
            -- A different player starting the next combat after a full combat
            -- drop is not part of the prior fight. This is the key protection
            -- against a stream of sequential players becoming 22v38, etc.
            W.Finish("new-opponent-after-combat")
            session = nil
        else
            -- Same opponent came back during the short Classic combat-drop
            -- grace period. Treat it as continuity (Vanish/Feign/CC/etc.).
            session.outOfCombatAt = nil
        end
    end
    if not session then
        if not PvPInteraction(info, playerGUID) then return end
        session = W.Start(playerGUID, info)
        if not session then return end
    end

    MarkInteraction(session, info)
    if IsPlayer(info[6]) then InferParticipantClassFromCombat(session, info[4], info[12], info[13]) end
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
        if enemy then
            enemy.level = enemy.level or ResolvePlayerLevel(enemy.guid)
            enemy.died = true; enemy.killedAt = GetTime() - session.startedElapsed
            session.lastKillPosition = PlayerPosition() or session.lastKillPosition
            if info[4] == playerGUID then session.killingBlows = (session.killingBlows or 0) + 1; enemy.killingBlow = true end
        end
    elseif event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
        if info[8] == playerGUID then
            session.playerDied = true
            session.playerDiedAt = GetTime() - session.startedElapsed
            session.deathPosition = PlayerPosition() or session.deathPosition
        elseif session.enemies[info[8]] then
            session.enemies[info[8]].level = session.enemies[info[8]].level or ResolvePlayerLevel(info[8])
            session.enemies[info[8]].died = true
            session.enemies[info[8]].killedAt = GetTime() - session.startedElapsed
            session.lastKillPosition = PlayerPosition() or session.lastKillPosition
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
        resultLabel = "OUTNUMBERED VICTORY",
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
                best = math.max(best, prior.peakContestingEnemies or prior.enemyCount or 0)
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

    local enemyCount = math.max(record.peakContestingEnemies or record.contestingEnemyCount or record.enemyCount or 2, 2)
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
    local store = W.observer.worldPvP
    record.id = store.nextSequence
    store.nextSequence = store.nextSequence + 1
    store.encounters[#store.encounters + 1] = record
    TrimEncounterStore(store)
    W.ShowResultToast(record)
    if W.callbacks and W.callbacks.saved then W.callbacks.saved(record) end
    if W.callbacks and W.callbacks.changed then W.callbacks.changed() end
end

function W.Event(event, ...)
    if W.active and UnitGUID and (event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_AURA") then
        local unit = event == "NAME_PLATE_UNIT_ADDED" and (...) or event == "UNIT_AURA" and (...) or event == "UPDATE_MOUSEOVER_UNIT" and "mouseover" or "target"
        local guid = unit and UnitGUID(unit)
        local enemy = guid and W.active.enemies and W.active.enemies[guid]
        if enemy then
            enemy.level = enemy.level or ResolvePlayerLevel(guid)
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

function W.Summary()
    local summary = {kills = 0, deaths = 0, soloWins = 0, soloLosses = 0, outnumberedVictories = 0,
        honorableKills = 0, ganks = 0, lowbieGanks = 0, longestOutnumbered = 0, encounters = 0, rivals = 0,
        currentStreak = 0, longestStreak = 0, favoriteZone = nil, favoriteZoneKills = 0,
        mostKilledName = nil, mostKilledClass = nil, mostKilledKills = 0, mostKilledDeaths = 0,
        nemesisName = nil, nemesisClass = nil, nemesisDeaths = 0, nemesisKills = 0}
    local streak, rivals, zones, rivalStats = 0, {}, {}, {}
    for _, record in ipairs(W.GetEncounters()) do
        summary.encounters = summary.encounters + 1
        local recordKills = record.enemyDeaths or 0
        summary.kills = summary.kills + recordKills
        local zone = SummaryZoneName(record.location)
        if recordKills > 0 and zone and zone ~= "" and zone ~= "Unknown" then
            local z = zones[zone] or {kills = 0, encounters = 0}
            z.kills = z.kills + recordKills
            z.encounters = z.encounters + 1
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
                    r = {name = ShortName(enemy.name), class = enemy.class, kills = 0, deaths = 0, encounters = 0, lastAt = 0}
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
                if record.playerDied then r.deaths = r.deaths + 1 end
            end
        end
        local contesting = record.contestingEnemyCount
        if contesting == nil then contesting = record.enemyCount or 0 end -- legacy records
        if record.friendlyCount == 1 and contesting == 1 then
            if record.resultKey == "victory" then summary.soloWins = summary.soloWins + 1
            elseif record.playerDied then summary.soloLosses = summary.soloLosses + 1 end
        end
        if record.resultKey == "outnumbered_victory" then
            summary.outnumberedVictories = summary.outnumberedVictories + 1
            summary.longestOutnumbered = math.max(summary.longestOutnumbered, record.peakContestingEnemies or record.enemyCount or 0)
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

    local mostKilled, nemesis
    for _, r in pairs(rivalStats) do
        if r.kills > 0 and (not mostKilled or r.kills > mostKilled.kills or
            (r.kills == mostKilled.kills and r.encounters > mostKilled.encounters) or
            (r.kills == mostKilled.kills and r.encounters == mostKilled.encounters and r.lastAt > mostKilled.lastAt)) then
            mostKilled = r
        end
        if r.deaths > 0 and (not nemesis or r.deaths > nemesis.deaths or
            (r.deaths == nemesis.deaths and r.encounters > nemesis.encounters) or
            (r.deaths == nemesis.deaths and r.encounters == nemesis.encounters and r.lastAt > nemesis.lastAt)) then
            nemesis = r
        end
    end
    if mostKilled then
        summary.mostKilledName, summary.mostKilledClass = mostKilled.name, mostKilled.class
        summary.mostKilledKills, summary.mostKilledDeaths = mostKilled.kills, mostKilled.deaths
    end
    if nemesis then
        summary.nemesisName, summary.nemesisClass = nemesis.name, nemesis.class
        summary.nemesisDeaths, summary.nemesisKills = nemesis.deaths, nemesis.kills
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
            if record.playerDied then entry.deaths = entry.deaths + 1 end
            local soloContested = record.friendlyCount == 1 and record.enemyCount == 1 and
                (record.pressureModelVersion ~= 1 or enemy.pressuredPlayer == true) and not GankKind(record, enemy)
            if soloContested then
                if enemy.died then entry.soloKills = entry.soloKills + 1 end
                if record.playerDied then entry.soloDeaths = entry.soloDeaths + 1 end
            end
            data.byOpponent[key] = data.byOpponent[key] or {}
            data.byOpponent[key][#data.byOpponent[key] + 1] = record

            local classKey = enemy.class or "UNKNOWN"
            local class = classes[classKey]
            if not class then class = {key = classKey, kills = 0, deaths = 0, encounters = 0, rivals = {}}; classes[classKey] = class end
            class.encounters = class.encounters + 1
            class.rivals[key] = true
            if enemy.died then class.kills = class.kills + 1 end
            if record.playerDied then class.deaths = class.deaths + 1 end
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
    -- C_MapExplorationInfo overlays on top. Mirror that composition here so
    -- encounter cards look like the player's actual map instead of a permanently
    -- unrevealed parchment. This still respects normal Classic exploration; it
    -- does not manufacture art for areas this character has never discovered.
    local overlayUsed = 0
    local getExplored = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
    local explored = getExplored and getExplored(mapID) or nil
    for _, overlay in ipairs(explored or {}) do
        local overlayWidth = tonumber(overlay.textureWidth) or 0
        local overlayHeight = tonumber(overlay.textureHeight) or 0
        local offsetX = tonumber(overlay.offsetX) or 0
        local offsetY = tonumber(overlay.offsetY) or 0
        local fileIDs = overlay.fileDataIDs or {}
        if overlayWidth > 0 and overlayHeight > 0 and #fileIDs > 0 then
            -- Exploration textures are authored as 256px tiles in the same map
            -- coordinate space as the base art layer. Edge tiles are padded, so
            -- trim their texcoords to the overlay's declared dimensions.
            local tileSize = 256
            local overlayColumns = math.ceil(overlayWidth / tileSize)
            local overlayRows = math.ceil(overlayHeight / tileSize)
            local fileIndex = 0
            for overlayRow = 1, overlayRows do
                for overlayColumn = 1, overlayColumns do
                    fileIndex = fileIndex + 1
                    local fileID = fileIDs[fileIndex]
                    if fileID then
                        overlayUsed = overlayUsed + 1
                        local tile = EnsureExplorationTile(map, overlayUsed)
                        local localX = (overlayColumn - 1) * tileSize
                        local localY = (overlayRow - 1) * tileSize
                        local remainingW = math.min(tileSize, overlayWidth - localX)
                        local remainingH = math.min(tileSize, overlayHeight - localY)
                        tile:SetTexture(fileID)
                        tile:ClearAllPoints()
                        tile:SetPoint("TOPLEFT", map.canvas, "TOPLEFT", (offsetX + localX) * scale, -(offsetY + localY) * scale)
                        tile:SetSize(remainingW * scale, remainingH * scale)
                        tile:SetTexCoord(0, remainingW / tileSize, 0, remainingH / tileSize)
                        tile:Show()
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
local OVERVIEW_PAGE_BASE_X = -12

local function PositionOverviewPage(page, canvas, offset)
    if not page or not canvas then return end
    local x = (offset or 0) + OVERVIEW_PAGE_BASE_X
    page:ClearAllPoints()
    page:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, 0)
    page:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", x, 0)
end

local OVERVIEW_CLIP_LEFT = 12
local OVERVIEW_CLIP_WIDTH = 324

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
    -- The Character pane's inner field is x=18..342. Overview is offset 6px
    -- from CharacterFrame, so clip the carousel at x=12..336 here. Keep the
    -- scroll child in the original Overview coordinate system and scroll it by
    -- the same inset: stationary content does not shift, but moving pages can
    -- never paint over the stone border or outside the pane.
    viewport:ClearAllPoints()
    viewport:SetPoint("TOPLEFT", host, "TOPLEFT", OVERVIEW_CLIP_LEFT, 0)
    viewport:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", OVERVIEW_CLIP_LEFT, 0)
    viewport:SetWidth(OVERVIEW_CLIP_WIDTH)
    canvas:ClearAllPoints(); canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
    canvas:SetSize(width, height)
    if viewport.SetHorizontalScroll then viewport:SetHorizontalScroll(OVERVIEW_CLIP_LEFT) end
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
    local subtitle = world:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", 26, -178); subtitle:SetWidth(300); subtitle:SetJustifyH("CENTER")
    subtitle:SetText("Open-world record")
    W.overviewSubtitle = subtitle
    local currentStreak = world:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    currentStreak:SetPoint("TOPLEFT", 38, -198); currentStreak:SetWidth(124); currentStreak:SetJustifyH("CENTER")
    local bestStreak = world:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bestStreak:SetPoint("TOPLEFT", 190, -198); bestStreak:SetWidth(124); bestStreak:SetJustifyH("CENTER")
    W.overviewCurrentStreak, W.overviewBestStreak = currentStreak, bestStreak

    local left = DP.Theme.StatSlab(world, 26, -240, 140, 58, false)
    local right = DP.Theme.StatSlab(world, 186, -240, 140, 58, true)
    W.overviewSlabDivider = DP.Theme.StatDivider(world, 176, -269, 46)
    local soloTop = left:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    soloTop:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -8); soloTop:SetPoint("TOPRIGHT", left, "TOPRIGHT", -8, -8); soloTop:SetJustifyH("CENTER")
    local soloMid = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soloMid:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -24); soloMid:SetPoint("TOPRIGHT", left, "TOPRIGHT", -8, -24); soloMid:SetJustifyH("CENTER")
    local soloBot = left:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    soloBot:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -40); soloBot:SetPoint("TOPRIGHT", left, "TOPRIGHT", -8, -40); soloBot:SetJustifyH("CENTER")
    W.overviewSoloTop, W.overviewSoloMid, W.overviewSoloBot = soloTop, soloMid, soloBot

    local outTop = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    outTop:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -8); outTop:SetPoint("TOPRIGHT", right, "TOPRIGHT", -8, -8); outTop:SetJustifyH("CENTER")
    local outMid = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    outMid:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -24); outMid:SetPoint("TOPRIGHT", right, "TOPRIGHT", -8, -24); outMid:SetJustifyH("CENTER")
    local outBot = right:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    outBot:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -40); outBot:SetPoint("TOPRIGHT", right, "TOPRIGHT", -8, -40); outBot:SetJustifyH("CENTER")
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
    SlabTooltip(left, "Solo 1v1", function(summary)
        GameTooltip:AddLine("Unassisted fights where one opponent contested you.", 1, 1, 1, true)
        GameTooltip:AddLine(string.format("Record: %d-%d", summary.soloWins or 0, summary.soloLosses or 0), .4, .9, .68)
    end)
    SlabTooltip(right, "Solo 1vN", function(summary)
        local best = (summary.longestOutnumbered or 0) >= 2 and ("1v" .. tostring(summary.longestOutnumbered)) or "—"
        GameTooltip:AddLine("Solo wins against overlapping pressure from 2+ enemies.", 1, 1, 1, true)
        GameTooltip:AddLine(string.format("Wins: %d • Best: %s", summary.outnumberedVictories or 0, best), 1, .82, .42)
    end)

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

    -- Bronze quadrant rules live entirely inside the recessed field.
    local vRule = bottom:CreateTexture(nil, "ARTWORK")
    vRule:SetColorTexture(.84, .56, .31, .28)
    vRule:SetPoint("TOP", bottom, "TOP", 0, -7); vRule:SetPoint("BOTTOM", bottom, "BOTTOM", 0, 7); vRule:SetWidth(1)
    local hRule = bottom:CreateTexture(nil, "ARTWORK")
    hRule:SetColorTexture(.84, .56, .31, .28)
    hRule:SetPoint("LEFT", bottom, "LEFT", 9, 0); hRule:SetPoint("RIGHT", bottom, "RIGHT", -9, 0); hRule:SetHeight(1)

    local function quadrant(x, y)
        local holder = CreateFrame("Frame", nil, bottom)
        holder:SetPoint("TOPLEFT", bottom, "TOPLEFT", x, y)
        holder:SetSize(148, 37)
        local label = holder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetPoint("CENTER", holder, "CENTER", 0, 7); label:SetWidth(132); label:SetJustifyH("CENTER")
        local value = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("CENTER", holder, "CENTER", 0, -8); value:SetWidth(132); value:SetJustifyH("CENTER")
        holder:EnableMouse(true)
        return holder, label, value
    end
    local hkBox, hkL, hkV = quadrant(0, 0)
    local gankBox, gankL, gankV = quadrant(148, 0)
    local mostBox, mostL, mostV = quadrant(0, -37)
    local nemesisBox, nemesisL, nemesisV = quadrant(148, -37)
    W.overviewStatLabels = {hkL=hkL, hkV=hkV, gankL=gankL, gankV=gankV,
        mostL=mostL, mostV=mostV, nemesisL=nemesisL, nemesisV=nemesisV}
    W.overviewStatBoxes = {hk=hkBox, gank=gankBox, most=mostBox, nemesis=nemesisBox}

    local function StatTooltip(box, title, build)
        box:SetScript("OnEnter", function(self)
            local summary = W.Summary()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title)
            build(summary)
            GameTooltip:Show()
        end)
        box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    StatTooltip(hkBox, "Honorable kills", function(summary)
        GameTooltip:AddLine("Blizzard-awarded HKs recorded by Rivals.", 1, 1, 1, true)
        GameTooltip:AddLine(string.format("Total: %d", summary.honorableKills or 0), 1, .82, .42)
    end)
    StatTooltip(gankBox, "Ganks", function(summary)
        GameTooltip:AddLine("Kills against lower-level players.", 1, 1, 1, true)
        GameTooltip:AddLine(string.format("%d total • %d were 5+ levels below", summary.ganks or 0, summary.lowbieGanks or 0), 1, .68, .40)
    end)
    StatTooltip(mostBox, "Most killed rival", function(summary)
        if not summary.mostKilledName then
            GameTooltip:AddLine("No rival kills recorded yet.", .72, .76, .82)
            return
        end
        GameTooltip:AddLine(summary.mostKilledName, 1, 1, 1)
        GameTooltip:AddLine(string.format("Killed %d times", summary.mostKilledKills or 0), 1, .82, .42)
        GameTooltip:AddLine(string.format("Killed you %d times", summary.mostKilledDeaths or 0), .72, .76, .82)
    end)
    StatTooltip(nemesisBox, "Nemesis", function(summary)
        if not summary.nemesisName then
            GameTooltip:AddLine("No World PvP deaths recorded yet.", .72, .76, .82)
            return
        end
        GameTooltip:AddLine(summary.nemesisName, 1, 1, 1)
        GameTooltip:AddLine(string.format("Killed you %d times", summary.nemesisDeaths or 0), 1, .45, .45)
        GameTooltip:AddLine(string.format("You killed them %d times", summary.nemesisKills or 0), .72, .76, .82)
        GameTooltip:AddLine("Deaths are encounter-relative when an exact killing blow is unavailable.", .62, .66, .72, true)
    end)
    W.overviewLowerCard = lowerCard

    local note = world:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 26, -390); note:SetWidth(300); note:SetJustifyH("CENTER")
    note:SetText("Open-world encounters • no Duel Rating impact")

    -- Deaths and K/D are useful history, but not the identity of this page. Keep
    -- them one hover away rather than making them the headline.
    local cardHover = CreateFrame("Button", nil, world)
    cardHover:SetSize(300, 96); cardHover:SetPoint("TOPLEFT", 26, -130)
    cardHover:SetFrameLevel(world:GetFrameLevel() + 8)
    cardHover:SetScript("OnEnter", function(self)
        local summary = W.Summary()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("World PvP record")
        GameTooltip:AddLine(string.format("Kills  %d", summary.kills or 0), .4, .9, .68)
        GameTooltip:AddLine(string.format("Deaths  %d", summary.deaths or 0), 1, .45, .45)
        GameTooltip:AddLine(string.format("K/D  %.2f", (summary.kills or 0) / math.max(1, summary.deaths or 0)), 1, .82, .42)
        GameTooltip:AddLine(string.format("Fights recorded  %d   Rivals  %d", summary.encounters or 0, summary.rivals or 0), .75, .78, .84)
        if summary.favoriteZone then
            GameTooltip:AddLine(string.format("Favorite zone  %s (%d kills)", summary.favoriteZone, summary.favoriteZoneKills or 0), 1, .82, .42)
        end
        GameTooltip:Show()
    end)
    cardHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    W.overviewCardHover = cardHover

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
    dots:SetPoint("CENTER", overview, "TOPLEFT", 176, -233)
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
    if W.overviewSubtitle then
        if s.favoriteZone and (s.favoriteZoneKills or 0) > 0 then
            local noun = s.favoriteZoneKills == 1 and "kill" or "kills"
            W.overviewSubtitle:SetText(string.format("|cff9f9f9fFavorite zone|r  |cffffce70%s|r  •  %d %s", s.favoriteZone, s.favoriteZoneKills, noun))
        else
            W.overviewSubtitle:SetText("Open-world record")
        end
    end
    if W.overviewCurrentStreak then W.overviewCurrentStreak:SetText(string.format("|cff65e6ad%d|r current streak", s.currentStreak or 0)) end
    if W.overviewBestStreak then W.overviewBestStreak:SetText(string.format("|cffffce70%d|r best streak", s.longestStreak or 0)) end

    if W.overviewSoloTop then W.overviewSoloTop:SetText(string.format("|cff65e6ad%d|r—|cffff8888%d|r", s.soloWins or 0, s.soloLosses or 0)) end
    if W.overviewSoloMid then W.overviewSoloMid:SetText("Solo 1v1") end
    if W.overviewSoloBot then
        local wins = s.soloWins or 0
        W.overviewSoloBot:SetText(string.format("%d %s", wins, wins == 1 and "victory" or "victories"))
    end

    local largest = (s.longestOutnumbered or 0) >= 2 and ("1v" .. tostring(s.longestOutnumbered)) or "—"
    if W.overviewOutTop then W.overviewOutTop:SetText(string.format("|cffffce70%d|r", s.outnumberedVictories or 0)) end
    if W.overviewOutMid then W.overviewOutMid:SetText("Solo 1vN") end
    if W.overviewOutBot then W.overviewOutBot:SetText("Best " .. largest) end

    local L = W.overviewStatLabels or {}
    if L.hkL then L.hkL:SetText("HONORABLE KILLS") end
    if L.hkV then L.hkV:SetText(string.format("|cffffce70%d|r", s.honorableKills or 0)) end
    if L.gankL then L.gankL:SetText("GANKS") end
    if L.gankV then L.gankV:SetText(string.format("|cffffad66%d|r", s.ganks or 0)) end
    if L.mostL then L.mostL:SetText("MOST KILLED") end
    if L.mostV then
        local value = s.mostKilledName and string.format("%s |cffadb5c2×%d|r", DP.Theme.ClassName(s.mostKilledName, s.mostKilledClass), s.mostKilledKills or 0) or "—"
        L.mostV:SetText(value)
    end
    if L.nemesisL then L.nemesisL:SetText("NEMESIS") end
    if L.nemesisV then
        local value = s.nemesisName and DP.Theme.ClassName(s.nemesisName, s.nemesisClass) or "—"
        L.nemesisV:SetText(value)
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
    function scroll:ScrollByWheel(delta)
        local range = Range(self)
        if range <= 0 then
            self.smoothTarget = 0
            self:SetVerticalScroll(0)
            self:UpdateScrollHints()
            return
        end
        local base = self.smoothTarget
        if base == nil then base = self:GetVerticalScroll() or 0 end
        self.smoothTarget = Clamp(base - delta * step, 0, range)
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
            local amount = math.min(1, math.max(.12, (elapsed or 0) * 12))
            frame:SetVerticalScroll(current + difference * amount)
            frame:UpdateScrollHints()
        end)
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
    local state = enemy.died and "Killed" or "Survived"
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
    if record then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("IN THIS ENCOUNTER", 1, .82, .42)
        local state = enemy.died and "Killed" or "Survived"
        if enemy.killingBlow then state = state .. " — your killing blow" end
        GameTooltip:AddLine(state, enemy.died and 1 or .4, enemy.died and .45 or .9, enemy.died and .45 or .68)
        local fight = OpponentFightStats(record, enemy)
        if fight.damageToYou > 0 or fight.damageFromYou > 0 then
            GameTooltip:AddDoubleLine("Damage exchanged", string.format("%d / %d", math.floor(fight.damageFromYou + .5), math.floor(fight.damageToYou + .5)), .75, .78, .84, .4, .9, .68)
        end
    end
end
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
    window.resultLabel = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); window.resultLabel:SetPoint("TOPLEFT", 10, -9); window.resultLabel:SetWidth(144); window.resultLabel:SetJustifyH("LEFT"); window.resultLabel:SetText("ENCOUNTER")
    window.outcome = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); window.outcome:SetPoint("TOPLEFT", 10, -29); window.outcome:SetWidth(144); window.outcome:SetJustifyH("LEFT")
    window.headcount = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); window.headcount:SetPoint("TOPLEFT", 10, -57); window.headcount:SetWidth(144); window.headcount:SetJustifyH("LEFT")
    local resultRule = window.resultBox:CreateTexture(nil, "ARTWORK"); resultRule:SetColorTexture(.84, .56, .31, .22); resultRule:SetPoint("TOPLEFT", 10, -91); resultRule:SetSize(144, 1)
    window.result = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); window.result:SetPoint("BOTTOMLEFT", 10, 15); window.result:SetWidth(92); window.result:SetJustifyH("LEFT"); window.result:SetWordWrap(false)
    window.duration = window.resultBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); window.duration:SetPoint("BOTTOMRIGHT", -10, 15); window.duration:SetWidth(48); window.duration:SetJustifyH("RIGHT"); window.duration:SetWordWrap(false)

    window.intelBox = CreateFrame("Frame", nil, window)
    window.intelBox:SetPoint("TOPLEFT", 434, -34); window.intelBox:SetSize(184, 142)
    window.intelBox.bg = window.intelBox:CreateTexture(nil, "BACKGROUND"); window.intelBox.bg:SetAllPoints(); window.intelBox.bg:SetColorTexture(.03, .036, .045, .58)
    DP.Theme.Border(window.intelBox, 0, 0, 184, 142)
    window.locationLabel = window.intelBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); window.locationLabel:SetPoint("TOPLEFT", 10, -9); window.locationLabel:SetWidth(164); window.locationLabel:SetJustifyH("LEFT"); window.locationLabel:SetText("LOCATION")
    window.location = window.intelBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); window.location:SetPoint("TOPLEFT", 10, -25); window.location:SetWidth(164); window.location:SetHeight(36); window.location:SetJustifyH("LEFT"); window.location:SetJustifyV("MIDDLE"); window.location:SetWordWrap(true)
    window.subzone = window.intelBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); window.subzone:SetPoint("TOPLEFT", 10, -46); window.subzone:SetWidth(164); window.subzone:SetHeight(18); window.subzone:SetJustifyH("LEFT"); window.subzone:SetJustifyV("TOP"); window.subzone:SetWordWrap(true); window.subzone:Hide()
    local intelRule = window.intelBox:CreateTexture(nil, "ARTWORK"); intelRule:SetColorTexture(.84, .56, .31, .22); intelRule:SetPoint("TOPLEFT", 10, -68); intelRule:SetSize(164, 1)
    window.enemiesLabel = window.intelBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); window.enemiesLabel:SetPoint("TOPLEFT", 10, -77); window.enemiesLabel:SetWidth(164); window.enemiesLabel:SetJustifyH("LEFT"); window.enemiesLabel:SetText("OPPONENTS")
    window.enemiesScroll = CreateFrame("ScrollFrame", nil, window.intelBox)
    window.enemiesScroll:SetPoint("TOPLEFT", 10, -93); window.enemiesScroll:SetSize(164, 40)
    window.enemiesBody = CreateFrame("Frame", nil, window.enemiesScroll); window.enemiesBody:SetSize(164, 40); window.enemiesScroll:SetScrollChild(window.enemiesBody)
    window.enemiesRows = {}
    window.enemiesUpHint = window.intelBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); window.enemiesUpHint:SetPoint("TOPRIGHT", -5, -91); window.enemiesUpHint:SetText("|cffffce70▲|r"); window.enemiesUpHint:Hide()
    window.enemiesDownHint = window.intelBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); window.enemiesDownHint:SetPoint("BOTTOMRIGHT", -5, 5); window.enemiesDownHint:SetText("|cffffce70▼|r"); window.enemiesDownHint:Hide()
    ConfigureSmoothWheelScroll(window.enemiesScroll, window.enemiesBody, 12, window.enemiesUpHint, window.enemiesDownHint)
    window.locationHover = CreateFrame("Frame", nil, window.intelBox); window.locationHover:SetPoint("TOPLEFT", 6, -6); window.locationHover:SetSize(172, 61)

    window.summaryTab = DP.Theme.DataTab(window, "Summary", 20, -191, 110, function() W.SelectDetailTab("summary") end)
    window.usageTab = DP.Theme.DataTab(window, "Items & Abilities", 131, -191, 150, function() W.SelectDetailTab("usage") end)
    window.logTab = DP.Theme.DataTab(window, "Combat Log", 282, -191, 120, function() W.SelectDetailTab("log") end)

    window.content = CreateFrame("Frame", nil, window); window.content:SetPoint("TOPLEFT", 20, -221); window.content:SetPoint("BOTTOMRIGHT", -20, 18)
    if window.content.SetClipsChildren then window.content:SetClipsChildren(false) end

    -- Summary uses a denser two-column layout: compact metric plaques and
    -- encounter context on the left, enemy rivalry cards on the right.
    window.summaryMetrics = CreateFrame("Frame", nil, window.content)
    window.summaryMetrics:SetPoint("TOPLEFT", 0, -4); window.summaryMetrics:SetSize(276, 128)
    window.summaryMetricTiles = {}
    local metricNames = {"Enemy players", "Kills", "Killing blows", "Honorable kills"}
    local metricPositions = {{0, 0}, {142, 0}, {0, -66}, {142, -66}}
    for i, name in ipairs(metricNames) do
        local tile = CreateFrame("Frame", nil, window.summaryMetrics)
        local pos = metricPositions[i]
        tile:SetSize(134, 60); tile:SetPoint("TOPLEFT", pos[1], pos[2])
        tile.bg = tile:CreateTexture(nil, "BACKGROUND"); tile.bg:SetAllPoints(); tile.bg:SetColorTexture(.045, .055, .07, .86)
        DP.Theme.Border(tile, 0, 0, 134, 60)
        tile.value = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); tile.value:SetPoint("TOPLEFT", 6, -10); tile.value:SetWidth(122); tile.value:SetJustifyH("CENTER")
        tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); tile.label:SetPoint("TOPLEFT", 6, -38); tile.label:SetWidth(122); tile.label:SetJustifyH("CENTER"); tile.label:SetText(name)
        local metricIndex = i
        DetailTooltip(tile, name, function(_, record)
            if metricIndex == 1 then
                GameTooltip:AddLine("Unique enemy players Rivals associated with this encounter.", 1, 1, 1, true)
                GameTooltip:AddDoubleLine("Recorded", tostring(record.enemyCount or 0), .75, .78, .84, 1, .82, .42)
                GameTooltip:AddDoubleLine("Directly contested you", tostring(record.contestingEnemyCount or 0), .75, .78, .84, 1, 1, 1)
                GameTooltip:AddDoubleLine("Peak pressure at once", tostring(record.peakContestingEnemies or 0), .75, .78, .84, 1, .82, .42)
                GameTooltip:AddLine(" ")
                AddTooltipEnemyList(record)
            elseif metricIndex == 2 then
                local kills = record.enemyDeaths or 0
                local kb = record.killingBlows or 0
                GameTooltip:AddLine("Enemy players who died during this encounter.", 1, 1, 1, true)
                GameTooltip:AddDoubleLine("Kills", tostring(kills), .75, .78, .84, .4, .9, .68)
                GameTooltip:AddDoubleLine("Your killing blows", tostring(kb), .75, .78, .84, 1, .82, .42)
                if kills > kb then GameTooltip:AddDoubleLine("Deaths without your KB", tostring(kills - kb), .75, .78, .84, .72, .76, .82) end
                GameTooltip:AddLine(" ")
                AddTooltipEnemyList(record, function(enemy) return enemy.died end, "No enemy deaths were recorded.")
            elseif metricIndex == 3 then
                local kills = record.enemyDeaths or 0
                local kb = record.killingBlows or 0
                GameTooltip:AddLine("Kills where Rivals observed direct killing-blow credit for you.", 1, 1, 1, true)
                GameTooltip:AddDoubleLine("Killing blows", tostring(kb), .75, .78, .84, .4, .9, .68)
                if kills > 0 then GameTooltip:AddDoubleLine("Share of tracked kills", string.format("%d%%", math.floor((kb / kills) * 100 + .5)), .75, .78, .84, 1, .82, .42) end
                GameTooltip:AddLine(" ")
                AddTooltipEnemyList(record, function(enemy) return enemy.killingBlow end, "No direct killing blows were recorded.")
            else
                local hk = record.honorableKills or 0
                local kills = record.enemyDeaths or 0
                GameTooltip:AddLine("Blizzard-awarded honorable-kill credit observed during this encounter.", 1, 1, 1, true)
                GameTooltip:AddDoubleLine("Honorable kills", tostring(hk), .75, .78, .84, 1, .82, .42)
                GameTooltip:AddDoubleLine("Tracked enemy deaths", tostring(kills), .75, .78, .84, .4, .9, .68)
                if hk ~= kills then
                    GameTooltip:AddLine("Honor credit and tracked deaths can differ because Blizzard's HK credit is separate from Rivals' encounter death tracking.", .65, .7, .76, true)
                end
            end
        end)
        window.summaryMetricTiles[i] = tile
    end
    window.summaryContextBox = CreateFrame("Frame", nil, window.content)
    window.summaryContextBox:SetPoint("TOPLEFT", 0, -142); window.summaryContextBox:SetSize(276, 88)
    window.summaryContextBox.bg = window.summaryContextBox:CreateTexture(nil, "BACKGROUND"); window.summaryContextBox.bg:SetAllPoints(); window.summaryContextBox.bg:SetColorTexture(.035, .045, .06, .72)
    DP.Theme.Border(window.summaryContextBox, 0, 0, 276, 88)
    window.summaryContextTitle = window.summaryContextBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    window.summaryContextTitle:SetPoint("TOPLEFT", 10, -8); window.summaryContextTitle:SetWidth(256); window.summaryContextTitle:SetJustifyH("LEFT"); window.summaryContextTitle:SetText("ENCOUNTER CONTEXT")
    window.summaryNotes = window.summaryContextBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.summaryNotes:SetPoint("TOPLEFT", 10, -28); window.summaryNotes:SetWidth(256); window.summaryNotes:SetJustifyH("LEFT"); window.summaryNotes:SetJustifyV("TOP")
    DetailTooltip(window.summaryContextBox, "Encounter context", function(_, record)
        GameTooltip:AddLine(DetailEncounterLabel(record), 1, .82, .42)
        GameTooltip:AddLine(record.playerDied and "You died." or "You survived.", record.playerDied and 1 or .4, record.playerDied and .45 or .9, record.playerDied and .45 or .68)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Friendly offensive contributors", tostring(record.friendlyCount or 1), .75, .78, .84, 1, 1, 1)
        GameTooltip:AddDoubleLine("Enemies who contested you", tostring(record.contestingEnemyCount or 0), .75, .78, .84, 1, 1, 1)
        GameTooltip:AddDoubleLine("Peak simultaneous pressure", tostring(record.peakContestingEnemies or 0), .75, .78, .84, 1, .82, .42)
        GameTooltip:AddDoubleLine("Duration", HeaderDurationText(record.duration), .75, .78, .84, 1, 1, 1)
        if record.endReason then GameTooltip:AddDoubleLine("Encounter ended by", FriendlyEndReason(record.endReason) or "Unknown", .75, .78, .84, .72, .76, .82) end
        GameTooltip:AddLine(" ")
        if (record.friendlyCount or 1) == 1 then
            GameTooltip:AddLine("No other friendly player offensively contributed to a tracked enemy, so this is counted as solo on your side.", .65, .7, .76, true)
        else
            GameTooltip:AddLine("Friendly count only includes players Rivals saw offensively contribute to a tracked enemy.", .65, .7, .76, true)
        end
        local ganks, lowbies = CountGanks(record)
        if ganks > 0 then GameTooltip:AddLine(string.format("Gank flags: %d%s", ganks, lowbies > 0 and (" (" .. lowbies .. " low-level)") or ""), 1, .68, .4) end
        GameTooltip:AddLine(record.npcAssistance and "NPC assistance/interference detected." or "No NPC assistance detected.", record.npcAssistance and 1 or .65, record.npcAssistance and .68 or .7, record.npcAssistance and .4 or .76, true)
    end)
    window.summaryRivalsTitle = window.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.summaryRivalsTitle:SetPoint("TOPLEFT", 292, -4); window.summaryRivalsTitle:SetWidth(306); window.summaryRivalsTitle:SetJustifyH("LEFT"); window.summaryRivalsTitle:SetText("OPPONENT RECORDS")
    window.summaryRivalsBox = CreateFrame("Frame", nil, window.content)
    window.summaryRivalsBox:SetPoint("TOPLEFT", 292, -24); window.summaryRivalsBox:SetSize(306, 206)
    window.summaryRivalsBox.bg = window.summaryRivalsBox:CreateTexture(nil, "BACKGROUND"); window.summaryRivalsBox.bg:SetAllPoints(); window.summaryRivalsBox.bg:SetColorTexture(.035, .045, .06, .72)
    DP.Theme.Border(window.summaryRivalsBox, 0, 0, 306, 206)
    window.summaryRivalsScroll = CreateFrame("ScrollFrame", nil, window.summaryRivalsBox)
    window.summaryRivalsScroll:SetPoint("TOPLEFT", 5, -5); window.summaryRivalsScroll:SetPoint("BOTTOMRIGHT", -5, 5)
    window.summaryRivalsBody = CreateFrame("Frame", nil, window.summaryRivalsScroll); window.summaryRivalsBody:SetSize(296, 196); window.summaryRivalsScroll:SetScrollChild(window.summaryRivalsBody)
    window.summaryRivalCards = {}
    window.summaryRivalsUpHint = window.summaryRivalsBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); window.summaryRivalsUpHint:SetPoint("TOPRIGHT", -3, -2); window.summaryRivalsUpHint:SetText("|cffffce70▲|r"); window.summaryRivalsUpHint:Hide()
    window.summaryRivalsDownHint = window.summaryRivalsBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); window.summaryRivalsDownHint:SetPoint("BOTTOMRIGHT", -3, 2); window.summaryRivalsDownHint:SetText("|cffffce70▼|r"); window.summaryRivalsDownHint:Hide()
    ConfigureSmoothWheelScroll(window.summaryRivalsScroll, window.summaryRivalsBody, 30, window.summaryRivalsUpHint, window.summaryRivalsDownHint)
    window.summaryRivalsEmpty = window.summaryRivalsBody:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.summaryRivalsEmpty:SetPoint("TOPLEFT", 5, -5); window.summaryRivalsEmpty:SetWidth(286); window.summaryRivalsEmpty:SetJustifyH("LEFT"); window.summaryRivalsEmpty:SetJustifyV("TOP"); window.summaryRivalsEmpty:Hide()

    window.filter = DP.Theme.DropDown(window.content, 0, -2, 180, function()
        local options = {{text = "All participants", value = "all"}}
        local record = window.record
        if record then
            options[#options + 1] = {text = "You", value = record.playerGUID}
            for _, enemy in ipairs(record.enemies or {}) do options[#options + 1] = {text = ShortName(enemy.name), value = enemy.guid} end
            for _, friendly in ipairs(record.friendlies or {}) do
                if friendly.guid ~= record.playerGUID then options[#options + 1] = {text = ShortName(friendly.name), value = friendly.guid} end
            end
        end
        return options
    end, function(value) window.participantFilter = value or "all"; W.RefreshDetailContent() end)

    window.usageHeader = CreateFrame("Frame", nil, window.content); window.usageHeader:SetPoint("TOPLEFT", 0, -38); window.usageHeader:SetSize(552, 24)
    window.usageHeader.bg = window.usageHeader:CreateTexture(nil, "BACKGROUND"); window.usageHeader.bg:SetAllPoints(); window.usageHeader.bg:SetColorTexture(.08, .09, .11, .95)
    local headers = {{"Time", 0, 54}, {"Player", 54, 118}, {"Used", 172, 274}, {"Target", 446, 106}}
    for _, h in ipairs(headers) do
        local text = window.usageHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); text:SetPoint("TOPLEFT", h[2] + 6, -6); text:SetWidth(h[3] - 10); text:SetJustifyH("LEFT"); text:SetText(h[1])
    end
    -- Blizzard's UIPanelScrollFrameTemplate places its scrollbar just outside
    -- the scrollframe's nominal right edge. Inset the frame enough that the
    -- arrows/thumb remain inside our fixed Encounter Details border.
    window.usageScroll = CreateFrame("ScrollFrame", nil, window.content, "UIPanelScrollFrameTemplate"); window.usageScroll:SetPoint("TOPLEFT", 0, -62); window.usageScroll:SetPoint("BOTTOMRIGHT", -28, 8)
    window.usageBody = CreateFrame("Frame", nil, window.usageScroll); window.usageBody:SetSize(536, 1); window.usageScroll:SetScrollChild(window.usageBody)
    window.usageRows = {}

    window.logBox = CreateFrame("Frame", nil, window.content)
    window.logBox:SetPoint("TOPLEFT", 0, -8); window.logBox:SetPoint("BOTTOMRIGHT", 0, 8)
    window.logBox.bg = window.logBox:CreateTexture(nil, "BACKGROUND"); window.logBox.bg:SetAllPoints(); window.logBox.bg:SetColorTexture(.025, .032, .043, .78)
    local logBorder = DP.Theme.Border(window.logBox, 0, 0, 598, 322)
    logBorder:ClearAllPoints(); logBorder:SetAllPoints(window.logBox); logBorder:EnableMouse(false)
    window.logScroll = CreateFrame("ScrollFrame", nil, window.logBox, "UIPanelScrollFrameTemplate")
    window.logScroll:SetPoint("TOPLEFT", 10, -10); window.logScroll:SetPoint("BOTTOMRIGHT", -28, 10)
    window.logBody = CreateFrame("Frame", nil, window.logScroll); window.logBody:SetSize(552, 1); window.logScroll:SetScrollChild(window.logBody)
    window.logText = window.logBody:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); window.logText:SetPoint("TOPLEFT", 4, -4); window.logText:SetWidth(544); window.logText:SetJustifyH("LEFT"); window.logText:SetJustifyV("TOP"); window.logText:SetWordWrap(true)

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
    local result, normalKeys = {}, {}
    for _, entry in ipairs(events) do
        if filter == "all" or entry.guid == filter then
            result[#result + 1] = entry
            normalKeys[tostring(entry.guid or "") .. ":" .. tostring(entry.spellID or "")] = true
        end
    end
    -- Buff snapshots fill the biggest hole in ordinary usage tracking: things
    -- the opponent consumed before Rivals saw the cast, especially world buffs
    -- and long-duration elixirs/flasks.
    for _, enemy in ipairs(record.enemies or {}) do
        if filter == "all" or filter == enemy.guid then
            for _, buff in ipairs(SortedDetectedBuffs(enemy, "world")) do
                result[#result + 1] = {t = buff.firstSeenAt or 0, guid = enemy.guid, actorName = enemy.name,
                    spellID = buff.spellID, itemID = buff.itemID, name = buff.name, buffCategory = "worldbuffs",
                    displayTarget = buff.activeAtEngagement and "At pull" or buff.gainedDuringFight and "Gained" or "Observed"}
            end
            for _, buff in ipairs(SortedDetectedBuffs(enemy, "consumables")) do
                local key = tostring(enemy.guid or "") .. ":" .. tostring(buff.spellID or "")
                if not (buff.gainedDuringFight and normalKeys[key]) then
                    result[#result + 1] = {t = buff.firstSeenAt or 0, guid = enemy.guid, actorName = enemy.name,
                        spellID = buff.spellID, itemID = buff.itemID, name = buff.name, buffCategory = "consumablebuffs",
                        displayTarget = buff.activeAtEngagement and "At pull" or buff.gainedDuringFight and "Gained" or "Observed"}
                end
            end
        end
    end
    return result
end

local CATEGORY_ORDER = {worldbuffs = 0, consumablebuffs = 1, potions = 2, engineering = 3, equipment = 4, cooldowns = 5, racials = 6}
local CATEGORY_LABEL = {worldbuffs = "World Buffs", consumablebuffs = "Consumable Buffs", potions = "Potions/Consumables", engineering = "Engineering Gadgets", equipment = "Equipment", cooldowns = "Cooldowns (≥3 min)", racials = "Racials"}

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
    local row = window.usageRows[index]
    if row and row.kind == kind then return row end
    if row then row:Hide() end
    row = CreateFrame("Button", nil, window.usageBody); row.kind = kind; row:SetSize(552, kind == "category" and 24 or 22)
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
    if kind == "category" then
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.label:SetPoint("LEFT", 7, 0); row.label:SetWidth(536); row.label:SetJustifyH("LEFT")
    else
        row.time = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); row.time:SetPoint("TOPLEFT", 6, -5); row.time:SetWidth(48); row.time:SetJustifyH("LEFT")
        row.player = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.player:SetPoint("TOPLEFT", 60, -5); row.player:SetWidth(106); row.player:SetJustifyH("LEFT"); row.player:SetWordWrap(false)
        row.used = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.used:SetPoint("TOPLEFT", 178, -5); row.used:SetWidth(258); row.used:SetJustifyH("LEFT"); row.used:SetWordWrap(false)
        row.target = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); row.target:SetPoint("TOPLEFT", 452, -5); row.target:SetWidth(94); row.target:SetJustifyH("LEFT"); row.target:SetWordWrap(false)
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

local function EnsureSummaryRivalCard(window, index)
    local card = window.summaryRivalCards[index]
    if card then return card end
    card = CreateFrame("Frame", nil, window.summaryRivalsBody)
    card:SetSize(286, 47)
    card.bg = card:CreateTexture(nil, "BACKGROUND"); card.bg:SetAllPoints(); card.bg:SetColorTexture(.045, .055, .07, .92)
    DP.Theme.Border(card, 0, 0, 286, 47)
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); card.name:SetPoint("TOPLEFT", 8, -4); card.name:SetWidth(132); card.name:SetJustifyH("LEFT"); card.name:SetWordWrap(false)
    card.state = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); card.state:SetPoint("TOPRIGHT", -8, -4); card.state:SetWidth(100); card.state:SetJustifyH("RIGHT"); card.state:SetWordWrap(false)
    card.status = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); card.status:SetPoint("TOPLEFT", 8, -17); card.status:SetWidth(270); card.status:SetJustifyH("LEFT"); card.status:SetWordWrap(false)
    card.record = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); card.record:SetPoint("TOPLEFT", 8, -30); card.record:SetWidth(270); card.record:SetJustifyH("LEFT"); card.record:SetWordWrap(false)
    card:EnableMouse(true); card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", function(_, delta) if window.summaryRivalsScroll and window.summaryRivalsScroll.ScrollByWheel then window.summaryRivalsScroll:ScrollByWheel(delta) end end)
    card:SetScript("OnEnter", function(self)
        if not self.enemy then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        AddOpponentRecordTooltip(self.enemy, self.stats, window.record)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    window.summaryRivalCards[index] = card
    return card
end

function W.RefreshDetailContent()
    local window = W.details
    local record = window and window.record
    if not window or not record then return end
    local tab = window.activeTab or "summary"
    window.summaryMetrics:SetShown(tab == "summary")
    window.summaryRivalsTitle:SetShown(tab == "summary")
    window.summaryRivalsBox:SetShown(tab == "summary")
    window.summaryRivalsScroll:SetShown(tab == "summary")
    window.summaryContextBox:SetShown(tab == "summary")
    window.summaryNotes:SetShown(tab == "summary")
    window.filter:SetShown(tab == "usage")
    window.usageHeader:SetShown(tab == "usage")
    window.usageScroll:SetShown(tab == "usage")
    window.logBox:SetShown(tab == "log")
    window.logScroll:SetShown(tab == "log")

    if tab == "summary" then
        window:SetHeight(480)
        local metricValues = {
            tostring(record.enemyCount or 0),
            tostring(record.enemyDeaths or 0),
            tostring(record.killingBlows or 0),
            tostring(record.honorableKills or 0),
        }
        for index, value in ipairs(metricValues) do
            local tile = window.summaryMetricTiles[index]
            tile.value:SetText((index == 1 and "|cffffce70" or index == 4 and "|cffffce70" or "|cff65e6ad") .. value .. "|r")
        end

        local matchupData = W.BuildMatchups()
        local opponentStats = {}
        for _, stats in ipairs(matchupData.Opponents or {}) do opponentStats[stats.key] = stats end
        local enemies = record.enemies or {}
        for _, card in ipairs(window.summaryRivalCards or {}) do card:Hide() end
        if window.summaryRivalsEmpty then window.summaryRivalsEmpty:Hide() end
        window.summaryRivalsScroll.smoothTarget = 0
        window.summaryRivalsScroll:SetVerticalScroll(0)
        for index, enemy in ipairs(enemies) do
            local card = EnsureSummaryRivalCard(window, index)
            card:ClearAllPoints(); card:SetPoint("TOPLEFT", 5, -((index - 1) * 49))
            if card then
                local key = enemy.guid or enemy.name
                local stats = opponentStats[key] or {}
                local className = enemy.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[enemy.class]) or enemy.class) or "Unknown"
                local levelText = enemy.level and ("Lv " .. tostring(enemy.level)) or "Lv ?"
                local spec = enemy.spec and enemy.spec.label
                card.enemy, card.stats = enemy, stats
                card.name:SetText(DP.Theme.ClassName(ShortName(enemy.name), enemy.class))
                local gank = enemy.died and GankKind(record, enemy)
                local state = gank == "lowbie" and "|cffff8888Lowbie gank|r" or gank == "gank" and "|cffffad66Gank|r" or enemy.died and "|cffff8888Dead|r" or "|cff65e6adSurvived|r"
                if enemy.killingBlow then state = state .. "  |cffffce70KB|r" end
                card.state:SetText(state)
                card.status:SetText(levelText .. " " .. className .. (spec and (" • " .. spec) or ""))
                card.record:SetText(string.format("W |cff65e6ad%d|r-|cffff8888%d|r  •  S |cff65e6ad%d|r-|cffff8888%d|r  •  %d enc",
                    stats.kills or 0, stats.deaths or 0, stats.soloKills or 0, stats.soloDeaths or 0,
                    stats.encounters or 0))
                card:Show()
            end
        end
        if #enemies == 0 and window.summaryRivalsEmpty then
            window.summaryRivalsEmpty:SetText("|cffadb5c2No enemy player identity was retained for this encounter.|r")
            window.summaryRivalsEmpty:Show()
        end
        window.summaryRivalsBody:SetHeight(math.max(196, #enemies * 49))
        window.summaryRivalsScroll.smoothTarget = 0
        window.summaryRivalsScroll:SetVerticalScroll(0)
        if window.summaryRivalsScroll.UpdateScrollHints then window.summaryRivalsScroll:UpdateScrollHints() end
        for index = #enemies + 1, #window.summaryRivalCards do window.summaryRivalCards[index]:Hide() end
        local contesting = record.contestingEnemyCount or 0
        local pressure = contesting == 1 and "1 enemy contested you" or string.format("%d enemies contested you", contesting)
        local ganks, lowbies = CountGanks(record)
        local gankText = lowbies > 0 and string.format(" • |cffff8888%d lowbie gank%s|r", lowbies, lowbies == 1 and "" or "s") or
            ganks > 0 and string.format(" • |cffffad66%d gank%s|r", ganks, ganks == 1 and "" or "s") or ""
        window.summaryNotes:SetText(string.format("%s • %s • %.0fs%s\n%s", EncounterHeadcount(record), pressure,
            record.duration or 0, gankText, record.npcAssistance and "|cffffad66NPC assistance/interference detected|r" or "No NPC assistance detected"))
    elseif tab == "usage" then
        local filter = window.participantFilter or "all"
        local filterLabel = "All participants"
        if filter ~= "all" then
            local identity = record.session and record.session.participants and record.session.participants[filter]
            filterLabel = filter == record.playerGUID and "You" or ShortName(identity and identity.name or filter)
        end
        window.filter:SetSelectedValue(filter, filterLabel)
        local events = UsageEvents(record, filter)
        table.sort(events, function(a, b)
            local ao, bo = CATEGORY_ORDER[a.buffCategory or a.category] or 99, CATEGORY_ORDER[b.buffCategory or b.category] or 99
            if ao ~= bo then return ao < bo end
            return (a.t or 0) < (b.t or 0)
        end)
        local y, rowIndex, dataRowIndex, lastCategory = 0, 0, 0
        for _, entry in ipairs(events) do
            local display = DescribeWorldUsage(entry, record)
            local category = display.category or entry.category or "cooldowns"
            if category ~= lastCategory then
                rowIndex = rowIndex + 1
                local header = EnsureUsageRow(window, rowIndex, "category")
                header:ClearAllPoints(); header:SetPoint("TOPLEFT", 0, -y); header.bg:SetColorTexture(.09, .07, .035, .92)
                header.label:SetText("|cffffce70" .. (CATEGORY_LABEL[category] or category) .. "|r"); header:Show(); y = y + 24
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
        if #events == 0 then
            rowIndex = 1
            local row = EnsureUsageRow(window, rowIndex, "category"); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, 0); row.bg:SetColorTexture(.045, .055, .07, .6)
            row.label:SetText("|cffadb5c2No tracked item, engineering, racial, or ≥3 minute cooldown use for this filter.|r"); row:Show(); y = 42
        end
        for index = rowIndex + 1, #window.usageRows do window.usageRows[index]:Hide() end
        window.usageBody:SetHeight(math.max(1, y + 12))
        -- Short encounters should not leave a large dead footer. Grow only as
        -- much as the rows need, then cap at the normal scrolling height.
        local usageHeight = math.min(600, math.max(420, 325 + y))
        window:SetHeight(usageHeight)
    elseif tab == "log" then
        local participants = record.session and record.session.participants or {}
        local inferredClassByGUID, inferredClassByName = {}, {}
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
            for _, logEntry in ipairs(record.session and record.session.worldCombatLog or {}) do
                local class = logEntry.sourceGUID and inferredClassByGUID[logEntry.sourceGUID] or nil
                if not class then class = DP.Specs.InferClassFromAbility(logEntry.spellID, logEntry.spellName) end
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
            local name = ShortName(fallback or (identity and identity.name) or "Unknown")
            local class = (identity and identity.class) or inferredClassByGUID[guid] or inferredClassByName[name]
            return class and DP.Theme.ClassName(name, class) or name
        end
        local function AmountText(amount, heal)
            if not amount then return "" end
            return heal and ("|cff65e6ad" .. tostring(math.floor(amount + .5)) .. "|r") or ("|cffff8888" .. tostring(math.floor(amount + .5)) .. "|r")
        end
        local function SpellText(name)
            return name and ("|cffffffff" .. name .. "|r") or ""
        end
        local function EscapePattern(text)
            return (tostring(text or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
        end
        local function ColorLegacyText(entry)
            local text = entry.text or ""
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
                text = text:gsub(" hit ", " |cffff8888hit|r ", 1)
                text = text:gsub(" for (%d+)", " for |cffff8888%1|r", 1)
            elseif entry.event == "SPELL_CAST_SUCCESS" then
                text = text:gsub(" cast ", " |cffffce70cast|r ", 1)
            elseif entry.event == "SPELL_INTERRUPT" then
                text = text:gsub(" interrupted ", " |cffffce70interrupted|r ", 1)
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
                event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" or event == "SPELL_CAST_SUCCESS" or
                event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED" or event == "SPELL_INTERRUPT"
            local needsAmount = event == "SWING_DAMAGE" or event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or
                event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL"
            if (needsSpell and not entry.spellName) or (needsAmount and not entry.amount) then
                return ColorLegacyText(entry)
            end
            local source = ParticipantText(entry.sourceGUID, entry.sourceName)
            local dest = ParticipantText(entry.destGUID, entry.destName)
            local spell = SpellText(entry.spellName or (entry.spellID and ("Spell " .. tostring(entry.spellID))) or nil)
            if event == "SWING_DAMAGE" then
                return string.format("%s |cffff8888hit|r %s for %s", source, dest, AmountText(entry.amount, false))
            elseif event == "SWING_MISSED" then
                return string.format("%s missed %s |cffadb5c2(%s)|r", source, dest, tostring(entry.missType or "miss"))
            elseif event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" then
                return string.format("%s's %s |cffff8888hit|r %s for %s", source, spell, dest, AmountText(entry.amount, false))
            elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
                return string.format("%s's %s |cff65e6adhealed|r %s for %s", source, spell, dest, AmountText(entry.amount, true))
            elseif event == "SPELL_CAST_SUCCESS" then
                return string.format("%s |cffffce70cast|r %s%s", source, spell, entry.destGUID and entry.destGUID ~= entry.sourceGUID and (" on " .. dest) or "")
            elseif event == "SPELL_AURA_APPLIED" then
                return string.format("%s applied %s to %s", source, spell, dest)
            elseif event == "SPELL_AURA_REMOVED" then
                return string.format("%s's %s faded from %s", source, spell, dest)
            elseif event == "SPELL_INTERRUPT" then
                return string.format("%s's %s |cffffce70interrupted|r %s", source, spell, dest)
            elseif event == "PARTY_KILL" then
                return string.format("|cffff8888%s killed %s|r", source, dest)
            elseif event == "UNIT_DIED" then
                return string.format("|cffff8888%s died|r", dest)
            end
            return ColorLegacyText(entry)
        end
        local lines = {}
        for _, entry in ipairs(record.session and record.session.worldCombatLog or {}) do
            lines[#lines + 1] = string.format("|cff8f98a6+%05.1fs|r  %s", entry.t or 0, FormatLogEntry(entry))
        end
        if record.session and record.session.worldCombatTruncated then lines[#lines + 1] = "|cff8f98a6… additional events were omitted.|r" end
        if #lines == 0 then lines[1] = "|cffadb5c2No combat events recorded.|r" end
        window.logText:SetText(table.concat(lines, "\n")); window.logBody:SetHeight(math.max(200, (window.logText:GetStringHeight() or 180) + 12)); window:SetHeight(600)
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

local function EnsureHeaderOpponentRow(window, index)
    window.enemiesRows = window.enemiesRows or {}
    local row = window.enemiesRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, window.enemiesBody)
    row:SetSize(164, 17)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 17)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.text:SetPoint("LEFT", 0, 0)
    row.text:SetWidth(164)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:EnableMouse(true); row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) if window.enemiesScroll and window.enemiesScroll.ScrollByWheel then window.enemiesScroll:ScrollByWheel(delta) end end)
    row:SetScript("OnEnter", function(self)
        if not self.enemy then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        AddEncounterOpponentTooltip(self.enemy, window.record)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    window.enemiesRows[index] = row
    return row
end

function W.OpenDetails(record)
    if DP.Usage and DP.Usage.window and DP.Usage.window:IsShown() then
        DP.Usage.window:Hide()
    end
    local window = EnsureDetails()
    local selectedTab = window.activeTab or "summary"
    window.record = record; window.participantFilter = "all"
    W.SetMapRecord(window.map, record)
    local color = ResultColor(record.resultKey)
    window.outcome:SetText(color .. HeaderOutcomeText(record) .. "|r")
    window.headcount:SetText(EncounterHeadcount(record))
    window.result:SetText(HeaderSurvivalText(record))
    window.duration:SetText(HeaderDurationText(record.duration))
    local loc = record.location or {}
    local zone = SummaryZoneName(loc) or loc.zone or "Unknown location"
    local subzone = loc.subzone and loc.subzone ~= "" and loc.subzone ~= zone and not IsGenericWorldZone(loc.subzone) and loc.subzone or nil
    window.location:SetFontObject((#zone > 26) and GameFontHighlightSmall or GameFontHighlight)
    window.location:ClearAllPoints(); window.location:SetPoint("TOPLEFT", 10, -25)
    if subzone then
        window.location:SetHeight(19); window.location:SetJustifyV("TOP"); window.location:SetText(zone)
        window.subzone:SetText(subzone); window.subzone:Show()
    else
        window.location:SetHeight(36); window.location:SetJustifyV("MIDDLE"); window.location:SetText(zone)
        window.subzone:Hide()
    end
    local matchupData = W.BuildMatchups()
    local opponentStats = {}
    for _, stats in ipairs(matchupData.Opponents or {}) do opponentStats[stats.key] = stats end
    local opponents = record.enemies or {}
    local count = math.max(1, #opponents)
    for index = 1, count do
        local row = EnsureHeaderOpponentRow(window, index)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(index - 1) * 17)
        local enemy = opponents[index]
        if enemy then
            row.enemy = enemy
            row.stats = opponentStats[enemy.guid or enemy.name]
            local level = enemy.level and ("Lv " .. tostring(enemy.level)) or "Lv ?"
            local className = enemy.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[enemy.class]) or enemy.class) or "Unknown"
            row.text:SetText(DP.Theme.ClassName(ShortName(enemy.name), enemy.class) .. "  |cffadb5c2" .. level .. " " .. className .. "|r")
        else
            row.enemy, row.stats = nil, nil
            row.text:SetText("|cffadb5c2Unknown opponent|r")
        end
        row:Show()
    end
    for index = count + 1, #(window.enemiesRows or {}) do window.enemiesRows[index]:Hide() end
    window.enemiesBody:SetHeight(math.max(40, count * 17))
    window.enemiesScroll.smoothTarget = 0
    window.enemiesScroll:SetVerticalScroll(0)
    if window.enemiesScroll.UpdateScrollHints then window.enemiesScroll:UpdateScrollHints() end
    W.RefreshDetailStar()
    window:Show(); W.SelectDetailTab(selectedTab)
end

local function ClassLabel(class)
    if not class then return "Unknown class" end
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

local function HistoryOutcomeLabel(record)
    local label = record and record.resultLabel or "WORLD PVP"
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

local function HistoryHeadcount(record)
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

function W.HistoryOpponentLine(record)
    local enemies = record and record.enemies or {}
    local enemy = enemies[1]
    if not enemy then return "Unknown opponent" end
    local level = enemy.level and ("Lv " .. tostring(enemy.level)) or "Lv ?"
    local first = DP.Theme.ClassName(ShortName(enemy.name), enemy.class) .. "  |cffadb5c2• " .. level .. " " .. ClassLabel(enemy.class) .. "|r"
    if #enemies > 1 then first = first .. string.format("  |cffadb5c2+%d more|r", #enemies - 1) end
    return first
end

function W.HistoryResultLine(record)
    local color = ResultColor(record and record.resultKey)
    local label = HistoryOutcomeLabel(record)
    return string.format("%s%s|r  •  %s  •  %d %s", color, label, HistoryHeadcount(record), record.enemyDeaths or 0,
        (record.enemyDeaths or 0) == 1 and "kill" or "kills")
end

function W.HistoryMeta(record)
    local loc = record.location or {}
    return {
        title = HistoryOutcomeLabel(record),
        subtitle = string.format("%s • %d %s • %s", HistoryHeadcount(record), record.enemyDeaths or 0,
            (record.enemyDeaths or 0) == 1 and "kill" or "kills", SurvivalText(record)),
        footer = string.format("%s%s", loc.zone or "Unknown", record.npcAssistance and " • NPC interference" or ""),
    }
end

function W.ShowHistoryTooltip(owner, record)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText((ResultColor(record.resultKey) .. HistoryOutcomeLabel(record) .. "|r"))
    GameTooltip:AddLine(string.format("%s • %d %s • %s", HistoryHeadcount(record), record.enemyDeaths or 0,
        (record.enemyDeaths or 0) == 1 and "kill" or "kills", SurvivalText(record)), 1, 1, 1)
    if record.location then GameTooltip:AddLine((record.location.zone or "Unknown") .. (record.location.subzone and record.location.subzone ~= "" and (" • " .. record.location.subzone) or ""), .7, .75, .82) end
    for index, enemy in ipairs(record.enemies or {}) do
        if index > 6 then break end
        local level = enemy.level and ("Lv " .. tostring(enemy.level)) or "Lv ?"
        local kind = enemy.died and GankKind(record, enemy)
        local suffix = kind == "lowbie" and "  |cffff8888LOWBIE GANK|r" or kind == "gank" and "  |cffffad66GANK|r" or ""
        GameTooltip:AddLine(DP.Theme.ClassName(ShortName(enemy.name), enemy.class) .. "  |cffadb5c2" .. level .. " " .. ClassLabel(enemy.class) .. "|r" .. suffix, 1, 1, 1, true)
    end
    if record.npcAssistance then GameTooltip:AddLine("NPC assistance/interference detected", 1, .68, .4, true) end
    GameTooltip:AddLine("Click for encounter details", .55, .6, .68, true)
    GameTooltip:Show()
end

return W
