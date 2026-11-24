/* Golden Braid AIDM B1 S20 Bandit — species
FILE: Monster_Mentzer_Basic_Bandit_Insert.sql
TARGET: DnD on PEQUOD (SQL Server 2016+)
SOURCE: Mentzer Basic 1983 Dungeon Masters Rulebook, Bandit printed p.25.
B1 S20 is the species selector only; The False Guides is a synthetic fixture.
2026-11-22. Idempotent INSERT-ONLY; Specified/SourceChecked are not execution, approval or UAT.
*/
USE [DnD];
GO

IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL OR COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
 THROW 57200,'Rules.Monster v0.4 required before Bandit insert',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS (SELECT 1 FROM [Rules].[Monster] WITH(UPDLOCK,HOLDLOCK) WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'BANDIT')
 BEGIN
  INSERT INTO [Rules].[Monster] ([RecordDate],[RulesetCode],[MonsterCode],[Active],[MonsterName],[ParentMonsterCode],[SourceStatus],[SourceReference],[HouseRuleOverlayRefs],[ArmorClass],[HitDiceText],[AttackPattern],[DamagePattern],[SaveAs],[Morale],[MovementTurnFeet],[MovementRoundFeet],[MovementSpecialText],[Alignment],[XPValue],[NumberAppearingText],[TreasureType],[GeneralDescription],[SpecialAttacksFeatures],[SpecialEncounterFeatures],[D1Feet],[D2Feet],[ZFeet],[SizeBasis],[IllustrationPath],[MapIconPath],[NotesMarkdown])
  VALUES (CONVERT(DATE,SYSUTCDATETIME()),N'MentzerBECMI',N'BANDIT',0,N'Bandit',NULL,N'SourceChecked',N'Mentzer Basic 1983 Dungeon Masters Rulebook, Bandit, printed p.25. B1 stocklist S20 selects the monster type, not a prescribed encounter.',NULL,6,N'1',N'1 equipped weapon',N'1d6 standard weapon damage, or actual weapon damage under the approved Variable Weapon Damage option',N'Thief 1',8,90,30,NULL,N'Chaotic or Neutral',10,N'1-8 (3-30)',N'U (A)',N'Bandits are ordinary human NPCs who work together to rob others. Their appearance need not announce hostile intent. Clothing, visible weapons, apparent occupation and demeanor depend on the scene; they may appear to be travellers or explorers. No fixed dialogue or forced hostility.',N'BANDIT COMBAT: Armor Class 6; 1 Hit Die; 1 actually equipped weapon attack per eligible round, using the ordinary 1-HD monster hit row; Save As Thief 1 is solely a saving-throw designation and does not confer Pick Locks, Hide in Shadows, Backstab or any other Thief class skill. Resolve hits, misses, damage, ordinary side initiative, valid combat modifiers, HP and morale 8 through the Combat Engine. Do not add automatic surprise, class bonuses, statuses, injury mechanics or pre-combat deception to combat. Individual loadouts belong to the encounter fixture.',N'BANDIT ENCOUNTER: Intelligent human robbers may pose as ordinary travellers, bluff, negotiate, threaten, demand valuables, retreat or fight according to their aims and reactions. Determine group count, disposition, surprise (one d6 per side under normal rules), party intent, dialogue and any escalation in the future Encounter Engine, not the Combat Engine. Social deception never grants automatic surprise or a combat modifier without a separately supported rule. Higher-level NPC leaders are optional and separately generated only when actually present. Type U is individual treasure; parenthetical Type A refers to a wilderness lair and is not automatically added to dungeon bandits. No leader in BANDIT-T001.',5,5,6,N'AIDM human-scale modelling dimensions D1=5 ft, D2=5 ft, Z=6 ft, not published Mentzer measurements.',N'assets/monsters/AIDM_BANDIT_S20_The_False_Guides.webp',NULL,N'S20 The False Guides: four bandits HP 6/4/5/3 (18 total), two ordinary swords, one spear, one club, no higher-level leader and no thief skills. 14 COMBAT and 8 ENCOUNTER specified cases; Encounter is future work. Artwork is illustrative only. This insert does not execute the test cases.');
  PRINT N'Inserted inactive SourceChecked Bandit species';
 END ELSE PRINT N'Existing Bandit species preserved';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RulesetCode],[MonsterCode],[MonsterName],[SourceStatus],[Active],[ArmorClass],[HitDiceText],[Morale],[MovementTurnFeet],[MovementRoundFeet],[D1Feet],[D2Feet],[ZFeet],[IllustrationPath]
FROM [Rules].[Monster] WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'BANDIT';
GO
