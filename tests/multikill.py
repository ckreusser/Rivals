from pathlib import Path

root = Path(__file__).resolve().parents[1]
mk = (root / 'MultiKill.lua').read_text(encoding='utf-8-sig')
wpvp = (root / 'WorldPvP.lua').read_text(encoding='utf-8-sig')
views = (root / 'Views.lua').read_text(encoding='utf-8-sig')
toc = (root / 'Rivals.toc').read_text(encoding='utf-8-sig')

expected = [
    ('DoubleKill', 2), ('TripleKill', 3), ('Overkill', 4), ('Killtacular', 5),
    ('Killtrocity', 6), ('Killamanjaro', 7), ('Killtastrophe', 8),
    ('Killpocalypse', 9), ('Killionaire', 10),
]

assert 'local WINDOW_SECONDS = 12' in mk

core = (root / 'Core.lua').read_text(encoding='utf-8-sig')
assert 'elseif command == "kb" then' in core
kb_block = core.split('elseif command == "kb" then', 1)[1].split('elseif command == "season start" then', 1)[0]
assert 'DP.MultiKill.OnKillingBlow()' in kb_block
assert 'Say(' not in kb_block
assert 'WorldPvP' not in kb_block
assert 'local MAX_VISIBLE_MEDALS = 4' in mk
assert 'local MEDAL_SIZE = 40' in mk
assert 'function M.OnKillingBlow(level, playerLevel, persist)' in mk
assert 'function M.DevKillingBlow()' not in mk
assert 'DP.MultiKill.OnKillingBlow(enemy.level, session.playerLevel, true)' in wpvp
assert 'DP.MultiKill.Reset()' in wpvp
assert 'DEV KB' not in views and 'DevKillingBlow' not in views
assert 'KillstreaksEnabled' in views and 'SetKillstreaksEnabled' in views
assert 'if DP.KillstreaksEnabled and not DP.KillstreaksEnabled() then return 0 end' in mk
assert 'MultiKill.lua' in toc and toc.index('MultiKill.lua') < toc.index('WorldPvP.lua')
assert '## Version: 1.0.144' in toc

for asset, count in expected:
    assert f'[{count}]' in mk and asset in mk
    assert (root / 'Textures' / 'MultiKill' / f'{asset}.tga').exists()
    assert (root / 'Sounds' / 'MultiKill' / f'{asset}.wav').exists()

# Reach-style feed contracts.
assert 'frame:SetPoint("LEFT", UIParent, "LEFT", x, y)' in mk
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

# Movable killstreak HUD editor contracts.
assert 'function M.BeginPositioning()' in mk
assert 'function M.EndPositioning()' in mk
assert 'function M.TogglePositioning()' in mk
assert 'function M.ApplySavedPosition()' in mk
assert 'Drag to move  •  Right-click to finish' in mk
assert 'DP.SetKillstreakPosition' in mk
assert 'DP.MultiKill.TogglePositioning' in views
assert 'local killstreakPosition = Button(manage, "Move"' in views

print('PASS: multi-kill assets, KB hook, newest-left Reach feed, stable rightward queue, clean snap/pop, movable HUD placement, caption, fade, Manage toggle, and the killstreak position editor are wired')
