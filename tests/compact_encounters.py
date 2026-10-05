from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
dp=lua.table()
source=root.joinpath('WorldPvP.lua').read_text(encoding='utf-8-sig')
lua.execute(source,'Rivals',dp)
lua.globals().DP=dp
lua.execute('''
local W=DP.WorldPvP
assert(W.CompactEncounterLabel({resultKey='outnumbered_victory',completedSoloSweep=3,peakContestingEnemies=1})=='1v3 VICTORY')
assert(W.CompactEncounterLabel({resultKey='outnumbered_escape',peakContestingEnemies=2})=='1v2 ESCAPE')
assert(W.CompactEncounterLabel({resultKey='outnumbered_partial',peakContestingEnemies=4})=='1v4 FIGHT')
assert(not W.CompactEncounterLabel({resultKey='death'}))
local line=W.HistoryResultLine({resultKey='outnumbered_victory',resultLabel='1v3 VICTORY',completedSoloSweep=3,killingBlows=3})
assert(line:find('1v3 VICTORY',1,true) and line:find('3 KBs',1,true) and not line:find('vs',1,true))
assert(W.HistoryResultLine({resultKey='kills',enemyDeaths=1,killingBlows=1}):find('1 KB|r',1,true))
assert(W.HistoryResultLine({resultKey='death',playerDied=true}):find('Died',1,true))
assert(W.HistoryResultLine({resultKey='disengaged'}):find('Survived',1,true))
local selected,hidden
DP.ShowRivalsCharacterPanel=function() return true end
DP.SetMatchupSource=function(s) assert(s=='world') end
DP.SelectDuelView=function(view,filter,label,back)
 assert(view=='MatchupDetail' and filter.kind=='opponent' and filter.key=='Player-enemy' and filter.world)
 assert(label=='Enemy-Realm' and back=='Opponents');selected=true
end
W.details={Hide=function() hidden=true end}
W.OpenOpponentMatchup({guid='Player-enemy',name='Enemy-Realm'})
assert(selected and not hidden,'opening Matchups closed the encounter details')
selected,hidden=nil,nil
DP.ShowRivalsCharacterPanel=function() return false end
W.OpenOpponentMatchup({guid='Player-enemy',name='Enemy-Realm'})
assert(not selected and not hidden)
''')
assert 'return "MIXED-LEVEL FIGHT", "mixed_level"' in source
assert 'record.resultLabel = W.CompactEncounterLabel(record) or record.resultLabel' in source
assert 'button == "LeftButton" and self.kind == "player"' in source
print('PASS: compact labels, sweep headcount, retroactive label migration, uppercase mixed level, opponent navigation and blocked opening')
