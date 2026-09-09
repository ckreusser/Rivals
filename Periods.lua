local _, DP = ...
local P = {}
DP.Periods = P

function P.Rebuild(records)
    local lifetime, err = DP.Rating.Rebuild(records)
    if not lifetime then return nil, err end
    local seasons = {}
    for _, record in ipairs(records) do
        if record.periodId then
            seasons[record.periodId] = seasons[record.periodId] or DP.Rating.New()
            DP.Rating.Apply(seasons[record.periodId], record, lifetime.applied[record.id])
        end
    end
    return lifetime, seasons
end

function P.Points(records, rating)
    local points = {{value = 1500, label = "Baseline", match = 0}}
    local count = 0
    for _, r in ipairs(records) do
        local d = rating.applied[r.id]
        if d and d.eligible then
            count = count + 1
            points[#points + 1] = {value = d.after, label = r.opponent, at = r.timestamp, match = count}
        end
    end
    -- Bound rendering while retaining a clearly labeled recent window and its preceding point.
    if #points > 101 then
        local recent = {}
        for i = #points - 100, #points do recent[#recent + 1] = points[i] end
        return recent
    end
    return points
end

function DP.InstallGraph(panel, getRating, getRecords)
    local frame = CreateFrame("Frame", nil, panel)
    frame:SetAllPoints(panel); frame:Hide()
    local function Label(y)
        local l = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 30, y); l:SetWidth(292); l:SetJustifyH("CENTER")
        return l
    end
    local title, range, caption = Label(-111), Label(-143), Label(-368)
    title:SetWidth(174); title:SetJustifyH("LEFT")
    local graph = CreateFrame("Frame", nil, frame)
    graph:SetSize(272, 190); graph:SetPoint("TOPLEFT", 40, -171)
    local bg = graph:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(graph); bg:SetColorTexture(.055, .075, .095, 1)
    for i = 0, 4 do
        local grid = graph:CreateTexture(nil, "BACKGROUND")
        grid:SetPoint("TOPLEFT", 0, -i * 47); grid:SetSize(272, 1); grid:SetColorTexture(.18, .20, .23, .7)
    end
    local lines, dots = {}, {}
    function DP.RefreshGraph()
        local r = getRating()
        local points = P.Points(getRecords(), r)
        local low, high = points[1].value, points[1].value
        for _, p in ipairs(points) do low = math.min(low, p.value); high = math.max(high, p.value) end
        if high - low < 20 then local mid = (high + low) / 2; low, high = mid - 10, mid + 10 end
        title:SetText("Rating history")
        range:SetText(string.format("Range: %.1f - %.1f | Current: %.1f", low, high, r.rating))
        caption:SetText(#points == 1 and "No eligible duels yet · Baseline 1500" or
            string.format("Matches %d–%d · Hover points for details", points[1].match, points[#points].match))
        for _, line in ipairs(lines) do line:Hide() end
        for _, dot in ipairs(dots) do dot:Hide() end
        local lastX, lastY
        for i, point in ipairs(points) do
            local x = #points == 1 and 136 or (i - 1) * 264 / (#points - 1) + 4
            local y = 4 + (point.value - low) * 182 / (high - low)
            if i > 1 then
                local line = lines[i - 1] or graph:CreateLine(nil, "ARTWORK")
                lines[i - 1] = line
                line:SetColorTexture(.84, .68, .36, 1); line:SetThickness(2)
                line:SetStartPoint("BOTTOMLEFT", lastX, lastY); line:SetEndPoint("BOTTOMLEFT", x, y); line:Show()
            end
            local dot = dots[i]
            if not dot then
                dot = CreateFrame("Button", nil, graph); dot:SetSize(4, 4)
                local texture = dot:CreateTexture(nil, "OVERLAY"); texture:SetAllPoints(dot); texture:SetColorTexture(1, .9, .4, 1)
                dot:SetScript("OnEnter", function(self)
                    local p = self.pointData
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(string.format("%.2f rating | Match %d", p.value, p.match))
                    GameTooltip:AddLine(p.label, 1, 1, 1)
                    if p.at then GameTooltip:AddLine(date("%m/%d %H:%M", p.at), 1, 1, 1) end
                    GameTooltip:Show()
                end)
                dot:SetScript("OnLeave", function() GameTooltip:Hide() end)
                dots[i] = dot
            end
            dot.pointData = point; dot:ClearAllPoints(); dot:SetPoint("CENTER", graph, "BOTTOMLEFT", x, y); dot:Show()
            lastX, lastY = x, y
        end
    end
    return frame
end
