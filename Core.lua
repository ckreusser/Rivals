local addonName, DP = ...
local VERSION, TRACE_LIMIT, ACTIVITY_LIMIT = "1.0.0", 1000, 200
local frame = CreateFrame("Frame")
local db, observer, tracker, parsers, ready, rating
local seasons, selectedPeriod = {}, nil
local Say
local verifier
local recovery

function DP.InterruptedItems() return recovery and recovery:Items() or {} end
function DP.RecoveryStatus() return recovery and recovery.status or "Target the previous opponent and retry recovery." end
function DP.AcceptedRecoveryItems() return recovery and recovery:AcceptedItems() or {} end
function DP.ReviewRecovery(item, undo)
    if tracker and tracker.session then Say("Finish or cancel the current duel before applying a recovered report."); return end
    local preview, err
    if undo then preview, err = recovery:PreviewUndo(item) else preview, err = recovery:Preview(item) end
    if not preview then Say(err); return end
    if not DP.recoveryReview then
        local window = CreateFrame("Frame", "RivalsRecoveryReview", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(440, 260); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG")
        window.TitleText:SetText("Review recovered duel")
        window.text = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        window.text:SetPoint("TOPLEFT", 18, -40); window.text:SetWidth(400); window.text:SetJustifyH("LEFT")
        local apply = DP.Theme.Button(window, "Apply to local record", 18, -218, 180)
        apply:ClearAllPoints(); apply:SetSize(180, 24); apply:SetPoint("BOTTOMLEFT", 18, 18); apply:SetText("Apply to local record")
        local cancel = DP.Theme.Button(window, "Cancel", 322, -218, 100)
        cancel:ClearAllPoints(); cancel:SetSize(100, 24); cancel:SetPoint("BOTTOMRIGHT", -18, 18); cancel:SetText("Cancel")
        cancel:SetScript("OnClick", function() window:Hide() end)
        window.apply = apply
        DP.recoveryReview = window
        UISpecialFrames[#UISpecialFrames + 1] = "RivalsRecoveryReview"
    end
    local window = DP.recoveryReview
    window.TitleText:SetText(undo and "Undo recovered duel acceptance" or "Review recovered duel")
    window.apply:SetText(undo and "Undo acceptance" or "Apply to local record")
    local oldRating = rating.rating
    local scope = item.periodId and ("Lifetime and Season " .. item.periodId) or "Lifetime only (no saved season assignment)"
    window.text:SetText(string.format("%s vs %s — %s\n\nLifetime: %.2f -> %.2f (%+.2f)\n%s\n\nRival Report; not independently observed.\nThis updates W/L, repeat counts and later ratings.\n%s",
        item.won and "Win" or "Loss", item.name, date("%m/%d %H:%M", item.timestamp), oldRating, preview.rating.rating,
        preview.rating.rating - oldRating, scope, undo and "The original report returns to Interrupted." or "The evidence label remains Rival Report."))
    window.apply:SetScript("OnClick", function()
        if tracker.session then Say("Finish the current duel before applying this report."); window:Hide(); return end
        local fresh, failure
        if undo then fresh, failure = recovery:PreviewUndo(item) else fresh, failure = recovery:Preview(item) end
        if not fresh then Say(failure); window:Hide(); return end
        if fresh.count ~= preview.count or fresh.rating.rating ~= preview.rating.rating or rating.rating ~= oldRating then
            DP.ReviewRecovery(item, undo); Say("Record changed; review the updated rating before applying."); return
        end
        if not undo then
            fresh.record.captureVersion = VERSION
            fresh.record.acceptanceImpact = fresh.rating.rating - oldRating
        end
        observer.results = fresh.records
        if not undo then observer.nextSequence = fresh.record.id + 1 end
        rating, seasons = fresh.rating, fresh.seasons
        observer.duelTargets, observer.ratingGuards = rating.opponents, rating.targets
        for _, period in ipairs(observer.seasons) do seasons[period.id] = seasons[period.id] or DP.Rating.New() end
        for _, record in ipairs(observer.results) do
            record.ratingDecision = rating.applied[record.id]
            record.ratingEligible = record.ratingDecision and record.ratingDecision.eligible or false
            record.seasonDecision = record.periodId and seasons[record.periodId].applied[record.id] or nil
        end
        if undo then recovery:RestoreReport(fresh.record) else item.appliedId = fresh.record.id end
        observer.recoveryAudit[#observer.recoveryAudit + 1] = {action = undo and "undo" or "accept", at = time(),
            recordId = fresh.record.id, token = fresh.record.session.verificationToken, opponent = fresh.record.opponent,
            before = oldRating, after = rating.rating, originalAcceptedAt = fresh.record.acceptedAt}
        window:Hide()
        Say(string.format("%s. Lifetime rating: %.2f -> %.2f.", undo and "Acceptance undone; report restored" or "Rival Report accepted locally", oldRating, rating.rating))
        if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
    end)
    window:Show()
end
function DP.RetryRecovery()
    if not recovery then return end
    -- Historical opponents may be offline; addon whispers to them produce server errors.
    -- Resolve the live target at send time, never from a saved opponent list.
    if DP.CanWhisperUnit("target") then
        local name, realm = UnitName("target")
        if name then recovery:Request({name = name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName()), guid = UnitGUID("target")}) end
    else
        recovery:SetStatus("Target a connected same-faction opponent before retrying recovery.")
    end
end

function DP.DuelModeLabel()
    return db and db.duelMode == "casual" and "Prefer Casual" or "Prefer Rated"
end
function DP.DuelAgreementStatus()
    return DP.Verification.AgreementStatus(tracker and tracker.session, db and db.verifyResults ~= false)
end
function DP.HasActiveDuel() return tracker and tracker.session ~= nil end

function DP.ToggleDuelMode(mode)
    if not db then return end
    if tracker and tracker.session then Say("Change mode after the current duel or request ends."); return end
    db.duelMode = mode or (db.duelMode == "casual" and "rated" or "casual")
    Say("Next duel preference: " .. DP.DuelModeLabel() .. ". Rated requires Rivals verification from both players.")
    if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
end

function DP.ProfileSharingEnabled()
    return db and db.shareProfile ~= false
end

function DP.SetProfileSharing(enabled)
    if not db then return end
    db.shareProfile = enabled and true or false
    Say("Profile summary sharing " .. (db.shareProfile and "on" or "off") .. ".")
    if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
end

function DP.DuelScreenshotsEnabled()
    return db and db.duelScreenshots == true
end

function DP.WorldPvPScreenshotsEnabled()
    return db and db.worldPvPScreenshots == true
end

function DP.SetDuelScreenshots(enabled)
    if not db then return end
    db.duelScreenshots = enabled and true or false
    Say("Duel screenshots " .. (db.duelScreenshots and "on" or "off") .. ".")
    if DP.RefreshDuelViews then DP.RefreshDuelViews() end
end

function DP.SetWorldPvPScreenshots(enabled)
    if not db then return end
    db.worldPvPScreenshots = enabled and true or false
    Say("World PvP screenshots " .. (db.worldPvPScreenshots and "on" or "off") .. ".")
    if DP.RefreshDuelViews then DP.RefreshDuelViews() end
end

function DP.DisplayPeriodName()
    return selectedPeriod and ("Season " .. selectedPeriod) or "Lifetime"
end

function DP.DisplayPeriodValue()
    return selectedPeriod or "lifetime"
end

function DP.DisplayPeriodOptions()
    local options = {{text = "Lifetime", value = "lifetime"}}
    if observer then
        for index = 1, #(observer.seasons or {}) do
            options[#options + 1] = {text = "Season " .. index, value = index}
        end
    end
    return options
end

function DP.SetDisplayPeriod(value)
    if not observer then return end
    if value == nil or value == false or value == "lifetime" then
        selectedPeriod = nil
    else
        local id = tonumber(value)
        if not id or not observer.seasons or not observer.seasons[id] then return end
        selectedPeriod = id
    end
    if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
end

function DP.ProgressCheckpoint()
    observer.progressSeen = observer.progressSeen or {}
    local key = selectedPeriod and ("season:" .. selectedPeriod) or "lifetime"
    observer.progressSeen[key] = observer.progressSeen[key] or {duels = 0, opponents = 0}
    return observer.progressSeen[key]
end

local function DisplayRating()
    return selectedPeriod and seasons[selectedPeriod] or rating
end

local function DisplayRecords()
    if not selectedPeriod then return observer.results end
    local records = {}
    for _, r in ipairs(observer.results) do if r.periodId == selectedPeriod then records[#records + 1] = r end end
    return records
end

function DP.AllDuelRecords()
    return observer and observer.results or {}
end

local function SpecTargetMatches(target, profile)
    if not target or not profile then return false end
    local session = target.session or target
    local identity = session and session.identity
    if profile.guid and identity and identity.guid then return profile.guid == identity.guid end
    local targetName = (identity and identity.name) or target.opponent or session.opponent
    local profileName = profile.name
    if not targetName or not profileName then return false end
    local a = tostring(targetName):match("^([^-]+)") or tostring(targetName)
    local b = tostring(profileName):match("^([^-]+)") or tostring(profileName)
    return a:lower() == b:lower()
end

local function BindInspectSpecToOneDuel(profile)
    if not profile or not DP.Specs or not DP.Specs.BindInspect then return false end

    -- An in-progress duel is the strongest possible binding: the inspect happened
    -- while this exact session is current.
    if tracker and tracker.session and SpecTargetMatches(tracker.session, profile) then
        return DP.Specs.BindInspect(tracker.session, profile)
    end

    -- If the player explicitly has one duel's tooltip/details open, bind the
    -- inspection to that record only, never to every duel against this opponent.
    local focused = DP.Usage and DP.Usage.SpecTargetRecord and DP.Usage.SpecTargetRecord()
    if focused and SpecTargetMatches(focused, profile) then
        return DP.Specs.BindInspect(focused, profile)
    end

    -- Normal post-duel workflow: inspecting the opponent shortly after the match
    -- upgrades only the most recent matching duel. Older meetings remain untouched
    -- because the opponent may have respecced between them.
    if observer and observer.results then
        local now = time and time() or 0
        for i = #observer.results, 1, -1 do
            local record = observer.results[i]
            if SpecTargetMatches(record, profile) then
                local age = now > 0 and record.timestamp and (now - record.timestamp) or 0
                if age >= 0 and age <= 600 then return DP.Specs.BindInspect(record, profile) end
                break
            end
        end
    end
    return false
end

function DP.CyclePeriod()
    if not observer then return end
    local count = #(observer.seasons or {})
    if count == 0 then Say("No season yet. /rivals season start opens a fresh local season."); return end
    if not selectedPeriod then selectedPeriod = 1
    elseif selectedPeriod < count then selectedPeriod = selectedPeriod + 1
    else selectedPeriod = nil end
    if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
end

local function SummaryText()
    local streak = rating.streak == 0 and "None" or
        DP.Views.Count(math.abs(rating.streak), rating.streak > 0 and "win" or "loss", rating.streak > 0 and "wins" or "losses")
    return string.format("LOCAL DUEL RATING  %.1f  |  %s\nPeak: %.1f\nRecord: %s / %s\nStreak: %s | Longest win streak: %d\nPlacements: %d / 10 duels; %d / 5 distinct opponents\n\nBased only on your recorded duels. Opponent ratings are local estimates.\nRecords begin with version 0.2.0; earlier diagnostic captures remain separate.",
        rating.rating, DP.Rating.Provisional(rating) and "Provisional" or "Established local estimate",
        rating.peak, DP.Views.Count(rating.wins, "win", "wins"), DP.Views.Count(rating.losses, "loss", "losses"), streak, rating.longestWinStreak,
        DP.Rating.PlacementCount(rating), rating.distinct)
end

Say = function(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66Rivals:|r " .. message)
end

local function BoundedAppend(list, value, limit)
    list[#list + 1] = value
    if #list > limit then table.remove(list, 1) end
end

local function Trace(event, ...)
    if not ready or (not db.traceEnabled and not event:match("^VERIFY_") and event ~= "ADDON_ACTION_BLOCKED" and event ~= "ADDON_ACTION_FORBIDDEN") then return end
    local args = {}
    for i = 1, math.min(select("#", ...), 6) do
        local value = select(i, ...)
        if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
            args[#args + 1] = tostring(value):sub(1, 1000)
        end
    end
    BoundedAppend(observer.trace, {at = time(), elapsed = GetTime(), event = event,
        args = args}, TRACE_LIMIT)
end

local SCREENSHOT_STATUS_EVENTS = {"SCREENSHOT_STARTED", "SCREENSHOT_SUCCEEDED", "SCREENSHOT_FAILED"}
local silentScreenshot = {pending = 0, generation = 0}

local function RestoreRivalsScreenshotStatus()
    local saved = silentScreenshot.saved
    silentScreenshot.saved = nil
    silentScreenshot.pending = 0
    if not saved then return end
    for _, entry in ipairs(saved) do
        local statusFrame = entry.frame
        if statusFrame and statusFrame.RegisterEvent and statusFrame.UnregisterEvent then
            for event, wasRegistered in pairs(entry.events) do
                if wasRegistered then
                    pcall(statusFrame.RegisterEvent, statusFrame, event)
                else
                    pcall(statusFrame.UnregisterEvent, statusFrame, event)
                end
            end
        end
    end
end

local function FinishRivalsScreenshotStatus()
    if silentScreenshot.pending <= 0 then return end
    silentScreenshot.pending = silentScreenshot.pending - 1
    if silentScreenshot.pending > 0 then return end
    -- Do not re-register Blizzard's status frames during the same event dispatch;
    -- on Classic that can allow the just-fired screenshot event to reach them.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, RestoreRivalsScreenshotStatus)
    else
        RestoreRivalsScreenshotStatus()
    end
end

local function SilenceRivalsScreenshotStatus()
    if silentScreenshot.pending == 0 then
        silentScreenshot.saved = {}
        -- Classic currently has two independent center-screen screenshot notices:
        -- Blizzard_ActionStatus's ActionStatus and UIParent/WorldFrame's
        -- ScreenshotStatus. Silence only Rivals' capture window, then restore the
        -- exact event-registration state so normal PrintScreen behavior is untouched.
        local statusFrames = {}
        if _G.ActionStatus then statusFrames[#statusFrames + 1] = _G.ActionStatus end
        if _G.ScreenshotStatus and _G.ScreenshotStatus ~= _G.ActionStatus then
            statusFrames[#statusFrames + 1] = _G.ScreenshotStatus
        end
        for _, statusFrame in ipairs(statusFrames) do
            if statusFrame.UnregisterEvent and statusFrame.IsEventRegistered then
                local entry = {frame = statusFrame, events = {}}
                for _, event in ipairs(SCREENSHOT_STATUS_EVENTS) do
                    local ok, registered = pcall(statusFrame.IsEventRegistered, statusFrame, event)
                    if ok then
                        entry.events[event] = registered and true or false
                        if registered then pcall(statusFrame.UnregisterEvent, statusFrame, event) end
                    end
                end
                silentScreenshot.saved[#silentScreenshot.saved + 1] = entry
                -- Also remove any fading status left over from an earlier manual
                -- screenshot so Rivals never captures that stale notification.
                if statusFrame.Hide then pcall(statusFrame.Hide, statusFrame) end
            end
        end
    end
    silentScreenshot.pending = silentScreenshot.pending + 1
    silentScreenshot.generation = silentScreenshot.generation + 1
    local generation = silentScreenshot.generation
    -- Defensive watchdog: if the client never returns SUCCEEDED/FAILED, do not
    -- leave Blizzard's screenshot-status frames muted for the rest of the session.
    if C_Timer and C_Timer.After then
        C_Timer.After(5, function()
            if silentScreenshot.pending > 0 and silentScreenshot.generation == generation then
                Trace("SCREENSHOT_STATUS_TIMEOUT", silentScreenshot.pending)
                RestoreRivalsScreenshotStatus()
            end
        end)
    end
end

function DP.TakeRivalsScreenshot(kind, subject)
    if not db then return false end
    local enabled = kind == "duel" and db.duelScreenshots == true or
        kind == "world" and db.worldPvPScreenshots == true
    if not enabled or type(Screenshot) ~= "function" then return false end
    SilenceRivalsScreenshotStatus()
    local ok, err = pcall(Screenshot)
    if not ok then
        FinishRivalsScreenshotStatus()
        Trace("SCREENSHOT_FAILED", kind, subject or "", tostring(err))
        return false
    end
    Trace("SCREENSHOT", kind, subject or "")
    return true
end

local DUEL_SCREENSHOT_DELAY = 0.20

local function ScheduleDuelScreenshot(subject)
    local function Capture()
        if DP.TakeRivalsScreenshot then DP.TakeRivalsScreenshot("duel", subject) end
    end
    Trace("DUEL_SCREENSHOT_SCHEDULED", subject or "", DUEL_SCREENSHOT_DELAY)
    if C_Timer and C_Timer.After then C_Timer.After(DUEL_SCREENSHOT_DELAY, Capture) else Capture() end
end

local function UnitIdentity(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local name, realm = UnitName(unit)
    if not name then return nil end
    if not realm or realm == "" then realm = GetNormalizedRealmName() end
    local _, class = UnitClass(unit)
    local localizedRace, raceFile
    if UnitRace then localizedRace, raceFile = UnitRace(unit) end
    local faction = UnitFactionGroup and UnitFactionGroup(unit)
    local sex = UnitSex and UnitSex(unit)
    local displayID = UnitCreatureDisplayID and UnitCreatureDisplayID(unit)
    return {name = name .. "-" .. realm, guid = UnitGUID(unit), class = class,
        level = UnitLevel(unit), race = raceFile or localizedRace, localizedRace = localizedRace,
        raceFile = raceFile, faction = faction, sex = sex, portraitSex = sex,
        portraitDisplayID = displayID, whisperBlocked = not DP.CanWhisperUnit(unit)}
end

local function FindIdentity(name)
    for _, unit in ipairs({"target", "mouseover"}) do
        local identity = UnitIdentity(unit)
        if identity and DP.Parser.SameName(identity.name, name) then return identity end
    end
end

local function PersistSession()
    observer.pending = tracker.session
    if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
end

local function Request(name, direction, excluded, identity)
    if not ready or type(name) ~= "string" or name == "" then return end
    if DP.WorldPvP and DP.WorldPvP.active then DP.WorldPvP.Finish("formal-duel-start") end
    local id = tracker:Request(name, direction, excluded, GetTime(), identity or FindIdentity(name))
    if tracker.session and not tracker.session.playerLevel then tracker.session.playerLevel = UnitLevel("player") end
    if tracker.session and not tracker.session.modePreference then tracker.session.modePreference = db.duelMode or "rated" end
    if tracker.session and not tracker.session.startedTimestamp then tracker.session.startedTimestamp = time() end
    if tracker.session and tracker.session.periodId == nil then tracker.session.periodId = observer.activeSeason or false end
    DP.Usage.Scan()
    DP.Usage.Begin(tracker.session)
    if tracker.session then
        tracker.session.playerGUID = tracker.session.playerGUID or UnitGUID("player")
        tracker.session.playerName = tracker.session.playerName or (UnitName("player") or player.name)
        tracker.session.playerClass = tracker.session.playerClass or player.class
        if DP.Usage.CaptureDuelBuffs then DP.Usage.CaptureDuelBuffs(tracker.session) end
    end
    if verifier then verifier:Begin(tracker.session) end
    PersistSession()
    Trace("CAPTURE_REQUEST", name, direction, excluded or false)
    -- A generous diagnostic timeout; no duration or outcome is inferred from it.
    C_Timer.After(1800, function()
        if ready then tracker:Expire(id, GetTime()); PersistSession() end
    end)
end

local function ExportText()
    local lines = {"Rivals capture " .. VERSION, "Observer: " .. observer.name,
        "Build: " .. observer.build .. " | Locale: " .. observer.locale,
        SummaryText(), "", "CLIENT FORMATS"}
    for _, key in ipairs({"DUEL_WINNER_KNOCKOUT", "DUEL_WINNER_RETREAT", "ERR_DUEL_REQUESTED", "DUEL_COUNTDOWN", "ERR_DUEL_CANCELLED"}) do
        lines[#lines + 1] = key .. " = " .. tostring(_G[key])
    end
    lines[#lines + 1] = "\nRECENT RESULTS (up to 50)"
    for i = math.max(1, #observer.results - 49), #observer.results do
        local r = observer.results[i]
        lines[#lines + 1] = "  Result evidence: " .. DP.Verification.Label(r)
        if r.verification and r.verification.reason then lines[#lines + 1] = "  Evidence detail: " .. r.verification.reason end
        if r.verification and r.verification.matchId then lines[#lines + 1] = "  Match ID: " .. r.verification.matchId end
        local status = (r.modelVersion == 1 or r.modelVersion == 2 or r.modelVersion == 3) and r.status == "matched-request-history-only" and "matched-request" or r.status
        if r.duelMode then lines[#lines + 1] = "  Mode: " .. r.duelMode .. " | " .. tostring(r.modeReason) end
        lines[#lines + 1] = string.format("#%d %s | %s > %s | %s | %s", r.id,
            date("%Y-%m-%d %H:%M:%S", r.timestamp), r.winner, r.loser, r.outcome, status)
        if r.duration then
            lines[#lines + 1] = string.format("  Duration: %.2fs (%s)", r.duration, r.durationQuality)
        end
        local d = rating.applied[r.id]
        if r.periodId and seasons[r.periodId] then
            local sd = seasons[r.periodId].applied[r.id]
            lines[#lines + 1] = "  Local season: " .. r.periodId
            if sd and sd.eligible then lines[#lines + 1] = string.format("  Season rating: %.2f -> %.2f (%+.2f)", sd.before, sd.after, sd.delta) end
        end
        if d and d.eligible then
            lines[#lines + 1] = string.format("  Rating: %.1f -> %.1f (%+.2f); opponent %.1f -> %.1f; pair #%d, %.0f%% value",
                d.before, d.after, d.delta, d.opponentBefore, d.opponentAfter, d.pairNumber, d.weight * 100)
        elseif d then lines[#lines + 1] = "  No rating change: " .. d.reason end
        if d and d.matchup then
            local m = d.matchup
            lines[#lines + 1] = string.format("  vs %s matchup: %.2f -> %.2f (%+.2f); reciprocal vs %s: %.2f -> %.2f",
                m.class, m.before, m.after, m.delta, m.playerClass, m.opponentBefore, m.opponentAfter)
        end
    end
    lines[#lines + 1] = "\nRECOVERY ACCEPTANCE AUDIT"
    for _, event in ipairs(observer.recoveryAudit or {}) do
        lines[#lines + 1] = string.format("%s | %s | #%d %s | %.2f -> %.2f", date("%Y-%m-%d %H:%M:%S", event.at),
            event.action, event.recordId, event.opponent, event.before, event.after)
    end
    lines[#lines + 1] = "\nRECENT ACTIVITY"
    for _, a in ipairs(observer.activity) do
        lines[#lines + 1] = string.format("%s | %s | %s", date("%H:%M:%S", a.timestamp),
            a.status, a.session and a.session.opponent or "unknown")
    end
    lines[#lines + 1] = "\nTRACE (oldest to newest; latest " .. TRACE_LIMIT .. " events retained)"
    for _, t in ipairs(observer.trace) do
        lines[#lines + 1] = string.format("%s %.3f %s | %s", date("%H:%M:%S", t.at),
            t.elapsed, t.event, table.concat(t.args, " | "))
    end
    return table.concat(lines, "\n")
end

local function ShowExport(profile)
    if not DP.window then
        local window = CreateFrame("Frame", "RivalsCaptureWindow", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(700, 480)
        window:SetPoint("CENTER")
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        window.TitleText:SetText("Rivals - capture report (Ctrl+A, Ctrl+C)")
        local scroll = CreateFrame("ScrollFrame", nil, window)
        scroll:SetPoint("TOPLEFT", 14, -34)
        scroll:SetPoint("BOTTOMRIGHT", -23, 14)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(663)
        edit:SetMaxLetters(0)
        edit:SetScript("OnEscapePressed", function() window:Hide() end)
        scroll:SetScrollChild(edit)
        local scrollBar = DP.Theme and DP.Theme.ScrollBar and DP.Theme.ScrollBar(window, 32)
        if scrollBar then
            scrollBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -10, -34)
            scrollBar:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -10, 14)
            scrollBar:SetOnValueChanged(function(self, value)
                if self._syncing then return end
                local range = math.max(0, (edit:GetHeight() or 0) - (scroll:GetHeight() or 0))
                scroll:SetVerticalScroll(math.max(0, math.min(range, value or 0)))
            end)
            local function Sync(reset)
                local range = math.max(0, (edit:GetHeight() or 0) - (scroll:GetHeight() or 0))
                scrollBar._syncing = true; scrollBar:SetMinMaxValues(0, range); scrollBar:SetValue(reset and 0 or math.min(range, scroll:GetVerticalScroll() or 0)); scrollBar._syncing = false
                scrollBar:SetShown(range > 1)
                if reset then scroll:SetVerticalScroll(0) end
            end
            scroll:EnableMouseWheel(true)
            scroll:SetScript("OnMouseWheel", function(_, delta)
                local low, high = scrollBar:GetMinMaxValues()
                scrollBar:SetValue(math.max(low or 0, math.min(high or 0, (scrollBar:GetValue() or 0) - delta * 32)))
            end)
            window.SyncScrollbar = Sync
            window.scrollBar = scrollBar
        end
        window.edit = edit
        DP.window = window
        UISpecialFrames[#UISpecialFrames + 1] = "RivalsCaptureWindow"
    end
    local report = ExportText()
    if profile then
        local lines = {SummaryText(), "\nOPPONENTS (your record; local estimate)"}
        local entries = {}
        for _, opponent in pairs(rating.opponents) do entries[#entries + 1] = opponent end
        table.sort(entries, function(a, b) return a.name < b.name end)
        for _, opponent in ipairs(entries) do
            lines[#lines + 1] = string.format("%s | %d-%d | %.1f | %.2f weighted rating credit",
                opponent.name, opponent.wins, opponent.losses, opponent.rating, opponent.effective)
        end
        lines[#lines + 1] = "\nCLASSES (all tracked W/L since 0.2.0)"
        local classes = {}
        for class in pairs(rating.classes) do classes[#classes + 1] = class end
        table.sort(classes)
        for _, class in ipairs(classes) do
            local s = rating.classes[class]
            lines[#lines + 1] = string.format("%s | %d-%d", class, s.wins, s.losses)
        end
        local last = rating.last
        if last then
            local d = rating.applied[last.id]
            lines[#lines + 1] = string.format("\nLAST DUEL: %s vs %s | %+.2f | %s",
                last.won and "Win" or "Loss", last.opponent, d.delta, d.reason)
        end
        lines[#lines + 1] = "\n/rivals history for duel details; /rivals export for diagnostics."
        report = table.concat(lines, "\n")
    end
    DP.window.TitleText:SetText(profile and "Rivals - local rating" or "Rivals - report (Ctrl+A, Ctrl+C)")
    DP.window.edit:SetText(report)
    if DP.window.SyncScrollbar then DP.window.SyncScrollbar(true) end
    DP.window:Show()
    DP.window.edit:SetFocus()
    DP.window.edit:HighlightText()
end

local function Initialize()
    if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
        Say("This prototype supports Classic Era only.")
        return
    end
    if RivalsDB and RivalsDB.schemaVersion ~= 1 then
        Say("Unsupported saved-data version; capture disabled and data preserved.")
        return
    end
    RivalsDB = RivalsDB or {schemaVersion = 1, traceEnabled = false, observers = {}}
    db = RivalsDB
    if DP.Specs and DP.Specs.Initialize then DP.Specs.Initialize(db) end
    -- Sharing is the normal Rivals experience. Preserve an explicit legacy OFF,
    -- but migrate unset installs/settings to the new default.
    if db.shareProfile == nil then db.shareProfile = true end
    local player = UnitIdentity("player")
    if not player or not player.guid then Say("Player identity unavailable; capture disabled."); return end
    observer = db.observers[player.guid]
    if not observer then
        observer = {nextSequence = 1, results = {}, activity = {}, trace = {}}
        db.observers[player.guid] = observer
    end
    observer.name, observer.locale = player.name, GetLocale()
    if DP.WorldPvP and DP.WorldPvP.Initialize then
        DP.WorldPvP.Initialize(observer, db, {
            changed = function()
                if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
                if DP.RefreshDuelViews then DP.RefreshDuelViews() end
            end,
            saved = function(record)
                local color = DP.WorldPvP.ResultColor and DP.WorldPvP.ResultColor(record.resultKey) or "|cffffce70"
                local headcount = DP.WorldPvP.EncounterHeadcount and DP.WorldPvP.EncounterHeadcount(record) or
                    string.format("%dv%d", record.friendlyCount or 1, record.enemyCount or 0)
                Say(color .. (record.resultLabel or "World PvP") .. "|r: " ..
                    string.format("%s, %d %s, %s", headcount, record.enemyDeaths or 0,
                        (record.enemyDeaths or 0) == 1 and "kill" or "kills", record.playerDied and "death" or "survived"))
            end,
        })
    end
    local version, build = GetBuildInfo()
    observer.build = tostring(version) .. "." .. tostring(build)
    local ratingError
    rating, ratingError = DP.Periods.Rebuild(observer.results)
    if not rating then Say(ratingError .. "; capture disabled and data preserved."); return end
    seasons = ratingError
    observer.duelTargets, observer.ratingGuards = rating.opponents, rating.targets
    -- Migration baseline: existing progress is already earned, not a new gain.
    -- Subsequent gains stay pending across reloads until their reveal completes.
    observer.progressSeen = observer.progressSeen or {}
    local function Seed(key, state)
        if not observer.progressSeen[key] then
            observer.progressSeen[key] = {duels = math.min(10, DP.Rating.PlacementCount(state)), opponents = math.min(5, state.distinct)}
        end
    end
    Seed("lifetime", rating)
    for id, state in pairs(seasons) do Seed("season:" .. id, state) end
    observer.seasons = observer.seasons or {}
    recovery = DP.Recovery.New({guid = player.guid, playerClass = player.class, guardPolicy = 1, now = time, after = C_Timer.After,
        statusChanged = function() if DP.RefreshDuelViews then DP.RefreshDuelViews() end end,
        enabled = function() return db.verifyResults ~= false end,
        nextToken = function()
            observer.recoverySequence = (observer.recoverySequence or 0) + 1
            return time() .. "-" .. observer.recoverySequence
        end,
        send = function(message, target)
            if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                pcall(C_ChatInfo.SendAddonMessage, DP.Recovery.prefix, message, "WHISPER", target)
            end
        end,
        changed = function(item)
            Say("Interrupted duel vs " .. item.name .. ": " .. item.status .. ". See /rivals interrupted.")
            if DP.RefreshDuelViews then DP.RefreshDuelViews() end
        end,
    }, observer)
    for _, period in ipairs(observer.seasons) do seasons[period.id] = seasons[period.id] or DP.Rating.New() end
    tracker = DP.Tracker.New(player.name, function(record)
        record.timestamp, record.build, record.locale = time(), observer.build, observer.locale
        record.captureVersion = VERSION
        if record.kind == "result" then
            record.modelVersion = 3
            record.guardPolicy = 1
            record.playerLevel = record.session and record.session.playerLevel
            if record.session and verifier then verifier:LockMode(record.session) end
            record.duelMode = record.session and record.session.duelMode or "casual"
            record.modeReason = record.session and record.session.modeReason or "No matched pre-duel agreement"
            record.modeFailure = record.session and record.session.modeFailure
            record.playerClass = player.class
            record.periodId = record.session and record.session.periodId or observer.activeSeason
            record.id = observer.nextSequence
            observer.nextSequence = observer.nextSequence + 1
            observer.results[#observer.results + 1] = record
            local decision = DP.Rating.Apply(rating, record)
            if record.periodId then
                seasons[record.periodId] = seasons[record.periodId] or DP.Rating.New()
                record.seasonDecision = DP.Rating.Apply(seasons[record.periodId], record, decision)
            end
            record.ratingEligible = decision.eligible
            record.ratingDecision = decision
            if DP.Usage and DP.Usage.CaptureDuelConsumableCost then
                record.duelConsumableCost = DP.Usage.CaptureDuelConsumableCost(record)
            end
            if verifier then verifier:Finish(record) end
            if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
            Say((record.won and "Win" or "Loss") .. " vs " .. record.opponent ..
                (decision.eligible and string.format(" | %+.2f -> %.1f | %.0f%% value", decision.delta,
                    rating.rating, decision.weight * 100) .. " (lifetime)" or " | History only: " .. decision.reason))
            if record.seasonDecision and record.seasonDecision.eligible then
                Say(string.format("Season %d: %+.2f -> %.1f", record.periodId, record.seasonDecision.delta, record.seasonDecision.after))
            end
        else
            if record.status ~= "cancelled" then recovery:Remember(record.session) end
            if verifier then verifier:Cancel(record.session) end
            BoundedAppend(observer.activity, record, ACTIVITY_LIMIT)
        end
    end)
    if observer.pending then
        recovery:Remember(observer.pending)
        BoundedAppend(observer.activity, {kind = "activity", status = "reload-unresolved",
            timestamp = time(), session = observer.pending}, ACTIVITY_LIMIT)
        observer.pending = nil
    end
    parsers = {
        {key = "DUEL_WINNER_KNOCKOUT", outcome = "knockout"},
        {key = "DUEL_WINNER_RETREAT", outcome = "retreat"},
    }
    for _, parser in ipairs(parsers) do
        parser.compiled = DP.Parser.Compile(_G[parser.key])
        if not parser.compiled then Say(parser.key .. " unavailable/unsupported; that result parser is disabled.") end
    end
    DP.Usage.Scan()
    ready = true
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, DP.Verification.prefix) end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, DP.Recovery.prefix) end
    verifier = DP.Verification.New({
        canSend = function(entry)
            if entry.session and entry.session.identity and entry.session.identity.whisperBlocked then return false end
            for _, unit in ipairs({"target", "mouseover"}) do
                if UnitExists(unit) and UnitGUID(unit) == entry.guid and not DP.CanWhisperUnit(unit) then return false end
            end
            return not entry.offline
        end,
        guid = player.guid, now = GetTime, timestamp = time, after = C_Timer.After, trace = Trace,
        modeLocked = function(session)
            Say("Duel mode: " .. session.duelMode .. " | " .. session.modeReason)
            if session.modeFailure then Say(session.modeFailure) end
            if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
        end,
        modeReady = function(session)
            Say(session.modePreference == "rated" and session.peerMode == "rated" and
                "Rivals Rated agreement complete. Mode locks at the duel start." or "Casual agreed: this duel will not change ratings.")
            if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
        end,
        enabled = function() return db.verifyResults ~= false end,
        nextToken = function()
            observer.verificationSequence = (observer.verificationSequence or 0) + 1
            return tostring(time()) .. "-" .. observer.verificationSequence
        end,
        send = function(message, target)
            if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                local ok, result = pcall(C_ChatInfo.SendAddonMessage, DP.Verification.prefix, message, "WHISPER", target)
                Trace("VERIFY_TRANSPORT", ok, tostring(result), target)
            end
        end,
        changed = function(record)
            Say("Duel vs " .. record.opponent .. ": " .. DP.Verification.Label(record) .. ".")
            if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
        end,
    })
    DP.Inspect.Initialize(function() return rating end, db)
    DP.Inspect.Install()
    DP.InstallPlayerTooltip(function() return rating end)
    DP.InstallCharacterTab(DisplayRating, DisplayRecords)
    for _, event in ipairs({"DUEL_REQUESTED", "DUEL_FINISHED", "DUEL_INBOUNDS", "DUEL_OUTOFBOUNDS",
        "DUEL_TO_THE_DEATH_REQUESTED", "CHAT_MSG_SYSTEM", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "UNIT_AURA", "PLAYER_ENTERING_WORLD",
        "PLAYER_DEAD", "PLAYER_LOGOUT", "START_TIMER", "MIRROR_TIMER_START", "ADDON_LOADED", "CHAT_MSG_ADDON",
        "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "COMBAT_LOG_EVENT_UNFILTERED",
        "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "INSPECT_READY",
        "CHAT_MSG_COMBAT_HONOR_GAIN", "SCREENSHOT_SUCCEEDED", "SCREENSHOT_FAILED"}) do
        local ok = pcall(frame.RegisterEvent, frame, event)
        if not ok then Trace("UNSUPPORTED_EVENT", event) end
    end
    if type(StartDuel) == "function" then
        hooksecurefunc("StartDuel", function(unit)
            local identity = UnitIdentity(unit)
            Trace("HOOK_StartDuel", unit, identity and identity.name)
            if identity then Request(identity.name, "outgoing-intent", false, identity) end
        end)
    end
    Trace("CAPTURE_LOGIN", observer.build, observer.locale)
    Say("Local rating " .. string.format("%.1f", rating.rating) .. ". Character pane > Duels, or /rivals.")
    DP.RetryRecovery()
    C_Timer.After(35, DP.RetryRecovery)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then Initialize(); return end
    if not ready then return end
    if event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
        FinishRivalsScreenshotStatus()
        return
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if tracker.session then DP.Usage.Combat(tracker.session, UnitGUID("player")) end
        if DP.WorldPvP and DP.WorldPvP.Combat then DP.WorldPvP.Combat(UnitGUID("player")) end
        return
    end
    if DP.WorldPvP and DP.WorldPvP.Event then DP.WorldPvP.Event(event, ...) end
    if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "GET_ITEM_INFO_RECEIVED" then
        DP.Usage.Scan(); return
    end
    if event == "CHAT_MSG_ADDON" then
        DP.Inspect.Receive(...)
        local prefix, message, channel, sender = ...
        if prefix == DP.Recovery.prefix and channel == "WHISPER" and type(sender) == "string" then
            if not sender:find("-", 1, true) then sender = sender .. "-" .. GetNormalizedRealmName() end
            recovery:Receive(message, sender)
        end
        if prefix == DP.Verification.prefix and channel == "WHISPER" and type(sender) == "string" then
            if not sender:find("-", 1, true) then sender = sender .. "-" .. GetNormalizedRealmName() end
            local packet = DP.Verification.Parse(message)
            local session = tracker.session
            if packet and packet[1] == "H" and session and not session.identity and not session.excluded and
                DP.Parser.SameName(session.opponent, sender) and packet[3] ~= UnitGUID("player") then
                session.identity = {name = sender, guid = packet[3]}
                Trace("VERIFY_IDENTITY_FROM_PEER", sender, packet[3])
                verifier:Begin(session)
                PersistSession()
            end
            verifier:Receive(message, sender)
        end
        return
    end
    if event == "INSPECT_READY" then
        local guid = ...
        local profile = DP.Specs and DP.Specs.CaptureInspect and DP.Specs.CaptureInspect(guid, InspectFrame and InspectFrame.unit)
        if profile then
            local bound = BindInspectSpecToOneDuel(profile)
            if DP.Inspect and DP.Inspect.SpecUpdated then DP.Inspect.SpecUpdated(guid, profile) end
            if bound and DP.Usage and DP.Usage.RefreshSpecDisplays then DP.Usage.RefreshSpecDisplays() end
            if DP.RefreshDuelViews then DP.RefreshDuelViews() end
            if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
        end
        return
    end
    Trace(event, ...)
    local first = ...
    if event == "ADDON_LOADED" then
        DP.Inspect.Install()
        DP.InstallCharacterTab(DisplayRating, DisplayRecords)
    elseif event == "DUEL_REQUESTED" or event == "DUEL_TO_THE_DEATH_REQUESTED" then
        Request(first, "incoming", event == "DUEL_TO_THE_DEATH_REQUESTED")
    elseif event == "DUEL_FINISHED" then
        local id = tracker:Finished(GetTime())
        PersistSession()
        if id then C_Timer.After(3, function() tracker:Expire(id, GetTime()); PersistSession() end) end
    elseif event == "CHAT_MSG_SYSTEM" then
        if type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string" then
            for _, entry in pairs(verifier.entries) do
                if first == string.format(ERR_CHAT_PLAYER_NOT_FOUND_S, entry.name) or
                    first == string.format(ERR_CHAT_PLAYER_NOT_FOUND_S, entry.name:match("^[^-]+")) then entry.offline = true end
            end
        end
        local seconds = DP.Parser.Countdown(_G.DUEL_COUNTDOWN, first)
        if seconds then
            if tracker.session and not tracker.session.identity then tracker.session.identity = FindIdentity(tracker.session.opponent) end
            if tracker.session and DP.Usage and DP.Usage.CaptureDuelBuffs then DP.Usage.CaptureDuelBuffs(tracker.session) end
            if verifier then verifier:Begin(tracker.session) end
            local accepted = tracker:Countdown(seconds, GetTime())
            if accepted then
                local session = tracker.session
                verifier:ModePulse(session)
                if not session.previewShown then
                    session.previewShown = true
                    local identity = session.identity
                    if session.modePreference == "casual" then
                        Say("Casual preference: this duel will not change ratings.")
                    elseif identity and identity.guid then
                        local opponent = rating.opponents[identity.guid]
                        local before = opponent and opponent.rating or 1500
                        local count = 0
                        for _, at in ipairs(rating.pairs[identity.guid] or {}) do if at > time() - 86400 then count = count + 1 end end
                        local weight = DP.Rating.Weight(count)
                        Say(string.format("If Rated (local lifetime estimate): win %+.2f / loss %+.2f; %.0f%% value, pair #%d.",
                            DP.Rating.Delta(rating.rating, before, true, weight), DP.Rating.Delta(rating.rating, before, false, weight), weight * 100, count + 1))
                        if observer.activeSeason then
                            local sr = seasons[observer.activeSeason]
                            local so = sr.opponents[identity.guid]
                            Say(string.format("If Rated (Season %d): win %+.2f / loss %+.2f.", observer.activeSeason,
                                DP.Rating.Delta(sr.rating, so and so.rating or 1500, true, weight),
                                DP.Rating.Delta(sr.rating, so and so.rating or 1500, false, weight)))
                        end
                    end
                end
                C_Timer.After(seconds, function()
                    if tracker.session == session and GetTime() >= session.estimatedStartAt then
                        if DP.Usage and DP.Usage.CaptureDuelBuffs then DP.Usage.CaptureDuelBuffs(session) end
                        verifier:LockMode(session)
                    end
                end)
            end
            Trace("COUNTDOWN_CLASSIFICATION", accepted, seconds)
            PersistSession()
            return
        end
        for _, parser in ipairs(parsers) do
            local winner, loser = DP.Parser.Match(parser.compiled, first)
            if winner then
                local accepted, reason = tracker:Result(winner, loser, parser.outcome, GetTime())
                Trace("RESULT_CLASSIFICATION", accepted, reason, winner, loser)
                -- Anchor duel screenshots to the localized result message rather than
                -- DUEL_FINISHED. Waiting one short render window lets Blizzard's
                -- "has defeated ... in a duel" feedback actually appear on screen.
                -- Only local-player victories are captured. Losses and
                -- recovered/duplicate result chatter do not create screenshots.
                if accepted and reason ~= "recovered-history-only" and
                    DP.Parser.SameName(winner, tracker.playerName) then
                    ScheduleDuelScreenshot(loser)
                end
                PersistSession()
                return
            end
        end
        if first == _G.ERR_DUEL_REQUESTED then
            -- Server acknowledgement must not replace hook-captured identity if the target changed.
            if tracker.session then Trace("REQUEST_ACKNOWLEDGED"); return end
            local identity = UnitIdentity("target")
            if identity then Request(identity.name, "outgoing-intent", false, identity) end
        end
    elseif event == "UI_INFO_MESSAGE" then
        local _, message = ...
        -- Prefer the localized client constant. English fallback is evidenced by the 1.15.9 trace.
        local cancelled = _G.ERR_DUEL_CANCELLED
        if (type(cancelled) == "string" and message == cancelled) or
            (GetLocale() == "enUS" and message == "Duel cancelled.") then
            tracker:Close("cancelled", GetTime())
            Trace("CANCELLATION_CLASSIFICATION", "cancelled")
            PersistSession()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        local identity = tracker.session and FindIdentity(tracker.session.opponent)
        if identity and tracker.session then
            tracker.session.identity = identity
            if verifier then verifier:Begin(tracker.session) end
            PersistSession()
        end
        DP.RetryRecovery()
    elseif event == "PLAYER_ENTERING_WORLD" then
        tracker:Close("world-change-unresolved", GetTime())
        PersistSession()
    elseif event == "PLAYER_LOGOUT" then
        PersistSession()
    end
end)

SLASH_RIVALS1 = "/rivals"
SlashCmdList.RIVALS = function(command)
    if not ready then Say("Capture is not available on this client or saved-data version."); return end
    command = (command or ""):lower():match("^%s*(.-)%s*$")
    if command == "" or command == "rating" then
        if DP.ShowRivalsCharacterPanel then DP.ShowRivalsCharacterPanel()
        else Say("Character pane is not available yet; open it and try again.") end
    elseif command == "season start" then
        if tracker.session then Say("Finish or cancel the current duel before starting a season."); return end
        local id = #observer.seasons + 1
        observer.seasons[id] = {id = id, startedAt = time()}
        if observer.activeSeason then observer.seasons[observer.activeSeason].endedAt = time() end
        observer.activeSeason = id
        seasons[id] = DP.Rating.New()
        selectedPeriod = id
        Say("Season " .. id .. " started at 1500. Lifetime ratings and repeat limits continue.")
        if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
    elseif command == "lifetime" then
        selectedPeriod = nil
        if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
    elseif command == "season" then
        selectedPeriod = observer.activeSeason
        if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
    elseif command == "world" then
        if DP.WorldPvP and DP.WorldPvP.SetOverviewMode then DP.WorldPvP.SetOverviewMode("world") end
        if DP.SelectDuelView then DP.SelectDuelView("Overview") end
        if DP.ShowRivalsCharacterPanel then DP.ShowRivalsCharacterPanel() end
    elseif command == "graph" then
        if DP.SelectDuelView then DP.SelectDuelView("Graph") end
        if DP.ShowRivalsCharacterPanel then DP.ShowRivalsCharacterPanel() end
    elseif command == "mode rated" or command == "mode casual" then
        DP.ToggleDuelMode(command == "mode rated" and "rated" or "casual")
    elseif command == "verify on" or command == "verify off" then
        db.verifyResults = command == "verify on"
        if not db.verifyResults then verifier.entries = {}; verifier.current = nil end
        Say("Duel result exchange " .. (db.verifyResults and "on" or "off") .. ".")
        if DP.RefreshCharacterTab then DP.RefreshCharacterTab() end
    elseif command == "share on" or command == "share off" then
        DP.SetProfileSharing(command == "share on")
    elseif command == "trace on" or command == "trace off" then
        db.traceEnabled = command == "trace on"
        Trace("TRACE_ENABLED")
        Say("Diagnostic trace " .. (db.traceEnabled and "on" or "off") .. ".")
    elseif command == "interrupted" then
        DP.RetryRecovery()
        if DP.SelectDuelView then DP.SelectDuelView("Interrupted") end
        if DP.ShowRivalsCharacterPanel then DP.ShowRivalsCharacterPanel() end
    elseif command == "history" or command == "opponents" or command == "classes" or command == "leaderboard" then
        if DP.SelectDuelView then
            DP.SelectDuelView(command:sub(1, 1):upper() .. command:sub(2))
            if DP.ShowRivalsCharacterPanel then DP.ShowRivalsCharacterPanel() end
        end
    elseif command == "export" then
        ShowExport()
    elseif command == "status" then
        Say(#observer.results .. " captured results; " .. #observer.trace .. " trace events; trace " ..
            (db.traceEnabled and "on" or "off") .. "; session " .. (tracker.session and tracker.session.state or "idle") .. ".")
    else
        Say("/rivals rating | world | graph | history | opponents | classes | leaderboard | lifetime | season | season start | export | status | mode rated | mode casual | verify on | verify off | share on | share off")
        Say("/rivals rating opens your local profile. Enable trace only for diagnostics.")
    end
end
