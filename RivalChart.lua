local _,DP=...
local C={};DP.RivalChart=C
function C.Rank(stats)
    local function Top(metric,limit)
        local list={}
        for key,r in pairs(stats or {}) do
            if (r[metric] or 0)>0 then
                local copy={}
                for k,v in pairs(r) do copy[k]=v end
                copy.key=tostring(key);list[#list+1]=copy
            end
        end
        table.sort(list,function(a,b)
            if a[metric]~=b[metric] then return a[metric]>b[metric] end
            if a.encounters~=b.encounters then return (a.encounters or 0)>(b.encounters or 0) end
            if a.lastAt~=b.lastAt then return (a.lastAt or 0)>(b.lastAt or 0) end
            return a.key<b.key
        end)
        for i=#list,limit+1,-1 do list[i]=nil end
        return list
    end
    return Top("kills",5),Top("deaths",3)
end
local classTextures={MAGE="Mage",WARLOCK="Warlock",PRIEST="Priest",PALADIN="Paladin",
    SHAMAN="Shaman",DRUID="Druid",HUNTER="Hunter",ROGUE="Rogue",WARRIOR="Warrior"}
function C.ClassTexture(class)
    local name=classTextures[type(class)=="string" and class:upper() or ""]
    return name and ("Interface\\AddOns\\Rivals\\Textures\\ClassBars\\"..name..".tga") or
        "Interface\\AddOns\\Rivals\\Textures\\RivalBarRaised.tga"
end
local tooltip
local function Ensure()
    if tooltip then return tooltip end
    local f=CreateFrame("Frame","RivalsMostKilledTooltip",UIParent,"BackdropTemplate")
    f:SetFrameStrata("TOOLTIP");f:EnableMouse(false);f:SetClampedToScreen(true)
    f:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
    local bg=f:CreateTexture(nil,"BACKGROUND");bg:SetPoint("TOPLEFT",4,-4);bg:SetPoint("BOTTOMRIGHT",-4,4);bg:SetColorTexture(.025,.025,.03,1)
    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOP",0,-10);title:SetText("MOST KILLED");title:SetTextColor(.82,.72,.46);title:SetShadowColor(0,0,0,.8);title:SetShadowOffset(1,-1)
    local caption=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    caption:SetPoint("TOP",0,-26);caption:SetText("World PvP opponents");caption:SetShadowColor(0,0,0,.8);caption:SetShadowOffset(1,-1)
    f.rows={};f.sections={}
    for i=1,2 do
        local h=f:CreateFontString(nil,"OVERLAY","GameFontNormal");h:SetShadowColor(0,0,0,.8);h:SetShadowOffset(1,-1);f.sections[i]=h
    end
    for i=1,8 do
        local row=CreateFrame("Frame",nil,f);row:SetSize(252,26)
        row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        row.name:SetPoint("TOPLEFT",6,-6);row.name:SetWidth(173);row.name:SetJustifyH("LEFT")
        row.name:SetTextColor(1,1,1);row.name:SetShadowColor(0,0,0,.8);row.name:SetShadowOffset(1,-1)
        local nameFont,nameSize=row.name:GetFont()
        row.name:SetFont(nameFont,nameSize,"")
        row.count=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.count:SetPoint("TOPRIGHT",-6,-7)
        row.count:SetShadowColor(0,0,0,.8);row.count:SetShadowOffset(1,-1)
        local countFont,countSize=row.count:GetFont()
        row.count:SetFont(countFont,math.max(11,countSize),"")
        row.rule=row:CreateTexture(nil,"BACKGROUND")
        row.rule:SetPoint("TOPLEFT",0,-25);row.rule:SetSize(252,1)
        row.rule:SetColorTexture(.18,.20,.23,.35)
        row.bar=row:CreateTexture(nil,"ARTWORK");row.bar:SetPoint("TOPLEFT",0,0);row.bar:SetHeight(24)

        if row.bar.SetSnapToPixelGrid then row.bar:SetSnapToPixelGrid(false) end
        if row.bar.SetTexelSnappingBias then row.bar:SetTexelSnappingBias(0) end
        row.track=row:CreateTexture(nil,"BACKGROUND")
        row.track:SetPoint("TOPLEFT");row.track:SetSize(252,24)

        row.track:SetTexCoord(0,252/256,0,24/32)
        row.detail=CreateFrame("Frame",nil,row)
        row.detail:SetPoint("TOPLEFT");row.detail:SetSize(252,24)
        if row.detail.SetClipsChildren then row.detail:SetClipsChildren(true) end
        row.detail:Hide()
        row.edge=row.detail:CreateTexture(nil,"ARTWORK")
        row.edge:SetPoint("TOPLEFT");row.edge:SetPoint("TOPRIGHT");row.edge:SetHeight(1)
        row.edge:SetColorTexture(1,1,1,.24)
        local base=row.detail:CreateTexture(nil,"ARTWORK")
        base:SetPoint("BOTTOMLEFT");base:SetPoint("BOTTOMRIGHT");base:SetHeight(1);base:SetColorTexture(0,0,0,.55)
        -- Keep labels above the texture detail frame.
        row.labels=CreateFrame("Frame",nil,row);row.labels:SetAllPoints(row)
        if row.labels.SetFrameLevel and row.detail.GetFrameLevel then row.labels:SetFrameLevel(row.detail:GetFrameLevel()+2) end
        row.name:SetParent(row.labels);row.count:SetParent(row.labels)
        f.rows[i]=row
    end
    f.empty=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    f.empty:SetPoint("TOP",0,-53)
    f.animate=function(self)
        local t=math.min(1,math.max(0,(GetTime()-self.startedAt)/.75))
        local eased=t*t*(3-2*t)
        for _,row in ipairs(self.rows) do
            if row.target then
                local width=math.max(.01,row.target*eased)
                row.bar:SetWidth(width);row.bar:SetTexCoord(0,width/256,0,24/32);row.bar:SetShown(t>0)
                row.detail:SetWidth(math.max(.01,row.target*eased));row.detail:SetShown(t>0)
            end
        end
        if t==1 then self:SetScript("OnUpdate",nil) end
    end
    f:Hide();tooltip=f;C.Tooltip=f;return f
end
function C.Show(owner,summary)
    local f=Ensure();local y,index=44,1
    local groups={summary.topMostKilled or {},summary.topNemeses or {}}
    for group,list in ipairs(groups) do
        local header=f.sections[group];header:SetShown(group==2 and #list>0)
        if #list>0 then
            if group==2 then
                header:ClearAllPoints();header:SetPoint("TOP",0,-y)
                header:SetText("NEMESES");header:SetTextColor(.82,.72,.46)
                y=y+20
            end
            local metric=group==1 and "kills" or "deaths"
            local maximum=list[1][metric]
            for rank,r in ipairs(list) do
                local row=f.rows[index];row:ClearAllPoints();row:SetPoint("TOPLEFT",14,-y);row:Show()
                local name=r.name or "Unknown"
                row.name:SetText(name);row.name:SetTextColor(1,1,1)
                local value=r[metric]
                row.count:SetText(value..(group==1 and (value==1 and " KB" or " KBs") or (value==1 and " death" or " deaths")))
                row.target=252*value/maximum;row.bar:SetWidth(.01);row.bar:Hide();row.detail:Hide()
                local class=type(r.class)=="string" and r.class:upper() or nil
                local color=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or
                    (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
                local texture=C.ClassTexture(class)
                row.bar:SetTexture(texture,"CLAMP","CLAMP","LINEAR")
                row.track:SetTexture(texture,"CLAMP","CLAMP","LINEAR")
                row.track:SetVertexColor((color and color.r or .58)*.23,(color and color.g or .65)*.23,(color and color.b or .73)*.23,1)
                -- Class RGB stays intact; the texture supplies the shading.
                row.bar:SetVertexColor(color and color.r or .58,
                    color and color.g or .65,color and color.b or .73,1)
                y=y+26;index=index+1
            end
            y=y+6
        end
    end
    for i=index,8 do f.rows[i]:Hide();f.rows[i].target=nil end
    f.empty:SetShown(index==1);f.empty:SetText("No opponent records yet")
    local height=index==1 and 82 or y+5
    f:SetSize(280,height);f:ClearAllPoints()
    if UIParent and UIParent.GetHeight and owner.GetRight then
        local ratio=owner:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local x,bottom,scale=DP.SpendChart.Placement(UIParent:GetWidth(),UIParent:GetHeight(),
            (owner:GetLeft() or 0)*ratio,(owner:GetRight() or 0)*ratio,(owner:GetTop() or 0)*ratio,height)
        f:SetScale(scale);f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x/scale,bottom/scale)
    else
        f:SetScale(1);f:SetPoint("TOPLEFT",owner,"TOPRIGHT",10,8)
    end
    f.startedAt=GetTime();f:SetScript("OnUpdate",index>1 and f.animate or nil);f:Show()
end
function C.Hide() if tooltip then
    tooltip:Hide();tooltip:SetScript("OnUpdate",nil)
end end
