/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Mentzer_Basic_Four_Species_Insert.sql
Repository Path : Database/tables/inserts/Monster_Mentzer_Basic_Four_Species_Insert.sql
Project         : AIDM / D&D - Quasqueton Character Collection
Purpose         : Insert reviewed base species profiles for four monster artworks:
                  Orc, Giant Centipede, Carrion Crawler, Giant Crab Spider.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Table           : Rules.Monster
Version         : 0.4.0 (REVIEW SEED; NOT ACTIVE)
Created         : 2026-11-21
Dependencies    : Database/database/dnd.sql, Database/database/Rules.sql,
                  Database/tables/Monster.sql
Source          : 1983 Mentzer Basic Dungeon Masters Rulebook pp.27, 28, 35, 37
                  and original Golden Braid DES-001.7 source review, 2026-11-21.

DESIGN NOTES
- NO B1 module encounter stats. B1 selects species only.
- NO encounter group counts/individual HP/conditions are seeded here.
- Only four base species, no chieftain/leader *instance* spawned.
- SpecialAttacksFeatures is combat-only; SpecialEncounterFeatures carries
  mechanical Encounter rules AND all nontechnical social/tactical/habitat
  guidance, including parley, stand-off, retreat, camouflage and surprise.
- Existing older inactive seeds are backfilled by the v0.4 migration first;
  this script does not overwrite historical records.
- Non-destructive and rerunnable: existing rows are NOT updated/deactivated.
  If any historical row exists for a (RulesetCode,MonsterCode), skip that key.
- Rows are SourceChecked, Active=0 until owner approves and activates them.
  Table constraint correctly prevents making unapproved rows active.
- Original image filenames were saved in OneDrive and reportedly copied to
  local assets/images/monsters; directory was NOT visible on GitHub bonnie
  during authoring. Paths must be checked after owner's push before activation.
- CRAB illustration is a DRAFT with unwanted webbing/party figures, not canon.
- D1 and D2 are FULL major/minor horizontal ellipse DIAMETERS in feet;
  Z is the approximate height. They are not Mentzer map/combat rules.
- Mentzer describes roughly 1-ft Centipede length, 9-ft Crawler length and
  3-ft height, and 5-ft Crab Spider length; unspecified widths/heights are
  clearly labeled AIDM estimates, NOT official published statistics.
- Owner default for humans/humanoids is a FIVE-FOOT-DIAMETER circular base;
  for Orc D1=D2=5 ft, not the previous ten-foot diameter.
- Existing inactive SourceChecked rows are NOT changed on rerun. If an
  earlier Monster table/seed exists, use v0.3.0 diameter migration first.
- SpecialAttacksFeatures carries *natural-language* Combat Agent guidance;
  deterministic generic services validate typed requests and commit state.
- This script does NOT run against PEQUOD; owner runs it after local review.

CHANGE LOG
2026-11-21  0.1.0  First four reviewed monster species seed records.
2026-11-21  0.2.0  Set ellipse radii R1/R2 and Z estimates for four monsters.
2026-11-21  0.3.0  Use ellipse full diameters D1/D2; humanoid circle 5ft.
2026-11-21  0.4.0  Split combat and encounter special-features guidance.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'Rules.Monster', N'U') IS NULL
    THROW 56510, 'Missing Rules.Monster. Run Database/tables/Monster.sql first.', 1;
GO

SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRAN;

    DECLARE @Seed TABLE
    (
        [MonsterCode] NVARCHAR(80) NOT NULL PRIMARY KEY,
        [MonsterName] NVARCHAR(120) NOT NULL,
        [ParentMonsterCode] NVARCHAR(80) NULL,
        [SourceReference] NVARCHAR(400) NOT NULL,
        [ArmorClass] SMALLINT NULL,
        [HitDiceText] NVARCHAR(40) NULL,
        [AttackPattern] NVARCHAR(200) NULL,
        [DamagePattern] NVARCHAR(200) NULL,
        [SaveAs] NVARCHAR(100) NULL,
        [Morale] TINYINT NULL,
        [MovementTurnFeet] DECIMAL(9,2) NULL,
        [MovementRoundFeet] DECIMAL(9,2) NULL,
        [MovementSpecialText] NVARCHAR(200) NULL,
        [Alignment] NVARCHAR(40) NULL,
        [XPValue] INT NULL,
        [NumberAppearingText] NVARCHAR(100) NULL,
        [TreasureType] NVARCHAR(100) NULL,
        [GeneralDescription] NVARCHAR(MAX) NOT NULL,
        [SpecialAttacksFeatures] NVARCHAR(MAX) NOT NULL,
        [SpecialEncounterFeatures] NVARCHAR(MAX) NOT NULL,
        [D1Feet] DECIMAL(9,2) NULL,
        [D2Feet] DECIMAL(9,2) NULL,
        [ZFeet] DECIMAL(9,2) NULL,
        [SizeBasis] NVARCHAR(200) NULL,
        [IllustrationPath] NVARCHAR(500) NULL,
        [MapIconPath] NVARCHAR(500) NULL,
        [NotesMarkdown] NVARCHAR(MAX) NULL
    );

    INSERT INTO @Seed
    ([MonsterCode], [MonsterName], [ParentMonsterCode], [SourceReference], [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern], [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet], [MovementSpecialText], [Alignment], [XPValue], [NumberAppearingText], [TreasureType], [GeneralDescription], [SpecialAttacksFeatures], [SpecialEncounterFeatures], [D1Feet], [D2Feet], [ZFeet], [SizeBasis], [IllustrationPath], [MapIconPath], [NotesMarkdown])
    VALUES
    (N'ORC',
     N'Orc',
     NULL,
     N'1983 Mentzer Basic Dungeon Masters Rulebook, Orc, printed p.35 and continuation.',
     6,
     N'1',
     N'1 attack with equipped weapon',
     N'By equipped weapon',
     N'Fighter 1',
     8,
     120,
     40,
     NULL,
     N'Chaotic',
     10,
     N'2-8 normally; 10-60 in lair',
     N'(P), D',
     N'Orcs are quarrelsome, ill-tempered humanoids with a preference for dark underground places and night activity. They commonly carry swords, spears, axes or clubs, and may be cautious around larger or stronger enemies. Narrate differences between ordinary members, a clearly identified leader and a separate tribal chieftain. Their nocturnal habits and temperament inform tactics and conversation; they do not by themselves impose extra dice penalties.',
     N'Ordinary Orcs attack once with equipped weapon using the authorised Combat roster''s hit table and damage profile. A fighting Orc, including a chieftain, has -1 to its Hit roll in daylight; this changes neither AC nor damage. The explicitly assigned ordinary group leader has 8 starting HP supplied before combat and +1 damage on successful weapon hits, not +1 Hit. Confirmed death of that leader changes the surviving group''s morale from 8 to 6 but creates NO additional unscheduled morale check: use the next normal generic check. A separate tribal chieftain has 15 starting HP supplied by Encounter, attacks on the 4-HD hit table and adds +2 weapon damage, NOT an additional ordinary leader +1. Combat Agent proposes appropriate signed modifiers by actor and event; generic deterministic tools validate and commit effects. All attack rolls, damage rolls, morale triggers and state transitions must be journalled.',
     N'Nocturnal, quarrelsome, ill-tempered omnivorous humanoids, normally dwelling underground; likely hostile but may threaten, bargain, talk, stand off, obey a stronger leader or retreat when intimidated. They are cautious around foes larger or stronger than themselves; this is a behavioural preference, not an automatic fear or Hit penalty. Typical weapons are swords, spears, axes or clubs; nonleaders are not competent with siege/mechanical weapons such as catapults. Orcs commonly form groups with an ordinary leader; a chieftain belongs to separately identified large tribal contexts. Normally 2-8 Orcs, 10-60 in a lair. Tribes may have equal male/female numbers and two young per two adults; possible Ogre support on a 1-in-6 chance per twenty tribal Orcs. Optional Expert-only troll presence (1-in-10 chance) applies ONLY if the Expert overlay is enabled, not in the current Mentzer Basic game. Orcs may serve in larger Chaotic armies. Encounter chooses group count, roles, weapons, environment, intentions, reaction, negotiation and whether combat begins, and supplies daylight to Combat. No special surprise range is stated: normal two-side surprise procedure when appropriate. Never force combat or import B1-specific encounter stats.',
     5.00,
     5.00,
     6.00,
     N'Owner AIDM humanoid default: circular D1=D2=5ft diameter; Z=6ft is estimated standing height, not a Mentzer mechanic.',
     N'assets/images/monsters/AIDM_ORC-T001_Five_Orcs_Illustration.png',
     NULL,
     N'Orc illustration shows five Orcs for ORC-T001; it is a presentation asset, not a default number appearing. This row describes the base species only; leader/chieftain are roles in encounters, not implicitly added to every battle. B1 stocked list provides selection only. Asset path is based on the owner''s local Git folder and previously saved filename; remote bonnie visibility awaits owner''s push. Source summary: AIDM-DES-001.7 Mentzer Monster Catalogue, OneNote, reviewed 2026-11-21.'),
    (N'GIANT_CENTIPEDE',
     N'Giant Centipede',
     NULL,
     N'1983 Mentzer Basic Dungeon Masters Rulebook, Giant Centipede, printed p.28.',
     9,
     N'1/2',
     N'1 bite',
     N'0 HP from bite; save versus Poison on hit',
     N'Normal Man',
     7,
     60,
     20,
     NULL,
     N'Neutral',
     6,
     N'2-8 normally; 1-8 in lair',
     N'Nil',
     N'An unusually large, approximately foot-long centipede, its low body carried on many restless legs. It prefers dark, damp dungeon spaces. Describe the creeping approach, flicker of countless legs, and venomous bite, but do not portray it as a many-foot-long carrion crawler. Its preference for darkness and moisture does not itself modify combat rolls.',
     N'One bite attack. A miss triggers neither HP damage nor saving throw. A successful bite deals zero HP damage and obliges the actual bitten actor to Save vs Poison using that victim''s saving-throw profile, not the centipede''s Save As. Success causes no additional effect; failure assigns generic NAUSEATED to the correct actor. Source effect lasts ten in-game days and permits only half-speed movement, forbidding other physical actions; the CURRENT Combat fixture checks only initial named-state assignment and no bite damage. World-time duration, movement/action restrictions, cross-encounter persistence and expiry belong to generic lifecycle Build AIDM-DES-001.7.5. No automatic death, extra HP poison damage or save on miss. Source attribution and each hit/save are journalled.',
     N'Approximately one foot long, crawling on many legs; prefers damp, dark dungeon areas. Many may gather around moist stone, debris or refuse; its appearance and movement can be described to players and may provoke caution, avoidance, inspection or parley attempts, without presuming intelligent conversation or forcing combat. Mentzer number appearing 2-8 normally, 1-8 in a lair. No unusual surprise threshold or special hiding/surprise bonus stated: standard side-based surprise when relevant. A poisonous bite is NOT an ambient exposure: do not apply NAUSEATED merely because the creature is seen or approaches. If anyone remains ill after a fight, future Expedition/Bookkeeper world-time service preserves the condition; Encounter does not prematurely expire it. No made-up stench radius or extra mechanics.',
     1.00,
     0.30,
     0.20,
     N'Mentzer approx. 1ft body length -> D1=1ft; D2=0.3ft width and Z=0.2ft height are AIDM estimates.',
     N'assets/images/monsters/AIDM_CENT-T001_Six_Giant_Centipedes_Illustration.png',
     NULL,
     N'CENT-T001 separately uses six centipedes with pre-encounter HP 4,3,4,3,1,4; do not copy those six individual HP values into the species definition. Approved second illustration from 2026-11-21. Asset path pending remote bonnie verification. Source summary: AIDM-DES-001.7 Mentzer Monster Catalogue, OneNote, reviewed 2026-11-21.'),
    (N'CARRION_CRAWLER',
     N'Carrion Crawler',
     NULL,
     N'1983 Mentzer Basic Dungeon Masters Rulebook, Carrion Crawler, printed p.27; general Paralysis rules.',
     7,
     N'3+1*',
     N'8 separate tentacle attacks per round',
     N'0 HP per tentacle; save versus Paralysis on hit',
     N'Fighter 2',
     9,
     120,
     40,
     N'Can crawl on walls and ceilings',
     N'Neutral',
     75,
     N'1-4 normally; 0 in lair',
     N'B',
     N'A revolting wormlike scavenger, approximately nine feet long and three feet high, supported by many short legs. Eight restless tentacles encircle its small mouth. It can creep across floors, walls and ceilings and scavenges deep in damp, dark dungeons. Narrate the repellent ripple of its long body, the probing tentacles, and its tendency to feed on helpless prey when it is not threatened. Sensory detail is narrative colour, not an extra mechanical penalty.',
     N'A living Carrion Crawler has eight tentacles which may each make a separately journalled Hit roll in the same round when eligible. Every tentacle hit causes zero HP damage and one Save vs Paralysis for the actual target; a miss causes neither save nor paralysis. On failed save, apply PARALYZED to the correct victim; no invented tentacle poison or bite damage. Generic PARALYZED state leaves the victim conscious but unable to move, speak, attack or cast, with attacks on paralysed victims automatically hitting and default duration 2d4 dungeon turns unless source changes it. This current Combat fixture verifies only independent hits/saves and initial PARALYZED assignment; ongoing expiry, auto-hit and cure are separately owned by AIDM-DES-001.7.6. A monster agent may prefer still-active targets during attacks; all rolls and effect commits remain deterministic and audited.',
     N'A revolting roughly nine-foot scavenger, feeding on carrion and helpless prey, crawling along floors, walls and ceilings with many short legs and eight probing mouth tentacles. Found in deep, filthy, dank dungeon areas; narrate sound, smell, investigation, discovery and fear without inventing numerical surprise/fear mechanics. Number appearing 1-4 normally; 0 in lair in the Mentzer table. No special surprise threshold documented; generic two-side procedure only. A crawler generally engages viable threats rather than wasting tentacles on already paralysed prey, and attempts to approach helpless prey to feed when no one threatens it; do not invent automatic death or bite damage. Players may decide to fight, attempt parley or a stand-off, avoid it, or flee; recognise FLEE intent and hand off unresolved escape to Encounter/Expedition, not automatic successful escape. Wall/ceiling movement, spatial approach, exits, chase and feeding outcomes are deferred to Encounter/Geometry/Expedition. CRAW-T001 tests four crawlers as an intentionally dangerous, unbalanced stress encounter; do not quietly rebalance or script a wipe.',
     9.00,
     3.00,
     3.00,
     N'Mentzer approx. 9ft length and 3ft height -> D1=9ft, Z=3ft; D2=3ft width is an AIDM estimate.',
     N'assets/images/monsters/AIDM_CRAW-T001_Four_Carrion_Crawlers_Illustration.png',
     NULL,
     N'CRAW-T001 separately tests four crawlers and the possibility of up to 32 tentacle attacks if each can legally act. Individual fixture HP 17,12,20,6 are encounter data, not catalogue stats. Approved monster-only illustration. Asset path pending remote bonnie verification. Source summary: AIDM-DES-001.7 Mentzer Monster Catalogue, OneNote, reviewed 2026-11-21.'),
    (N'GIANT_CRAB_SPIDER',
     N'Giant Crab Spider',
     NULL,
     N'1983 Mentzer Basic Dungeon Masters Rulebook, Giant Spider - Crab Spider, printed p.37; spider overview.',
     7,
     N'2*',
     N'1 bite per round',
     N'1d8 HP from bite, plus separate Poison save',
     N'Fighter 1',
     7,
     120,
     40,
     N'Clings to walls and ceilings; camouflaged ambush',
     N'Neutral',
     25,
     N'1-4 normally; 1-4 outdoors/in lair',
     N'U',
     N'A carnivorous, relatively unintelligent giant crab spider approximately five feet long. Its mottled body and limbs can blend uncannily into surrounding stone, lichen or shadow, and it can cling to sheer walls and ceilings before dropping on prey. Describe the sudden movement of its many jointed legs and venomous fangs. It does NOT make webs. It will often avoid or flee conspicuous fire, but a visible torch does not by itself create a fixed numerical penalty or an automatic morale check.',
     N'A Giant Crab Spider has one bite attack per eligible round. If it misses, there is no HP damage or poison saving throw. A successful bite deals 1d8 HP damage and separately triggers Save vs Poison for the actual victim with +2 to the victim''s save roll due to weak venom. Pass avoids the poison but not initial bite damage; fail marks the correct actor POISONED with source spider identified. In the full rule the venom can cause delayed death after 1d4 dungeon turns, but current Combat fixture checks only initial POISONED assignment, not timer, death, treatment or expiry; generic lifecycle is AIDM-DES-001.7.7. The +2 is NOT an attack or damage bonus. No extra web attack, fire fear penalty, automatic morale check, or immediate fatal poison. Deterministic tools resolve damage, saves and state changes.',
     N'Five-foot-long, relatively unintelligent carnivorous spider with mottled camouflaging colour; moves across walls and ceilings and can drop suddenly upon prey. It DOES NOT create webs. In suitable camouflage, its presence changes the opposing party''s surprise threshold from the normal 1-2 on d6 to 1-4 on d6. Its own group still uses normal vulnerability to surprise 1-2 on d6; one roll PER SIDE, not one per spider. After its initial attack the spider becomes visible and targetable normally. Often retreats from conspicuous fire, but a torch does not automatically impose a numerical Hit, AC, morale or damage penalty, nor trigger an extra morale check; cautious, avoidance, retreat, tactical intimidation and reaction/parley may be interpreted by Encounter within source rules. No forced attack if creatures can avoid or stand off. Appears 1-4 normally/in lair. Scenes specify available walls/ceiling/lighting and whether camouflage is physically applicable; no assumed surprise in an unsuitable environment. Keep the CRAB-T001 fixed surprise result (party 5, spider group 2: spiders surprised) in the Scenario table, not in this species definition. Artwork is DRAFT with incorrect webs and adventurer figures: never treat it as approved reference art.',
     5.00,
     4.00,
     2.00,
     N'Mentzer approx. 5ft body length -> D1=5ft; D2=4ft width and Z=2ft height are AIDM estimates.',
     N'assets/images/monsters/AIDM_CRAB-T001_Four_Giant_Crab_Spiders_DRAFT.png',
     NULL,
     N'CRAB-T001 separately tests four spiders with HP 11,11,9,7 and a fixed encounter surprise branch (party d6=5, spider side d6=2: spiders are surprised, not party). Current illustration is DRAFT, showing party figures and decorative webs inconsistent with monster-only/no-web requirement; NOT approved artwork. IllustrationPath is provisional and must be reviewed/replaced. Asset path pending remote bonnie verification. Source summary: AIDM-DES-001.7 Mentzer Monster Catalogue, OneNote, reviewed 2026-11-21.');

    DECLARE @Inserted TABLE ([MonsterCode] NVARCHAR(80) NOT NULL);

    INSERT INTO [Rules].[Monster]
    (
        [RulesetCode], [MonsterCode], [Active], [SourceStatus],
        [RecordDate], [MonsterName], [ParentMonsterCode], [SourceReference], [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern], [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet], [MovementSpecialText], [Alignment], [XPValue], [NumberAppearingText], [TreasureType], [GeneralDescription], [SpecialAttacksFeatures], [SpecialEncounterFeatures], [D1Feet], [D2Feet], [ZFeet], [SizeBasis], [IllustrationPath], [MapIconPath], [NotesMarkdown]
    )
    OUTPUT inserted.[MonsterCode] INTO @Inserted([MonsterCode])
    SELECT
        N'MentzerBECMI', s.[MonsterCode], CONVERT(BIT,0), N'SourceChecked',
        CONVERT(DATE,SYSUTCDATETIME()), s.[MonsterName], s.[ParentMonsterCode], s.[SourceReference], s.[ArmorClass], s.[HitDiceText], s.[AttackPattern], s.[DamagePattern], s.[SaveAs], s.[Morale], s.[MovementTurnFeet], s.[MovementRoundFeet], s.[MovementSpecialText], s.[Alignment], s.[XPValue], s.[NumberAppearingText], s.[TreasureType], s.[GeneralDescription], s.[SpecialAttacksFeatures], s.[SpecialEncounterFeatures], s.[D1Feet], s.[D2Feet], s.[ZFeet], s.[SizeBasis], s.[IllustrationPath], s.[MapIconPath], s.[NotesMarkdown]
    FROM @Seed AS s
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [Rules].[Monster] AS existing WITH (UPDLOCK, HOLDLOCK)
        WHERE existing.[RulesetCode] = N'MentzerBECMI'
          AND existing.[MonsterCode] = s.[MonsterCode]
    );

    DECLARE @InsertedCount INT = (SELECT COUNT(*) FROM @Inserted);
    COMMIT;

    PRINT CONCAT(N'Rules.Monster seed inserted ', @InsertedCount,
                 N' draft records; existing monster keys preserved.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- Read-only review of the four keys, including previous/historical versions.
SELECT [RecordDate], [RulesetCode], [MonsterCode], [MonsterName], [Active],
       [SourceStatus], [ArmorClass], [HitDiceText], [AttackPattern],
       [DamagePattern], [IllustrationPath], [D1Feet], [D2Feet], [ZFeet]
FROM [Rules].[Monster]
WHERE [RulesetCode] = N'MentzerBECMI'
  AND [MonsterCode] IN
      (N'ORC', N'GIANT_CENTIPEDE', N'CARRION_CRAWLER', N'GIANT_CRAB_SPIDER')
ORDER BY [MonsterCode], [RecordDate] DESC;
GO
