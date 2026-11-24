/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterExpedition.sql
Repository Path : Database/tables/CharacterExpedition.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Record each character's participation in a specific outing,
                  including HP changes, XP/treasure settlement and notes.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterExpedition
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/tables/Expedition.sql
                  Database/tables/CharacterAdventure.sql

DESIGN NOTES
- One participation row per character/adventure/expedition, versioned by UTC
  RecordDate DATE. Each old version remains as history with Active=0.
- PK: (RecordDate, CharacterName, AdventureCode, ExpeditionNumber).
- Unique filtered index: at most one active version of a participation record.
- ExpeditionRecordDate identifies the exact version of dbo.Expedition.
- CharacterAdventureRecordDate identifies the exact version of the character's
  adventure membership, which in turn references a version of Character.
- Image path remains on CharacterAdventure, NOT in CharacterExpedition.
- StartHP / EndHP record actual HP at departure/return, not new maxima;
  maximum HP by level belongs in the future CharacterLevel table.
- NULL means unknown/not settled; do not enter 0 for missing XP or treasure.
- XP fields are award accounting, not the character's cumulative level XP.
  The values may be populated when the expedition settlement is completed.
- Monetary shares use copper-piece units as integers; equipment and non-coin
  loot are described separately, not silently given fictional cash values.
- AdventureParticipationRole can change between outings even if the original
  CharacterAdventure role does not.
- NotesMarkdown is player-safe narrative/history.
- This CREATE script does not modify or migrate an existing table.

CHANGE LOG
Date         Version   Description
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     First versioned character-expedition record with
                        individual HP, XP, treasury share and notes.
===============================================================================
*/

USE [DnD];
GO

IF SCHEMA_ID(N'characters') IS NULL
    THROW 51600, 'Missing characters schema.', 1;
IF OBJECT_ID(N'characters.CharacterAdventure', N'U') IS NULL
    THROW 51601, 'Missing characters.CharacterAdventure. Run its CREATE script first.', 1;
IF OBJECT_ID(N'dbo.Expedition', N'U') IS NULL
    THROW 51602, 'Missing dbo.Expedition. Run Expedition.sql first.', 1;
GO

IF OBJECT_ID(N'characters.CharacterExpedition', N'U') IS NULL
BEGIN
    CREATE TABLE [characters].[CharacterExpedition]
    (
        [RecordDate]                  DATE           NOT NULL
            CONSTRAINT [DF_CharacterExpedition_RecordDate]
                DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [CharacterName]               NVARCHAR(60)   NOT NULL,
        [AdventureCode]               NVARCHAR(100)  NOT NULL,
        [ExpeditionNumber]            INT            NOT NULL,
        [Active]                      BIT            NOT NULL
            CONSTRAINT [DF_CharacterExpedition_Active] DEFAULT (1),
        [CharacterAdventureRecordDate] DATE          NOT NULL,
        [ExpeditionRecordDate]        DATE           NOT NULL,
        [ParticipationRole]           NVARCHAR(40)   NULL,
        [ParticipationStatus]         NVARCHAR(20)   NOT NULL
            CONSTRAINT [DF_CharacterExpedition_Status] DEFAULT (N'Joined'),
        [StartHP]                     SMALLINT       NULL,
        [EndHP]                       SMALLINT       NULL,
        [StartXP]                     INT            NULL,
        [MonsterXP]                   INT            NULL,
        [TreasureXP]                  INT            NULL,
        [OtherXP]                     INT            NULL,
        [PrimeRequisiteBonusXP]       INT            NULL,
        [EndXP]                       INT            NULL,
        [TreasureShareCopper]         BIGINT         NULL,
        [NotesMarkdown]               NVARCHAR(MAX)  NULL,

        CONSTRAINT [PK_CharacterExpedition]
            PRIMARY KEY CLUSTERED
                ([RecordDate], [CharacterName], [AdventureCode],
                 [ExpeditionNumber]),
        CONSTRAINT [FK_CharacterExpedition_Expedition]
            FOREIGN KEY ([ExpeditionRecordDate], [AdventureCode],
                         [ExpeditionNumber])
            REFERENCES [dbo].[Expedition]
                ([RecordDate], [AdventureCode], [ExpeditionNumber]),
        CONSTRAINT [FK_CharacterExpedition_CharacterAdventure]
            FOREIGN KEY ([CharacterAdventureRecordDate], [CharacterName],
                         [AdventureCode])
            REFERENCES [characters].[CharacterAdventure]
                ([RecordDate], [CharacterName], [AdventureCode]),
        CONSTRAINT [CK_CharacterExpedition_Number]
            CHECK ([ExpeditionNumber] >= 1),
        CONSTRAINT [CK_CharacterExpedition_Status]
            CHECK ([ParticipationStatus] IN
                (N'Joined', N'Returned', N'Died', N'Withdrew', N'Missing')),
        CONSTRAINT [CK_CharacterExpedition_HP]
            CHECK (([StartHP] IS NULL OR [StartHP] >= 0)
               AND ([EndHP] IS NULL OR [EndHP] >= 0)),
        CONSTRAINT [CK_CharacterExpedition_XP]
            CHECK (([StartXP] IS NULL OR [StartXP] >= 0)
               AND ([MonsterXP] IS NULL OR [MonsterXP] >= 0)
               AND ([TreasureXP] IS NULL OR [TreasureXP] >= 0)
               AND ([OtherXP] IS NULL OR [OtherXP] >= 0)
               AND ([PrimeRequisiteBonusXP] IS NULL OR [PrimeRequisiteBonusXP] >= 0)
               AND ([EndXP] IS NULL OR [EndXP] >= 0)),
        CONSTRAINT [CK_CharacterExpedition_Treasure]
            CHECK ([TreasureShareCopper] IS NULL OR [TreasureShareCopper] >= 0)
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_CharacterExpedition_OneActiveVersion]
        ON [characters].[CharacterExpedition]
            ([CharacterName], [AdventureCode], [ExpeditionNumber])
        WHERE [Active] = 1;

    PRINT N'Created characters.CharacterExpedition.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'characters.CharacterExpedition', N'RecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterExpedition', N'CharacterName') IS NULL
       OR COL_LENGTH(N'characters.CharacterExpedition', N'AdventureCode') IS NULL
       OR COL_LENGTH(N'characters.CharacterExpedition', N'ExpeditionNumber') IS NULL
       OR COL_LENGTH(N'characters.CharacterExpedition', N'Active') IS NULL
       OR COL_LENGTH(N'characters.CharacterExpedition', N'ExpeditionRecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterExpedition', N'CharacterAdventureRecordDate') IS NULL
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.columns AS c
           JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID(N'characters.CharacterExpedition', N'U')
             AND c.[name] = N'RecordDate' AND ty.[name] = N'date'
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.indexes AS ix
           WHERE ix.object_id = OBJECT_ID(N'characters.CharacterExpedition', N'U')
             AND ix.[name] = N'UX_CharacterExpedition_OneActiveVersion'
             AND ix.is_unique = 1 AND ix.has_filter = 1
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.foreign_keys AS fk
           WHERE fk.parent_object_id = OBJECT_ID(N'characters.CharacterExpedition', N'U')
             AND fk.[name] = N'FK_CharacterExpedition_Expedition'
             AND fk.referenced_object_id = OBJECT_ID(N'dbo.Expedition', N'U')
       )
       OR NOT EXISTS
       (
           SELECT 1 FROM sys.foreign_keys AS fk
           WHERE fk.parent_object_id = OBJECT_ID(N'characters.CharacterExpedition', N'U')
             AND fk.[name] = N'FK_CharacterExpedition_CharacterAdventure'
             AND fk.referenced_object_id = OBJECT_ID(N'characters.CharacterAdventure', N'U')
       )
    BEGIN
        THROW 51603,
              'An incompatible CharacterExpedition table exists. Review a data-preserving migration.', 1;
    END;
    PRINT N'CharacterExpedition already exists; no data or schema changed.';
END;
GO

-- Read-only verification.
SELECT [RecordDate], [CharacterName], [AdventureCode], [ExpeditionNumber],
       [Active], [ParticipationRole], [ParticipationStatus], [StartHP], [EndHP],
       [StartXP], [EndXP], [TreasureShareCopper]
FROM [characters].[CharacterExpedition]
ORDER BY [CharacterName], [AdventureCode], [ExpeditionNumber], [RecordDate] DESC;
GO
