from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
s=root.joinpath('Views.lua').read_text(encoding='utf-8-sig')
lua=LuaRuntime()
dp=lua.table()
lua.execute(s,'Rivals',dp)
lua.globals().DP=dp
lua.execute('''
local V=DP.Views
local records={
 {modelVersion=3,duelMode='rated',status='matched-request-history-only',won=true},
 {modelVersion=3,modeReason='Casual preference',status='matched-request-history-only',won=true},
 {modelVersion=3,status='matched-request-history-only',won=false},
 {modelVersion=1,status='matched-request-history-only',won=true},
 {modelVersion=2,status='matched-request-history-only',won=false},
}
assert(V.Mode(records[1])=='Rated')
for i=2,5 do assert(V.Mode(records[i])=='Casual') end
assert(#V.FilterHistory(records,'Casual')==4)
assert(#V.FilterHistory(records,'Rated')==1)
assert(#V.FilterHistory(records,'All')==5)
local totals=V.RecordTotals(records)
assert(totals.Casual.wins==2 and totals.Casual.losses==2 and totals.Rated.wins==1)
assert(#V.ModeDetails(records)==2)
''')
assert 'historySourceButton:SetAnchor(30, -104)' in s
assert 'Unconfirmed duels' not in s and 'Legacy duels' not in s
block=s.split('return {{text = "All encounters"',1)[1].split('\n        end,',1)[0]
labels=['Starred','World PvP','All duels','Rated duels','Casual duels']
assert [block.index(f'text = "{x}"') for x in labels]==sorted(block.index(f'text = "{x}"') for x in labels)
print('PASS: aligned History filter, ordered categories, casual includes unconfirmed/legacy, totals preserve records')
