local _, DP = ...
local R = {prefix = "RivalsRecover1"}
R.__index = R
DP.Recovery = R

local function guid(s) return type(s) == "string" and #s <= 60 and s:match("^Player%-%x+%-%x+$") end
local function token(s) return type(s) == "string" and #s <= 50 and s:match("^%d+%-%d+$") end
function R.Parse(message)
    if type(message) ~= "string" or #message > 240 then return end
    local p = {}
    for part in (message .. "|"):gmatch("(.-)|") do p[#p + 1] = part end
    if p[1] == "Q" and #p == 3 and token(p[2]) and guid(p[3]) then return p end
    if p[1] == "E" and #p == 4 and token(p[2]) and guid(p[3]) and p[4]:match("^%d+$") and tonumber(p[4]) <= 10 then return p end
    if p[1] == "S" and #p == 10 and token(p[2]) and guid(p[3]) and token(p[4]) and token(p[5]) and guid(p[6]) and
        p[7]:match("^%d+$") and #p[7] <= 12 and (p[8] == "knockout" or p[8] == "retreat") and
        (p[9] == "rated" or p[9] == "casual") and p[10] == "1" then return p end
end

function R.New(config, observer)
    observer.interrupted = observer.interrupted or {}
    observer.recoveryAudit = observer.recoveryAudit or {}
    return setmetatable({config = config, observer = observer, pending = {}, lastReply = {}, lastQuery = {}}, R)
end

function R:AcceptedItems()
    local items = {}
    for _, record in ipairs(self.observer.results) do
        if record.provenance == "peer-recovery" and record.acceptedPeerReport then
            items[#items + 1] = {record = record, name = record.opponent, timestamp = record.timestamp,
                won = record.won, periodId = record.periodId, acceptedAt = record.acceptedAt}
        end
    end
    table.sort(items, function(a, b) return a.acceptedAt > b.acceptedAt end)
    return items
end

function R:PreviewUndo(item)
    local records, found = {}, false
    for _, record in ipairs(self.observer.results) do
        if record == item.record and record.provenance == "peer-recovery" and record.acceptedPeerReport then found = true
        else records[#records + 1] = record end
    end
    if not found then return nil, "This accepted report is no longer in the record." end
    local rating, seasons = DP.Periods.Rebuild(records)
    if not rating then return nil, seasons end
    return {record = item.record, records = records, rating = rating, seasons = seasons, count = #self.observer.results}
end

function R:RestoreReport(record)
    local s = record.session
    local report
    for _, item in ipairs(self.observer.interrupted) do
        if item.token == s.verificationToken and item.guid == s.identity.guid then report = item; break end
    end
    if not report then
        report = {token = s.verificationToken, peerToken = s.peerVerificationToken, guid = s.identity.guid,
            name = record.opponent, timestamp = record.timestamp, won = record.won, outcome = record.outcome,
            winner = record.won and self.config.guid or s.identity.guid, mode = record.duelMode,
            periodId = record.periodId, class = s.identity.class, status = "Peer-reported"}
        self.observer.interrupted[#self.observer.interrupted + 1] = report
    end
    report.appliedId = nil
end

function R:Remember(session)
    if not session or session.excluded or not session.verificationToken or not session.identity then return end
    for _, item in ipairs(self.observer.interrupted) do if item.token == session.verificationToken then return end end
    local list = self.observer.interrupted
    list[#list + 1] = {token = session.verificationToken, name = session.identity.name, guid = session.identity.guid,
        timestamp = session.startedTimestamp or self.config.now(), status = "Unresolved", mode = session.duelMode or "unknown",
        periodId = session.periodId, class = session.identity.class}
    if #list > 100 then table.remove(list, 1) end
end

function R:Request(identity)
    if not self.config.enabled() then self:SetStatus("Recovery disabled: /rivals verify on"); return end
    if not identity or not guid(identity.guid) or identity.guid == self.config.guid or
        type(identity.name) ~= "string" or #identity.name > 100 then return end
    local now = self.config.now()
    if self.lastQuery[identity.guid] and now - self.lastQuery[identity.guid] < 30 then
        self:SetStatus("Retry available in " .. (30 - (now - self.lastQuery[identity.guid])) .. " seconds."); return
    end
    self.lastQuery[identity.guid] = now
    local nonce = self.config.nextToken()
    self.pending[identity.guid] = {name = identity.name, nonce = nonce, expires = now + 20}
    self:SetStatus("Requesting recovery from " .. identity.name .. "...")
    self.config.send("Q|" .. nonce .. "|" .. self.config.guid, identity.name)
    if self.config.after then self.config.after(20, function()
        local pending = self.pending[identity.guid]
        if pending and pending.nonce == nonce and not pending.replied then
            self:SetStatus("No reply. Check both clients are updated and verification is on.")
        end
    end) end
end

function R:SetStatus(message)
    self.status = message
    if self.config.statusChanged then self.config.statusChanged() end
end

function R:Receive(message, sender)
    if not self.config.enabled() then return end
    local p = R.Parse(message)
    if not p then return end
    local now = self.config.now()
    if p[1] == "Q" then
        if self.lastReplyAt and now - self.lastReplyAt < 2 then return end
        if self.lastReply[sender] and now - self.lastReply[sender] < 5 then return end
        self.lastReplyAt = now
        for name, at in pairs(self.lastReply) do if now - at > 60 then self.lastReply[name] = nil end end
        self.lastReply[sender] = now
        local sent = 0
        for i = #self.observer.results, 1, -1 do
            local record = self.observer.results[i]
            local s = record.session
            if record.provenance ~= "peer-recovery" and record.timestamp >= now - 86400 and record.timestamp <= now and record.status == "matched-request-history-only" and
                s and s.identity and s.identity.guid == p[3] and s.identity.name == sender and token(s.verificationToken) and token(s.peerVerificationToken) then
                self.config.send(table.concat({"S", p[2], self.config.guid, s.verificationToken, s.peerVerificationToken,
                    record.won and self.config.guid or p[3], record.timestamp, record.outcome, record.duelMode or "casual", "1"}, "|"), sender)
                sent = sent + 1
                if sent >= 10 then break end
            end
        end
        self.config.send("E|" .. p[2] .. "|" .. self.config.guid .. "|" .. sent, sender)
        return
    end
    local pending = self.pending[p[3]]
    if p[1] == "E" then
        if not pending or pending.name ~= sender or pending.nonce ~= p[2] or now > pending.expires then return end
        pending.replied = true
        self:SetStatus(p[4] == "0" and "Peer replied: no recoverable results with saved handshake tokens." or
            "Peer replied: " .. p[4] .. " reports sent; duplicates excluded.")
        return
    end
    local at = tonumber(p[7])
    if not pending or pending.name ~= sender or pending.nonce ~= p[2] or now > pending.expires or
        at < now - 86400 or at > now or (p[6] ~= p[3] and p[6] ~= self.config.guid) then return end
    -- Never import an already observed result, even when its confirmation was lost.
    for _, record in ipairs(self.observer.results) do
        local s = record.session
        if s and s.verificationToken == p[5] and s.identity and s.identity.guid == p[3] then return end
    end
    local item
    for _, existing in ipairs(self.observer.interrupted) do
        if existing.token == p[5] and existing.guid == p[3] then item = existing; break end
    end
    if not item then
        item = {token = p[5], guid = p[3], name = sender}
        local list = self.observer.interrupted
        list[#list + 1] = item
        if #list > 100 then table.remove(list, 1) end
    end
    if item.winner and (item.winner ~= p[6] or item.outcome ~= p[8] or item.peerToken ~= p[4]) then
        item.status = "Conflicting peer reports"
    elseif not item.winner then
        item.status, item.winner, item.outcome = "Peer-reported", p[6], p[8]
        item.timestamp, item.receivedAt, item.peerToken, item.mode = at, now, p[4], p[9]
        item.won = p[6] == self.config.guid
    else return end
    if self.config.changed then self.config.changed(item) end
end

function R:Preview(item)
    local present = false
    for _, entry in ipairs(self.observer.interrupted) do if entry == item then present = true end end
    if not present or item.status ~= "Peer-reported" or not item.winner or item.appliedId then return nil, "This report cannot be applied." end
    for _, record in ipairs(self.observer.results) do
        local s = record.session
        if s and s.verificationToken == item.token and s.identity and s.identity.guid == item.guid then return nil, "Already recorded." end
    end
    local record = {id = self.observer.nextSequence, kind = "result", modelVersion = 3, guardPolicy = self.config.guardPolicy,
        timestamp = item.timestamp, status = "matched-request-history-only", provenance = "peer-recovery",
        acceptedPeerReport = true, acceptedAt = self.config.now(), won = item.won, opponent = item.name,
        winner = item.won and self.observer.name or item.name, loser = item.won and item.name or self.observer.name,
        outcome = item.outcome, duelMode = item.mode, modeReason = "User accepted peer-reported mode and result",
        periodId = item.periodId, playerClass = self.config.playerClass, durationQuality = "unknown",
        session = {verificationToken = item.token, peerVerificationToken = item.peerToken,
            opponent = item.name, identity = {name = item.name, guid = item.guid, class = item.class}},
        verification = {status = "peer-reported", reason = "Recovered report explicitly accepted locally; not independently observed."}}
    local records, inserted = {}, false
    for _, existing in ipairs(self.observer.results) do
        if not inserted and existing.timestamp > record.timestamp then records[#records + 1] = record; inserted = true end
        records[#records + 1] = existing
    end
    if not inserted then records[#records + 1] = record end
    local rating, seasons = DP.Periods.Rebuild(records)
    if not rating then return nil, seasons end
    return {record = record, records = records, rating = rating, seasons = seasons, count = #self.observer.results}
end

function R:Items()
    local items = {}
    for _, item in ipairs(self.observer.interrupted) do
        local observed = false
        for _, record in ipairs(self.observer.results) do
            local s = record.session
            if s and s.verificationToken == item.token and s.identity and s.identity.guid == item.guid then observed = true; break end
        end
        if not observed then items[#items + 1] = item end
    end
    table.sort(items, function(a, b) return a.timestamp > b.timestamp end)
    return items
end
