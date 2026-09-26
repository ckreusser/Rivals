local U = DP.Usage
local s = {estimatedStartAt = 10, identity = {guid = "rival"}}
U.Begin(s)
U.items[101] = "Test potion"
U.Observe(s, "me", 9, "SPELL_CAST_SUCCESS", "me", 101, "Test potion", 0)
U.Observe(s, "me", 11, "SPELL_CAST_SUCCESS", "stranger", 101, "Test potion", 0)
U.Observe(s, "me", 11, "SPELL_AURA_APPLIED", "me", 101, "Test potion", 0)
U.Observe(s, "me", 11, "SPELL_CAST_SUCCESS", "me", 202, "Short ability", 179999)
assert(next(s.usage.player) == nil and next(s.usage.opponent) == nil)
U.Observe(s, "me", 12, "SPELL_CAST_SUCCESS", "me", 101, "Test potion", 0)
U.Observe(s, "me", 13, "SPELL_CAST_SUCCESS", "me", 101, "Test potion", 0)
U.Observe(s, "me", 14, "SPELL_CAST_SUCCESS", "rival", 203, "Long ability", 180000)
assert(s.usage.player["101"].count == 2 and s.usage.player["101"].kind == "item")
assert(s.usage.opponent["203"].cooldown == 180)
s.finishedAt = 15
U.Observe(s, "me", 16, "SPELL_CAST_SUCCESS", "me", 101, "Test potion", 0)
assert(s.usage.player["101"].count == 2)
assert(table.concat(U.Tooltip({session = s}), " "):find("[Test potion]|r x2", 1, true))
assert(#U.Tooltip({}) == 0)
U.items = {}
print("PASS: item/3-minute cooldown capture, actor/start/end guards, threshold and historical tooltip")

local fixture = {session={usage={player={
 gem={spellID=23725,name="Gift of Life",kind="item",count=1},
 reck={spellID=1719,name="Recklessness",kind="cooldown",cooldown=1800,count=1},
 racial={spellID=20572,name="Blood Fury",kind="racial",count=2},
 potion={spellID=999,itemID=123,itemName="Test Potion",quality=1,category="potions",kind="item",count=1}
},opponent={charm={spellID=835,name="Tidal Charm",kind="item",count=2}}}}}
local lines=table.concat(U.Tooltip(fixture), "\n")
assert(lines:find("|cffa335ee[Lifegiving Gem]|r",1,true))
assert(lines:find("|cff1eff00[Tidal Charm]|r x2",1,true))
assert(lines:find("|cffffffff[Test Potion]|r",1,true))
assert(lines:find("Recklessness [30 min]",1,true))
assert(lines:find("Blood Fury x2",1,true))
assert(not lines:find("Gift of Life",1,true) and not lines:find("x1",1,true))
assert(#U.Groups(fixture)==4)
local onlyGem=U.Tooltip({session={usage={opponent={gem=fixture.session.usage.player.gem}}}})
assert(#onlyGem==3 and onlyGem[1]:find("Equipment:",1,true))
local racialSession={estimatedStartAt=1,identity={guid="other"}}
U.Observe(racialSession,"me",2,"SPELL_CAST_SUCCESS","other",20572,"Blood Fury",120000)
assert(racialSession.usage.opponent["20572"].kind=="racial")
U.Observe(racialSession,"me",3,"SPELL_CAST_SUCCESS","other",23725,"Gift of Life",0)
assert(racialSession.usage.opponent["23725"].itemID==19341)
print("PASS: conditional usage sections, colored item identities, counts, cooldown durations and opponent item/racial capture")

-- Classic PvP Insignia activations are generic internal item-effect spells, not
-- class cooldowns. Existing World PvP rows must re-render under Equipment and
-- resolve the class/faction-specific item even if they were originally stored as
-- a 5-minute cooldown.
local oldFactionGroup = UnitFactionGroup
UnitFactionGroup = function() return "Horde" end
local insigniaRecord = {
    kind="worldpvp", playerGUID="me", playerClass="WARRIOR",
    enemies={{guid="enemy-druid", class="DRUID", raceFile="NightElf"}},
    session={worldPvP=true, participants={
        ["enemy-druid"]={guid="enemy-druid", class="DRUID", raceFile="NightElf"}
    }}
}
local insigniaDisplay = U.Describe({spellID=23277, guid="enemy-druid", name="Immune Charm/Fear/Stun",
    category="cooldowns", kind="cooldown", cooldown=300}, insigniaRecord)
assert(insigniaDisplay.category=="equipment")
assert(insigniaDisplay.itemID==18863)
assert(insigniaDisplay.text:find("Insignia of the Alliance",1,true))
UnitFactionGroup = oldFactionGroup
print("PASS: Classic class/faction PvP Insignia effects render as Equipment, including legacy cooldown rows")

local oldInfo, oldSpell, oldInventory = GetItemInfo, GetItemSpell, GetInventoryItemID
GetItemInfo = function(id)
    if id == 19341 then return "Lifegiving Gem", "item:19341", 4, 76, 60, "Armor", "Misc", 1, "INVTYPE_TRINKET", 1, 0, 4 end
end
GetItemSpell = function(id) if id == 19341 then return "Gift of Life", 23725 end end
GetInventoryItemID = function(_, slot) if slot == 13 then return 19341 end end
U.Scan()
assert(U.items[23725].itemID == 19341 and U.items[23725].name == "Lifegiving Gem")
local captured={estimatedStartAt=1,identity={guid="other"}}
U.Observe(captured,"me",2,"SPELL_CAST_SUCCESS","me",23725,"Gift of Life",0)
assert(U.Describe(captured.usage.player["23725"]).text == "|cffa335ee[Lifegiving Gem]|r")
GetItemInfo, GetItemSpell, GetInventoryItemID = oldInfo, oldSpell, oldInventory
U.items = {}
print("PASS: inventory scan saves actual item identity and quality instead of activation buff name")

local oldContainerSlots, oldContainerItem = GetContainerNumSlots, GetContainerItemID
local equippedHelmet, bagHelmet = 9394, 10588
GetItemInfo = function(id)
    if id == 9394 then return "Horned Viking Helmet", "item:9394", 3, 42, 40, "Armor", "Plate", 1, "INVTYPE_HEAD", 1, 0, 4 end
    if id == 10588 then return "Goblin Rocket Helmet", "item:10588", 2, 47, 0, "Armor", "Cloth", 1, "INVTYPE_HEAD", 1, 0, 4 end
end
GetItemSpell = function(id)
    if id == 9394 or id == 10588 then return "Reckless Charge", 22641 end
end
GetInventoryItemID = function(_, slot) if slot == 1 then return equippedHelmet end end
GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end
GetContainerItemID = function(bag, slot) if bag == 0 and slot == 1 then return bagHelmet end end
U.Scan()
assert(U.items[22641].candidates and #U.items[22641].candidates == 2)
local horned={estimatedStartAt=1,identity={guid="other"}}
U.Observe(horned,"me",2,"SPELL_CAST_SUCCESS","me",22641,"Reckless Charge",0)
assert(horned.usage.player["22641:9394"].itemID==9394)
assert(horned.usage.player["22641:9394"].itemName=="Horned Viking Helmet")
assert(horned.usage.player["22641:9394"].category=="equipment")

equippedHelmet, bagHelmet = 10588, 9394
U.Scan()
local rocket={estimatedStartAt=1,identity={guid="other"}}
U.Observe(rocket,"me",2,"SPELL_CAST_SUCCESS","me",22641,"Reckless Charge",0)
assert(rocket.usage.player["22641:10588"].itemID==10588)
assert(rocket.usage.player["22641:10588"].itemName=="Goblin Rocket Helmet")
assert(rocket.usage.player["22641:10588"].category=="engineering")

-- Two distinct items sharing Reckless Charge must remain distinct within one duel.
local both={estimatedStartAt=1,identity={guid="other"}}
equippedHelmet, bagHelmet = 9394, 10588
U.Scan()
U.Observe(both,"me",2,"SPELL_CAST_SUCCESS","me",22641,"Reckless Charge",0)
equippedHelmet, bagHelmet = 10588, 9394
U.Scan()
U.Observe(both,"me",3,"SPELL_CAST_SUCCESS","me",22641,"Reckless Charge",0)
assert(both.usage.player["22641:9394"] and both.usage.player["22641:9394"].count==1)
assert(both.usage.player["22641:10588"] and both.usage.player["22641:10588"].count==1)
assert(both.usage.player["22641:9394"].itemName=="Horned Viking Helmet")
assert(both.usage.player["22641:10588"].itemName=="Goblin Rocket Helmet")
GetItemInfo, GetItemSpell, GetInventoryItemID = oldInfo, oldSpell, oldInventory
GetContainerNumSlots, GetContainerItemID = oldContainerSlots, oldContainerItem
U.items = {}
print("PASS: shared activation spells resolve to the actually equipped item instead of bag scan order")

local engineeringFixture={session={usage={player={
    grenade={spellID=4068,name="Iron Grenade",kind="item",count=1},
    cap={spellID=13180,name="Gnomish Mind Control Cap",kind="item",count=1}
},opponent={rocket={spellID=8892,name="Goblin Rocket Boots",kind="item",count=1}}}}}
local engineeringGroups=U.Groups(engineeringFixture)
assert(#engineeringGroups==1 and engineeringGroups[1].key=="engineering")
assert(#engineeringGroups[1].player==2 and #engineeringGroups[1].opponent==1)
assert(U.Describe(engineeringFixture.session.usage.player.grenade).category=="engineering")
assert(U.Describe(engineeringFixture.session.usage.player.cap).category=="engineering")
print("PASS: Engineering Gadgets separates grenades, rocket gear and Gnomish/Goblin devices from Equipment")

-- Usage begins when the duel is accepted/countdown starts, not only when combat starts.
local prestart={acceptedAt=5,estimatedStartAt=10,identity={guid="rival"}}
DP.Usage.Observe(prestart,"player",7,"SPELL_CAST_SUCCESS","player",999001,"Prestart Trinket",180000)
assert(prestart.usage and prestart.usage.player["999001"], "pre-start accepted-window usage should be recorded")
local tooEarly={acceptedAt=5,estimatedStartAt=10,identity={guid="rival"}}
DP.Usage.Observe(tooEarly,"player",4,"SPELL_CAST_SUCCESS","player",999002,"Too Early",180000)
assert(not tooEarly.usage or not tooEarly.usage.player["999002"], "usage before duel acceptance must not be recorded")

-- Legacy consumable migration merges retained usage + buff evidence, supports
-- TSM4 Classic DBMarket, and never mistakes reusable gear for consumables.
do
    local oldGetItemInfo = GetItemInfo
    local oldTSMAPI = TSM_API
    local oldTSM4 = TSMAPI_FOUR
    local oldAuctionator = Auctionator
    local oldAtr = Atr_GetAuctionBuyout

    GetItemInfo = function(id)
        if id == 2458 then return "Elixir of Minor Fortitude", "item:2458", 1, 12, 2, "Consumable", "Elixir", 5, "", 1, 15, 0 end
        -- Simulate an uncached / incomplete gear item: catalog category must
        -- still keep Diamond Flask out of consumable spend.
        if id == 20130 then return "Diamond Flask", "item:20130", 3 end
        return oldGetItemInfo and oldGetItemInfo(id)
    end
    TSM_API = nil
    TSMAPI_FOUR = {
        Item = {ToItemString = function(link) return link and "i:" .. tostring(link:match("item:(%d+)")) end},
        CustomPrice = {GetValue = function(source, itemString)
            if source == "DBMarket" and itemString == "i:2458" then return 3135 end
        end},
    }
    Auctionator, Atr_GetAuctionBuyout = nil, nil

    local record = {
        timestamp = 1700000000,
        playerGUID = "Player-1", playerName = "Alice", playerClass = "WARRIOR", playerLevel = 60,
        enemies = {{
            guid = "Enemy-1", name = "Toso", class = "HUNTER",
            detectedBuffs = {
                consumables = {minorfort = {spellID=2378, name="Elixir of Minor Fortitude", activeAtEngagement=true}},
                all = {minorfort = {spellID=2378, name="Elixir of Minor Fortitude", activeAtEngagement=true}},
            },
        }},
        session = {
            participants = { ["Player-1"]={name="Alice",class="WARRIOR"}, ["Enemy-1"]={name="Toso",class="HUNTER"} },
            worldUsage = {version=2, events={{
                guid="Player-1", actorName="Alice", spellID=24427, sourceSpellID=24427,
                itemID=20130, itemName="Diamond Flask", name="Diamond Flask", kind="item", category="equipment", count=1,
            }}},
            worldCombatLog = {},
        },
    }
    local snap = U.CaptureLegacyWorldConsumableCost(record, 1700000100, {}, true)
    assert(snap.legacyBackfillVersion == U.LEGACY_CONSUMABLE_BACKFILL_VERSION)
    assert(snap.legacyAuraInferredCount == 1)
    assert(snap.pricedCount == 1 and snap.unpricedCount == 0 and snap.totalCopper == 3135)
    assert(#snap.actors == 1 and snap.actors[1].guid == "Enemy-1")
    assert(#snap.actors[1].items == 1 and snap.actors[1].items[1].itemID == 2458)
    assert(snap.actors[1].items[1].priceSource == "TradeSkillMaster")
    assert(U.IsConsumableWorldEvent({spellID=24427,itemID=20130,name="Diamond Flask",category="equipment",kind="item"}) == false)

    -- Conjured mage mana gems remain usage events but must never add gold cost.
    local manaSession = {playerGUID="Player-1", playerName="Alice", playerClass="MAGE", participants={
        ["Player-1"]={name="Alice", class="MAGE"}}, worldUsage={events={{
        guid="Player-1", actorName="Alice", spellID=10058, itemID=8008, itemName="Mana Ruby",
        name="Mana Ruby", kind="item", category="potions", consumable=true, count=1,
    }}}}
    local manaSnap = U.CaptureWorldConsumableCost(manaSession, {capturedAt=1700000100, priceCache={}})
    assert(manaSnap.totalCopper == 0 and manaSnap.pricedCount == 0 and manaSnap.unpricedCount == 0 and #manaSnap.actors == 0)
    local frozen = {consumableCost={totalCopper=5106,pricedCount=1,unpricedCount=1,partial=true,actors={{guid="Player-1",name="Alice",totalCopper=5106,pricedCount=1,unpricedCount=1,items={
        {itemID=8008,name="Mana Ruby",count=1,unpriced=true},
        {itemID=13444,name="Greater Mana Potion",count=1,unitCopper=5106,totalCopper=5106},
    }}}}}
    assert(U.SanitizeConsumableCostSnapshot(frozen) == true)
    assert(frozen.consumableCost.totalCopper == 5106 and frozen.consumableCost.pricedCount == 1 and frozen.consumableCost.unpricedCount == 0 and not frozen.consumableCost.partial)
    assert(#frozen.consumableCost.actors == 1 and #frozen.consumableCost.actors[1].items == 1 and frozen.consumableCost.actors[1].items[1].itemID == 13444)

    GetItemInfo, TSM_API, TSMAPI_FOUR = oldGetItemInfo, oldTSMAPI, oldTSM4
    Auctionator, Atr_GetAuctionBuyout = oldAuctionator, oldAtr
end
print("PASS: legacy consumable backfill merges buff evidence, reads TSM4 DBMarket, and excludes reusable gear")


-- Legacy economy reconstruction must recover old Items & Abilities rows whose
-- itemID was not retained, infer Chronoboon use from the saved Supercharged aura,
-- and value BOP Zanzas/Jujus by their one-for-one tradeable source materials.
do
    local oldGetItemInfo = GetItemInfo
    local oldTSMAPI = TSM_API
    local oldTSM4 = TSMAPI_FOUR
    local oldAuctionator = Auctionator
    local oldAtr = Atr_GetAuctionBuyout

    local names = {
        [13506]="Flask of Petrification", [2091]="Magic Dust", [5634]="Free Action Potion",
        [14530]="Heavy Runecloth Bandage", [184937]="Chronoboon Displacer", [184938]="Supercharged Chronoboon Displacer",
        [20081]="Swiftness of Zanza", [19708]="Blue Hakkari Bijou", [12451]="Juju Power", [12431]="Winterfall E'ko",
    }
    GetItemInfo = function(id)
        local name = names[id]
        if name then return name, "item:"..id, 1, 60, 0, "Consumable", "", 20, "", 1, 0, 0 end
        return oldGetItemInfo and oldGetItemInfo(id)
    end
    TSM_API = nil
    local prices = {
        [13506]=120000, [2091]=5000, [5634]=35000, [14530]=2500, [184937]=100000,
        [19707]=52000, [19708]=49105, [19709]=60000, [19710]=70000, [19711]=80000,
        [19712]=90000, [19713]=100000, [19714]=110000, [19715]=120000,
        [12431]=76543,
    }
    TSMAPI_FOUR = {
        Item = {ToItemString = function(link) return link and "i:" .. tostring(link:match("item:(%d+)")) end},
        CustomPrice = {GetValue = function(source, itemString)
            if source ~= "DBMarket" then return nil end
            local id = tonumber(tostring(itemString):match("i:(%d+)"))
            return id and prices[id] or nil
        end},
    }
    Auctionator, Atr_GetAuctionBuyout = nil, nil

    local zanza, _, zanzaKey, _, zanzaProxy = U.GetSnapshotPrice(20081)
    assert(zanza == 49105 and zanzaProxy == 19708)
    assert(zanzaKey and zanzaKey:find("1x Blue Hakkari Bijou", 1, true), "Zanza must name the actual one-Bijou proxy")
    local juju, _, jujuKey, _, jujuProxy = U.GetSnapshotPrice(12451)
    assert(juju == 76543 and jujuProxy == 12431)
    assert(jujuKey and jujuKey:find("1x Winterfall E'ko", 1, true))
    local boon, _, boonKey, _, boonProxy = U.GetSnapshotPrice(184938)
    assert(boon == 100000 and boonProxy == 184937)
    assert(boonKey and boonKey:find("1x Chronoboon Displacer", 1, true))

    local record = {
        timestamp=1700001000, playerGUID="Player-1", playerName="Zurker", playerClass="WARRIOR", playerLevel=60,
        enemies={{guid="Enemy-1",name="Burp",class="ROGUE",detectedBuffs={
            consumables={juju={spellID=16323,name="Juju Power",activeAtEngagement=true}},
            all={juju={spellID=16323,name="Juju Power",activeAtEngagement=true}},
        }}},
        session={
            participants={ ["Player-1"]={name="Zurker",class="WARRIOR"}, ["Enemy-1"]={name="Burp",class="ROGUE"} },
            worldUsage={version=2,events={
                -- Old builds retained these rows well enough to render them in Items & Abilities,
                -- but not well enough for the cost backfill because itemID was missing.
                {t=14.1,guid="Enemy-1",actorName="Burp",spellID=17624,name="Flask of Petrification",category="potions",kind="item",count=1},
                {t=43.0,guid="Enemy-1",actorName="Burp",spellID=1090,name="Magic Dust",category="potions",kind="item",count=1},
                {t=240.9,guid="Player-1",actorName="Zurker",spellID=6615,name="Free Action Potion",category="potions",kind="item",count=1},
                {t=271.7,guid="Player-1",actorName="Zurker",spellID=18610,name="Heavy Runecloth Bandage",category="potions",kind="item",count=1},
            }},
            worldCombatLog={
                {t=84.1,event="SPELL_AURA_APPLIED",sourceGUID="Enemy-1",sourceName="Burp",destGUID="Enemy-1",destName="Burp",spellID=349981,spellName="Supercharged Chronoboon Displacer"},
            },
        },
    }
    local rebuilt = U.ReconstructLegacyWorldUsage(record, record.session)
    local byItem = {}
    for _, event in ipairs(rebuilt.events) do byItem[event.itemID] = (byItem[event.itemID] or 0) + (event.count or 1) end
    assert(byItem[13506] == 1 and byItem[2091] == 1 and byItem[5634] == 1 and byItem[14530] == 1)
    assert(byItem[184937] == 1, "Supercharged aura must recover one consumed Chronoboon")
    assert(byItem[12451] == 1, "retained Juju buff must infer one Juju Power")

    local snap = U.CaptureLegacyWorldConsumableCost(record, 1700002000, {}, true)
    assert(snap.legacyBackfillVersion == U.LEGACY_CONSUMABLE_BACKFILL_VERSION)
    assert(snap.pricedCount == 6 and snap.unpricedCount == 0)
    local expected = 120000 + 5000 + 35000 + 2500 + 100000 + 76543
    assert(snap.totalCopper == expected, "legacy reconstruction total mismatch: "..tostring(snap.totalCopper).." ~= "..expected)
    local actors = {}
    for _, actor in ipairs(snap.actors) do actors[actor.guid] = actor end
    assert(actors["Player-1"] and #actors["Player-1"].items == 2, "player FAP/bandage spend must be included")
    assert(actors["Enemy-1"] and #actors["Enemy-1"].items == 4, "enemy uses and inferred buff spend must be included")

    GetItemInfo, TSM_API, TSMAPI_FOUR = oldGetItemInfo, oldTSMAPI, oldTSM4
    Auctionator, Atr_GetAuctionBuyout = oldAuctionator, oldAtr
end
print("PASS: legacy rows recover item IDs, Chronoboon aura is retained, and Zanza/Juju proxies are one-for-one")


-- Noggenfogger is a fixed vendor purchase and must bypass market add-ons.
do
    local oldTSMAPI, oldTSM4, oldAuctionator, oldAtr = TSM_API, TSMAPI_FOUR, Auctionator, Atr_GetAuctionBuyout
    TSM_API = {GetCustomPriceValue=function() return 999999 end}
    TSMAPI_FOUR = nil
    Auctionator, Atr_GetAuctionBuyout = nil, nil
    local value, source, sourceKey = U.GetSnapshotPrice(8529)
    assert(value == 700 and source == "Vendor" and sourceKey == "Fixed vendor price")
    TSM_API, TSMAPI_FOUR, Auctionator, Atr_GetAuctionBuyout = oldTSMAPI, oldTSM4, oldAuctionator, oldAtr
end
print("PASS: Noggenfogger uses fixed 7-silver vendor replacement cost")


-- A current-generation false-zero snapshot must not permanently suppress legacy
-- evidence that the Items & Abilities pane can still reconstruct.
do
    local record = {
        timestamp=1700003000, playerGUID="Player-1", playerName="Zurker", playerClass="WARRIOR", playerLevel=60,
        enemies={{guid="Enemy-1",name="Burp",class="ROGUE"}},
        session={
            participants={ ["Player-1"]={name="Zurker",class="WARRIOR"}, ["Enemy-1"]={name="Burp",class="ROGUE"} },
            worldUsage={version=1,events={
                {t=14.1,guid="Enemy-1",actorName="Burp",spellID=17624,name="Flask of Petrification",category="potions",kind="item",count=1},
            }},
            worldCombatLog={},
        },
        consumableCost={backfilled=true,legacyBackfillVersion=U.LEGACY_CONSUMABLE_BACKFILL_VERSION,totalCopper=0,pricedCount=0,unpricedCount=0,actors={}},
    }
    assert(U.NeedsLegacyConsumableBackfill(record) == true, "false-zero legacy snapshots with retained usage must self-repair")
    record.consumableCost.unpricedCount = 1
    record.consumableCost.actors = {{guid="Enemy-1",name="Burp",items={{itemID=13506,name="Flask of Petrification",count=1,unpriced=true}},totalCopper=0,pricedCount=0,unpricedCount=1}}
    assert(U.NeedsLegacyConsumableBackfill(record) == false, "complete explicitly captured unpriced evidence must remain frozen")
end
print("PASS: current-generation false-zero legacy consumable snapshots self-repair from retained usage")


-- Partial legacy snapshots must self-repair when retained Items & Abilities
-- evidence contains additional participants/items. Canonical spell/name data
-- must win over stale item IDs and stale consumable=false flags.
do
    local record = {
        timestamp=1700004000, playerGUID="Player-1", playerName="Zurker", playerClass="WARRIOR", playerLevel=60,
        enemies={{guid="Enemy-1",name="Burp",class="ROGUE"}},
        session={
            participants={ ["Player-1"]={name="Zurker",class="WARRIOR"}, ["Enemy-1"]={name="Burp",class="ROGUE"} },
            worldUsage={version=1,events={
                {t=14.1,guid="Enemy-1",actorName="Burp",spellID=17624,itemID=17624,name="Flask of Petrification",category="potions",kind="item",consumable=false,count=1},
                {t=43.0,guid="Enemy-1",actorName="Burp",spellID=1090,itemID=2091,name="Magic Dust",category="potions",kind="item",count=1},
                {t=240.9,guid="Player-1",actorName="Zurker",spellID=6615,itemID=6615,name="[Free Action Potion]",category="potions",kind="item",consumable=false,count=1},
                {t=271.7,guid="Player-1",actorName="Zurker",spellID=18610,name="Heavy Runecloth Bandage",category="potions",kind="item",count=1},
            }},
            worldCombatLog={},
        },
        consumableCost={
            backfilled=true, legacyBackfillVersion=U.LEGACY_CONSUMABLE_BACKFILL_VERSION, totalCopper=5000, pricedCount=1, unpricedCount=0,
            actors={{guid="Enemy-1",name="Burp",items={{itemID=2091,name="Magic Dust",count=1,totalCopper=5000}},totalCopper=5000,pricedCount=1,unpricedCount=0}},
        },
    }
    assert(U.NeedsLegacyConsumableBackfill(record) == true, "partial one-item snapshot must repair against four retained consumables")
    local rebuilt = U.ReconstructLegacyWorldUsage(record, record.session)
    local byItem = {}
    for _, event in ipairs(rebuilt.events) do byItem[event.itemID] = (byItem[event.itemID] or 0) + (event.count or 1) end
    assert(byItem[13506] == 1 and byItem[2091] == 1 and byItem[5634] == 1 and byItem[14530] == 1, "all four legacy Items & Abilities rows must survive reconstruction")
end
print("PASS: partial legacy ledger self-repairs from all retained participant consumables")

-- Distinct Noggenfogger result auras prove distinct drinks. The same aura copied
-- into both detected buff buckets must not double-count.
do
    local record = {
        timestamp=1700005000, playerGUID="Player-1", playerName="Zurker", playerClass="WARRIOR", playerLevel=60,
        enemies={{guid="Enemy-1",name="Puff",class="ROGUE",detectedBuffs={
            consumables={
                skeleton={spellID=16591,name="Noggenfogger Elixir",activeAtEngagement=true},
                shrink={spellID=16595,name="Noggenfogger Elixir",activeAtEngagement=true},
            },
            all={
                skeleton={spellID=16591,name="Noggenfogger Elixir",activeAtEngagement=true},
                shrink={spellID=16595,name="Noggenfogger Elixir",activeAtEngagement=true},
            },
        }}},
        session={participants={ ["Player-1"]={name="Zurker",class="WARRIOR"}, ["Enemy-1"]={name="Puff",class="ROGUE"} }, worldCombatLog={}},
    }
    local rebuilt = U.ReconstructLegacyWorldUsage(record, record.session)
    local count = 0
    for _, event in ipairs(rebuilt.events or {}) do if event.itemID == 8529 then count = count + (event.count or 1) end end
    assert(count == 2, "two distinct Noggenfogger result auras must infer two elixirs, got "..tostring(count))
    local snap = U.CaptureLegacyWorldConsumableCost(record, 1700005001, {}, true)
    assert(snap.totalCopper == 1400 and snap.pricedCount == 2, "two Noggenfoggers must cost 14 silver total")
end
print("PASS: distinct Noggenfogger result auras infer separate vendor-priced drinks")
