local _, DP = ...
local M = {}
DP.Minimap = M

local DEFAULT_ANGLE = 220
local button, menuFrame
local MENU_WIDTH = 108
local MENU_HIDE_GRACE = 0.65
local menuHideToken = 0

-- Keep the minimap launcher's geometry on whole physical pixels when Blizzard's
-- PixelUtil helpers are available. The previous 31px button / 22px crest pairing
-- forced the crest onto half-pixel boundaries at some UI scales, which is why
-- one-pixel nudges never stayed visually centered.
local function SetPixelSize(region, width, height)
    if PixelUtil and PixelUtil.SetSize then
        PixelUtil.SetSize(region, width, height)
    else
        region:SetSize(width, height)
    end
end

local function SetPixelPoint(region, point, relativeTo, relativePoint, x, y)
    region:ClearAllPoints()
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(region, point, relativeTo, relativePoint, x or 0, y or 0)
    else
        region:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
    end
end

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 then
        if y >= 0 then return math.atan(y / x) + math.pi end
        return math.atan(y / x) - math.pi
    end
    if y > 0 then return math.pi / 2 end
    if y < 0 then return -math.pi / 2 end
    return 0
end

local function Radius()
    if not Minimap then return 80 end
    local width = Minimap.GetWidth and Minimap:GetWidth() or 140
    local height = Minimap.GetHeight and Minimap:GetHeight() or width
    return math.min(width or 140, height or 140) / 2 + 9
end

local function Place(angle)
    if not button or not Minimap then return end
    angle = tonumber(angle) or DEFAULT_ANGLE
    local radians = math.rad(angle)
    local radius = Radius()
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

local function SavePositionFromCursor()
    if not button or not Minimap or not GetCursorPosition then return end
    local mx, my = Minimap:GetCenter()
    if not mx or not my then return end
    local scale = Minimap.GetEffectiveScale and Minimap:GetEffectiveScale() or 1
    if not scale or scale == 0 then scale = 1 end
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    local angle = math.deg(Atan2(cy - my, cx - mx))
    if angle < 0 then angle = angle + 360 end
    if M.db then M.db.minimapButtonAngle = angle end
    Place(angle)
end

local function SetFactionIcon()
    if not button or not button.icon then return end
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "Horde"
    local atlas = faction == "Alliance" and
        "glues-CharacterSelect-icon-faction-alliance-selected" or
        "glues-CharacterSelect-icon-faction-horde-selected"

    -- Keep the crest on the same pixel-snapped center as the button geometry
    -- and lower it by one physical pixel. The Horde atlas reads slightly left
    -- inside its bounds, so nudge Horde only 1px right; Alliance stays unchanged.
    SetPixelSize(button.icon, 22, 22)
    local crestX = faction == "Horde" and 1 or 0
    SetPixelPoint(button.icon, "CENTER", button, "CENTER", crestX, -1)

    if button.icon.SetAtlas then
        button.icon:SetAtlas(atlas, false)
    else
        button.icon:SetTexture("Interface\\AddOns\\Rivals\\Textures\\Rivals_Icon.tga")
        button.icon:SetTexCoord(0, 1, 0, 1)
    end
end

local function OpenCurrent()
    if DP.ShowRivalsCharacterPanel then DP.ShowRivalsCharacterPanel() end
end

local function OpenOverview(mode)
    if DP.WorldPvP and DP.WorldPvP.SetOverviewMode then DP.WorldPvP.SetOverviewMode(mode, true) end
    if DP.SelectDuelView then DP.SelectDuelView("Overview") end
    OpenCurrent()
end

local function OpenSettings()
    if DP.SelectDuelView then DP.SelectDuelView("Manage") end
    OpenCurrent()
end

local function CancelMenuHide()
    menuHideToken = menuHideToken + 1
end

local function FrameIsMouseOver(frame)
    if not frame or not frame:IsShown() then return false end
    if frame.IsMouseOver then return frame:IsMouseOver() end
    if MouseIsOver then return MouseIsOver(frame) end
    return false
end

local function HideMenu()
    CancelMenuHide()
    if menuFrame then menuFrame:Hide() end
end

local function ScheduleMenuHide()
    if not menuFrame or not menuFrame:IsShown() then return end
    menuHideToken = menuHideToken + 1
    local token = menuHideToken
    local function TryHide()
        if token ~= menuHideToken then return end
        if FrameIsMouseOver(button) or FrameIsMouseOver(menuFrame) then return end
        HideMenu()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(MENU_HIDE_GRACE, TryHide)
    else
        TryHide()
    end
end

local function RunMenuAction(action)
    HideMenu()
    if action then action() end
end

local function ApplyMenuChrome(frame, backgroundAlpha)
    local alpha = backgroundAlpha or .99

    -- Draw the menu as explicit one-pixel rails around an inset fill. This avoids
    -- the oversized/tiled corners of Blizzard backdrop textures and guarantees
    -- that the background never bleeds outside the visible menu edge.
    if not frame.innerBg then
        frame.innerBg = frame:CreateTexture(nil, "BACKGROUND")
        frame.innerBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.innerBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

        local borderColor = {.72, .53, .25, .95}
        frame.borderTop = frame:CreateTexture(nil, "BORDER")
        frame.borderTop:SetHeight(1)
        frame.borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, 0)
        frame.borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, 0)
        frame.borderTop:SetColorTexture(unpack(borderColor))

        frame.borderBottom = frame:CreateTexture(nil, "BORDER")
        frame.borderBottom:SetHeight(1)
        frame.borderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 0)
        frame.borderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 0)
        frame.borderBottom:SetColorTexture(unpack(borderColor))

        frame.borderLeft = frame:CreateTexture(nil, "BORDER")
        frame.borderLeft:SetWidth(1)
        frame.borderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
        frame.borderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)
        frame.borderLeft:SetColorTexture(unpack(borderColor))

        frame.borderRight = frame:CreateTexture(nil, "BORDER")
        frame.borderRight:SetWidth(1)
        frame.borderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -1)
        frame.borderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)
        frame.borderRight:SetColorTexture(unpack(borderColor))
    end
    frame.innerBg:SetColorTexture(.055, .06, .07, alpha)
end

local function CreateMenuButton(parent, index)
    local rowHeight, pad, firstRowY = 19, 2, 25
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(rowHeight)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, -(firstRowY + (index - 1) * rowHeight))
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -pad, -(firstRowY + (index - 1) * rowHeight))

    -- Character-pane neutral grey on hover, with the label warming to Rivals gold.
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetPoint("TOPLEFT", 1, -1)
    row.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    row.highlight:SetColorTexture(.28, .30, .34, .78)
    row.highlight:Hide()

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetPoint("RIGHT", -6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.label:SetTextColor(.92, .92, .92, 1)

    function row:SetOption(label, action)
        self.action = action
        self.label:SetText(label or "")
        self:SetShown(label ~= nil)
    end

    row:SetScript("OnEnter", function(self)
        CancelMenuHide()
        self.highlight:Show()
        self.label:SetTextColor(1, .82, .42, 1)
    end)
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        self.label:SetTextColor(.92, .92, .92, 1)
        ScheduleMenuHide()
    end)
    row:SetScript("OnClick", function(self) RunMenuAction(self.action) end)
    return row
end

local function EnsureMenu()
    if menuFrame then return menuFrame end

    menuFrame = CreateFrame("Frame", "RivalsMinimapMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    menuFrame:SetSize(MENU_WIDTH, 65)
    menuFrame:SetFrameStrata("DIALOG")
    menuFrame:SetFrameLevel(100)
    menuFrame:SetClampedToScreen(true)
    menuFrame:EnableMouse(true)
    if menuFrame.SetClipsChildren then menuFrame:SetClipsChildren(true) end
    ApplyMenuChrome(menuFrame, .99)

    -- Copy the small engraved-looking brand treatment from the 1vN toast.
    menuFrame.title = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    menuFrame.title:SetPoint("TOP", menuFrame, "TOP", 0, -7)
    menuFrame.title:SetText("RIVALS")
    menuFrame.title:SetTextColor(.88, .74, .44, .9)
    local titlePath = menuFrame.title:GetFont()
    if titlePath then menuFrame.title:SetFont(titlePath, 8, "OUTLINE") end

    menuFrame.divider = menuFrame:CreateTexture(nil, "ARTWORK")
    menuFrame.divider:SetColorTexture(.42, .30, .18, .65)
    menuFrame.divider:SetHeight(1)
    menuFrame.divider:SetPoint("TOPLEFT", 5, -21)
    menuFrame.divider:SetPoint("TOPRIGHT", -5, -21)

    menuFrame.rows = {
        CreateMenuButton(menuFrame, 1),
        CreateMenuButton(menuFrame, 2),
    }
    menuFrame:SetScript("OnEnter", CancelMenuHide)
    menuFrame:SetScript("OnLeave", ScheduleMenuHide)

    if UISpecialFrames then
        local found = false
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == "RivalsMinimapMenu" then found = true break end
        end
        if not found then table.insert(UISpecialFrames, "RivalsMinimapMenu") end
    end

    menuFrame:Hide()
    return menuFrame
end

local function RefreshMenuOptions(menu)
    if not menu or not menu.rows then return end
    local current = DP.WorldPvP and DP.WorldPvP.GetOverviewMode and DP.WorldPvP.GetOverviewMode() or "duels"
    if current == "world" then
        menu.rows[1]:SetOption("Duels", function() OpenOverview("duels") end)
    else
        menu.rows[1]:SetOption("World PvP", function() OpenOverview("world") end)
    end
    menu.rows[2]:SetOption("Settings", OpenSettings)
    menu:SetHeight(65)
end

local function ShowMenu()
    local menu = EnsureMenu()
    if not menu or not button then return end
    if menu:IsShown() then
        HideMenu()
        return
    end

    RefreshMenuOptions(menu)
    CancelMenuHide()

    -- Open inward from the minimap button so the menu always feels attached to
    -- the launcher instead of floating beside the minimap. Mirror the anchor on
    -- whichever side of the screen the user has placed the minimap.
    local bx, by = button:GetCenter()
    local ux, uy = 0, 0
    if UIParent and UIParent.GetCenter then ux, uy = UIParent:GetCenter() end
    bx, by = bx or 0, by or 0
    ux, uy = ux or 0, uy or 0
    local openRight = bx <= ux
    local openDown = by >= uy

    menu:ClearAllPoints()
    if openRight and openDown then
        menu:SetPoint("TOPLEFT", button, "CENTER", 13, -2)
    elseif openRight then
        menu:SetPoint("BOTTOMLEFT", button, "CENTER", 13, 2)
    elseif openDown then
        menu:SetPoint("TOPRIGHT", button, "CENTER", -13, -2)
    else
        menu:SetPoint("BOTTOMRIGHT", button, "CENTER", -13, 2)
    end
    menu:Show()
end

local function CreateButton()
    if button or not Minimap then return button end
    button = CreateFrame("Button", "RivalsMinimapButton", Minimap)
    SetPixelSize(button, 32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    -- The selected faction atlas supplies the inner gold medallion ring; the
    -- standard minimap tracking border supplies the normal outer ring.
    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.background:SetSize(24, 24)
    button.background:SetPoint("CENTER")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    SetFactionIcon()

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border:SetSize(53, 53)
    button.border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    SetPixelSize(highlight, 32, 32)
    SetPixelPoint(highlight, "CENTER", button, "CENTER", 0, 0)

    button:SetScript("OnEnter", function(self)
        CancelMenuHide()
        if not GameTooltip then return end
        local bx = self:GetCenter()
        local ux = UIParent and UIParent:GetCenter()
        -- Point the tooltip toward the center of the screen. A left-side minimap
        -- gets a right-side tooltip; a right-side minimap gets a left-side one.
        local anchor = (bx and ux and bx <= ux) and "ANCHOR_RIGHT" or "ANCHOR_LEFT"
        GameTooltip:SetOwner(self, anchor)
        GameTooltip:SetText("Rivals")
        GameTooltip:AddLine("Left-click: Open / close", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Options", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move", .72, .72, .72)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
        ScheduleMenuHide()
    end)
    button:SetScript("OnDragStart", function(self)
        self.rivalsDragging = true
        self:SetScript("OnUpdate", SavePositionFromCursor)
        SavePositionFromCursor()
    end)
    button:SetScript("OnDragStop", function(self)
        SavePositionFromCursor()
        self:SetScript("OnUpdate", nil)
        self.rivalsDragging = nil
        self.rivalsDragged = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() if button then button.rivalsDragged = nil end end)
        else
            self.rivalsDragged = nil
        end
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if self.rivalsDragging or self.rivalsDragged then return end
        if GameTooltip then GameTooltip:Hide() end
        if mouseButton == "RightButton" then
            ShowMenu()
        else
            HideMenu()
            if DP.ToggleRivalsCharacterPanel then
                DP.ToggleRivalsCharacterPanel()
            else
                OpenCurrent()
            end
        end
    end)

    return button
end

function M.RefreshVisibility()
    local current = CreateButton()
    if not current then return end
    if DP.MinimapButtonShown and DP.MinimapButtonShown() then current:Show() else current:Hide() end
end

function M.RefreshFaction()
    CreateButton()
    SetFactionIcon()
end

function M.Initialize(settings)
    M.db = settings
    if settings and type(settings.minimapButtonAngle) ~= "number" then settings.minimapButtonAngle = DEFAULT_ANGLE end
    CreateButton()
    Place(settings and settings.minimapButtonAngle or DEFAULT_ANGLE)
    M.RefreshFaction()
    M.RefreshVisibility()
end
