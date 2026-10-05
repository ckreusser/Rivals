local _, DP = ...

local M = {}
DP.MultiKill = M

local WINDOW_SECONDS = 12

-- Reach-style medal feed presentation.
-- The newest medal always occupies the LEFT-most slot, matching Reach: the
-- caption describes that medal, while older medals are pushed to the right.
local MAX_VISIBLE_MEDALS = 4
local MEDAL_SIZE = 40
local MEDAL_GAP = 5
local MEDAL_STEP = MEDAL_SIZE + MEDAL_GAP
local MEDAL_SHIFT_SECONDS = 0.12
local MEDAL_SPAWN_DELAY = 0.035
local MEDAL_POP_SECONDS = 0.16
local MEDAL_LIFETIME = 3.75
local MEDAL_FADE_START = 3.25
local CAPTION_LIFETIME = 2.50
local CAPTION_FADE_START = 1.90
local KILL_FONT = "Fonts\\ARIALN.TTF"
local DEFAULT_POSITION_X, DEFAULT_POSITION_Y = 56, 0

-- Reach's cool blue HUD text.
local TEXT_R, TEXT_G, TEXT_B = 0.36, 0.66, 0.82
local SHADOW_R, SHADOW_G, SHADOW_B = 0.025, 0.09, 0.14

local medals = {
    [2] = {name = "Double Kill!", asset = "DoubleKill"},
    [3] = {name = "Triple Kill!", asset = "TripleKill"},
    [4] = {name = "Overkill!", asset = "Overkill"},
    [5] = {name = "Killtacular!", asset = "Killtacular"},
    [6] = {name = "Killtrocity!", asset = "Killtrocity"},
    [7] = {name = "Killimanjaro!", asset = "Killamanjaro"},
    [8] = {name = "Killtastrophe!", asset = "Killtastrophe"},
    [9] = {name = "Killpocalypse!", asset = "Killpocalypse"},
    [10] = {name = "Killionaire!", asset = "Killionaire"},
}

local count, lastKillAt = 0, nil
local eligibleCount, lastEligibleKillAt = 0, nil
local announcement

function M.IsEligibleLevel(level, playerLevel)
    level, playerLevel = tonumber(level), tonumber(playerLevel)
    if not level or level <= 0 or not playerLevel or playerLevel <= 0 then return false end
    local gray = playerLevel <= 5 and 0 or playerLevel <= 39 and
        (playerLevel - math.floor(playerLevel / 10) - 5) or
        (playerLevel - math.floor(playerLevel / 5) - 1)
    return level > gray
end

local function TexturePath(asset)
    return "Interface\\AddOns\\Rivals\\Textures\\MultiKill\\" .. asset .. ".tga"
end

local function SoundPath(asset)
    return "Interface\\AddOns\\Rivals\\Sounds\\MultiKill\\" .. asset .. ".wav"
end

local function Clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function Lerp(a, b, p)
    return a + (b - a) * p
end

local function EaseOutCubic(p)
    p = Clamp01(p)
    local q = 1 - p
    return 1 - (q * q * q)
end

local function SetSlotPosition(slot, index, offsetX)
    local x = (MEDAL_SIZE * 0.5) + ((index - 1) * MEDAL_STEP) + (offsetX or 0)
    slot:ClearAllPoints()
    slot:SetPoint("CENTER", slot:GetParent(), "TOPLEFT", x, -(MEDAL_SIZE * 0.5))
end

local function ResetMedalSlot(slot, index)
    if not slot then return end
    slot.entry = nil
    slot:SetScale(1)
    slot:SetAlpha(1)
    slot.icon:SetAlpha(1)
    if index then SetSlotPosition(slot, index, 0) end
    slot:Hide()
end

local function SavedPosition()
    if DP.GetKillstreakPosition then
        local x, y = DP.GetKillstreakPosition()
        if type(x) == "number" and type(y) == "number" then return x, y end
    end
    return DEFAULT_POSITION_X, DEFAULT_POSITION_Y
end

local function ApplyPosition(frame)
    if not frame or not UIParent then return end
    local x, y = SavedPosition()
    frame:ClearAllPoints()
    frame:SetPoint("LEFT", UIParent, "LEFT", x, y)
end

local function EnsureAnnouncement()
    if announcement or not UIParent then return announcement end

    local rowWidth = (MEDAL_SIZE * MAX_VISIBLE_MEDALS) + (MEDAL_GAP * (MAX_VISIBLE_MEDALS - 1))

    local frame = CreateFrame("Frame", "RivalsMultiKillAnnouncement", UIParent)
    frame:SetSize(rowWidth + 8, 76)
    -- Default is the Reach-like left/mid-screen placement, but the user may
    -- reposition the complete medal/caption unit with Rivals' lightweight HUD
    -- position editor.
    ApplyPosition(frame)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(120)
    frame:SetMovable(true)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:EnableMouse(false)
    frame.activeMedals = {}
    frame.medalSlots = {}

    frame.medalRow = CreateFrame("Frame", nil, frame)
    frame.medalRow:SetSize(rowWidth, MEDAL_SIZE)
    frame.medalRow:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.medalRow:EnableMouse(false)

    for i = 1, MAX_VISIBLE_MEDALS do
        local slot = CreateFrame("Frame", nil, frame.medalRow)
        slot:SetSize(MEDAL_SIZE, MEDAL_SIZE)
        SetSlotPosition(slot, i, 0)
        slot:SetFrameLevel(frame.medalRow:GetFrameLevel() + 1)
        slot:EnableMouse(false)

        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints(slot)
        slot.icon:SetTexCoord(0, 1, 0, 1)
        if slot.icon.SetSnapToPixelGrid then slot.icon:SetSnapToPixelGrid(false) end
        if slot.icon.SetTexelSnappingBias then slot.icon:SetTexelSnappingBias(0) end

        ResetMedalSlot(slot, i)
        frame.medalSlots[i] = slot
    end

    -- In Reach the newest medal sits at the left edge and its caption begins
    -- directly beneath that same edge rather than beneath the full medal row.
    frame.labelAnchor = CreateFrame("Frame", nil, frame)
    frame.labelAnchor:SetSize(rowWidth, 25)
    frame.labelAnchor:SetPoint("TOPLEFT", frame.medalRow, "BOTTOMLEFT", 0, -3)

    frame.labelShadow = frame.labelAnchor:CreateFontString(nil, "OVERLAY")
    frame.labelShadow:SetPoint("TOPLEFT", frame.labelAnchor, "TOPLEFT", 1, -1)
    frame.labelShadow:SetWidth(rowWidth)
    frame.labelShadow:SetHeight(25)
    frame.labelShadow:SetJustifyH("LEFT")
    frame.labelShadow:SetJustifyV("TOP")
    frame.labelShadow:SetFont(KILL_FONT, 20, "")
    frame.labelShadow:SetTextColor(SHADOW_R, SHADOW_G, SHADOW_B, 0.92)

    frame.label = frame.labelAnchor:CreateFontString(nil, "OVERLAY")
    frame.label:SetPoint("TOPLEFT", frame.labelAnchor, "TOPLEFT", 0, 0)
    frame.label:SetWidth(rowWidth)
    frame.label:SetHeight(25)
    frame.label:SetJustifyH("LEFT")
    frame.label:SetJustifyV("TOP")
    frame.label:SetFont(KILL_FONT, 20, "")
    frame.label:SetTextColor(TEXT_R, TEXT_G, TEXT_B, 1)

    -- Lightweight Rivals-specific Edit Mode.  It deliberately edits the exact
    -- live announcement frame rather than a detached proxy, so the saved point
    -- is precisely where the real medals will appear.
    frame.positionOverlay = CreateFrame("Frame", nil, frame)
    frame.positionOverlay:SetAllPoints(frame)
    frame.positionOverlay:SetFrameLevel(frame:GetFrameLevel() + 8)
    frame.positionOverlay:EnableMouse(true)
    frame.positionOverlay:RegisterForDrag("LeftButton")
    frame.positionOverlay:Hide()

    local overlayBg = frame.positionOverlay:CreateTexture(nil, "BACKGROUND")
    overlayBg:SetPoint("TOPLEFT", frame.positionOverlay, "TOPLEFT", -7, 7)
    overlayBg:SetPoint("BOTTOMRIGHT", frame.positionOverlay, "BOTTOMRIGHT", 7, -7)
    overlayBg:SetColorTexture(0.02, 0.10, 0.14, 0.28)

    local function Edge(point1, point2, x1, y1, x2, y2, width, height)
        local edge = frame.positionOverlay:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0.35, 0.86, 1.0, 0.95)
        edge:SetPoint(point1, frame.positionOverlay, point1, x1, y1)
        if point2 then
            edge:SetPoint(point2, frame.positionOverlay, point2, x2, y2)
        else
            edge:SetSize(width, height)
        end
        return edge
    end
    Edge("TOPLEFT", "TOPRIGHT", -7, 7, 7, 7, nil, nil):SetHeight(1)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", -7, -7, 7, -7, nil, nil):SetHeight(1)
    Edge("TOPLEFT", "BOTTOMLEFT", -7, 7, -7, -7, nil, nil):SetWidth(1)
    Edge("TOPRIGHT", "BOTTOMRIGHT", 7, 7, 7, -7, nil, nil):SetWidth(1)

    frame.positionOverlay.title = frame.positionOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.positionOverlay.title:SetPoint("BOTTOMLEFT", frame.positionOverlay, "TOPLEFT", -5, 10)
    frame.positionOverlay.title:SetText("KILLSTREAK MEDALS")

    frame.positionOverlay.help = frame.positionOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.positionOverlay.help:SetPoint("TOPLEFT", frame.positionOverlay, "BOTTOMLEFT", -5, -10)
    frame.positionOverlay.help:SetText("Drag to move  •  Right-click to finish")

    local function SaveDraggedPosition(self)
        local owner = self:GetParent()
        if not owner or not UIParent then return end
        owner:StopMovingOrSizing()
        local left = owner:GetLeft()
        local _, centerY = owner:GetCenter()
        local parentLeft = UIParent:GetLeft() or 0
        local _, parentCenterY = UIParent:GetCenter()
        parentCenterY = parentCenterY or ((UIParent:GetHeight() or 0) * 0.5)
        if left and centerY and DP.SetKillstreakPosition then
            DP.SetKillstreakPosition(left - parentLeft, centerY - parentCenterY)
        end
        ApplyPosition(owner)
    end

    frame.positionOverlay:SetScript("OnDragStart", function(self)
        local owner = self:GetParent()
        if owner and owner.editingPosition then owner:StartMoving() end
    end)
    frame.positionOverlay:SetScript("OnDragStop", SaveDraggedPosition)
    frame.positionOverlay:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self:GetParent().editingPosition then
            M.EndPositioning()
        end
    end)

    local function RefreshSlots(self, now)
        local active = self.activeMedals

        -- Entries are newest -> oldest. Only retire from the tail so surviving
        -- medals never jump left when an old one times out.
        while #active > 0 and (now - active[#active].startedAt) >= MEDAL_LIFETIME do
            table.remove(active, #active)
        end

        for i = 1, MAX_VISIBLE_MEDALS do
            local slot = self.medalSlots[i]
            local entry = active[i]
            if not entry then
                ResetMedalSlot(slot, i)
            else
                if slot.entry ~= entry then
                    slot.entry = entry
                    slot.icon:SetTexture(TexturePath(entry.medal.asset), nil, nil, "TRILINEAR")
                    slot:Show()
                end

                local elapsed = now - entry.startedAt

                -- When a new medal arrives, existing medals glide one position
                -- to the right. The newest medal itself stays anchored at the
                -- left edge, exactly like Reach's medal strip.
                local offsetX = 0
                if entry.shiftStartedAt then
                    local shiftP = Clamp01((now - entry.shiftStartedAt) / MEDAL_SHIFT_SECONDS)
                    local eased = EaseOutCubic(shiftP)
                    offsetX = -MEDAL_STEP * (1 - eased)
                    if shiftP >= 1 then entry.shiftStartedAt = nil end
                end
                SetSlotPosition(slot, i, offsetX)

                -- Reach's icon arrival is a quick snap/pop, not a spin and not
                -- a second enlarged copy of the medal. The previous duplicated
                -- additive texture was the source of the bright ring/ghosting
                -- visible in recordings.
                local iconAlpha = 1
                local scale = 1
                if i == 1 and elapsed < (MEDAL_SPAWN_DELAY + MEDAL_POP_SECONDS) then
                    if elapsed < MEDAL_SPAWN_DELAY then
                        iconAlpha = 0
                        scale = 0.86
                    else
                        local p = Clamp01((elapsed - MEDAL_SPAWN_DELAY) / MEDAL_POP_SECONDS)
                        iconAlpha = EaseOutCubic(Clamp01(p / 0.58))
                        if p < 0.68 then
                            local q = EaseOutCubic(p / 0.68)
                            scale = Lerp(0.86, 1.045, q)
                        else
                            local q = EaseOutCubic((p - 0.68) / 0.32)
                            scale = Lerp(1.045, 1.0, q)
                        end
                    end
                end

                local fade = 1
                if elapsed >= MEDAL_FADE_START then
                    fade = 1 - Clamp01((elapsed - MEDAL_FADE_START) / (MEDAL_LIFETIME - MEDAL_FADE_START))
                end

                slot:SetScale(scale)
                slot:SetAlpha(fade * iconAlpha)
                slot.icon:SetAlpha(1)
            end
        end
    end

    local function RefreshCaption(self, now)
        if not self.captionStartedAt then
            self.labelAnchor:Hide()
            return
        end

        local elapsed = now - self.captionStartedAt
        if elapsed >= CAPTION_LIFETIME then
            self.captionStartedAt = nil
            self.labelAnchor:Hide()
            return
        end

        local alpha = 1
        if elapsed >= CAPTION_FADE_START then
            alpha = 1 - Clamp01((elapsed - CAPTION_FADE_START) / (CAPTION_LIFETIME - CAPTION_FADE_START))
        end

        -- Keep the text treatment from 1.0.133, but remove the scale animation.
        -- Reach's caption reads as HUD copy appearing under the icon, not as a
        -- second object zooming independently from the medal.
        local drawP = EaseOutCubic(Clamp01(elapsed / 0.12))
        self.labelAnchor:SetAlpha(alpha * drawP)
        self.label:SetTextColor(
            Lerp(0.88, TEXT_R, drawP),
            Lerp(0.96, TEXT_G, drawP),
            Lerp(1.00, TEXT_B, drawP),
            1
        )
        self.labelShadow:SetTextColor(SHADOW_R, SHADOW_G, SHADOW_B, 0.92 * drawP)
        self.labelAnchor:Show()
    end

    frame:SetScript("OnUpdate", function(self)
        if self.editingPosition then return end
        if not GetTime then return end
        local now = GetTime()
        RefreshSlots(self, now)
        RefreshCaption(self, now)

        if #self.activeMedals == 0 and not self.captionStartedAt then
            self:Hide()
        end
    end)

    frame:Hide()
    announcement = frame
    return frame
end

local function ShowMedal(medal)
    if not medal then return end
    local frame = EnsureAnnouncement()
    if not frame then return end
    -- A real killing blow takes precedence over position editing. Keep the
    -- just-saved location, close the editor, and show the real medal there.
    if frame.editingPosition then
        M.EndPositioning()
        frame = EnsureAnnouncement()
    end

    local now = GetTime and GetTime() or 0
    local active = frame.activeMedals

    -- Reach places the newly-earned medal at the LEFT. Existing medals slide
    -- right, and the oldest medal drops off the far end if the row is full.
    while #active >= MAX_VISIBLE_MEDALS do
        table.remove(active, #active)
    end
    for i = 1, #active do
        active[i].shiftStartedAt = now
    end
    table.insert(active, 1, {medal = medal, startedAt = now})

    frame.labelShadow:SetText(medal.name)
    frame.label:SetText(medal.name)
    frame.labelAnchor:SetAlpha(0)
    frame.captionStartedAt = now
    frame:Show()

    if PlaySoundFile then
        PlaySoundFile(SoundPath(medal.asset), "Master")
    end
end

function M.ApplySavedPosition()
    local frame = EnsureAnnouncement()
    ApplyPosition(frame)
end

function M.IsPositioning()
    return announcement and announcement.editingPosition and true or false
end

function M.BeginPositioning()
    local frame = EnsureAnnouncement()
    if not frame then return end
    if frame.editingPosition then return end

    M.Reset()
    ApplyPosition(frame)
    frame.editingPosition = true
    frame:EnableMouse(false)

    -- Static preview: newest medal on the left with older medals to the right,
    -- exactly matching the real feed's footprint. No sounds or animation fire.
    local preview = {medals[5], medals[4], medals[3]}
    for i = 1, MAX_VISIBLE_MEDALS do
        local slot = frame.medalSlots[i]
        ResetMedalSlot(slot, i)
        local medal = preview[i]
        if medal then
            slot.icon:SetTexture(TexturePath(medal.asset), nil, nil, "TRILINEAR")
            slot:SetScale(1)
            slot:SetAlpha(1)
            slot:Show()
        end
    end
    frame.labelShadow:SetText(medals[5].name)
    frame.label:SetText(medals[5].name)
    frame.labelAnchor:SetAlpha(1)
    frame.labelAnchor:Show()
    frame.positionOverlay:Show()
    frame:Show()
end

function M.EndPositioning()
    local frame = announcement
    if not frame or not frame.editingPosition then return end
    frame.editingPosition = false
    if frame.positionOverlay then frame.positionOverlay:Hide() end
    frame:EnableMouse(false)
    M.Reset()
end

function M.TogglePositioning()
    if M.IsPositioning() then M.EndPositioning() else M.BeginPositioning() end
end

function M.ResetPosition()
    if DP.ResetKillstreakPosition then DP.ResetKillstreakPosition() end
    if announcement and announcement.editingPosition then
        ApplyPosition(announcement)
    end
end

function M.Reset()
    count = 0
    lastKillAt = nil
    eligibleCount, lastEligibleKillAt = 0, nil
    if announcement then
        announcement.editingPosition = false
        if announcement.positionOverlay then announcement.positionOverlay:Hide() end
        announcement:EnableMouse(false)
        announcement.activeMedals = {}
        announcement.captionStartedAt = nil
        for i = 1, #(announcement.medalSlots or {}) do
            ResetMedalSlot(announcement.medalSlots[i], i)
        end
        if announcement.labelAnchor then announcement.labelAnchor:Hide() end
        announcement:Hide()
    end
end

function M.GetCount()
    if not lastKillAt or not GetTime or (GetTime() - lastKillAt) > WINDOW_SECONDS then return 0 end
    return count
end

function M.OnKillingBlow(level, playerLevel, persist)
    -- This is the single gate for the entire killstreak feature: chain
    -- tracking, Reach medal feed, captions, and announcer sounds.
    if DP.KillstreaksEnabled and not DP.KillstreaksEnabled() then return 0 end

    local now = GetTime and GetTime() or 0
    if not lastKillAt or (now - lastKillAt) > WINDOW_SECONDS then
        count = 1
    else
        count = count + 1
    end
    lastKillAt = now

    -- Persist a separate chain containing only known, non-gray victims.
    -- Gray kills still animate, but cannot bridge or inflate earned medals.
    if persist and M.IsEligibleLevel(level, playerLevel) then
        eligibleCount = lastEligibleKillAt and (now - lastEligibleKillAt) <= WINDOW_SECONDS and (eligibleCount + 1) or 1
        lastEligibleKillAt = now
        local earned = medals[eligibleCount]
        if earned and DP.RecordMedal then DP.RecordMedal(earned.asset) end
    else
        eligibleCount, lastEligibleKillAt = 0, nil
    end

    local medal = medals[count]
    if medal then ShowMedal(medal) end
    return count
end

function M.Combat(playerGUID)
    local inInstance, kind = IsInInstance()
    if not inInstance or kind ~= "pvp" or not CombatLogGetCurrentEventInfo then return end
    local info = {CombatLogGetCurrentEventInfo()}
    if info[2] == "PARTY_KILL" and info[4] == playerGUID and info[8] and
            info[8]:match("^Player%-") then
        local level
        local unit = DP.WorldPvP and DP.WorldPvP.VisibleUnitForGUID(info[8])
        if unit and UnitLevel then level = UnitLevel(unit) end
        -- Battlegrounds have transient animations only, no persistent tracking.
        M.OnKillingBlow(level, UnitLevel("player"), false)
    end
end

