-- Contract test of CharacterFrame integration; does not validate rendered appearance.
local originalCreate = CreateFrame
function CreateFrame(kind, name, parent, template)
    local f = originalCreate()
    f.visible = true
    function f:SetAllPoints() end
    function f:SetFrameStrata() end
    function f:GetFrameLevel() return self.frameLevel or 1 end
    function f:SetFrameLevel(level) self.frameLevel = level end
    function f:SetVertexColor(...) self.vertexColor = {...} end
    function f:SetTextColor(...) self.textColor = {...} end
    function f:SetFontString() end
    function f:CreateAnimationGroup()
        local group = {animations = {}, playCount = 0}
        function group:CreateAnimation(kind)
            local anim = {kind = kind}
            for _, key in ipairs({"Order", "Duration", "StartDelay", "Origin", "ScaleFrom", "ScaleTo", "Smoothing", "Offset"}) do
                anim["Set" .. key] = function(self, ...) self[key] = {...} end
            end
            self.animations[#self.animations + 1] = anim
            return anim
        end
        function group:Play() self.playing = true; self.playCount = self.playCount + 1 end
        function group:Stop() self.playing = false end
        return group
    end
    function f:GetStringWidth() return #(self.text or "") * 5 end
    function f:SetScale(scale) self.scale = scale end
    function f:GetFont() return "Fonts/FRIZQT__.TTF", 10, "" end
    function f:SetFont(font, size, flags) self.fontSize = size end
    function f:SetParent(parent) self.parent = parent end
    function f:EnableMouseWheel() end
    function f:SetValueStep() end
    function f:SetOrientation() end
    function f:SetThumbTexture() end
    function f:SetMinMaxValues(a, b) self.min, self.max = a, b end
    function f:SetValue(value) self.value = value; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end end
    function f:SetID(id) self.id = id end
    function f:GetID() return self.id end
    function f:Hide()
        local wasShown = self.visible
        self.visible = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:Show() self.visible = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:IsShown() return self.visible end
    function f:CreateTexture()
        self.textures = self.textures or {}
        local texture = CreateFrame()
        self.textures[#self.textures + 1] = texture
        return texture
    end
    function f:CreateFontString() return CreateFrame() end
    function f:CreateLine() return CreateFrame() end
    function f:SetThickness() end
    function f:SetStartPoint() end
    function f:SetEndPoint() end
    function f:SetTexture() end
    function f:CreateMaskTexture() return CreateFrame() end
    function f:AddMaskTexture(mask) self.mask = mask end
    function f:SetDrawLayer(layer, sublevel) self.drawLayer, self.sublevel = layer, sublevel end
    function f:SetBlendMode(mode) self.blendMode = mode end
    function f:SetAlpha(alpha) self.alpha = alpha end
    function f:SetTexCoord() end
    function f:EnableMouse() end
    function f:SetPushedTexture() end
    function f:SetButtonState(state) self.buttonState = state end
    function f:SetColorTexture() end
    function f:SetJustifyH() end
    function f:SetJustifyV() end
    function f:SetSize(width, height) self.width, self.height = width, height end
    function f:SetWidth(width) self.width = width end
    function f:GetWidth() return self.width or 0 end
    function f:GetHeight() return self.height or 0 end
    function f:SetHeight(height) self.height = height end
    function f:SetPushedTextOffset(x, y) self.pushedTextOffset = {x, y} end
    function f:SetWordWrap() end
    function f:SetHighlightTexture() end
    function f:SetEnabled(value) self.enabled = value end
    function f:SetShown(value) self.visible = value end
    function f:ClearAllPoints() end
    function f:SetPoint(...) self.point = {...} end
    function f:GetRight() return 300 end
    function f:GetLeft() return 0 end
    function f:HookScript(key, fn) self.scripts[key] = fn end
    if name then _G[name] = f end
    return f
end
CharacterFrame = CreateFrame(); CharacterFrame.numTabs = 5
CharacterFrameCloseButton = CreateFrame()
CHARACTERFRAME_SUBFRAMES = {"PaperDollFrame", "PetPaperDollFrame", "ReputationFrame", "SkillFrame", "HonorFrame"}
for i, name in ipairs(CHARACTERFRAME_SUBFRAMES) do
    CreateFrame("Frame", name)
    CreateFrame("Button", "CharacterFrameTab" .. i)
end
function PanelTemplates_SetNumTabs(frame, n) frame.numTabs = n end
function PanelTemplates_TabResize() end
function ToggleCharacter(name)
    for _, sub in ipairs(CHARACTERFRAME_SUBFRAMES) do _G[sub]:Hide() end
    _G[name]:Show()
end
local state = DP.Rating.New()
local journal = {}
assert(DP.InstallCharacterTab(function() return state end, function() return journal end))
assert(CharacterFrame.numTabs == 6)
assert(CharacterFrameTab6.point[2] == CharacterFrameTab5)
assert(CharacterFrameTab6.text == "Duels")
CharacterFrameTab6.scripts.OnClick()
assert(RivalsCharacterPanel:IsShown() and not HonorFrame:IsShown())
assert(#RivalsCharacterPanel.chrome == 4) -- One complete, matching frame texture set.
assert(RivalsCharacterPanel.logo and RivalsCharacterPanel.logo:IsShown())
assert(not RivalsCharacterPanel.logo.mask and RivalsCharacterPanel.logo.blendMode == "BLEND")
for _, texture in ipairs(RivalsCharacterPanel.chrome) do assert(texture:IsShown()) end
ToggleCharacter("HonorFrame")
assert(HonorFrame:IsShown() and not RivalsCharacterPanel:IsShown())
for _, texture in ipairs(RivalsCharacterPanel.chrome) do assert(not texture:IsShown()) end
assert(not RivalsCharacterPanel.logoFrame:IsShown())
assert(not DP.InstallCharacterTab(function() return state end, function() end))
print("PASS: Duels tab follows Honor; native subframe switching and installation idempotency")

for i = 1, 12 do
    local r = {id = i, modelVersion = 1, timestamp = 1800000000 + i, won = i % 2 == 0,
        duration = 5, durationQuality = "estimated", opponent = "Bob", status = "matched-request-history-only",
        session = {estimatedStartAt = 1, identity = {guid = "Bob", name = "Bob", class = "MAGE"}}}
    journal[#journal + 1] = r
    DP.Rating.Apply(state, r)
end
DP.SelectDuelView("History")
local controls = DP.duelViewControls
assert(controls.nav.Matchups.text == "Matchups" and controls.nav.Rivals.text == "Rivals")
assert(not controls.nav.Classes and not controls.nav.Opponents)
assert(controls.historySource.selectedValue == "all" and controls.historySource.text:find("All encounters", 1, true))
-- The remaining legacy History assertions exercise Duel-only rows explicitly.
DP.SetHistorySource("duels")
assert(controls.page.text == "12 records")
assert(controls.rows[1].tipTitle == "Win vs Bob")
controls.body.scripts.OnMouseWheel(nil, -1)
assert(controls.scrollbar.value == 1 and controls.rows[1].tipTitle == "Loss vs Bob")
controls.scrollbar:SetValue(7)
assert(controls.rows[5].visible and not controls.nextPage.visible)
DP.SelectDuelView("Opponents")
assert(controls.rows[1].first.text == "Bob")
controls.rows[1].scripts.OnClick(controls.rows[1])
assert(controls.clear.visible and controls.page.text == "12 records")
assert(controls.nav.Matchups.selection.visible and not controls.nav.History.selection.visible)
controls.clear.scripts.OnClick()
assert(not controls.clear.visible and controls.nav.Matchups.selection.visible)
DP.SelectDuelView("Classes")
assert(controls.rows[1].first.text == "MAGE" and controls.rows[1].amount.text:find("Unrated"))
controls.rows[1].scripts.OnClick(controls.rows[1])
assert(controls.page.text == "12 records")
assert(DP.Views.Count(1, "loss", "losses") == "1 loss")
local data = DP.Views.Build({{id = 999}, journal[1]}, state)
assert(#data.History == 1 and #data.byOpponent.Bob == 1)
assert(data.Classes[1].distinct == 1)
print("PASS: paging, opponent/class history filters, diagnostic exclusion and singular labels")
DP.SelectDuelView("Graph")
DP.SelectDuelView("Overview")
print("PASS: graph construction and view switching")

local function outcome(version, mode, reason, won)
    return {modelVersion = version, duelMode = mode, modeReason = reason, won = won, status = "matched-request-history-only"}
end
local totals = DP.Views.RecordTotals({outcome(1, nil, nil, true), outcome(2, nil, nil, false),
    outcome(3, "rated", nil, true), outcome(3, "casual", "Casual preference", false),
    outcome(3, "casual", "Rated agreement not completed before start", true), {modelVersion = 3}})
assert(totals.Rated.wins == 1 and totals.Rated.losses == 0)
assert(totals.Casual.losses == 1 and totals["Unconfirmed"].wins == 1)
assert(totals.Legacy.wins == 1 and totals.Legacy.losses == 1)
assert(DP.Views.PlacementProgress({effective = 13.5, distinct = 4}) == "Need 0 placement duels; 1 new opponent")
assert(DP.Views.PlacementProgress({effective = 10, distinct = 5}) == "Placements complete")
DP.SelectDuelView("History")
assert(controls.rows[1].first.text == "Bob" and controls.rows[1].amount.text ~= "")
print("PASS: separate mode totals, legacy preservation, history labels and placement deficits")
local mixed = {outcome(1, nil, nil, true), outcome(3, "rated", nil, true), outcome(3, "casual", "Casual preference", false)}
assert(#DP.Views.FilterHistory(mixed, "All") == 3)
assert(DP.Views.FilterHistory(mixed, "Rated")[1] == mixed[2])
assert(#DP.Views.FilterHistory(mixed, "Unconfirmed") == 0)
controls.nextPage.scripts.OnClick()
controls.historyMode.scripts.OnClick() -- Rated: no eligible rows in this legacy fixture.
assert(controls.page.text == "0 records" and not controls.rows[1].visible)
DP.SelectDuelView("Opponents")
assert(table.concat(controls.rows[1].tipLines, " "):find("Rated  |cff65e6ad0 W|r  |cffff88880 L|r", 1, true))
controls.rows[1].scripts.OnClick(controls.rows[1])
assert(controls.clear.visible and controls.page.text == "0 records")
for i = 1, 4 do controls.historyMode.scripts.OnClick() end
assert(controls.page.text == "12 records")
DP.SelectDuelView("Overview")
print("PASS: history mode filtering, pagination reset and opponent filter composition")
local owner = RivalsDB.observers["Player-1-A"]
local report = {token = "1800000000-701", peerToken = "1800000000-702", guid = "Player-1-C", name = "Recovered-Realm",
    status = "Peer-reported", winner = "Player-1-C", won = false, mode = "rated", timestamp = time() - 1, outcome = "knockout"}
owner.interrupted[#owner.interrupted + 1] = report
local priorCount = #owner.results
DP.ReviewRecovery(report)
assert(DP.recoveryReview:IsShown() and #owner.results == priorCount)
DP.recoveryReview.apply.scripts.OnClick()
assert(#owner.results == priorCount + 1 and report.appliedId)
assert(not DP.recoveryReview:IsShown())
DP.ReviewRecovery(report)
assert(#owner.results == priorCount + 1)
print("PASS: review window previews without mutation, applies once and rejects repeat acceptance")
local acceptedReports = DP.AcceptedRecoveryItems()
assert(#acceptedReports == 1)
local sequence = owner.nextSequence
DP.SelectDuelView("Accepted")
assert(DP.duelViewControls.rows[1].second.text:find("Accepted:"))
DP.ReviewRecovery(acceptedReports[1], true)
assert(#owner.results == priorCount + 1)
DP.recoveryReview.apply.scripts.OnClick()
assert(#owner.results == priorCount and owner.nextSequence == sequence and not report.appliedId)
assert(#DP.AcceptedRecoveryItems() == 0)
assert(owner.recoveryAudit[#owner.recoveryAudit].action == "undo")
DP.ReviewRecovery(report)
DP.recoveryReview.apply.scripts.OnClick()
assert(#owner.results == priorCount + 1 and owner.nextSequence == sequence + 1)
assert(owner.recoveryAudit[#owner.recoveryAudit].action == "accept")
print("PASS: undo preview, report restoration, monotonic IDs, reacceptance and audit history")

-- Layout contracts for the reported overlap/navigation regressions.
for _, texture in ipairs(RivalsCharacterPanel.textures or {}) do
    if texture ~= RivalsCharacterPanel.logo then
        assert(texture.point[3] <= -74, "Custom background must stay below the native header")
    end
end
DP.SelectDuelView("Manage")
assert(controls.manage.visible and not controls.period.visible and controls.nav.Overview.selection.visible)
assert(controls.shareOn.selection.visible and not controls.shareOff.selection.visible)
controls.shareOff.scripts.OnClick(); assert(controls.shareOff.selection.visible and not controls.shareOn.selection.visible)
controls.shareOn.scripts.OnClick(); assert(controls.shareOn.selection.visible)
controls.recoveryOpen.scripts.OnClick()
assert(controls.manageBack.visible and not controls.period.visible)
assert(controls.empty.point[3] < -190)
controls.manageBack.scripts.OnClick()
assert(controls.manage.visible and controls.nav.Overview.selection.visible)
controls.manageOverviewBack.scripts.OnClick()
assert(controls.nav.Overview.selection.visible and controls.nav.Overview.enabled)
DP.SelectDuelView("Details")
assert(controls.details.visible)
controls.detailsBack.scripts.OnClick()
assert(not controls.details.visible)
DP.SelectDuelView("Graph")
controls.graphBack.scripts.OnClick()
assert(controls.nav.Overview.selection.visible and controls.nav.Overview.enabled)
DP.SelectDuelView("History")
assert(controls.period.point[3] == -104 and controls.empty.point[3] < -160)
local savedColors = RAID_CLASS_COLORS
RAID_CLASS_COLORS = {MAGE = {r = .25, g = .75, b = 1}}
DP.SelectDuelView("Opponents")
assert(controls.rows[1].first.text == "|cff40bfffBob|r")
DP.SelectDuelView("Classes")
assert(controls.rows[1].first.text == "|cff40bfffMAGE|r")
RAID_CLASS_COLORS = savedColors
DP.SelectDuelView("Overview")
print("PASS: header exclusion, filter spacing, Overview return paths and known-class colors")

DP.SelectDuelView("Interrupted")
assert(controls.manageBack.point[3] == controls.graphBack.point[3])
assert(controls.manageBack.point[3] == controls.detailsBack.point[3])
controls.nav.History.buttonState = "PUSHED"
controls.nav.History.scripts.OnClick()
assert(controls.nav.History.buttonState == "NORMAL" and controls.nav.History.enabled)
assert(controls.nav.History.selection.visible)
controls.nav.History.scripts.OnClick()
assert(controls.nav.History.buttonState == "NORMAL")
DP.SelectDuelView("Overview")
print("PASS: navigation marks selection without locking the pressed state and Manage shares the back-button row")

DP.WorldPvP.SetOverviewMode("world", true)
controls.nav.Matchups.scripts.OnClick()
assert(controls.matchupSource.selectedValue == "world")
assert(controls.nav.Matchups.buttonState == "NORMAL")
-- Local Matchups source changes remain stable while switching Opponents/Classes.
controls.matchupSource:SelectValue("duels")
DP.WorldPvP.SetOverviewMode("duels", true)
assert(controls.nav.History.buttonState == "NORMAL")
controls.classes.scripts.OnClick()
assert(controls.classes.selected and not controls.matchups.selected)
controls.matchups.scripts.OnClick()
assert(controls.matchups.selected and not controls.classes.selected)
assert(controls.matchups.point[2] + controls.matchups.width == controls.classes.point[2])
assert(controls.period.isDropdown and controls.historyMode.isDropdown)
DP.SelectDuelView("History"); local historyPeriodY = controls.period.point[3]
DP.SelectDuelView("Opponents"); assert(controls.period.point[3] == historyPeriodY)
DP.SelectDuelView("Classes"); assert(controls.period.point[3] == historyPeriodY)
DP.SelectDuelView("Overview")

assert(controls.nav.Overview.pushedTextOffset[1] == 1 and controls.nav.Overview.pushedTextOffset[2] == -1)
assert(RivalsCharacterPanel.chrome[1].point[2] == 0 and RivalsCharacterPanel.chrome[1].point[3] == 0)

assert(controls.nav.Overview.selection.visible and controls.nav.Overview.text:find("ffffce70"))
assert(not controls.nav.History.selection.visible and controls.nav.History.text == "History")

local recent = DP.Views.Build({
    {modelVersion = 3, status = "matched-request-history-only", timestamp = 1, opponent = "Old", session = {identity = {guid = "old", class = "MAGE"}}},
    {modelVersion = 3, status = "matched-request-history-only", timestamp = 20, opponent = "New", session = {identity = {guid = "new", class = "WARRIOR"}}}
}, {opponents = {old = {name = "Old", lastAt = 1, wins = 99, losses = 0}, new = {name = "New", lastAt = 20, wins = 1, losses = 0}}, classes = {MAGE = {}, WARRIOR = {}}})
assert(recent.Opponents[1].key == "new" and recent.Classes[1].key == "WARRIOR")
print("PASS: opponent and class matchups sort by recency before volume")

assert(DP.Views.RatingChange(1500, 1508.25):find("(+8.25)", 1, true))
assert(DP.Views.RatingChange(1500, 1491):find("(-9.00)", 1, true))
assert(DP.Views.RatingChange(1500, 1500):find("(+0.00)", 1, true))

local blips = DP.Theme.ProgressRow(CreateFrame(), 10, 101, -213, {.2, .6, 1})
blips:SetProgress(0, false)
assert(not blips.slots[1].fill.visible)
blips:SetProgress(1.5, true)
assert(blips.slots[1].scripts.OnUpdate and blips.slots[2].scripts.OnUpdate)
blips.slots[1].scripts.OnUpdate(blips.slots[1], .6)
blips.slots[2].scripts.OnUpdate(blips.slots[2], .6)
assert(blips.slots[1].display == 1 and blips.slots[2].display == .5)
assert(not blips.slots[1].scripts.OnUpdate)
blips:SetProgress(1.5, true)
assert(not blips.slots[1].scripts.OnUpdate)
blips:SetProgress(0, false)
assert(not blips.slots[1].fill.visible)
local rivals = DP.Theme.ProgressRow(CreateFrame(), 5, 249.5, -213, {.7, .4, 1})
assert(blips.span == rivals.span and blips.slotHeight == rivals.slotHeight)
assert(rivals.slotWidth > blips.slotWidth)
assert(blips.slots[2].point[2] - blips.slotWidth == rivals.slots[2].point[2] - rivals.slotWidth)
print("PASS: equal-span progress rows, fractional fill, animation completion and no replay on refresh")

local oldCheckpoint = DP.ProgressCheckpoint
local checkpoint = {duels = 1, opponents = 1}
DP.ProgressCheckpoint = function() return checkpoint end
local oldEffective, oldDistinct, oldPlacements = state.effective, state.distinct, state.placements
state.effective, state.distinct, state.placements = 3.5, 3, 4
RivalsCharacterPanel:Hide()
DP.RefreshCharacterTab()
assert(checkpoint.duels == 1 and checkpoint.opponents == 1)
assert(not RivalsCharacterPanel.progressOverview.scripts.OnUpdate)
RivalsCharacterPanel:Show()
DP.SelectDuelView("Overview")
local screen = RivalsCharacterPanel.progressOverview
assert(screen.scripts.OnUpdate)
screen.scripts.OnUpdate(screen, .2)
assert(RivalsCharacterPanel.progressRows[1].slots[2].display == 0)
screen.scripts.OnUpdate(screen, .16)
assert(RivalsCharacterPanel.progressRows[1].slots[2].display == 1)
assert(RivalsCharacterPanel.progressRows[1].slots[3].display == 0)
screen.scripts.OnUpdate(screen, .24)
assert(RivalsCharacterPanel.progressRows[1].slots[3].display == 1)
assert(RivalsCharacterPanel.progressRows[1].slots[4].display == 0)
assert(checkpoint.duels == 1)
DP.SelectDuelView("History")
assert(not screen.scripts.OnUpdate and checkpoint.duels == 1)
DP.SelectDuelView("Overview")
assert(screen.scripts.OnUpdate)
screen.scripts.OnUpdate(screen, 10)
assert(checkpoint.duels == 4 and checkpoint.opponents == 3)
assert(not screen.scripts.OnUpdate)
DP.RefreshCharacterTab()
assert(not screen.scripts.OnUpdate)
DP.ProgressCheckpoint = oldCheckpoint
state.effective, state.distinct, state.placements = oldEffective, oldDistinct, oldPlacements
print("PASS: hidden gains queue, delayed catch-up, interrupted reveal retries and completed gains stay viewed")

local savedCheckpoint = DP.ProgressCheckpoint
local savedPlacements, savedDistinct = state.placements, state.distinct
local milestoneCheckpoint = {duels = 9, opponents = 4}
DP.ProgressCheckpoint = function() return milestoneCheckpoint end
local sweeps = RivalsCharacterPanel.milestoneSweeps
assert(#sweeps == 3)
for _, sweep in ipairs(sweeps) do sweep:Stop() end
state.placements, state.distinct = 10, 4
DP.RefreshProgress(); screen.scripts.OnUpdate(screen, 10)
assert(sweeps[1].scripts.OnUpdate and not sweeps[2].scripts.OnUpdate)
sweeps[1].scripts.OnUpdate(sweeps[1], .5)
local visibleBands = 0
for _, band in ipairs(sweeps[1].bands) do
    if band.visible then visibleBands = visibleBands + 1 end
end
assert(visibleBands > 0)
for i, band in ipairs(sweeps[1].bands) do
    assert(band == RivalsCharacterPanel.progressRows[1].slots[i].flash)
end
sweeps[1].scripts.OnUpdate(sweeps[1], 2)
assert(not sweeps[1].scripts.OnUpdate)
state.distinct = 5
DP.RefreshProgress(); screen.scripts.OnUpdate(screen, 10)
assert(not sweeps[1].scripts.OnUpdate and sweeps[2].scripts.OnUpdate and not sweeps[3].scripts.OnUpdate)
for _, sweep in ipairs(sweeps) do sweep:Stop() end
DP.RefreshProgress()
assert(not screen.scripts.OnUpdate and not sweeps[3].scripts.OnUpdate)
RivalsCharacterPanel.establishedPromotion:Play(0)
assert(state.placements == 10 and state.distinct == 5 and milestoneCheckpoint.duels == 10 and milestoneCheckpoint.opponents == 5)
assert(RivalsCharacterPanel.devMilestoneButton == nil)
assert(RivalsCharacterPanel.establishedPromotion.scripts.OnUpdate)
DP.SelectDuelView("History")
for _, sweep in ipairs(sweeps) do assert(not sweep.scripts.OnUpdate) end
DP.ProgressCheckpoint = savedCheckpoint
state.placements, state.distinct = savedPlacements, savedDistinct
DP.SelectDuelView("Overview")
assert(sweeps[3].scripts.OnUpdate) -- Returning to Overview replays only the card.
assert(not sweeps[1].scripts.OnUpdate and not sweeps[2].scripts.OnUpdate)
sweeps[3]:Stop()
DP.SelectDuelView("Overview")
assert(sweeps[3].scripts.OnUpdate)
print("PASS: milestone thresholds, visible sweep, completion, no repeat, stat-safe dev preview and hide cleanup")
local caption = CreateFrame()
caption:SetText("|cff79bdff10 / 10 duels|r")
local originalCaption = caption:GetText()
local glyphSweep = DP.Theme.CompletionSweep(screen, blips, caption, {121/255, 189/255, 1})
glyphSweep:Play(0, .8)
glyphSweep.scripts.OnUpdate(glyphSweep, .4)
assert(caption:GetText() ~= originalCaption)
assert(caption:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") == "10 / 10 duels")
glyphSweep:Stop()
assert(caption:GetText() == originalCaption)
print("PASS: completion sweep uses existing blips and glyph colors, preserving caption text and restoring colors")

local promotion = RivalsCharacterPanel.establishedPromotion
local savedPromotionCheckpoint = DP.ProgressCheckpoint
local savedPromotionPlacements, savedPromotionDistinct = state.placements, state.distinct
local graduation = {duels = 10, opponents = 5, promotionPending = true}
DP.ProgressCheckpoint = function() return graduation end
state.placements, state.distinct = 10, 5
DP.SelectDuelView("Overview")
assert(promotion.checkpoint == graduation and promotion.scripts.OnUpdate)
promotion.scripts.OnUpdate(promotion, 1)
DP.SelectDuelView("History")
assert(not promotion.scripts.OnUpdate and not graduation.promotionSeen)
DP.SelectDuelView("Overview")
assert(promotion.scripts.OnUpdate)
promotion.scripts.OnUpdate(promotion, 10)
assert(graduation.promotionSeen and not graduation.promotionPending)
DP.SelectDuelView("Overview")
assert(not promotion.scripts.OnUpdate)
RivalsCharacterPanel.establishedPromotion:Play(0)
assert(promotion.scripts.OnUpdate and not promotion.checkpoint)
promotion.scripts.OnUpdate(promotion, 10)
assert(graduation.promotionSeen and state.placements == 10 and state.distinct == 5)
DP.ProgressCheckpoint = savedPromotionCheckpoint
state.placements, state.distinct = savedPromotionPlacements, savedPromotionDistinct
print("PASS: Established promotion retries after interruption, persists completion and dev preview leaves state untouched")

promotion:Play(0)
promotion.scripts.OnUpdate(promotion, .25)
assert(promotion.title:GetText() == "Provisional" and promotion.title.alpha == 1 and promotion.word.alpha == 0)
promotion.scripts.OnUpdate(promotion, .95)
assert(promotion.title:GetText() == "Established" and promotion.title.alpha == 0 and promotion.word.alpha == 1)
local enlarged = promotion.word.width
promotion.scripts.OnUpdate(promotion, .6)
local previous = promotion.word.width
for i = 1, 60 do
    promotion.scripts.OnUpdate(promotion, .02)
    assert(promotion.word.width <= previous + .00001)
    previous = promotion.word.width
    assert(promotion.motion.scale == nil)
end
assert(promotion.word.width < enlarged)
promotion.scripts.OnUpdate(promotion, .06)
assert(promotion.motion.point[4] == 0 and promotion.motion.point[5] == 0)
assert(#promotion.stars == 10)
for i, star in ipairs(promotion.stars) do
    assert(star.point[2] == promotion.motion and star.point[5] == 0)
end
assert(promotion.stars[1].point[4] < 0 and promotion.stars[5].point[4] == 0 and promotion.stars[9].point[4] > 0)
promotion.scripts.OnUpdate(promotion, .19)
assert(promotion.word.alpha == 0 and promotion.title.alpha == 1)
promotion.scripts.OnUpdate(promotion, .79)
assert(promotion.scripts.OnUpdate and promotion.alpha == 1)
promotion.scripts.OnUpdate(promotion, .42)
assert(not promotion.scripts.OnUpdate)
print("PASS: bitmap shrink is monotonic, all glows share its center, native text takes over at rest, and one-second glow hold is preserved")

local originalTooltip = GameTooltip
local hoveredItem, hoveredSpell
GameTooltip = {SetOwner=function() end, Show=function() end, Hide=function() end,
    SetHyperlink=function(_, link) hoveredItem=link end,
    SetSpellByID=function(_, id) hoveredSpell=id end}
DP.SelectDuelView("History")
assert(controls.rows[1].duelRecord)
controls.rows[1].scripts.OnEnter(controls.rows[1])
assert(DP.Usage.historyTip and DP.Usage.historyTip:IsShown())
controls.rows[1].scripts.OnLeave(controls.rows[1])
assert(not DP.Usage.historyTip:IsShown())
controls.rows[1].scripts.OnClick(controls.rows[1])
assert(DP.Usage.window:IsShown())
local usageRecord={won=true,opponent="Rival",timestamp=1800000000,session={usage={player={
    gem={spellID=23725,name="Gift of Life",kind="item",count=1},
    reck={spellID=1719,name="Recklessness",kind="cooldown",cooldown=1800,count=1},
    racial={spellID=20572,name="Blood Fury",kind="racial",count=1}
}}}}
DP.Usage.OpenDetails(usageRecord)
assert(DP.Usage.window.header and DP.Usage.window.close and DP.Usage.window.tableHeader)
for _, button in ipairs(DP.Usage.window.entryButtons or {}) do
    if button:IsShown() and button.entry then button.scripts.OnEnter(button) end
end
assert(hoveredItem=="item:19341" and hoveredSpell==20572)
DP.Usage.window:Hide()
assert(not DP.Usage.window:IsShown())
GameTooltip=originalTooltip
DP.SelectDuelView("Overview")
print("PASS: History click opens closable usage details with native item and spell hover tooltips")

assert(blips.slots[1].light.sublevel > blips.slots[1].fill.sublevel)
assert(rivals.slots[1].light.sublevel > rivals.slots[1].fill.sublevel)
print("PASS: blue and purple blip highlights render explicitly above their fills")
