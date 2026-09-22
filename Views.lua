local _, DP = ...
local V = {}
DP.Views = V

function V.Mode(record)
    if record.modelVersion ~= 3 then return "Legacy" end
    if record.duelMode == "rated" then return "Rated" end
    if record.modeReason == "Casual preference" then return "Casual" end
    return "Unconfirmed"
end

function V.RecordTotals(records)
    local totals = {}
    for _, label in ipairs({"Rated", "Casual", "Unconfirmed", "Legacy"}) do totals[label] = {wins = 0, losses = 0} end
    for _, record in ipairs(records) do
        if (record.modelVersion == 1 or record.modelVersion == 2 or record.modelVersion == 3) and record.status == "matched-request-history-only" then
            local bucket = totals[V.Mode(record)]
            local key = record.won and "wins" or "losses"
            bucket[key] = bucket[key] + 1
        end
    end
    return totals
end

function V.PlacementProgress(r)
    local effective, opponents = math.max(0, 10 - DP.Rating.PlacementCount(r)), math.max(0, 5 - r.distinct)
    if effective == 0 and opponents == 0 then return "Placements complete" end
    return string.format("Need %d placement duels; %s", effective, V.Count(opponents, "new opponent", "new opponents"))
end

function V.FilterHistory(records, mode)
    local result = {}
    for _, record in ipairs(records) do
        if mode == "All" or V.Mode(record) == mode then result[#result + 1] = record end
    end
    return result
end

function V.ModeDetails(records)
    local totals, lines = V.RecordTotals(records), {}
    for _, mode in ipairs({"Rated", "Casual", "Unconfirmed", "Legacy"}) do
        local t = totals[mode]
        lines[#lines + 1] = string.format("%s: %d-%d", mode, t.wins, t.losses)
    end
    return lines
end

function V.Count(n, singular, plural)
    return n .. " " .. (n == 1 and singular or plural)
end

local function IsStarredHistoryRecord(record)
    return record and record.starred and true or false
end

local function SetStarredHistoryRecord(record, starred)
    if not record then return end
    if record.kind == "worldpvp" and DP.WorldPvP and DP.WorldPvP.SetStarred then
        DP.WorldPvP.SetStarred(record, starred)
    else
        record.starred = starred and true or nil
    end
end

local function StyleHistoryStar(texture, record)
    if DP.WorldPvP and DP.WorldPvP.StyleStarTexture then
        DP.WorldPvP.StyleStarTexture(texture, IsStarredHistoryRecord(record))
    end
end


function V.Key(record)
    local s = record.session
    local identity = s and s.identity
    return identity and identity.guid or (s and s.opponent) or record.opponent
end

function V.Build(records, rating)
    local data = {History = {}, Opponents = {}, Classes = {}, byOpponent = {}, byClass = {}}
    for i = #records, 1, -1 do
        local r = records[i]
        if (r.modelVersion == 1 or r.modelVersion == 2 or r.modelVersion == 3) and r.status == "matched-request-history-only" then
            local key = V.Key(r)
            local class = r.session and r.session.identity and r.session.identity.class or "UNKNOWN"
            data.History[#data.History + 1] = r
            data.byOpponent[key] = data.byOpponent[key] or {}
            data.byClass[class] = data.byClass[class] or {}
            table.insert(data.byOpponent[key], r)
            table.insert(data.byClass[class], r)
        end
    end
    for key, opponent in pairs(rating.opponents) do
        data.Opponents[#data.Opponents + 1] = {key = key, name = opponent.name, stats = opponent}
    end
    table.sort(data.Opponents, function(a, b)
        local ac, bc = a.stats.lastAt or 0, b.stats.lastAt or 0
        if ac ~= bc then return ac > bc end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    for key, stats in pairs(rating.classes) do
        local unique = {}
        for _, r in ipairs(data.byClass[key] or {}) do unique[V.Key(r)] = true end
        local count = 0
        for _ in pairs(unique) do count = count + 1 end
        local lastAt = 0
        for _, record in ipairs(data.byClass[key] or {}) do lastAt = math.max(lastAt, record.timestamp or 0) end
        data.Classes[#data.Classes + 1] = {key = key, stats = stats, distinct = count, lastAt = lastAt}
    end
    table.sort(data.Classes, function(a, b)
        if a.lastAt ~= b.lastAt then return a.lastAt > b.lastAt end
        return a.key < b.key
    end)
    return data
end

function V.MatchupSummary(rating)
    local qualified = {}
    for class, s in pairs(rating.classes) do
        local count = s.wins + s.losses
        if class ~= "UNKNOWN" and count >= 10 and (s.distinct or 0) >= 3 then
            qualified[#qualified + 1] = {class = class, count = count, rate = s.wins / count, stats = s}
        end
    end
    table.sort(qualified, function(a, b)
        if a.rate ~= b.rate then return a.rate > b.rate end
        if a.count ~= b.count then return a.count > b.count end
        return a.class < b.class
    end)
    local function Description(item)
        local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[item.class]) or item.class
        return string.format("%s %d-%d", name, item.stats.wins, item.stats.losses)
    end
    if #qualified == 0 then return "Matchup summaries need 10 duels against\n3 opponents per class. Local records only." end
    if #qualified == 1 then return "Most-tested: " .. Description(qualified[1]) .. "\nAll recorded duels; local records only." end
    local best = qualified[1]
    table.sort(qualified, function(a, b)
        if a.rate ~= b.rate then return a.rate < b.rate end
        if a.count ~= b.count then return a.count > b.count end
        return a.class < b.class
    end)
    if best.class == qualified[1].class then
        return "Matchups tied by win rate\nMost-tested: " .. Description(best) .. "\nAcross all recorded duels."
    end
    return "Best: " .. Description(best) .. "\nWorst: " .. Description(qualified[1]) .. "\nBy win rate across all recorded duels."
end

function V.Page(items, page, size)
    local pages = math.max(1, math.ceil(#items / size))
    page = math.max(1, math.min(page, pages))
    local rows = {}
    for i = (page - 1) * size + 1, math.min(page * size, #items) do rows[#rows + 1] = items[i] end
    return rows, page, pages
end

function V.Reason(d)
    if not d then return "No rating data" end
    local guards = {['level-disparity-or-unknown'] = "No rating: level gap is 10+ or a level is unknown",
        ['level-disparity'] = "Reduced rating: lower-level opponent",
        ['opponent-win-streak'] = "Reduced rating: more than 8 consecutive wins vs this opponent",
        ['weekly-opponent-wins'] = "No rating: 12 wins vs this opponent in 7 days",
        ['weekly-opponent-gain'] = "Rating capped: 64 points vs this opponent in 7 days",
        ['retreat-no-rating'] = "No rating gain: duel ended in retreat",
        ['short-duel'] = "No rating gain: duel lasted less than 5 seconds",
        ['recovered-evidence-incomplete'] = "No rating: recovered result lacks observed duel evidence"}
    if guards[d.guardReason] then return guards[d.guardReason] end
    if d.eligible then
        return d.weight == 0 and "History only: repeat limit" or string.format("%.0f%% rating value", d.weight * 100)
    end
    local names = {['casual-or-unconfirmed-mode'] = "Casual/unconfirmed: no rating impact", ['opponent-guid-unknown'] = "Opponent could not be verified before the duel", ['start-not-observed'] = "Duel start not observed",
        ['clock-moved-backward'] = "Clock moved backward", ['diagnostic-capture'] = "Earlier diagnostic capture"}
    return names[d.reason] or d.reason
end

function V.RatingChange(before, after)
    local delta = after - before
    local color = delta > 0 and "|cff65e6ad" or delta < 0 and "|cffff8888" or "|cffadb5c2"
    return string.format("  |cffadb5c2%.2f|r > |cffffffff%.2f|r %s(%+.2f)|r", before, after, color, delta)
end

function V.EvidenceLabel(record)
    local status = record and record.verification and record.verification.status
    if status == "peer-reported" then return "Rival Report" end
    if status == "confirmed" then return "Rivals Verified" end
    if status == "disputed" then return "Disputed" end
    return "Local Record"
end

local function RatingDeltaLine(label, before, after, labelColor)
    if before == nil or after == nil then return nil end
    local delta = after - before
    local deltaColor = delta > 0 and "|cff65e6ad" or delta < 0 and "|cffff8888" or "|cffadb5c2"
    return string.format("%s%s|r  |cffadb5c2%.2f|r → |cffffffff%.2f|r  %s%+.2f|r",
        labelColor or "|cff79bdff", label, before, after, deltaColor, delta)
end

local function RatingReasonDetail(decision)
    local reason = V.Reason(decision)
    reason = reason:gsub("^No rating:%s*", ""):gsub("^No rating gain:%s*", ""):gsub("^History only:%s*", "")
    return reason:gsub("^%l", string.upper)
end

local function RatingSummaryLines(record, decision)
    if not decision then return nil end
    local lines = {}
    if decision.eligible then
        local changed = math.abs((decision.after or 0) - (decision.before or 0)) >= .005
        if decision.matchup then
            changed = changed or math.abs((decision.matchup.after or 0) - (decision.matchup.before or 0)) >= .005
        end
        if changed then
            lines[#lines + 1] = "|cffffce70Rating change|r"
            local you = RatingDeltaLine("You", decision.before, decision.after, "|cff79bdff")
            local rival = RatingDeltaLine("Rival estimate", decision.opponentBefore, decision.opponentAfter, "|cffffad66")
            if you then lines[#lines + 1] = you end
            if rival then lines[#lines + 1] = rival end
            if decision.matchup then
                local m = decision.matchup
                local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[m.class]) or
                    (m.class and (m.class:sub(1, 1) .. m.class:sub(2):lower())) or "Matchup"
                local label = className .. " matchup"
                local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
                local labelColor = color and string.format("|cff%02x%02x%02x", math.floor(color.r * 255 + .5), math.floor(color.g * 255 + .5), math.floor(color.b * 255 + .5)) or "|cffffce70"
                local matchup = RatingDeltaLine(label, m.before, m.after, labelColor)
                if matchup then lines[#lines + 1] = matchup end
            end
        else
            lines[#lines + 1] = "|cffffce70No rating change|r"
            lines[#lines + 1] = "|cff9da6b5" .. RatingReasonDetail(decision) .. "|r"
            if decision.before ~= nil and decision.opponentBefore ~= nil then
                lines[#lines + 1] = string.format("|cff79bdffYou|r  %.2f    |cffffad66Rival estimate|r  %.2f",
                    decision.before, decision.opponentBefore)
            end
        end
    else
        lines[#lines + 1] = "|cffffce70No rating impact|r"
        if not (record and record.modeFailure and decision.reason == "casual-or-unconfirmed-mode") then
            lines[#lines + 1] = "|cff9da6b5" .. RatingReasonDetail(decision) .. "|r"
        end
    end
    return lines
end

function DP.InstallViews(panel, getRating, getRecords, overview)
    local graph = DP.InstallGraph(panel, getRating, getRecords)
    local duelOverviewPage = overview.duelPage or overview
    local body = CreateFrame("Frame", nil, panel)
    body:SetAllPoints(panel)
    local current, page, filter, filterLabel, filterSource = "Overview", 1
    local modes, modeIndex, establishedOnly, leaderboardSort = {"All", "Rated", "Casual", "Unconfirmed", "Legacy"}, 1, false, "rating"
    local historySource, matchupSource = "all", "duels"
    local cached, cachedCount, cachedRating
    local nav, rows = {}, {}
    local function Label(parent, y, font)
        local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 30, y)
        label:SetWidth(292)
        label:SetJustifyH("LEFT")
        return label
    end
    local title = Label(body, -111, "GameFontNormal")
    title:SetWordWrap(false)
    local matchupDetailSummary = Label(body, -128, "GameFontDisableSmall")
    matchupDetailSummary:SetWidth(292); matchupDetailSummary:SetJustifyH("LEFT"); matchupDetailSummary:Hide()
    local empty = Label(body, -205)
    empty:SetText("No duels recorded in this view yet.")
    local emptyCard = CreateFrame("Frame", nil, body)
    emptyCard:SetAllPoints(body)
    DP.Theme.Fill(emptyCard, 30, -185, 292, 118, .045, .065, .095)
    DP.Theme.Border(emptyCard, 30, -185, 292, 118)
    -- Keep the empty-state copy as one centered composition inside the card.
    empty:SetParent(emptyCard)
    empty:ClearAllPoints(); empty:SetPoint("TOPLEFT", emptyCard, "TOPLEFT", 40, -205); empty:SetWidth(272); empty:SetJustifyH("CENTER")
    local emptyHint = Label(emptyCard, -244, "GameFontDisableSmall")
    emptyHint:ClearAllPoints(); emptyHint:SetPoint("TOPLEFT", emptyCard, "TOPLEFT", 40, -244); emptyHint:SetWidth(272); emptyHint:SetJustifyH("CENTER")
    local scope = Label(body, -403, "GameFontDisableSmall")
    scope:SetText("Tracked duels since 0.2.0. Local records only.\nSelect an opponent or class to see its history.")
    local Button = DP.Theme.Button
    local refresh
    local function Select(view, selectedFilter, label, source)
        current, filter, filterLabel, filterSource, page = view, selectedFilter, label, source, 1
        refresh()
        if view == "Overview" then
            local worldSelected = DP.WorldPvP and DP.WorldPvP.GetOverviewMode and DP.WorldPvP.GetOverviewMode() == "world"
            if worldSelected and DP.WorldPvP.PlayOverviewSweep then DP.WorldPvP.PlayOverviewSweep()
            elseif DP.PlayOverviewSweep then DP.PlayOverviewSweep() end
        end
    end
    for i, spec in ipairs({{"Overview", "Overview"}, {"History", "History"}, {"Matchups", "Opponents"}, {"Rivals", "Leaderboard"}}) do
        local label, view = spec[1], spec[2]
        nav[label] = Button(panel, label, 12 + (i - 1) * 81, -74, 81, function()
            -- Matchups inherits the user's current Overview context whenever the
            -- top-level tab is opened. The local source dropdown can still be
            -- changed afterward without Opponents/Classes snapping it back.
            if label == "Matchups" then
                local overviewMode = DP.WorldPvP and DP.WorldPvP.GetOverviewMode and DP.WorldPvP.GetOverviewMode() or
                    (DP.WorldPvP and DP.WorldPvP.overviewMode) or "duels"
                matchupSource = overviewMode == "world" and "world" or "duels"
                page = 1
            end
            Select(view)
        end)
    end
    -- Non-Overview period filter. Overview owns a separate control parented to
    -- the Duel carousel page so it travels with that page during a swipe.
    local periodButton = DP.Theme.DropDown(panel, 180, -104, 142,
        function() return DP.DisplayPeriodOptions and DP.DisplayPeriodOptions() or {{text = "Lifetime", value = "lifetime"}} end,
        function(value) if DP.SetDisplayPeriod then DP.SetDisplayPeriod(value) end end)
    local overviewPeriodButton = DP.Theme.DropDown(duelOverviewPage, 180, -350, 142,
        function() return DP.DisplayPeriodOptions and DP.DisplayPeriodOptions() or {{text = "Lifetime", value = "lifetime"}} end,
        function(value) if DP.SetDisplayPeriod then DP.SetDisplayPeriod(value) end end)
    overviewPeriodButton:SetParent(duelOverviewPage)
    local details = CreateFrame("Frame", nil, panel)
    details:SetAllPoints(panel); details:Hide()
    local detailsTitle = Label(details, -111, "GameFontNormal")
    detailsTitle:SetText("Record details")
    local detailTiles = {}
    for i, name in ipairs({"Rated", "Casual", "Unconfirmed", "Legacy"}) do
        local x, y = 30 + ((i - 1) % 2) * 150, -144 - math.floor((i - 1) / 2) * 57
        DP.Theme.Fill(details, x, y, 142, 51, .055, .075, .095)
        DP.Theme.Border(details, x, y, 142, 51)
        local text = Label(details, y - 10)
        text:ClearAllPoints(); text:SetPoint("TOPLEFT", x + 8, y - 10); text:SetWidth(126); text:SetJustifyH("CENTER")
        detailTiles[name] = text
    end
    DP.Theme.Border(details, 30, -265, 292, 112)
    local detailsText = Label(details, -278)
    detailsText:ClearAllPoints(); detailsText:SetPoint("TOPLEFT", 40, -278); detailsText:SetWidth(272)
    local detailsBack = Button(details, "< Overview", 30, -395, 142, function() Select("Overview") end)
    local graphBack = Button(graph, "< Overview", 30, -395, 142, function() Select("Overview") end)
    local manageBack = Button(body, "< Manage", 30, -395, 142, function() Select("Manage") end)
    -- Duel preference is part of the Duel page, not stationary Overview chrome.
    -- Parenting it here makes it enter/leave with every other Duel element.
    local modeButton = Button(duelOverviewPage, "Rated", 30, -350, 136, function() if DP.ToggleDuelMode then DP.ToggleDuelMode() end end)
    modeButton:SetParent(duelOverviewPage)

    local manage = CreateFrame("Frame", nil, panel)
    manage:SetAllPoints(panel); manage:Hide()
    local manageTitle = Label(manage, -111, "GameFontNormalLarge")
    manageTitle:SetJustifyH("CENTER"); manageTitle:SetText("Manage Rivals")
    local sharingTitle = Label(manage, -128, "GameFontNormal")
    sharingTitle:SetJustifyH("CENTER"); sharingTitle:SetText("PROFILE SHARING")
    local sharingHelp = Label(manage, -149, "GameFontDisableSmall")
    sharingHelp:SetJustifyH("CENTER")
    sharingHelp:SetText("Shares your rating summary only when another Rival inspects you.\nEnabled by default; no duel history is transmitted.")
    local shareOn = Button(manage, "On", 30, -189, 146, function() if DP.SetProfileSharing then DP.SetProfileSharing(true) end end)
    local shareOff = Button(manage, "Off", 176, -189, 146, function() if DP.SetProfileSharing then DP.SetProfileSharing(false) end end)
    local worldTrackingTitle = Label(manage, -226, "GameFontNormal")
    worldTrackingTitle:SetJustifyH("CENTER"); worldTrackingTitle:SetText("WORLD PVP TRACKING")
    local worldTrackingHelp = Label(manage, -247, "GameFontDisableSmall")
    worldTrackingHelp:SetJustifyH("CENTER"); worldTrackingHelp:SetText("Automatically records open-world player fights. No duel rating impact.")
    local worldOn = Button(manage, "On", 30, -270, 146, function() if DP.WorldPvP then DP.WorldPvP.SetEnabled(true) end end)
    local worldOff = Button(manage, "Off", 176, -270, 146, function() if DP.WorldPvP then DP.WorldPvP.SetEnabled(false) end end)
    local recoveryTitle = Label(manage, -314, "GameFontNormal")
    recoveryTitle:SetJustifyH("CENTER"); recoveryTitle:SetText("RECOVERY")
    local recoveryHelp = Label(manage, -314, "GameFontDisableSmall"); recoveryHelp:Hide()
    local recoveryOpen = Button(manage, "Interrupted duels  >", 30, -334, 292, function() Select("Interrupted") end)
    local manageOverviewBack = Button(manage, "< Overview", 30, -395, 142, function() Select("Overview") end)
    local clearProfiles = Button(manage, "Clear Rivals cache", 180, -395, 142, function()
        if StaticPopup_Show then
            StaticPopup_Show("RIVALS_CLEAR_PROFILE_CACHE")
        else
            DP.Inspect.ClearLeaderboard(); page = 1
        end
    end)

    modeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(DP.DuelAgreementStatus and DP.DuelAgreementStatus() or "Preference for your next duel")
        GameTooltip:Show()
    end)
    modeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local recoveryStatus = Label(body, -133, "GameFontHighlightSmall")
    local previous = Button(body, "Prev", 30, -380, 60, function() page = page - 1; refresh() end)
    local nextPage = Button(body, "Next", 262, -380, 60, function() page = page + 1; refresh() end)
    local pageLabel = Label(body, -386)
    pageLabel:ClearAllPoints(); pageLabel:SetPoint("TOPLEFT", 95, -386); pageLabel:SetWidth(162); pageLabel:SetJustifyH("CENTER")
    local clear = Button(body, "< Matchups", 180, -137, 142, function() Select(filterSource or "Opponents") end)
    local matchups = DP.Theme.DataTab(body, "Opponents", 30, -137, 146, function() Select("Opponents") end)
    local classes = DP.Theme.DataTab(body, "Classes", 176, -137, 146, function() Select("Classes") end)
    local modeLabels = {All = "All modes", Rated = "Rated", Casual = "Casual",
        Unconfirmed = "Unconfirmed", Legacy = "Legacy"}
    local historySourceButton = DP.Theme.DropDown(body, 30, -104, 142,
        function()
            return {{text = "All encounters", value = "all"}, {text = "World PvP", value = "world"},
                {text = "Starred", value = "starred"}, {text = "All duels", value = "duels"}, {text = "Rated duels", value = "rated"},
                {text = "Casual duels", value = "casual"}, {text = "Unconfirmed duels", value = "unconfirmed"},
                {text = "Legacy duels", value = "legacy"}}
        end,
        function(value)
            local modeFor = {duels = "All", rated = "Rated", casual = "Casual", unconfirmed = "Unconfirmed", legacy = "Legacy"}
            if value == "world" or value == "all" or value == "starred" then
                historySource, modeIndex = value, 1
            else
                historySource = "duels"
                local wanted = modeFor[value] or "All"
                for index, mode in ipairs(modes) do if mode == wanted then modeIndex = index; break end end
            end
            page = 1; refresh()
        end)
    local matchupSourceButton = DP.Theme.DropDown(body, 30, -104, 142,
        function() return {{text = "Duel matchups", value = "duels"}, {text = "World PvP", value = "world"}} end,
        function(value) matchupSource = value == "world" and "world" or "duels"; page = 1; refresh() end)
    local historyMode = DP.Theme.DropDown(body, 180, -104, 142,
        function()
            local options = {}
            for _, mode in ipairs(modes) do options[#options + 1] = {text = modeLabels[mode] or mode, value = mode} end
            return options
        end,
        function(value)
            for index, mode in ipairs(modes) do if mode == value then modeIndex = index; break end end
            page = 1; refresh()
        end)
    local boardFilter = DP.Theme.DropDown(body, 30, -104, 142,
        function()
            return {{text = "All rivals", value = "all"}, {text = "Established only", value = "established"}}
        end,
        function(value)
            establishedOnly = value == "established"; page = 1; refresh()
        end)
    local boardSort = DP.Theme.DropDown(body, 180, -104, 142,
        function()
            return {{text = "Highest rating", value = "rating"}, {text = "Name", value = "name"}, {text = "Class", value = "class"}, {text = "Most duels", value = "duels"}, {text = "Recently updated", value = "recent"}}
        end,
        function(value)
            leaderboardSort = value or "rating"; page = 1; refresh()
        end)
    local interrupted = Button(body, "Interrupted", 180, -105, 142, function() Select("Interrupted") end)
    local retry = Button(body, "Retry recovery", 30, -105, 142, function(self)
        if DP.RetryRecovery then DP.RetryRecovery() end
        GameTooltip:SetOwner(self or body, "ANCHOR_RIGHT")
        GameTooltip:SetText(DP.RecoveryStatus and DP.RecoveryStatus() or "Recovery requested")
        GameTooltip:Show()
    end)
    retry:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(DP.RecoveryStatus and DP.RecoveryStatus() or "Target the opponent to retry recovery.")
        GameTooltip:Show()
    end)
    retry:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local accepted = Button(body, "Accepted", 180, -105, 142, function() Select("Accepted") end)
    local pendingReports = Button(body, "Interrupted", 30, -105, 292, function() Select("Interrupted") end)
    for _, control in ipairs({retry, accepted, pendingReports}) do
        local x = (control == accepted) and 180 or 30
        control:ClearAllPoints(); control:SetPoint("TOPLEFT", x, -137)
    end
    recoveryStatus:ClearAllPoints(); recoveryStatus:SetPoint("TOPLEFT", 30, -165)
    local scrolling = false
    local scrollbar = CreateFrame("Slider", nil, body)
    scrollbar:SetPoint("TOPLEFT", 320, -168); scrollbar:SetSize(12, 212)
    scrollbar:SetOrientation("VERTICAL")
    -- Compact native Blizzard scrollbar treatment. The previous knob was mostly
    -- outside the History gutter, so the list looked arbitrarily shifted left.
    -- Keep the full control inside the pane and use the stock middle/knob art.
    local scrollTrack = scrollbar:CreateTexture(nil, "BACKGROUND")
    scrollTrack:SetTexture("Interface\\Buttons\\UI-ScrollBar-Middle")
    scrollTrack:SetPoint("TOP", 0, -8); scrollTrack:SetPoint("BOTTOM", 0, 8)
    scrollTrack:SetWidth(8); scrollTrack:SetAlpha(.72)
    local thumb = scrollbar:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    thumb:SetSize(16, 24)
    scrollbar:SetThumbTexture(thumb)
    if scrollbar.SetObeyStepOnDrag then scrollbar:SetObeyStepOnDrag(true) end
    if scrollbar.SetHitRectInsets then scrollbar:SetHitRectInsets(-3, -3, 0, 0) end
    scrollbar:SetValueStep(1); scrollbar:SetMinMaxValues(0, 0); scrollbar:SetValue(0)
    scrollbar:SetScript("OnValueChanged", function(_, value)
        if not scrolling then page = math.floor(value + .5) + 1; refresh() end
    end)
    body:EnableMouseWheel(true)
    body:SetScript("OnMouseWheel", function(_, delta) page = page - delta; refresh() end)
    for i = 1, 6 do
        local row = CreateFrame("Button", nil, body)
        row:SetSize(292, 49); row:SetPoint("TOPLEFT", 30, -113 - (i - 1) * 51)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.first = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.first:SetPoint("TOPLEFT", 8, -6); row.first:SetWidth(286); row.first:SetJustifyH("LEFT"); row.first:SetWordWrap(false)
        row.second = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.second:SetPoint("TOPLEFT", 3, -24); row.second:SetWidth(286); row.second:SetJustifyH("LEFT"); row.second:SetWordWrap(false)
        row.mode = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.mode:SetPoint("TOPLEFT", 3, -35); row.mode:SetWidth(286); row.mode:SetJustifyH("LEFT"); row.mode:SetWordWrap(false)
        row.amount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.amount:SetPoint("TOPRIGHT", -8, -7); row.amount:SetWidth(65); row.amount:SetJustifyH("RIGHT")
        row.bg = DP.Theme.Fill(row, 0, 0, 292, 40, .055, .075, .095, .95)
        row.bg:ClearAllPoints(); row.bg:SetAllPoints(row)
        row.border = DP.Theme.Border(row, 0, 0, 292, 40); row.border:ClearAllPoints(); row.border:SetAllPoints(row); row.border:EnableMouse(false)
        if DP.WorldPvP and DP.WorldPvP.CreateMapThumbnail then
            row.worldMap = DP.WorldPvP.CreateMapThumbnail(row, 88, 52)
            row.worldMap:SetPoint("TOPLEFT", 4, -3); row.worldMap:Hide()
        end
        row.starButton = CreateFrame("Button", nil, row)
        row.starButton:SetSize(20, 20)
        row.starButton.icon = row.starButton:CreateTexture(nil, "OVERLAY")
        row.starButton.icon:SetPoint("CENTER")
        row.starButton.icon:SetSize(14, 14)
        row.starButton:SetFrameLevel(row:GetFrameLevel() + 30)
        row.starButton:SetScript("OnEnter", function(self)
            if not self.record then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if IsStarredHistoryRecord(self.record) then
                GameTooltip:SetText("Starred encounter")
                if self.record.kind == "worldpvp" then
                    GameTooltip:AddLine("World PvP stars retain the encounter beyond the rolling recent cap.", .85, .85, .85, true)
                else
                    GameTooltip:AddLine("Keeps this duel in the Starred view for quick access.", .85, .85, .85, true)
                end
                GameTooltip:AddLine("Click to unstar.", .55, .6, .68, true)
            else
                GameTooltip:SetText("Star encounter")
                if self.record.kind == "worldpvp" then
                    GameTooltip:AddLine("Keep this World PvP encounter beyond the rolling recent cap.", .85, .85, .85, true)
                else
                    GameTooltip:AddLine("Add this duel to the Starred view.", .85, .85, .85, true)
                end
            end
            GameTooltip:Show()
        end)
        row.starButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.starButton:SetScript("OnClick", function(self)
            if self.record then
                SetStarredHistoryRecord(self.record, not IsStarredHistoryRecord(self.record))
                refresh()
            end
        end)
        row:SetScript("OnEnter", function(self)
            if self.worldRecord then
                if DP.Usage and DP.Usage.HideHistoryTooltip then DP.Usage.HideHistoryTooltip() end
                GameTooltip:Hide()
                return
            end
            if self.duelRecord and DP.Usage and DP.Usage.ShowHistoryTooltip then
                GameTooltip:Hide()
                DP.Usage.ShowHistoryTooltip(self, self.duelRecord, self.historyMeta)
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tipTitle)
            for _, line in ipairs(self.tipLines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            if DP.Usage and DP.Usage.HideHistoryTooltip then DP.Usage.HideHistoryTooltip() end
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(self)
            if self.worldRecord and DP.WorldPvP and DP.WorldPvP.OpenDetails then GameTooltip:Hide(); DP.WorldPvP.OpenDetails(self.worldRecord); return end
            if self.duelRecord then DP.Usage.OpenDetails(self.duelRecord); return end
            if self.recoveryItem and DP.ReviewRecovery then DP.ReviewRecovery(self.recoveryItem, self.undoRecovery); return end
            if self.destination then Select("MatchupDetail", self.destination, self.tipTitle, current) end
        end)
        rows[i] = row
    end
    local refreshUI = {
        periodButton = periodButton,
        overviewPeriodButton = overviewPeriodButton,
        modeButton = modeButton,
        graph = graph,
        manage = manage,
        body = body,
        nav = nav,
        shareOn = shareOn,
        shareOff = shareOff,
        worldOn = worldOn,
        worldOff = worldOff,
        detailTiles = detailTiles,
        detailsText = detailsText,
        scope = scope,
        empty = empty,
        historySourceButton = historySourceButton,
        historyMode = historyMode,
        boardFilter = boardFilter,
        boardSort = boardSort,
        interrupted = interrupted,
        retry = retry,
        accepted = accepted,
        pendingReports = pendingReports,
        recoveryStatus = recoveryStatus,
        title = title,
        clear = clear,
        manageBack = manageBack,
        pageLabel = pageLabel,
        previous = previous,
        nextPage = nextPage,
        scrollbar = scrollbar,
        emptyCard = emptyCard,
        emptyHint = emptyHint,
        matchupSourceButton = matchupSourceButton,
        matchupDetailSummary = matchupDetailSummary,
    }
    refresh = function()
        local periodValue = DP.DisplayPeriodValue and DP.DisplayPeriodValue() or "lifetime"
        local periodLabel = DP.DisplayPeriodName and DP.DisplayPeriodName() or "Lifetime"
        refreshUI.periodButton:SetSelectedValue(periodValue, periodLabel)
        refreshUI.overviewPeriodButton:SetSelectedValue(periodValue, periodLabel)
        refreshUI.modeButton:SetText(DP.DuelModeLabel and DP.DuelModeLabel() or "Rated")
        refreshUI.modeButton:SetEnabled(not (DP.HasActiveDuel and DP.HasActiveDuel()))
        -- These two controls remain shown whenever Overview is the active top-level
        -- view. Their Duel-page parent determines whether they are actually visible.
        refreshUI.modeButton:SetShown(current == "Overview")
        refreshUI.overviewPeriodButton:SetShown(current == "Overview")
        refreshUI.graph:Hide()
        details:Hide()
        refreshUI.manage:Hide()
        local topFilterView = current == "History" or current == "Opponents" or current == "Classes" or current == "MatchupDetail"
        local historyTab = current == "History"
        local matchupTabs = current == "Opponents" or current == "Classes"
        local worldMatchupDetail = current == "MatchupDetail" and filter and filter.world
        -- The shared period dropdown now belongs only to non-Overview views. The
        -- dedicated Overview copy lives on duelOverviewPage and swipes with it.
        refreshUI.periodButton:SetVisibleWidth(refreshUI.periodButton.usesNativeAssets and 126 or 142)
        refreshUI.periodButton:SetAnchor(180, (current == "Details" or current == "Graph") and -395 or -104)
        refreshUI.overviewPeriodButton:SetVisibleWidth(refreshUI.modeButton:GetWidth())
        local overviewPeriodX = 322 - refreshUI.modeButton:GetWidth() - (refreshUI.overviewPeriodButton.usesNativeAssets and 6 or 0)
        refreshUI.overviewPeriodButton:SetAnchor(overviewPeriodX, -350)
        if refreshUI.historyMode.SetAnchor then refreshUI.historyMode:SetAnchor(30, current == "MatchupDetail" and -137 or -104) end
        refreshUI.periodButton:SetShown(current == "Details" or current == "Graph" or
            (historyTab and historySource == "duels") or
            ((matchupTabs or current == "MatchupDetail") and matchupSource == "duels" and not worldMatchupDetail))
        local activeNav = (current == "Opponents" or current == "Classes" or current == "MatchupDetail") and "Matchups" or
            current == "Leaderboard" and "Rivals" or
            (current == "Manage" or current == "Interrupted" or current == "Accepted" or current == "Details" or current == "Graph") and "Overview" or current
        for view, b in pairs(refreshUI.nav) do DP.Theme.SelectButton(b, view == activeNav, view) end
        if current == "Overview" then refreshUI.body:Hide(); overview:Show(); if DP.RefreshProgress then DP.RefreshProgress() end; return end
        if current == "Manage" then
            refreshUI.body:Hide(); overview:Hide(); refreshUI.manage:Show()
            local sharing = DP.ProfileSharingEnabled and DP.ProfileSharingEnabled() or false
            DP.Theme.ToggleButton(refreshUI.shareOn, sharing, "On")
            DP.Theme.ToggleButton(refreshUI.shareOff, not sharing, "Off")
            local worldEnabled = DP.WorldPvP and DP.WorldPvP.Enabled and DP.WorldPvP.Enabled() or false
            DP.Theme.ToggleButton(refreshUI.worldOn, worldEnabled, "On")
            DP.Theme.ToggleButton(refreshUI.worldOff, not worldEnabled, "Off")
            return
        end
        if current == "Graph" then refreshUI.body:Hide(); overview:Hide(); refreshUI.graph:Show(); DP.RefreshGraph(); return end
        if current == "Details" then
            refreshUI.body:Hide(); overview:Hide(); details:Show()
            local r = getRating()
            local totals = V.RecordTotals(getRecords())
            for name, tile in pairs(refreshUI.detailTiles) do
                local t = totals[name]
                tile:SetText(name .. string.format("\n|cff65e6ad%d W|r   |cffff8888%d L|r", t.wins, t.losses))
            end
            local lines = {string.format("|cff79bdffPlacements|r   %d / 10 duels · %d / 5 rivals", DP.Rating.PlacementCount(r), r.distinct),
                string.format("|cffffce70Streak|r  %d     |cffffce70Best|r  %d", r.streak, r.longestWinStreak), "", V.MatchupSummary(r)}
            refreshUI.detailsText:SetText(table.concat(lines, "\n")); return
        end
        overview:Hide(); refreshUI.body:Show()
        refreshUI.scope:Show()
        refreshUI.scope:ClearAllPoints(); refreshUI.scope:SetPoint("TOPLEFT", 30, (current == "Interrupted" or current == "Accepted") and -363 or -403)
        local records, rating = getRecords(), getRating()
        local allDuelRecords = DP.AllDuelRecords and DP.AllDuelRecords() or records
        if not cached or cachedCount ~= #records or cachedRating ~= rating then
            cached = V.Build(records, rating); cachedCount, cachedRating = #records, rating
        end
        local worldData = DP.WorldPvP and DP.WorldPvP.BuildMatchups and DP.WorldPvP.BuildMatchups() or {Opponents = {}, Classes = {}, byOpponent = {}, byClass = {}}
        local selectedWorldMatchup
        if worldMatchupDetail and filter then
            local source = filter.kind == "opponent" and worldData.Opponents or worldData.Classes
            for _, entry in ipairs(source or {}) do
                if entry.key == filter.key then selectedWorldMatchup = entry; break end
            end
        end
        refreshUI.scope:ClearAllPoints(); refreshUI.scope:SetPoint("TOPLEFT", 30, current == "History" and -414 or current == "Leaderboard" and -403 or -403)
        refreshUI.scope:SetText((DP.DisplayPeriodName and DP.DisplayPeriodName() or "Lifetime") .. " records. Local estimates only.\nSelect an opponent or class for matchup details.")
        if current == "History" or current == "Opponents" or current == "Classes" or current == "MatchupDetail" then
            refreshUI.scope:ClearAllPoints(); refreshUI.scope:SetPoint("TOPLEFT", 30, current == "History" and -397 or current == "Leaderboard" and -399 or -397)
            if current == "History" and historySource == "all" then
                refreshUI.scope:SetText("Duels + World PvP  •  markers show encounter locations")
            elseif current == "History" and historySource == "world" then
                refreshUI.scope:SetText("World PvP history  •  markers show encounter locations")
            elseif current == "History" and historySource == "starred" then
                refreshUI.scope:SetText("Starred encounters  •  kept for quick access")
            elseif (current == "Opponents" or current == "Classes" or worldMatchupDetail) and matchupSource == "world" then
                refreshUI.scope:SetText(worldMatchupDetail and "World PvP records • local observations, no rating impact" or
                    "World PvP rivalry records are local observations only.\nKills/deaths are encounter-relative, not an Elo rating.")
            elseif current == "History" then
                refreshUI.scope:SetText("Duel history  •  local records")
            else
                refreshUI.scope:SetText("Local estimates; client agreement is not proof.\nUsage is partial. Click a duel for details.")
            end
        end
        if worldMatchupDetail then
            refreshUI.scope:ClearAllPoints()
            refreshUI.scope:SetPoint("TOPLEFT", 30, -408)
            refreshUI.scope:SetWidth(292)
            refreshUI.scope:SetJustifyH("CENTER")
        else
            refreshUI.scope:SetWidth(292)
            refreshUI.scope:SetJustifyH("LEFT")
        end
        local items
        if current == "History" then
            local duelHistoryRecords = historySource == "duels" and records or allDuelRecords
            items = DP.WorldPvP and DP.WorldPvP.History and DP.WorldPvP.History(duelHistoryRecords, historySource) or cached.History
        elseif current == "MatchupDetail" and filter and filter.world then
            items = (filter.kind == "opponent" and worldData.byOpponent[filter.key]) or (filter.kind == "class" and worldData.byClass[filter.key]) or {}
        elseif current == "MatchupDetail" then
            items = (filter and filter.kind == "opponent" and cached.byOpponent[filter.key]) or
                (filter and filter.kind == "class" and cached.byClass[filter.key]) or {}
        elseif (current == "Opponents" or current == "Classes") and matchupSource == "world" then
            items = worldData[current]
        else
            items = cached[current]
        end
        if current == "Leaderboard" then
            items = DP.Inspect.Leaderboard(establishedOnly, leaderboardSort)
            refreshUI.scope:SetText("Shared lifetime rivals you inspected.\nSelf-reported, not verified or realm-wide.")
        end
        if current == "Interrupted" then
            items = DP.InterruptedItems and DP.InterruptedItems() or {}
            refreshUI.scope:SetText("Rival Reports are not locally observed results.\nSeparate records; no rating impact.")
        end
        if current == "Accepted" then
            items = DP.AcceptedRecoveryItems and DP.AcceptedRecoveryItems() or {}
            refreshUI.scope:SetText("Accepted Rival Reports. Click to preview undo.\nUndo preserves the original report.")
        end
        refreshUI.empty:SetText(current == "Leaderboard" and "No shared profiles yet. Inspect another Rival\nand open their Duels tab to request one." or
            (current == "History" and historySource == "all") and "No encounters recorded yet." or
            (current == "History" and historySource == "world") and "No World PvP encounters recorded yet." or
            (current == "History" and historySource == "starred") and "No starred encounters yet." or "No duels recorded in this view yet.")
        local duelHistoryLike = (current == "History" and historySource == "duels") or (current == "MatchupDetail" and not (filter and filter.world))
        if duelHistoryLike then items = V.FilterHistory(items, modes[modeIndex]) end
        refreshUI.historySourceButton:SetShown(current == "History")
        if refreshUI.historySourceButton.SetAnchor and current == "History" then
            refreshUI.historySourceButton:SetAnchor(18, -104)
        end
        local historyFilterValue, historyFilterLabel = historySource, "All encounters"
        if historySource == "world" then
            historyFilterValue, historyFilterLabel = "world", "World PvP"
        elseif historySource == "starred" then
            historyFilterValue, historyFilterLabel = "starred", "Starred"
        elseif historySource == "duels" then
            local mode = modes[modeIndex]
            local valueFor = {All = "duels", Rated = "rated", Casual = "casual", Unconfirmed = "unconfirmed", Legacy = "legacy"}
            local labelFor = {All = "All duels", Rated = "Rated duels", Casual = "Casual duels", Unconfirmed = "Unconfirmed duels", Legacy = "Legacy duels"}
            historyFilterValue, historyFilterLabel = valueFor[mode] or "duels", labelFor[mode] or "All duels"
        end
        refreshUI.historySourceButton:SetSelectedValue(historyFilterValue, historyFilterLabel)
        refreshUI.matchupSourceButton:SetShown(current == "Opponents" or current == "Classes")
        refreshUI.matchupSourceButton:SetSelectedValue(matchupSource, matchupSource == "world" and "World PvP" or "Duel matchups")
        refreshUI.historyMode:SetShown(current == "MatchupDetail" and duelHistoryLike); refreshUI.historyMode:SetSelectedValue(modes[modeIndex], modeLabels[modes[modeIndex]] or modes[modeIndex])
        refreshUI.boardFilter:SetShown(current == "Leaderboard"); refreshUI.boardFilter:SetSelectedValue(establishedOnly and "established" or "all", establishedOnly and "Established only" or "All rivals")
        refreshUI.boardSort:SetShown(current == "Leaderboard"); refreshUI.boardSort:SetSelectedValue(leaderboardSort, leaderboardSort == "recent" and "Recently updated" or leaderboardSort == "name" and "Name" or leaderboardSort == "class" and "Class" or leaderboardSort == "duels" and "Most duels" or "Highest rating")
        refreshUI.interrupted:Hide()
        matchups:SetShown(current == "Opponents" or current == "Classes")
        classes:SetShown(current == "Opponents" or current == "Classes")
        DP.Theme.SelectDataTab(matchups, current == "Opponents", "Opponents")
        DP.Theme.SelectDataTab(classes, current == "Classes", "Classes")
        refreshUI.retry:SetShown(current == "Interrupted")
        refreshUI.accepted:SetShown(current == "Interrupted")
        refreshUI.pendingReports:SetShown(current == "Accepted")
        if current == "Accepted" then refreshUI.empty:SetText("No accepted Rival Reports in your record.") end
        if current == "Interrupted" then
            refreshUI.empty:SetText("No recovered entries.")
        end
        refreshUI.recoveryStatus:SetShown(current == "Interrupted")
        refreshUI.recoveryStatus:SetText(current == "Interrupted" and (DP.RecoveryStatus and DP.RecoveryStatus() or "Target the previous opponent and retry recovery.") or "")
        local headerless = current == "History" or current == "Leaderboard" or current == "Opponents" or current == "Classes" or
            (current == "MatchupDetail" and not worldMatchupDetail)
        refreshUI.empty:ClearAllPoints()
        if current == "History" or current == "Opponents" or current == "Classes" or current == "MatchupDetail" then
            refreshUI.empty:SetPoint("TOPLEFT", refreshUI.emptyCard, "TOPLEFT", 40, -205)
            refreshUI.empty:SetWidth(272)
        else
            refreshUI.empty:SetPoint("TOPLEFT", 30, current == "Interrupted" and -228 or -210)
            refreshUI.empty:SetWidth(292)
        end
        if current == "Leaderboard" and establishedOnly then refreshUI.empty:SetText("No established shared profiles.\nSelect All profiles to include provisional players.") end
        refreshUI.title:SetText(current == "Leaderboard" and "Rivals" or current == "Interrupted" and "Manage: recovery" or
            (current == "Opponents" or current == "Classes") and "Matchups" or current == "MatchupDetail" and (filterLabel or "Matchup") or current)
        refreshUI.title:SetWidth(worldMatchupDetail and 292 or 142)
        refreshUI.title:SetJustifyH(worldMatchupDetail and "CENTER" or "LEFT")
        refreshUI.title:SetShown(not headerless)
        refreshUI.matchupDetailSummary:SetShown(worldMatchupDetail)
        if worldMatchupDetail then
            refreshUI.matchupDetailSummary:ClearAllPoints(); refreshUI.matchupDetailSummary:SetPoint("TOPLEFT", 30, -128); refreshUI.matchupDetailSummary:SetWidth(292); refreshUI.matchupDetailSummary:SetJustifyH("CENTER")
            if selectedWorldMatchup then
                if filter.kind == "opponent" then
                    refreshUI.matchupDetailSummary:SetText(string.format("World |cff65e6ad%d|r-|cffff8888%d|r  •  Solo %d-%d  •  %d %s",
                        selectedWorldMatchup.kills or 0, selectedWorldMatchup.deaths or 0, selectedWorldMatchup.soloKills or 0, selectedWorldMatchup.soloDeaths or 0,
                        selectedWorldMatchup.encounters or 0, (selectedWorldMatchup.encounters or 0) == 1 and "encounter" or "encounters"))
                else
                    refreshUI.matchupDetailSummary:SetText(string.format("World |cff65e6ad%d|r-|cffff8888%d|r  •  %d encounters  •  %d rivals",
                        selectedWorldMatchup.kills or 0, selectedWorldMatchup.deaths or 0, selectedWorldMatchup.encounters or 0, selectedWorldMatchup.distinct or 0))
                end
            else refreshUI.matchupDetailSummary:SetText("World PvP encounter history") end
        end
        refreshUI.clear:ClearAllPoints(); refreshUI.clear:SetPoint("TOPLEFT", worldMatchupDetail and 30 or 180, worldMatchupDetail and -148 or -137)
        refreshUI.clear:SetText("< " .. (filterSource == "Classes" and "Classes" or "Opponents"))
        refreshUI.manageBack:SetShown(current == "Interrupted" or current == "Accepted")
        refreshUI.clear:SetShown(current == "MatchupDetail")
        local slice, total
        local pageSize = (current == "Interrupted" or current == "Accepted") and 3 or
            worldMatchupDetail and 4 or current == "History" and (historySource == "duels" and 6 or 4) or 5
        page = math.max(1, math.min(page, math.max(1, #items - pageSize + 1)))
        slice = {}
        for j = page, math.min(#items, page + pageSize - 1) do slice[#slice + 1] = items[j] end
        refreshUI.pageLabel:ClearAllPoints(); refreshUI.pageLabel:SetPoint("TOPLEFT", 95,
            worldMatchupDetail and -394 or (current == "Interrupted" or current == "Accepted") and -351 or current == "History" and -382 or current == "Leaderboard" and -378 or -382)
        refreshUI.pageLabel:SetWidth(162)
        refreshUI.pageLabel:SetText(V.Count(#items, "record", "records"))
        refreshUI.previous:Hide(); refreshUI.nextPage:Hide()
        scrolling = true
        refreshUI.scrollbar:ClearAllPoints(); refreshUI.scrollbar:SetPoint("TOPLEFT", current == "History" and 320 or 325, worldMatchupDetail and -188 or current == "History" and -135 or current == "Leaderboard" and -135 or matchupTabs and -160 or -168)
        refreshUI.scrollbar:SetHeight(worldMatchupDetail and 168 or current == "History" and 235 or current == "Leaderboard" and 196 or matchupTabs and 220 or 212)
        refreshUI.scrollbar:SetMinMaxValues(0, math.max(0, #items - pageSize)); refreshUI.scrollbar:SetValue(page - 1)
        refreshUI.scrollbar:SetShown(#items > pageSize)
        scrolling = false
        local styledEmpty = #items == 0 and (current == "History" or current == "Opponents" or current == "Classes" or current == "MatchupDetail")
        refreshUI.emptyCard:SetShown(#items == 0)
        refreshUI.emptyHint:SetShown(styledEmpty)
        refreshUI.emptyHint:SetText(current == "History" and historySource ~= "duels" and "Open-world fights involving you appear here.\nEncounters close shortly after combat ends; 60 seconds is only a safety timeout." or
            (current == "History" or current == "MatchupDetail") and "Completed duels appear here.\nUse the available filters to browse this record." or
            matchupSource == "world" and "World PvP opponents and classes appear here after an encounter." or "Compare your record by opponent or class.\nComplete a duel to begin building your matchups.")
        refreshUI.empty:SetJustifyH("CENTER")
        refreshUI.empty:SetShown(#items == 0)
        if styledEmpty then
            refreshUI.pageLabel:Hide()
            refreshUI.scope:Hide()
        else
            refreshUI.pageLabel:Show()
        end
        for i, row in ipairs(rows) do
            row:ClearAllPoints()
            local withControls = current == "History" or current == "Leaderboard" or current == "Interrupted" or current == "Accepted"
            local firstRowY = current == "Interrupted" and 210 or current == "History" and 135 or current == "Leaderboard" and 135 or
                worldMatchupDetail and 188 or matchupTabs and 159 or 168
            local roomyHistory = current == "History" and historySource ~= "duels"
            local roomyWorldDetail = worldMatchupDetail
            local rowStep = roomyHistory and 60 or roomyWorldDetail and 50 or (current == "History" or current == "Leaderboard" or matchupTabs) and 39 or 42
            local historyRow = current == "History"
            local rowX = historyRow and 18 or 30
            local rowWidth = historyRow and 296 or 292
            row:SetPoint("TOPLEFT", rowX, -firstRowY - (i - 1) * rowStep)
            row:SetSize(rowWidth, roomyHistory and 58 or roomyWorldDetail and 48 or 40)
            row.first:ClearAllPoints(); row.first:SetPoint("TOPLEFT", 8, -6)
            row.second:ClearAllPoints(); row.second:SetPoint("TOPLEFT", 8, roomyWorldDetail and -21 or -25)
            row.first:SetWidth(rowWidth - 16); row.second:SetWidth(rowWidth - 16)
            if current == "Interrupted" or current == "Accepted" then row.second:ClearAllPoints(); row.second:SetPoint("TOPLEFT", 8, -17) end
            row.mode:ClearAllPoints(); row.mode:SetPoint("TOPLEFT", 8, roomyWorldDetail and -35 or -29); row.mode:SetWidth(rowWidth - 16); row.mode:SetJustifyH("LEFT")
            local item = slice[i]
            row:SetShown(item ~= nil)
            row.destination = nil
            row.recoveryItem = nil
            row.duelRecord = nil
            row.worldRecord = nil
            row.undoRecovery = false
            row.historyMeta = nil
            if row.worldMap then row.worldMap:Hide() end
            row.starButton:Hide(); row.starButton.record = nil
            row.mode:SetText("")
            row.amount:SetText("")
            if item then
                if item.kind == "worldpvp" and (current == "History" or current == "MatchupDetail") then
                    local color = DP.WorldPvP and DP.WorldPvP.ResultColor and DP.WorldPvP.ResultColor(item.resultKey) or "|cffffce70"
                    row.worldRecord = item
                    if current == "History" and row.worldMap and DP.WorldPvP and DP.WorldPvP.SetMapRecord then
                        row.worldMap:Show(); DP.WorldPvP.SetMapRecord(row.worldMap, item)
                        local textWidth = rowWidth - 108
                        row.first:ClearAllPoints(); row.first:SetPoint("TOPLEFT", 100, -6); row.first:SetWidth(textWidth)
                        row.second:ClearAllPoints(); row.second:SetPoint("TOPLEFT", 100, -23); row.second:SetWidth(textWidth)
                        row.mode:ClearAllPoints(); row.mode:SetPoint("TOPLEFT", 100, -40); row.mode:SetWidth(textWidth); row.mode:SetJustifyH("LEFT")
                    else
                        row.first:SetWidth(rowWidth - 30)
                    end
                    row.starButton.record = item
                    row.starButton:ClearAllPoints()
                    if current == "History" and row.worldMap and row.worldMap:IsShown() then
                        row.starButton:SetPoint("TOPLEFT", row.worldMap, "TOPLEFT", 1, -1)
                    else
                        row.starButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -5)
                    end
                    row.starButton:Show()
                    StyleHistoryStar(row.starButton.icon, item)
                    row.first:SetText(DP.WorldPvP and DP.WorldPvP.HistoryOpponentLine and DP.WorldPvP.HistoryOpponentLine(item) or
                        (color .. (item.resultLabel or "WORLD PVP") .. "|r"))
                    row.amount:SetText("")
                    local headcount = DP.WorldPvP and DP.WorldPvP.EncounterHeadcount and DP.WorldPvP.EncounterHeadcount(item) or string.format("%dv%d", item.friendlyCount or 1, item.enemyCount or 0)
                    local survival = DP.WorldPvP and DP.WorldPvP.SurvivalText and DP.WorldPvP.SurvivalText(item) or (item.playerDied and "death" or "survived")
                    if DP.WorldPvP and DP.WorldPvP.HistoryResultLine then
                        row.second:SetText(DP.WorldPvP.HistoryResultLine(item))
                    else
                        row.second:SetText(string.format("%s · %d %s · %s", headcount, item.enemyDeaths or 0,
                            (item.enemyDeaths or 0) == 1 and "kill" or "kills", survival))
                    end
                    local loc = item.location or {}
                    row.mode:SetText(string.format("%s · %s", date("%m/%d %H:%M", item.timestamp), loc.zone or "Unknown"))
                    row.tipTitle = item.resultLabel or "World PvP"
                    row.tipLines = {}
                elseif current == "History" or current == "MatchupDetail" then
                    row.duelRecord = item
                    row.starButton.record = item
                    row.starButton:ClearAllPoints()
                    row.starButton:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
                    row.starButton:Show()
                    StyleHistoryStar(row.starButton.icon, item)
                    row.first:ClearAllPoints(); row.first:SetPoint("TOPLEFT", 25, -6)
                    row.second:ClearAllPoints(); row.second:SetPoint("TOPLEFT", 25, -25)
                    local d = rating.applied[item.id]
                    row.first:SetText(DP.Theme.ClassName(item.opponent, item.session and item.session.identity and item.session.identity.class)); row.first:SetWidth(rowWidth - 126)
                    local delta = d and d.delta or 0
                    row.amount:SetText((delta > 0 and "|cff65e6ad" or delta < 0 and "|cffff8888" or "|cffadb5c2") .. string.format("%+.2f|r", delta))
                    row.second:SetText("|cffadb5c2" .. date("%m/%d %H:%M", item.timestamp) .. "|r  " .. (item.won and "|cff65e6adWin|r" or "|cffff8888Loss|r") .. " · " .. V.EvidenceLabel(item))
                    row.second:ClearAllPoints(); row.second:SetPoint("TOPLEFT", 8, -25)
                    row.second:SetWidth(rowWidth - 114)
                    row.mode:ClearAllPoints(); row.mode:SetPoint("TOPRIGHT", -8, -25); row.mode:SetWidth(74); row.mode:SetJustifyH("RIGHT")
                    row.mode:SetText(V.Mode(item))
                    local class = item.session and item.session.identity and item.session.identity.class
                    row.tipTitle = (item.won and "Win vs " or "Loss vs ") .. DP.Theme.ClassName(item.opponent, class)
                    row.tipLines = {"|cffadb5c2" .. date("%Y-%m-%d %H:%M:%S", item.timestamp) .. "|r", "",
                        "|cffffce70Duel summary|r",
                        item.duration and string.format("Duration: %.2fs (%s)", item.duration, item.durationQuality) or "Duration: unknown"}
                    if item.duelMode then
                        local mode = item.duelMode:gsub("^%l", string.upper)
                        table.insert(row.tipLines, "Mode: " .. mode)
                    end
                    if item.modeFailure then table.insert(row.tipLines, item.modeFailure) end
                    if d and d.guardReason then table.insert(row.tipLines, "|cffadb5c2" .. V.Reason(d) .. "|r") end
                    if d and d.eligible then
                        table.insert(row.tipLines, "")
                        table.insert(row.tipLines, "|cffffce70Rating change|r")
                        table.insert(row.tipLines, "|cff79bdffYour rating|r")
                        table.insert(row.tipLines, V.RatingChange(d.before, d.after))
                        table.insert(row.tipLines, "|cffffad66Rival estimate|r")
                        table.insert(row.tipLines, V.RatingChange(d.opponentBefore, d.opponentAfter))
                    end
                    if d and d.matchup then
                        local m = d.matchup
                        local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[m.class]) or (m.class:sub(1, 1) .. m.class:sub(2):lower())
                        table.insert(row.tipLines, DP.Theme.ClassName(className, m.class) .. " matchup")
                        table.insert(row.tipLines, V.RatingChange(m.before, m.after))
                    end
                    if d and d.eligible and d.pairNumber then
                        table.insert(row.tipLines, "")
                        table.insert(row.tipLines, "|cffadb5c2Duel #" .. d.pairNumber .. " vs this opponent within 24h|r")
                    end
                    for _, line in ipairs(DP.Usage.Tooltip(item)) do table.insert(row.tipLines, line) end

                    local historyMeta = {mode = V.Mode(item)}
                    if item.duration then
                        local quality = item.durationQuality and (" (" .. item.durationQuality .. ")") or ""
                        historyMeta.duration = string.format("%.2fs%s", item.duration, quality)
                    else
                        historyMeta.duration = "Duration unknown"
                    end
                    if item.modeFailure then historyMeta.verificationNote = item.modeFailure end
                    historyMeta.ratingSummary = RatingSummaryLines(item, d)
                    if d and d.eligible and d.pairNumber then
                        historyMeta.footer = "Duel #" .. d.pairNumber .. " vs this opponent within 24h"
                    end
                    row.historyMeta = historyMeta
                elseif current == "Accepted" then
                    row.first:SetText(date("%m/%d %H:%M", item.timestamp) .. "  " .. item.name)
                    row.second:SetText("Accepted: " .. date("%m/%d %H:%M", item.acceptedAt))
                    row.mode:SetText("Click to preview Undo acceptance")
                    row.recoveryItem, row.undoRecovery = item, true
                    row.tipTitle = "Accepted Rival Report"
                    row.tipLines = {"Accepted: " .. date("%Y-%m-%d %H:%M:%S", item.acceptedAt),
                        item.record.acceptanceImpact and string.format("Net lifetime change at acceptance: %+.2f", item.record.acceptanceImpact) or "Original net impact was not saved by the earlier version.",
                        "Undo recalculates current ratings and restores the report.", "Acceptance and undo events are included in /rivals export."}
                elseif current == "Interrupted" then
                    row.first:SetText(date("%m/%d %H:%M", item.timestamp) .. "  " .. item.name)
                    row.second:SetText(item.status .. (item.winner and (item.won and " win" or " loss") or ""))
                    row.mode:SetText(item.status == "Peer-reported" and "Click to review and apply" or "No rating impact")
                    if item.status == "Peer-reported" then row.recoveryItem = item end
                    row.tipTitle = "Interrupted duel vs " .. item.name
                    row.tipLines = {item.status, "Not a locally observed result. No rating or W/L changes.",
                        "Rival Report mode: " .. item.mode, "Recovery requests cover the last 24 hours.",
                        "Target the opponent and retry if no report is available.", "Saved reports do not prove untampered data."}
                elseif current == "Leaderboard" then
                    local classKey = item.class
                    local specName = item.spec or (classKey and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classKey]) or classKey)) or "Unknown"
                    local duels = item.duels or ((item.wins or 0) + (item.losses or 0))
                    local wins, losses = item.wins or 0, item.losses or 0
                    local recordSummary = wins >= losses and string.format("%d-%d rated", wins, losses) or string.format("%d %s", duels, duels == 1 and "duel" or "duels")
                    row.first:SetText(string.format("%d. %s", page - 1 + i, DP.Theme.ClassName(item.name, classKey)))
                    row.first:SetWidth(198)
                    row.amount:SetText(string.format("|cffffce70%.1f|r", item.rating))
                    row.second:SetText(string.format("%s  ·  %s  ·  %s",
                        DP.Rating.Provisional(item) and "|cffffca67Provisional|r" or "|cff65e6adEstablished|r",
                        DP.Theme.ClassName(specName, classKey), recordSummary))
                    row.tipTitle = DP.Theme.ClassName(item.name, classKey)
                    row.tipLines = {"|cffadb5c2Self-reported lifetime rival; not verified.|r", "|cffadb5c2Includes historical rating models.|r", "",
                        string.format("|cff79bdffSpec|r  %s", DP.Theme.ClassName(specName, classKey)),
                        string.format("|cff79bdffRated record|r  |cff65e6ad%d W|r  |cffff8888%d L|r", wins, losses),
                        string.format("|cff79bdffDuels|r  %d", duels),
                        "Updated: " .. date("%m/%d %H:%M", item.receivedAt), V.PlacementProgress(item), "Entries expire after 7 days. Inspect again to refresh."}
                elseif current == "Opponents" and matchupSource == "world" then
                    row.first:SetText(DP.Theme.ClassName(item.name, item.class)); row.first:SetWidth(198)
                    row.amount:SetText(string.format("|cff65e6ad%d|r-|cffff8888%d|r", item.kills or 0, item.deaths or 0))
                    local worldIdentity = (item.level and ("Lv " .. item.level .. "  ·  ") or "") .. (item.spec and (item.spec .. "  ·  ") or "")
                    row.second:SetText(string.format("%sSolo %d-%d  ·  %d encounters", worldIdentity, item.soloKills or 0, item.soloDeaths or 0, item.encounters or 0))
                    row.mode:SetText("")
                    row.tipTitle = DP.Theme.ClassName(item.name, item.class)
                    row.tipLines = {string.format("World record  |cff65e6ad%d kills|r  |cffff8888%d deaths|r", item.kills or 0, item.deaths or 0),
                        item.level and ("Last observed level  " .. item.level) or "Level not observed",
                        item.spec and ("Last inferred spec  " .. item.spec) or "Spec not inferred",
                        string.format("Solo 1v1  %d-%d", item.soloKills or 0, item.soloDeaths or 0),
                        "Last encounter: " .. date("%m/%d %H:%M", item.lastAt or 0)}
                    row.destination = {kind = "opponent", key = item.key, world = true}
                elseif current == "Classes" and matchupSource == "world" then
                    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[item.key]) or item.key
                    if item.key == "UNKNOWN" then name = "Unknown class" end
                    row.first:SetText(DP.Theme.ClassName(name, item.key)); row.first:SetWidth(198)
                    row.amount:SetText(string.format("|cff65e6ad%d|r-|cffff8888%d|r", item.kills or 0, item.deaths or 0))
                    row.second:SetText(string.format("%d encounters  ·  %d rivals", item.encounters or 0, item.distinct or 0))
                    row.mode:SetText("")
                    row.tipTitle = name
                    row.tipLines = {string.format("World record  |cff65e6ad%d kills|r  |cffff8888%d deaths|r", item.kills or 0, item.deaths or 0),
                        string.format("%d observed rivals", item.distinct or 0)}
                    row.destination = {kind = "class", key = item.key, world = true}
                elseif current == "Opponents" then
                    local s = item.stats
                    local recordsForName = cached.byOpponent[item.key] or {}
                    local identity = recordsForName[1] and recordsForName[1].session and recordsForName[1].session.identity
                    row.first:SetText(DP.Theme.ClassName(item.name, identity and identity.class)); row.first:SetWidth(198)
                    row.amount:SetText(s.effective > 0 and string.format("|cffffce70%.1f|r", s.rating) or "—")
                    local estimate = s.effective > 0 and string.format("%.1f local estimate", s.rating) or "Rating unknown"
                    row.second:SetText(string.format("|cff65e6ad%d W|r  |cffff8888%d L|r", s.wins, s.losses))
                    row.mode:ClearAllPoints(); row.mode:SetPoint("TOPRIGHT", -8, -25); row.mode:SetWidth(110); row.mode:SetJustifyH("RIGHT"); row.mode:SetText("Local estimate")
                    row.tipTitle = DP.Theme.ClassName(item.name, identity and identity.class)
                    row.tipLines = {
                        string.format("Your record  |cff65e6ad%d W|r  |cffff8888%d L|r", s.wins, s.losses),
                        string.format("Local estimate  %s", s.effective > 0 and string.format("|cffffce70%.1f|r", s.rating) or "|cffadb5c2Unknown|r"),
                        string.format("Placements  %d / 10 duels", DP.Rating.PlacementCount(s)),
                        "|cffadb5c2Last duel:|r " .. date("%m/%d %H:%M", s.lastAt),
                        "",
                        "|cffffce70Mode breakdown|r"
                    }
                    row.destination = {kind = "opponent", key = item.key}
                else
                    local s = item.stats
                    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[item.key]) or item.key
                    if item.key == "UNKNOWN" then name = "Unknown class" end
                    local matchup = rating.matchups[item.key]
                    local estimate = matchup and matchup.effective > 0 and string.format("%.1f", matchup.rating) or "Unrated"
                    row.first:SetText(DP.Theme.ClassName(name, item.key)); row.first:SetWidth(198)
                    row.amount:SetText("|cffffce70" .. estimate .. "|r")
                    row.second:SetText(string.format("|cff65e6ad%d W|r  |cffff8888%d L|r  ·  %.0f%% wins  ·  %d opponents", s.wins, s.losses, 100 * s.wins / (s.wins + s.losses), item.distinct))
                    row.tipTitle = name
                    row.tipLines = {
                        "|cffadb5c2W/L includes all tracked outcomes, including repeat-limited duels.|r",
                        "|cffadb5c2Matchup ratings begin with 0.5.0; overall rating is independent.|r",
                        "",
                        "|cffffce70Class matchup|r"
                    }
                    if matchup then
                        table.insert(row.tipLines, string.format("Matchup rating  |cffffce70%.1f|r (%s)", matchup.rating,
                            DP.Rating.MatchupProvisional(matchup) and "Provisional" or "Established local estimate"))
                        table.insert(row.tipLines, string.format("Placements  %d / 10 duels; %d / 3 opponents", DP.Rating.PlacementCount(matchup), matchup.distinct))
                    else table.insert(row.tipLines, "|cffadb5c2No eligible matchup results recorded yet.|r") end
                    table.insert(row.tipLines, "")
                    table.insert(row.tipLines, "|cffffce70Mode breakdown|r")
                    row.destination = {kind = "class", key = item.key}
                end
                if current == "Opponents" or current == "Classes" then
                    if matchupSource == "duels" then
                        local recordsForRow = (current == "Opponents" and cached.byOpponent[item.key] or cached.byClass[item.key]) or {}
                        local details = V.ModeDetails(recordsForRow)
                        for _, line in ipairs(details) do
                            local mode, wins, losses = line:match("^(.-): (%d+)%-(%d+)$")
                            if mode then
                                table.insert(row.tipLines, string.format("%s  |cff65e6ad%s W|r  |cffff8888%s L|r", mode, wins, losses))
                            else
                                table.insert(row.tipLines, line)
                            end
                        end
                        table.insert(row.tipLines, "")
                    end
                    table.insert(row.tipLines, current == "Opponents" and "|cffadb5c2Click for opponent matchup details|r" or "|cffadb5c2Click for class matchup details|r")
                end
            end
        end
    end
    if StaticPopupDialogs and not StaticPopupDialogs["RIVALS_CLEAR_PROFILE_CACHE"] then
        StaticPopupDialogs["RIVALS_CLEAR_PROFILE_CACHE"] = {
            text = "Delete all cached Rivals entries?",
            button1 = YES,
            button2 = CANCEL,
            OnAccept = function()
                DP.Inspect.ClearLeaderboard(); page = 1; refresh()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    DP.SelectDuelView = Select
    DP.SetHistorySource = function(source)
        historySource = (source == "world" or source == "duels" or source == "starred") and source or "all"
        modeIndex = 1
        page = 1; if refresh then refresh() end
    end
    DP.SetMatchupSource = function(source)
        matchupSource = source == "world" and "world" or "duels"
        page = 1; if refresh then refresh() end
    end
    DP.ResetDuelViewToOverview = function()
        current, filter, filterLabel, filterSource, page = "Overview", nil, nil, nil, 1
        -- History is a combined record by default each time the Character pane
        -- is reopened; explicit World History navigation can still select World PvP.
        historySource, modeIndex = "all", 1
        refresh()
    end
    DP.RefreshDuelViews = refresh
    DP.duelViewControls = {rows = rows, nav = nav, previous = previous, nextPage = nextPage, clear = clear, page = pageLabel,
        historyMode = historyMode, historySource = historySourceButton, matchupSource = matchupSourceButton, boardFilter = boardFilter, boardSort = boardSort, clearProfiles = clearProfiles, scrollbar = scrollbar, body = body,
        details = details, detailsBack = detailsBack, graphBack = graphBack, period = periodButton, overviewPeriod = overviewPeriodButton, mode = modeButton, manageBack = manageBack, empty = empty, classes = classes, matchups = matchups,
        manage = manage, manageOverviewBack = manageOverviewBack, shareOn = shareOn, shareOff = shareOff, dev1vNToast = dev1vNToast,
        worldOn = worldOn, worldOff = worldOff, recoveryOpen = recoveryOpen}
    refresh()
end
