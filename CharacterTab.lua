local _, DP = ...

function DP.InstallCharacterTab(getRating, getRecords)
    if DP.characterPanel or not CharacterFrame or not CharacterFrameTab5 then return false end
    local id = (CharacterFrame.numTabs or 5) + 1
    while _G["CharacterFrameTab" .. id] do id = id + 1 end
    local panel = CreateFrame("Frame", "RivalsCharacterPanel", CharacterFrame)
    panel:SetAllPoints(CharacterFrame)
    panel:SetID(id)
    panel:Hide()
    -- Classic's window chrome belongs to the selected subframe. Keep our copy
    -- on CharacterFrame's BORDER layer: the portrait is BACKGROUND and must
    -- sit under its circular rim; the native title remains on its child frame.
    panel.chrome = {}
    for _, part in ipairs({{"TopLeft", 256, 0, 0}, {"TopRight", 128, 256, 0},
        {"BottomLeft", 256, 0, -256}, {"BottomRight", 128, 256, -256}}) do
        local texture = CharacterFrame:CreateTexture(nil, "BORDER")
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
    local portraitPoints, closePoints
    local function RestoreCloseButton()
        if not closePoints or not CharacterFrameCloseButton then return end
        CharacterFrameCloseButton:ClearAllPoints()
        for _, point in ipairs(closePoints) do CharacterFrameCloseButton:SetPoint(unpack(point)) end
        closePoints = nil
    end
    local function RestorePortrait()
        if not portraitPoints or not CharacterFramePortrait then return end
        CharacterFramePortrait:ClearAllPoints()
        for _, point in ipairs(portraitPoints) do CharacterFramePortrait:SetPoint(unpack(point)) end
        portraitPoints = nil
    end
    panel:SetScript("OnHide", function()
        RestorePortrait()
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
        local close = CharacterFrameCloseButton
        if close and close.GetNumPoints and not closePoints then
            closePoints = {}
            for i = 1, close:GetNumPoints() do closePoints[i] = {close:GetPoint(i)} end
            close:ClearAllPoints()
            for _, point in ipairs(closePoints) do
                close:SetPoint(point[1], point[2], point[3], (point[4] or 0) - 2, point[5] or 0)
            end
        end
        if CharacterFramePortrait and not portraitPoints then
            portraitPoints = {}
            for i = 1, CharacterFramePortrait:GetNumPoints() do
                portraitPoints[i] = {CharacterFramePortrait:GetPoint(i)}
            end
            CharacterFramePortrait:ClearAllPoints()
            CharacterFramePortrait:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 8, -7)
        end
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
    CHARACTERFRAME_SUBFRAMES[#CHARACTERFRAME_SUBFRAMES + 1] = "RivalsCharacterPanel"
    local tab = CreateFrame("Button", "CharacterFrameTab" .. id, CharacterFrame, "CharacterFrameTabButtonTemplate")
    tab:SetID(id)
    tab:SetText("Duels")
    tab:SetScript("OnClick", function() ToggleCharacter("RivalsCharacterPanel", true) end)
    tab:SetScript("OnEnter", function()
        GameTooltip:SetOwner(tab, "ANCHOR_RIGHT")
        GameTooltip:SetText("Duel rating, World PvP, and rivalry record")
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PanelTemplates_SetNumTabs(CharacterFrame, id)
    PanelTemplates_TabResize(tab, 0)
    local layingOut = false
    local function Layout()
        if layingOut then return end
        layingOut = true
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", CharacterFrameTab5:IsShown() and CharacterFrameTab5 or CharacterFrameTab4, "RIGHT", -16, 0)
        local right, left, edge = tab:GetRight(), CharacterFrameTab1:GetLeft(), CharacterFrameCloseButton:GetRight()
        if right and left and edge and right > edge then
            local visible = {}
            for i = 1, id do
                local candidate = _G["CharacterFrameTab" .. i]
                if candidate and candidate:IsShown() then visible[#visible + 1] = candidate end
            end
            local width = math.max(42, (edge - left + 16 * (#visible - 1)) / #visible)
            for _, candidate in ipairs(visible) do PanelTemplates_TabResize(candidate, 0, nil, nil, width) end
        end
        layingOut = false
    end
    function DP.RefreshRivalsCharacterTabLabel()
        local world = DP.WorldPvP and DP.WorldPvP.GetOverviewMode and DP.WorldPvP.GetOverviewMode() == "world"
        local label = world and "WPvP" or "Duels"
        if tab:GetText() ~= label then tab:SetText(label) end
        PanelTemplates_TabResize(tab, 0)
        Layout()
    end
    hooksecurefunc("CharacterFrame_TabBoundsCheck", Layout)
    CharacterFrame:HookScript("OnShow", Layout)
    DP.characterPanel = panel
    DP.RefreshRivalsCharacterTabLabel()
    return true
end
