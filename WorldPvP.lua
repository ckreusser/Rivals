local _, DP = ...

local W = {}
DP.WorldPvP = W

local INACTIVITY_TIMEOUT = 60
local ALL_ENEMIES_DEAD_GRACE = 6
local ENEMY_PRESSURE_WINDOW = 12
local MAX_ENCOUNTERS = 250
local MAX_WORLD_LOG = 160
local BAND = bit and bit.band or bit32 and bit32.band

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
        zone = (info and info.name) or (GetZoneText and GetZoneText()) or "Unknown",
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
        session.worldCombatLog[#session.worldCombatLog + 1] = {t = math.max(0, GetTime() - session.startedElapsed), text = text,
            sourceGUID = info[4], destGUID = info[8], event = event}
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
    if (record.enemyDeaths or 0) > 0 then return "no death" end
    return "disengaged"
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
            local quiet = GetTime() - (active.lastActivity or GetTime())
            local allEnemiesDead, enemyCount = true, 0
            for _, enemy in pairs(active.enemies or {}) do
                enemyCount = enemyCount + 1
                if not enemy.died then allEnemiesDead = false end
            end
            if enemyCount > 0 and (active.playerDied or allEnemiesDead) and quiet >= ALL_ENEMIES_DEAD_GRACE then
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

    -- Once an enemy is part of the encounter, any grouped/friendly player who
    -- materially interacts with them (or heals/buffs the player) counts as help.
    if sourcePlayer and sourceGUID ~= playerGUID and (group[sourceGUID] or sourceFriendly) then
        if session.enemies[destGUID] or ((supportEvent or appliedToOther) and (destGUID == playerGUID or session.friendlies[destGUID])) then
            local friendly = AddParticipant(session, "friendlies", sourceGUID, sourceName, sourceFlags)
            session.participants[sourceGUID] = friendly
        end
    end
    if destPlayer and destGUID ~= playerGUID and (group[destGUID] or destFriendly) and session.enemies[sourceGUID] then
        local friendly = AddParticipant(session, "friendlies", destGUID, destName, destFlags)
        session.participants[destGUID] = friendly
    end

    -- NPC participation is deliberately only a disclosure flag; it never
    -- changes the player-vs-player headcount used for outnumbered recognition.
    if not sourcePlayer and sourceGUID and (destGUID == playerGUID or session.enemies[destGUID]) then session.npcAssistance = true end
    if not destPlayer and destGUID and (sourceGUID == playerGUID or session.enemies[sourceGUID]) then session.npcAssistance = true end
    UpdatePeaks(session)
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
    if not session then
        if not PvPInteraction(info, playerGUID) then return end
        session = W.Start(playerGUID, info)
        if not session then return end
    end

    MarkInteraction(session, info)
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

local function EnsureResultToast()
    if W.resultToast then return W.resultToast end
    local toast = CreateFrame("Frame", "RivalsWorldPvPResultToast", UIParent)
    toast:SetSize(360, 82); toast:SetPoint("TOP", UIParent, "TOP", 0, -155); toast:SetFrameStrata("DIALOG")
    toast.bg = toast:CreateTexture(nil, "BACKGROUND"); toast.bg:SetAllPoints(); toast.bg:SetColorTexture(.025, .032, .045, .96)
    DP.Theme.Border(toast, 0, 0, 360, 82)
    toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    toast.title:SetPoint("TOP", 0, -12); toast.title:SetWidth(338); toast.title:SetJustifyH("CENTER")
    toast.summary = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toast.summary:SetPoint("TOP", 0, -37); toast.summary:SetWidth(338); toast.summary:SetJustifyH("CENTER")
    toast.names = toast:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    toast.names:SetPoint("TOP", 0, -58); toast.names:SetWidth(338); toast.names:SetJustifyH("CENTER"); toast.names:SetWordWrap(false)
    toast:Hide(); W.resultToast = toast; return toast
end

function W.ShouldShowResultToast(record)
    if not record then return false end
    -- Routine World PvP already lands in History and receives the compact chat
    -- confirmation. Reserve the center-screen plaque for the thing Rivals is
    -- meant to celebrate: solo success while outnumbered. Full 1v2+ clears and
    -- kill-and-escape results qualify; ordinary 1v1 wins, deaths, trades, group
    -- fights, partial deaths and disengages stay out of the player's way.
    if (record.friendlyCount or 1) ~= 1 or (record.enemyCount or 0) < 2 then return false end
    if record.resultKey == "outnumbered_victory" then return true end
    if record.resultKey == "outnumbered_escape" and not record.playerDied and (record.enemyDeaths or 0) > 0 then return true end
    return false
end

function W.ShowResultToast(record)
    if not W.ShouldShowResultToast(record) or not UIParent then return end
    local toast = EnsureResultToast()
    W.toastGeneration = (W.toastGeneration or 0) + 1
    local generation = W.toastGeneration
    toast.title:SetText(ResultColor(record.resultKey) .. (record.resultLabel or "WORLD PVP") .. "|r")
    toast.summary:SetText(string.format("%dv%d  •  %d %s  •  %s", record.friendlyCount or 1, record.enemyCount or 0,
        record.enemyDeaths or 0, (record.enemyDeaths or 0) == 1 and "kill" or "kills", record.playerDied and "death" or "survived"))
    toast.names:SetText(table.concat(EnemyNames(record, 4), "  •  "))
    toast:Show()
    if C_Timer and C_Timer.After then
        C_Timer.After(record.resultKey == "outnumbered_victory" and 5.5 or 4.0, function()
            if W.toastGeneration == generation and toast then toast:Hide() end
        end)
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
    if W.active and UnitGUID and (event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or event == "NAME_PLATE_UNIT_ADDED") then
        local unit = event == "NAME_PLATE_UNIT_ADDED" and (...) or event == "UPDATE_MOUSEOVER_UNIT" and "mouseover" or "target"
        local guid = unit and UnitGUID(unit)
        local enemy = guid and W.active.enemies and W.active.enemies[guid]
        if enemy then enemy.level = enemy.level or ResolvePlayerLevel(guid) end
    end
    if event == "CHAT_MSG_COMBAT_HONOR_GAIN" then W.Honor((...)); return end
    if event == "PLAYER_ENTERING_WORLD" then if W.active then W.Finish("world-change") end; return end
    if event == "PLAYER_LOGOUT" then if W.active then W.Finish("logout") end; return end
    if event == "PLAYER_DEAD" and W.active then W.active.playerDied = true; W.active.lastActivity = GetTime(); return end
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
        local zone = record.location and record.location.zone
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
        if not record.playerDied and (record.enemyDeaths or 0) > 0 then streak = streak + 1 else streak = 0 end
        summary.longestStreak = math.max(summary.longestStreak, streak)
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
    local function SetCross(texture)
        -- Set the sheet explicitly before calling Blizzard's helper. Some Classic
        -- clients only apply texcoords in the helper, which left our prior marker
        -- with no visible texture even though its geometry was correct.
        texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        if SetRaidTargetIconTexture then SetRaidTargetIconTexture(texture, 7)
        else texture:SetTexCoord(.5, .75, .5, 1) end
        texture:SetAlpha(1)
        texture:SetBlendMode("BLEND")
    end
    SetCross(map.markerShadow); map.markerShadow:SetVertexColor(0, 0, 0, .95)
    SetCross(map.marker); map.marker:SetVertexColor(1, 1, 1, 1)
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
        GameTooltip:AddLine(string.format("%s • %d kills • %d deaths", summary.mostKilledName,
            summary.mostKilledKills or 0, summary.mostKilledDeaths or 0), 1, 1, 1)
    end)
    StatTooltip(nemesisBox, "Nemesis", function(summary)
        if not summary.nemesisName then
            GameTooltip:AddLine("No World PvP deaths recorded yet.", .72, .76, .82)
            return
        end
        GameTooltip:AddLine(string.format("%s • %d deaths • %d kills", summary.nemesisName,
            summary.nemesisDeaths or 0, summary.nemesisKills or 0), 1, 1, 1)
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
        local value = s.mostKilledName and string.format("%s |cffadb5c2• %d|r", DP.Theme.ClassName(s.mostKilledName, s.mostKilledClass), s.mostKilledKills or 0) or "—"
        L.mostV:SetText(value)
    end
    if L.nemesisL then L.nemesisL:SetText("NEMESIS") end
    if L.nemesisV then
        local value = s.nemesisName and string.format("%s |cffadb5c2• %d|r", DP.Theme.ClassName(s.nemesisName, s.nemesisClass), s.nemesisDeaths or 0) or "—"
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

    window.map = W.CreateMapThumbnail(window, 230, 142); window.map:SetPoint("TOPLEFT", 20, -42)
    window.starButton:ClearAllPoints(); window.starButton:SetPoint("TOPLEFT", window.map, "TOPLEFT", 8, -8)
    DP.Theme.Border(window.map, 0, 0, 230, 142)
    window.outcome = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); window.outcome:SetPoint("TOPLEFT", 270, -48); window.outcome:SetWidth(350); window.outcome:SetJustifyH("LEFT")
    window.headcount = window:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); window.headcount:SetPoint("TOPLEFT", 270, -74); window.headcount:SetWidth(350); window.headcount:SetJustifyH("LEFT")
    window.result = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); window.result:SetPoint("TOPLEFT", 270, -111); window.result:SetWidth(350); window.result:SetJustifyH("LEFT")
    window.location = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); window.location:SetPoint("TOPLEFT", 270, -139); window.location:SetWidth(350); window.location:SetJustifyH("LEFT")
    window.enemies = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); window.enemies:SetPoint("TOPLEFT", 270, -158); window.enemies:SetWidth(350); window.enemies:SetJustifyH("LEFT")

    window.summaryTab = DP.Theme.DataTab(window, "Summary", 20, -203, 110, function() W.SelectDetailTab("summary") end)
    window.usageTab = DP.Theme.DataTab(window, "Items & Abilities", 131, -203, 150, function() W.SelectDetailTab("usage") end)
    window.logTab = DP.Theme.DataTab(window, "Combat Log", 282, -203, 120, function() W.SelectDetailTab("log") end)

    window.content = CreateFrame("Frame", nil, window); window.content:SetPoint("TOPLEFT", 20, -233); window.content:SetPoint("BOTTOMRIGHT", -20, 20)
    if window.content.SetClipsChildren then window.content:SetClipsChildren(true) end

    -- Summary uses the fixed Details footprint instead of leaving a small text
    -- block stranded in the upper-left. A metric strip gives the encounter's
    -- shape at a glance; the rivalry section below adds persistent context for
    -- every enemy in the fight.
    window.summaryMetrics = CreateFrame("Frame", nil, window.content)
    window.summaryMetrics:SetPoint("TOPLEFT", 0, -4); window.summaryMetrics:SetSize(610, 62)
    window.summaryMetricTiles = {}
    local metricNames = {"Enemy players", "Kills", "Killing blows", "Honorable kills"}
    for i, name in ipairs(metricNames) do
        local tile = CreateFrame("Frame", nil, window.summaryMetrics)
        tile:SetSize(142, 56); tile:SetPoint("TOPLEFT", (i - 1) * 152, 0)
        tile.bg = tile:CreateTexture(nil, "BACKGROUND"); tile.bg:SetAllPoints(); tile.bg:SetColorTexture(.045, .055, .07, .86)
        DP.Theme.Border(tile, 0, 0, 142, 56)
        tile.value = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); tile.value:SetPoint("TOPLEFT", 6, -9); tile.value:SetWidth(130); tile.value:SetJustifyH("CENTER")
        tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); tile.label:SetPoint("TOPLEFT", 6, -34); tile.label:SetWidth(130); tile.label:SetJustifyH("CENTER"); tile.label:SetText(name)
        window.summaryMetricTiles[i] = tile
    end
    window.summaryRivalsTitle = window.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.summaryRivalsTitle:SetPoint("TOPLEFT", 4, -78); window.summaryRivalsTitle:SetWidth(600); window.summaryRivalsTitle:SetJustifyH("LEFT"); window.summaryRivalsTitle:SetText("ENEMY RIVALRIES")
    window.summaryRivalsBox = CreateFrame("Frame", nil, window.content)
    window.summaryRivalsBox:SetPoint("TOPLEFT", 0, -98); window.summaryRivalsBox:SetSize(598, 166)
    window.summaryRivalsBox.bg = window.summaryRivalsBox:CreateTexture(nil, "BACKGROUND"); window.summaryRivalsBox.bg:SetAllPoints(); window.summaryRivalsBox.bg:SetColorTexture(.035, .045, .06, .70)
    DP.Theme.Border(window.summaryRivalsBox, 0, 0, 598, 166)
    window.summaryRivals = window.summaryRivalsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.summaryRivals:SetPoint("TOPLEFT", 10, -10); window.summaryRivals:SetWidth(578); window.summaryRivals:SetJustifyH("LEFT"); window.summaryRivals:SetJustifyV("TOP")
    window.summaryContextBox = CreateFrame("Frame", nil, window.content)
    window.summaryContextBox:SetPoint("TOPLEFT", 0, -276); window.summaryContextBox:SetSize(598, 54)
    window.summaryContextBox.bg = window.summaryContextBox:CreateTexture(nil, "BACKGROUND"); window.summaryContextBox.bg:SetAllPoints(); window.summaryContextBox.bg:SetColorTexture(.035, .045, .06, .58)
    DP.Theme.Border(window.summaryContextBox, 0, 0, 598, 54)
    window.summaryNotes = window.summaryContextBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.summaryNotes:SetPoint("TOPLEFT", 10, -10); window.summaryNotes:SetWidth(578); window.summaryNotes:SetJustifyH("LEFT"); window.summaryNotes:SetJustifyV("TOP")

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

    window.usageHeader = CreateFrame("Frame", nil, window.content); window.usageHeader:SetPoint("TOPLEFT", 0, -38); window.usageHeader:SetSize(578, 24)
    window.usageHeader.bg = window.usageHeader:CreateTexture(nil, "BACKGROUND"); window.usageHeader.bg:SetAllPoints(); window.usageHeader.bg:SetColorTexture(.08, .09, .11, .95)
    local headers = {{"Time", 0, 54}, {"Player", 54, 118}, {"Used", 172, 274}, {"Target", 446, 126}}
    for _, h in ipairs(headers) do
        local text = window.usageHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); text:SetPoint("TOPLEFT", h[2] + 6, -6); text:SetWidth(h[3] - 10); text:SetJustifyH("LEFT"); text:SetText(h[1])
    end
    -- Blizzard's UIPanelScrollFrameTemplate places its scrollbar just outside
    -- the scrollframe's nominal right edge. Inset the frame enough that the
    -- arrows/thumb remain inside our fixed Encounter Details border.
    window.usageScroll = CreateFrame("ScrollFrame", nil, window.content, "UIPanelScrollFrameTemplate"); window.usageScroll:SetPoint("TOPLEFT", 0, -62); window.usageScroll:SetSize(578, 260)
    window.usageBody = CreateFrame("Frame", nil, window.usageScroll); window.usageBody:SetSize(552, 1); window.usageScroll:SetScrollChild(window.usageBody)
    window.usageRows = {}

    window.logBox = CreateFrame("Frame", nil, window.content)
    window.logBox:SetPoint("TOPLEFT", 0, -8); window.logBox:SetPoint("BOTTOMRIGHT", -12, 8)
    window.logBox.bg = window.logBox:CreateTexture(nil, "BACKGROUND"); window.logBox.bg:SetAllPoints(); window.logBox.bg:SetColorTexture(.025, .032, .043, .78)
    local logBorder = DP.Theme.Border(window.logBox, 0, 0, 598, 322)
    logBorder:ClearAllPoints(); logBorder:SetAllPoints(window.logBox); logBorder:EnableMouse(false)
    window.logScroll = CreateFrame("ScrollFrame", nil, window.logBox, "UIPanelScrollFrameTemplate")
    window.logScroll:SetPoint("TOPLEFT", 10, -10); window.logScroll:SetPoint("BOTTOMRIGHT", -32, 10)
    window.logBody = CreateFrame("Frame", nil, window.logScroll); window.logBody:SetSize(548, 1); window.logScroll:SetScrollChild(window.logBody)
    window.logText = window.logBody:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); window.logText:SetPoint("TOPLEFT", 4, -4); window.logText:SetWidth(536); window.logText:SetJustifyH("LEFT"); window.logText:SetJustifyV("TOP"); window.logText:SetWordWrap(true)

    UISpecialFrames[#UISpecialFrames + 1] = "RivalsWorldPvPDetails"
    W.details = window
    return window
end

local function UsageEvents(record, filter)
    local events = record.session and record.session.worldUsage and record.session.worldUsage.events or {}
    local result = {}
    for _, entry in ipairs(events) do if filter == "all" or entry.guid == filter then result[#result + 1] = entry end end
    table.sort(result, function(a, b) if a.category ~= b.category then return a.category < b.category end return (a.t or 0) < (b.t or 0) end)
    return result
end

local CATEGORY_ORDER = {potions = 1, engineering = 2, equipment = 3, cooldowns = 4, racials = 5}
local CATEGORY_LABEL = {potions = "Potions/Consumables", engineering = "Engineering Gadgets", equipment = "Equipment", cooldowns = "Cooldowns (≥3 min)", racials = "Racials"}

local function DescribeWorldUsage(entry, record)
    if DP.Usage and DP.Usage.Describe then
        local display = DP.Usage.Describe(entry, record)
        return display.text, display.category
    end
    return entry.name or ("Spell " .. tostring(entry.spellID)), entry.category or "cooldowns"
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
        row:SetScript("OnClick", function(self) InsertLink(self.entry) end)
    end
    window.usageRows[index] = row
    return row
end

function W.RefreshDetailContent()
    local window = W.details
    local record = window and window.record
    if not window or not record then return end
    local tab = window.activeTab or "summary"
    window.summaryMetrics:SetShown(tab == "summary")
    window.summaryRivalsTitle:SetShown(tab == "summary")
    window.summaryRivalsBox:SetShown(tab == "summary")
    window.summaryContextBox:SetShown(tab == "summary")
    window.summaryNotes:SetShown(tab == "summary")
    window.filter:SetShown(tab == "usage")
    window.usageHeader:SetShown(tab == "usage")
    window.usageScroll:SetShown(tab == "usage")
    window.logBox:SetShown(tab == "log")
    window.logScroll:SetShown(tab == "log")

    if tab == "summary" then
        window:SetHeight(600)
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
        local enemyLines = {}
        local enemies = record.enemies or {}
        for index, enemy in ipairs(enemies) do
            if index > 4 then break end
            local key = enemy.guid or enemy.name
            local stats = opponentStats[key] or {}
            local spec = enemy.spec and enemy.spec.label
            local className = enemy.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[enemy.class]) or enemy.class) or "Unknown class"
            local levelText = enemy.level and ("Lv " .. tostring(enemy.level)) or "Lv ?"
            local identity = DP.Theme.ClassName(ShortName(enemy.name), enemy.class) .. "  |cffadb5c2" .. levelText .. " " .. className .. "|r" .. (spec and (" |cffadb5c2(" .. spec .. ")|r") or "")
            local gank = enemy.died and GankKind(record, enemy)
            local state = gank == "lowbie" and "|cffff8888Lowbie gank|r" or gank == "gank" and "|cffffad66Gank|r" or enemy.died and "|cffff8888Dead|r" or "|cff65e6adSurvived|r"
            local blow = enemy.killingBlow and "  |cffffce70• Killing blow|r" or ""
            local world = string.format("World  |cff65e6ad%d K|r-|cffff8888%d D|r", stats.kills or 0, stats.deaths or 0)
            local solo = string.format("Solo  |cff65e6ad%d|r-|cffff8888%d|r", stats.soloKills or 0, stats.soloDeaths or 0)
            local encounters = string.format("%d %s", stats.encounters or 0, (stats.encounters or 0) == 1 and "encounter" or "encounters")
            enemyLines[#enemyLines + 1] = string.format("%s  %s%s\n  %s   •   %s   •   %s", identity, state, blow, world, solo, encounters)
        end
        if #enemies > 4 then enemyLines[#enemyLines + 1] = string.format("|cffadb5c2+%d additional enemies in this encounter|r", #enemies - 4) end
        if #enemyLines == 0 then enemyLines[1] = "|cffadb5c2No enemy player identity was retained for this encounter.|r" end
        window.summaryRivals:SetText(table.concat(enemyLines, "\n\n"))
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
            local ao, bo = CATEGORY_ORDER[a.category] or 99, CATEGORY_ORDER[b.category] or 99
            if ao ~= bo then return ao < bo end
            return (a.t or 0) < (b.t or 0)
        end)
        local y, rowIndex, lastCategory = 0, 0
        for _, entry in ipairs(events) do
            local text, category = DescribeWorldUsage(entry, record)
            category = category or entry.category or "cooldowns"
            if category ~= lastCategory then
                rowIndex = rowIndex + 1
                local header = EnsureUsageRow(window, rowIndex, "category")
                header:ClearAllPoints(); header:SetPoint("TOPLEFT", 0, -y); header.bg:SetColorTexture(.09, .07, .035, .92)
                header.label:SetText("|cffffce70" .. (CATEGORY_LABEL[category] or category) .. "|r"); header:Show(); y = y + 24
                lastCategory = category
            end
            rowIndex = rowIndex + 1
            local row = EnsureUsageRow(window, rowIndex, "entry")
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row.bg:SetColorTexture(.045, .055, .07, rowIndex % 2 == 0 and .72 or .5)
            row.time:SetText(string.format("%05.1f", entry.t or 0))
            local identity = record.session and record.session.participants and record.session.participants[entry.guid]
            row.player:SetText(DP.Theme.ClassName(entry.guid == record.playerGUID and "You" or ShortName(entry.name), identity and identity.class))
            row.used:SetText(text or entry.name or "Unknown")
            row.target:SetText(entry.targetName and ShortName(entry.targetName) or "—")
            row.entry = entry; row:Show(); y = y + 22
        end
        if #events == 0 then
            rowIndex = 1
            local row = EnsureUsageRow(window, rowIndex, "category"); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, 0); row.bg:SetColorTexture(.045, .055, .07, .6)
            row.label:SetText("|cffadb5c2No tracked item, engineering, racial, or ≥3 minute cooldown use for this filter.|r"); row:Show(); y = 42
        end
        for index = rowIndex + 1, #window.usageRows do window.usageRows[index]:Hide() end
        local displayHeight = math.min(300, math.max(66, y))
        window.usageScroll:SetHeight(displayHeight); window.usageBody:SetHeight(math.max(1, y))
        -- The dataframe can size itself to the encounter, but the surrounding
        -- Encounter Details window must never jump when switching tabs.
        window:SetHeight(600)
    elseif tab == "log" then
        local lines = {}
        for _, entry in ipairs(record.session and record.session.worldCombatLog or {}) do
            lines[#lines + 1] = string.format("|cff8f98a6+%05.1fs|r  %s", entry.t or 0, entry.text or "")
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

function W.OpenDetails(record)
    local window = EnsureDetails(); window.record = record; window.participantFilter = "all"
    W.SetMapRecord(window.map, record)
    local color = ResultColor(record.resultKey)
    window.outcome:SetText(color .. (record.resultLabel or "WORLD PVP") .. "|r")
    window.headcount:SetText(EncounterHeadcount(record))
    window.result:SetText(string.format("%d %s • %s • %.0fs", record.enemyDeaths or 0, (record.enemyDeaths or 0) == 1 and "kill" or "kills",
        SurvivalText(record), record.duration or 0))
    local loc = record.location or {}
    window.location:SetText(string.format("%s%s", loc.zone or "Unknown location", loc.subzone and loc.subzone ~= "" and (" • " .. loc.subzone) or ""))
    window.enemies:SetText(W.HistoryOpponentLine and W.HistoryOpponentLine(record) or table.concat(EnemyNames(record, 5), " • "))
    W.RefreshDetailStar()
    window:Show(); W.SelectDetailTab("summary")
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
