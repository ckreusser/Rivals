local _, DP = ...
local I = {prefix = "RivalsInspect1", sequence = 0}
DP.Inspect = I

local function Qualified(name)
    if type(name) ~= "string" or name == "" or name:find("[%s|]") then return nil end
    if not name:find("-", 1, true) then name = name .. "-" .. GetNormalizedRealmName() end
    return name
end

function I.Decode(message)
    if type(message) ~= "string" or #message > 240 then return nil end
    local parts = {}
    for field in (message .. "|"):gmatch("(.-)|") do parts[#parts + 1] = field end
    if parts[1] ~= "1" or not parts[3] or not parts[3]:match("^%d+%.?%d*%-%d+$") then return nil end
    if #parts[3] > 40 then return nil end
    if parts[2] == "Q" and #parts == 3 then return {kind = "Q", token = parts[3]} end
    if parts[2] == "A" and #parts == 4 and parts[4]:match("^Player%-%x+%-%x+$") then
        return {kind = "A", token = parts[3], guid = parts[4]}
    end
    if parts[2] ~= "S" or (#parts ~= 12 and #parts ~= 14) or not parts[4]:match("^Player%-%x+%-%x+$") then return nil end
    local result = {kind = "S", token = parts[3], guid = parts[4]}
    for index, key in ipairs({"rating", "peak", "wins", "losses", "streak", "longest", "effective", "distinct"}) do
        local value = tonumber(parts[index + 4])
        if not value or value ~= value or math.abs(value) > 10000000 then return nil end
        if key ~= "rating" and key ~= "peak" and key ~= "streak" and value < 0 then return nil end
        if key ~= "rating" and key ~= "peak" and key ~= "effective" and value % 1 ~= 0 then return nil end
        result[key] = value
    end
    if #parts >= 13 and parts[13] ~= "" then result.class = parts[13] end
    if #parts >= 14 and parts[14] ~= "" then result.spec = parts[14] end
    return result
end

local function Send(message, target)
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return false end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, I.prefix, message, "WHISPER", target)
    if not ok or result == false then return false end
    if Enum and Enum.SendAddonMessageResult and type(result) == "number" then
        return result == Enum.SendAddonMessageResult.Success
    end
    return true
end


local function CurrentSpecName()
    if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
    local bestName, bestPoints = nil, -1
    local count = GetNumTalentTabs(false, false) or 0
    for i = 1, count do
        local name, _, points = GetTalentTabInfo(i)
        points = tonumber(points) or 0
        if name and points > bestPoints then
            bestName, bestPoints = name, points
        end
    end
    if bestName and bestPoints > 0 then return bestName end
    return nil
end

function I.Initialize(getRating, settings)
    I.getRating, I.settings = getRating, settings
    settings.sharedProfiles = settings.sharedProfiles or {}
    if settings.shareProfile == nil then settings.shareProfile = true end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, I.prefix)
        I.available = ok and result ~= false
        if ok and type(result) == "number" and Enum and Enum.RegisterAddonMessagePrefixResult then
            I.available = result == Enum.RegisterAddonMessagePrefixResult.Success
        end
    end
end

-- A local list of explicitly requested summaries, never forwarded or broadcast automatically.
function I.ClearLeaderboard()
    if I.settings then I.settings.sharedProfiles = {} end
end

function I.Leaderboard(establishedOnly, sortBy)
    local items = {}
    if not I.settings then return items end
    local now = time()
    for guid, profile in pairs(I.settings.sharedProfiles) do
        if now - profile.receivedAt > 7 * 86400 or profile.receivedAt > now then
            I.settings.sharedProfiles[guid] = nil
        elseif guid ~= UnitGUID("player") then items[#items + 1] = profile end
    end
    if I.settings.shareProfile then
        local r = I.getRating()
        local _, class = UnitClass("player")
        items[#items + 1] = {name = Qualified(UnitName("player")), guid = UnitGUID("player"), rating = r.rating,
            effective = DP.Rating.PlacementCount(r), distinct = r.distinct, wins = r.wins, losses = r.losses,
            duels = (r.wins or 0) + (r.losses or 0), class = class, spec = CurrentSpecName(), receivedAt = now}
    end
    if establishedOnly then
        local filtered = {}
        for _, item in ipairs(items) do
            if not DP.Rating.Provisional(item) then filtered[#filtered + 1] = item end
        end
        items = filtered
    end
    for _, item in ipairs(items) do
        if item.duels == nil then item.duels = (item.wins or 0) + (item.losses or 0) end
    end
    sortBy = sortBy or "rating"
    table.sort(items, function(a, b)
        local aDuels, bDuels = a.duels or ((a.wins or 0) + (a.losses or 0)), b.duels or ((b.wins or 0) + (b.losses or 0))
        local aClass = a.spec or (a.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[a.class]) or a.class)) or "Unknown"
        local bClass = b.spec or (b.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[b.class]) or b.class)) or "Unknown"
        if sortBy == "name" then
            if a.name ~= b.name then return a.name < b.name end
            return a.rating > b.rating
        elseif sortBy == "recent" then
            if a.receivedAt ~= b.receivedAt then return a.receivedAt > b.receivedAt end
            return a.name < b.name
        elseif sortBy == "class" then
            if aClass ~= bClass then return aClass < bClass end
            if a.rating ~= b.rating then return a.rating > b.rating end
            return a.name < b.name
        elseif sortBy == "duels" then
            if aDuels ~= bDuels then return aDuels > bDuels end
            if a.rating ~= b.rating then return a.rating > b.rating end
            return a.name < b.name
        else
            if a.rating ~= b.rating then return a.rating > b.rating end
            if a.receivedAt ~= b.receivedAt then return a.receivedAt > b.receivedAt end
            return a.name < b.name
        end
    end)
    return items
end

function I.Receive(prefix, message, channel, sender)
    if prefix ~= I.prefix or channel ~= "WHISPER" or not I.getRating then return end
    local parsed, name = I.Decode(message), Qualified(sender)
    if not parsed or not name then return end
    if parsed.kind == "Q" then
        if I.lastReply and GetTime() - I.lastReply < 2 then return end
        I.lastReply = GetTime()
        local guid = UnitGUID("player")
        if not guid then return end
        if not I.settings.shareProfile then
            Send(table.concat({"1", "A", parsed.token, guid}, "|"), name)
            return
        end
        local r = I.getRating()
        local _, class = UnitClass("player")
        local spec = CurrentSpecName() or ""
        Send(table.concat({"1", "S", parsed.token, guid, string.format("%.2f", r.rating),
            string.format("%.2f", r.peak), r.wins, r.losses, r.streak, r.longestWinStreak,
            tostring(DP.Rating.PlacementCount(r)), r.distinct, class or "", spec}, "|"), name)
    elseif parsed.kind == "A" and I.pending and name == I.pending.name and parsed.guid == I.pending.guid and
        parsed.token == I.pending.token and GetTime() <= I.pending.expires then
        I.pending = nil
        I.remoteInstalled = true
        I.noAddon = false
        I.status = "Rivals installed • profile sharing off"
        if I.Render then I.Render() end
    elseif parsed.kind == "S" and I.pending and name == I.pending.name and parsed.guid == I.pending.guid and
        parsed.token == I.pending.token and GetTime() <= I.pending.expires then
        I.profile = parsed
        I.profile.receivedAt = time()
        I.profile.name = name
        I.profile.class = I.profile.class or (I.target and I.target.class)
        I.profile.duels = (I.profile.wins or 0) + (I.profile.losses or 0)
        I.remoteInstalled = true
        I.noAddon = false
        I.settings.sharedProfiles[parsed.guid] = I.profile
        I.Leaderboard() -- Drop expired entries before applying the size bound.
        local count, oldest, oldestAt = 0, nil, math.huge
        for guid, profile in pairs(I.settings.sharedProfiles) do
            count = count + 1
            if profile.receivedAt < oldestAt then oldest, oldestAt = guid, profile.receivedAt end
        end
        if count > 100 then I.settings.sharedProfiles[oldest] = nil end
        I.pending = nil
        I.status = "Self-reported profile"
        if I.Render then I.Render() end
        if DP.RefreshDuelViews then DP.RefreshDuelViews() end
    end
end

function I.Request()
    local target = I.target
    if not target then return end
    if I.lastRequest and GetTime() - I.lastRequest < 3 then return end
    I.lastRequest = GetTime()
    I.sequence = I.sequence + 1
    local token = tostring(time()) .. "-" .. I.sequence
    I.profile = nil
    I.remoteInstalled = nil
    I.noAddon = false
    I.pending = {name = target.name, guid = target.guid, token = token, expires = GetTime() + 8}
    I.status = "Requesting shared profile..."
    if not I.available or not Send("1|Q|" .. token, target.name) then
        I.pending = nil; I.status = "Addon messaging unavailable"
    end
    if I.Render then I.Render() end
    C_Timer.After(8, function()
        if I.pending and I.pending.token == token then
            I.pending = nil
            I.remoteInstalled = false
            I.noAddon = true
            I.status = "Rivals not detected"
            if I.Render then I.Render() end
        end
    end)
end

function I.Install()
    if I.panel or not InspectFrame or not InspectFrameTab2 or not INSPECTFRAME_SUBFRAMES then return end
    local id = (InspectFrame.numTabs or 2) + 1
    while _G["InspectFrameTab" .. id] do id = id + 1 end
    local panel = CreateFrame("Frame", "RivalsInspectPanel", InspectFrame)
    panel:SetAllPoints(InspectFrame); panel:SetID(id); panel:Hide()

    -- Transparent carved-stone wordmark fitted to the exact band between
    -- the native player-name header and the Rivals navigation tabs.
    panel.logoFrame = CreateFrame("Frame", nil, panel)
    panel.logoFrame:SetSize(194, 41)
    panel.logoFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 94, -27)
    if panel.logoFrame.SetClipsChildren then panel.logoFrame:SetClipsChildren(true) end
    panel.logoFrame:SetFrameLevel(panel:GetFrameLevel() + 2)
    DP.Promos.Attach(panel.logoFrame)
    panel.logoShadowFar = panel.logoFrame:CreateTexture(nil, "ARTWORK")
    panel.logoShadowFar:SetTexture("Interface\\AddOns\\Rivals\\Textures\\RivalsHeaderShadow.tga")
    panel.logoShadowFar:SetTexCoord(0.031250, 0.968750, 0.101562, 0.898438)
    panel.logoShadowFar:SetPoint("TOPLEFT", 2, -2)
    panel.logoShadowFar:SetPoint("BOTTOMRIGHT", -2, -2)
    panel.logoShadowFar:SetVertexColor(.02, .02, .02, .74)
    panel.logoShadowFar:SetBlendMode("BLEND")
    panel.logoShadowNear = panel.logoFrame:CreateTexture(nil, "ARTWORK")
    panel.logoShadowNear:SetTexture("Interface\\AddOns\\Rivals\\Textures\\RivalsShared.tga")
    panel.logoShadowNear:SetTexCoord(0.031250, 0.968750, 0.101562, 0.898438)
    panel.logoShadowNear:SetPoint("TOPLEFT", 1, -1)
    panel.logoShadowNear:SetPoint("BOTTOMRIGHT", -3, -1)
    panel.logoShadowNear:SetVertexColor(.06, .05, .05, .44)
    panel.logoShadowNear:SetBlendMode("BLEND")
    panel.logoHighlight = panel.logoFrame:CreateTexture(nil, "OVERLAY")
    panel.logoHighlight:SetTexture("Interface\\AddOns\\Rivals\\Textures\\RivalsShared.tga")
    panel.logoHighlight:SetTexCoord(0.031250, 0.968750, 0.101562, 0.898438)
    panel.logoHighlight:SetPoint("TOPLEFT", -1, 1)
    panel.logoHighlight:SetPoint("BOTTOMRIGHT", -5, 1)
    panel.logoHighlight:SetVertexColor(1, .98, .92, .11)
    panel.logoHighlight:SetBlendMode("ADD")
    panel.logo = panel.logoFrame:CreateTexture(nil, "OVERLAY")
    panel.logo:SetTexture("Interface\\AddOns\\Rivals\\Textures\\RivalsShared.tga")
    panel.logo:SetTexCoord(0.031250, 0.968750, 0.101562, 0.898438)
    panel.logo:SetPoint("TOPLEFT", panel.logoFrame, "TOPLEFT", 0, 0)
    panel.logo:SetPoint("BOTTOMRIGHT", panel.logoFrame, "BOTTOMRIGHT", -4, 0)
    panel.logo:SetVertexColor(.98, .98, .98, .97)
    panel.logo:SetBlendMode("BLEND")
    panel.logoFrame:Hide()


    -- Keep the native Inspect portrait/title/chrome and make this feel like
    -- the other player's actual Rivals Overview rather than a data dump.
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetColorTexture(0.035, 0.045, 0.06, 0.98)
    background:SetPoint("TOPLEFT", 8, -62)
    background:SetPoint("BOTTOMRIGHT", -8, 8)

    -- InspectFrame is narrower than CharacterFrame. The old layout copied the
    -- Character pane's absolute X coordinates, which shifted every card and
    -- label to the right. Put the entire Rivals layout inside a fixed 292-wide
    -- strip anchored to the actual horizontal center of InspectFrame instead.
    local content = CreateFrame("Frame", nil, panel)
    content:SetWidth(292)
    content:SetPoint("TOP", panel, "TOP", 0, 28)
    content:SetPoint("BOTTOM", panel, "BOTTOM", 0, 0)

    local function Label(y, font)
        local label = content:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 0, y); label:SetWidth(292); label:SetJustifyH("CENTER")
        return label
    end
    local function PositionedLabel(x, y, width, font)
        local label = content:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", x, y); label:SetWidth(width); label:SetJustifyH("CENTER")
        return label
    end

    -- Mirror the owner's Overview geometry: heading, rating card, placement
    -- progress, record/best tiles, then a Rivals-only local matchup section.
    local heading = Label(-109, "GameFontNormalLarge")
    heading:SetText("DUEL RATING")
    heading:SetTextColor(.72, .66, .50, 1)
    local leftFiligree = content:CreateTexture(nil, "ARTWORK")
    if leftFiligree.SetAtlas then leftFiligree:SetAtlas("PetJournal-BattleSlotTitle-Left", true) end
    leftFiligree:SetSize(25, 25)
    leftFiligree:SetPoint("CENTER", heading, "CENTER", -72, 0)
    leftFiligree:SetVertexColor(.72, .66, .50, .98)
    leftFiligree:SetBlendMode("BLEND")
    local rightFiligree = content:CreateTexture(nil, "ARTWORK")
    if rightFiligree.SetAtlas then rightFiligree:SetAtlas("PetJournal-BattleSlotTitle-Right", true) end
    rightFiligree:SetSize(25, 25)
    rightFiligree:SetPoint("CENTER", heading, "CENTER", 72, 0)
    rightFiligree:SetVertexColor(.72, .66, .50, .98)
    rightFiligree:SetBlendMode("BLEND")

    for i = 0, 41 do
        local glow = math.sin((i / 41) * math.pi)
        DP.Theme.Fill(content, 2, -144 - i * 2, 288, 2,
            .035 + glow * .035, .055 + glow * .055, .09 + glow * .08)
    end
    DP.Theme.Border(content, 0, -142, 292, 88)
    DP.Theme.Border(content, 3, -145, 286, 82)
    local value = Label(-154, "GameFontNormalHuge")
    local status = Label(-184, "GameFontHighlightSmall")
    local duelText = PositionedLabel(12, -196, 118, "GameFontHighlightSmall")
    local rivalText = PositionedLabel(162, -196, 118, "GameFontHighlightSmall")
    local duelProgress = DP.Theme.ProgressRow(content, 10, 71, -211, {.18, .59, 1})
    local rivalProgress = DP.Theme.ProgressRow(content, 5, 221, -211, {.68, .38, 1})

    DP.Theme.Fill(content, 0, -238, 292, 52, .065, .08, .095)
    DP.Theme.Border(content, 0, -238, 142, 52)
    DP.Theme.Border(content, 150, -238, 142, 52)
    DP.Theme.Fill(content, 145.5, -246, 1, 36, .30, .29, .25)
    local record = PositionedLabel(8, -238, 126, "GameFontHighlight")
    record:SetHeight(52); record:SetJustifyV("MIDDLE")
    local peak = PositionedLabel(158, -238, 126, "GameFontHighlight")
    peak:SetHeight(52); peak:SetJustifyV("MIDDLE")

    -- The owner does not have this card because it is specifically the local
    -- relationship between you and the Rival being inspected.
    DP.Theme.Fill(content, 0, -296, 292, 54, .055, .075, .095)
    DP.Theme.Border(content, 0, -296, 292, 54)
    DP.Theme.Fill(content, 145.5, -312, 1, 24, .30, .29, .25)
    local matchupTitle = Label(-304, "GameFontNormalSmall")
    matchupTitle:SetText("YOUR MATCHUP")
    local personalRecord = PositionedLabel(8, -316, 126, "GameFontHighlight")
    personalRecord:SetHeight(30); personalRecord:SetJustifyV("MIDDLE")
    local personalEstimate = PositionedLabel(158, -316, 126, "GameFontHighlight")
    personalEstimate:SetHeight(30); personalEstimate:SetJustifyV("MIDDLE")

    -- Inspect has less usable vertical space than the Character pane. Keep
    -- streak information as a compact summary line instead of another full card.
    local streakText = Label(-360, "GameFontHighlightSmall")
    streakText:ClearAllPoints(); streakText:SetPoint("TOPLEFT", 0, -360); streakText:SetWidth(292); streakText:SetJustifyH("CENTER")
    streakText:SetHeight(18); streakText:SetJustifyV("MIDDLE")
    local bestText = streakText -- kept as an alias for existing refresh/test references

    local refresh = DP.Theme.Button(content, "Refresh profile", 76, -385, 140)
    refresh:ClearAllPoints(); refresh:SetSize(140, 22); refresh:SetPoint("TOPLEFT", 76, -385); refresh:SetText("Refresh profile")
    local note = Label(-414, "GameFontDisableSmall")
    note:ClearAllPoints(); note:SetPoint("TOPLEFT", 0, -414); note:SetWidth(292); note:SetJustifyH("CENTER")
    note:SetHeight(16); note:SetJustifyV("MIDDLE")
    refresh:SetScript("OnClick", I.Request)

    local invite = DP.Theme.Button(panel, "Whisper Rivals link", 0, 0, 174)
    invite:ClearAllPoints(); invite:SetSize(174, 23); invite:SetPoint("CENTER", panel, "CENTER", 0, -8)
    invite:SetText("Whisper Rivals link")
    invite:Hide()
    invite:SetScript("OnClick", function()
        if not I.target or not I.target.name or not SendChatMessage then return end
        SendChatMessage("Rivals addon: " .. DP.Promos.url, "WHISPER", nil, I.target.name)
    end)

    local function TargetShortName()
        local name = I.target and I.target.name
        return name and (name:match("^([^%-]+)") or name) or nil
    end

    function I.Render()
        if I.noAddon then
            content:Hide()
            invite:Show()
            return
        end
        invite:Hide()
        content:Show()
        local p = I.profile
        local placements = p and DP.Rating.PlacementCount(p) or 0
        local distinct = p and p.distinct or 0
        value:SetText(p and string.format("%.1f", p.rating) or "—")
        if p then
            status:SetText(DP.Rating.Provisional(p) and "|cffffca67Provisional|r  |cff8f98a8• Shared profile|r" or
                "|cff65e6adEstablished|r  |cff8f98a8• Shared profile|r")
        else
            status:SetText(I.status or "No shared profile")
        end
        duelText:SetText(string.format("|cff79bdff%d / 10 duels|r", math.min(10, math.floor(placements or 0))))
        rivalText:SetText(string.format("|cffe5b9ff%d / 5 opponents|r", math.min(5, math.floor(distinct or 0))))
        duelProgress:SetProgress(math.min(10, placements or 0), false)
        rivalProgress:SetProgress(math.min(5, distinct or 0), false)

        if p then
            record:SetText(string.format("|cff65e6ad%d|r — |cffff8888%d|r\nRated record", p.wins, p.losses))
            peak:SetText(string.format("|cffffce70%.1f|r\nPersonal best", p.peak))
        else
            record:SetText("—\nRated record")
            peak:SetText("—\nPersonal best")
        end

        local r = I.getRating and I.getRating()
        local known = r and I.target and (r.opponents[I.target.guid] or r.opponents[I.target.name])
        local shortName = TargetShortName()
        local priorDuels = known and ((known.wins or 0) + (known.losses or 0)) or 0
        if shortName then
            local displayName = shortName
            if I.target and I.target.class then displayName = DP.Theme.ClassName(displayName, I.target.class) end
            matchupTitle:SetText((priorDuels == 1 and "Your matchup vs " or "Your matchups vs ") .. displayName)
        else
            matchupTitle:SetText(priorDuels == 1 and "Your matchup" or "Your matchups")
        end
        if known then
            personalRecord:SetText(string.format("|cff65e6ad%d|r — |cffff8888%d|r\nYour record", known.wins, known.losses))
            personalEstimate:SetText((known.effective > 0 and string.format("|cffffce70%.1f|r", known.rating) or "—") .. "\nLocal estimate")
        else
            personalRecord:SetText("0 — 0\nYour record")
            personalEstimate:SetText("—\nLocal estimate")
        end

        if p then
            local streak = p.streak or 0
            local streakValue
            if streak > 0 then
                streakValue = string.format("|cff65e6ad%d win%s|r", streak, streak == 1 and "" or "s")
            elseif streak < 0 then
                local losses = math.abs(streak)
                streakValue = string.format("|cffff8888%d loss%s|r", losses, losses == 1 and "" or "es")
            else
                streakValue = "None"
            end
            streakText:SetText(string.format("Current streak: %s   •   Best win streak: |cffffce70%d|r", streakValue, p.longest or 0))
            note:SetText(string.format("Self-reported • refreshed %s • not independently verified", date("%H:%M:%S", p.receivedAt)))
        elseif I.pending then
            streakText:SetText("Current streak: —   •   Best win streak: —")
            note:SetText("Requesting this Rival's shared profile...")
        else
            streakText:SetText("Current streak: —   •   Best win streak: —")
            note:SetText(I.status or "No shared profile")
        end
    end

    panel:SetScript("OnShow", function()
        panel.logoFrame:Show()
        local unit = InspectFrame.unit
        local name, realm
        if unit then name, realm = UnitName(unit) end
        local guid = unit and UnitGUID(unit)
        local _, class = unit and UnitClass(unit)
        I.profile, I.pending, I.target = nil, nil, nil
        I.remoteInstalled, I.noAddon = nil, false
        if name and guid then
            I.target = {name = name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName()), guid = guid, class = class}
            I.status = "Requesting shared profile..."
            I.Request()
        else I.status = "Inspected player unavailable" end
        I.Render()
    end)
    panel:SetScript("OnHide", function()
        I.pending = nil; I.profile = nil; I.target = nil
        I.remoteInstalled, I.noAddon = nil, false
        panel.logoFrame:Hide()
        invite:Hide(); content:Show()
    end)
    INSPECTFRAME_SUBFRAMES[id] = "RivalsInspectPanel"
    local tab = CreateFrame("Button", "InspectFrameTab" .. id, InspectFrame, "CharacterFrameTabButtonTemplate")
    tab:SetID(id); tab:SetText("Duels"); tab:SetPoint("LEFT", InspectFrameTab2, "RIGHT", -16, 0)
    tab:SetScript("OnClick", function() InspectSwitchTabs(id) end)
    PanelTemplates_SetNumTabs(InspectFrame, id); PanelTemplates_TabResize(tab, 0)
    I.panel = panel
    I.ui = {content = content, value = value, status = status, duelProgress = duelProgress, rivalProgress = rivalProgress,
        duelText = duelText, rivalText = rivalText, record = record, peak = peak,
        matchupTitle = matchupTitle, personalRecord = personalRecord, personalEstimate = personalEstimate,
        streak = streakText, best = bestText, note = note, refresh = refresh, invite = invite}
end
