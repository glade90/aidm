/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Expedition_B1_12_Insert.sql
Repository Path : Database/tables/Expedition_B1_12_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Seed Expedition 12 of B1 as returned to town but not yet
                  formally closed by its XP/treasure settlement ceremony.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema / Table  : dbo.Expedition
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/tables/Adventure_B1_Insert.sql
                  Database/tables/Expedition.sql

DESIGN NOTES
- The party exited Quasqueton by dungeon Turn 74; the Turn 74 corridor
  encounter was superseded in the approved return-travel ruling.
- Three full wine barrels were delivered and the cooper's payment collected.
- Adventure B1 continues, but Expedition 12 is in SETTLEMENT status:
  monster/treasure XP is still unawarded and the closing ceremony incomplete.
- Do not invent an in-game calendar date, exact clock time or final XP total.
- Seed inserts ONCE per adventure/expedition; never overwrites history.

CHANGE LOG
Date         Version   Description
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     Record Expedition 12 return and pending XP ceremony.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'dbo.Expedition', N'U') IS NULL
    THROW 51510, 'Missing dbo.Expedition. Execute Expedition.sql first.', 1;
GO

DECLARE @AdventureRecordDate DATE;
SELECT @AdventureRecordDate = [RecordDate]
FROM [dbo].[Adventure]
WHERE [AdventureCode] = N'B1' AND [Active] = 1;

IF @AdventureRecordDate IS NULL
    THROW 51511, 'No active B1 adventure. Execute Adventure_B1_Insert.sql first.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM [dbo].[Expedition]
    WHERE [AdventureCode] = N'B1' AND [ExpeditionNumber] = 12
)
BEGIN
    INSERT INTO [dbo].[Expedition]
    (
        [AdventureCode], [ExpeditionNumber], [Active], [AdventureRecordDate],
        [ExpeditionStatus], [StartLocation], [EndLocation],
        [FinalDungeonTurn], [SummaryMarkdown], [SettlementNotes]
    )
    VALUES
    (
        N'B1', 12, 1, @AdventureRecordDate,
        N'Settlement', N'Town', N'Town', 74,
        N'## Expedition 12 — In Search of the Unknown

Six adventurers explored the Caverns of Quasqueton and returned alive. The party investigated the Room of Pools, explored the lower caverns, overcame several hostile encounters, recovered an engraved crystal goblet, and brought three full barrels of wine back to town for delivery to the cooper.

The group is safely back in town preparing for Expedition 13. This summary records player-known events and contains no undiscovered dungeon secrets.',
        N'## Settlement still pending

- The party reached town and completed the cooper and treasure-sale transactions.
- Expedition 12 monster XP and treasure XP have **not** been finalized or awarded.
- Individual XP shares, retainer terms, and ending character records require audit before closing this expedition.
- Do not mark this expedition Closed or set ClosedAtUtc until the XP ceremony is complete.'
    );
    PRINT N'Inserted B1 Expedition 12 in Settlement status.';
END
ELSE
BEGIN
    PRINT N'B1 Expedition 12 already has a record; no existing version was changed.';
END;
GO

SELECT [RecordDate], [AdventureCode], [ExpeditionNumber], [Active],
       [ExpeditionStatus], [FinalDungeonTurn], [StartLocation],
       [EndLocation], [ClosedAtUtc]
FROM [dbo].[Expedition]
WHERE [AdventureCode] = N'B1' AND [ExpeditionNumber] = 12
ORDER BY [RecordDate] DESC;
GO
