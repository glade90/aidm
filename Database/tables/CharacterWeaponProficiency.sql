/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterWeaponProficiency.sql
Repository Path : Database/tables/CharacterWeaponProficiency.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Create a versioned narrative weapon-familiarity table.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Version         : 1.0.0
Created         : 2026-10-20
Last Modified   : 2026-10-20
Dependencies    : Character.sql; Weapons.sql
Source          : D&D Master Players' Book (1985), weapon mastery;
                  D&D Rules Cyclopedia (1991), Chapter 5; B1 party choices.

DESIGN NOTES
- Exact active Character and Weapon version dates are referenced by FKs.
- UseMode distinguishes Ralt's dagger-throwing versus melee experience.
- General use means unspecified (Pell dagger, Sho hand axe); it is not a bonus.
- NarrativeOnly is required by a CHECK; no proficiency ranks or modifiers.
- No drop or automatic migration of an existing table.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-20   1.0.0     Initial narrative-only weapon catalog and proficiencies.
===============================================================================
*/

USE [DnD];
GO
IF OBJECT_ID(N'characters.Character',N'U') IS NULL
    THROW 56420, 'Missing characters.Character; run Character.sql first.', 1;
IF OBJECT_ID(N'Rules.Weapons',N'U') IS NULL
    THROW 56421, 'Missing Rules.Weapons; run Weapons.sql first.', 1;
GO
IF OBJECT_ID(N'characters.CharacterWeaponProficiency',N'U') IS NULL
BEGIN
    CREATE TABLE [characters].[CharacterWeaponProficiency]
    (
        [RecordDate]             DATE           NOT NULL
            CONSTRAINT [DF_CharacterWeaponProficiency_RecordDate]
            DEFAULT (CONVERT(DATE,SYSUTCDATETIME())),
        [CharacterName]          NVARCHAR(60)   NOT NULL,
        [RulesetCode]            NVARCHAR(80)   NOT NULL,
        [WeaponCode]             NVARCHAR(80)   NOT NULL,
        [UseMode]                NVARCHAR(20)   NOT NULL,
        [Active]                 BIT            NOT NULL
            CONSTRAINT [DF_CharacterWeaponProficiency_Active] DEFAULT (1),
        [CharacterRecordDate]    DATE           NOT NULL,
        [WeaponRecordDate]       DATE           NOT NULL,
        [NarrativeOnly]          BIT            NOT NULL
            CONSTRAINT [DF_CharacterWeaponProficiency_NarrativeOnly] DEFAULT (1),
        [AcquisitionMethod]      NVARCHAR(40)   NOT NULL,
        [LearnedOn]              DATE           NULL,
        [NarrativeDescription]   NVARCHAR(500)  NOT NULL,
        [NotesMarkdown]         NVARCHAR(MAX)  NULL,
        CONSTRAINT [PK_CharacterWeaponProficiency]
            PRIMARY KEY CLUSTERED ([RecordDate],[CharacterName],[RulesetCode],
                                   [WeaponCode],[UseMode]),
        CONSTRAINT [FK_CharacterWeaponProficiency_Character]
            FOREIGN KEY ([CharacterRecordDate],[CharacterName])
            REFERENCES [characters].[Character] ([RecordDate],[CharacterName]),
        CONSTRAINT [FK_CharacterWeaponProficiency_Weapon]
            FOREIGN KEY ([WeaponRecordDate],[RulesetCode],[WeaponCode])
            REFERENCES [Rules].[Weapons] ([RecordDate],[RulesetCode],[WeaponCode]),
        CONSTRAINT [CK_CharacterWeaponProficiency_NarrativeOnly]
            CHECK ([NarrativeOnly] = 1),
        CONSTRAINT [CK_CharacterWeaponProficiency_UseMode]
            CHECK ([UseMode] IN (N'Melee',N'Thrown',N'Missile',N'General')),
        CONSTRAINT [CK_CharacterWeaponProficiency_AcquisitionMethod]
            CHECK ([AcquisitionMethod] IN
                (N'InitialNarrativeAssignment',N'BackgroundRevision',
                 N'EarnedInPlay',N'DMGranted'))
    );
    CREATE UNIQUE NONCLUSTERED INDEX [UX_CharacterWeaponProficiency_OneActive]
        ON [characters].[CharacterWeaponProficiency]
           ([CharacterName],[RulesetCode],[WeaponCode],[UseMode])
        WHERE [Active]=1;
    PRINT N'Created characters.CharacterWeaponProficiency: narrative-only.';
END
ELSE
BEGIN
    IF COL_LENGTH(N'characters.CharacterWeaponProficiency',N'RecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'CharacterName') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'RulesetCode') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'WeaponCode') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'UseMode') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'Active') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'CharacterRecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'WeaponRecordDate') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'NarrativeOnly') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'AcquisitionMethod') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'LearnedOn') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'NarrativeDescription') IS NULL
       OR COL_LENGTH(N'characters.CharacterWeaponProficiency',N'NotesMarkdown') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t
           ON c.user_type_id=t.user_type_id
           WHERE c.object_id=OBJECT_ID(N'characters.CharacterWeaponProficiency',N'U')
             AND c.name=N'RecordDate' AND t.name=N'date')
       OR NOT EXISTS (SELECT 1 FROM sys.foreign_keys f
           WHERE f.parent_object_id=OBJECT_ID(N'characters.CharacterWeaponProficiency',N'U')
           AND f.name=N'FK_CharacterWeaponProficiency_Character')
       OR NOT EXISTS (SELECT 1 FROM sys.foreign_keys f
           WHERE f.parent_object_id=OBJECT_ID(N'characters.CharacterWeaponProficiency',N'U')
           AND f.name=N'FK_CharacterWeaponProficiency_Weapon')
       OR NOT EXISTS (SELECT 1 FROM sys.indexes i
           WHERE i.object_id=OBJECT_ID(N'characters.CharacterWeaponProficiency',N'U')
             AND i.name=N'UX_CharacterWeaponProficiency_OneActive'
             AND i.is_unique=1 AND i.has_filter=1)
        THROW 56422, 'Incompatible characters.CharacterWeaponProficiency; review migration.', 1;
    PRINT N'Existing CharacterWeaponProficiency preserved; no changes made.';
END;
GO
