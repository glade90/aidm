/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Mentzer_Basic_Skeleton_Insert.sql
Repository Path : Database/tables/inserts/Monster_Mentzer_Basic_Skeleton_Insert.sql
Project         : Golden Braid / AIDM / B1 stocklist S14
Purpose         : Mentzer Basic Skeleton species (undead, not encounter actor state).
Target          : PEQUOD, SQL Server 2016+, DnD
Version         : 0.1.0, SourceChecked or Specified, NOT active/executed
Created         : 2026-11-22
Sources         : 1983 Mentzer Basic DM Rulebook p.37 (Skeleton), Players
                  Manual pp.25 (Turning) and 59-60 (weapons/holy water).
Boundary        : B1 Monster List #14 selects species only; never reuse its
                  preassigned monster counts, Hit Points or item data.
                  Turning mechanics are ALREADY tracked in existing story
                  AIDM-DES-001.7.10. No duplicate implementation story.
                  Equipment belongs to the encounter, not every Skeleton.
                  SourceChecked/Specified = NOT approved, activated or passed.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL
 THROW 56900,'Rules.Monster table missing',1;
IF COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'D1Feet') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'D2Feet') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
 THROW 56901,'Rules.Monster schema v0.4 (Encounter and D1/D2/Z) required',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS (
  SELECT 1 FROM [Rules].[Monster] WITH (UPDLOCK,HOLDLOCK)
  WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'SKELETON'
 )
 BEGIN
 INSERT INTO [Rules].[Monster]
 ([RecordDate], [RulesetCode], [MonsterCode], [Active], [MonsterName], [ParentMonsterCode], [SourceStatus], [SourceReference], [HouseRuleOverlayRefs], [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern], [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet], [MovementSpecialText], [Alignment], [XPValue], [NumberAppearingText], [TreasureType], [GeneralDescription], [SpecialAttacksFeatures], [SpecialEncounterFeatures], [D1Feet], [D2Feet], [ZFeet], [SizeBasis], [IllustrationPath], [MapIconPath], [NotesMarkdown])
 VALUES
 (CONVERT(DATE,SYSUTCDATETIME()),
  N'MentzerBECMI',
  N'SKELETON',
  0,
  N'Skeleton',
  NULL,
  N'SourceChecked',
  N'1983 Mentzer Basic Dungeon Masters Rulebook, Skeleton, printed p.37; Players Manual Turning p.25; Variable Weapon Damage p.60; Holy Water p.59.',
  NULL,
  7,
  N'1',
  N'1 attack by equipped weapon',
  N'By weapon; plain 1d6 or variable damage from configured Mentzer weapon',
  N'Fighter 1',
  12,
  60,
  20,
  NULL,
  N'Chaotic',
  10,
  N'3-12 normally in a dungeon; (3-30) wilderness/suggested dungeon lair',
  N'Nil',
  N'Animated humanoid skeleton with exposed bones and hollow sockets, found around graveyards, dungeons and deserted places. Such undead frequently guard places for powerful magic-users or clerics. Describe desiccated bone, rattling footfalls, lifeless gaze and the particular worn weapon in each hand without inventing poison, paralysis, fear, bleeding, or other special attacks.',
  N'Skeletons make exactly ONE weapon attack per eligible round, using the weapon carried by each encounter actor. Ordinary weapon damage is 1d6; when the Mentzer Basic optional Variable Weapon Damage rule is used, look up the exact weapon: Sword (normal) 1d8, Mace 1d6, Battle Axe 1d8 (two-handed), Spear 1d6, Club 1d4, Pole Arm 1d10 (two-handed). A two-handed wielder may not benefit from holding a shield and always loses its own initiative as stipulated by Mentzer. No extra attacks, extra AC or invented rapier rules. Undead immunities from the species entry: not affected by Sleep, Charm or mind reading; they are eligible for Cleric Turning under generic pre-existing AIDM-DES-001.7.10. Ordinary morale is 12: they fight until destroyed unless an external source-backed effect such as Turning makes them retreat. The general holy-water rule inflicts 1d8 to undead only after a successful vial strike (and vial breaking). No blunt-weapon weakness is published in this Skeleton entry.',
  N'Skeletons may act as guards placed by magic-users or clerics. Encounter determines guard instructions, approach, positioning, communication or hostility from the room and fiction, not from the species alone. Normal dungeon number appearing is 3-12; wilderness/lair number is 3-30. Standard one surprise die per side applies, with no special Skeleton surprise threshold. Turned monsters flee as far as possible, stay away for 1-10 rounds and may return under normal DM rules; this is a shared Turning/Encounter lifecycle, NOT new Skeleton-specific code. Pass authoritative species snapshot and selected actors with per-actor equipment and HP to Combat. The six different weapons in SKELETON-T001 are scenario-only equipment, not species defaults.',
  5,
  5,
  6,
  N'AIDM agreed humanoid full 5-ft diameter circular footprint and estimated 6-ft height; neither is stated as Skeleton dimensions by Mentzer.',
  N'assets/monsters/AIDM_SKELETON-T001_Six_Skeletons_Mentzer_Weapons.webp',
  NULL,
  N'B1 S14 Skeleton is a species selector, never an authority for test count, HP or monster weapons. Scenario SKELETON-T001 has six independent 1-HD actors, mixed published Mentzer weapons, HP [6,5,3,2,4,7], party/skeleton surprise 2/3. Rapier is not in the Mentzer Basic weapon chart and was expressly replaced by the user. Existing cleric Turning story AIDM-DES-001.7.10 is re-used, not duplicated. SourceChecked and Active=0 pending owner approval.');
 PRINT N'Inserted SourceChecked/Inactive Skeleton species.';
 END
 ELSE PRINT N'Existing Skeleton species preserved (no version overwritten).';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RecordDate],[RulesetCode],[MonsterCode],[MonsterName],
       [SourceStatus],[Active],[ArmorClass],[HitDiceText],
       [AttackPattern],[DamagePattern],[IllustrationPath]
FROM [Rules].[Monster]
WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'SKELETON'
ORDER BY [RecordDate] DESC;
GO