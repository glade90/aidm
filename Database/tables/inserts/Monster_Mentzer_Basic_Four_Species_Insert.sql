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
Version         : 0.2.0 (REVIEW SEED; NOT ACTIVE)
Created         : 2026-11-21
Dependencies    : Database/database/dnd.sql, Database/database/Rules.sql,
                  Database/tables/Monster.sql
Source          : 1983 Mentzer Basic Dungeon Masters Rulebook pp.27, 28, 35, 37
                  and original Golden Braid DES-001.7 source review, 2026-11-21.

DESIGN NOTES
- NO B1 module encounter stats. B1 selects species only.
- NO encounter group counts/individual HP/conditions are seeded here.
- Only four base species, no chieftain/leader *instance* spawned.
- Non-destructive and rerunnable: existing rows are NOT updated/deactivated.
  If any historical row exists for a (RulesetCode,MonsterCode), skip that key.
- Rows are SourceChecked, Active=0 until owner approves and activates them.
  Table constraint correctly prevents making unapproved rows active.
- Original image filenames were saved in OneDrive and reportedly copied to
  local assets/images/monsters; directory was NOT visible on GitHub bonnie
  during authoring. Paths must be checked after owner's push before activation.
- CRAB illustration is a DRAFT with unwanted webbing/party figures, not canon.
- R1 and R2 are major/minor horizontal ellipse RADII in feet, not diameter.
  Z is vertical height in feet; footprint is descriptive and not a rule.
- Mentzer gives approximately 1-ft Centipede length, 9-ft Crawler length and
  3-ft height, and 5-ft Crab Spider length. Other dimensions are AIDM guesses.
- All humans/humanoids use owner-defined 5-ft circular R1/R2 default;
  for Orc R1=R2=5. Thus Orc has a TEN-FOOT DIAMETER footprint.
- Existing inactive SourceChecked rows are NOT changed on rerun. Use the
  separate ellipse migration script to update legacy unapproved draft rows.
- SpecialAttacksFeatures carries *natural-language* Combat Agent guidance;
  deterministic generic services validate typed requests and commit state.
- This script does NOT run against PEQUOD; owner runs it after local review.

CHANGE LOG
2026-11-21  0.1.0  First four reviewed monster species seed records.
2026-11-21  0.2.0  Set ellipse radii R1/R2 and Z estimates for four monsters.
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
        [R1Feet] DECIMAL(9,2) NULL,
        [R2Feet] DECIMAL(9,2) NULL,
        [ZFeet] DECIMAL(9,2) NULL,
        [SizeBasis] NVARCHAR(200) NULL,
        [IllustrationPath] NVARCHAR(500) NULL,
        [MapIconPath] NVARCHAR(500) NULL,
        [NotesMarkdown] NVARCHAR(MAX) NULL
    );

    INSERT INTO @Seed
    ([MonsterCode], [MonsterName], [ParentMonsterCode], [SourceReference], [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern], [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet], [MovementSpecialText], [Alignment], [XPValue], [NumberAppearingText], [TreasureType], [GeneralDescription], [SpecialAttacksFeatures], [R1Feet], [R2Feet], [ZFeet], [SizeBasis], [IllustrationPath], [MapIconPath], [NotesMarkdown])
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
     N'Use the encounter roster to identify each Orc''s role and current conditions; do not create roles, equipment, starting HP or targets from this species row. A fighting Orc in daylight suffers -1 to its Hit roll; this is not a damage or Armor Class penalty. A specifically designated ordinary Orc group leader has 8 starting HP supplied by encounter setup and adds +1 to damage after a successful weapon hit. If that leader dies, the surviving group''s morale value becomes 6 instead of 8, but roll a morale check only when the generic Mentzer morale procedure next requires one; death alone does not create a bonus check. A tribal chieftain is a distinct, explicitly identified encounter role with 15 starting HP, attacks using the 4-HD monster attack table and adds +2 damage after a successful weapon hit; do not also add the ordinary leader''s +1. The daylight -1 Hit penalty applies to the chieftain as well. These rules are conditions for the Combat Agent to interpret and propose; generic deterministic tools validate and apply them. Do not infer numerical morale penalties merely from Orc fear of strong foes.',
     5,
     5,
     6,
     N'Owner AIDM humanoid convention: R1=R2=5ft (10ft diameter); Z=6ft is approximate standing height, not a Mentzer rule.',
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
     N'A Giant Centipede attacks once by biting. If its Hit roll misses, no poison saving throw or damage is caused. If its bite hits, the bite itself causes zero HP damage; the bitten target must make a Saving Throw versus Poison. A successful save causes no illness or condition. A failed save applies the owner-approved named condition NAUSEATED to the actual victim. It lasts ten days of in-game time, allows movement at half normal speed, and forbids other physical actions while active. It is not death, continuing HP poison damage, a second saving throw, or complete immobility. The current prototype Combat test only checks the correct bite/save trigger, zero damage, and initial NAUSEATED assignment; enforcing movement/action limits, lasting time, persistence and expiry belongs to generic future lifecycle story AIDM-DES-001.7.5. The Combat Agent selects the relevant Poison save/effect proposal; generic tools resolve and commit state.',
     0.50,
     0.15,
     0.20,
     N'Mentzer approx. 1ft body length -> R1=0.5ft; R2=0.15ft and Z=0.2ft estimated for future geometry.',
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
     N'The Carrion Crawler can make eight independent tentacle Hit rolls in a round, each against a legal target chosen by its Combat Agent within the permitted attack/target sequence. A miss causes neither damage nor saving throw. Each tentacle hit deals zero HP damage but requires the struck target to save versus Paralysis; a failed save marks that individual PARALYZED. The crawler generally prefers an unparalysed viable opponent over wasting further attacks on a helpless target and may distribute its permitted attacks among eligible foes. When it is no longer under attack and prey is paralysed, it seeks to feed; do not invent a new bite-damage schedule or automatic death. Generic PARALYZED rules: the victim remains conscious but cannot move, speak, attack or cast; attacks against a paralysed victim automatically hit and need only a damage roll. Base paralysis typically lasts 2d4 dungeon turns unless overridden; Cure Light Wounds can instead remove paralysis without healing HP. The initial crawler Combat test requires only separate attacks, correct-target saves and PARALYZED assignment; lifecycle/recovery/automatic-hit verification is deferred to generic story AIDM-DES-001.7.6. No species-specific hardcoded Python branch.',
     4.50,
     1.50,
     3.00,
     N'Mentzer approx. 9ft length and 3ft height -> R1=4.5ft, Z=3ft; R2=1.5ft estimated width.',
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
     N'Camouflage allows the Crab Spider to surprise enemies on party-side surprise die results 1-4 on 1d6, rather than the normal 1-2; the spiders'' own vulnerability to being surprised is the ordinary 1-2. Resolve this at the generic Encounter surprise boundary, using one roll per side; do not roll per spider or automatically grant a surprise round. After its first attack, the spider is visible and may be targeted normally. In combat it makes one bite attack: a miss causes no damage and no poison save; a hit causes 1d8 direct HP damage and requires the victim to Save versus Poison, adding +2 to that victim''s save roll because the venom is weak. A successful save avoids poison while keeping the bite damage. On failed save, assign generic POISONED to the actual victim, source attributed to that spider; the full source effect can cause delayed death in 1d4 dungeon turns, NOT immediate death on the bite. Current combat acceptance checks only HP damage, the correct +2 Poison save and initial POISONED state; timing/recovery is deferred to AIDM-DES-001.7.7. Fire avoidance is tactical behaviour, not a guaranteed fear effect or numeric modifier. The spider does not create webs.',
     2.50,
     2.00,
     2.00,
     N'Mentzer approx. 5ft body length -> R1=2.5ft; R2=2ft and Z=2ft estimated for leg span/height.',
     N'assets/images/monsters/AIDM_CRAB-T001_Four_Giant_Crab_Spiders_DRAFT.png',
     NULL,
     N'CRAB-T001 separately tests four spiders with HP 11,11,9,7 and a fixed encounter surprise branch (party d6=5, spider side d6=2: spiders are surprised, not party). Current illustration is DRAFT, showing party figures and decorative webs inconsistent with monster-only/no-web requirement; NOT approved artwork. IllustrationPath is provisional and must be reviewed/replaced. Asset path pending remote bonnie verification. Source summary: AIDM-DES-001.7 Mentzer Monster Catalogue, OneNote, reviewed 2026-11-21.');

    DECLARE @Inserted TABLE ([MonsterCode] NVARCHAR(80) NOT NULL);

    INSERT INTO [Rules].[Monster]
    (
        [RulesetCode], [MonsterCode], [Active], [SourceStatus],
        [RecordDate], [MonsterName], [ParentMonsterCode], [SourceReference], [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern], [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet], [MovementSpecialText], [Alignment], [XPValue], [NumberAppearingText], [TreasureType], [GeneralDescription], [SpecialAttacksFeatures], [R1Feet], [R2Feet], [ZFeet], [SizeBasis], [IllustrationPath], [MapIconPath], [NotesMarkdown]
    )
    OUTPUT inserted.[MonsterCode] INTO @Inserted([MonsterCode])
    SELECT
        N'MentzerBECMI', s.[MonsterCode], CONVERT(BIT,0), N'SourceChecked',
        CONVERT(DATE,SYSUTCDATETIME()), s.[MonsterName], s.[ParentMonsterCode], s.[SourceReference], s.[ArmorClass], s.[HitDiceText], s.[AttackPattern], s.[DamagePattern], s.[SaveAs], s.[Morale], s.[MovementTurnFeet], s.[MovementRoundFeet], s.[MovementSpecialText], s.[Alignment], s.[XPValue], s.[NumberAppearingText], s.[TreasureType], s.[GeneralDescription], s.[SpecialAttacksFeatures], s.[R1Feet], s.[R2Feet], s.[ZFeet], s.[SizeBasis], s.[IllustrationPath], s.[MapIconPath], s.[NotesMarkdown]
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
       [DamagePattern], [IllustrationPath], [R1Feet], [R2Feet], [ZFeet]
FROM [Rules].[Monster]
WHERE [RulesetCode] = N'MentzerBECMI'
  AND [MonsterCode] IN
      (N'ORC', N'GIANT_CENTIPEDE', N'CARRION_CRAWLER', N'GIANT_CRAB_SPIDER')
ORDER BY [MonsterCode], [RecordDate] DESC;
GO
