/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Mentzer_Basic_Kobold_Insert.sql
Repository Path : Database/tables/inserts/Monster_Mentzer_Basic_Kobold_Insert.sql
Project         : Golden Braid / AIDM
Purpose         : Source-checked Kobold species/leader/ambush guidance and art.
Target Server   : PEQUOD SQL Server 2016+ / DnD.[Rules].[Monster]
Version         : 0.1.0 — REVIEW ONLY; SourceChecked, Active=0
Created         : 2026-11-21
Dependencies    : Database/tables/Monster.sql v0.4 (requires SpecialEncounterFeatures
                  and FULL diameter D1/D2/Z).
Source          : Mentzer Basic (1983), Dungeon Masters Rulebook, Kobold entry,
                  printed p.32. B1 S03/S19 select species ONLY.
Design notes    : ONE species row; special chieftain/bodyguard combat roles are
                  explicit Encounter actors (see Test.KOB-T002), not repeated
                  or overwritten in the species catalogue.
                  Scenario count, raw HP/surprise dice, fixture weapons and
                  expected test outcomes live ONLY in Test schema.
                  No SQL Server execution occurs from Git commit.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL
    THROW 56630,'Rules.Monster missing; run current Monster table SQL first.',1;
IF COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL
    OR COL_LENGTH(N'Rules.Monster',N'D1Feet') IS NULL
    OR COL_LENGTH(N'Rules.Monster',N'D2Feet') IS NULL
    OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
    THROW 56631,'Expected Rules.Monster v0.4 (Encounter prose, diameter fields).',1;
GO

SET XACT_ABORT ON;
GO
BEGIN TRY
    BEGIN TRAN;
    IF NOT EXISTS
    (
        SELECT 1 FROM [Rules].[Monster] WITH (UPDLOCK,HOLDLOCK)
        WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'KOBOLD'
    )
    BEGIN
        INSERT INTO [Rules].[Monster]
        ([RecordDate], [RulesetCode], [MonsterCode], [Active], [MonsterName], [ParentMonsterCode], [SourceStatus], [SourceReference], [HouseRuleOverlayRefs], [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern], [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet], [MovementSpecialText], [Alignment], [XPValue], [NumberAppearingText], [TreasureType], [GeneralDescription], [SpecialAttacksFeatures], [SpecialEncounterFeatures], [D1Feet], [D2Feet], [ZFeet], [SizeBasis], [IllustrationPath], [MapIconPath], [NotesMarkdown])
        VALUES
        (CONVERT(DATE,SYSUTCDATETIME()),
         N'MentzerBECMI',
         N'KOBOLD',
         0,
         N'Kobold',
         NULL,
         N'SourceChecked',
         N'1983 Mentzer Basic Dungeon Masters Rulebook, Kobold monster entry; printed p.32.',
         N'AIDM default humanoid footprint full diameter 5 feet, Z approximate 3 feet.',
         7,
         N'1/2 (1-4 HP)',
         N'1 equipped weapon',
         N'By weapon - 1 (minimum 1 HP on a successful damaging hit)',
         N'Normal Man',
         6,
         90.00,
         30.00,
         N'Infravision 90 ft; prefers ambush and underground concealment.',
         N'Chaotic',
         5,
         N'4-16 normally; 6-60 in lair',
         N'(P) J',
         N'Small, wiry, dog-like humanoids with scaly rust-brown skin and no hair. Their narrow muzzles, pointed ears and furtive movements give them an unsettling appearance. They live underground and use their keen senses to find their way in darkness, preferring to fight from ambush when their surroundings permit it. They may carry simple weapons and make threatening noises or exchange wary gestures; narrate individual actions, tension, fear and cunning without inventing automatic modifiers or supernatural abilities.',
         N'Base Kobold: AC 7, HD 1/2 (1-4 starting HP per individual, prepared by Encounter), one weapon attack using the appropriate up-to-1-HD attack profile; successful weapon damage is reduced by 1 after the weapon''s ordinary damage is rolled. This is a DAMAGE penalty, NOT -1 to the Hit roll, AC or saving throw. A successful damaging hit must still inflict at least 1 HP under the approved generic damage floor; on a miss no damage is rolled. An explicitly created Kobold chieftain has 9 starting HP and attacks on the 2-HD monster attack table, even though it is still a Kobold; do not change its HD/XP to imply a new species. The chieftain''s 1-6 bodyguards each have 6 HP and attack as 1+1 HD monsters. All Kobolds WITH a living chieftain receive Morale 8 rather than the ordinary Morale 6, including the chieftain''s accompanying bodyguards. If the chieftain dies or is no longer with a Kobold, recalculate that actor''s applicable Morale as 6 for the next normally scheduled check; do NOT generate an extra unscheduled morale check. Do not stack leadership bonuses or grant extra attacks. Track roles, equipped weapons, chieftain presence and exact damage calculations as typed encounter/combat data.',
         N'Kobolds are small, evil, rust-brown scaly dog-like humanoids who usually live underground. They have 90-foot infravision and PREFER AMBUSHING enemies, using tunnels, cover, concealment and coordinated tactics when plausible. No exceptional 1-3 or 1-4 surprise die range is stated in their Mentzer Basic monster entry: use ordinary one-d6-per-side surprise thresholds unless a separately sourced rule applies. Kobolds hate gnomes and usually attack them on sight; that is encounter reaction/hostility guidance, not a compulsory scripted attack that denies the player the opportunity to parley, retreat, bargain, intimidate or stand off. They may try to lure intruders, defend homes, protect a chieftain or bargain from strength when situation and DM adjudication permit; no automatic fear, reaction, damage, initiative or surprise modifier follows from the descriptive prose alone. Number appearing 4-16 normally, 6-60 in lair. A Kobold lair has a chieftain with 9 HP and 1-6 bodyguards each with 6 HP; Encounter must identify their roles, starting HP, equipment and individual fighting profiles explicitly and hand the prepared roster to Combat. While the chieftain is alive and with them, all Kobolds in that group have Morale 8 instead of 6. Presence/life and cover must be verified from scene/actor facts, not inferred from merely having Kobold species on a roster. Do not import monster counts, pre-rolled HP, weapons or scenario surprises from B1 module entries S03/S19; those entries select the species only.',
         5.00,
         5.00,
         3.00,
         N'Owner humanoid convention D1=D2=5ft FULL diameters; Kobold Z=3ft estimated, not Mentzer.',
         N'assets/images/monsters/AIDM_KOB-T001_Eight_Kobolds_Illustration.webp',
         NULL,
         N'Source: Frank Mentzer 1983 Basic Dungeon Masters Rulebook, Kobold monster entry, printed p.32 in the DM booklet (verify if edition print pagination varies). Specific text: AC7, HD1/2 (1-4 HP), movement 90(30), 1 weapon, weapon damage -1, 4-16 (6-60) appearing, Save Normal Man, ML6 or8, Treasure (P) J, Chaotic, XP5; subterranean, 90-ft infravision, prefers ambush; chieftain 9 HP fights as 2HD, 1-6 bodyguards 6 HP fight as 1+1 HD, ML8 with living chieftain, hates gnomes. The five-foot-diameter circular footprint is the owner''s general humanoid modelling convention; Z=3ft approximate estimate, NOT a printed rule. Review/fixture illustrations live in separate [Test] tables and source-controlled artwork. Illustration is a depiction for KOB-T001''s eight Kobolds, not canonical species count or fixture evidence.');
        PRINT N'Inserted KOBOLD (SourceChecked, inactive), one base species.';
    END
    ELSE
        PRINT N'KOBOLD already exists; left all source versions intact.';
    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW;
END CATCH;
GO

SELECT [RecordDate],[RulesetCode],[MonsterCode],[MonsterName],
       [SourceStatus],[Active],[ArmorClass],[HitDiceText],[DamagePattern],
       [D1Feet],[D2Feet],[ZFeet],[IllustrationPath],
       LEN([SpecialAttacksFeatures]) AS [CombatFeatureChars],
       LEN([SpecialEncounterFeatures]) AS [EncounterFeatureChars]
FROM [Rules].[Monster]
WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'KOBOLD';
GO
