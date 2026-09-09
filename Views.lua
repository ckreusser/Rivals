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
    local guards = {['level-disparity-or-unknown'] = "No rating: level gap is 10+ or levels are unknown",
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
    local names = {['casual-or-unconfirmed-mode'] = "Casual/unconfirmed: no rating impact", ['opponent-guid-unknown'] = "Opponent identity incomplete", ['start-not-observed'] = "Duel start not observed",
        ['clock-moved-backward'] = "Clock moved backward", ['diagnostic-capture'] = "Earlier diagnostic capture"}
    return names[d.reason] or d.reason
end

function V.RatingChange(before, after)
    local delta = after - before
    local color = delta > 0 and "|cff65e6ad" or delta < 0 and "|cffff8888" or "|cffadb5c2"
    return string.format("  |cffadb5c2%.2f|r > |cffffffff%.2f|r %s(%+.2f)|r", before, after, color, delta)
end

function DP.InstallViews(panel, getRating, getRecords, overview)
    local graph = DP.InstallGraph(panel, getRating, getRecords)
    local body = CreateFrame("Frame", nil, panel)
    body:SetAllPoints(panel)
    local current, page, filter, filterLabel, filterSource = "Overview", 1
    local modes, modeIndex, establishedOnly, leaderboardSort = {"All", "Rated", "Casual", "Unconfirmed", "Legacy"}, 1, false, "rating"
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
    local empty = Label(body, -150)
    empty:SetText("No duels recorded in this view yet.")
    local emptyCard = CreateFrame("Frame", nil, body)
    emptyCard:SetAllPoints(body)
    DP.Theme.Fill(emptyCard, 30, -185, 292, 132, .045, .065, .095)
    DP.Theme.Border(emptyCard, 30, -185, 292, 132)
    -- Text stays on this card's layer, above its background.
    empty:SetParent(emptyCard)
    local emptyHint = Label(emptyCard, -250, "GameFontDisableSmall")
    emptyHint:SetJustifyH("CENTER")
    local scope = Label(body, -403, "GameFontDisableSmall")
    scope:SetText("Tracked duels since 0.2.0. Local records only.\nSelect an opponent or class to see its history.")
    local Button = DP.Theme.Button
    local refresh
    local function Select(view, selectedFilter, label, source)
        current, filter, filterLabel, filterSource, page = view, selectedFilter, label, source, 1
        refresh()
        if view == "Overview" and DP.PlayOverviewSweep then DP.PlayOverviewSweep() end
    end
    for i, spec in ipairs({{"Overview", "Overview"}, {"History", "History"}, {"Matchups", "Opponents"}, {"Rivals", "Leaderboard"}}) do
        local label, view = spec[1], spec[2]
        nav[label] = Button(panel, label, 12 + (i - 1) * 81, -74, 81, function() Select(view) end)
    end
    local periodButton = DP.Theme.DropDown(panel, 180, -350, 142,
        function() return DP.DisplayPeriodOptions and DP.DisplayPeriodOptions() or {{text = "Lifetime", value = "lifetime"}} end,
        function(value) if DP.SetDisplayPeriod then DP.SetDisplayPeriod(value) end end)
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
    local modeButton = Button(overview, "Rated", 30, -350, 136, function() if DP.ToggleDuelMode then DP.ToggleDuelMode() end end)

    local manage = CreateFrame("Frame", nil, panel)
    manage:SetAllPoints(panel); manage:Hide()
    local manageTitle = Label(manage, -111, "GameFontNormalLarge")
    manageTitle:SetJustifyH("CENTER"); manageTitle:SetText("Manage Rivals")
    local sharingTitle = Label(manage, -157, "GameFontNormal")
    sharingTitle:SetJustifyH("CENTER"); sharingTitle:SetText("PROFILE SHARING")
    local sharingHelp = Label(manage, -178, "GameFontDisableSmall")
    sharingHelp:SetJustifyH("CENTER")
    sharingHelp:SetText("Shares your rating summary only when another Rival inspects you.\nEnabled by default; no duel history is transmitted.")
    local shareOn = Button(manage, "On", 30, -218, 146, function() if DP.SetProfileSharing then DP.SetProfileSharing(true) end end)
    local shareOff = Button(manage, "Off", 176, -218, 146, function() if DP.SetProfileSharing then DP.SetProfileSharing(false) end end)
    local recoveryTitle = Label(manage, -270, "GameFontNormal")
    recoveryTitle:SetJustifyH("CENTER"); recoveryTitle:SetText("RECOVERY")
    local recoveryHelp = Label(manage, -291, "GameFontDisableSmall")
    recoveryHelp:SetJustifyH("CENTER"); recoveryHelp:SetText("Review interrupted duels and peer-reported recovery data.")
    local recoveryOpen = Button(manage, "Interrupted duels  >", 30, -322, 292, function() Select("Interrupted") end)
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
    local historyMode = DP.Theme.DropDown(body, 30, -104, 142,
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
    scrollbar:SetPoint("TOPLEFT", 325, -168); scrollbar:SetSize(8, 212)
    scrollbar:SetOrientation("VERTICAL")
    local thumb = scrollbar:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(.70, .54, .30, 1); thumb:SetSize(6, 24)
    scrollbar:SetThumbTexture(thumb)
    DP.Theme.Fill(scrollbar, 2, 0, 2, 212, .16, .17, .19)
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
        row.mode:SetPoint("TOPLEFT", 3, -35); row.mode:SetWidth(286); row.mode:SetJustifyH("LEFT")
        row.amount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.amount:SetPoint("TOPRIGHT", -8, -7); row.amount:SetWidth(65); row.amount:SetJustifyH("RIGHT")
        DP.Theme.Fill(row, 0, 0, 292, 40, .055, .075, .095, .95)
        DP.Theme.Border(row, 0, 0, 292, 40)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tipTitle)
            for _, line in ipairs(self.tipLines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            if self.recoveryItem and DP.ReviewRecovery then DP.ReviewRecovery(self.recoveryItem, self.undoRecovery); return end
            if self.destination then Select("MatchupDetail", self.destination, self.tipTitle, current) end
        end)
        rows[i] = row
    end
    refresh = function()
        periodButton:SetSelectedValue(DP.DisplayPeriodValue and DP.DisplayPeriodValue() or "lifetime",
            DP.DisplayPeriodName and DP.DisplayPeriodName() or "Lifetime")
        modeButton:SetText(DP.DuelModeLabel and DP.DuelModeLabel() or "Rated")
        modeButton:SetEnabled(not (DP.HasActiveDuel and DP.HasActiveDuel()))
        graph:Hide()
        details:Hide()
        manage:Hide()
        local topFilterView = current == "History" or current == "Opponents" or current == "Classes" or current == "MatchupDetail"
        local historyTab = current == "History"
        local matchupTabs = current == "Opponents" or current == "Classes"
        local overviewPeriod = current == "Overview"
        periodButton:SetVisibleWidth(overviewPeriod and modeButton:GetWidth() or
            (periodButton.usesNativeAssets and 126 or 142))
        -- Native artwork begins six pixels inside the logical anchor. Mirror
        -- the left button around the 30..322 content bounds using visible art.
        local periodX = overviewPeriod and (322 - modeButton:GetWidth() - (periodButton.usesNativeAssets and 6 or 0)) or
            ((historyTab or matchupTabs) and 30 or 180)
        periodButton:SetAnchor(periodX,
            current == "Overview" and -345 or (current == "Details" or current == "Graph") and -395 or -104)
        if historyMode.SetAnchor then historyMode:SetAnchor(current == "History" and 180 or 30, current == "MatchupDetail" and -137 or -104) end
        periodButton:SetShown(current == "Overview" or current == "Details" or current == "Graph" or topFilterView)
        local activeNav = (current == "Opponents" or current == "Classes" or current == "MatchupDetail") and "Matchups" or
            current == "Leaderboard" and "Rivals" or
            (current == "Manage" or current == "Interrupted" or current == "Accepted" or current == "Details" or current == "Graph") and "Overview" or current
        for view, b in pairs(nav) do DP.Theme.SelectButton(b, view == activeNav, view) end
        if current == "Overview" then body:Hide(); overview:Show(); if DP.RefreshProgress then DP.RefreshProgress() end; return end
        if current == "Manage" then
            body:Hide(); overview:Hide(); manage:Show()
            local sharing = DP.ProfileSharingEnabled and DP.ProfileSharingEnabled() or false
            DP.Theme.ToggleButton(shareOn, sharing, "On")
            DP.Theme.ToggleButton(shareOff, not sharing, "Off")
            return
        end
        if current == "Graph" then body:Hide(); overview:Hide(); graph:Show(); DP.RefreshGraph(); return end
        if current == "Details" then
            body:Hide(); overview:Hide(); details:Show()
            local r = getRating()
            local totals = V.RecordTotals(getRecords())
            for name, tile in pairs(detailTiles) do
                local t = totals[name]
                tile:SetText(name .. string.format("\n|cff65e6ad%d W|r   |cffff8888%d L|r", t.wins, t.losses))
            end
            local lines = {string.format("|cff79bdffPlacements|r   %d / 10 duels · %d / 5 rivals", DP.Rating.PlacementCount(r), r.distinct),
                string.format("|cffffce70Streak|r  %d     |cffffce70Best|r  %d", r.streak, r.longestWinStreak), "", V.MatchupSummary(r)}
            detailsText:SetText(table.concat(lines, "\n")); return
        end
        overview:Hide(); body:Show()
        scope:Show()
        scope:ClearAllPoints(); scope:SetPoint("TOPLEFT", 30, (current == "Interrupted" or current == "Accepted") and -363 or -403)
        local records, rating = getRecords(), getRating()
        if not cached or cachedCount ~= #records or cachedRating ~= rating then
            cached = V.Build(records, rating); cachedCount, cachedRating = #records, rating
        end
        scope:ClearAllPoints(); scope:SetPoint("TOPLEFT", 30, current == "History" and -414 or current == "Leaderboard" and -403 or -403)
        scope:SetText((DP.DisplayPeriodName and DP.DisplayPeriodName() or "Lifetime") .. " records. Local estimates only.\nSelect an opponent or class for matchup details.")
        if current == "History" or current == "Opponents" or current == "Classes" or current == "MatchupDetail" then
            scope:ClearAllPoints(); scope:SetPoint("TOPLEFT", 30, current == "History" and -399 or current == "Leaderboard" and -399 or -397)
            scope:SetText("Local estimates; client agreement is not proof.\nUsage partial; N/A means none recorded.")
        end
        local items = current == "MatchupDetail" and ((filter and filter.kind == "opponent" and cached.byOpponent[filter.key]) or
            (filter and filter.kind == "class" and cached.byClass[filter.key]) or {}) or cached[current]
        if current == "Leaderboard" then
            items = DP.Inspect.Leaderboard(establishedOnly, leaderboardSort)
            scope:SetText("Shared lifetime rivals you inspected.\nSelf-reported, not verified or realm-wide.")
        end
        if current == "Interrupted" then
            items = DP.InterruptedItems and DP.InterruptedItems() or {}
            scope:SetText("Peer reports are not locally observed results.\nSeparate records; no rating impact.")
        end
        if current == "Accepted" then
            items = DP.AcceptedRecoveryItems and DP.AcceptedRecoveryItems() or {}
            scope:SetText("Accepted peer reports. Click to preview undo.\nUndo preserves the original report.")
        end
        empty:SetText(current == "Leaderboard" and "No shared profiles yet. Inspect another Rival\nand open their Duels tab to request one." or "No duels recorded in this view yet.")
        local historyLike = current == "History" or current == "MatchupDetail"
        if historyLike then items = V.FilterHistory(items, modes[modeIndex]) end
        historyMode:SetShown(historyLike); historyMode:SetSelectedValue(modes[modeIndex], modeLabels[modes[modeIndex]] or modes[modeIndex])
        boardFilter:SetShown(current == "Leaderboard"); boardFilter:SetSelectedValue(establishedOnly and "established" or "all", establishedOnly and "Established only" or "All rivals")
        boardSort:SetShown(current == "Leaderboard"); boardSort:SetSelectedValue(leaderboardSort, leaderboardSort == "recent" and "Recently updated" or leaderboardSort == "name" and "Name" or leaderboardSort == "class" and "Class" or leaderboardSort == "duels" and "Most duels" or "Highest rating")
        interrupted:Hide()
        matchups:SetShown(current == "Opponents" or current == "Classes")
        classes:SetShown(current == "Opponents" or current == "Classes")
        DP.Theme.SelectDataTab(matchups, current == "Opponents", "Opponents")
        DP.Theme.SelectDataTab(classes, current == "Classes", "Classes")
        retry:SetShown(current == "Interrupted")
        accepted:SetShown(current == "Interrupted")
        pendingReports:SetShown(current == "Accepted")
        if current == "Accepted" then empty:SetText("No accepted peer reports in your record.") end
        if current == "Interrupted" then
            empty:SetText("No recovered entries.")
        end
        recoveryStatus:SetShown(current == "Interrupted")
        recoveryStatus:SetText(current == "Interrupted" and (DP.RecoveryStatus and DP.RecoveryStatus() or "Target the previous opponent and retry recovery.") or "")
        local headerless = current == "History" or current == "Leaderboard" or current == "Opponents" or current == "Classes" or current == "MatchupDetail"
        empty:ClearAllPoints(); empty:SetPoint("TOPLEFT", 30, current == "Interrupted" and -228 or current == "History" and -186 or -210)
        if current == "Leaderboard" and establishedOnly then empty:SetText("No established shared profiles.\nSelect All profiles to include provisional players.") end
        title:SetText(current == "Leaderboard" and "Rivals" or current == "Interrupted" and "Manage: recovery" or
            (current == "Opponents" or current == "Classes") and "Matchups" or current == "MatchupDetail" and (filterLabel or "Matchup") or current)
        title:SetWidth(142)
        title:SetJustifyH("LEFT")
        title:SetShown(not headerless)
        clear:ClearAllPoints(); clear:SetPoint("TOPLEFT", 180, -137)
        clear:SetText("< " .. (filterSource == "Classes" and "Classes" or "Opponents"))
        manageBack:SetShown(current == "Interrupted" or current == "Accepted")
        clear:SetShown(current == "MatchupDetail")
        local slice, total
        local pageSize = (current == "Interrupted" or current == "Accepted") and 3 or current == "History" and 6 or 5
        page = math.max(1, math.min(page, math.max(1, #items - pageSize + 1)))
        slice = {}
        for j = page, math.min(#items, page + pageSize - 1) do slice[#slice + 1] = items[j] end
        pageLabel:ClearAllPoints(); pageLabel:SetPoint("TOPLEFT", 95,
            (current == "Interrupted" or current == "Accepted") and -351 or current == "History" and -378 or current == "Leaderboard" and -378 or -382)
        pageLabel:SetWidth(162)
        pageLabel:SetText(V.Count(#items, "record", "records"))
        previous:Hide(); nextPage:Hide()
        scrolling = true
        scrollbar:ClearAllPoints(); scrollbar:SetPoint("TOPLEFT", 325, current == "History" and -135 or current == "Leaderboard" and -135 or matchupTabs and -160 or -168)
        scrollbar:SetHeight(current == "History" and 235 or current == "Leaderboard" and 196 or matchupTabs and 220 or 212)
        scrollbar:SetMinMaxValues(0, math.max(0, #items - pageSize)); scrollbar:SetValue(page - 1)
        scrollbar:SetShown(#items > pageSize)
        scrolling = false
        local styledEmpty = #items == 0 and (current == "History" or current == "Opponents" or current == "Classes" or current == "MatchupDetail")
        emptyCard:SetShown(#items == 0)
        emptyHint:SetShown(styledEmpty)
        emptyHint:SetText((current == "History" or current == "MatchupDetail") and "Completed duels appear here.\nUse the mode and period filters to browse this record." or "Compare your record by opponent or class.\nComplete a duel to begin building your matchups.")
        empty:SetJustifyH("CENTER")
        empty:SetShown(#items == 0)
        for i, row in ipairs(rows) do
            row:ClearAllPoints()
            local withControls = current == "History" or current == "Leaderboard" or current == "Interrupted" or current == "Accepted"
            local firstRowY = current == "Interrupted" and 210 or current == "History" and 135 or current == "Leaderboard" and 135 or matchupTabs and 159 or 168
            local rowStep = (current == "History" or current == "Leaderboard" or matchupTabs) and 39 or 42
            row:SetPoint("TOPLEFT", 30, -firstRowY - (i - 1) * rowStep)
            row:SetSize(292, 40)
            row.second:ClearAllPoints(); row.second:SetPoint("TOPLEFT", 8, -25)
            row.first:SetWidth(276); row.second:SetWidth(276)
            if current == "Interrupted" or current == "Accepted" then row.second:ClearAllPoints(); row.second:SetPoint("TOPLEFT", 8, -17) end
            row.mode:ClearAllPoints(); row.mode:SetPoint("TOPLEFT", 8, -29); row.mode:SetWidth(276); row.mode:SetJustifyH("LEFT")
            local item = slice[i]
            row:SetShown(item ~= nil)
            row.destination = nil
            row.recoveryItem = nil
            row.undoRecovery = false
            row.mode:SetText("")
            row.amount:SetText("")
            if item then
                if current == "History" or current == "MatchupDetail" then
                    local d = rating.applied[item.id]
                    row.first:SetText(DP.Theme.ClassName(item.opponent, item.session and item.session.identity and item.session.identity.class)); row.first:SetWidth(198)
                    local delta = d and d.delta or 0
                    row.amount:SetText((delta > 0 and "|cff65e6ad" or delta < 0 and "|cffff8888" or "|cffadb5c2") .. string.format("%+.2f|r", delta))
                    local evidence = item.verification and item.verification.status
                    row.second:SetText("|cffadb5c2" .. date("%m/%d %H:%M", item.timestamp) .. "|r  " .. (item.won and "|cff65e6adWin|r" or "|cffff8888Loss|r") .. " · " ..
                        (evidence == "peer-reported" and "Peer report" or evidence == "confirmed" and "Both clients" or evidence == "disputed" and "Disputed" or "Local"))
                    row.second:ClearAllPoints(); row.second:SetPoint("TOPLEFT", 8, -25)
                    row.second:SetWidth(194)
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
                        table.insert(row.tipLines, "|cffffce70Rating changes|r")
                        table.insert(row.tipLines, "|cff79bdffYour rating|r")
                        table.insert(row.tipLines, V.RatingChange(d.before, d.after))
                        table.insert(row.tipLines, "|cff79bdffOpponent estimate|r")
                        table.insert(row.tipLines, V.RatingChange(d.opponentBefore, d.opponentAfter))
                    end
                    if d and d.matchup then
                        local m = d.matchup
                        local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[m.class]) or (m.class:sub(1, 1) .. m.class:sub(2):lower())
                        table.insert(row.tipLines, "vs " .. DP.Theme.ClassName(className, m.class) .. " rating")
                        table.insert(row.tipLines, V.RatingChange(m.before, m.after))
                    end
                    if d and d.eligible and d.pairNumber then
                        table.insert(row.tipLines, "")
                        table.insert(row.tipLines, "|cffadb5c2Duel #" .. d.pairNumber .. " vs this opponent within 24h|r")
                    end
                    for _, line in ipairs(DP.Usage.Tooltip(item)) do table.insert(row.tipLines, line) end
                elseif current == "Accepted" then
                    row.first:SetText(date("%m/%d %H:%M", item.timestamp) .. "  " .. item.name)
                    row.second:SetText("Accepted: " .. date("%m/%d %H:%M", item.acceptedAt))
                    row.mode:SetText("Click to preview Undo acceptance")
                    row.recoveryItem, row.undoRecovery = item, true
                    row.tipTitle = "Accepted peer report"
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
                        "Peer-reported mode: " .. item.mode, "Recovery requests cover the last 24 hours.",
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
    DP.RefreshDuelViews = refresh
    DP.duelViewControls = {rows = rows, nav = nav, previous = previous, nextPage = nextPage, clear = clear, page = pageLabel,
        historyMode = historyMode, boardFilter = boardFilter, boardSort = boardSort, clearProfiles = clearProfiles, scrollbar = scrollbar, body = body,
        details = details, detailsBack = detailsBack, graphBack = graphBack, period = periodButton, manageBack = manageBack, empty = empty, classes = classes, matchups = matchups,
        manage = manage, manageOverviewBack = manageOverviewBack, shareOn = shareOn, shareOff = shareOff, recoveryOpen = recoveryOpen}
    refresh()
end
