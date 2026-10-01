from pathlib import Path

root = Path(__file__).resolve().parents[1]
mk = (root / 'MultiKill.lua').read_text()
wpvp = (root / 'WorldPvP.lua').read_text()
views = (root / 'Views.lua').read_text()
toc = (root / 'Rivals.toc').read_text()

expected = [
    ('DoubleKill', 2), ('TripleKill', 3), ('Overkill', 4), ('Killtacular', 5),
    ('Killtrocity', 6), ('Killamanjaro', 7), ('Killtastrophe', 8),
    ('Killpocalypse', 9), ('Killionaire', 10),
]

assert 'local WINDOW_SECONDS = 8' in mk
assert 'local MAX_VISIBLE_MEDALS = 4' in mk
assert 'local MEDAL_SIZE = 40' in mk
assert 'function M.OnKillingBlow()' in mk
assert 'function M.DevKillingBlow()' not in mk
assert 'DP.MultiKill.OnKillingBlow()' in wpvp
assert 'DP.MultiKill.Reset()' in wpvp
assert 'DEV KB' not in views and 'DevKillingBlow' not in views
assert 'KillstreaksEnabled' in views and 'SetKillstreaksEnabled' in views
assert 'if DP.KillstreaksEnabled and not DP.KillstreaksEnabled() then return 0 end' in mk
assert 'MultiKill.lua' in toc and toc.index('MultiKill.lua') < toc.index('WorldPvP.lua')
assert '## Version: 1.0.139' in toc

for asset, count in expected:
    assert f'[{count}]' in mk and asset in mk
    assert (root / 'Textures' / 'MultiKill' / f'{asset}.tga').exists()
    assert (root / 'Sounds' / 'MultiKill' / f'{asset}.wav').exists()

# Reach-style feed contracts.
assert 'frame:SetPoint("LEFT", UIParent, "LEFT", 56, 0)' in mk
assert 'frame.medalSlots = {}' in mk
assert 'frame.label:SetJustifyH("LEFT")' in mk
assert 'frame.labelShadow:SetJustifyH("LEFT")' in mk
assert 'table.insert(active, 1, {medal = medal, startedAt = now})' in mk
assert 'table.remove(active, #active)' in mk
assert 'active[i].shiftStartedAt = now' in mk
assert 'SetSlotPosition(slot, i, offsetX)' in mk
assert 'local MEDAL_SHIFT_SECONDS = 0.12' in mk
assert 'local MEDAL_SPAWN_DELAY = 0.035' in mk
assert 'local MEDAL_POP_SECONDS = 0.16' in mk
assert 'SetTextureRotation' not in mk
assert 'slot.flash' not in mk
assert 'SetBlendMode("ADD")' not in mk
assert 'labelAnchor:SetScale' not in mk
assert 'CircleMask' not in mk
assert 'sweepSoftClip' not in mk
assert 'sweepCoreClip' not in mk

print('PASS: multi-kill assets, KB hook, newest-left Reach feed, stable rightward queue, clean snap/pop, left HUD placement, caption, fade, and the Manage killstreak toggle are wired')
