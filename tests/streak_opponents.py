"""Current streak opponent details must match retained and archived kills."""
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
state = runpy.run_path(str(root / 'tests/overview_retention.py'))
lua = state['lua']
lua.execute('''
local W = DP.WorldPvP
local original = W.Summary()
assert(#original.currentStreakOpponents == 1)
assert(original.currentStreakOpponents[1].kills == original.currentStreak)
assert(original.topStreaks[1].kills==original.currentStreak and original.topStreaks[1].current)

local function Record(id, enemies, died, kills)
    return {id=id,timestamp=id,enemyDeaths=kills or 1,playerDied=died,
        enemies=enemies,friendlyCount=1,enemyCount=#enemies}
end
local function Enemy(name, died)
    return {guid=name,name=name,class='HUNTER',level=60,died=died,pvpRankObserved=true,pvpRankNumber=10,pvpRankIndex=14}
end
local archived = Record(3,{Enemy('Alice',true)})
archived.overviewArchived = true
W.observer={worldPvP={
    overviewArchive={archived},
    encounters={
        Record(5,{Enemy('Alice',true),Enemy('Survivor',false)}),
        Record(1,{Enemy('Old',true)}),
        Record(4,{Enemy('Bob',true)}),
        Record(2,{Enemy('Trade',true)},true),
    }
}}
local s=W.Summary()
assert(s.currentStreak==3 and #s.currentStreakOpponents==2)
assert(s.currentStreakOpponents[1].name=='Alice' and s.currentStreakOpponents[1].kills==2)
assert(s.currentStreakOpponents[2].name=='Bob' and s.currentStreakUnknownKills==0)
assert(s.currentStreakOpponents[1].class=='HUNTER' and s.currentStreakOpponents[1].pvpRankNumber==10)
local compact=DP.OverviewArchive.Compact(archived,{})
assert(compact.enemies[1].pvpRankNumber==10 and compact.enemies[1].pvpRankIndex==14)
table.insert(W.observer.worldPvP.encounters,Record(6,{},false,2))
s=W.Summary();assert(s.currentStreak==5 and s.currentStreakUnknownKills==2)
table.insert(W.observer.worldPvP.encounters,Record(7,{},true,0))
s=W.Summary();assert(s.currentStreak==0 and #s.currentStreakOpponents==0 and s.currentStreakUnknownKills==0)
assert(#s.topStreaks==2 and s.topStreaks[1].kills==5 and s.topStreaks[2].kills==2)
assert(s.topStreaks[1].startedAt==3 and s.topStreaks[1].endedAt==7 and not s.topStreaks[1].current)
-- Rank distinct runs, including trade kills, ties, archived records, and an active run.
W.observer={worldPvP={overviewArchive={Record(1,{},false,8)},encounters={
    Record(2,{},true,0),Record(3,{},true,12),Record(4,{},false,5),
    Record(5,{},true,7),Record(6,{},true,3),Record(7,{},false,12)}}}
s=W.Summary()
assert(#s.topStreaks==3 and s.longestStreak==12 and s.currentStreak==12)
assert(s.topStreaks[1].current and s.topStreaks[1].startedAt==7)
assert(s.topStreaks[2].startedAt==4 and s.topStreaks[2].endedAt==5 and s.topStreaks[2].kills==12)
assert(s.topStreaks[3].startedAt==3 and s.topStreaks[3].kills==12)
W.observer={worldPvP={encounters={}}};s=W.Summary();assert(#s.topStreaks==0)
''')

source = (root / 'WorldPvP.lua').read_text(encoding='utf-8-sig')
lua.execute((root / 'Theme.lua').read_text(encoding='utf-8-sig'), 'Rivals', state['dp'])
short_start = source.index('local function ShortName(')
short_end = source.index('\nend', short_start) + len('\nend')
start = source.index('    local function ShowStreakTooltip(')
end = source.index('\n    -- Tile the lower plaque', start)
lua.execute('''
W=DP.WorldPvP
RAID_CLASS_COLORS={HUNTER={r=.67,g=.83,b=.45}}
summaryCalls=0
GameTooltip={SetOwner=function() end,SetText=function(self,title) self.title=title end,
    AddLine=function(self,text) self.lines[#self.lines+1]=text end,
    AddDoubleLine=function(self,a,b) self.rows[#self.rows+1]={a,b} end,Show=function() end}
function W.Summary()
    summaryCalls=summaryCalls+1
    local s={currentStreak=10000,longestStreak=10000,currentStreakOpponents={},topStreaks={
        {kills=10000,current=true,startedAt=1,endedAt=2},
        {kills=79,current=false,startedAt=1,endedAt=2},
        {kills=50,current=false,startedAt=1,endedAt=2}}}
    for i=1,10000 do s.currentStreakOpponents[i]={name='Enemy'..i..'-Realm',kills=1,class='HUNTER',pvpRankNumber=10} end
    return s
end
''')
lua.execute(source[short_start:short_end] + '\n' + source[start:end] + '''
local owner={}
local seen={}
for offset=0,9996,12 do
    owner.streakOpponentOffset=offset;GameTooltip.rows={};GameTooltip.lines={}
    ShowStreakTooltip(owner,false)
    assert(owner.streakOpponentOffset==offset)
    assert(#GameTooltip.rows==1+math.min(12,10000-offset))
    for row=2,#GameTooltip.rows do
        local label=GameTooltip.rows[row][1]
        assert(label:find('PvPRank10:14:14',1,true) and label:find('|cffabd473',1,true))
        assert(not label:find('-Realm',1,true))
        local id=tonumber(label:match('Enemy(%d+)'))
        assert(not seen[id]);seen[id]=true
    end
    assert(not table.concat(GameTooltip.lines):find('Leaving combat',1,true))
end
for i=1,10000 do assert(seen[i]) end
assert(summaryCalls==1,'paging rescanned all history')
for _,offset in ipairs({12000,-12}) do
    owner.streakOpponentOffset=offset;GameTooltip.rows={};GameTooltip.lines={}
    ShowStreakTooltip(owner,false)
    assert(owner.streakOpponentOffset==math.max(0,math.min(offset,9996)))
end
GameTooltip.rows={};GameTooltip.lines={}
ShowStreakTooltip({},true)
assert(GameTooltip.title=='Best Streak' and #GameTooltip.rows==3 and #GameTooltip.lines==0)
assert(GameTooltip.rows[1][1]:find('Current',1,true) and GameTooltip.rows[1][2]=='10000 kills')
assert(GameTooltip.rows[2][2]=='79 kills' and GameTooltip.rows[3][2]=='50 kills')
date=os.date
local function Stamp(year,month,day) return os.time({year=year,month=month,day=day,hour=12}) end
for _,case in ipairs({
    {Stamp(2026,9,18),Stamp(2026,9,21),'Sep 18–21, 2026'},
    {Stamp(2026,9,30),Stamp(2026,10,2),'Sep 30–Oct 2, 2026'},
    {Stamp(2026,12,31),Stamp(2027,1,2),'Dec 31, 2026–Jan 2, 2027'},
    {Stamp(2026,10,5),Stamp(2026,10,5),'Oct 5, 2026'},
}) do
    GameTooltip.rows={};GameTooltip.lines={}
    ShowStreakTooltip({streakSummary={topStreaks={{kills=79,startedAt=case[1],endedAt=case[2]}}}},true)
    assert(#GameTooltip.rows==1 and #GameTooltip.lines==0)
    assert(GameTooltip.rows[1][1]:find(case[3],1,true),GameTooltip.rows[1][1])
end
''')
print('PASS: streak opponents, archived rank/class, death resets, name formatting, compact tooltips, and 10,000 opponents across all pages with one summary scan')
