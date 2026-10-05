from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
source=root.joinpath('Usage.lua').read_text(encoding='utf-8-sig')
lua=LuaRuntime()
lua.execute('''
DP={WorldPvP={}}; identity={guid='enemy',portraitAppearance={slotCount=3}}
function DuelIdentity() return identity end
function DP.WorldPvP.ApplyOpponentPortrait(frame,enemy)
 assert(frame.enemy==enemy,'retry identity missing when shared loader starts')
 frame.requested=enemy
end
''')
start=source.index('local function ApplyDuelPortrait(')
end=source.index('local function RefreshDuelBuffBox(',start)
lua.execute(source[start:end].replace('local function ApplyDuelPortrait(', 'function ApplyDuelPortrait(',1))
lua.execute('''
local frame={}
ApplyDuelPortrait(frame,{})
assert(frame.requested==identity)
local previous=identity;identity={guid='next'}
ApplyDuelPortrait(frame,{})
assert(frame.enemy==identity and frame.enemy~=previous,'switched duel retained old opponent')
''')
create=source.split('local function CreateDuelPortrait(',1)[1].split('local function ApplyDuelPortrait(',1)[0]
assert 'frame.portraitSpinnerFrame=CreateFrame' in create
assert 'frame.portraitSpinnerFrame:Hide()' in create
print('PASS: duel card supplies retry identity before portrait loading, record switching replaces identity, loading indicator available')
