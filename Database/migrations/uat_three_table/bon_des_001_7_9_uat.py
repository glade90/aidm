"""BON independent DES-001.7.9 owner-executed harness.
Read-only SQL source checks; synthetic fixtures never persisted. No source mutations.
Run from exact DAVOS worktree via python -c runpy.run_path(...,run_name='__main__').
"""
from __future__ import annotations
import json, os, subprocess, sys
from dataclasses import replace
from hashlib import sha256
from datetime import date
from aidm.catalogue import (MonsterCatalogue, MonsterTestScenarios, SqlServerReader,
    CatalogueError, CatalogueUnavailable, NotPlayable, build_test_handoff,
    public_monster_asset, _MONSTER_COLS, _SCENARIO_COLS, _CASE_COLS)
from aidm.catalogue_combat import prepare_prototype_encounter
from aidm.config import load_config
from aidm.combat.fixtures import canonical_three_vs_three
from aidm.combat.session import CombatSessionService
from aidm.combat.dice import FixedRollSource
from aidm.combat.test.test_combat_session import FakeLogger, WIN_FACES, start, act, reset, log
from aidm.test.test_catalogue import FakeQuery, monster_row, scenario_row, case_row
from aidm.web.app import create_chat_app
from aidm.b1_fixtures import read_candidates
from fastapi.testclient import TestClient
SHA="08928fc4edd040495e1f50c79ebac02b5da01b96"
CODES=("ORC","GIANT_CENTIPEDE","CARRION_CRAWLER","GIANT_CRAB_SPIDER")
R="MentzerBECMI"; D="2026-11-21"
class Blocked(Exception): pass
def require(ok, why):
    if not ok: raise AssertionError(why)
def refused(fn, why):
    try: fn()
    except CatalogueError: return
    raise AssertionError(why)
def git(*args):
    return subprocess.check_output(["git",*args],text=True).strip()
def digest(x):
    return sha256(str(x).encode("utf-8")).hexdigest()[:16]
def raw_query(factory, sql, params=()):
    c=cur=None
    try:
        c=factory(); c.timeout=10; cur=c.cursor(); cur.execute(sql,*params)
        names=[x[0] for x in cur.description]
        rows=cur.fetchmany(101)
        require(len(rows)<=100,"Raw read exceeded bound")
        return [dict(zip(names,row)) for row in rows]
    except AssertionError: raise
    except Exception: raise Blocked("Raw read unavailable; inspect SQL/ODBC privately") from None
    finally:
        if cur is not None: cur.close()
        if c is not None: c.close()
def raw_table(factory, cols, table, where, params):
    return raw_query(factory,"SELECT "+",".join("["+c+"]" for c in cols)+" FROM "+table+" WHERE "+where,params)
def sql_factory():
    try:
        config=load_config(required_secrets=("AIDM_SQL_ODBC_CONNECTION",))
        secret=config.get_secret("AIDM_SQL_ODBC_CONNECTION")
        if config.mode!="development" or not secret: raise Blocked("Explicit development SELECT-only ODBC config required")
        import pyodbc
    except Blocked: raise
    except Exception: raise Blocked("Local pyodbc/config unavailable") from None
    f=lambda:pyodbc.connect(secret,timeout=5,autocommit=False)
    db=raw_query(f,"SELECT DB_NAME() AS db, IS_SRVROLEMEMBER('sysadmin') AS sa, IS_MEMBER('db_owner') AS owner")[0]
    require(db["db"]=="DnD","Wrong database")
    if db["sa"]!=0 or db["owner"]!=0:
        raise Blocked("Principal not verified SELECT-only; sysadmin/db_owner or unknown role")
    for table in ("Rules.Monster","Test.MonsterTestScenario","Test.MonsterTestCase"):
        for perm in ("INSERT","UPDATE","DELETE","ALTER","CONTROL"):
            p=raw_query(f,"SELECT HAS_PERMS_BY_NAME(?, 'OBJECT', ?) AS permitted",(table,perm))[0]["permitted"]
            if p!=0: raise Blocked("Write/DDL permission present or unknown: "+table+" "+perm)
    print("DnD SELECT-only source-table effective permission checks OK")
    return f
def sql01(f):
    fields=dict(zip(_MONSTER_COLS,("record_date","ruleset_code","monster_code","active","monster_name","parent_code","source_status","source_reference","house_rule_overlay_refs","armor_class","hit_dice_text","attack_pattern","damage_pattern","save_as","morale","movement_turn_feet","movement_round_feet","movement_special_text","alignment","xp_value","number_appearing_text","treasure_type","general_description","special_attacks_features","special_encounter_features","d1_feet","d2_feet","z_feet","size_basis","illustration_path","map_icon_path","notes_markdown"),strict=True))
    provider=MonsterCatalogue(SqlServerReader(f))
    for code in CODES:
        rows=raw_table(f,_MONSTER_COLS,"[Rules].[Monster]","[RulesetCode]=? AND [MonsterCode]=? AND [RecordDate]=?",(R,code,D))
        require(len(rows)==1,code+" wrong raw row count")
        raw=rows[0]; s=provider.resolve(R,code,record_date=D,source_checked_test_only=True)
        for col,attr in fields.items():
            expected=raw[col]
            if col=="RecordDate": expected=str(expected)
            require(getattr(s,attr)==expected,code+" mismatch "+col)
        require(s.identity==(R,code,D) and not s.active and s.source_status=="SourceChecked",code+" approval/date mismatch")
        print(code,s.identity,"AC",s.armor_class,"HD",s.hit_dice_text,"attacks",s.attack_pattern,"damage",s.damage_pattern,"D1/D2/Z",(s.d1_feet,s.d2_feet,s.z_feet))
        print("  Source:",s.source_reference,"Image:",s.illustration_path)
        print("  Exact field matches",len(fields),"separate prose digests:",*[digest(x) for x in (s.general_description,s.special_attacks_features,s.special_encounter_features)])
def sql02(f):
    cat=MonsterCatalogue(SqlServerReader(f))
    for code in CODES:
        refused(lambda:cat.resolve(R,code,record_date=D),"Draft accepted as approved "+code)
        refused(lambda:cat.resolve(R,code),"Normal approved-only unexpectedly resolves "+code)
        refused(lambda:cat.resolve(R,code,record_date="1999-01-01",source_checked_test_only=True),"Wrong date substituted")
        require(public_monster_asset(cat.resolve(R,code,record_date=D,source_checked_test_only=True),revealed=True)=={},"Draft art leaked")
    q=FakeQuery(monsters=[monster_row(),monster_row(record="2026-11-22")]); c=MonsterCatalogue(q)
    refused(lambda:c.resolve(R,"ORC"),"Duplicate active version accepted")
    refused(lambda:c.resolve("Unknown","ORC"),"Unknown ruleset accepted")
    refused(lambda:c.resolve(R,"ORC;DROP"),"Unsafe ID accepted")
    require(c.resolve(R,"ORC",record_date=D).identity==(R,"ORC",D),"Explicit version not pinned")
    print("4 drafts refused in normal mode; exact missing/duplicate/unsafe gates verified")
def sql03(f):
    repo=MonsterTestScenarios(SqlServerReader(f))
    parent=raw_table(f,_SCENARIO_COLS,"[Test].[MonsterTestScenario]","[ScenarioCode]=?",("ORC-T001-A",))
    children=raw_table(f,_CASE_COLS,"[Test].[MonsterTestCase]","[ScenarioCode]=?",("ORC-T001-A",))
    require(len(parent)==1 and len(children)==5,"Expected one parent and five cases")
    p=parent[0]; s=repo.resolve("ORC-T001-A",include_unready_test_only=True)
    require(s.status==p["ScenarioStatus"]=="Specified" and not s.ready_for_execution and not s.ready,"Scenario became ready")
    require(s.revision==p["FixtureRevision"] and s.origin_reference==p["OriginReference"] and s.monster_count==p["MonsterCount"],"Parent mapping differs")
    for attr,col in (("party_roster_json","PartyRosterJson"),("monster_roster_json","MonsterRosterJson"),("scene_facts_json","SceneFactsJson")):
        require(json.loads(getattr(s,attr))==json.loads(p[col]),"Parent JSON mismatch "+col)
    for a,b in zip(s.cases,sorted(children,key=lambda x:x["SequenceNo"]),strict=True):
        require((a.case_code,a.sequence,a.name,a.phase,a.status,a.revision,a.given,a.expected,a.linked_story,a.automated_test_ref)==tuple(b[x] for x in ("TestCaseCode","SequenceNo","TestName","TestPhase","TestStatus","TestRevision","GivenText","ExpectedText","LinkedStoryRef","AutomatedTestRef")),"Case field mismatch")
        require(not a.executable,"Unready child executable")
        if b["DiceFixtureJson"] is not None: require(json.loads(a.dice_json)==json.loads(b["DiceFixtureJson"]),"Dice fixture mismatch")
        print(a.sequence,a.case_code,a.status,a.phase)
    refused(lambda:repo.resolve("ORC-T001-A"),"Normal unready scenario accepted")
    def never_query(*args): raise AssertionError("Unready scenario queried catalogue")
    refused(lambda:build_test_handoff(s,MonsterCatalogue(never_query),mechanics_verified_ref="bon.synthetic"),"Unready handoff accepted")
    print("Specified/0, five normalized children verified; normal resolution and handoff refused")
class DisconnectQuery(FakeQuery):
    disconnected=False
    def __call__(self,sql,params):
        if self.disconnected: raise AssertionError("Provider accessed after disconnect")
        return super().__call__(sql,params)
def synthetic_pair():
    # Entirely fabricated approved data; never loaded from or written to PEQUOD.
    raw=monster_row(status="Approved",active=1,record=D,SourceReference="BON synthetic fixture only",SpecialAttacksFeatures="",SpecialEncounterFeatures="BON_SECRET_PARLAY")
    rows=[]; cases=[]
    for key,hps in (("BON-A",(7,5,2)),("BON-B",(2,7,5))):
        party=[{"actor_id":i,"hp_start":h} for i,h in (("alho",8),("evro",8),("sho-rembo",9))]
        actors=[{"actor_id":f"orc-{i:02d}","species":"ORC","role":"ordinary","hp_start":hp,"weapon":"shortsword","species_record_date":D} for i,hp in enumerate(hps,1)]
        rows.append(scenario_row(code=key,status="Ready",ready=1,MonsterCount=3,PartyRosterJson=json.dumps(party),MonsterRosterJson=json.dumps(actors),SceneFactsJson=json.dumps({"approved_for_test_bootstrap":True,"surprise":"author-approved-none"})))
        cases.append(case_row(code=key,status="Ready",GivenText="BON synthetic stationary melee",ExpectedText="Pinned source and individual HP"))
    q=DisconnectQuery(monsters=[raw],scenarios=rows,cases=cases); repo=MonsterTestScenarios(q); cat=MonsterCatalogue(q)
    template=canonical_three_vs_three().encounter
    capability=lambda p:p.identity==(R,"ORC",D) and p.armor_class==6 and p.hit_dice_text=="1" and p.attack_pattern=="1" and p.damage_pattern=="1d6" and p.save_as=="F1" and not p.special_attacks_features
    hands=[build_test_handoff(repo.resolve(key),cat,mechanics_verified_ref="bon.synthetic.melee") for key in ("BON-A","BON-B")]
    encounters=[prepare_prototype_encounter(h,authored_template=template,mechanics_supported=capability) for h in hands]
    return q,hands,encounters,template,capability
def app_for(service):
    return create_chat_app(settings=load_config(environ={"AIDM_MODE":"test"},dotenv_path="/nonexistent/bon.env"),logger=FakeLogger(),combat_session_handler=service)
def offline04():
    q,hands,encounters,_,_=synthetic_pair(); before=len(q.calls); q.disconnected=True
    for h,e,hps in zip(hands,encounters,((7,5,2),(2,7,5)),strict=True):
        require(tuple(a.starting_hp for a in h.actors)==hps,"Roster HP mismatch")
        require({a.source_version for a in h.actors}=={(R,"ORC",D)},"Version pin mismatch")
        require("BON_SECRET_PARLAY" not in repr(h.sources) and "BON_SECRET_PARLAY" not in repr(e),"Encounter-only guidance leaked into combat")
        service=CombatSessionService(prototype_encounter=e,roll_source_factory=lambda:FixedRollSource(WIN_FACES))
        with TestClient(app_for(service)) as client:
            reply=start(client); view=reply["combat"]; engine=service._sessions["s1"].engine
            require(reply["status"]=="NEEDS_PLAYER_INPUT" and view["fixture_status"]=="TEST_ONLY","START failed")
            def hp(): return tuple(service._sessions["s1"].engine.snapshot()["hp"][f"orc-{n:02d}"] for n in range(1,4))
            require(hp()==hps,"START HP wrong")
            version=engine.snapshot()["version"]
            result=act(client,view,"HOLD",action_id="bon-independent")
            require(result["status"] in ("NEEDS_PLAYER_INPUT","COMPLETED") and engine.snapshot()["version"]>version,"ACTION failed")
            restored=reset(client,result["combat"])
            require(restored["combat"]["encounter_id"]!=view["encounter_id"] and hp()==hps,"RESET wrong")
            print(h.scenario_code,"pin",h.actors[0].source_version,"START HP",hps,"ACTION",result["status"],"RESET HP",hp(),"TEST_ONLY")
    require(len(q.calls)==before,"Additional provider calls")
    print("No provider calls after deliberate disconnect")
def negative05():
    q,hands,_,template,cap=synthetic_pair(); h=hands[0]
    variants=[("special",replace(h,sources=(replace(h.sources[0],special_attacks_features="synthetic poison"),)),cap),
              ("leader",replace(h,actors=(replace(h.actors[0],role="leader"),*h.actors[1:])),cap),
              ("missing-core",replace(h,sources=(replace(h.sources[0],damage_pattern=""),)),cap),
              ("wrong-version",replace(h,actors=(replace(h.actors[0],source_version=(R,"ORC","1999-01-01")),*h.actors[1:])),cap),
              ("missing-HP",replace(h,actors=(replace(h.actors[0],starting_hp=0),*h.actors[1:])),cap),
              ("unapproved-scene",replace(h,scene_facts_json='{"approved_for_test_bootstrap":false}'),cap),
              ("unsupported-mechanics",h,lambda p:False)]
    for label,hand,check in variants:
        refused(lambda:prepare_prototype_encounter(hand,authored_template=template,mechanics_supported=check),"Unsafe handoff accepted: "+label)
        print(label,"REFUSED")
def integration06():
    # Safe fake cursor only. SQL strings never reach actual SQL Server.
    class Fake:
        def __init__(self,fail=False): self.fail=fail; self.calls=[]; self.closed=0; self.description=[("x",)]
        def cursor(self): require(self.timeout==10,"Timeout not set"); return self
        def execute(self,sql,*params):
            self.calls.append((sql,params))
            if self.fail: raise RuntimeError("BON_PRIVATE_SENTINEL")
        def fetchmany(self,n): return [(1,)]
        def close(self): self.closed+=1
    f=Fake(True)
    try: SqlServerReader(lambda:f)("SELECT [x] FROM [Synthetic] WHERE [x]=?",(1,))
    except CatalogueUnavailable as e: require("BON_PRIVATE_SENTINEL" not in str(e) and f.closed==2,"Error leak or cleanup failure")
    else: raise AssertionError("Driver failure not reported")
    m=MonsterCatalogue(FakeQuery(monsters=[monster_row(SourceReference="BON_PRIVATE_SENTINEL",IllustrationPath="assets/../secret.png")])).resolve(R,"ORC")
    require(public_monster_asset(m,revealed=False)=={},"Hidden species leaked")
    require(public_monster_asset(m,revealed=True)=={"name":m.monster_name,"illustration_path":"","map_icon_path":m.map_icon_path},"Unsafe asset or extra fields")
    service=CombatSessionService(roll_source_factory=lambda:FixedRollSource(WIN_FACES))
    with TestClient(app_for(service)) as client:
        for item in read_candidates():
            res=client.post("/api/turn",json={"session_id":"b1-bon","correlation_id":"bon-"+item.fixture_id,"combat":{"kind":"START","fixture_id":item.fixture_id}})
            require(res.status_code==200 and res.json()["status"]=="BLOCKED" and "b1-bon" not in service._sessions,"B1 fixture enabled")
            print(item.fixture_id,"BLOCKED")
        reply=start(client); view=reply["combat"]
        require(reply["status"]=="NEEDS_PLAYER_INPUT" and view["fixture_status"]=="TEST_ONLY","Original START failed")
        result=act(client,view,"HOLD",action_id="bon-canonical")
        require(result["status"] in ("NEEDS_PLAYER_INPUT","COMPLETED"),"Original ACTION failed")
        require(reset(client,result["combat"])["status"]=="NEEDS_PLAYER_INPUT","Original RESET failed")
        require("BON_PRIVATE_SENTINEL" not in json.dumps(reply),"Private sentinel leaked")
        print("Original synthetic Meta START/ACTION/RESET and five B1 gates passed")
    failed=[]
    for unsafe in ("SELECT 1; DELETE FROM [SyntheticExample]","SELECT 1 INTO [SyntheticExample]"):
        f=Fake()
        try: SqlServerReader(lambda:f)(unsafe,())
        except CatalogueError: pass
        if f.calls: failed.append("write-capable syntax forwarded")
    require(not failed,"Read-only guard defect DES-001.7.9.1 reproduced using fake cursor only")
def main():
    require(git("rev-parse","HEAD")==SHA and not git("status","--porcelain"),"Wrong or dirty source")
    print("SOURCE",SHA,"CLEAN")
    factory=None; sql_block=None
    try: factory=sql_factory()
    except Blocked as e: sql_block=str(e)
    except AssertionError as e: sql_block=str(e)
    results={}
    for ident,fn in (("01",sql01),("02",sql02),("03",sql03),("04",offline04),("05",negative05),("06",integration06)):
        try:
            if ident in ("01","02","03"):
                if factory is None: raise Blocked(sql_block)
                fn(factory)
            else: fn()
            status="Pass"; msg="Independent assertions satisfied"
        except (Blocked,CatalogueUnavailable) as e: status="Blocked"; msg=str(e)
        except AssertionError as e: status="Fail"; msg=str(e) or "Assertion failed"
        except Exception as e: status="Blocked"; msg="Unexpected runtime/setup exception: "+type(e).__name__
        results[ident]={"result":status,"observed":msg}
        print("BON-UAT-"+ident,status,msg)
    print("BON_RECEIPT",json.dumps({"source_sha":SHA,"results":results},sort_keys=True))
    return 0 if all(r["result"]=="Pass" for r in results.values()) else 1
if __name__=="__main__": sys.exit(main())
