/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Alho_Evro_B1_Expedition12_Correction_v1_0_1.sql
Repository Path : Database/tables/Alho_Evro_B1_Expedition12_Correction_v1_0_1.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Correct first B1 expedition to 12 for both Evro and Alho;
                  insert Alho's B1 Expedition 12 participation with correctly
                  escaped Markdown and actual table column names.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema / Tables : characters.CharacterAdventure
                  characters.CharacterExpedition
Version         : 1.0.1
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/tables/CharacterAdventure.sql
                  Database/tables/CharacterExpedition.sql
                  Database/tables/Expedition_B1_12_Insert.sql
                  Alho's earlier Character and CharacterAdventure inserts

DESIGN NOTES
- The characters have adventures together before B1, but both FIRST join the
  B1 adventure in Expedition 12; this is not their first ever adventure.
- Corrections to InitialExpedition fix mistaken seed data in-place, preserving
  RecordDate and all existing FK references (not a new in-world event).
- Safe to rerun: an existing Alho Expedition 12 participation is not duplicated.
- Records unknown XP and treasure shares as NULL until settlement; StartHP=8
  is from the agreed retroactive maximum-first-hit-die rule.
- This script neither changes table definitions nor creates missing characters.
- NotesMarkdown uses N'...''...' SQL Unicode string quoting, not N''#...''.

CHANGE LOG
Date         Version  Description
-----------  -------  -------------------------------------------------------
2026-10-18   1.0.0    Correct B1 initial expedition; repair Alho T-SQL insert.
2026-10-18   1.0.1    Validate actual CharacterExpedition column names;
                        issue separate file to prevent running obsolete SQL.
===============================================================================
*/

USE [DnD];
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'characters.CharacterAdventure', N'U') IS NULL
    THROW 51800, 'Missing characters.CharacterAdventure.', 1;
IF OBJECT_ID(N'characters.CharacterExpedition', N'U') IS NULL
    THROW 51801, 'Missing characters.CharacterExpedition.', 1;
IF OBJECT_ID(N'dbo.Expedition', N'U') IS NULL
    THROW 51802, 'Missing dbo.Expedition.', 1;

-- Fail with a useful message before doing any data changes if the live table
-- does not match the currently agreed CharacterExpedition.sql schema.
IF COL_LENGTH(N'characters.CharacterExpedition', N'ParticipationRole') IS NULL
   OR COL_LENGTH(N'characters.CharacterExpedition', N'ParticipationStatus') IS NULL
   OR COL_LENGTH(N'characters.CharacterExpedition', N'StartHP') IS NULL
   OR COL_LENGTH(N'characters.CharacterExpedition', N'EndHP') IS NULL
BEGIN
    THROW 51805,
        'CharacterExpedition is missing expected columns. Verify the deployed table schema before inserting.', 1;
END;
GO

DECLARE @ExpeditionRecordDate DATE;
DECLARE @CharacterAdventureRecordDate DATE;

SELECT @ExpeditionRecordDate = [RecordDate]
FROM [dbo].[Expedition]
WHERE [AdventureCode] = N'B1'
  AND [ExpeditionNumber] = 12
  AND [Active] = 1;

SELECT @CharacterAdventureRecordDate = [RecordDate]
FROM [characters].[CharacterAdventure]
WHERE [CharacterName] = N'Alho'
  AND [AdventureCode] = N'B1'
  AND [Active] = 1;

IF @ExpeditionRecordDate IS NULL
    THROW 51803, 'Active B1 Expedition 12 not found. Insert that expedition first.', 1;
IF @CharacterAdventureRecordDate IS NULL
    THROW 51804, 'Active Alho/B1 CharacterAdventure not found. Run Alho''s CharacterAdventure insert first.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Correct the originally assumed Expedition 1 for Alho and ensure Evro=12.
    -- This does not change their historical database RecordDate key.
    UPDATE [characters].[CharacterAdventure]
       SET [InitialExpedition] = 12
     WHERE [AdventureCode] = N'B1'
       AND [CharacterName] IN (N'Alho', N'Evro')
       AND [Active] = 1
       AND [InitialExpedition] <> 12;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [characters].[CharacterExpedition]
        WHERE [CharacterName] = N'Alho'
          AND [AdventureCode] = N'B1'
          AND [ExpeditionNumber] = 12
    )
    BEGIN
        INSERT INTO [characters].[CharacterExpedition]
        (
            [CharacterName], [AdventureCode], [ExpeditionNumber], [Active],
            [CharacterAdventureRecordDate], [ExpeditionRecordDate],
            [ParticipationRole], [ParticipationStatus],
            [StartHP], [EndHP], [NotesMarkdown]
        )
        VALUES
        (
            N'Alho', N'B1', 12, 1,
            @CharacterAdventureRecordDate, @ExpeditionRecordDate,
            N'PlayerCharacter', N'Returned',
            8, NULL,
            N'# B1 — Expedition 12

Alho joined the B1 adventure during Expedition 12 as a front-line Fighter.
She is a noble-born adventurer who rejects court life in favour of danger,
companionship, and discovery. She is one of Evro''s closest friends and the
one person he trusts completely. Her battlefield resolve and ruthless
commitment compensate for her otherwise unexceptional ability scores.

Her permanent appearance and personal history are recorded in separate
CharacterAppearance and Character records. XP, treasure share, and any
unverified closing statistics remain pending until expedition settlement.'
        );
        PRINT N'Inserted Alho B1 Expedition 12 participation.';
    END
    ELSE
    BEGIN
        PRINT N'Alho B1 Expedition 12 participation already exists; skipped.';
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Read-only verification.
SELECT [CharacterName], [AdventureCode], [InitialExpedition], [Active],
       [RecordDate]
FROM [characters].[CharacterAdventure]
WHERE [CharacterName] IN (N'Alho', N'Evro')
  AND [AdventureCode] = N'B1'
ORDER BY [CharacterName], [RecordDate] DESC;

SELECT [CharacterName], [AdventureCode], [ExpeditionNumber], [Active],
       [ParticipationRole], [ParticipationStatus], [StartHP], [EndHP],
       [StartXP], [MonsterXP], [TreasureXP], [EndXP], [TreasureShareCopper]
FROM [characters].[CharacterExpedition]
WHERE [CharacterName] = N'Alho'
  AND [AdventureCode] = N'B1'
  AND [ExpeditionNumber] = 12
ORDER BY [RecordDate] DESC;
GO
