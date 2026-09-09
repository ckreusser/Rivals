local _, DP = ...
local T = {}
DP.Theme = T
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
