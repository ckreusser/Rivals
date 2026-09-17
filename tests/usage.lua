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
