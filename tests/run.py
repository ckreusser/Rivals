"""Run outside WoW with Python + lupa (Lua 5.1); never loaded by the addon."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('DP = {}; function loadAddon(source) assert(loadstring(source))("Rivals", DP) end')
for name in ("Parser.lua", "Tracker.lua", "Usage.lua", "Rating.lua", "Verification.lua", "Recovery.lua", "Periods.lua", "Theme.lua", "Views.lua", "CharacterTab.lua", "Inspect.lua", "Tooltip.lua"):
    lua.globals().loadAddon((root / name).read_text(encoding="utf-8"))
lua.execute((root / "tests" / "spec.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "usage.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "rating.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "verification.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "recovery.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "wow_mock.lua").read_text(encoding="utf-8"))
lua.globals().loadAddon((root / "Core.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "integration.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "character_tab.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "inspect.lua").read_text(encoding="utf-8"))
print("PASS: Lua 5.1 parser, tracker, and mocked client integration checks")
