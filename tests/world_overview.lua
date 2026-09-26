local W = DP.WorldPvP
assert(W and W.overviewHost and W.overviewFrame and W.duelOverviewFrame)
assert(W.overviewViewport and W.overviewCanvas and W.swipeShield)
assert(W.duelDot and W.worldDot)
assert(W.duelDot.dot.fontSize == W.worldDot.dot.fontSize)
assert(not W.duelTab and not W.worldTab)
assert(not W.overviewFrame.bg) -- World PvP is a sibling page, not an opaque overlay pane.

W.SetOverviewMode("world", true)
assert(W.overviewMode == "world" and W.GetOverviewMode() == "world")
assert(W.db.worldPvPOverviewMode == "world")
assert(W.overviewFrame:IsShown() and not W.duelOverviewFrame:IsShown())
assert(W.worldDot.dot.textColor[1] > W.duelDot.dot.textColor[1])
assert(W.duelDot.dot.fontSize == W.worldDot.dot.fontSize)
assert(W.overviewHeader.text.text == "World PvP")
assert(W.overviewSweep and W.overviewCurrentStreak and W.overviewBestStreak)
assert(not W.overviewFormSlots and not W.overviewHistoryButton)
assert(W.overviewManageButton)

-- Closing the Character pane must not reset the chosen Overview page.
RivalsCharacterPanel:Hide()
assert(W.db.worldPvPOverviewMode == "world")
RivalsCharacterPanel:Show()
assert(W.overviewMode == "world" and W.overviewFrame:IsShown())
assert(CharacterFrameTab6 == nil and RivalsCharacterTab.rivalsLabel:GetText() == "WPvP")

-- A live page change is animated as a horizontal swipe, then settles into the
-- same Overview bounds with only the selected page shown.
W.SetOverviewMode("duels")
assert(W.overviewHost.scripts.OnUpdate)
W.overviewHost.scripts.OnUpdate(W.overviewHost, .30)
assert(W.overviewMode == "duels")
assert(W.db.worldPvPOverviewMode == "duels")
assert(W.duelOverviewFrame:IsShown() and not W.overviewFrame:IsShown())
assert(CharacterFrameTab6 == nil and RivalsCharacterTab.rivalsLabel:GetText() == "Duels")
assert(not W.overviewHost.scripts.OnUpdate)
assert(W.duelDot.dot.textColor[1] > W.worldDot.dot.textColor[1])
-- Duel-only controls are children of the moving Duel page. The shared period
-- dropdown is reserved for non-Overview views, so nothing pops on/off after a swipe.
local controls = DP.duelViewControls
assert(controls and controls.mode and controls.period and controls.overviewPeriod)
assert(controls.mode.parent == W.duelOverviewFrame)
assert(controls.overviewPeriod.parent == W.duelOverviewFrame)
assert(not controls.period:IsShown())
W.SetOverviewMode("world", true)
assert(not W.duelOverviewFrame:IsShown() and controls.mode:IsShown() and controls.overviewPeriod:IsShown())
W.SetOverviewMode("duels", true)
assert(W.duelOverviewFrame:IsShown() and controls.mode:IsShown() and controls.overviewPeriod:IsShown())
assert(not W.duelDot.scripts.OnEnter and not W.worldDot.scripts.OnEnter)

-- Active dots cycle instead of no-op. Repeatedly clicking the same physical dot
-- bounces between pages as it alternates between active and inactive.
W.SetOverviewMode("duels", true)
W.duelDot.scripts.OnClick(W.duelDot)
assert(W.overviewMode == "world")
W.overviewHost.scripts.OnUpdate(W.overviewHost, .30)
W.duelDot.scripts.OnClick(W.duelDot)
assert(W.overviewMode == "duels")
W.overviewHost.scripts.OnUpdate(W.overviewHost, .30)

print("PASS: clipped persistent Duel/World carousel with centered cycling paginator and page-owned Duel controls")
