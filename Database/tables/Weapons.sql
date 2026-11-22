/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Weapons.sql
Repository Path : Database/tables/Weapons.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Create versioned narrative-only reference weapon catalog.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Version         : 1.0.0
Created         : 2026-10-20
Last Modified   : 2026-10-20
Dependencies    : Rules.sql
Source          : D&D Master Players' Book (1985), weapon mastery;
                  D&D Rules Cyclopedia (1991), Chapter 5; B1 party choices.

DESIGN NOTES
- Weapon names reference later BECMI/Rules Cyclopedia mastery index.
- POLEARM_GENERAL and FLAIL_GENERAL are explicit campaign descriptors.
- No weapon mastery rules, bonuses or training-slot limits are enabled.
- Existing records never dropped, silently migrated, or overwritten.
- RecordDate DATE, Active BIT, composite PK, filtered one-active index.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-20   1.0.0     Initial narrative-only weapon catalog and proficiencies.
===============================================================================
*/

USE [DnD];
GO
IF SCHEMA_ID(N'Rules') IS NULL
    THROW 56400, 'Missing Rules schema; run Rules.sql first.', 1;
GO
IF OBJECT_ID(N'Rules.Weapons', N'U') IS NULL
BEGIN
    CREATE TABLE [Rules].[Weapons]
    (
        [RecordDate]           DATE           NOT NULL
            CONSTRAINT [DF_Weapons_RecordDate] DEFAULT (CONVERT(DATE,SYSUTCDATETIME())),
        [RulesetCode]          NVARCHAR(80)   NOT NULL,
        [WeaponCode]           NVARCHAR(80)   NOT NULL,
        [Active]               BIT            NOT NULL
            CONSTRAINT [DF_Weapons_Active] DEFAULT (1),
        [WeaponName]           NVARCHAR(120)  NOT NULL,
        [WeaponFamily]         NVARCHAR(60)   NOT NULL,
        [PrimaryUse]           NVARCHAR(30)   NOT NULL,
        [CatalogCode]          NVARCHAR(80)   NOT NULL,
        [SourceStatus]         NVARCHAR(30)   NOT NULL,
        [NarrativeDescription] NVARCHAR(600)  NOT NULL,
        [NarrativeOnly]        BIT            NOT NULL
            CONSTRAINT [DF_Weapons_NarrativeOnly] DEFAULT (1),
        [SourceReference]      NVARCHAR(300)  NOT NULL,
        [NotesMarkdown]       NVARCHAR(MAX)  NULL,
        CONSTRAINT [PK_Weapons] PRIMARY KEY CLUSTERED
            ([RecordDate],[RulesetCode],[WeaponCode]),
        CONSTRAINT [CK_Weapons_PrimaryUse] CHECK
            ([PrimaryUse] IN (N'Melee',N'Missile',N'Thrown',N'MeleeAndThrown',N'Unarmed')),
        CONSTRAINT [CK_Weapons_SourceStatus] CHECK
            ([SourceStatus] IN (N'OfficialRC1991',N'CampaignDescriptor')),
        CONSTRAINT [CK_Weapons_NarrativeOnly] CHECK ([NarrativeOnly]=1)
    );
    CREATE UNIQUE NONCLUSTERED INDEX [UX_Weapons_OneActive]
        ON [Rules].[Weapons] ([RulesetCode],[WeaponCode]) WHERE [Active]=1;
    PRINT N'Created Rules.Weapons: narrative catalog only.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'Rules.Weapons',N'RecordDate') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'RulesetCode') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'WeaponCode') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'Active') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'WeaponName') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'WeaponFamily') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'PrimaryUse') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'CatalogCode') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'SourceStatus') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'NarrativeDescription') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'NarrativeOnly') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'SourceReference') IS NULL
       OR COL_LENGTH(N'Rules.Weapons',N'NotesMarkdown') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t
           ON c.user_type_id=t.user_type_id
           WHERE c.object_id=OBJECT_ID(N'Rules.Weapons',N'U')
           AND c.name=N'RecordDate' AND t.name=N'date')
       OR NOT EXISTS (SELECT 1 FROM sys.indexes i
           WHERE i.object_id=OBJECT_ID(N'Rules.Weapons',N'U')
           AND i.name=N'UX_Weapons_OneActive' AND i.is_unique=1 AND i.has_filter=1)
        THROW 56401, 'Incompatible Rules.Weapons exists; review a data-preserving migration.', 1;
    PRINT N'Rules.Weapons already exists; no changes made.';
END;
GO
