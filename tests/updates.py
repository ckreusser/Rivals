"""Update discovery, notification, and traffic limits under Lua 5.1."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for p in root.glob('*.lua'):
    lua.execute('assert(loadstring(...))', p.read_text(encoding='utf-8-sig'))
source = (root / 'Updates.lua').read_text(encoding='utf-8-sig')
lua.execute("""
DP={}; settings={}; now=0; sent={}; notices={}; tasks={}
guild=true; party=true; raid=false; instance=false; LE_PARTY_CATEGORY_INSTANCE=2
function GetTime() return now end
function UnitName() return 'Tester' end
function GetNormalizedRealmName() return 'Realm' end
function IsInGuild() return guild end
function IsInRaid() return raid end
function IsInGroup(category) if category==2 then return instance end; return party end
C_ChatInfo={RegisterAddonMessagePrefix=function() return true end,
 SendAddonMessage=function(prefix,message,channel) sent[#sent+1]={prefix,message,channel} end}
C_Timer={After=function(delay,fn) tasks[#tasks+1]=fn end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function(self,event,fn) self.event=fn end} end
function flush() local queue=tasks; tasks={}; now=now+5; for _,fn in ipairs(queue) do fn() end end
function say(text) notices[#notices+1]=text end
""")
lua.execute(source, 'Rivals', lua.globals().DP)
lua.execute("""
local U=DP.Updates
assert(U.IsNewer('1.0.103','1.0.99'))
assert(U.IsNewer('2.0.0','1.99.999'))
assert(not U.IsNewer('1.0.9','1.0.103'))
assert(not U.IsNewer('1.0.103','1.0.103'))
assert(not U.IsNewer('1.0.999-beta','1.0.103'))
U.Initialize(settings,'1.0.103',say)
U.ScheduleAnnouncement(); U.ScheduleAnnouncement(); assert(#tasks==1)
flush(); assert(#sent==2 and sent[1][3]=='GUILD' and sent[2][3]=='PARTY')
assert(#notices==0)
U.Receive(U.prefix,'V|1.0.103','GUILD','Other-Realm')
U.Receive(U.prefix,'V|1.0.99','PARTY','Other-Realm')
U.Receive(U.prefix,'V|1.0.999-beta','GUILD','Other-Realm')
U.Receive('Wrong','V|9.0.0','GUILD','Other-Realm')
U.Receive(U.prefix,'V|9.0.0','WHISPER','Other-Realm')
assert(#notices==0 and settings.newestKnownRivalsVersion==nil)
U.Receive(U.prefix,'V|1.0.104','GUILD','Other-Realm')
assert(#notices==1 and notices[1]=='Fresh updates. Same grudges. Get the latest build on CurseForge.')
U.Receive(U.prefix,'V|1.0.105','PARTY','Other-Realm')
assert(#notices==1 and settings.newestKnownRivalsVersion=='1.0.105')
local count=#sent
U.Receive(U.prefix,'Q|1.0.103','GUILD','Tester-Realm'); assert(#sent==count)
for i=1,100 do U.Receive(U.prefix,'Q|1.0.104','GUILD','Other-Realm') end
assert(#sent==count+1 and sent[#sent][2]=='V|1.0.103')
U.Announce(); assert(#sent==count+1)
now=now+60; guild=false; raid=true; U.Announce(); assert(sent[#sent][3]=='RAID')
now=now+60; instance=true; U.Announce(); assert(sent[#sent][3]=='INSTANCE_CHAT')
""")
# Reload: remembered newer release prompts once. Updating clears stale knowledge.
lua.execute(source, 'Rivals', lua.globals().DP)
lua.execute("DP.Updates.Initialize(settings,'1.0.103',say); flush(); assert(#notices==2)")
lua.execute(source, 'Rivals', lua.globals().DP)
lua.execute("DP.Updates.Initialize(settings,'1.0.105',say); flush(); assert(#notices==2 and settings.newestKnownRivalsVersion==nil)")
print('PASS: numeric release comparison, exact notice, session deduplication, cached discovery, update clearing, channel selection, malformed messages, and traffic limits')
