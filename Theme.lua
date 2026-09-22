local _, DP = ...
local T = {}
DP.Theme = T
-- Keep the sweep texture inside the target rectangle. Shifting its UVs moves
-- the light; a one-unit horizontal shift per vertical unit gives a 45-degree edge.
function T.LightSweep(parent, target, color, diagonal)
    local sweep = CreateFrame("Frame", nil, parent)
    sweep:SetAllPoints(target)
    sweep:SetFrameLevel(target:GetFrameLevel() + 5)
    if sweep.SetClipsChildren then sweep:SetClipsChildren(true) end

    -- Move a real gradient texture across the card instead of rewriting its UV
    -- coordinates every frame. Classic's texture sampler can break the heavily
    -- skewed/out-of-range UVs into visible blocks; fixed UVs stay smooth.
    local band = sweep:CreateTexture(nil, "OVERLAY")
    band:SetTexture("Interface\\AddOns\\Rivals\\Textures\\LightSweep.tga")
    band:SetTexCoord(0, 1, 0, 1)
    band:SetVertexColor(color[1], color[2], color[3])
    band:SetBlendMode("ADD")
    if band.SetSnapToPixelGrid then band:SetSnapToPixelGrid(false) end
    if band.SetTexelSnappingBias then band:SetTexelSnappingBias(0) end
    if diagonal and band.SetRotation then band:SetRotation(math.rad(-12)) end
    sweep.bands = {band}

    function sweep:Stop()
        self:SetScript("OnUpdate", nil)
        band:Hide()
        self:Hide()
    end

    function sweep:Play(delay, duration)
        self:SetScript("OnUpdate", nil)
        self:Show(); band:Show()
        local elapsed = -(delay or 0)
        duration = duration or .8
        local width = math.max(1, target:GetWidth())
        local height = math.max(1, target:GetHeight())
        local bandWidth = math.max(self.minBandWidth or 76, width * (self.bandWidthFactor or .28))
        band:SetSize(bandWidth, height * (diagonal and 1.8 or 1.05))
        band:SetAlpha(0)
        self:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed < 0 then return end
            if elapsed >= duration then self:Stop(); return end
            local t = elapsed / duration
            -- smoothstep avoids the tiny start/stop hitch that made the old
            -- sweep look choppy on low or uneven frame rates.
            local eased = t * t * (3 - 2 * t)
            local x = -bandWidth * .55 + (width + bandWidth * 1.10) * eased
            band:ClearAllPoints()
            band:SetPoint("CENTER", sweep, "LEFT", x, 0)
            band:SetAlpha(math.sin(math.pi * t) * .42)
        end)
    end
    sweep:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        band:Hide()
    end)
    sweep:Hide()
    return sweep
end
-- Animate the glyph colors and the existing inset blip flashes themselves.
-- There is no luminous rectangle behind the text or between the sockets.
function T.EstablishedPromotion(parent, card, status)
    local fx = CreateFrame("Frame", nil, parent)
    fx:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
    fx:SetSize(card:GetWidth() - 8, card:GetHeight() - 8)
    fx:SetFrameLevel(card:GetFrameLevel() + 10)
    local field = fx:CreateTexture(nil, "BACKGROUND")
    field:SetAllPoints(fx); field:SetColorTexture(.025, .045, .06, .97)
    -- Keep one unscaled coordinate space. The animated word is a filtered
    -- bitmap; only its dimensions change, never the font raster or frame scale.
    local motion = CreateFrame("Frame", nil, fx)
    motion:SetSize(1, 1)
    motion:SetPoint("CENTER", status, "CENTER", 0, 0)
    motion:SetFrameLevel(fx:GetFrameLevel() + 1)
    local title = motion:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("CENTER", motion, "CENTER", 0, 0)
    title:SetJustifyH("CENTER")
    local word = motion:CreateTexture(nil, "OVERLAY")
    word:SetTexture("Interface\\AddOns\\Rivals\\Textures\\EstablishedText.tga")
    word:SetVertexColor(101/255, 230/255, 173/255)
    word:SetPoint("CENTER", motion, "CENTER", 0, 0)
    if word.SetSnapToPixelGrid then word:SetSnapToPixelGrid(false) end
    if word.SetTexelSnappingBias then word:SetTexelSnappingBias(0) end
    fx.title, fx.motion, fx.word = title, motion, word
    local flash = fx:CreateTexture(nil, "ARTWORK")
    flash:SetAllPoints(fx); flash:SetColorTexture(1, .86, .55, 1)
    flash:SetBlendMode("ADD")
    local glow = fx:CreateTexture(nil, "ARTWORK")
    glow:SetTexture("Interface\\AddOns\\Rivals\\Textures\\PromotionGlow.tga")
    glow:SetVertexColor(1, .85, .48); glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER", status, "CENTER", 0, 8)
    -- Repeat the friendly FC star pair across the word, keeping the glow
    -- attached to its measured width throughout the scaling animation.
    local stars = {}
    for i = 1, 10 do
        local rear = i % 2 == 1
        local star = motion:CreateTexture(nil, "ARTWORK", nil, rear and -2 or -1)
        star:SetTexture("Interface\\Cooldown\\star4")
        star:SetBlendMode("ADD")
        star:SetPoint("CENTER", motion, "CENTER", 0, 0)
        if star.SetSnapToPixelGrid then star:SetSnapToPixelGrid(false) end
        if star.SetTexelSnappingBias then star:SetTexelSnappingBias(0) end
        if rear then star:SetVertexColor(1, .78, .08)
        else star:SetVertexColor(1, 1, .68) end
        stars[i] = star
    end
    fx.stars = stars
    local sparks = {}
    for i = 1, 18 do
        local spark = fx:CreateTexture(nil, "ARTWORK")
        spark:SetTexture("Interface\\AddOns\\Rivals\\Textures\\PromotionGlow.tga")
        spark:SetVertexColor(1, .85, .48); spark:SetBlendMode("ADD")
        sparks[i] = spark
    end
    function fx:Stop()
        self:SetScript("OnUpdate", nil); self:Hide(); self.checkpoint = nil
    end
    function fx:Play(delay, checkpoint)
        self:Stop(); self.checkpoint = checkpoint
        self:SetAlpha(0); self:Show()
        local font, size, flags = status:GetFont()
        title:SetFont(font, size, flags)
        title:SetText("Established")
        local establishedWidth = title:GetStringWidth()
        local lastPromoted
        local elapsed = -(delay or 0)
        self:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed < 0 then return end
            if elapsed >= 4.45 then
                if self.checkpoint then
                    self.checkpoint.promotionSeen = true
                    self.checkpoint.promotionPending = nil
                end
                self:Stop(); return
            end
            self:SetAlpha(math.min(1, elapsed / .2, (4.45 - elapsed) / .4))
            local promoted = elapsed >= 1.05
            local burstAge = elapsed - 1.05
            local scale, x, y = 1, 0, 0
            if not promoted then
                local tension = math.max(0, (elapsed - .3) / .75)
                x, y = math.sin(elapsed * 91) * tension * 2.4, math.sin(elapsed * 127) * tension * 1.5
            else
                local grow = math.min(1, burstAge / .16)
                local settle = math.max(0, math.min(1, (elapsed - 1.65) / 1.4))
                local remaining = 1 - settle^3 * (settle * (settle * 6 - 15) + 10)
                scale = 1 + .65 * (1 - (1 - grow)^3) * remaining
                y = 10 * grow * remaining
            end
            motion:SetPoint("CENTER", status, "CENTER", x, y)
            if lastPromoted ~= promoted then
                title:SetText(promoted and "Established" or "Provisional")
                lastPromoted = promoted
            end
            if promoted then title:SetTextColor(101/255, 230/255, 173/255)
            else title:SetTextColor(1, 202/255, 103/255) end
            local handoff = math.max(0, math.min(1, (elapsed - 3.05) / .18))
            title:SetAlpha(promoted and handoff or 1)
            word:SetAlpha(promoted and (1 - handoff) or 0)
            word:SetSize(establishedWidth * scale, establishedWidth * (71/467) * scale)
            local burst = promoted and math.max(0, 1 - burstAge / .45) or 0
            flash:SetAlpha(burst * burst * .38)
            glow:SetSize(160 + 70 * (1 - burst), 54)
            glow:SetAlpha(burst * .95)
            local rearPulse = .5 + .5 * math.sin(math.max(0, burstAge) * 4.2)
            local innerPulse = .5 + .5 * math.sin(math.max(0, burstAge) * 4.2 + math.pi * .72)
            local textWidth = establishedWidth * scale
            for i, star in ipairs(stars) do
                local rear = i % 2 == 1
                local pulse = rear and rearPulse or innerPulse
                local diameter = (textWidth * (rear and .40 or .34) + 5 * pulse)
                star:SetPoint("CENTER", motion, "CENTER", (math.floor((i - 1) / 2) - 2) * textWidth / 5, 0)
                star:SetSize(diameter, diameter)
                star:SetAlpha(promoted and (.30 + .16 * pulse) or 0)
                if star.SetRotation then star:SetRotation(math.max(0, burstAge) * (rear and .75 or -1.05)) end
            end
            local travel = math.max(0, math.min(1, burstAge / .65))
            for i, spark in ipairs(sparks) do
                local angle = i * math.pi * 2 / #sparks
                spark:ClearAllPoints()
                spark:SetPoint("CENTER", status, "CENTER", math.cos(angle) * (18 + 104 * travel), 8 + math.sin(angle) * (3 + 25 * travel))
                spark:SetSize(9 - 5 * travel, 9 - 5 * travel)
                spark:SetAlpha(promoted and (1 - travel)^2 or 0)
            end
        end)
    end
    fx:SetScript("OnHide", function(self) self:Stop() end)
    fx:Hide()
    return fx
end
function T.CompletionSweep(parent, row, label, color)
    local sweep = CreateFrame("Frame", nil, parent)
    sweep.bands = {}
    for i, slot in ipairs(row.slots) do sweep.bands[i] = slot.flash end
    local original, painted
    function sweep:Stop()
        self:SetScript("OnUpdate", nil)
        if original and label:GetText() == painted then label:SetText(original) end
        original, painted = nil, nil
        for _, slot in ipairs(row.slots) do slot:Paint(slot.display or 0, 0) end
        self:Hide()
    end
    function sweep:Play(delay, duration)
        self:Stop(); self:Show()
        local elapsed = -(delay or 0)
        duration = duration or .8
        self:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed < 0 then return end
            if elapsed >= duration then self:Stop(); return end
            local current = label:GetText() or ""
            if current ~= painted then original = current end
            local text = (original or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local center = -.2 + 1.4 * elapsed / duration
            local function Glow(x)
                local distance = math.abs(x - center) / .2
                return distance < 1 and math.cos(distance * math.pi / 2)^2 or 0
            end
            local pieces = {}
            -- Placement captions use ASCII; inline colors preserve font shaping,
            -- spacing and glyph transparency without an overlay surface.
            for i = 1, #text do
                local glow = Glow((i - .5) / #text)
                pieces[i] = string.format("|cff%02x%02x%02x%s|r",
                    math.floor(255 * (color[1] + (1 - color[1]) * glow)),
                    math.floor(255 * (color[2] + (1 - color[2]) * glow)),
                    math.floor(255 * (color[3] + (1 - color[3]) * glow)), text:sub(i, i))
            end
            painted = table.concat(pieces); label:SetText(painted)
            for i, slot in ipairs(row.slots) do
                slot:Paint(slot.display or 0, Glow((i - .5) / #row.slots) * .85)
            end
        end)
    end
    sweep:SetScript("OnHide", function(self) self:Stop() end)
    sweep:Hide()
    return sweep
end
-- Match Zurk Maps' physical-pixel border layout: round once, then disable
-- independent texture snapping so opposite edges cannot drift apart.
function T.ProgressRow(parent, count, center, y, color)
    local row = CreateFrame("Frame", nil, parent)
    row.slots = {}
    local function Texture(owner, layer, r, g, b, a)
        local t = owner:CreateTexture(nil, layer)
        t:SetColorTexture(r, g, b, a or 1)
        if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
        if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
        return t
    end
    local function Place(t, x, top, w, h)
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", x, -top); t:SetSize(w, h)
    end
    for i = 1, count do
        local slot = CreateFrame("Frame", nil, row)
        slot.well = Texture(slot, "BACKGROUND", .008, .012, .022)
        slot.top = Texture(slot, "BORDER", .30, .21, .12)
        slot.left = Texture(slot, "BORDER", .22, .15, .09)
        slot.bottom = Texture(slot, "BORDER", .62, .46, .27)
        slot.right = Texture(slot, "BORDER", .44, .31, .17)
        slot.innerTop = Texture(slot, "BORDER", .005, .007, .01)
        slot.innerBottom = Texture(slot, "BORDER", .14, .12, .09)
        slot.fill = Texture(slot, "ARTWORK", color[1] * .65, color[2] * .65, color[3] * .65)
        slot.light = Texture(slot, "ARTWORK", .35 + color[1] * .65, .35 + color[2] * .65, .35 + color[3] * .65)
        slot.shade = Texture(slot, "ARTWORK", color[1] * .30, color[2] * .30, color[3] * .30)
        slot.fill:SetDrawLayer("ARTWORK", 0)
        slot.shade:SetDrawLayer("ARTWORK", 1)
        slot.light:SetDrawLayer("ARTWORK", 2)
        slot.flash = Texture(slot, "OVERLAY", .8, .9, 1, .6)
        function slot:Paint(value, glow)
            self.display = value
            local p, w, h = row.pixel, row.slotWidth, row.slotHeight
            local width = math.floor((w - 4 * p) * value / p + .5) * p
            local visible = width > 0
            self.fill:SetShown(visible); self.light:SetShown(visible); self.shade:SetShown(visible)
            self.flash:SetShown(visible and glow > 0)
            if visible then
                Place(self.fill, 2 * p, 2 * p, width, h - 4 * p)
                Place(self.light, 2 * p, 2 * p, width, p)
                Place(self.shade, 2 * p, h - 3 * p, width, p)
                Place(self.flash, 2 * p, 2 * p, width, h - 4 * p); self.flash:SetAlpha(glow)
            end
        end
        function slot:Pop(age)
            local pulse = math.sin(math.pi * math.min(1, age / .44))
            self:Paint(1, pulse)
            local p, w, h = row.pixel, row.slotWidth, row.slotHeight
            local extra = pulse > .45 and p or 0
            -- Expand the whole inset around its center, then settle. Never
            -- reveal a partial width: the earned blip is present as one piece.
            Place(self.fill, 2 * p - extra / 2, 2 * p - extra / 2, w - 4 * p + extra, h - 4 * p + extra)
        end
        slot:SetScript("OnHide", function(self)
            self:SetScript("OnUpdate", nil)
            if self.target then self:Paint(self.target, 0) end
        end)
        row.slots[i] = slot
    end
    function row:Layout()
        local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() or 1
        if not PixelUtil and GetPhysicalScreenSize then
            local _, height = GetPhysicalScreenSize(); if height and height > 0 then factor = 768 / height end
        end
        local scale = (parent.GetEffectiveScale and parent:GetEffectiveScale() or 1) / factor
        local function Pixels(n) return math.max(1, math.floor(n * scale + .5)) end
        local base, h, gap = math.max(6, Pixels(10)), math.max(7, Pixels(9)), Pixels(2)
        -- Five wide sockets occupy exactly the same pixel span as ten narrow
        -- sockets: each wide one replaces two narrow ones and their gap.
        local w = count == 5 and (2 * base + gap) or base
        local total = count * w + (count - 1) * gap
        self.pixel, self.slotWidth, self.slotHeight = 1 / scale, w / scale, h / scale
        self.span = total / scale
        local left = parent.GetLeft and parent:GetLeft() or 0
        local top = parent.GetTop and parent:GetTop() or 0
        left, top = left or 0, top or 0
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", (math.floor((left + center) * scale - total / 2 + .5) / scale) - left,
            math.floor((top + y) * scale + .5) / scale - top)
        self:SetSize(total / scale, h / scale)
        local p = self.pixel
        for i, slot in ipairs(self.slots) do
            slot:ClearAllPoints(); slot:SetPoint("TOPLEFT", (i - 1) * (w + gap) / scale, 0)
            slot:SetSize(w / scale, h / scale)
            Place(slot.well, 0, 0, w / scale, h / scale)
            Place(slot.top, p, 0, (w - 2) / scale, p)
            Place(slot.bottom, p, (h - 1) / scale, (w - 2) / scale, p)
            Place(slot.left, 0, p, p, (h - 2) / scale)
            Place(slot.right, (w - 1) / scale, p, p, (h - 2) / scale)
            Place(slot.innerTop, p, p, (w - 2) / scale, p)
            Place(slot.innerBottom, p, (h - 2) / scale, (w - 2) / scale, p)
            slot:Paint(slot.display or 0, 0)
        end
    end
    function row:SetProgress(value, animate)
        self:Layout()
        for i, slot in ipairs(self.slots) do
            local target = math.max(0, math.min(1, value - i + 1))
            if target ~= slot.target then
                local previous = slot.target
                slot.target = target
                slot:SetScript("OnUpdate", nil)
                if animate and previous and target > previous and self:IsShown() then
                    local start, elapsed = slot.display or previous, 0
                    slot:SetScript("OnUpdate", function(self, dt)
                        elapsed = elapsed + dt
                        local t = math.min(1, elapsed / .55)
                        self:Paint(start + (target - start) * (1 - (1 - t)^3), math.sin(t * math.pi) * .65)
                        if t == 1 then self:SetScript("OnUpdate", nil) end
                    end)
                else slot:Paint(target, 0) end
            elseif not animate then
                slot:SetScript("OnUpdate", nil); slot:Paint(target, 0)
            end
        end
    end
    row:Layout()
    return row
end
function T.Fill(parent, x, y, width, height, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetPoint("TOPLEFT", x, y); texture:SetSize(width, height)
    texture:SetColorTexture(r, g, b, a or 1)
    return texture
end
function T.Border(parent, x, y, width, height)
    local box = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetPoint("TOPLEFT", x, y); box:SetSize(width, height)
    if box.SetBackdrop then
        box:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8,
            insets = {left = 2, right = 2, top = 2, bottom = 2}})
        box:SetBackdropColor(.045, .055, .075, 0)
        box:SetBackdropBorderColor(.84, .56, .31, .85)
    end
    return box
end
-- The connected title-plaque assembly used by Zurk Maps. Keep the ornament
-- construction in one place so Rivals' rating card and secondary windows use
-- the exact same endcaps, trim, fill, and text placement.
-- Native decorative divider used between paired stat slabs. The BattleBar
-- atlas has the same visual language as the gold Rivals framing and avoids
-- the hand-drawn two-pixel rule looking like an arbitrary separator.
function T.StatDivider(parent, x, y, height)
    local divider = parent:CreateTexture(nil, "OVERLAY")
    divider:SetPoint("CENTER", parent, "TOPLEFT", x, y)
    if divider.SetAtlas then
        divider:SetAtlas("BattleBar-ButtonBG-Divider", true)
        local nativeW, nativeH = divider:GetWidth(), divider:GetHeight()
        local h = height or 42
        local aspect = (nativeW and nativeH and nativeH > 0) and (nativeW / nativeH) or .30
        divider:SetSize(math.max(10, h * aspect), h)
        divider:SetVertexColor(.84, .56, .31, .92)
    else
        divider:SetTexture("Interface\\Buttons\\WHITE8X8")
        divider:SetSize(2, height or 42)
        divider:SetVertexColor(.84, .56, .31, .92)
    end
    return divider
end

function T.PlaqueHeader(parent, width, label, fontObject)
    -- Match the Zurk Maps title plaque geometry and colors exactly.  The
    -- center background occupies the plaque itself; native Blizzard filigree
    -- endcaps overlap the plaque edges and the top/bottom trim tucks beneath
    -- those endcaps.  Do not add a second inset border/background box here.
    local plaque = CreateFrame("Frame", nil, parent)
    plaque:SetSize(width, 18)
    if plaque.SetFrameLevel and parent.GetFrameLevel then plaque:SetFrameLevel(parent:GetFrameLevel() + 8) end

    plaque.bg = plaque:CreateTexture(nil, "BACKGROUND")
    plaque.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    plaque.bg:SetVertexColor(0.018, 0.012, 0.008, 0.97)

    plaque.border = CreateFrame("Frame", nil, plaque)
    plaque.border:SetAllPoints(plaque)
    plaque.border:SetFrameLevel(plaque:GetFrameLevel() + 1)
    plaque.border:EnableMouse(false)

    plaque.borderR = 0.84
    plaque.borderG = 0.56
    plaque.borderB = 0.31
    plaque.filigreeOverlap = 4
    plaque.trimHeight = 8

    local function ApplyAtlas(texture, atlasName, useAtlasSize)
        texture:SetVertexColor(plaque.borderR, plaque.borderG, plaque.borderB, 0.97)
        if texture.SetAtlas then
            texture:SetAtlas(atlasName, useAtlasSize and true or false)
        else
            texture:SetColorTexture(plaque.borderR, plaque.borderG, plaque.borderB, 1)
        end
    end

    plaque.topTrim = plaque.border:CreateTexture(nil, "BORDER")
    ApplyAtlas(plaque.topTrim, "battlefieldminimap-border-top")

    plaque.bottomTrim = plaque.border:CreateTexture(nil, "BORDER")
    ApplyAtlas(plaque.bottomTrim, "battlefieldminimap-border-bottom")

    plaque.leftTrim = plaque.border:CreateTexture(nil, "OVERLAY")
    ApplyAtlas(plaque.leftTrim, "PetJournal-BattleSlotTitle-Left", true)

    plaque.rightTrim = plaque.border:CreateTexture(nil, "OVERLAY")
    ApplyAtlas(plaque.rightTrim, "PetJournal-BattleSlotTitle-Right", true)

    local filigreeAspect = 1
    if plaque.leftTrim:GetHeight() and plaque.leftTrim:GetHeight() > 0 then
        filigreeAspect = plaque.leftTrim:GetWidth() / plaque.leftTrim:GetHeight()
    end

    plaque.text = plaque:CreateFontString(nil, "OVERLAY")
    plaque.text:SetPoint("CENTER", plaque, "CENTER", 0, 0)
    plaque.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    plaque.text:SetTextColor(0.72, 0.66, 0.50, 1)
    plaque.text:SetText(label or "")

    local filigreeHeight = 20
    local filigreeWidth = filigreeHeight * filigreeAspect
    local trimInset = math.max(0, plaque.filigreeOverlap - 1)

    plaque.leftTrim:ClearAllPoints()
    plaque.leftTrim:SetPoint("RIGHT", plaque.border, "LEFT", plaque.filigreeOverlap, 0)
    plaque.leftTrim:SetSize(filigreeWidth, filigreeHeight)

    plaque.rightTrim:ClearAllPoints()
    plaque.rightTrim:SetPoint("LEFT", plaque.border, "RIGHT", -plaque.filigreeOverlap, 0)
    plaque.rightTrim:SetSize(filigreeWidth, filigreeHeight)

    plaque.bg:ClearAllPoints()
    plaque.bg:SetPoint("TOPLEFT", plaque.border, "TOPLEFT", 0, -1)
    plaque.bg:SetPoint("BOTTOMRIGHT", plaque.border, "BOTTOMRIGHT", 0, 1)

    plaque.topTrim:ClearAllPoints()
    plaque.topTrim:SetPoint("TOPLEFT", plaque.border, "TOPLEFT", trimInset, 2)
    plaque.topTrim:SetPoint("TOPRIGHT", plaque.border, "TOPRIGHT", -trimInset, 2)
    plaque.topTrim:SetHeight(plaque.trimHeight)

    plaque.bottomTrim:ClearAllPoints()
    plaque.bottomTrim:SetPoint("BOTTOMLEFT", plaque.border, "BOTTOMLEFT", trimInset, -2)
    plaque.bottomTrim:SetPoint("BOTTOMRIGHT", plaque.border, "BOTTOMRIGHT", -trimInset, -2)
    plaque.bottomTrim:SetHeight(plaque.trimHeight)

    return plaque
end

function T.RatingHeader(parent, card)
    local header = T.PlaqueHeader(parent, card:GetWidth() * .5, "Duel Rating")
    header:SetPoint("BOTTOM", card, "TOP", 0, -4)
    return header
end

function T.StatSlab(parent, x, y, width, height, mirrored)
    -- Clipped corners and opposing bevel light distinguish two separate slabs;
    -- no background crosses the channel between them.
    local slab = CreateFrame("Frame", nil, parent)
    slab:SetPoint("TOPLEFT", x, y); slab:SetSize(width, height)
    local mask = slab:CreateMaskTexture()
    mask:SetTexture("Interface\\AddOns\\Rivals\\Textures\\StatSlabMask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(slab)
    slab.interiorMask = mask
    local function Interior(...)
        local texture = T.Fill(slab, ...)
        texture:AddMaskTexture(mask)
        return texture
    end
    local function Edge(...)
        local texture = T.Fill(slab, ...)
        texture:SetDrawLayer("BORDER")
        return texture
    end
    for row = 0, height - 1 do
        local inset = math.max(0, 3 - math.min(row, height - 1 - row))
        local glow = 1 - row / (height - 1)
        Interior(inset, -row, width - 2 * inset, 1, .045 + .025 * glow, .055 + .03 * glow, .065 + .035 * glow)
        local edge = row == 0 or row == height - 1
        if edge then
            Edge(inset, -row, width - 2 * inset, 1, row == 0 and .40 or .16, row == 0 and .33 or .14, row == 0 and .23 or .10)
        else
            local light, dark = mirrored and .16 or .36, mirrored and .36 or .16
            Edge(inset, -row, 1, 1, light, light * .82, light * .57)
            Edge(width - inset - 1, -row, 1, 1, dark, dark * .82, dark * .57)
        end
    end
    Interior(4, -2, width - 8, 1, .19, .19, .17, .6)
    Interior(4, -height + 2, width - 8, 1, .012, .015, .02)
    return slab
end

function T.ClassName(name, class)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not color then return name end
    return string.format("|cff%02x%02x%02x%s|r", math.floor(color.r * 255 + .5), math.floor(color.g * 255 + .5), math.floor(color.b * 255 + .5), name)
end
function T.Button(parent, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 23); button:SetPoint("TOPLEFT", x, y)
    button:SetPushedTextOffset(1, -1)
    local caps = {}
    -- Fixed-width end caps preserve the bevel at every control width.
    for i, uv in ipairs({{0, .0625}, {.0625, .5625}, {.5625, .625}}) do
        local texture = button:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
        texture:SetTexCoord(uv[1], uv[2], 0, .6875)
        caps[#caps + 1] = texture
        if i == 1 then texture:SetPoint("TOPLEFT"); texture:SetSize(8, 23)
        elseif i == 3 then texture:SetPoint("TOPRIGHT"); texture:SetSize(8, 23)
        else texture:SetPoint("TOPLEFT", 8, 0); texture:SetPoint("BOTTOMRIGHT", -8, 0) end
    end
    local border = T.Border(button, 0, 0, width, 23)
    border:SetAllPoints(button)
    border:EnableMouse(false)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetAllPoints(button); button:SetFontString(label); button:SetText(text)
    button.label = label
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    local pressed = button:CreateTexture(nil, "ARTWORK")
    pressed:SetAllPoints(button); pressed:SetColorTexture(0, 0, 0, .3)
    button:SetPushedTexture(pressed)
    local function ButtonArtwork(down)
        for _, cap in ipairs(caps) do
            cap:SetTexture(down and "Interface\\Buttons\\UI-Panel-Button-Down" or "Interface\\Buttons\\UI-Panel-Button-Up")
        end
    end
    button:SetScript("OnMouseDown", function() ButtonArtwork(true) end)
    button:SetScript("OnMouseUp", function() ButtonArtwork(false) end)
    button:HookScript("OnHide", function() ButtonArtwork(false) end)
    button:SetScript("OnClick", callback)
    button.selection = button:CreateTexture(nil, "OVERLAY")
    button.selection:SetPoint("BOTTOMLEFT", 3, 1); button.selection:SetPoint("BOTTOMRIGHT", -3, 1)
    button.selection:SetHeight(2); button.selection:SetColorTexture(.90, .69, .27, 1)
    button.selection:Hide()
    return button
end

function T.SelectButton(button, selected, text)
    button:SetEnabled(true)
    button:SetButtonState("NORMAL", false)
    button.selection:SetShown(selected)
    button:SetText(selected and ("|cffffce70" .. text .. "|r") or text)
end

-- Native Blizzard drop-down control. In game this uses UIDropDownMenuTemplate
-- and the stock menu/checkmark/arrow artwork rather than Rivals button art.
-- The tiny fallback exists only for stripped-down test environments where the
-- Blizzard drop-down API is not loaded.
function T.DropDown(parent, x, y, width, getOptions, onSelect)
    local native = UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton and UIDropDownMenu_SetText
    local dropdown
    if native then
        dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
        if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dropdown, math.max(40, width - 32)) end
        if UIDropDownMenu_SetButtonWidth then UIDropDownMenu_SetButtonWidth(dropdown, width) end
        if UIDropDownMenu_JustifyText then UIDropDownMenu_JustifyText(dropdown, "CENTER") end
    else
        dropdown = T.Button(parent, "", x, y, width, function() end)
    end
    dropdown.isDropdown = true
    dropdown.usesNativeAssets = native and true or false
    dropdown.logicalWidth = width

    function dropdown:SetVisibleWidth(visibleWidth)
        if self.usesNativeAssets then
            -- The native middle strip has 16px of visible endcap artwork.
            UIDropDownMenu_SetWidth(self, math.max(40, visibleWidth - 16))
            if UIDropDownMenu_SetButtonWidth then UIDropDownMenu_SetButtonWidth(self, visibleWidth + 16) end
        else
            self:SetWidth(visibleWidth)
        end
    end

    function dropdown:SetAnchor(anchorX, anchorY)
        self.logicalX, self.logicalY = anchorX, anchorY
        self:ClearAllPoints()
        if self.usesNativeAssets then
            -- UIDropDownMenuTemplate has built-in 16px side padding and sits a
            -- few pixels taller than a panel button. Offset so its visible art
            -- occupies the same logical 23px row as the other controls.
            self:SetPoint("TOPLEFT", anchorX - 14, anchorY + 2)
        else
            self:SetPoint("TOPLEFT", anchorX, anchorY)
        end
    end

    local function Find(value)
        for _, option in ipairs((getOptions and getOptions()) or {}) do
            if option.value == value then return option end
        end
    end
    function dropdown:SetSelectedValue(value, text)
        self.selectedValue = value
        local option = Find(value)
        text = text or (option and option.text) or tostring(value or "")
        self.text = text
        if self.usesNativeAssets then
            if UIDropDownMenu_SetSelectedValue then UIDropDownMenu_SetSelectedValue(self, value) end
            UIDropDownMenu_SetText(self, text)
        else
            self:SetText(text .. "  v")
        end
    end
    function dropdown:SelectValue(value)
        local option = Find(value)
        if not option then return end
        self:SetSelectedValue(value, option.text)
        if CloseDropDownMenus then CloseDropDownMenus() end
        if onSelect then onSelect(value) end
    end

    if native then
        UIDropDownMenu_Initialize(dropdown, function(_, level)
            if level and level ~= 1 then return end
            for _, option in ipairs((getOptions and getOptions()) or {}) do
                local value, label = option.value, option.text
                local info = UIDropDownMenu_CreateInfo()
                info.text = label
                info.value = value
                info.checked = dropdown.selectedValue == value
                info.func = function() dropdown:SelectValue(value) end
                info.keepShownOnClick = false
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    else
        -- Unit tests can call SelectValue directly. A click advances only in the
        -- fallback so the control remains operable outside the WoW UI runtime.
        dropdown:SetScript("OnClick", function()
            local options = (getOptions and getOptions()) or {}
            if #options == 0 then return end
            local index = 1
            for i, option in ipairs(options) do if option.value == dropdown.selectedValue then index = i % #options + 1; break end end
            dropdown:SelectValue(options[index].value)
        end)
    end
    dropdown:SetAnchor(x, y)
    return dropdown
end

function T.ToggleButton(button, selected, text)
    T.SelectButton(button, selected, text)
end


function T.DataTab(parent, text, x, y, width, callback)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(width, 25)
    tab:SetPoint("TOPLEFT", x, y)
    tab:EnableMouse(true)
    if tab.RegisterForClicks then tab:RegisterForClicks("LeftButtonUp") end
    if tab.SetFrameLevel and parent.GetFrameLevel then tab:SetFrameLevel(parent:GetFrameLevel() + 8) end

    -- Texture-only chrome: nothing sits above the Button to intercept clicks.
    tab.fill = tab:CreateTexture(nil, "BACKGROUND")
    tab.fill:SetAllPoints(tab)

    tab.top = tab:CreateTexture(nil, "BORDER")
    tab.top:SetPoint("TOPLEFT", 1, -1)
    tab.top:SetPoint("TOPRIGHT", -1, -1)
    tab.top:SetHeight(1)
    tab.top:SetColorTexture(.34, .28, .20, .72)

    tab.left = tab:CreateTexture(nil, "BORDER")
    tab.left:SetPoint("TOPLEFT", 0, -1)
    tab.left:SetPoint("BOTTOMLEFT", 0, 0)
    tab.left:SetWidth(1)
    tab.left:SetColorTexture(.24, .22, .19, .78)

    tab.right = tab:CreateTexture(nil, "BORDER")
    tab.right:SetPoint("TOPRIGHT", 0, -1)
    tab.right:SetPoint("BOTTOMRIGHT", 0, 0)
    tab.right:SetWidth(1)
    tab.right:SetColorTexture(.24, .22, .19, .78)

    tab.bottom = tab:CreateTexture(nil, "BORDER")
    tab.bottom:SetPoint("BOTTOMLEFT", 0, 0)
    tab.bottom:SetPoint("BOTTOMRIGHT", 0, 0)
    tab.bottom:SetHeight(1)

    tab.gloss = tab:CreateTexture(nil, "ARTWORK")
    tab.gloss:SetPoint("TOPLEFT", 2, -2)
    tab.gloss:SetPoint("TOPRIGHT", -2, -2)
    tab.gloss:SetHeight(8)
    tab.gloss:SetColorTexture(1, 1, 1, .035)

    local label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 1)
    tab:SetFontString(label)
    tab.label = label

    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", 2, -2)
    highlight:SetPoint("BOTTOMRIGHT", -2, 1)
    highlight:SetColorTexture(1, .78, .35, .08)

    tab:SetScript("OnClick", function(self)
        if callback then callback(self) end
    end)

    T.SelectDataTab(tab, false, text)
    return tab
end

function T.SelectDataTab(button, selected, text)
    button.selected = selected and true or false
    button.text = text
    button:SetText(selected and ("|cffffce70" .. text .. "|r") or "|cffd8d8d8" .. text .. "|r")
    if selected then
        button.fill:SetColorTexture(.13, .035, .035, 1)
        -- Selected tab visually opens into the data area: the lower rule
        -- disappears instead of drawing a bright custom box around the tab.
        button.bottom:SetColorTexture(.035, .055, .075, 1)
        button.top:SetColorTexture(.47, .36, .22, .62)
        button.left:SetColorTexture(.29, .25, .20, .76)
        button.right:SetColorTexture(.29, .25, .20, .76)
        button.gloss:SetAlpha(.62)
    else
        button.fill:SetColorTexture(.05, .025, .025, .98)
        button.bottom:SetColorTexture(.20, .18, .15, .84)
        button.top:SetColorTexture(.28, .24, .19, .62)
        button.left:SetColorTexture(.18, .17, .15, .72)
        button.right:SetColorTexture(.18, .17, .15, .72)
        button.gloss:SetAlpha(.32)
    end
end
