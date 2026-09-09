local _, DP = ...

-- Read-only local knowledge: hovering never requests or broadcasts a profile.
function DP.InstallPlayerTooltip(getRating)
    if DP.tooltipInstalled or not GameTooltip or not GameTooltip.HookScript then return end
    DP.tooltipInstalled = true
    local displayedGUID
    GameTooltip:HookScript("OnTooltipCleared", function() displayedGUID = nil end)
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        local _, unit = self:GetUnit()
        if not unit or not UnitIsPlayer(unit) then return end
        local guid = UnitGUID(unit)
        if not guid or guid == displayedGUID then return end
        local rating = getRating()
        if not rating then return end
        local known = rating.opponents[guid]
        if not known then
            local name, realm = UnitName(unit)
            if name then
                known = rating.opponents[name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName())]
            end
        end
        if not known then return end
        displayedGUID = guid
        self:AddLine(" ")
        self:AddLine("Rivals - your local records", 1, 0.82, 0)
        self:AddLine(string.format("Your record: %d-%d", known.wins, known.losses), 1, 1, 1)
        if known.effective > 0 then
            self:AddLine(string.format("Local estimate: %.1f (%.2f effective duels)", known.rating, known.effective), 0.8, 0.8, 0.8)
        else self:AddLine("Local rating: unknown", 0.8, 0.8, 0.8) end
        if known.lastAt then self:AddLine("Last duel: " .. date("%m/%d %H:%M", known.lastAt), 0.8, 0.8, 0.8) end
        self:Show()
    end)
end
