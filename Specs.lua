local _, DP = ...
local S = {}
DP.Specs = S

local db
local SOURCE_PRIORITY = {combat = 1, shared = 2, inspect = 3}

-- Vanilla / Classic Era talent-tree order. Tree names from the client are still
-- captured, but these English names let classification remain stable if the API
-- changes its return layout.
local TREE_NAMES = {
    WARRIOR = {"Arms", "Fury", "Protection"},
    PALADIN = {"Holy", "Protection", "Retribution"},
    HUNTER = {"Beast Mastery", "Marksmanship", "Survival"},
    ROGUE = {"Assassination", "Combat", "Subtlety"},
    PRIEST = {"Discipline", "Holy", "Shadow"},
    SHAMAN = {"Elemental", "Enhancement", "Restoration"},
    MAGE = {"Arcane", "Fire", "Frost"},
    WARLOCK = {"Affliction", "Demonology", "Destruction"},
    DRUID = {"Balance", "Feral", "Restoration"},
}

local SIGNATURE_BY_ID = {
    -- Warrior
    [12294]="Mortal Strike", [21551]="Mortal Strike", [21552]="Mortal Strike", [21553]="Mortal Strike",
    [23881]="Bloodthirst", [23892]="Bloodthirst", [23893]="Bloodthirst", [23894]="Bloodthirst",
    [23922]="Shield Slam", [23923]="Shield Slam", [23924]="Shield Slam", [23925]="Shield Slam",
    [12292]="Sweeping Strikes", [12328]="Death Wish", [12323]="Piercing Howl", [12975]="Last Stand",
    -- Paladin
    [20473]="Holy Shock", [20929]="Holy Shock", [20930]="Holy Shock", [20066]="Repentance",
    [20925]="Holy Shield", [20927]="Holy Shield", [20928]="Holy Shield", [20216]="Divine Favor",
    -- Hunter
    [19574]="Bestial Wrath", [19577]="Intimidation", [19503]="Scatter Shot", [19386]="Wyvern Sting",
    [19506]="Trueshot Aura", [19263]="Deterrence", [19306]="Counterattack",
    -- Rogue
    [16511]="Hemorrhage", [17347]="Hemorrhage", [17348]="Hemorrhage", [14185]="Preparation",
    [14177]="Cold Blood", [13750]="Adrenaline Rush", [13877]="Blade Flurry", [14183]="Premeditation",
    -- Priest
    [15473]="Shadowform", [10060]="Power Infusion", [14751]="Inner Focus", [15286]="Vampiric Embrace",
    -- Shaman
    [16166]="Elemental Mastery", [17364]="Stormstrike", [16190]="Mana Tide Totem", [16188]="Nature's Swiftness",
    -- Mage
    [11426]="Ice Barrier", [13031]="Ice Barrier", [13032]="Ice Barrier", [13033]="Ice Barrier",
    [11958]="Cold Snap", [11113]="Blast Wave", [13018]="Blast Wave", [13019]="Blast Wave", [13020]="Blast Wave", [13021]="Blast Wave",
    [11129]="Combustion", [12042]="Arcane Power", [12043]="Presence of Mind",
    -- Warlock
    [19028]="Soul Link", [18708]="Fel Domination", [17962]="Conflagrate", [17877]="Shadowburn",
    [18265]="Siphon Life", [18223]="Curse of Exhaustion", [18288]="Amplify Curse",
    -- Druid
    [24858]="Moonkin Form", [16979]="Feral Charge", [17007]="Leader of the Pack", [18562]="Swiftmend", [17116]="Nature's Swiftness",
}

local SIGNATURE_CLASS_BY_NAME = {
    -- Warrior
    ["mortal strike"]="WARRIOR", ["bloodthirst"]="WARRIOR", ["shield slam"]="WARRIOR",
    ["sweeping strikes"]="WARRIOR", ["death wish"]="WARRIOR", ["piercing howl"]="WARRIOR", ["last stand"]="WARRIOR",
    -- Paladin
    ["holy shock"]="PALADIN", ["repentance"]="PALADIN", ["holy shield"]="PALADIN", ["divine favor"]="PALADIN", ["reckoning"]="PALADIN",
    -- Hunter
    ["bestial wrath"]="HUNTER", ["intimidation"]="HUNTER", ["scatter shot"]="HUNTER", ["wyvern sting"]="HUNTER",
    ["trueshot aura"]="HUNTER", ["deterrence"]="HUNTER", ["counterattack"]="HUNTER",
    -- Rogue
    ["hemorrhage"]="ROGUE", ["preparation"]="ROGUE", ["cold blood"]="ROGUE", ["adrenaline rush"]="ROGUE",
    ["blade flurry"]="ROGUE", ["premeditation"]="ROGUE",
    -- Priest
    ["shadowform"]="PRIEST", ["power infusion"]="PRIEST", ["inner focus"]="PRIEST", ["vampiric embrace"]="PRIEST", ["lightwell"]="PRIEST",
    -- Shaman
    ["elemental mastery"]="SHAMAN", ["stormstrike"]="SHAMAN", ["mana tide totem"]="SHAMAN", ["nature's swiftness"]="SHAMAN",
    -- Mage
    ["ice barrier"]="MAGE", ["cold snap"]="MAGE", ["blast wave"]="MAGE", ["combustion"]="MAGE",
    ["arcane power"]="MAGE", ["presence of mind"]="MAGE", ["pyroblast"]="MAGE",
    -- Warlock
    ["soul link"]="WARLOCK", ["fel domination"]="WARLOCK", ["conflagrate"]="WARLOCK", ["shadowburn"]="WARLOCK",
    ["siphon life"]="WARLOCK", ["curse of exhaustion"]="WARLOCK", ["amplify curse"]="WARLOCK",
    -- Druid
    ["moonkin form"]="DRUID", ["feral charge"]="DRUID", ["leader of the pack"]="DRUID", ["swiftmend"]="DRUID",
}

local function Lower(value)
    return type(value) == "string" and value:lower() or ""
end

local function SignatureName(spellID, spellName)
    return (spellID and SIGNATURE_BY_ID[tonumber(spellID)]) or spellName
end

local function SignatureClass(spellID, spellName)
    local name = SignatureName(spellID, spellName)
    return name and SIGNATURE_CLASS_BY_NAME[Lower(name)] or nil
end

local function UsageEvidence(session)
    local evidence, detectedClass = {}, nil
    local usage = session and session.usage and session.usage.opponent
    if type(usage) ~= "table" then return evidence, detectedClass end
    for _, entry in pairs(usage) do
        if type(entry) == "table" then
            local name = SignatureName(entry.spellID, entry.name)
            if type(name) == "string" and name ~= "" then
                evidence[Lower(name)] = true
                detectedClass = detectedClass or SignatureClass(entry.spellID, entry.name)
            end
        end
    end
    return evidence, detectedClass
end

local function QualifiedName(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return nil end
    local name, realm = UnitName(unit)
    if not name then return nil end
    if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() or "" end
    return realm ~= "" and (name .. "-" .. realm) or name
end

local function NameKey(name)
    if type(name) ~= "string" or name == "" then return nil end
    return name:lower()
end

local function TabInfo(index, inspect)
    if not GetTalentTabInfo then return nil, 0 end
    local ok, a, b, c, d, e = pcall(GetTalentTabInfo, index, inspect and true or false)
    if not ok then return nil, 0 end
    -- Era 1.15.8+: id, name, description, icon, pointsSpent, ...
    if type(b) == "string" then return b, tonumber(e) or 0 end
    -- Older Classic shape: name, icon, pointsSpent, background, ...
    if type(a) == "string" then return a, tonumber(c) or 0 end
    return nil, tonumber(e) or tonumber(c) or 0
end

local function NumTalents(index, inspect)
    if not GetNumTalents then return 0 end
    local ok, value = pcall(GetNumTalents, index, inspect and true or false)
    if not ok then ok, value = pcall(GetNumTalents, index) end
    return ok and (tonumber(value) or 0) or 0
end

local function TalentInfo(tab, index, inspect)
    if not GetTalentInfo then return nil end
    local ok, name, icon, tier, column, rank, maxRank = pcall(GetTalentInfo, tab, index, inspect and true or false)
    if not ok then return nil end
    return name, tonumber(rank) or 0, tonumber(maxRank) or 0, tonumber(tier), tonumber(column)
end

local function WeaponState(unit)
    if not unit or not GetInventoryItemLink then return false, false end
    local main = GetInventoryItemLink(unit, 16)
    local off = GetInventoryItemLink(unit, 17)
    local twoHanded = false
    if main and GetItemInfo then
        local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(main)
        twoHanded = equipLoc == "INVTYPE_2HWEAPON"
    end
    return twoHanded, off ~= nil
end

local function Snapshot(unit, inspect)
    if not unit or not UnitClass then return nil end
    local _, class = UnitClass(unit)
    if not class then return nil end
    local snapshot = {class = class, unit = unit, points = {}, treeNames = {}, talents = {}, talentsLower = {}}
    local numTabs = 0
    if GetNumTalentTabs then
        local ok, n = pcall(GetNumTalentTabs, inspect and true or false)
        if ok then numTabs = tonumber(n) or 0 end
    end
    if numTabs == 0 then numTabs = 3 end
    for tab = 1, numTabs do
        local name, points = TabInfo(tab, inspect)
        snapshot.treeNames[tab] = name or (TREE_NAMES[class] and TREE_NAMES[class][tab]) or tostring(tab)
        local rankSum = 0
        for index = 1, NumTalents(tab, inspect) do
            local talentName, rank, maxRank, tier, column = TalentInfo(tab, index, inspect)
            if talentName and rank and rank > 0 then
                rankSum = rankSum + rank
                snapshot.talents[talentName] = rank
                snapshot.talentsLower[Lower(talentName)] = {rank = rank, maxRank = maxRank, tab = tab, tier = tier, column = column}
            end
        end
        snapshot.points[tab] = (points and points > 0) and points or rankSum
    end
    snapshot.twoHanded, snapshot.hasOffhand = WeaponState(unit)
    snapshot.totalPoints = 0
    for _, points in ipairs(snapshot.points) do snapshot.totalPoints = snapshot.totalPoints + (tonumber(points) or 0) end
    return snapshot
end

local function Has(snapshot, name)
    if not snapshot or not snapshot.talentsLower then return false end
    local value = snapshot.talentsLower[Lower(name)]
    return value and (value.rank or 0) > 0 or false
end

local function Point(snapshot, index)
    return tonumber(snapshot and snapshot.points and snapshot.points[index]) or 0
end

local function Dominant(snapshot)
    if not snapshot then return nil end
    local bestIndex, best = nil, -1
    for index, points in ipairs(snapshot.points or {}) do
        points = tonumber(points) or 0
        if points > best then bestIndex, best = index, points end
    end
    if not bestIndex or best <= 0 then return nil end
    return (TREE_NAMES[snapshot.class] and TREE_NAMES[snapshot.class][bestIndex]) or snapshot.treeNames[bestIndex]
end

local function Near(value, target, tolerance)
    return math.abs((tonumber(value) or 0) - target) <= (tolerance or 1)
end

function S.Classify(snapshot)
    if not snapshot or not snapshot.class then return nil end
    local c = snapshot.class
    local p1, p2, p3 = Point(snapshot, 1), Point(snapshot, 2), Point(snapshot, 3)

    if c == "WARRIOR" then
        if Has(snapshot, "Mortal Strike") or p1 >= 31 then return "Arms" end
        if Has(snapshot, "Bloodthirst") or p2 >= 31 then
            -- 20/31/0 (and the nearby 18-20 Arms / 31+ Fury variants) is the
            -- classic 2H Fury PvP shell even if the player happens to have a
            -- shield/offhand equipped at the instant we inspect them.
            if (p1 >= 18 and p3 == 0) or snapshot.twoHanded then return "2H Fury" end
            return "Fury"
        end
        if Has(snapshot, "Shield Slam") or p3 >= 31 then return "Protection" end
    elseif c == "PALADIN" then
        if Has(snapshot, "Reckoning") and p2 >= 25 then return "Reckoning" end
        if Has(snapshot, "Repentance") or p3 >= 31 then return "Retribution" end
        if Has(snapshot, "Holy Shock") or p1 >= 31 then return "Holy" end
        if Has(snapshot, "Holy Shield") or p2 >= 31 then return "Protection" end
    elseif c == "HUNTER" then
        if Has(snapshot, "Bestial Wrath") or p1 >= 31 then return "Deep BM" end
        if Has(snapshot, "Lightning Reflexes") and Has(snapshot, "Scatter Shot") and p3 >= 25 then return "LR/Scatter" end
        if Has(snapshot, "Intimidation") and Has(snapshot, "Scatter Shot") then return "Intimidation/Scatter" end
        if Has(snapshot, "Wyvern Sting") or p3 >= 31 then return "Survival" end
        if Has(snapshot, "Scatter Shot") or p2 >= 21 then return p3 >= 15 and "MM/Survival" or "Marksmanship" end
    elseif c == "ROGUE" then
        if Has(snapshot, "Cold Blood") and Has(snapshot, "Hemorrhage") and Has(snapshot, "Preparation") then return "CB/Hemo" end
        if Has(snapshot, "Hemorrhage") and Has(snapshot, "Preparation") then return "Hemo/Prep" end
        if Has(snapshot, "Adrenaline Rush") or p2 >= 31 then return "Combat" end
        if Has(snapshot, "Premeditation") or p3 >= 31 then return "Subtlety" end
        if Has(snapshot, "Seal Fate") or p1 >= 30 then return "Seal Fate" end
        if Has(snapshot, "Cold Blood") then return "Cold Blood" end
    elseif c == "PRIEST" then
        if Has(snapshot, "Shadowform") or p3 >= 31 then return "Shadow" end
        if Has(snapshot, "Power Infusion") and Has(snapshot, "Searing Light") and p2 >= 15 then return "Smite/PI" end
        if Has(snapshot, "Power Infusion") or p1 >= 31 then return "PI Discipline" end
        if Has(snapshot, "Lightwell") or p2 >= 31 then return "Holy" end
    elseif c == "SHAMAN" then
        if Has(snapshot, "Nature's Swiftness") and p1 >= 25 then return "Elemental/NS" end
        if Has(snapshot, "Elemental Mastery") or p1 >= 31 then return "Elemental/EM" end
        if Has(snapshot, "Nature's Swiftness") and p2 >= 25 then return "Enh/NS" end
        if Has(snapshot, "Stormstrike") and p1 >= 15 then return "Elemental Devastation" end
        if Has(snapshot, "Stormstrike") or p2 >= 31 then return "Enhancement" end
        if Has(snapshot, "Mana Tide Totem") or p3 >= 31 then return "Restoration" end
    elseif c == "MAGE" then
        -- Elementalist commonly reaches Ice Barrier (e.g. 0/24/27), so test
        -- the Fire/Frost hybrid before treating Ice Barrier as Deep Frost.
        if p2 >= 20 and p3 >= 20 and Has(snapshot, "Blast Wave") then return "Elementalist" end
        if Has(snapshot, "Presence of Mind") and Has(snapshot, "Pyroblast") and p2 >= 15 then return "PoM Pyro" end
        if Has(snapshot, "Ice Barrier") or p3 >= 31 then return "Deep Frost" end
        if Has(snapshot, "Arcane Power") or p1 >= 31 then return "Arcane Power" end
        if Has(snapshot, "Combustion") or p2 >= 31 then return "Fire" end
    elseif c == "WARLOCK" then
        if Has(snapshot, "Soul Link") and Has(snapshot, "Nightfall") and p1 >= 15 then return "SL/Nightfall" end
        if Has(snapshot, "Soul Link") and Has(snapshot, "Shadowburn") then return "SL/Shadowburn" end
        if Has(snapshot, "Shadow Mastery") and Has(snapshot, "Ruin") then return "SM/Ruin" end
        if Has(snapshot, "Conflagrate") or p3 >= 31 then return "Conflagrate" end
        if Has(snapshot, "Soul Link") or p2 >= 31 then return "Soul Link" end
        if p1 >= 30 then return "Affliction" end
    elseif c == "DRUID" then
        if Has(snapshot, "Swiftmend") and Has(snapshot, "Feral Charge") then return "Swiftmend/FC" end
        if Has(snapshot, "Heart of the Wild") and Has(snapshot, "Nature's Swiftness") then return "HotW/NS" end
        if Has(snapshot, "Moonkin Form") or p1 >= 31 then return "Balance" end
        if Has(snapshot, "Leader of the Pack") or p2 >= 31 then return "Feral" end
        if Has(snapshot, "Swiftmend") or p3 >= 31 then return "Restoration" end
    end
    return Dominant(snapshot)
end

local function EvidenceHas(evidence, name)
    if not evidence then return false end
    return evidence[Lower(name)] and true or false
end

function S.InferCombat(class, evidence)
    if not class or not evidence then return nil, 0 end
    if class == "WARRIOR" then
        if EvidenceHas(evidence, "Mortal Strike") then return "Arms", .99 end
        if EvidenceHas(evidence, "Bloodthirst") then return "Fury", .99 end
        if EvidenceHas(evidence, "Death Wish") then return "Fury", .96 end
        if EvidenceHas(evidence, "Sweeping Strikes") then return "Arms", .95 end
        if EvidenceHas(evidence, "Shield Slam") then return "Protection", .99 end
    elseif class == "PALADIN" then
        if EvidenceHas(evidence, "Repentance") then return "Retribution", .99 end
        if EvidenceHas(evidence, "Holy Shock") then return "Holy", .99 end
        if EvidenceHas(evidence, "Holy Shield") then return "Protection", .98 end
        if EvidenceHas(evidence, "Reckoning") then return "Reckoning", .95 end
    elseif class == "HUNTER" then
        if EvidenceHas(evidence, "Bestial Wrath") then return "Deep BM", .99 end
        if EvidenceHas(evidence, "Wyvern Sting") then return "Survival", .99 end
        if EvidenceHas(evidence, "Intimidation") and EvidenceHas(evidence, "Scatter Shot") then return "Intimidation/Scatter", .98 end
        if EvidenceHas(evidence, "Scatter Shot") then return "Marksmanship", .92 end
    elseif class == "ROGUE" then
        if EvidenceHas(evidence, "Cold Blood") and EvidenceHas(evidence, "Hemorrhage") and EvidenceHas(evidence, "Preparation") then return "CB/Hemo", .99 end
        if EvidenceHas(evidence, "Hemorrhage") and EvidenceHas(evidence, "Preparation") then return "Hemo/Prep", .98 end
        if EvidenceHas(evidence, "Hemorrhage") then return "Hemo", .92 end
        if EvidenceHas(evidence, "Adrenaline Rush") then return "Combat", .99 end
        if EvidenceHas(evidence, "Premeditation") then return "Subtlety", .99 end
        if EvidenceHas(evidence, "Cold Blood") then return "Cold Blood", .92 end
    elseif class == "PRIEST" then
        if EvidenceHas(evidence, "Shadowform") then return "Shadow", .99 end
        if EvidenceHas(evidence, "Power Infusion") then return "PI Discipline", .99 end
        if EvidenceHas(evidence, "Lightwell") then return "Holy", .99 end
    elseif class == "SHAMAN" then
        if EvidenceHas(evidence, "Nature's Swiftness") and EvidenceHas(evidence, "Elemental Mastery") then return "Elemental", .98 end
        if EvidenceHas(evidence, "Elemental Mastery") then return "Elemental/EM", .99 end
        if EvidenceHas(evidence, "Stormstrike") then return "Enhancement", .99 end
        if EvidenceHas(evidence, "Mana Tide Totem") then return "Restoration", .99 end
        if EvidenceHas(evidence, "Nature's Swiftness") then return "NS Hybrid", .82 end
    elseif class == "MAGE" then
        if EvidenceHas(evidence, "Ice Barrier") then return "Deep Frost", .99 end
        if EvidenceHas(evidence, "Presence of Mind") and EvidenceHas(evidence, "Pyroblast") then return "PoM Pyro", .98 end
        if EvidenceHas(evidence, "Blast Wave") and EvidenceHas(evidence, "Cold Snap") then return "Elementalist", .98 end
        if EvidenceHas(evidence, "Arcane Power") then return "Arcane Power", .98 end
        if EvidenceHas(evidence, "Combustion") then return "Fire", .98 end
    elseif class == "WARLOCK" then
        if EvidenceHas(evidence, "Soul Link") and EvidenceHas(evidence, "Shadowburn") then return "SL/Shadowburn", .98 end
        if EvidenceHas(evidence, "Soul Link") and (EvidenceHas(evidence, "Siphon Life") or EvidenceHas(evidence, "Curse of Exhaustion")) then return "SL/Nightfall", .94 end
        if EvidenceHas(evidence, "Soul Link") then return "Soul Link", .99 end
        if EvidenceHas(evidence, "Conflagrate") then return "Conflagrate", .99 end
        if EvidenceHas(evidence, "Siphon Life") and EvidenceHas(evidence, "Shadowburn") then return "SM/Ruin", .86 end
    elseif class == "DRUID" then
        if EvidenceHas(evidence, "Moonkin Form") then return "Balance", .99 end
        if EvidenceHas(evidence, "Leader of the Pack") then return "Feral", .99 end
        if EvidenceHas(evidence, "Swiftmend") and EvidenceHas(evidence, "Feral Charge") then return "Swiftmend/FC", .98 end
        if EvidenceHas(evidence, "Swiftmend") then return "Restoration", .98 end
        if EvidenceHas(evidence, "Feral Charge") and EvidenceHas(evidence, "Nature's Swiftness") then return "Resto/Feral Hybrid", .90 end
    end
    return nil, 0
end

local function Save(profile)
    if not db or not profile or not profile.label then return profile end
    db.specProfiles = db.specProfiles or {}
    db.specProfilesByName = db.specProfilesByName or {}
    local current
    if profile.guid then current = db.specProfiles[profile.guid] end
    if not current and profile.name then current = db.specProfilesByName[NameKey(profile.name)] end
    local newPriority = SOURCE_PRIORITY[profile.source] or 0
    local oldPriority = current and (SOURCE_PRIORITY[current.source] or 0) or -1
    if current and oldPriority > newPriority then return current end
    if profile.guid then db.specProfiles[profile.guid] = profile end
    if profile.name then db.specProfilesByName[NameKey(profile.name)] = profile end
    return profile
end

local function Cached(guid, name)
    if not db then return nil end
    if guid and db.specProfiles and db.specProfiles[guid] then return db.specProfiles[guid] end
    if name and db.specProfilesByName then return db.specProfilesByName[NameKey(name)] end
    return nil
end

function S.Initialize(database)
    db = database
    if db then
        db.specProfiles = db.specProfiles or {}
        db.specProfilesByName = db.specProfilesByName or {}
        -- Older builds cached combat/inspect conclusions by player identity. That
        -- can incorrectly carry a spec across duels after a respec. Keep only the
        -- separately shared current-profile data; duel specs live on each record.
        for key, profile in pairs(db.specProfiles) do
            if not profile or profile.source ~= "shared" then db.specProfiles[key] = nil end
        end
        for key, profile in pairs(db.specProfilesByName) do
            if not profile or profile.source ~= "shared" then db.specProfilesByName[key] = nil end
        end
    end
end

function S.PointsString(snapshot)
    if not snapshot then return nil end
    return string.format("%d/%d/%d", Point(snapshot, 1), Point(snapshot, 2), Point(snapshot, 3))
end

function S.CurrentPlayerSpec()
    local snapshot = Snapshot("player", false)
    return S.Classify(snapshot), snapshot and S.PointsString(snapshot) or nil
end

function S.RememberShared(guid, name, class, label)
    if type(label) ~= "string" or label == "" then return nil end
    label = label:gsub("[|\r\n]", "")
    if #label > 32 then label = label:sub(1, 32) end
    if label == "" then return nil end
    return Save({guid = guid, name = name, class = class, label = label, source = "shared", updatedAt = time and time() or 0})
end

function S.CaptureInspect(guid, preferredUnit)
    if not guid then return nil end
    local unit = preferredUnit
    if not (unit and UnitGUID and UnitGUID(unit) == guid) then
        unit = nil
        local candidates = {"target", "mouseover"}
        if InspectFrame and InspectFrame.unit then table.insert(candidates, 1, InspectFrame.unit) end
        for _, candidate in ipairs(candidates) do
            if UnitGUID and UnitGUID(candidate) == guid then unit = candidate; break end
        end
    end
    if not unit then return nil end
    local snapshot = Snapshot(unit, true)
    if not snapshot or (snapshot.totalPoints or 0) <= 0 then return nil end
    local label = S.Classify(snapshot)
    if not label then return nil end
    local profile = {
        guid = guid, name = QualifiedName(unit), class = snapshot.class, label = label,
        build = S.PointsString(snapshot), source = "inspect", updatedAt = time and time() or 0,
    }
    return profile
end

function S.BindInspect(target, profile)
    if not target or not profile or not profile.label then return false end
    local session = target.session or target
    if type(session) ~= "table" then return false end
    local current = session.opponentSpec
    if current and (SOURCE_PRIORITY[current.source] or 0) > (SOURCE_PRIORITY[profile.source] or 0) then return false end
    session.identity = session.identity or {}
    if profile.class then session.identity.class = profile.class end
    if profile.guid and not session.identity.guid then session.identity.guid = profile.guid end
    if profile.name and not session.identity.name then session.identity.name = profile.name end
    session.opponentSpec = {
        label = profile.label, build = profile.build, class = profile.class,
        source = profile.source or "inspect", updatedAt = profile.updatedAt or (time and time() or 0),
        confidence = profile.confidence or 1,
    }
    return true
end

local function SameOpponent(session, sourceGUID, sourceName)
    local identity = session and session.identity
    if identity and identity.guid and sourceGUID then return identity.guid == sourceGUID end
    if type(sourceName) ~= "string" or not session or type(session.opponent) ~= "string" then return false end
    local a = sourceName:match("^([^-]+)") or sourceName
    local b = session.opponent:match("^([^-]+)") or session.opponent
    return a == b
end

function S.ObserveCombat(session, info)
    if not session or type(info) ~= "table" then return end
    local sourceGUID, sourceName = info[4], info[5]
    if not SameOpponent(session, sourceGUID, sourceName) then return end
    local class = session.identity and session.identity.class
    if not class and UnitGUID and UnitClass then
        for _, unit in ipairs({"target", "mouseover", "focus"}) do
            local exists = not UnitExists or UnitExists(unit)
            if exists and UnitGUID(unit) and sourceGUID and UnitGUID(unit) == sourceGUID then
                local _, detectedClass = UnitClass(unit)
                if detectedClass then
                    class = detectedClass
                    session.identity = session.identity or {}
                    session.identity.class = detectedClass
                    session.identity.guid = session.identity.guid or sourceGUID
                    if not session.identity.name and UnitName then
                        local unitName, realm = UnitName(unit)
                        if unitName then
                            if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() or "" end
                            session.identity.name = realm ~= "" and (unitName .. "-" .. realm) or unitName
                        end
                    end
                    break
                end
            end
        end
    end
    local spellID, spellName = tonumber(info[12]), info[13]
    local signature = spellID and SIGNATURE_BY_ID[spellID] or nil
    -- Talent-defining spells are themselves reliable class evidence. This matters
    -- when the duel handshake knew the opponent GUID but no target/mouseover class
    -- was available at the exact combat-log event.
    if not class then class = SignatureClass(spellID, spellName) end
    if not class then return end
    if session.identity and not session.identity.class then session.identity.class = class end
    session.specEvidence = session.specEvidence or {}
    local name = signature or spellName
    if type(name) ~= "string" or name == "" then return end
    session.specEvidence[Lower(name)] = true
    if spellName and spellName ~= name then session.specEvidence[Lower(spellName)] = true end
    local label, confidence = S.InferCombat(class, session.specEvidence)
    if not label then return end
    session.opponentSpec = {label = label, confidence = confidence, source = "combat", class = class,
        updatedAt = time and time() or 0, evidence = session.specEvidence}
    if DP.Usage and DP.Usage.RefreshSpecDisplays then DP.Usage.RefreshSpecDisplays() end
end

-- Open-world PvP can have several enemies at once. Keep spec evidence on
-- each enemy identity instead of the duel-scoped session.opponentSpec field.
function S.ObserveWorldCombat(session, info)
    if not session or not session.worldPvP or type(info) ~= "table" then return end
    local sourceGUID = info[4]
    local enemy = sourceGUID and session.enemies and session.enemies[sourceGUID]
    if not enemy then return end
    local spellID, spellName = tonumber(info[12]), info[13]
    local signature = spellID and SIGNATURE_BY_ID[spellID] or nil
    local class = enemy.class or SignatureClass(spellID, spellName)
    if not class then return end
    enemy.class = enemy.class or class
    local name = signature or spellName
    if type(name) ~= "string" or name == "" then return end
    enemy.specEvidence = enemy.specEvidence or {}
    enemy.specEvidence[Lower(name)] = true
    if spellName and spellName ~= name then enemy.specEvidence[Lower(spellName)] = true end
    local label, confidence = S.InferCombat(class, enemy.specEvidence)
    if label then
        enemy.spec = {label = label, confidence = confidence, source = "combat", class = class,
            updatedAt = time and time() or 0, evidence = enemy.specEvidence}
    end
end

function S.ResolveWorld(identity)
    if not identity then return nil end
    if identity.spec and identity.spec.label then return identity.spec.label, identity.spec end
    return nil
end

function S.Resolve(record)
    if not record then return nil end
    local session = record.session or record
    local identity = session and session.identity or nil

    -- Spec is duel-scoped. Never inherit a cached profile from another duel with
    -- the same opponent: players can respec between matches.
    if session and session.opponentSpec and session.opponentSpec.label then
        return session.opponentSpec.label, session.opponentSpec
    end

    -- Older/current records may already contain a signature cooldown in their
    -- usage dataframe even when the live event missed inference. Derive and store
    -- that result on this duel only.
    local evidence, evidenceClass = UsageEvidence(session)
    local class = (identity and identity.class) or evidenceClass
    if class then
        local label, confidence = S.InferCombat(class, evidence)
        if label then
            if identity and not identity.class then identity.class = class end
            session.specEvidence = session.specEvidence or {}
            for key, value in pairs(evidence) do if value then session.specEvidence[key] = true end end
            session.opponentSpec = {label = label, confidence = confidence, source = "combat", class = class,
                updatedAt = time and time() or 0, evidence = session.specEvidence}
            return label, session.opponentSpec
        end
    end
    return nil
end

function S.ResolveIdentity(guid, name)
    local profile = Cached(guid, name)
    return profile and profile.label or nil, profile
end

function S.Profile(guid, name)
    return Cached(guid, name)
end

S.Snapshot = Snapshot
