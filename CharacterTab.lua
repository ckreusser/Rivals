local _, DP = ...

local function InstallCharacterStatsCompatibility(panel)
    local statsPanel, hiddenByRivals

    local function HideStats()
        if not statsPanel then
            -- CSC's panel is anonymous and private to its namespace. Identify
            -- its two dropdowns only when CSC's compatibility API is present.
            -- That API also changes saved preferences, so hide the frame itself.
            if type(CSC_HideStatsPanel) ~= "function" then return end
            for _, child in ipairs({CharacterFrame:GetChildren()}) do
                if child.leftStatsDropDown and child.rightStatsDropDown then
                    statsPanel = child
                    statsPanel:HookScript("OnShow", function()
                        if panel:IsShown() then
                            hiddenByRivals = true
                            statsPanel:Hide()
                        else
                            hiddenByRivals = nil
                        end
                    end)
                    break
                end
            end
        end
        if statsPanel and statsPanel:IsShown() then
            hiddenByRivals = true
            statsPanel:Hide()
        end
    end

    local function RestoreStats()
        -- Native switches can show PaperDollFrame before or after hiding Rivals.
        -- Keep the pending restore until both conditions hold, including reopen.
        if hiddenByRivals and not panel:IsShown()
            and PaperDollFrame and PaperDollFrame:IsShown() then
            hiddenByRivals = nil
            if not (UISettingsGlobal and UISettingsGlobal.statsPanelHidden) then
                statsPanel:Show()
            end
        end
    end

    panel:HookScript("OnShow", HideStats)
    panel:HookScript("OnHide", RestoreStats)
    if PaperDollFrame then PaperDollFrame:HookScript("OnShow", RestoreStats) end
end

function DP.InstallCharacterTab(getRating, getRecords)
    if DP.characterPanel or not CharacterFrame or not CharacterFrameTab5 then return false end
    -- Rivals must not join Blizzard's CharacterFrame tab/subframe registries.
    -- Those registries are traversed by the protected ToggleCharacter path; an
    -- addon-owned CharacterFrameTab6 taints that traversal and prevents C from
    -- opening the character pane during combat. Keep our panel/button completely
    -- separate while preserving the attached-tab appearance.
    local panel = CreateFrame("Frame", "RivalsCharacterPanel", CharacterFrame)
    panel:SetAllPoints(CharacterFrame)
    local tab, tabLabel
    local tabHovered = false
    local pendingNativeRestore = false
    panel:Hide()
    -- Keep all Rivals-owned chrome on the Rivals panel itself. Do not add regions
    -- to CharacterFrame; modifying Blizzard-owned frame regions is unnecessary
    -- taint surface.
    panel.chrome = {}
    for _, part in ipairs({{"TopLeft", 256, 0, 0}, {"TopRight", 128, 256, 0},
        {"BottomLeft", 256, 0, -256}, {"BottomRight", 128, 256, -256}}) do
        local texture = panel:CreateTexture(nil, "BORDER")
        texture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-" .. part[1])
        texture:SetSize(part[2], 256)
        texture:SetPoint("TOPLEFT", part[3], part[4])
        texture:Hide()
        panel.chrome[#panel.chrome + 1] = texture
    end
    -- Transparent carved-stone wordmark fitted to the exact band between
    -- the native player-name header and the Rivals navigation tabs.
    panel.logoFrame = CreateFrame("Frame", nil, panel)
    panel.logoFrame:SetSize(194, 40)
    panel.logoFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 102, -39)
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

    -- Rivals redraws the CharacterFrame body chrome with the classic General
    -- texture set. Its top-right close-button socket sits 2px left of the
    -- stock CharacterFrame anchor, so temporarily align Blizzard's existing
    -- close button to that socket while our panel is visible. This is purely
    -- visual: it does not touch CharacterFrame tab/subframe registration or
    -- selected-tab state.
    local closePoints
    local function AlignCloseButtonToRivalsChrome()
        local close = CharacterFrameCloseButton
        if not close or not close.GetNumPoints then return end
        if not closePoints then
            closePoints = {}
            for i = 1, close:GetNumPoints() do
                closePoints[i] = {close:GetPoint(i)}
            end
        end
        close:ClearAllPoints()
        for _, point in ipairs(closePoints) do
            close:SetPoint(point[1], point[2], point[3], (point[4] or 0) - 2, point[5] or 0)
        end
    end

    local function RestoreCloseButton()
        local close = CharacterFrameCloseButton
        if not close or not closePoints then return end
        close:ClearAllPoints()
        for _, point in ipairs(closePoints) do
            close:SetPoint(unpack(point))
        end
        closePoints = nil
    end

    local function UpdateTabLabelColor(selected)
        if not tabLabel or not tabLabel.SetTextColor then return end
        if selected or tabHovered then
            tabLabel:SetTextColor(1, 1, 1)
        else
            tabLabel:SetTextColor(1, .82, 0)
        end
    end

    local function UpdateTabLabelPosition(selected)
        if not tabLabel or not tabLabel.ClearAllPoints or not tabLabel.SetPoint then return end
        -- Blizzard raises the text on the active CharacterFrame tab slightly as
        -- the selected artwork opens into the pane. Mirror that treatment on our
        -- independent overlay label without handing the tab back to PanelTemplates.
        tabLabel:ClearAllPoints()
        tabLabel:SetPoint("CENTER", tab, "CENTER", 0, selected and 4 or 2)
    end

    local function SetTabSelected(selected)
        if not tab then return end
        if selected and PanelTemplates_SelectTab then
            PanelTemplates_SelectTab(tab)
        elseif not selected and PanelTemplates_DeselectTab then
            PanelTemplates_DeselectTab(tab)
        end
        UpdateTabLabelPosition(selected)
        UpdateTabLabelColor(selected)
    end
    local function CurrentNativeTab()
        local selected = CharacterFrame and CharacterFrame.selectedTab or 1
        local native = selected and _G["CharacterFrameTab" .. selected] or nil
        if native == tab then native = nil end
        return native or CharacterFrameTab1
    end

    local function RestoreNativeTabVisual()
        if InCombatLockdown and InCombatLockdown() then
            pendingNativeRestore = true
            return
        end
        pendingNativeRestore = false
        local native = CurrentNativeTab()
        if native and PanelTemplates_SelectTab then PanelTemplates_SelectTab(native) end
    end

    local function DeselectNativeTabVisual()
        -- This changes only the existing Blizzard tab button's presentation; it
        -- does not alter CharacterFrame.selectedTab, invoke PanelTemplates_SetTab,
        -- or switch CharacterFrame subframes. Keeping it active in combat prevents
        -- the underlying native tab from looking selected at the same time as the
        -- isolated Rivals tab.
        local native = CurrentNativeTab()
        if native and PanelTemplates_DeselectTab then
            PanelTemplates_DeselectTab(native)
        end
    end

    panel:SetScript("OnHide", function()
        SetTabSelected(false)
        RestoreNativeTabVisual()
        RestoreCloseButton()
        if DP.ResetDuelViewToOverview then
            DP.ResetDuelViewToOverview()
        elseif DP.SelectDuelView then
            DP.SelectDuelView("Overview")
        end
        panel.playOverviewSweepOnShow = true
        panel.logoFrame:Hide()
        for _, texture in ipairs(panel.chrome) do texture:Hide() end
    end)
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, 0)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 6, 0)
    local overview = CreateFrame("Frame", nil, content)
    overview:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 5)
    overview:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 5)
    if overview.SetClipsChildren then overview:SetClipsChildren(true) end
    local duelPage = CreateFrame("Frame", nil, overview)
    duelPage:SetAllPoints(overview)
    panel.duelOverviewPage = duelPage
    overview.duelPage = duelPage
    -- Fill the Rivals pane all the way to the inner bottom edge of the Character frame.
    DP.Theme.Fill(panel, 18, -74, 324, 354, .035, .045, .06, .96)
    -- A symmetrical gold frame and graduated midnight-blue field make rating
    -- the focal point without a faction stripe cutting through its border.
    for i = 0, 45 do
        local glow = math.sin((i / 45) * math.pi)
        DP.Theme.Fill(duelPage, 28, -132 - i * 2, 296, 2,
            .035 + glow * .035, .055 + glow * .055, .09 + glow * .08)
    end
    local ratingCard = DP.Theme.Border(duelPage, 26, -130, 300, 96)
    DP.Theme.Border(duelPage, 29, -133, 294, 90)
    panel.ratingHeader = DP.Theme.RatingHeader(duelPage, ratingCard)
    local leftSlab = DP.Theme.StatSlab(duelPage, 26, -240, 140, 58, false)
    local rightSlab = DP.Theme.StatSlab(duelPage, 186, -240, 140, 58, true)
    DP.Theme.Border(duelPage, 26, -304, 300, 38)
    local duelProgress = DP.Theme.ProgressRow(duelPage, 10, 101, -208, {.18, .59, 1})
    local rivalProgress = DP.Theme.ProgressRow(duelPage, 5, 251, -208, {.68, .38, 1})
    local reveal
    local fallbackCheckpoint = {duels = 0, opponents = 0}
    panel.progressRows = {duelProgress, rivalProgress}
    local duelSweep, opponentSweep
    local overviewSweep = DP.Theme.LightSweep(duelPage, ratingCard, {1, .82, .42}, true)
    local promotion
    function DP.PlayOverviewSweep()
        if not duelPage:IsShown() then return end
        overviewSweep:Play(0, .40)
        local state = getRating()
        local checkpoint = DP.ProgressCheckpoint and DP.ProgressCheckpoint() or fallbackCheckpoint
        if not state or DP.Rating.Provisional(state) or checkpoint.promotionSeen then return end
        if promotion.checkpoint == checkpoint then return end
        -- Existing Established profiles do not receive a retroactive graduation.
        if not checkpoint.promotionPending and checkpoint.duels >= 10 and checkpoint.opponents >= 5 then
            checkpoint.promotionSeen = true; return
        end
        checkpoint.promotionPending = true
        local steps = math.max(10 - checkpoint.duels, 5 - checkpoint.opponents)
        promotion:Play(.35 + math.max(0, steps - 1) * .24 + .44 + .9, checkpoint)
    end
    -- Overview sweeps are explicitly triggered after carousel/navigation settles;
    -- do not fire merely because this child frame is shown during a swipe.
    local function Celebrate(duelsDone, opponentsDone)
        if duelsDone then duelSweep:Play(0, .8) end
        if opponentsDone then opponentSweep:Play(0, .8) end
    end
    -- Match the World PvP page with Blizzard's native paired-slab divider.
    DP.Theme.StatDivider(duelPage, 176, -269, 46)
    local function Text(y, font)
        local label = duelPage:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        label:SetPoint("TOPLEFT", 26, y)
        label:SetWidth(300)
        label:SetJustifyH("CENTER")
        return label
    end
    local number = Text(-146, "GameFontNormalHuge")
    number:ClearAllPoints()
    number:SetPoint("TOP", ratingCard, "TOP", -3, -16)
    number:SetWidth(120)
    number:SetJustifyH("CENTER")
    do
        local function AddNumberFlourish(side, mirrored)
            local flourish = duelPage:CreateTexture(nil, "OVERLAY")
            local shadow = duelPage:CreateTexture(nil, "ARTWORK")
            flourish:SetVertexColor(.84, .56, .31, .96)
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
            if side == "left" then
                flourish:SetPoint("CENTER", number, "CENTER", -40, -2)
            else
                flourish:SetPoint("CENTER", number, "CENTER", 42, -2)
            end
            shadow:SetPoint("CENTER", flourish, "CENTER", 1, -1)
            flourish.shadow = shadow
            return flourish
        end
        panel.numberFlourishLeft = AddNumberFlourish("left", false)
        panel.numberFlourishRight = AddNumberFlourish("right", true)
    end
    local placement = Text(-179, "GameFontHighlightSmall")
    promotion = DP.Theme.EstablishedPromotion(duelPage, ratingCard, placement)
    panel.establishedPromotion = promotion
    local progressText = Text(-193, "GameFontHighlightSmall")
    progressText:ClearAllPoints(); progressText:SetPoint("TOPLEFT", 38, -193); progressText:SetWidth(124)
    local opponentProgress = Text(-193, "GameFontHighlightSmall")
    opponentProgress:ClearAllPoints(); opponentProgress:SetPoint("TOPLEFT", 190, -193); opponentProgress:SetWidth(124)
    duelSweep = DP.Theme.CompletionSweep(duelPage, duelProgress, progressText, {121/255, 189/255, 1})
    opponentSweep = DP.Theme.CompletionSweep(duelPage, rivalProgress, opponentProgress, {229/255, 185/255, 1})
    panel.milestoneSweeps = {duelSweep, opponentSweep, overviewSweep}
    local stats = leftSlab:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stats:SetAllPoints(leftSlab); stats:SetJustifyH("CENTER"); stats:SetJustifyV("MIDDLE")
    local peak = rightSlab:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    peak:SetAllPoints(rightSlab); peak:SetJustifyH("CENTER"); peak:SetJustifyV("MIDDLE")
    local last = Text(-304, "GameFontHighlightSmall")
    last:SetHeight(38); last:SetJustifyV("MIDDLE")

    -- Overview hover zones keep the face of the Duel Rating page compact while
    -- exposing the meaning and supporting numbers behind each headline stat.
    local function OverviewTooltip(frame, title, build)
        frame:EnableMouse(true)
        frame:SetScript("OnEnter", function(self)
            local r = getRating()
            if not r then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title)
            build(r)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local ratingHover = CreateFrame("Frame", nil, duelPage)
    ratingHover:SetPoint("TOPLEFT", 26, -130); ratingHover:SetSize(300, 96)
    ratingHover:SetFrameLevel(duelPage:GetFrameLevel() + 8)
    OverviewTooltip(ratingHover, "Duel Rating", function(r)
        local placements = DP.Rating.PlacementCount(r)
        GameTooltip:AddDoubleLine("Current rating", string.format("%.1f", r.rating or 0), .75, .78, .84, 1, .82, .42)
        GameTooltip:AddDoubleLine("Status", DP.Rating.Provisional(r) and "Provisional" or "Established", .75, .78, .84,
            DP.Rating.Provisional(r) and 1 or .40, DP.Rating.Provisional(r) and .79 or .90, DP.Rating.Provisional(r) and .40 or .68)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Placement duels", string.format("%d / 10", math.min(10, placements)), .75, .78, .84, .47, .74, 1)
        GameTooltip:AddDoubleLine("Distinct opponents", string.format("%d / 5", math.min(5, r.distinct or 0)), .75, .78, .84, .90, .72, 1)
        if DP.Rating.Provisional(r) then
            GameTooltip:AddLine("Complete both placement requirements to establish your rating.", .60, .66, .74, true)
        else
            GameTooltip:AddLine("Established from your locally recorded eligible duels.", .60, .66, .74, true)
        end
    end)

    OverviewTooltip(leftSlab, "Rated Record", function(r)
        local totals = DP.Views.RecordTotals(getRecords())
        local rated = totals.Rated or {wins = 0, losses = 0}
        local games = (rated.wins or 0) + (rated.losses or 0)
        GameTooltip:AddDoubleLine("Wins", tostring(rated.wins or 0), .75, .78, .84, .40, .90, .68)
        GameTooltip:AddDoubleLine("Losses", tostring(rated.losses or 0), .75, .78, .84, 1, .53, .53)
        GameTooltip:AddDoubleLine("Win rate", games > 0 and string.format("%.1f%%", (rated.wins or 0) * 100 / games) or "—", .75, .78, .84, 1, .82, .42)
        GameTooltip:AddLine("Only rated duels are included in this record.", .60, .66, .74, true)
    end)

    OverviewTooltip(rightSlab, "Personal Best", function(r)
        GameTooltip:AddDoubleLine("Current rating", string.format("%.1f", r.rating or 0), .75, .78, .84, 1, 1, 1)
        GameTooltip:AddDoubleLine("Highest rating", string.format("%.1f", r.peak or r.rating or 0), .75, .78, .84, 1, .82, .42)
        local gap = math.max(0, (tonumber(r.peak) or 0) - (tonumber(r.rating) or 0))
        if gap > 0 then
            GameTooltip:AddDoubleLine("Below personal best", string.format("%.1f", gap), .65, .70, .76, 1, .70, .50)
        else
            GameTooltip:AddLine("You are currently at your personal best.", .40, .90, .68, true)
        end
    end)

    local duelProgressHover = CreateFrame("Frame", nil, duelPage)
    duelProgressHover:SetPoint("TOPLEFT", 38, -190); duelProgressHover:SetSize(124, 40)
    duelProgressHover:SetFrameLevel(duelPage:GetFrameLevel() + 8)
    OverviewTooltip(duelProgressHover, "Placement Duels", function(r)
        local placements = math.min(10, DP.Rating.PlacementCount(r))
        GameTooltip:AddDoubleLine("Completed", string.format("%d / 10", placements), .75, .78, .84, .47, .74, 1)
        GameTooltip:AddLine("Eligible rated duels count toward establishing your profile.", .60, .66, .74, true)
    end)

    local opponentProgressHover = CreateFrame("Frame", nil, duelPage)
    opponentProgressHover:SetPoint("TOPLEFT", 190, -190); opponentProgressHover:SetSize(124, 40)
    opponentProgressHover:SetFrameLevel(duelPage:GetFrameLevel() + 8)
    OverviewTooltip(opponentProgressHover, "Placement Opponents", function(r)
        GameTooltip:AddDoubleLine("Distinct opponents", string.format("%d / 5", math.min(5, r.distinct or 0)), .75, .78, .84, .90, .72, 1)
        GameTooltip:AddLine("Facing different players is required before Rivals marks the profile Established.", .60, .66, .74, true)
    end)

    local lastHover = CreateFrame("Frame", nil, duelPage)
    lastHover:SetPoint("TOPLEFT", 26, -304); lastHover:SetSize(300, 38)
    lastHover:SetFrameLevel(duelPage:GetFrameLevel() + 8)
    OverviewTooltip(lastHover, "Latest Duel", function(r)
        if r.last then
            local d = r.applied and r.applied[r.last.id] or nil
            GameTooltip:AddDoubleLine("Opponent", tostring(r.last.opponent or "Unknown"), .75, .78, .84, 1, 1, 1)
            GameTooltip:AddDoubleLine("Result", r.last.won and "Win" or "Loss", .75, .78, .84,
                r.last.won and .40 or 1, r.last.won and .90 or .45, r.last.won and .68 or .45)
            if d then
                GameTooltip:AddDoubleLine("Rating change", string.format("%+.2f", d.delta or 0), .75, .78, .84, 1, .82, .42)
                if DP.Views and DP.Views.Reason then GameTooltip:AddLine(DP.Views.Reason(d), .60, .66, .74, true) end
            end
        else
            GameTooltip:AddLine("No completed duel has been recorded yet.", .60, .66, .74, true)
        end
    end)

    local note = Text(-378, "GameFontDisableSmall")
    note:SetText("Local estimates from your recorded duels.\nEarlier diagnostic captures do not affect rating.")
    local button = DP.Theme.Button(duelPage, "Record details", 30, -395, 94)
    button:SetSize(94, 23)
    button:SetPoint("TOPLEFT", 30, -395)
    button:SetText("Record details")
    local function Details(self)
        local r = getRating()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("All recorded duels")
        for _, line in ipairs(DP.Views.ModeDetails(getRecords())) do GameTooltip:AddLine(line, 1, 1, 1) end
        GameTooltip:AddLine(string.format("All-duel streak: %d | Best win streak: %d", r.streak, r.longestWinStreak), 1, 1, 1)
        GameTooltip:AddLine(string.format("Placements: %d / 10; %d / 5 opponents", DP.Rating.PlacementCount(r), r.distinct), 1, 1, 1, true)
        GameTooltip:AddLine(DP.Views.MatchupSummary(r), 1, 1, 1, true); GameTooltip:Show()
    end
    button:SetScript("OnEnter", Details); button:SetScript("OnClick", function() GameTooltip:Hide(); DP.SelectDuelView("Details") end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local graphButton = DP.Theme.Button(duelPage, "Rating graph", 129, -395, 94)
    graphButton:SetSize(94, 23); graphButton:SetPoint("TOPLEFT", 129, -395); graphButton:SetText("Rating graph")
    graphButton:SetScript("OnClick", function() DP.SelectDuelView("Graph") end)
    local boardButton = DP.Theme.Button(duelPage, "Manage", 228, -395, 94)
    boardButton:SetSize(94, 23); boardButton:SetPoint("TOPLEFT", 228, -395); boardButton:SetText("Manage")
    boardButton:SetScript("OnClick", function() DP.SelectDuelView("Manage") end)
    local function DrawProgress(duels, opponents, glow)
        duelProgress:SetProgress(duels, false)
        rivalProgress:SetProgress(opponents, false)
        local text = tostring(math.floor(duels))
        progressText:SetText("|cff79bdff" .. text .. " / 10 duels|r")
        opponentProgress:SetText(string.format("|cffe5b9ff%d / 5 opponents|r", math.floor(opponents + .0001)))
        if glow and reveal then
            for index, row in ipairs({duelProgress, rivalProgress}) do
                local start = index == 1 and reveal.fromDuels or reveal.fromOpponents
                for i, slot in ipairs(row.slots) do
                    local age = glow - .35 - (i - start - 1) * .24
                    if i > start and slot.display == 1 and age >= 0 and age < .44 then
                        slot:Pop(age)
                    end
                end
            end
        end
    end
    local function StopReveal()
        duelPage:SetScript("OnUpdate", nil)
        reveal = nil
    end
    duelPage:SetScript("OnHide", function()
        StopReveal()
        promotion:Stop()
        for _, sweep in ipairs(panel.milestoneSweeps) do sweep:Stop() end
    end)
    overview:HookScript("OnHide", function()
        StopReveal()
        promotion:Stop()
        for _, sweep in ipairs(panel.milestoneSweeps) do sweep:Stop() end
    end)
    function DP.RefreshProgress()
        if not panel:IsShown() or not overview:IsShown() or not duelPage:IsShown() then StopReveal(); return end
        local state = getRating()
        if not state then return end
        local checkpoint = DP.ProgressCheckpoint and DP.ProgressCheckpoint() or fallbackCheckpoint
        if promotion.checkpoint and promotion.checkpoint ~= checkpoint then promotion:Stop() end
        local duels, opponents = math.min(10, DP.Rating.PlacementCount(state)), math.min(5, state.distinct)
        if not checkpoint.promotionSeen and duels >= 10 and opponents >= 5 and
            (checkpoint.duels < 10 or checkpoint.opponents < 5) then checkpoint.promotionPending = true end
        if reveal and reveal.checkpoint == checkpoint and reveal.duels == duels and reveal.opponents == opponents then return end
        StopReveal()
        local fromDuels, fromOpponents = math.floor(math.min(checkpoint.duels, duels)), math.floor(math.min(checkpoint.opponents, opponents))
        if fromDuels == duels and fromOpponents == opponents then
            checkpoint.duels, checkpoint.opponents = duels, opponents
            DrawProgress(duels, opponents); return
        end
        reveal = {checkpoint = checkpoint, fromDuels = fromDuels, fromOpponents = fromOpponents,
            duels = duels, opponents = opponents}
        DrawProgress(fromDuels, fromOpponents)
        local elapsed = 0
        local steps = math.max(duels - fromDuels, opponents - fromOpponents)
        local duration = .35 + math.max(0, steps - 1) * .24 + .44
        duelPage:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            local completed = elapsed < .35 and 0 or math.floor((elapsed - .35) / .24) + 1
            DrawProgress(math.min(duels, fromDuels + completed),
                math.min(opponents, fromOpponents + completed), elapsed)
            if elapsed >= duration then
                Celebrate(fromDuels < 10 and duels >= 10, fromOpponents < 5 and opponents >= 5)
                checkpoint.duels, checkpoint.opponents = duels, opponents
                DrawProgress(duels, opponents); StopReveal()
            end
        end)
    end
    panel.progressOverview = duelPage
    function DP.RefreshCharacterTab()
        local r = getRating()
        if not r then return end
        number:SetText(string.format("%.1f", r.rating))
        do
            local left = panel.numberFlourishLeft
            local right = panel.numberFlourishRight
            if left and right then
                local width = number.GetStringWidth and number:GetStringWidth() or 0
                local half = math.max(0, width * 0.5)
                local leftHalf = (left:GetWidth() or 0) * 0.5
                local rightHalf = (right:GetWidth() or 0) * 0.5
                local pad = 8
                local leftBias = 2
                local rightBias = 0
                local leftCenterOffset = half + leftHalf + pad - leftBias
                local rightCenterOffset = half + rightHalf + pad + rightBias
                left:ClearAllPoints()
                left:SetPoint("CENTER", number, "CENTER", -leftCenterOffset, -2)
                right:ClearAllPoints()
                right:SetPoint("CENTER", number, "CENTER", rightCenterOffset, -2)
            end
        end
        note:SetText("Local estimate • " .. (DP.DisplayPeriodName and DP.DisplayPeriodName() or "Lifetime"))
        placement:SetText(DP.Rating.Provisional(r) and "|cffffca67Provisional|r" or "|cff65e6adEstablished|r")
        local effective = math.min(10, DP.Rating.PlacementCount(r))
        local progress = string.format("%.2f", effective):gsub("0+$", ""):gsub("%.$", "")
        progressText:SetText("|cff79bdff" .. progress .. " / 10 duels|r")
        opponentProgress:SetText(string.format("|cffe5b9ff%d / 5 opponents|r", math.min(5, r.distinct)))
        local totals = DP.Views.RecordTotals(getRecords())
        local rated = totals.Rated
        stats:SetText(string.format("|cff65e6ad%d|r — |cffff8888%d|r\nRated record", rated.wins, rated.losses))
        peak:SetText(string.format("|cffffce70%.1f|r\nPersonal best", r.peak))
        if DP.HasActiveDuel and DP.HasActiveDuel() then
            last:SetText(DP.DuelAgreementStatus())
        elseif r.last then
            local d = r.applied[r.last.id]
            last:SetText(string.format("Last: %s vs %s\n%+.2f rating | %s", r.last.won and "Win" or "Loss",
                r.last.opponent, d.delta, r.last.modeFailure or (DP.Views.Mode(r.last) .. " | " .. DP.Views.Reason(d))))
        else last:SetText(DP.DuelAgreementStatus and DP.DuelAgreementStatus() or "Your next eligible duel starts your record.") end
        if DP.WorldPvP and DP.WorldPvP.RefreshOverview then DP.WorldPvP.RefreshOverview() end
        if DP.RefreshDuelViews then DP.RefreshDuelViews() end
    end
    if DP.WorldPvP and DP.WorldPvP.InstallOverview then DP.WorldPvP.InstallOverview(overview, duelPage) end
    DP.InstallViews(content, getRating, getRecords, overview)
    panel:SetScript("OnShow", function()
        SetTabSelected(true)
        DeselectNativeTabVisual()
        AlignCloseButtonToRivalsChrome()
        for _, texture in ipairs(panel.chrome) do texture:Show() end
        panel.logoFrame:Show()
        DP.RefreshCharacterTab()
        if panel.playOverviewSweepOnShow then
            panel.playOverviewSweepOnShow = nil
            local function PlayResetSweep()
                if not panel:IsShown() or not overview:IsShown() then return end
                local worldSelected = DP.WorldPvP and DP.WorldPvP.GetOverviewMode and DP.WorldPvP.GetOverviewMode() == "world"
                if worldSelected and DP.WorldPvP.PlayOverviewSweep then DP.WorldPvP.PlayOverviewSweep()
                elseif DP.PlayOverviewSweep then DP.PlayOverviewSweep() end
            end
            if C_Timer and C_Timer.After then C_Timer.After(.04, PlayResetSweep) else PlayResetSweep() end
        end
    end)
    tab = CreateFrame("Button", "RivalsCharacterTab", CharacterFrame, "CharacterFrameTabButtonTemplate")
    -- The stock CharacterFrameTabButtonTemplate squeezes its own FontString when
    -- the tab is selected so the text fits inside the inward-sloping/funnel art.
    -- That looks native, but on our compact standalone tab it turns Duels/WPvP
    -- into ellipses. Keep the native tab artwork and click behavior, but draw an
    -- addon-owned label over it so readability wins over the selected-tab funnel.
    tab:SetText("")
    tabLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabLabel:SetPoint("CENTER", tab, "CENTER", 0, 2)
    tabLabel:SetWidth(60)
    tabLabel:SetJustifyH("CENTER")
    if tabLabel.SetWordWrap then tabLabel:SetWordWrap(false) end
    tabLabel:SetText("Duels")
    tab.rivalsLabel = tabLabel
    UpdateTabLabelColor(false)

    tab:SetScript("OnClick", function()
        if DP.ShowRivalsCharacterPanel then DP.ShowRivalsCharacterPanel() end
    end)
    tab:SetScript("OnEnter", function()
        tabHovered = true
        UpdateTabLabelColor(panel:IsShown())
        GameTooltip:SetOwner(tab, "ANCHOR_RIGHT")
        GameTooltip:SetText("Duel rating, World PvP, and rivalry record")
    end)
    tab:SetScript("OnLeave", function()
        tabHovered = false
        UpdateTabLabelColor(panel:IsShown())
        GameTooltip:Hide()
    end)

    -- Keep the independent Rivals button visually in Blizzard's native tab row
    -- without registering it as CharacterFrameTab6.  Classic tabs overlap their
    -- neighbors by 15px; matching that geometry is more reliable than anchoring
    -- from CharacterFrame's right edge because the tab artwork extends beyond
    -- the button's logical bounds. Keep the compact 64px geometry; the separate
    -- overlay FontString above is what guarantees Duels/WPvP remain fully readable.
    local RIVALS_TAB_WIDTH = 64
    local RIVALS_TAB_OVERLAP = -15

    local function RightmostVisibleNativeTab()
        local best, bestRight
        local fallback
        local count = (CharacterFrame and CharacterFrame.numTabs) or 5
        for i = 1, count do
            local native = _G["CharacterFrameTab" .. i]
            if native and native ~= tab and (not native.IsShown or native:IsShown()) then
                -- On the first CharacterFrame show after /reload, Blizzard may not
                -- have assigned screen coordinates to every native tab yet. Keep
                -- the highest-index visible tab as a deterministic fallback so
                -- Rivals lands after Honor instead of temporarily stacking over it.
                fallback = native
                local right = native.GetRight and native:GetRight() or nil
                if right and (not bestRight or right > bestRight) then
                    best, bestRight = native, right
                end
            end
        end
        return best or fallback or CharacterFrameTab5 or CharacterFrameTab4 or CharacterFrameTab1
    end

    local function LayoutRivalsTab()
        if PanelTemplates_TabResize then
            PanelTemplates_TabResize(tab, 0, RIVALS_TAB_WIDTH)
        elseif tab.SetWidth then
            tab:SetWidth(RIVALS_TAB_WIDTH)
        end
        if tab.ClearAllPoints then tab:ClearAllPoints() end

        local native = RightmostVisibleNativeTab()
        if native then
            tab:SetPoint("LEFT", native, "RIGHT", RIVALS_TAB_OVERLAP, 0)
        else
            tab:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -30, -30)
        end
    end
    -- CharacterFrameTabButtonTemplate is born in its selected/funnel state.
    -- Because Rivals is deliberately *not* registered in CharacterFrame.numTabs,
    -- Blizzard never performs the initial deselect for us. Explicitly establish
    -- the correct visual state before the button is first shown; otherwise a
    -- fresh /reload makes the inactive Rivals tab look selected until the user
    -- visits Rivals once.
    LayoutRivalsTab()
    SetTabSelected(false)
    tab:SetScript("OnShow", function()
        LayoutRivalsTab()
        SetTabSelected(panel:IsShown())
        -- Child OnShow can run before Blizzard finishes laying out the native
        -- CharacterFrame tabs. Recheck once on the next frame so real coordinates
        -- replace the index fallback as soon as they are available.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if tab and tab.IsShown and tab:IsShown() then LayoutRivalsTab() end
            end)
        end
    end)

    -- Blizzard still owns CharacterFrame.selectedTab.  While Rivals is shown we
    -- visually deselect (and therefore re-enable) that *existing* native tab so
    -- it keeps normal hover/click behavior.  We never create a CharacterFrameTab6,
    -- change selectedTab, or insert Rivals into Blizzard's tab registry.
    local nativeStateEvents = CreateFrame("Frame", nil, CharacterFrame)
    if nativeStateEvents.RegisterEvent then
        nativeStateEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
        nativeStateEvents:SetScript("OnEvent", function()
            if pendingNativeRestore and not panel:IsShown() then RestoreNativeTabVisual() end
        end)
    end

    local function CombatBlocked()
        local message = "Rivals: open the Character pane before entering combat to use the Rivals tab."
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cffd0a45c" .. message .. "|r")
        end
    end

    local function HideNativeCharacterSubframes()
        if not CHARACTERFRAME_SUBFRAMES then return end
        for _, frameName in ipairs(CHARACTERFRAME_SUBFRAMES) do
            local frame = _G[frameName]
            if frame and frame.Hide then frame:Hide() end
        end
    end

    function DP.HideRivalsCharacterPanel()
        if panel:IsShown() then panel:Hide() end
        SetTabSelected(false)
    end

    function DP.ShowRivalsCharacterPanel()
        local inCombat = InCombatLockdown and InCombatLockdown()
        -- Opening CharacterFrame itself from addon code is the protected action
        -- that must stay out of combat. If the user already has CharacterFrame
        -- open (which is necessarily true when they can click this attached tab),
        -- switching to our addon-owned panel does not need ToggleCharacter() or
        -- ShowUIPanel(), so the Rivals tab can remain usable during combat.
        if not CharacterFrame:IsShown() then
            if inCombat then
                CombatBlocked()
                return false
            end
            if ToggleCharacter then
                ToggleCharacter("PaperDollFrame", true)
            elseif ShowUIPanel then
                ShowUIPanel(CharacterFrame)
            elseif CharacterFrame.Show then
                CharacterFrame:Show()
            end
        end
        -- These are the already-visible native content panes, not the protected
        -- UIPanel container. Hiding them avoids double-rendering underneath the
        -- Rivals overlay while leaving CharacterFrame.selectedTab and Blizzard's
        -- tab registry untouched.
        HideNativeCharacterSubframes()
        LayoutRivalsTab()
        panel:Show()
        SetTabSelected(true)
        return true
    end

    function DP.ToggleRivalsCharacterPanel()
        local rivalsVisible = panel:IsShown() and CharacterFrame and CharacterFrame:IsShown()
        if rivalsVisible then
            DP.HideRivalsCharacterPanel()
            if not (InCombatLockdown and InCombatLockdown()) then
                if HideUIPanel then HideUIPanel(CharacterFrame)
                elseif CharacterFrame.Hide then CharacterFrame:Hide() end
            elseif PaperDollFrame and PaperDollFrame.Show then
                PaperDollFrame:Show()
            end
            return false
        end
        return DP.ShowRivalsCharacterPanel()
    end

    -- Native tab/subframe switches should dismiss the Rivals overlay, but the
    -- secure Blizzard function itself remains untouched. hooksecurefunc executes
    -- our post-hook without tainting CharacterFrame_ShowSubFrame.
    if hooksecurefunc and CharacterFrame_ShowSubFrame then
        hooksecurefunc("CharacterFrame_ShowSubFrame", function()
            if panel:IsShown() then panel:Hide() end
        end)
    end
    function DP.RefreshRivalsCharacterTabLabel()
        local world = DP.WorldPvP and DP.WorldPvP.GetOverviewMode and DP.WorldPvP.GetOverviewMode() == "world"
        local label = world and "WPvP" or "Duels"
        if tabLabel and tabLabel:GetText() ~= label then tabLabel:SetText(label) end
        -- Keep the template's built-in text empty; PanelTemplates_SelectTab may
        -- otherwise reapply its narrow selected-state text region.
        if tab:GetText() ~= "" then tab:SetText("") end
        LayoutRivalsTab()
    end
    DP.characterPanel = panel
    InstallCharacterStatsCompatibility(panel)
    DP.RefreshRivalsCharacterTabLabel()
    return true
end
