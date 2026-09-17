local function eq(actual, expected, label)
    assert(actual == expected, string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
end

local function snap(class, points, talents, twoHanded, hasOffhand)
    local lower = {}
    for _, name in ipairs(talents or {}) do lower[name:lower()] = {rank = 1} end
    return {class = class, points = points, talentsLower = lower, twoHanded = twoHanded, hasOffhand = hasOffhand}
end

eq(DP.Specs.Classify(snap("WARRIOR", {20,31,0}, {"Bloodthirst"}, true, false)), "2H Fury", "20/31/0 2H Fury")
eq(DP.Specs.Classify(snap("WARRIOR", {31,20,0}, {"Mortal Strike"}, true, false)), "Arms", "31/20 Arms")
eq(DP.Specs.Classify(snap("ROGUE", {21,3,27}, {"Cold Blood", "Hemorrhage", "Preparation"})), "CB/Hemo", "CB Hemo")
eq(DP.Specs.Classify(snap("SHAMAN", {30,0,21}, {"Nature's Swiftness"})), "Elemental/NS", "Elemental NS")
eq(DP.Specs.Classify(snap("DRUID", {7,13,31}, {"Swiftmend", "Feral Charge"})), "Swiftmend/FC", "Druid Swiftmend FC")
eq(DP.Specs.Classify(snap("WARLOCK", {20,31,0}, {"Soul Link", "Nightfall"})), "SL/Nightfall", "Warlock SL Nightfall")
eq(DP.Specs.Classify(snap("HUNTER", {0,21,30}, {"Lightning Reflexes", "Scatter Shot"})), "LR/Scatter", "Hunter LR Scatter")
eq(DP.Specs.Classify(snap("MAGE", {17,0,34}, {"Ice Barrier"})), "Deep Frost", "Mage deep frost")
eq(DP.Specs.Classify(snap("MAGE", {0,24,27}, {"Blast Wave", "Ice Barrier"})), "Elementalist", "Mage elementalist")
eq(DP.Specs.Classify(snap("PALADIN", {1,25,25}, {"Reckoning"})), "Reckoning", "Paladin reckoning")
eq(DP.Specs.Classify(snap("PRIEST", {32,19,0}, {"Power Infusion", "Searing Light"})), "Smite/PI", "Priest smite PI")
eq(DP.Specs.Classify(snap("WARRIOR", {20,31,0}, {"Bloodthirst"}, false, true)), "2H Fury", "20/31/0 remains 2H Fury while weapon swapped")

local label = DP.Specs.InferCombat("WARRIOR", {['death wish'] = true})
eq(label, "Fury", "Death Wish implies Fury investment")
label = DP.Specs.InferCombat("WARRIOR", {['sweeping strikes'] = true})
eq(label, "Arms", "Sweeping Strikes implies Arms investment")
label = DP.Specs.InferCombat("WARRIOR", {['bloodthirst'] = true})
eq(label, "Fury", "combat fury")
label = DP.Specs.InferCombat("MAGE", {['presence of mind'] = true, ['pyroblast'] = true})
eq(label, "PoM Pyro", "combat pom pyro")

-- Stored duel usage must backfill combat inference even if the live event missed class resolution.
local deathWishRecord = {
    opponent = "Zurker-Whitemane",
    session = {
        identity = {guid = "Player-1-TEST", name = "Zurker-Whitemane"},
        usage = {opponent = {dw = {spellID = 12328, name = "Death Wish", kind = "cooldown"}}, player = {}},
    },
}
local deathWishSpec, deathWishProfile = DP.Specs.Resolve(deathWishRecord)
eq(deathWishSpec, "Fury", "stored Death Wish usage backfills Fury inference")
eq(deathWishProfile.class, "WARRIOR", "Death Wish backfills Warrior class")

-- Spec knowledge is duel-scoped: the same opponent may respec between matches.
local secondDuel = {
    opponent = "Zurker-Whitemane",
    session = {identity = {guid = "Player-1-TEST", name = "Zurker-Whitemane", class = "WARRIOR"}, usage = {opponent = {}, player = {}}},
}
local secondSpec = DP.Specs.Resolve(secondDuel)
eq(secondSpec, nil, "spec does not leak from another duel against the same opponent")
assert(DP.Specs.BindInspect(secondDuel, {guid = "Player-1-TEST", name = "Zurker-Whitemane", class = "WARRIOR", label = "2H Fury", build = "20/31/0", source = "inspect"}))
local inspectedSpec, inspectedProfile = DP.Specs.Resolve(secondDuel)
eq(inspectedSpec, "2H Fury", "inspect upgrades only the bound duel")
eq(inspectedProfile.source, "inspect", "inspect source retained on duel")
eq(DP.Specs.Resolve(deathWishRecord), "Fury", "older duel keeps its own inferred spec")
