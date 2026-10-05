local _, DP = ...
local S = {}
DP.SpendChart = S

local categories = {
    petrification = {name="Flask of Petrification", color={.94,.76,.30}},
    dust = {name="Magic Dust", color={.94,.93,.88}},
    arcane = {name="Arcane Bomb", color={.48,.57,1}},
    elixirs = {name="Elixirs", color={.77,.48,.94}},
    potions = {name="Potions", color={.35,.88,.62}},
    bandages = {name="Bandages", color={.96,.89,.70}},
    bombs = {name="Bombs", color={1,.43,.32}},
    gadgets = {name="Gadgets", color={.28,.75,.80}},
    other = {name="Other consumables", color={.58,.65,.73}},
}

function S.Category(item)
    local id, name = tonumber(item.itemID), tostring(item.name or item.itemName or ""):lower()
    local engineering = false
    for _, known in pairs(DP.UsageCatalog or {}) do
        if id and tonumber(known.itemID) == id then
            name = tostring(known.name or name):lower()
            if known.category == "engineering" then engineering = true end
        end
    end
    if id == 13506 or name == "flask of petrification" then return "petrification" end
    if id == 2091 or name == "magic dust" then return "dust" end
    if id == 16040 or name == "arcane bomb" then return "arcane" end
    if name:find("bandage",1,true) then return "bandages" end
    if name:find("target dummy",1,true) or name:find("love fool",1,true) or
            name:find("lovefool",1,true) or name:find("yeti",1,true) then return "gadgets" end
    if name:find("bomb",1,true) or name:find("grenade",1,true) or name:find("dynamite",1,true) or
            name:find("sapper",1,true) or name:find("land mine",1,true) or
            (engineering and name:find("rocket",1,true)) then return "bombs" end
    if engineering then return "gadgets" end
    if name:find("elixir",1,true) then return "elixirs" end
    if name:find("potion",1,true) or name:find("flask",1,true) then return "potions" end
    return "other"
end

function S.Merge(into, values)
    for key, copper in pairs(values or {}) do
        into[key] = (into[key] or 0) + math.max(0, tonumber(copper) or 0)
    end
end

-- Use exact angular boundaries; a small category is never rounded up.
function S.Slices(values,effectiveScale)
    local rows, total, grouped = {}, 0, {}
    for key, amount in pairs(values or {}) do
        key = categories[key] and key or "other"
        grouped[key] = (grouped[key] or 0) + math.max(0, tonumber(amount) or 0)
    end
    for key, amount in pairs(grouped) do
        if amount > 0 then
            local meta = categories[key]
            rows[#rows+1] = {key=key,name=meta.name,color=meta.color,copper=amount}
            total = total + amount
        end
    end
    local visible,visibleTotal={},0
    for _,row in ipairs(rows) do
        row.percent=100*row.copper/total
        local arcPixels=2*math.pi*100*(effectiveScale or 1)*row.copper/total
        if arcPixels>=2 then
            visible[#visible+1]=row;visibleTotal=visibleTotal+row.copper
        end
    end
    rows=visible
    table.sort(rows,function(a,b) return a.copper == b.copper and a.key < b.key or a.copper > b.copper end)
    local angle=0
    for i,row in ipairs(rows) do
        row.startAngle=angle
        angle=angle+360*row.copper/visibleTotal
        row.endAngle=i==#rows and 360 or angle
    end
    return rows, total
end

local tooltip
local DURATION, POP_DURATION = .75, .20
local RADIUS, WIDTH, ROW_HEIGHT = 100, 280, 22
local SURFACE = "Interface\\AddOns\\Rivals\\Textures\\SpendPieSurface.tga"
local function Commas(value)
    local text=tostring(math.floor(value))
    repeat
        local changed
        text,changed=text:gsub("^(%d+)(%d%d%d)","%1,%2")
        if changed==0 then break end
    until false
    return text
end
local function Money(copper)
    copper=math.max(0,math.floor(tonumber(copper) or 0))
    if copper>0 and copper<10000 then return "<1g" end
    return Commas(math.floor(copper/10000+.5)).."g"
end
S.Money=Money

local function Point(angle)
    local a=math.rad(angle)
    return RADIUS*math.sin(a),RADIUS*math.cos(a)
end
local function Triangle(t,startAngle,endAngle,dx,dy,scale)
    local ax,ay=Point(startAngle)
    local bx,by=Point(endAngle)
    dx,dy,scale=dx or 0,dy or 0,scale or 1
    t:SetVertexOffset(1,RADIUS+dx,-RADIUS+dy)
    t:SetVertexOffset(2,RADIUS+dx,RADIUS+dy)
    t:SetVertexOffset(3,ax*scale-RADIUS+dx,ay*scale-RADIUS+dy)
    t:SetVertexOffset(4,bx*scale-RADIUS+dx,by*scale+RADIUS+dy)
    -- All triangles sample the same continuous surface, including its soft rim.
    t:SetTexCoord(.5,.5,.5,.5,.5+ax/(2*RADIUS),.5-ay/(2*RADIUS),
        .5+bx/(2*RADIUS),.5-by/(2*RADIUS))
end
local function CompletionTime(angle)
    local low,high=0,1
    for _=1,24 do
        local t=(low+high)/2
        if t*t*(3-2*t)<angle/360 then low=t else high=t end
    end
    return DURATION*(low+high)/2
end
local function Pop(row,elapsed)
    local age=elapsed-row.completedAt
    if age<0 or age>=POP_DURATION then return 0,0,1 end
    local bounce=math.sin(math.pi*age/POP_DURATION)
    local a=math.rad((row.startAngle+row.endAngle)/2)
    return math.sin(a)*3*bounce,math.cos(a)*3*bounce,1+.025*bounce
end
-- Approximate pixel coverage for slices too thin for the GPU's hard triangle
-- edges to resolve. Keep the actual angles and the full category in the legend.
function S.FaceColor(row,previous,nextRow,effectiveScale)
    local coverage=math.min(1,(row.endAngle-row.startAngle)*math.pi/180*RADIUS*effectiveScale)
    if coverage>=1 or not previous or not nextRow then return row.color end
    local color={}
    for i=1,3 do
        color[i]=row.color[i]*coverage+(previous.color[i]+nextRow.color[i])*.5*(1-coverage)
    end
    return color
end
local function Render(f,angle,elapsed)
    local used=0
    local effectiveScale=f.GetEffectiveScale and f:GetEffectiveScale() or 1
    for i,row in ipairs(f.rows) do
        local finish=math.min(row.endAngle,angle)
        local start=row.startAngle
        local dx,dy,scale=Pop(row,elapsed)
        local color=S.FaceColor(row,f.rows[i-1] or f.rows[#f.rows],
            f.rows[i+1] or f.rows[1],effectiveScale*scale)
        row.popOffset=math.sqrt(dx*dx+dy*dy)
        while finish-start>.0000001 do
            local ending=math.min(start+1,finish)
            used=used+1
            local t=f.triangles[used]
            if not t then
                t=f.chart:CreateTexture(nil,"ARTWORK")
                t:SetAllPoints(f.chart);t:SetTexture(SURFACE,"CLAMP","CLAMP","LINEAR")
                if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
                if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
                local shadow=f.chart:CreateTexture(nil,"BACKGROUND")
                shadow:SetAllPoints(f.chart);shadow:SetTexture(SURFACE,"CLAMP","CLAMP","LINEAR")
                if shadow.SetSnapToPixelGrid then shadow:SetSnapToPixelGrid(false) end
                if shadow.SetTexelSnappingBias then shadow:SetTexelSnappingBias(0) end
                shadow:SetVertexColor(.16,.17,.20,1)
                t.shadow=shadow;f.triangles[used]=t
            end
            Triangle(t,start,ending,dx,dy,scale)
            Triangle(t.shadow,start,ending,dx,dy-4,scale)
            t:SetVertexColor(color[1],color[2],color[3],1)
            t:Show();t.shadow:Show();start=ending
        end
    end
    for i=used+1,#f.triangles do f.triangles[i]:Hide();f.triangles[i].shadow:Hide() end
    for i,line in ipairs(f.separators) do
        local row,nextRow=f.rows[i],f.rows[i+1] or f.rows[1]
        -- Completed boundaries only; omit lines that would swallow tiny slices.
        local visible=row and nextRow and angle>=row.endAngle and
            row.endAngle-row.startAngle>=3 and nextRow.endAngle-nextRow.startAngle>=3 and #f.rows>1
        line:SetShown(visible and true or false)
        if visible then
            local dx,dy,scale=Pop(row,elapsed)
            local x,y=Point(row.endAngle)
            line:SetSize(1.8,96*scale)
            line:ClearAllPoints();line:SetPoint("CENTER",f.chart,dx+x*scale*.48,dy+y*scale*.48)
            line:SetRotation(-math.rad(row.endAngle))
        end
    end
    local sweeping=elapsed<DURATION and angle>0 and angle<360
    f.sweep:SetShown(sweeping)
    if sweeping then
        local x,y=Point(angle)
        f.sweep:ClearAllPoints();f.sweep:SetPoint("CENTER",f.chart,x*.48,y*.48)
        f.sweep:SetRotation(-math.rad(angle))
    end
    f.renderedAngle=angle
end
local function EnsureTooltip()
    if tooltip then return tooltip end
    local f=CreateFrame("Frame","RivalsEnemySpendTooltip",UIParent,"BackdropTemplate")
    f:SetFrameStrata("TOOLTIP");f:SetSize(WIDTH,457);f:EnableMouse(false)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    f:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
    f.background=f:CreateTexture(nil,"BACKGROUND")
    f.background:SetPoint("TOPLEFT",4,-4);f.background:SetPoint("BOTTOMRIGHT",-4,4)
    f.background:SetColorTexture(.025,.025,.03,1)
    f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f.title:SetPoint("TOP",0,-13);f.title:SetText("ENEMY GOLD SPENT")
    f.title:SetTextColor(.82,.72,.46)
    f.total=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    f.total:SetPoint("TOP",0,-32)
    local font,_,flags=f.total:GetFont();f.total:SetFont(font,22,flags)
    f.caption=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    f.caption:SetPoint("TOP",0,-59);f.caption:SetText("Lifetime consumable value")
    f.chart=CreateFrame("Frame",nil,f);f.chart:SetSize(200,200)
    f.chart:SetPoint("TOP",0,-80)
    f.triangles={};f.legend={};f.separators={}
    f.sweep=f.chart:CreateTexture(nil,"OVERLAY")
    f.sweep:SetTexture("Interface\\AddOns\\Rivals\\Textures\\SpendPieDivider.tga","CLAMP","CLAMP","LINEAR")
    f.sweep:SetVertexColor(.90,.90,1,.42);f.sweep:SetSize(1.8,96);f.sweep:Hide()
    if f.sweep.SetSnapToPixelGrid then f.sweep:SetSnapToPixelGrid(false) end
    if f.sweep.SetTexelSnappingBias then f.sweep:SetTexelSnappingBias(0) end
    local function Header(text,x,width,align)
        local h=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        h:SetPoint("TOPLEFT",14+x,-293);h:SetWidth(width);h:SetJustifyH(align);h:SetText(text)
    end
    Header("Category",15,140,"LEFT");Header("Gold",160,46,"RIGHT");Header("Share",208,42,"RIGHT")
    for i=1,9 do
        local row=CreateFrame("Frame",nil,f);row:SetSize(252,ROW_HEIGHT)
        row:SetPoint("TOPLEFT",14,-312-(i-1)*ROW_HEIGHT)
        row.dot=row:CreateTexture(nil,"ARTWORK");row.dot:SetSize(9,9);row.dot:SetPoint("LEFT",0,0)
        row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        row.name:SetPoint("LEFT",15,0);row.name:SetWidth(140);row.name:SetJustifyH("LEFT")
        row.value=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        row.value:SetPoint("LEFT",160,0);row.value:SetWidth(46);row.value:SetJustifyH("RIGHT")
        row.percent=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        row.percent:SetPoint("RIGHT",-2,0);row.percent:SetWidth(42);row.percent:SetJustifyH("RIGHT")
        f.legend[i]=row
        local line=f.chart:CreateTexture(nil,"OVERLAY")
        line:SetTexture("Interface\\AddOns\\Rivals\\Textures\\SpendPieDivider.tga","CLAMP","CLAMP","LINEAR")
        line:SetVertexColor(.025,.025,.03,.55);line:Hide();f.separators[i]=line
        if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(false) end
        if line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
    end
    f.empty=f.chart:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    f.empty:SetPoint("CENTER");f.empty:SetText("No spending recorded")
    f.animate=function(self)
        local elapsed=math.max(0,GetTime()-self.startedAt)
        local t=math.min(1,elapsed/DURATION)
        Render(self,360*t*t*(3-2*t),elapsed)
        if elapsed>=DURATION+POP_DURATION then self:SetScript("OnUpdate",nil);self.finished=true end
    end
    f:Hide();tooltip=f;return f
end
-- UIParent coordinates; reserve a visible margin even on short screens.
function S.Placement(screenWidth,screenHeight,ownerLeft,ownerRight,ownerTop,height)
    local margin=16
    local scale=math.min(1,math.max(1,screenHeight-2*margin)/height,
        math.max(1,screenWidth-2*margin)/WIDTH)
    local width,height=WIDTH*scale,height*scale
    local x=ownerRight+10
    if x+width>screenWidth-margin and ownerLeft-width-10>=margin then
        x=ownerLeft-width-10
    end
    x=math.max(margin,math.min(x,screenWidth-margin-width))
    local y=math.max(margin,math.min(ownerTop+8-height,screenHeight-margin-height))
    return x,y,scale
end
function S.Show(owner,values,lifetimeTotal)
    local f=EnsureTooltip()
    local rows,total=S.Slices(values,UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1)
    local now=GetTime()
    local height=312+math.max(1,#rows)*ROW_HEIGHT+13
    f:SetSize(WIDTH,height)
    f:ClearAllPoints()
    if UIParent and UIParent.GetHeight and owner.GetRight and owner.GetTop then
        local ratio=owner:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local left,bottom,scale=S.Placement(UIParent:GetWidth(),UIParent:GetHeight(),
            (owner:GetLeft() or 0)*ratio,(owner:GetRight() or 0)*ratio,
            (owner:GetTop() or 0)*ratio,height)
        if scale<1 then
            rows,total=S.Slices(values,UIParent:GetEffectiveScale()*scale)
            height=312+math.max(1,#rows)*ROW_HEIGHT+13
            f:SetSize(WIDTH,height)
            left,bottom,scale=S.Placement(UIParent:GetWidth(),UIParent:GetHeight(),
                (owner:GetLeft() or 0)*ratio,(owner:GetRight() or 0)*ratio,
                (owner:GetTop() or 0)*ratio,height)
        end
        f:SetScale(scale)
        f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",left/scale,bottom/scale)
    else
        f:SetScale(1);f:SetPoint("TOPLEFT",owner,"TOPRIGHT",10,8)
    end
    f.total:SetText(Money(lifetimeTotal or total))
    for _,row in ipairs(rows) do row.completedAt=CompletionTime(row.endAngle) end
    f.rows=rows
    for i=1,9 do
        local row,data=f.legend[i],rows[i]
        row:SetShown(data~=nil)
        if data then
            row.dot:SetColorTexture(data.color[1],data.color[2],data.color[3],1)
            row.name:SetText(data.name)
            row.value:SetText(Money(data.copper))
            row.percent:SetText(data.percent>0 and data.percent<.1 and "<0.1%" or string.format("%.1f%%",data.percent))
        end
    end
    f.empty:SetShown(total==0)
    -- Every OnEnter starts a fresh reveal, including an immediate re-hover.
    f.startedAt=now;f.finished=false;Render(f,0,0)
    f:SetScript("OnUpdate",total>0 and not f.finished and f.animate or nil)
    f:Show()
end
function S.Hide()
    if tooltip and tooltip:IsShown() then
        tooltip:Hide();tooltip:SetScript("OnUpdate",nil)
    end
end
