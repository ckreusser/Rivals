local _,DP=...
local A={};DP.OverviewArchive=A
local fields={"id","timestamp","playerGUID","playerLevel","playerDied","enemyDeaths","honorableKills",
    "friendlyCount","enemyCount","contestingEnemyCount","resultKey","pressureModelVersion",
    "completedSoloSweep","peakContestingEnemies"}
local enemyFields={"guid","name","class","level","died","pressuredPlayer",
    "pvpRankObserved","pvpRankIndex","pvpRankNumber","pvpRankCapturedAt"}
local function Copy(source,keys)
    local out={}
    for _,key in ipairs(keys) do out[key]=source[key] end
    return out
end
function A.Compact(record,known)
    local out=Copy(record,fields)
    out.overviewArchived=true
    if record.location then out.location=Copy(record.location,{"zone","subzone","mapID","x","y"}) end
    out.enemies={}
    for _,enemy in ipairs(record.enemies or {}) do out.enemies[#out.enemies+1]=Copy(enemy,enemyFields) end
    -- Keep one map point per encounter; never retain combat logs or portraits.
    if record.killLocations and record.killLocations[1] then
        out.killLocations={Copy(record.killLocations[1],{"zone","subzone","mapID","x","y"})}
    end
    local buffs={worldBuffsRemoved={},worldBuffRemovalCount=0}
    DP.OverviewCharts.AddBuffs(buffs,record,known)
    out.archivedBuffs=buffs.worldBuffsRemoved
    return out
end
function A.Add(store,record,known)
    store.overviewArchive=store.overviewArchive or {}
    for _,entry in ipairs(store.overviewArchive) do if entry.id==record.id then return false end end
    store.overviewArchive[#store.overviewArchive+1]=A.Compact(record,known)
    return true
end
function A.Records(store)
    local out,seen={},{}
    -- Prefer retained records, which can still receive repairs and edits.
    for _,record in ipairs(store and store.encounters or {}) do
        out[#out+1]=record
        if record.id then seen[record.id]=true end
    end
    for _,record in ipairs(store and store.overviewArchive or {}) do
        if not seen[record.id] then out[#out+1]=record;seen[record.id]=true end
    end
    table.sort(out,function(a,b)
        if (a.timestamp or 0)~=(b.timestamp or 0) then return (a.timestamp or 0)<(b.timestamp or 0) end
        return (a.id or 0)<(b.id or 0)
    end)
    return out
end
function A.Recover(store,guid)
    local data=DP.OverviewArchiveRecovery and DP.OverviewArchiveRecovery[guid]
    if not data or store.overviewRecoveryApplied then return end
    local seen,first={},nil
    for _,record in ipairs(A.Records(store)) do seen[record.id]=true end
    for _,record in ipairs(store.encounters or {}) do
        if not record.starred and record.id then first=math.min(first or record.id,record.id) end
    end
    if not first then return end
    store.overviewArchive=store.overviewArchive or {}
    for _,record in ipairs(data) do
        -- Only recover aged-out records, never deliberate gaps inside history.
        if record.id<first and not seen[record.id] then
            store.overviewArchive[#store.overviewArchive+1]=record;seen[record.id]=true
        end
    end
    store.overviewRecoveryApplied=true
end
