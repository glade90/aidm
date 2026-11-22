/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Mentzer_Basic_Shrieker_Insert.sql
Repository Path : Database/tables/inserts/Monster_Mentzer_Basic_Shrieker_Insert.sql
Project         : Golden Braid / AIDM / AIDM-DES-001.7 S13
Purpose         : Seed the reviewed Mentzer Basic Shrieker species definition
                  for the future Encounter Engine, not a Combat test fixture.
Target          : PEQUOD, SQL Server / DnD.[Rules].[Monster] v0.4
Version         : 0.1.0 / SOURCE CHECKED / INACTIVE
Created         : 2026-11-22
Source          : Frank Mentzer, 1983 D&D Basic Dungeon Masters Rulebook,
                  Shrieker, printed page 37.

BOUNDARIES / OPEN RULINGS
- Shrieker has no damaging attack. The Combat Engine needs no Shrieker-
  specific implementation; ordinary attacks against it use generic rules.
- Owner-approved Encounter ruling: simultaneous group of Shriekers produces
  ONE alarm, not one independent alarm per creature.
- One alarm DOES NOT mean an approved cap of one responding monster group:
  multiple successful hearing checks, alarm retriggering after a continued
  stimulus, and whether killing a Shrieker ends a shriek are unresolved.
- Mentzer explicitly specifies 1-3 shrieking rounds, d6 hearing roll of 4-6
  each shrieking round, and a 2-12-round arrival delay. 1d3 and 2d6 are
  ordinary dice interpretations of those stated numeric ranges.
- One alarm and the arrival events are ENCOUNTER / EXPEDITION responsibilities.
  Wandering monster identity/reaction come from dungeon context and ordinary
  encounter rules; do not treat responding monsters as automatically hostile.
- Companion Encounter test definition files seed SHRIEKER-T001 from the
  earlier saved rolls and SHRIEKER-T002 from new independent synthetic rolls.
  Both remain Specified/Not Ready; THIS SPECIES FILE does not seed tests.
- AIDM narrative-based physical size estimate: D1=D2=4ft full cap diameter,
  Z=5ft height. These are inferred from 'giant mushroom', NOT Mentzer measurements.
- Image asset is a separate static file; this SQL references its repo path.
- Existing species rows are preserved except for targeted dimension-only
  backfill of the original NULL-size Shrieker seed; no other fields overwritten
  or Active status changed.
- This script is committed to bonnie only, NOT executed on PEQUOD.
===============================================================================
*/
USE [DnD];
GO

IF OBJECT_ID(N'Rules.Monster', N'U') IS NULL
    THROW 56800, 'Rules.Monster missing; install the species schema first.', 1;
IF COL_LENGTH(N'Rules.Monster', N'SpecialEncounterFeatures') IS NULL
    OR COL_LENGTH(N'Rules.Monster', N'D1Feet') IS NULL
    OR COL_LENGTH(N'Rules.Monster', N'D2Feet') IS NULL
    OR COL_LENGTH(N'Rules.Monster', N'ZFeet') IS NULL
    THROW 56801, 'Rules.Monster v0.4 including SpecialEncounterFeatures and diameters is required.', 1;
GO

SET XACT_ABORT ON;
GO
BEGIN TRY
    BEGIN TRAN;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [Rules].[Monster] WITH (UPDLOCK, HOLDLOCK)
        WHERE [RulesetCode] = N'MentzerBECMI'
          AND [MonsterCode] = N'SHRIEKER'
    )
    BEGIN
        INSERT INTO [Rules].[Monster]
        (
            [RecordDate], [RulesetCode], [MonsterCode], [Active],
            [MonsterName], [ParentMonsterCode], [SourceStatus],
            [SourceReference], [HouseRuleOverlayRefs],
            [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern],
            [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet],
            [MovementSpecialText], [Alignment], [XPValue],
            [NumberAppearingText], [TreasureType],
            [GeneralDescription], [SpecialAttacksFeatures],
            [SpecialEncounterFeatures],
            [D1Feet], [D2Feet], [ZFeet], [SizeBasis],
            [IllustrationPath], [MapIconPath], [NotesMarkdown]
        )
        VALUES
        (
            CONVERT(DATE, SYSUTCDATETIME()),
            N'MentzerBECMI', N'SHRIEKER', 0,
            N'Shrieker', NULL, N'SourceChecked',
            N'1983 Mentzer D&D Basic Dungeon Masters Rulebook, Shrieker, printed p.37.',
            N'Owner Encounter ruling (2026-11-22): one shared alarm for a group of Shriekers triggered together. Multiple independently arriving wandering-monster groups from repeated successful hearing rolls NOT YET RULED.',
            7, N'3', N'Piercing shriek (Encounter effect); no direct attack', N'Nil',
            N'Fighter 2', 12, 9.00, 3.00,
            NULL, N'Neutral', 35,
            N'1-8 in a dungeon room; (0) wilderness', N'Nil',
            N'A giant mushroom-like creature inhabiting underground caverns and moving extremely slowly. It reacts to nearby light or movement by emitting a piercing shriek. Its danger lies in drawing wandering monsters toward the party rather than harming anyone directly. Describe the fungus and its alarm without adding sonic damage, fear, deafness, paralysis, or invented attacks.',
            N'No damaging attack or special Combat action. Attacks made by adventurers against a Shrieker use existing generic Hit, damage, HP and defeat mechanics. The shriek, its triggering conditions, hearing checks and delayed wandering-monster arrivals are Encounter/Expedition concerns; Combat must not spawn wandering monsters or reimplement alarm behaviour.',
            N'Light within 60 feet OR movement within 30 feet triggers a piercing shriek lasting 1-3 rounds. For EACH round of shrieking, the DM rolls 1d6: results 4-6 indicate that a wandering monster heard the noise and will arrive in 2-12 rounds. Owner ruling: simultaneously triggered Shriekers in the same group produce ONE alarm, with one hearing check per alarm-round, not one per individual Shrieker. The published monster entry does not specify whether multiple successful checks represent distinct arrivals, how continuing light/movement retriggers an alarm, the maximum audible range, or precisely when an ongoing shriek is interrupted; leave those questions open for Encounter design. The dungeon wandering-monster table determines the responding creatures, and the DM resolves their reactions using ordinary encounter rules rather than automatic hostility. Once hearing is successful, record an arrival due later; do not teleport a monster directly into the same round. Alarm countdowns and any arrivals may outlast the Shrieker encounter. The normal wandering-monster procedure for loud combat is a separate exploration-turn system, not an automatic additional monster every combat round.',
            4.00, 4.00, 5.00,
            N'AIDM geometry estimate inferred from Mentzer giant mushroom description: 4ft cap diameter (D1=D2) and 5ft total height (Z). Not published dimensions.',
            N'assets/monsters/AIDM_SHRIEKER_Species_Torchlit_Cavern_Illustration.webp',
            NULL,
            N'Species catalogue entry only. Shrieker is OUT OF SCOPE for Shrieker-specific Combat Engine fixtures. Encounter tests SHRIEKER-T001 (saved 4-Shrieker count and HP 6,6,19,15) and SHRIEKER-T002 (new independent movement-only rolls) are specified separately in scenario/case SQL. Both remain ReadyForExecution=0. SourceChecked/Active=0 until owner approves activation. One simultaneous group alarm is owner-approved; cap on wandering-monster arrival groups remains unresolved. The full-resolution original illustration is preserved separately in Golden Braid/AIDM/Illustrations.'
        );
        PRINT N'Inserted inactive SourceChecked Shrieker species.';
    END
    ELSE
    BEGIN
        PRINT N'Existing SHRIEKER record found; no duplicate species row.';
    END;

    -- Correct only the original S13 seed rows that still contain all-NULL
    -- dimensions and the exact old SizeBasis marker. Do not touch dimensions
    -- already supplied by a later source or user, or any unrelated attributes.
    UPDATE [Rules].[Monster]
       SET [D1Feet] = 4.00,
           [D2Feet] = 4.00,
           [ZFeet] = 5.00,
           [SizeBasis] = N'AIDM geometry estimate inferred from Mentzer giant mushroom description: 4ft cap diameter (D1=D2) and 5ft total height (Z). Not published dimensions.'
     WHERE [RulesetCode] = N'MentzerBECMI'
       AND [MonsterCode] = N'SHRIEKER'
       AND [D1Feet] IS NULL
       AND [D2Feet] IS NULL
       AND [ZFeet] IS NULL
       AND [SizeBasis] = N'No published dimensions; previous AIDM estimate of 4 x 4 x 5 ft was proposed but not approved.';

    DECLARE @DimensionsBackfilled INT = @@ROWCOUNT;
    PRINT CONCAT(N'Shrieker dimension-only backfilled rows: ', @DimensionsBackfilled);

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- Read-only verification.
SELECT [RecordDate], [RulesetCode], [MonsterCode], [MonsterName],
       [SourceStatus], [Active], [ArmorClass], [HitDiceText],
       [AttackPattern], [DamagePattern], [Morale],
       [MovementTurnFeet], [MovementRoundFeet],
       [D1Feet], [D2Feet], [ZFeet], [IllustrationPath]
FROM [Rules].[Monster]
WHERE [RulesetCode] = N'MentzerBECMI'
  AND [MonsterCode] = N'SHRIEKER'
ORDER BY [RecordDate] DESC;
GO
