clock = 100
timers = {}
frames = {}
messages = {}
hooks = {}
WOW_PROJECT_ID = 2
WOW_PROJECT_CLASSIC = 2
DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel."
DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel."
ERR_DUEL_REQUESTED = "You have requested a duel."
DUEL_COUNTDOWN = "Duel starting: %d"
SlashCmdList = {}
UISpecialFrames = {}
UIParent = {}
ChatFontNormal = {}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, text) messages[#messages + 1] = text end}
function time() return 1800000000 + math.floor(clock) end
function GetTime() return clock end
function date(format, value) return os.date(format, value) end
function GetNormalizedRealmName() return "Realm" end
function GetLocale() return "enUS" end
function GetBuildInfo() return "1.15.9", "69547" end
function UnitExists(unit) return unit == "player" or unit == "target" end
function UnitIsPlayer(unit) return UnitExists(unit) end
function UnitName(unit) return unit == "player" and "Alice" or "Bob", "Realm" end
function UnitGUID(unit) return unit == "player" and "Player-1-A" or "Player-1-B" end
function UnitClass() return "Mage", "MAGE" end
function UnitLevel() return 60 end
function StartDuel() end
function hooksecurefunc(name, callback) hooks[name] = callback end
C_Timer = {After = function(delay, fn) timers[#timers + 1] = {at = clock + delay, fn = fn} end}
function advance(delta)
    clock = clock + delta
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do
        if timer.at <= clock then timer.fn() else timers[#timers + 1] = timer end
    end
end
local noop = function() end
function CreateFrame()
    local f = {events = {}, scripts = {}, TitleText = {SetText = noop}}
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:SetText(text) self.text = text end
    function f:GetText() return self.text end
    for _, key in ipairs({"SetSize", "SetPoint", "SetMovable", "EnableMouse", "RegisterForDrag",
        "StartMoving", "StopMovingOrSizing", "SetMultiLine", "SetAutoFocus", "SetFontObject",
        "SetWidth", "SetMaxLetters", "SetScrollChild", "Show", "Hide", "SetFocus", "HighlightText"}) do
        f[key] = noop
    end
    frames[#frames + 1] = f
    return f
end
function fire(event, ...)
    local f = frames[1]
    assert(f.events[event], "unregistered event: " .. event)
    f.scripts.OnEvent(f, event, ...)
end
