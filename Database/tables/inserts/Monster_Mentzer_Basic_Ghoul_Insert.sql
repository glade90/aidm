/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Mentzer_Basic_Ghoul_Insert.sql
Repository Path : Database/tables/inserts/Monster_Mentzer_Basic_Ghoul_Insert.sql
Project         : Golden Braid / AIDM
Purpose         : Source-checked Mentzer Ghoul species with Combat/Encounter
                  natural-language features and three-Ghoul artwork reference.
Target          : PEQUOD SQL Server 2016+, [DnD].[Rules].[Monster] v0.4
Created         : 2026-11-21
Version         : 0.1.0, inactive SourceChecked pending owner approval
Source          : Mentzer Basic (1983) Dungeon Masters Rulebook, Ghoul p.30;
                  general Undead paragraph later in DM Rulebook.
Dependencies    : Rules.Monster v0.4 (SpecialEncounterFeatures + D1/D2/Z).
Notes           : NEVER use B1 creature counts/HP as default. Ghoul species
                  has separate Combat mechanics and nontechnical Encounter
                  guidance; test fixture GHOUL-T001 and its rolled HP are in
                  [Test].[MonsterTestScenario]/[Test].[MonsterTestCase].
                  Rerunnable, does NOT update previously present versions.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL
    THROW 56650,'Rules.Monster missing. Create table first.',1;
IF COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL
  OR COL_LENGTH(N'Rules.Monster',N'D1Feet') IS NULL
  OR COL_LENGTH(N'Rules.Monster',N'D2Feet') IS NULL
  OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
    THROW 56651,'Rules.Monster v0.4 required; update schema before Ghoul insert.',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
    BEGIN TRAN;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [Rules].[Monster] WITH (UPDLOCK,HOLDLOCK)
        WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'GHOUL'
    )
    BEGIN
        INSERT INTO [Rules].[Monster]
        ([RecordDate], [RulesetCode], [MonsterCode], [Active], [MonsterName], [ParentMonsterCode], [SourceStatus], [SourceReference], [HouseRuleOverlayRefs], [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern], [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet], [MovementSpecialText], [Alignment], [XPValue], [NumberAppearingText], [TreasureType], [GeneralDescription], [SpecialAttacksFeatures], [SpecialEncounterFeatures], [D1Feet], [D2Feet], [ZFeet], [SizeBasis], [IllustrationPath], [MapIconPath], [NotesMarkdown])
        VALUES
        (CONVERT(DATE,SYSUTCDATETIME()),
         N'MentzerBECMI',
         N'GHOUL',
         0,
         N'Ghoul',
         NULL,
         N'SourceChecked',
         N'1983 Mentzer Basic Dungeon Masters Rulebook, Ghoul, printed p.30; general Undead entry.',
         NULL,
         6,
         N'2*',
         N'2 claws and 1 bite',
         N'1d3 / 1d3 / 1d3 + paralysis on each eligible successful hit',
         N'Fighter 2',
         9,
         90.00,
         30.00,
         N'Undead: silent movement; otherwise movement subject to normal dungeon geometry.',
         N'Chaotic',
         25,
         N'1-6 normally; 2-16 in lair',
         N'B',
         N'A hideous, bestial undead creature with the distorted appearance of a once-human corpse, hollow eyes, ragged flesh, taloned fingers and vicious teeth. It moves with a disturbing predatory purpose, emerging from dark, silent passages and crypts. Ghouls are created by dark magic and appear utterly hostile to living prey. Describe physical menace, silence and unnatural stillness without inventing a supernatural fear aura, odour-based sickness or other unsupported game effect.',
         N'Base Ghoul: AC 6, HD 2*, three separate natural attacks per eligible round: two claws and one bite; EACH successful attack independently deals 1d3 HP damage and separately triggers the ghoul''s paralyzing touch where the victim is eligible. A hit on a living creature of ogre SIZE OR SMALLER, other than an ELF, requires the actual victim to Save vs Paralysis. On success, ordinary HP damage still applies but no PARALYZED condition is assigned. On failed save, apply named PARALYZED to that victim, with ghoul source and attack attribution, in addition to the normal 1d3 damage. Elves are explicitly immune to GHOUL paralysis; they still take normal natural-attack damage on a hit, and must NOT be asked for a Ghoul paralysis save. Creatures larger than an ogre do not qualify for this special paralysis (normal damage still applies). A miss deals no damage and triggers no paralysis save. Do not make one saving throw for the whole three-hit combination; each eligible successful hit has its own save, using the correct victim''s profile. Normal paralysis lasts 2-8 dungeon turns unless magically cured; effects on the helpless, timer, cure and ongoing action restrictions belong to the existing generic PARALYZED state/rules (AIDM-DES-001.7.6), not a Ghoul-specific branch. Ghouls are UNDEAD: Sleep and Charm do not affect them; general undead are unaffected by poison and mind-affecting spells, and generic Turn Undead is adjudicated by the applicable Cleric rules, not by adding ad hoc Ghoul combat mechanics. Do not conflate Ghoul paralysis with poison, instant kill or a damage-free Carrion Crawler tentacle.',
         N'Ghouls are evil undead created by dark magic, resembling hideous beast-like humans. They make NO NOISE as a generic undead trait, and generally attack living creatures on encounter; this is strong hostility and predatory behaviour guidance, not an automatic surprise bonus or a requirement to deny the player chances to notice, withdraw, lure, hide, attempt negotiation, create a stand-off, or flee. When a victim becomes paralysed, a Ghoul tends to TURN TOWARD another still-active living opponent; it continues engaging such opponents until the ghoul is defeated or available opponents are dead or paralysed. This is tactical prioritisation for Encounter/LLM and Combat Agent, not a new damage schedule or automatic kill once everyone is helpless. The source provides NO special Ghoul surprise d6 range: use normal one-roll-per-side 1-2 surprise unless some independently sourced situation modifies it. Silence may change the observed scene but is not in itself a universal surprise success. Encounter chooses the number appearing (1-6 normally or 2-16 in lair), scene lighting/cover, access to victims, attempts at parley or retreat and initial visibility, and passes a ready roster to Combat. The Cleric''s Turn Undead interaction belongs to the generic undead/cleric rules interface. Ordinary undead immunity to Sleep, Charm, poison and mind effects should be represented as typed general traits; do not grant immunity to unrelated spells without a source. Do not copy B1 stocked creature counts or HP into species definitions.',
         5.00,
         5.00,
         6.00,
         N'AIDM user-defined humanoid footprint D1=D2=5ft FULL diameters; Ghoul Z=6ft is an estimate, not a Mentzer statistic.',
         N'assets/images/monsters/AIDM_GHOUL-T001_Three_Ghouls_Illustration.webp',
         NULL,
         N'1983 Mentzer Basic Dungeons & Dragons, Dungeon Masters Rulebook, Ghoul, printed p.30 (AC6, 2*, movement 90/30, 2 claws+1 bite 1-3/1-3/1-3 plus special, appearing 1-6/2-16, Fighter2, Morale9, Treasure B, Chaotic, XP25). Same source general Undead entry: created by dark magic, unaffected by poison or mind-affecting Sleep/Charm, make no noise. 2-8 turn normal paralysis unless magically cured. Specific ghoul immunity exception: elves cannot be paralysed by ghouls; victims larger than ogre are outside the special. The 5x5ft FULL diameter footprint is the user''s default humanoid spatial convention, estimated Z=6ft, not published Mentzer geometry. Three Ghoul artwork linked to GHOUL-T001 fixture, not mandatory species count. Test encounter details and per-actor rolled HP live ONLY in Test schema.');
        PRINT N'Inserted Ghoul species as SourceChecked, Active=0.';
    END
    ELSE
        PRINT N'Ghoul species history already exists; no insert/overwrite performed.';
    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW;
END CATCH;
GO
SELECT [RecordDate],[RulesetCode],[MonsterCode],[MonsterName],
       [SourceStatus],[Active],[ArmorClass],[HitDiceText],[AttackPattern],
       [DamagePattern],[D1Feet],[D2Feet],[ZFeet],[IllustrationPath],
       LEN([SpecialAttacksFeatures]) AS [CombatFeatureChars],
       LEN([SpecialEncounterFeatures]) AS [EncounterFeatureChars]
FROM [Rules].[Monster]
WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'GHOUL'
ORDER BY [RecordDate] DESC;
GO
