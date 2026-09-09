local _, DP = ...
local V = {}
V.__index = V
DP.Verification = V
V.prefix = "RivalsResult1"

function V.Label(record)
    local status = record.verification and record.verification.status
    if status == "peer-reported" then return "Peer-reported; accepted locally"
    elseif status == "confirmed" then return "Confirmed by both clients"
    elseif status == "disputed" then return "Disputed" end
    return "Local only"
end

function V.New(config)
    return setmetatable({config = config, entries = {}, order = {}}, V)
end

function V:Trace(event, ...)
    if self.config.trace then self.config.trace(event, ...) end
end

local function Token(value)
    return type(value) == "string" and #value <= 50 and value:match("^[%d%-]+$")
end

local function GUID(value)
    return type(value) == "string" and #value <= 60 and value:match("^Player%-%x+%-%x+$")
end

function V.Parse(message)
    if type(message) ~= "string" or #message > 240 then return nil end
    local p = {}
    for part in (message .. "|"):gmatch("(.-)|") do p[#p + 1] = part end
    if p[1] == "H" and #p == 3 and Token(p[2]) and GUID(p[3]) then return p end
    if p[1] == "A" and #p == 4 and Token(p[2]) and Token(p[3]) and GUID(p[4]) then return p end
    if (p[1] == "M" or p[1] == "C") and #p == 4 and Token(p[2]) and Token(p[3]) and
        (p[4] == "rated" or p[4] == "casual") then return p end
    if p[1] == "R" and #p == 5 and Token(p[2]) and Token(p[3]) and GUID(p[4]) and
        (p[5] == "knockout" or p[5] == "retreat") then return p end
end

function V:Send(entry, packet)
    if self.config.enabled() and self.entries[entry.token] == entry and
        (not self.config.canSend or self.config.canSend(entry)) then
        self:Trace("VERIFY_SEND", packet[1], entry.name, entry.token)
        self.config.send(table.concat(packet, "|"), entry.name)
    end
end

function V:Begin(session)
    if not self.config.enabled() or not session or session.excluded or session.verificationToken then return end
    local identity = session.identity
    if not identity or not GUID(identity.guid) or not identity.name or identity.guid == self.config.guid then return end
    local token = self.config.nextToken()
    local e = {token = token, name = identity.name, guid = identity.guid, expires = self.config.now() + 1800, session = session}
    session.verificationToken = token
    self:Trace("VERIFY_BEGIN", token, identity.name, identity.guid)
    self.entries[token], self.current = e, e
    self.order[#self.order + 1] = token
    if #self.order > 32 then self.entries[table.remove(self.order, 1)] = nil end
    local function hello()
        if not e.record and self.config.now() <= e.expires then self:Send(e, {"H", token, self.config.guid}) end
    end
    hello()
    self.config.after(1, hello); self.config.after(3, hello)
    local attempts = 0
    local function negotiate()
        if self.entries[token] ~= e or e.record or session.modeLocked or
            (session.estimatedStartAt and self.config.now() >= session.estimatedStartAt) then return end
        attempts = attempts + 1
        if not e.peerToken then hello() else self:ModePulse(session) end
        if attempts < 60 then self.config.after(.5, negotiate) end
    end
    self.config.after(.5, negotiate)
    self.config.after(1801, function() if self.entries[token] == e then self.entries[token] = nil end end)
end

function V:ModePulse(session)
    local e = session and self.entries[session.verificationToken]
    if not e or not e.peerToken or e.record or session.modeLocked then return end
    self:Send(e, {"M", e.peerToken, e.token, session.modePreference or "casual"})
end

function V:LockMode(session)
    if not session or session.modeLocked then return end
    session.modeLocked = true
    session.duelMode = session.modePreference == "rated" and session.peerMode == "rated" and session.modeAcknowledged and "rated" or "casual"
    session.modeReason = session.duelMode == "rated" and "Both clients agreed to Rated" or
        (session.modePreference == "casual" or session.peerMode == "casual") and "Casual preference" or "Rated agreement not completed before start"
    if session.duelMode ~= "rated" and session.modeReason ~= "Casual preference" then
        local entry = self.entries[session.verificationToken]
        session.modeFailure = not self.config.enabled() and "Verification is disabled on this client" or
            not session.identity and "Opponent identity was unavailable" or
            (not entry or not entry.peerToken) and "No completed handshake with opponent" or
            not session.peerMode and "Opponent mode was not received before start" or
            not session.modeAcknowledged and "Our preference was not acknowledged before start" or "Agreement incomplete at start"
    end
    self:Trace("VERIFY_MODE_LOCK", session.verificationToken or "none", session.modePreference or "unset",
        session.peerMode or "missing peer mode", session.modeAcknowledged or false, session.duelMode)
    if self.config.modeLocked then self.config.modeLocked(session) end
end

function V.AgreementStatus(session, enabled)
    if not session then return enabled == false and "Verification off: Rated agreement unavailable" or "No active duel; preference applies to the next duel" end
    if session.modeLocked then
        if session.duelMode == "rated" then return "This duel: Rated\nBoth clients agreed before start" end
        return "This duel: Casual\n" .. (session.modeFailure or session.modeReason or "No Rated agreement")
    end
    if enabled == false then return "Waiting for start: Casual fallback\nVerification is disabled on this client" end
    if session.modePreference == "casual" or session.peerMode == "casual" then return "Casual selected\nThis duel will not affect rating" end
    if session.peerMode == "rated" and session.modeAcknowledged then return "Rated agreement ready\nLocks when the duel starts" end
    return "Waiting for Rated agreement\nNo Rated guarantee until both clients agree"
end

function V:Cancel(session)
    local token = session and session.verificationToken
    if token then
        if self.current == self.entries[token] then self.current = nil end
        self.entries[token] = nil
    end
end

function V:Compare(e)
    if not e.record or not e.remoteWinner then return end
    local verification = e.record.verification
    local status = e.remoteWinner == e.winner and e.remoteOutcome == e.record.outcome and not e.conflict and "confirmed" or "disputed"
    if verification.status == "disputed" then status = "disputed" end
    if verification.status ~= status then
        verification.status = status
        verification.reason = nil
        verification.peerGUID = e.guid
        verification.peerWinnerGUID = e.remoteWinner
        verification.peerOutcome = e.remoteOutcome
        verification.receivedAt = self.config.timestamp()
        self.config.changed(e.record)
    end
end

function V:Report(e)
    if e.record and e.peerToken and self.config.now() <= e.expires then
        self:Send(e, {"R", e.peerToken, e.token, e.winner, e.record.outcome})
    end
end

function V:Finish(record)
    record.verification = {status = "local", reason = "No eligible handshake session"}
    local token = record.session and record.session.verificationToken
    local e = token and self.entries[token]
    if not e or not self.config.enabled() or record.status ~= "matched-request-history-only" or not record.duration then
        self:Cancel(record.session); return
    end
    e.record = record
    e.winner = record.won and self.config.guid or e.guid
    e.expires = self.config.now() + 15
    record.verification.reason = e.peerToken and "Waiting for peer result" or "Handshake incomplete"
    if e.peerToken then
        local a, b = self.config.guid .. ":" .. e.token, e.guid .. ":" .. e.peerToken
        record.verification.matchId = a < b and (a .. "/" .. b) or (b .. "/" .. a)
    end
    self:Compare(e)
    self:Report(e)
    for _, delay in ipairs({1, 3, 7, 12}) do self.config.after(delay, function() self:Report(e) end) end
    self.config.after(16, function()
        if record.verification.status == "local" then
            record.verification.reason = e.peerToken and "Peer result not received before timeout" or "Handshake incomplete"
            self:Trace("VERIFY_TIMEOUT", token, record.verification.reason)
        end
        if self.entries[token] == e then self.entries[token] = nil end
        if self.current == e then self.current = nil end
    end)
end

function V:Receive(message, sender)
    if not self.config.enabled() then return end
    local p = V.Parse(message)
    if not p then self:Trace("VERIFY_REJECT", "Malformed packet", sender); return end
    self:Trace("VERIFY_RECEIVE", p[1], sender, p[2])
    local now = self.config.now()
    if p[1] == "H" then
        local e = self.current
        if not e or e.record or e.name ~= sender or e.guid ~= p[3] or now > e.expires then
            self:Trace("VERIFY_REJECT", "Hello has no matching active session", sender); return
        end
        if e.lastAck and now - e.lastAck < .5 then return end
        e.lastAck = now
        self:Send(e, {"A", p[2], e.token, self.config.guid})
        -- The peer may acquire our identity after our initial retry window. Its hello
        -- must restart our half of the handshake as well as receive an acknowledgement.
        if not e.peerToken then self:Send(e, {"H", e.token, self.config.guid}) end
        return
    end
    local e = self.entries[p[2]]
    if not e or e.name ~= sender or now > e.expires then return end
    if p[1] == "A" then
        if e.record or e.guid ~= p[4] or (e.peerToken and e.peerToken ~= p[3]) then return end
        e.peerToken = p[3]
        e.session.peerVerificationToken = p[3]
        self:Trace("VERIFY_HANDSHAKE", e.token, e.peerToken, sender)
        self:ModePulse(e.session)
    elseif (p[1] == "M" or p[1] == "C") and e.peerToken == p[3] then
        local s = e.session
        if e.record or s.modeLocked or (s.estimatedStartAt and now >= s.estimatedStartAt) then return end
        if p[1] == "M" then
            if s.peerMode and s.peerMode ~= p[4] then return end
            s.peerMode = p[4]
            if not e.lastModeReply or now - e.lastModeReply >= .4 then
                e.lastModeReply = now
                self:Send(e, {"C", e.peerToken, e.token, p[4]})
                self:ModePulse(s)
            end
        elseif p[4] == (s.modePreference or "casual") then s.modeAcknowledged = true end
        if not s.modeNotice and (s.peerMode == "casual" or (s.peerMode == "rated" and s.modeAcknowledged)) then
            s.modeNotice = true
            if self.config.modeReady then self.config.modeReady(s) end
        end
    elseif p[1] == "R" and e.peerToken == p[3] then
        if p[4] ~= self.config.guid and p[4] ~= e.guid then return end
        if e.remoteWinner and (e.remoteWinner ~= p[4] or e.remoteOutcome ~= p[5]) then e.conflict = true end
        e.remoteWinner, e.remoteOutcome = p[4], p[5]
        self:Compare(e)
    end
end
