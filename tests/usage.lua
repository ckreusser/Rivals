local U = DP.Usage
local s = {estimatedStartAt = 10, identity = {guid = "rival"}}
U.Begin(s)
U.items[101] = "Test potion"
U.Observe(s, "me", 9, "SPELL_CAST_SUCCESS", "me", 101, "Test potion", 0)
U.Observe(s, "me", 11, "SPELL_CAST_SUCCESS", "stranger", 101, "Test potion", 0)
U.Observe(s, "me", 11, "SPELL_AURA_APPLIED", "me", 101, "Test potion", 0)
U.Observe(s, "me", 11, "SPELL_CAST_SUCCESS", "me", 202, "Short ability", 599999)
assert(next(s.usage.player) == nil and next(s.usage.opponent) == nil)
U.Observe(s, "me", 12, "SPELL_CAST_SUCCESS", "me", 101, "Test potion", 0)
U.Observe(s, "me", 13, "SPELL_CAST_SUCCESS", "me", 101, "Test potion", 0)
U.Observe(s, "me", 14, "SPELL_CAST_SUCCESS", "rival", 203, "Long ability", 600000)
assert(s.usage.player["101"].count == 2 and s.usage.player["101"].kind == "item")
assert(s.usage.opponent["203"].cooldown == 600)
s.finishedAt = 15
U.Observe(s, "me", 16, "SPELL_CAST_SUCCESS", "me", 101, "Test potion", 0)
assert(s.usage.player["101"].count == 2)
assert(table.concat(U.Tooltip({session = s}), " "):find("Test potion x2", 1, true))
assert(table.concat(U.Tooltip({}), " "):find("N/A", 1, true))
U.items = {}
print("PASS: item/10-minute cooldown capture, actor/start/end guards, threshold and historical tooltip")
