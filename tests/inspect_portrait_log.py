"""Read persisted portrait evidence; never modify WoW SavedVariables."""
import sys
from datetime import datetime
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
if len(sys.argv) > 1:
    path = Path(sys.argv[1])
else:
    files = list((ROOT.parents[2] / 'WTF' / 'Account').glob('*/SavedVariables/Rivals.lua'))
    if not files:
        raise SystemExit('No Rivals SavedVariables files found.')
    path = max(files, key=lambda p: p.stat().st_mtime)
print(f'Read-only source: {path}')
print(f'Written: {datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds")}')
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('os=nil;io=nil;package=nil;require=nil;dofile=nil;loadfile=nil;debug=nil')
lua.execute(path.read_text(encoding='utf-8-sig'))
db = lua.globals().RivalsDB
if db is None:
    raise SystemExit('No RivalsDB found.')
traces = list((db.portraitLoadTraceArchive or lua.table()).values())
if db.portraitLoadTrace:
    traces.append(db.portraitLoadTrace)
for trace in traces:
    print(f'\nVersion {trace.version}; session {trace.wallTime}; build {trace.build}')
    events = trace.events
    if events is None:
        continue
    start = trace.startedAt or (events[1].t if len(events) else 0)
    report_events = list(events.values())[-30:]
    failures = list((trace.failures or lua.table()).values())
    if failures:
        print('Retained failure evidence follows the recent events (may repeat).')
    for event in report_events + failures:
        print(f'+{(event.t or 0)-start:07.2f}s {event.event}: {event.key or ""} '
              f'body={event.body} source={event.source} display={event.displayID} {event.reason or ""}')
        detail = event.details
        if detail is None:
            continue
        print(f'  loaded={detail.loaded} geo={detail.geometryReady} file={detail.modelFileID} '
              f'TryOn={detail.tryOn} SetItem={detail.setItemInfo} '
              f'GetAppearance={detail.getAppearance} GetItem={detail.getItemInfo}')
        if detail.binding:
            for method, result in detail.binding.items():
                print(f'  bind {method}: {dict(result.items())}')
        if detail.gear:
            for slot in detail.gear.values():
                print(f'  gear: {dict(slot.items())}')
if not traces:
    print('No saved portrait trace; a reload/logout is needed to flush game state.')
