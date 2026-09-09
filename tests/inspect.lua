local I = DP.Inspect
local settings, sent = {}, {}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, text, channel, sender)
        sent[#sent + 1] = {prefix, text, channel, sender}; return true
    end,
}
local rating = DP.Rating.New()
I.Initialize(function() return rating end, settings)
assert(settings.shareProfile == true) -- Sharing defaults on.
settings.shareProfile = false
I.Receive(I.prefix, "1|Q|100-1", "WHISPER", "Bob-Realm")
assert(#sent == 1 and I.Decode(sent[1][2]).kind == "A") -- Opt-out acknowledges presence without sharing ratings.
clock = clock + 3 -- Advance the reply throttle without running unrelated pending UI timers.
settings.shareProfile = true
I.Receive(I.prefix, "1|Q|100-1", "WHISPER", "Bob-Realm")
assert(#sent == 2)
assert(I.Decode(sent[2][2]).rating == 1500)
I.Receive(I.prefix, "1|Q|100-2", "WHISPER", "Bob-Realm")
assert(#sent == 2) -- Global reply throttle.
assert(I.Decode("1|S|100-1|Player-1-B|nan|1500|0|0|0|0|0|0") == nil)
assert(I.Decode("1|S|100-1|Player-1-B|1500|1500|-1|0|0|0|0|0") == nil)
assert(I.Decode(string.rep("x", 241)) == nil)
I.target = {name = "Bob-Realm", guid = "Player-1-B"}
I.Request()
local token = I.pending.token
local response = "1|S|" .. token .. "|Player-1-B|1600|1620|5|2|1|2|6.5|3"
I.Receive(I.prefix, response, "WHISPER", "Charlie-Realm")
assert(I.pending and not I.profile)
I.Receive(I.prefix, response, "GUILD", "Bob-Realm")
assert(I.pending and not I.profile)
I.Receive(I.prefix, response:gsub("Player%-1%-B", "Player-1-C"), "WHISPER", "Bob-Realm")
assert(I.pending and not I.profile)
I.Receive(I.prefix, response, "WHISPER", "Bob")
assert(I.profile.rating == 1600 and not I.pending)
assert(settings.sharedProfiles["Player-1-B"].name == "Bob-Realm")
assert(#I.Leaderboard() == 2 and I.Leaderboard()[1].rating == 1600)
settings.shareProfile = false
assert(#I.Leaderboard() == 1)
settings.sharedProfiles.expired = {receivedAt = time() - 8 * 86400}
assert(#I.Leaderboard() == 1 and not settings.sharedProfiles.expired)
I.Receive(I.prefix, response:gsub("Player%-1%-B", "Player-1-D"), "WHISPER", "Stranger-Realm")
assert(not settings.sharedProfiles["Player-1-D"])
DP.SelectDuelView("Leaderboard")
assert(DP.duelViewControls.rows[1].first.text == "1. Bob-Realm")
assert(DP.duelViewControls.rows[1].second.text:find("Provisional"))
assert(DP.duelViewControls.rows[1].amount.text:find("1600.0", 1, true))
DP.duelViewControls.boardFilter.scripts.OnClick()
assert(DP.duelViewControls.page.text == "0 records")
DP.duelViewControls.boardFilter.scripts.OnClick()
assert(DP.duelViewControls.page.text == "1 record")
DP.duelViewControls.clearProfiles.scripts.OnClick()
assert(next(settings.sharedProfiles) == nil and rating.rating == 1500)
DP.SelectDuelView("Leaderboard") -- Reopen Rivals after clearing its cache from Manage.
assert(DP.duelViewControls.page.text == "0 records")
DP.SelectDuelView("Overview")
print("PASS: shared leaderboard default-on self entry, opt-out, sorting, expiry, unsolicited rejection and rendering")
assert(rating.rating == 1500 and rating.wins == 0)
advance(4)
I.Request()
advance(9)
assert(not I.pending and not I.profile and I.status == "Rivals not detected")
I.Receive(I.prefix, response, "WHISPER", "Bob-Realm")
assert(not I.profile)

InspectFrame = CreateFrame(); InspectFrame.numTabs = 2; InspectFrame.unit = "target"
InspectFrameTab2 = CreateFrame()
INSPECTFRAME_SUBFRAMES = {"InspectPaperDollFrame", "InspectHonorFrame"}
CreateFrame("Frame", "InspectPaperDollFrame")
CreateFrame("Frame", "InspectHonorFrame")
local selected = 1
function InspectSwitchTabs(id)
    _G[INSPECTFRAME_SUBFRAMES[selected]]:Hide()
    selected = id
    _G[INSPECTFRAME_SUBFRAMES[id]]:Show()
end
I.Install()
assert(#I.panel.textures >= 1 and I.ui.content) -- Overview cards live in a centered content frame inside native chrome.
assert(I.panel.textures[1].point[1] == "BOTTOMRIGHT")
assert(I.ui and I.ui.duelProgress and I.ui.rivalProgress and I.ui.record and I.ui.peak)
assert(InspectFrame.numTabs == 3 and InspectFrameTab3.point[2] == InspectFrameTab2)
InspectFrameTab3.scripts.OnClick()
assert(I.panel:IsShown() and I.target.name == "Bob-Realm")
InspectSwitchTabs(1)
assert(not I.panel:IsShown() and not I.pending and not I.target)
I.Install(); assert(InspectFrame.numTabs == 3)
print("PASS: Overview-style inspect tab, default-on sharing, opt-out, parser bounds, sender/GUID/nonce checks, timeout and local-rating isolation")

GameTooltip = {scripts = {}, lines = {}, unit = "target"}
function GameTooltip:HookScript(event, fn) self.scripts[event] = fn end
function GameTooltip:GetUnit() return "Bob", self.unit end
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function GameTooltip:Show() end
local localRating = DP.Rating.New()
localRating.opponents["Player-1-B"] = {wins = 2, losses = 1, effective = 3, rating = 1480, lastAt = 1800000000}
DP.InstallPlayerTooltip(function() return localRating end)
local sentBefore = #sent
GameTooltip.scripts.OnTooltipSetUnit(GameTooltip)
assert(GameTooltip.lines[3] == "Your record: 2-1")
local lineCount = #GameTooltip.lines
GameTooltip.scripts.OnTooltipSetUnit(GameTooltip)
assert(#GameTooltip.lines == lineCount and #sent == sentBefore)
GameTooltip.scripts.OnTooltipCleared()
GameTooltip.lines = {}
GameTooltip.unit = "player"
GameTooltip.scripts.OnTooltipSetUnit(GameTooltip)
assert(#GameTooltip.lines == 0)
print("PASS: local player tooltip records, duplicate guard, unknown players and no network requests")
