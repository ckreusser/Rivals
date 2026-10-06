from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[1]
state=runpy.run_path(str(root/'tests/spend_chart.py'))
lua,dp=state['lua'],state['dp']
for name in ('OverviewCharts.lua','OverviewArchive.lua','WorldPvP.lua'):
    lua.execute((root/name).read_text(encoding='utf-8-sig'),'Rivals',dp)
lua.execute("""
local W,A=DP.WorldPvP,DP.OverviewArchive
local store={encounters={}}
for i=1,270 do
    store.encounters[i]={id=i,timestamp=i,playerGUID='self',playerLevel=60,
        playerDied=i==2,enemyDeaths=1,honorableKills=1,friendlyCount=1,enemyCount=1,
        resultKey=i==2 and 'death' or 'victory',
        location={zone=i<=83 and 'Maraudon' or 'Mulgore',mapID=1443,x=.3,y=.6},
        enemies={{guid='enemy',name='Enemy',class='ROGUE',level=55,died=true,killedAt=1,
            detectedBuffs={world={{spellID=15366,name='Songflower Serenade',removedAt=1}}}}},
        session={worldCombatLog={},portraitCache={huge=true}},
        consumableCost={actors={{guid='enemy',totalCopper=20,pricedCount=1,
            items={{name='Healing Potion',totalCopper=20}}}}}}
end
W.observer={worldPvP=store}
local before=W.Summary()
assert(before.kills==270 and before.worldBuffRemovalCount==270)
assert(before.enemyGoldSpentCopper==5400 and before.currentStreak==268)
W.SetStarred(store.encounters[270],false)
assert(#store.encounters==250 and #store.overviewArchive==20)
assert(not store.overviewArchive[1].session and not store.overviewArchive[1].consumableCost)
local after=W.Summary()
for _,key in ipairs({'kills','deaths','honorableKills','ganks','lowbieGanks','soloWins','soloLosses',
 'currentStreak','longestStreak','mostKilledKills','mostKilledDeaths','encounters',
 'enemyGoldSpentCopper','worldBuffRemovalCount'}) do
 assert(before[key]==after[key],key..' changed after trim')
end
assert(after.topZones[2].name=='Maraudon' and after.topZones[2].kills==83)
W.SetStarred(store.encounters[250],true)
W.SetStarred(store.encounters[250],false)
assert(#store.overviewArchive==20 and W.Summary().kills==270)
-- Saved archive remains effective with a fresh observer and duplicate retained ids.
local reloaded={encounters=store.encounters,overviewArchive=store.overviewArchive,
 enemyGoldArchivedCopper=store.enemyGoldArchivedCopper,
 enemyGoldArchivedCategories=store.enemyGoldArchivedCategories}
W.observer={worldPvP=reloaded}
assert(W.Summary().topZones[2].kills==83 and W.Summary().kills==270)
local recover={encounters={{id=21,timestamp=21},{id=23,timestamp=23}}}
DP.OverviewArchiveRecovery={self={{id=1,timestamp=1},{id=20,timestamp=20},{id=22,timestamp=22}}}
A.Recover(recover,'self');A.Recover(recover,'self')
assert(#recover.overviewArchive==2 and #A.Records(recover)==4)
assert(recover.overviewArchive[1].id==1 and recover.overviewArchive[2].id==20)
""")
print('PASS: lifetime overview survives the 250-record cap, repeated trims, reload, and safe idempotent recovery; spend and buffs are counted once')
