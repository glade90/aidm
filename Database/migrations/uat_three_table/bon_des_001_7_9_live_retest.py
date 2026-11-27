"""BON independent live retest 01-03, under actual Windows reader only.
Run with isolated Python -I from admin-protected ProgramData runtime.
No source mutations. The original independent assertions are retained.
"""
from __future__ import annotations
import json, sys, importlib.util
from pathlib import Path
from hashlib import sha256
from decimal import Decimal
import pyodbc
SHA="ffe5b67e12141edb22a2135d3df9100e7a4a09a7"
ROOT=Path(__file__).resolve().parent
CAT=ROOT/"catalogue.py"
PROBE=ROOT/"reader_probe.py"
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod
assert sha256(CAT.read_bytes()).hexdigest()=="92777ef93602a38d2804b6b220fefc2c497b9ba983e8d3de88c8393656a85fa2", "Catalogue copy hash mismatch"
assert sha256(PROBE.read_bytes()).hexdigest()=="6fabab57f727dd39bee61c5e9444a719438163edc1060ac5ec4ca2bacc95473f", "Probe copy hash mismatch"
cat=load("bon_catalogue",CAT)
probe=load("bon_reader_probe",PROBE)
MonsterCatalogue, MonsterTestScenarios, SqlServerReader=cat.MonsterCatalogue,cat.MonsterTestScenarios,cat.SqlServerReader
CatalogueError,CatalogueUnavailable=cat.CatalogueError,cat.CatalogueUnavailable
build_test_handoff,public_monster_asset=cat.build_test_handoff,cat.public_monster_asset
_MONSTER_COLS,_SCENARIO_COLS,_CASE_COLS=cat._MONSTER_COLS,cat._SCENARIO_COLS,cat._CASE_COLS
CODES=("ORC","GIANT_CENTIPEDE","CARRION_CRAWLER","GIANT_CRAB_SPIDER")
R="MentzerBECMI"; D="2026-11-21"
class Blocked(Exception): pass
def require(ok, why):
    if not ok: raise AssertionError(why)
def refused(fn, why):
    try: fn()
    except CatalogueError: return
    raise AssertionError(why)
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
def monster_row(*, code="ORC", status="Approved", active=1, record="2026-11-21", **overrides):
    row = {name: None for name in _MONSTER_COLS}
    row.update({
        "RecordDate": record, "RulesetCode": "MentzerBECMI", "MonsterCode": code,
        "Active": active, "SourceStatus": status, "MonsterName": "Orc",
        "SourceReference": "Mentzer 1983 DMRB p. x", "ArmorClass": 6,
        "HitDiceText": "1", "AttackPattern": "1", "DamagePattern": "1d6",
        "SaveAs": "F1", "Morale": 8, "MovementTurnFeet": Decimal("90"),
        "MovementRoundFeet": Decimal("30"), "GeneralDescription": "Humanoid.",
        "SpecialAttacksFeatures": "Daylight: -1 to Hit, not damage.",
        "SpecialEncounterFeatures": "May stand off and negotiate; no fixed hostility.",
        "D1Feet": Decimal("2.5"), "D2Feet": Decimal("1.5"),
        "ZFeet": Decimal("5.0"), "SizeBasis": "illustrative",
        "HouseRuleOverlayRefs": None,
        "IllustrationPath": "assets/monsters/orc.png",
        "MapIconPath": "assets/monsters/orc_icon.png",
    })
    row.update(overrides)
    return row


class FakeQuery:
    def __init__(self, monsters=(), scenarios=(), cases=()):
        self.monsters = list(monsters)
        self.scenarios = list(scenarios)
        self.cases = list(cases)
        self.calls = []

    def __call__(self, sql, parameters):
        self.calls.append((sql, parameters))
        if "[Rules].[Monster]" in sql:
            rows = [r for r in self.monsters
                    if r["RulesetCode"] == parameters[0] and r["MonsterCode"] == parameters[1]]
            if "[SourceStatus] = N'Approved'" in sql:
                rows = [r for r in rows if r["Active"] == 1 and r["SourceStatus"] == "Approved"]
            elif "[SourceStatus] = N'SourceChecked'" in sql:
                rows = [r for r in rows if r["Active"] == 0 and r["SourceStatus"] == "SourceChecked"]
            if len(parameters) == 3:
                rows = [r for r in rows if str(r["RecordDate"]) == parameters[2]]
            return rows
        if "[Test].[MonsterTestScenario]" in sql:
            return [r for r in self.scenarios if r["ScenarioCode"] == parameters[0]]
        if "[Test].[MonsterTestCase]" in sql:
            return [r for r in self.cases if r["ScenarioCode"] == parameters[0]]
        raise AssertionError("Unexpected SQL table")


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

def refused(fn, why):
    try: fn()
    except CatalogueUnavailable: raise
    except CatalogueError: return
    raise AssertionError(why)
def main():
    proof=probe.inspect_reader("PEQUOD\\AIDM_Reader","PEQUOD","ODBC Driver 17 for SQL Server","PEQUOD",SHA)
    if proof["status"]!="PASS":
        print("BLOCKED: "+proof["reason"]); return 3
    print("SOURCE",SHA,"CATALOGUE/PROBE HASH MATCH",proof["process_account"],"READONLY PASS")
    f=lambda: pyodbc.connect("DRIVER={ODBC Driver 17 for SQL Server};SERVER=PEQUOD;DATABASE=DnD;Trusted_Connection=yes;",timeout=5,autocommit=False)
    results={}
    for ident,fn in (("01",sql01),("02",sql02),("03",sql03)):
        try: fn(f); status="Pass"; msg="Independent assertions satisfied"
        except (Blocked,CatalogueUnavailable) as e: status="Blocked"; msg=str(e)
        except AssertionError as e: status="Fail"; msg=str(e)
        except Exception as e: status="Blocked"; msg=type(e).__name__
        results[ident]={"result":status,"observed":msg}
        print("BON-UAT-"+ident,status,msg)
    print("BON_RECEIPT",json.dumps({"source_sha":SHA,"results":results},sort_keys=True))
    return 0 if all(r["result"]=="Pass" for r in results.values()) else 1
if __name__=="__main__": sys.exit(main())
