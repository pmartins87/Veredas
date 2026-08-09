#!/usr/bin/env python3
from pathlib import Path
import json,re,unicodedata,sys
ROOT=Path(__file__).resolve().parents[1]; DATA=ROOT/'data'
EXPECTED={'worlds':12,'locations':120,'families':96,'monsters':300,'bosses':60,'items':1116,'npcs':300,'marks':204,'debts':120,'characters':36,'abilities':72,'events':2544,'finals':36,'pools':144}

def load(n): return json.loads((DATA/f'{n}.json').read_text(encoding='utf-8'))
def norm(s):
 s=unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().lower(); s=re.sub(r'\d+','N',s); return re.sub(r'\s+',' ',s).strip()
def effect_rows(value):
 if isinstance(value,list): return [e for e in value if isinstance(e,dict)]
 if isinstance(value,dict): return [value]
 return []
rows={}; ids={}; errors=[]
for k,count in EXPECTED.items():
 a=load(k); rows[k]=a
 if len(a)!=count: errors.append(f'{k}: expected {count}, got {len(a)}')
 for r in a:
  rid=r.get('id','')
  if not re.fullmatch(r'[a-z0-9_.]+',rid): errors.append(f'invalid id {rid}')
  if rid in ids: errors.append(f'duplicate id {rid}')
  ids[rid]=k

def ref(r,key,prefix=''):
 v=r.get(key)
 if v and v not in ids: errors.append(f"{r.get('id')}: missing {key}={v}")
 if v and prefix and not str(v).startswith(prefix): errors.append(f"{r.get('id')}: bad ref {key}={v}")
for r in rows['locations']: ref(r,'world_id','world.')
for r in rows['families']: ref(r,'world_id','world.')
for r in rows['monsters']: ref(r,'world_id','world.'); ref(r,'location_id','location.'); ref(r,'family_id','family.')
for r in rows['bosses']:
 ref(r,'world_id','world.'); ref(r,'location_id','location.')
 if len(r.get('phases',[]))<3: errors.append(f"{r['id']}: boss needs three phases")
for k in ['items','marks','characters','finals','pools']:
 for r in rows[k]: ref(r,'world_id','world.')
for r in rows['npcs']: ref(r,'world_id','world.'); ref(r,'location_id','location.')
for r in rows['debts']: ref(r,'world_id','world.'); ref(r,'origin_location_id','location.')
for r in rows['characters']:
 for a in r.get('abilities',[]):
  if a not in ids: errors.append(f"{r['id']}: missing ability {a}")
for r in rows['events']:
 ref(r,'world_id','world.')
 if r.get('location_id'): ref(r,'location_id','location.')
 if r.get('character_id'): ref(r,'character_id','character.')
 if r.get('debt_id'): ref(r,'debt_id','debt.')
 for mark_key in ['memory_mark_id','callback_mark_id']:
  if r.get(mark_key): ref(r,mark_key,'mark.')
 for c in r.get('choices',[]):
  for e in effect_rows(c.get('effect',{})):
   for key in ['mark_id','debt_id']:
    if e.get(key) and e[key] not in ids: errors.append(f"{r['id']}: broken effect ref {e[key]}")
unique_text=len({norm(e.get('text','')) for e in rows['events']})/len(rows['events'])
choice_sigs=len({tuple(norm(c.get('text','')) for c in e.get('choices',[])) for e in rows['events']})
if unique_text<.80: errors.append(f'event uniqueness too low {unique_text:.3f}')
if choice_sigs<400: errors.append(f'choice diversity too low {choice_sigs}')
if len({m.get('ecology','') for m in rows['monsters']})<250: errors.append('monster ecology diversity too low')
if len({m.get('counterplay','') for m in rows['monsters']})<250: errors.append('monster counterplay diversity too low')
if len({n.get('objective','') for n in rows['npcs']})<200: errors.append('npc objective diversity too low')
if len({n.get('pressure','') for n in rows['npcs']})<250: errors.append('npc pressure diversity too low')
if len({n.get('voice','') for n in rows['npcs']})<150: errors.append('npc voice diversity too low')
if any(re.search(r'\b(?:weapon|item|component)\s*\d+\b',i.get('name',''),re.I) for i in rows['items']): errors.append('item placeholder name detected')
if len({c.get('passive','') for c in rows['characters']})<36: errors.append('passives not unique')
if len({c.get('weakness','') for c in rows['characters']})<36: errors.append('weaknesses not unique')
if len({a.get('signature','') for a in rows['abilities']})<70: errors.append('ability mechanical diversity too low')
print('CANONICAL QA')
for k in EXPECTED: print(f'{k:12s} {len(rows[k])}')
print('records      ',sum(len(v) for v in rows.values()))
print('event_unique ',f'{unique_text:.3%}')
print('choice_sigs  ',choice_sigs)
print('errors       ',len(errors))
for e in errors[:50]: print('ERROR:',e)
sys.exit(1 if errors else 0)