#!/usr/bin/env python3
"""Check actual client module/process events in a private verbose Flutter log."""
import argparse
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('log', type=Path)
args = parser.parse_args()
if args.log.stat().st_size > 32 * 1024 * 1024:
    raise SystemExit('Private acceptance log exceeded its bound')
events=[]
for line in args.log.read_text(errors='replace').splitlines():
    start=line.find('{')
    if start < 0: continue
    try: event,_=json.JSONDecoder().raw_decode(line[start:])
    except json.JSONDecodeError: continue
    if isinstance(event,dict) and event.get('service.name')=='nddev-device-sync-client':
        events.append(event)
        if len(events)>1024: raise SystemExit('Unexpected client event volume')
modules=[event for event in events if event.get('event.name')=='module.query.completed']
processes=[event for event in events if event.get('event.name') in ['native.process.completed','native.process.failed']]
if not {'sysinfo','clipboard','cleaner','updater','gds'} <= {event.get('module') for event in modules} or not processes:
    raise SystemExit('Actual module/process telemetry was not captured')
for event in [*modules,*processes]:
    if not re.fullmatch('[a-f0-9]{32}',event.get('trace_id','')) or not re.fullmatch('[a-f0-9]{16}',event.get('span_id','')):
        raise SystemExit('Actual native event is missing trace context')
    if int(event['trace_id'],16)==0 or int(event['span_id'],16)==0:
        raise SystemExit('Actual native event has an invalid zero context')
    if event.get('outcome') not in ['ok','error']:
        raise SystemExit('Actual native event has a noncanonical outcome')
    if any(key in event for key in ['stdout','stderr','output','path','argv','command','cwd']):
        raise SystemExit('Raw process fields reached client telemetry')
for process in processes:
    if not any(process['trace_id']==module['trace_id'] and process.get('module')==module.get('module') for module in modules):
        raise SystemExit('Native process event does not belong to its actual module call')
for event in events:
    if event.get('event.name','').startswith('logging.') and 'rejected' in event.get('event.name',''):
        raise SystemExit('An actual owned event/field was rejected')
    if any(isinstance(value,str) and (value.startswith(('/home/','/tmp/')) or 'NDS isolated archive:' in value) for value in event.values()):
        raise SystemExit('Private path/content reached client telemetry')
print(f'Validated {len(modules)} actual module and {len(processes)} process events; values not printed')
