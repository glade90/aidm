/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Adventure_B1_Insert.sql
Repository Path : Database/tables/Adventure_B1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Seed a player-safe record for the B1 adventure.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema / Table  : dbo.Adventure
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/tables/Adventure.sql

DESIGN NOTES
- B1 is a published module, but Adventure can also store original scenarios.
- The summary is player-facing; no DM-only stocking or secret information.
- 1983 Mentzer Basic D&D is the rulebook used by THIS campaign; the module's
  historical publication does not define or change our chosen ruleset.
- Idempotent initial insert: will not overwrite an existing AdventureCode B1.

CHANGE LOG
Date         Version   Description
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     Add B1 with its published-module identification,
                        spoiler-free introduction and established ruleset.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'dbo.Adventure', N'U') IS NULL
    THROW 51310, 'Missing dbo.Adventure; execute Adventure.sql first.', 1;

IF NOT EXISTS (SELECT 1 FROM [dbo].[Adventure] WHERE [AdventureCode] = N'B1')
BEGIN
    INSERT INTO [dbo].[Adventure]
    (
        [AdventureCode], [Active], [AdventureName], [AdventureType],
        [ModuleCode], [ModuleTitle], [Publisher], [Ruleset], [RulesNotes],
        [PlayerSummary], [AdventureStatus], [Notes]
    )
    VALUES
    (
        N'B1', 1, N'In Search of the Unknown', N'PublishedModule',
        N'B1', N'In Search of the Unknown', N'TSR',
        N'1983 Mentzer Basic D&D',
        N'Campaign uses Mentzer Basic, the B1 module, and the agreed house rulings documented in the campaign protocol. See the separately maintained Rules register when created.',
        N'An expedition explores the hidden Caverns of Quasqueton, a mysterious stronghold associated with two long-vanished adventurers. Its constructed halls and natural caverns promise danger, discovery and the possibility of treasure.',
        N'Ongoing',
        N'Player-safe adventure record. Expedition 12 has returned to town but its XP settlement remains unfinished. The adventure itself continues.'
    );
    PRINT N'Inserted adventure B1.';
END
ELSE
    PRINT N'Adventure B1 already exists; seed skipped to preserve recorded versions.';
GO

SELECT [RecordDate], [AdventureCode], [AdventureName], [ModuleCode],
       [ModuleTitle], [Ruleset], [AdventureStatus], [PlayerSummary], [Active]
FROM [dbo].[Adventure]
WHERE [AdventureCode] = N'B1'
ORDER BY [RecordDate] DESC;
GO
