local U, W = DP.Usage, DP.WorldPvP
local oldTSM = TSM_API
TSM_API = {GetCustomPriceValue=function() return 1000 end}
local enemy = {guid="Enemy-test", name="Opponent", detectedBuffs={all={
    {spellID=17539,name="Greater Arcane Elixir"},
    {spellID=17535,name="Elixir of the Sages"},
    {spellID=24382,name="Spirit of Zanza"},
    {spellID=11396,name="Elixir of Greater Intellect"},
    {spellID=16591,name="Noggenfogger Elixir"},
    {spellID=16595,name="Noggenfogger Elixir"},
    {spellID=999999,name="Unknown non-consumable aura"},
}}}
local session = {worldPvP=true, playerGUID="Player-test", enemies={[enemy.guid]=enemy},
    worldUsage={events={{guid="Player-test",spellID=6615,itemID=5634,name="Free Action Potion",kind="item",category="potions",t=1}}}}
local record = {enemies={enemy},session=session,
    consumableCost={actors={},pricedCount=0,unpricedCount=0,totalCopper=0}}
assert(U.NeedsLegacyConsumableBackfill(record), "empty original recordings must repair")
local live = U.CaptureWorldConsumableCost(session)
assert(live.pricedCount == 7 and live.unpricedCount == 0 and live.totalCopper == 6400,
    "finalization must immediately price all seven consumables")
local repaired = U.CaptureLegacyWorldConsumableCost(record,123,{},true)
assert(repaired.totalCopper == live.totalCopper and repaired.pricedCount == live.pricedCount)
record.consumableCost = live
assert(not U.NeedsLegacyConsumableBackfill(record), "valid captured prices must remain frozen")
TSM_API = oldTSM

local savedGUID, savedPortrait = UnitGUID, SetPortraitTexture
local calls = 0
UnitGUID = function() return "Enemy-test" end
SetPortraitTexture = function(tex)
    calls = calls + 1
    tex.render = "encounter appearance"
    tex.GetTexture = function() return "RTPortrait1" end
end
assert(W.CaptureOpponentPortrait(enemy,"target"))
assert(enemy.portraitTexture == nil, "runtime handles must not be serialized as images")
enemy.portraitFrozen = true
assert(not W.CaptureOpponentPortrait(enemy,"target"))
local card = {portrait=CreateFrame(), portraitFrame=CreateFrame(), portraitMask=CreateFrame()}
W.ApplyOpponentPortrait(card,enemy)
assert(calls == 1 and card._snapshotHolder.tex.render == "encounter appearance")
assert(card._snapshotHolder.tex.parent == card.portraitFrame)
W.ApplyOpponentPortrait(card,{class="MAGE"})
assert(card._snapshotHolder == nil, "recycled cards must detach the previous snapshot")
UnitGUID, SetPortraitTexture = savedGUID, savedPortrait

W.overviewHost:SetSize(384,430)
W.overviewHost:Show()
W.SetOverviewMode("world",true)
assert(W.overviewViewport:GetWidth() == 316, "transparent frame padding must stay outside the mask")
assert(W.overviewFrame:GetWidth() == 352)
assert(W.overviewFrame.point[4] == -18, "artwork must be centered within the clipped field")
W.SetOverviewMode("duels")
assert(W.overviewHost.scripts.OnUpdate)
W.overviewHost.scripts.OnUpdate(W.overviewHost,.3)
assert(not W.swipe and W.duelOverviewFrame.point[4] == -18)

-- Every playable Classic Era Horde race/class pair has a curated legacy portrait.
local hordePortraitKeys = {
    "Orc:WARRIOR", "Orc:HUNTER", "Orc:ROGUE", "Orc:SHAMAN", "Orc:WARLOCK",
    "Tauren:WARRIOR", "Tauren:HUNTER", "Tauren:SHAMAN", "Tauren:DRUID",
    "Troll:WARRIOR", "Troll:HUNTER", "Troll:ROGUE", "Troll:PRIEST", "Troll:SHAMAN", "Troll:MAGE",
    "Scourge:WARRIOR", "Scourge:ROGUE", "Scourge:PRIEST", "Scourge:MAGE", "Scourge:WARLOCK",
}
for _, key in ipairs(hordePortraitKeys) do
    local choices = DP.WorldPvP.CLASS_RACE_PORTRAIT_DISPLAY_IDS[key]
    assert(type(choices) == "table" and #choices > 0, "missing Horde portrait fallback: " .. key)
end

print("PASS: immediate pricing, false-zero repair, frozen portrait texture, centered clipped carousel")
