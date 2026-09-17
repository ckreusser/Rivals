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
        local name, realm = UnitName(unit)
        local fullName = name and (name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName())) or nil
        if not known and fullName then known = rating.opponents[fullName] end

        local world
        if DP.WorldPvP and DP.WorldPvP.BuildMatchups then
            local data = DP.WorldPvP.BuildMatchups()
            for _, entry in ipairs(data.Opponents or {}) do
                if entry.key == guid or (fullName and DP.Parser and DP.Parser.SameName and DP.Parser.SameName(entry.name, fullName)) then
                    world = entry; break
                end
            end
        end
        if not known and not world then return end
        displayedGUID = guid
        self:AddLine(" ")
        self:AddLine("Rivals - your local records", 1, 0.82, 0)
        if known then
            self:AddLine(string.format("Your record: %d-%d", known.wins, known.losses), 1, 1, 1)
            if known.effective > 0 then
                self:AddLine(string.format("Local estimate: %.1f (%.2f effective duels)", known.rating, known.effective), 0.8, 0.8, 0.8)
            else self:AddLine("Local rating: unknown", 0.8, 0.8, 0.8) end
            if known.lastAt then self:AddLine("Last duel: " .. date("%m/%d %H:%M", known.lastAt), 0.8, 0.8, 0.8) end
        end
        if world then
            self:AddLine(string.format("World PvP: %d kills - %d deaths", world.kills or 0, world.deaths or 0), .40, .90, .68)
            if world.spec then self:AddLine("Last inferred spec: " .. world.spec, 0.8, 0.8, 0.8) end
            self:AddLine(string.format("Solo 1v1: %d-%d", world.soloKills or 0, world.soloDeaths or 0), 0.8, 0.8, 0.8)
            if world.lastAt then self:AddLine("Last world encounter: " .. date("%m/%d %H:%M", world.lastAt), 0.8, 0.8, 0.8) end
        end
        self:Show()
    end)
end
