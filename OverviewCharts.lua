local _,DP=...
local C={};DP.OverviewCharts=C
function C.RankZones(zones)
    local list={}
    for _,zone in pairs(zones or {}) do if zone.kills>0 then list[#list+1]=zone end end
    table.sort(list,function(a,b)
        if a.kills~=b.kills then return a.kills>b.kills end
        if a.encounters~=b.encounters then return a.encounters>b.encounters end
        return a.name<b.name
    end)
    for i=#list,6,-1 do list[i]=nil end
    return list
end
function C.AddBuffs(summary,record,known)
    local names={}
    for _,name in pairs(known) do names[name]=true end
    local function BuffName(id,name) return known[id] or (names[name] and name) end
    local log=record.session and record.session.worldCombatLog or {}
    local enemies,deathTimes={},{}
    for _,enemy in ipairs(record.enemies or {}) do
        if enemy.guid then enemies[enemy.guid]=enemy end
        if enemy.died and enemy.killedAt then deathTimes[enemy.guid or enemy.name]={enemy.killedAt} end
    end
    for _,entry in ipairs(log) do
        if enemies[entry.destGUID] and (entry.event=="PARTY_KILL" or entry.event=="UNIT_DIED") and not entry.unconscious then
            local times=deathTimes[entry.destGUID] or {};times[#times+1]=entry.t;deathTimes[entry.destGUID]=times
        end
    end
    local seen,logged={},{}
    local function Add(guid,id,name,icon,t)
        local key=tostring(guid)..":"..name
        if seen[key] and t and math.abs(t-seen[key])<=.1 then return end
        seen[key]=t or 0;logged[key]=true
        local bucket=summary.worldBuffsRemoved[name]
        if not bucket then bucket={name=name,spellID=id,icon=icon,count=0};summary.worldBuffsRemoved[name]=bucket end
        bucket.count=bucket.count+1;bucket.icon=bucket.icon or icon
        summary.worldBuffRemovalCount=summary.worldBuffRemovalCount+1
    end
    for _,entry in ipairs(log) do
        local id=entry.event=="SPELL_DISPEL" and entry.removedSpellID or entry.spellID
        local name=BuffName(id,entry.spellName)
        if name and enemies[entry.destGUID] then
            local confirmed=entry.event=="SPELL_DISPEL" and entry.sourceGUID==record.playerGUID
            if entry.event=="SPELL_AURA_REMOVED" then
                for _,t in ipairs(deathTimes[entry.destGUID] or {}) do
                    if entry.t and math.abs(entry.t-t)<=1 then confirmed=true;break end
                end
            end
            if confirmed then Add(entry.destGUID,id,name,nil,entry.t) end
        end
    end
    for _,enemy in ipairs(record.enemies or {}) do
        for _,buff in pairs(enemy.detectedBuffs and enemy.detectedBuffs.world or {}) do
            local name=BuffName(buff.spellID,buff.name)
            if name and buff.removedAt and enemy.died and not logged[tostring(enemy.guid)..":"..name] and
                    (not enemy.killedAt or math.abs(buff.removedAt-enemy.killedAt)<=1) then
                Add(enemy.guid,buff.spellID,name,buff.icon,buff.removedAt)
            end
        end
    end
end
local function Base(name,title)
    local f=CreateFrame("Frame",name,UIParent,"BackdropTemplate")
    f:SetFrameStrata("TOOLTIP");f:EnableMouse(false);f:SetClampedToScreen(true)
    f:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
    local bg=f:CreateTexture(nil,"BACKGROUND");bg:SetPoint("TOPLEFT",4,-4);bg:SetPoint("BOTTOMRIGHT",-4,4);bg:SetColorTexture(.025,.025,.03,1)
    f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormal");f.title:SetPoint("TOP",0,-10);f.title:SetText(title);f.title:SetTextColor(.82,.72,.46)
    f.caption=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");f.caption:SetPoint("TOP",0,-26)
    f.empty=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");f.empty:SetPoint("TOP",0,-53)
    f:Hide();return f
end
local function Place(f,owner,width,height)
    f:SetSize(width,height);f:ClearAllPoints()
    if UIParent and UIParent.GetHeight and owner.GetRight then
        local ratio=owner:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local x,y,scale=DP.SpendChart.Placement(UIParent:GetWidth(),UIParent:GetHeight(),
            (owner:GetLeft() or 0)*ratio,(owner:GetRight() or 0)*ratio,(owner:GetTop() or 0)*ratio,height,width)
        f:SetScale(scale);f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x/scale,y/scale)
    else f:SetScale(1);f:SetPoint("TOPLEFT",owner,"TOPRIGHT",10,8) end
end
-- The entire zone spans the strip width. Select the horizontal crop containing
-- the most recorded kill points, and avoid overlapping markers within 9px.
function C.MapCrop(points,mapID,canvasHeight)
    local bestY,bestCount=.5,-1
    for _,candidate in ipairs(points) do
        if candidate.mapID==mapID then
            local top=math.max(0,math.min(canvasHeight-30,candidate.y*canvasHeight-15))
            local count=0
            for _,point in ipairs(points) do
                if point.mapID==mapID and point.y*canvasHeight>=top+5 and point.y*canvasHeight<=top+25 then count=count+1 end
            end
            if count>bestCount then bestY=candidate.y;bestCount=count end
        end
    end
    return math.max(0,math.min(math.max(0,canvasHeight-30),bestY*canvasHeight-15))
end
local zoneMaps={Maraudon=1443}
function C.ZoneMap(name)
    if zoneMaps[name] then return zoneMaps[name] end
    if C_Map and C_Map.GetMapChildrenInfo then
        for _,info in ipairs(C_Map.GetMapChildrenInfo(946,nil,true) or {}) do
            if info.name==name and (info.mapType or 3)>=3 then zoneMaps[name]=info.mapID;return info.mapID end
        end
    end
end
local function MapStrip(row,zone)
    local map=row.map;local points=zone.points or {};local maps={};local mapID,best
    for _,point in ipairs(points) do maps[point.mapID]=(maps[point.mapID] or 0)+1 end
    for id,count in pairs(maps) do if not best or count>best then mapID,best=id,count end end
    for _,t in pairs(map.tiles) do t:Hide() end
    map.overlays=map.overlays or {}
    for _,t in pairs(map.overlays) do t:Hide() end
    for _,t in ipairs(row.markers) do t:Hide() end
    local zoneID=C.ZoneMap(zone.name)
    if zone.name=="Maraudon" then
        -- Era has no Maraudon map. Show its approximate entrance in Desolace.
        mapID=1443;points={{mapID=1443,x=.29,y=.625}}
    elseif zoneID and zoneID~=mapID then
        local converted={}
        for _,point in ipairs(points) do
            if point.mapID==zoneID then converted[#converted+1]=point
            elseif C_Map.GetMapRectOnMap then
                local minX,maxX,minY,maxY=C_Map.GetMapRectOnMap(zoneID,point.mapID)
                if minX and maxX>minX and maxY>minY then
                    local x,y=(point.x-minX)/(maxX-minX),(point.y-minY)/(maxY-minY)
                    if x>=0 and x<=1 and y>=0 and y<=1 then converted[#converted+1]={mapID=zoneID,x=x,y=y} end
                end
            end
        end
        points,mapID=converted,zoneID
    elseif C_Map and C_Map.GetMapInfo then
        local info=mapID and C_Map.GetMapInfo(mapID)
        if info and (info.name~=zone.name or (info.mapType or 3)<3) then mapID=nil end
    end
    local layers=mapID and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
    local layer=layers and layers[1]
    local textures=layer and C_Map.GetMapArtLayerTextures(mapID,1)
    row.fallback:SetShown(not textures or #textures==0)
    if not textures or #textures==0 then return end
    local scale=1
    local canvasWidth,h=layer.layerWidth*scale,layer.layerHeight*scale
    local crop=C.MapCrop(points,mapID,h)
    local centerX=.5
    for _,point in ipairs(points) do
        if point.mapID==mapID and point.y*h>=crop+5 and point.y*h<=crop+25 then centerX=point.x;break end
    end
    local cropX=math.max(0,math.min(math.max(0,canvasWidth-252),centerX*canvasWidth-126))
    -- Crop each tile into the viewport; no oversized or displaced child frame.
    map.canvas:SetSize(252,30);map.canvas:ClearAllPoints()
    map.canvas:SetPoint("TOPLEFT",map,"TOPLEFT",0,0)
    local used=0
    for y=0,math.ceil(layer.layerHeight/layer.tileHeight)-1 do
        for x=0,math.ceil(layer.layerWidth/layer.tileWidth)-1 do
            used=used+1
            local tileX,tileY=x*layer.tileWidth*scale,y*layer.tileHeight*scale
            local left,top=math.max(tileX,cropX),math.max(tileY,crop)
            local right=math.min(tileX+layer.tileWidth*scale,canvasWidth,cropX+252)
            local bottom=math.min(tileY+layer.tileHeight*scale,h,crop+30)
            if textures[used] and right>left and bottom>top then
                local t=map.tiles[used]
                if not t then t=map.canvas:CreateTexture(nil,"ARTWORK");map.tiles[used]=t end
                t:SetTexture(textures[used],"CLAMP","CLAMP","LINEAR");t:SetVertexColor(1,1,1,1)
                t:ClearAllPoints();t:SetPoint("TOPLEFT",left-cropX,-(top-crop))
                t:SetSize(right-left,bottom-top)
                t:SetTexCoord((left-tileX)/(layer.tileWidth*scale),(right-tileX)/(layer.tileWidth*scale),
                    (top-tileY)/(layer.tileHeight*scale),(bottom-tileY)/(layer.tileHeight*scale))
                t:Show()
            end
        end
    end
    local explored=C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}
    local function EdgeSize(n)
        local size=16;while size<n do size=size*2 end;return size
    end
    local overlayUsed=0
    for _,overlay in ipairs(explored or {}) do
        if not overlay.isShownByMouseOver then
            local width,height=overlay.textureWidth or 0,overlay.textureHeight or 0
            local tw,th=layer.tileWidth,layer.tileHeight
            local columns,rows=math.ceil(width/tw),math.ceil(height/th)
            for y=0,rows-1 do
                for x=0,columns-1 do
                    local fileID=(overlay.fileDataIDs or {})[y*columns+x+1]
                    local w,hh=math.min(tw,width-x*tw),math.min(th,height-y*th)
                    local fileW,fileH=x==columns-1 and EdgeSize(w) or tw,y==rows-1 and EdgeSize(hh) or th
                    local tx,ty=((overlay.offsetX or 0)+x*tw)*scale,((overlay.offsetY or 0)+y*th)*scale
                    local left,top=math.max(tx,cropX),math.max(ty,crop)
                    local right,bottom=math.min(tx+w*scale,cropX+252),math.min(ty+hh*scale,crop+30)
                    if fileID and right>left and bottom>top then
                        overlayUsed=overlayUsed+1
                        local tile=map.overlays[overlayUsed]
                        if not tile then
                            tile=map.canvas:CreateTexture(nil,"ARTWORK",nil,overlay.isDrawOnTopLayer and 3 or 2)
                            map.overlays[overlayUsed]=tile
                        end
                        if tile.SetDrawLayer then tile:SetDrawLayer("ARTWORK",overlay.isDrawOnTopLayer and 3 or 2) end
                        tile:SetTexture(fileID,"CLAMP","CLAMP","LINEAR");tile:ClearAllPoints()
                        tile:SetPoint("TOPLEFT",left-cropX,-(top-crop));tile:SetSize(right-left,bottom-top)
                        tile:SetTexCoord((left-tx)/(fileW*scale),(right-tx)/(fileW*scale),
                            (top-ty)/(fileH*scale),(bottom-ty)/(fileH*scale));tile:Show()
                    end
                end
            end
        end
    end
    local shown={}
    for _,point in ipairs(points) do
        local x,y=point.x*canvasWidth-cropX,point.y*h-crop
        local fits=point.mapID==mapID and x>=5 and x<=252-5 and y>=5 and y<=25
        for _,position in ipairs(shown) do if math.abs(x-position.x)<9 and math.abs(y-position.y)<9 then fits=false;break end end
        if fits and #shown<20 then
            local i=#shown+1;shown[i]={x=x,y=y};local marker=row.markers[i]
            if not marker then
                marker=row.layer:CreateTexture(nil,"ARTWORK");marker:SetSize(10,10)
                marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
                marker:SetTexCoord(.5,.75,.5,1);row.markers[i]=marker
            end
            marker:ClearAllPoints();marker:SetPoint("CENTER",row.layer,"TOPLEFT",x,-y);marker:Show()
        end
    end
end
local zones,buffs
function C.ShowZones(owner,summary)
    if not zones then
        zones=Base("RivalsFavoriteZoneTooltip","FAVORITE ZONE");zones.caption:SetText("Kills by zone");zones.rows={}
        for i=1,5 do
            local row=CreateFrame("Frame",nil,zones);row:SetSize(252,34);row:SetPoint("TOPLEFT",14,-44-(i-1)*34)
            row.reveal=CreateFrame("ScrollFrame",nil,row);row.reveal:SetPoint("TOPLEFT");row.reveal:SetSize(252,30)
            row.fill=CreateFrame("Frame",nil,row.reveal);row.fill:SetPoint("TOPLEFT",row.reveal,"TOPLEFT",0,0);row.fill:SetSize(252,30);row.reveal:SetScrollChild(row.fill)
            row.map=CreateFrame("Frame",nil,row.fill);row.map:SetAllPoints(row.fill);row.map:SetClipsChildren(true)
            row.map.canvas=CreateFrame("Frame",nil,row.map);row.map.canvas:SetPoint("TOPLEFT",row.map,"TOPLEFT",0,0);row.map.canvas:SetSize(252,30);row.map.tiles={}
            row.layer=CreateFrame("Frame",nil,row.fill);row.layer:SetAllPoints(row.fill);row.layer:SetFrameLevel(row.map:GetFrameLevel()+10);row.markers={}
            row.fallback=row.fill:CreateTexture(nil,"BACKGROUND");row.fallback:SetAllPoints()
            row.fallback:SetTexture("Interface\\AddOns\\Rivals\\Textures\\RivalBarRaised.tga");row.fallback:SetVertexColor(.48,.40,.24,1)
            row.shade=row.layer:CreateTexture(nil,"OVERLAY");row.shade:SetColorTexture(0,0,0,.65)
            row.shade:SetPoint("TOPRIGHT");row.shade:SetPoint("BOTTOMRIGHT");row.shade:SetWidth(252)
            row.labels=CreateFrame("Frame",nil,row);row.labels:SetAllPoints(row);row.labels:SetFrameLevel(row.layer:GetFrameLevel()+10)
            row.name=row.labels:CreateFontString(nil,"OVERLAY","GameFontHighlight");row.name:SetPoint("LEFT",6,0);row.name:SetWidth(180);row.name:SetJustifyH("LEFT");row.name:SetShadowColor(0,0,0,.8);row.name:SetShadowOffset(1,-1)
            row.count=row.labels:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");row.count:SetPoint("RIGHT",-6,0);row.count:SetShadowColor(0,0,0,.8);row.count:SetShadowOffset(1,-1)
            row.border=DP.Theme.Border(row,0,0,252,30)
            row.border:SetFrameLevel(row.labels:GetFrameLevel()+1);row.border:EnableMouse(false)
            row.border:SetBackdropBorderColor(.84,.56,.31,.4)
            zones.rows[i]=row
        end
    end
    local list=summary.topZones or {}
    for i,row in ipairs(zones.rows) do
        local data=list[i];row:SetShown(data~=nil);row.target=nil
        if data then
            row.name:SetText(data.name);row.count:SetText(data.kills..(data.kills==1 and " kill" or " kills"))
            row.target=252*data.kills/list[1].kills;MapStrip(row,data);row.reveal:SetWidth(252);row.shade:SetWidth(252);row.shade:Show()
        end
    end
    zones.empty:SetShown(#list==0);zones.empty:SetText("No zone kills recorded")
    Place(zones,owner,280,#list==0 and 82 or 44+#list*34+10)
    zones.startedAt=GetTime();zones:SetScript("OnUpdate",#list>0 and function(self)
        local t=math.min(1,math.max(0,(GetTime()-self.startedAt)/.75));local eased=t*t*(3-2*t)
        for _,row in ipairs(self.rows) do if row.target then row.shade:SetWidth(math.max(.01,252-row.target*eased));row.shade:SetShown(row.target*eased<252) end end
        if t==1 then self:SetScript("OnUpdate",nil) end
    end or nil);zones:Show()
end
-- Group only the chart columns; retain individual aura identities for attribution.
function C.BuffColumns(summary)
    local list,dmf={}
    for _,buff in pairs(summary.worldBuffsRemoved or {}) do
        if buff.name and buff.name:find("Sayge's Dark Fortune of ",1,true)==1 then
            if not dmf then
                dmf={name="Darkmoon Faire",spellID=23768,count=0}
                list[#list+1]=dmf
            end
            dmf.count=dmf.count+(buff.count or 0)
        else list[#list+1]=buff end
    end
    table.sort(list,function(a,b) return a.count==b.count and a.name<b.name or a.count>b.count end)
    return list
end
local buffTiles={
    [24425]={file="Buff24425.tga",aspect=1.322997416,u=1.000000000,v=0.755859375,x=0.52,y=0.49},
    [22888]={file="Buff22888.tga",aspect=1.438202247,u=1.000000000,v=0.695312500,x=.36,y=.33},
    [23768]={file="Buff23768.tga",aspect=0.684375000,u=0.855468750,v=0.625000000,x=0.36,y=0.47},
    [22817]={file="Buff22817.tga",aspect=0.827759197,u=0.966796875,v=0.583984375,x=0.54,y=0.18},
    [22818]={file="Buff22818.tga",aspect=0.833876221,u=1.000000000,v=0.599609375,x=0.53,y=0.17},
    [22820]={file="Buff22820.tga",aspect=0.888888889,u=1.000000000,v=0.562500000,x=0.5,y=0.18},
    [15366]={file="Buff15366.tga",aspect=0.898245614,u=1.000000000,v=0.556640625,x=0.5,y=0.41},
    [29534]={file="Buff29534.tga",aspect=0.810397554,u=0.517578125,v=0.638671875,x=0.51,y=0.65},
    [16609]={file="Buff16609.tga",aspect=1.051334702,u=1.000000000,v=0.951171875,x=0.49,y=0.49},
}
buffTiles[1216566]=buffTiles[29534]
function C.BuffTileCrop(tile,height)
    local ratio=36/math.max(.01,height)
    local w,h=math.min(1,ratio/tile.aspect),math.min(1,tile.aspect/ratio)
    local x=math.max(0,math.min(1-w,tile.x-w/2))
    local y=math.max(0,math.min(1-h,tile.y-h/2))
    return x*tile.u,(x+w)*tile.u,y*tile.v,(y+h)*tile.v
end
local function BuffHeight(col,height)
    col.bar:SetHeight(math.max(.01,height))
    if col.tile then
        local left,right,top,bottom=C.BuffTileCrop(col.tile,150)
        col.bar:SetTexCoord(left,right,bottom-(bottom-top)*math.min(1,height/150),bottom)
    end
end
function C.ShowBuffs(owner,summary)
    if not buffs then buffs=Base("RivalsWorldBuffTooltip","WORLD BUFFS REMOVED");buffs.columns={} end
    local list=C.BuffColumns(summary)
    local span=#list*39-3
    local width=math.max(280,span+28)
    buffs.caption:SetText((summary.worldBuffRemovalCount or 0).." buffs removed")
    for i,data in ipairs(list) do
        local col=buffs.columns[i]
        if not col then
            col=CreateFrame("Frame",nil,buffs);col:SetSize(36,190)
            col.background=col:CreateTexture(nil,"BACKGROUND")
            col.background:SetPoint("BOTTOM",0,37);col.background:SetSize(36,150)
            col.background:SetVertexColor(.25,.25,.25,1)
            col.bar=col:CreateTexture(nil,"ARTWORK");col.bar:SetPoint("BOTTOM",0,37);col.bar:SetWidth(36)
            col.bar:SetTexture("Interface\\AddOns\\Rivals\\Textures\\RivalBarRaised.tga","CLAMP","CLAMP","LINEAR");col.bar:SetVertexColor(.82,.68,.32,1);col.bar:SetTexCoord(0,1,1,1,0,0,1,0)
            col.icon=col:CreateTexture(nil,"OVERLAY");col.icon:SetSize(36,36);col.icon:SetPoint("BOTTOM")
            col.count=col:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");col.count:SetPoint("BOTTOM",col.bar,"TOP",0,4)
            col.border=DP.Theme.Border(col,0,0,36,150)
            col.border:ClearAllPoints();col.border:SetPoint("BOTTOMLEFT",col,"BOTTOMLEFT",0,37)
            col.border:EnableMouse(false)
            col.border:SetBackdropBorderColor(.84,.56,.31,.4)
            buffs.columns[i]=col
        end
        col:ClearAllPoints();col:SetPoint("BOTTOMLEFT",buffs,"TOPLEFT",(width-span)/2+(i-1)*39,-245)
        col.icon:SetTexture(data.icon or (GetSpellTexture and GetSpellTexture(data.spellID)) or "Interface\\Icons\\INV_Misc_QuestionMark")
        col.tile=buffTiles[data.spellID]
        if col.tile then
            col.bar:SetTexture("Interface\\AddOns\\Rivals\\Textures\\WorldBuffs\\"..col.tile.file,"CLAMP","CLAMP","LINEAR")
            col.bar:SetVertexColor(1,1,1,1)
            col.background:SetTexture("Interface\\AddOns\\Rivals\\Textures\\WorldBuffs\\"..col.tile.file,"CLAMP","CLAMP","LINEAR")
            col.background:SetTexCoord(C.BuffTileCrop(col.tile,150));col.background:Show()
        else
            col.background:Hide()
            col.bar:SetTexture("Interface\\AddOns\\Rivals\\Textures\\RivalBarRaised.tga")
            col.bar:SetVertexColor(.82,.68,.32,1);col.bar:SetTexCoord(0,1,1,1,0,0,1,0)
        end
        col.count:SetText(data.count>0 and data.count or "");col.target=150*data.count/math.max(1,list[1].count);BuffHeight(col,.01);col.bar:SetShown(data.count>0);col:Show()
    end
    for i=#list+1,#buffs.columns do buffs.columns[i]:Hide();buffs.columns[i].target=nil end
    buffs.empty:SetShown(#list==0);buffs.empty:SetText("No world buffs removed yet")
    Place(buffs,owner,width,#list==0 and 82 or 259)
    buffs.startedAt=GetTime();buffs:SetScript("OnUpdate",#list>0 and function(self)
        local t=math.min(1,math.max(0,(GetTime()-self.startedAt)/.75));local eased=t*t*(3-2*t)
        for _,col in ipairs(self.columns) do if col.target then BuffHeight(col,math.max(.01,col.target*eased)) end end
        if t==1 then self:SetScript("OnUpdate",nil) end
    end or nil);buffs:Show()
end
function C.HideZones() if zones then zones:Hide();zones:SetScript("OnUpdate",nil) end end
function C.HideBuffs() if buffs then buffs:Hide();buffs:SetScript("OnUpdate",nil) end end
