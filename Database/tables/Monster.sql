/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster.sql
Repository Path : Database/tables/Monster.sql
Project         : D&D - Quasqueton Character Collection / AIDM
Purpose         : Versioned ruleset-specific monster species/variant catalogue
                  for encounter setup, Combat Agent guidance and future mapping.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Table           : Rules.Monster
Version         : 0.3.0 (DRAFT - OWNER REVIEW)
Created         : 2026-11-21
Last Modified   : 2026-11-21
Dependencies    : Database/database/dnd.sql
                  Database/database/Rules.sql
Source          : 1983 Mentzer Basic rulebooks plus separately approved
                  campaign house-rule overlays (per individual record).

DESIGN NOTES
- This is a reusable SPECIES/VARIANT catalogue. An encounter passes its own
  group size, individual combatant IDs, initial/current HP, active conditions,
  source-labelled equipment and remaining effect durations separately.
- A variant (e.g. Orc chieftain) is its own MonsterCode; ParentMonsterCode is
  an optional reference to the parent species, not a live-state foreign key.
- RecordDate is UTC DATE, consistent with existing Rules.Spells/Weapons.
  PK = (RecordDate, RulesetCode, MonsterCode); each dated version is preserved.
  A filtered unique index permits at most one Active=1 version per monster
  within each ruleset. Only SourceStatus=Approved may be Active.
- GeneralDescription is prose for the DM's appearance/behaviour narration.
  SpecialAttacksFeatures is source-backed NATURAL LANGUAGE guidance including
  conditional modifiers, triggers, attack effects, saves, statuses and
  durations/expiry. It is NOT directly executable SQL or authoritative state.
  The LLM Combat Agent interprets it into typed proposals; deterministic
  rules/tools validate the proposal and perform rolls/state mutations.
- Printed stats are NULL until sourced; unknown is NOT zero. HitDiceText
  retains notation such as fractions or bonuses without lossy numeric casting.
- Artwork paths identify approved static assets; image bytes are NOT stored in
  SQL. An illustration and a later map icon are independent presentation assets.
- D1/D2 are the FULL diameters (major/minor axes) of a horizontal elliptical
  footprint, in feet; D1 >= D2. Z is approximate VERTICAL HEIGHT in feet.
  These are descriptive spatial metadata, NOT Mentzer combat footprints,
  collision, attack reach, grid occupancy, or blocking rules. SizeBasis
  distinguishes source-described lengths from explicitly estimated widths.
- AIDM owner modelling convention: all humans and humanoids have default
  circular D1=5 ft and D2=5 ft (2.5-ft radii), unless approved otherwise.
  This REPLACES the prior 5-ft-radius / 10-ft-diameter proposal. Orc Z=6 ft
  is a size estimate; the convention is not a published Mentzer mechanic.
- Existing Radius (v0.2) or SizeX/SizeY (v0.1) tables must be migrated by
  Database/tables/migrations/Monster_Diameter_Footprint_v0_3_0.sql before
  rerunning this CREATE script or the four-species seed.
- B1 stocked monster names only select which species to review; do not import
  B1 encounter quantities, instance HP or module secrets as monster rules.
- Initial create is NON-DESTRUCTIVE and contains NO monster inserts.
  Existing incompatible tables are never silently altered or dropped.

CHANGE LOG
Date         Version   Description
-----------  --------  ------------------------------------------------------
2026-11-21   0.1.0     Draft Rules.Monster schema for local owner review.
2026-11-21   0.2.0     Replace X/Y footprint dimensions with R1/R2 ellipse
                        radii; Z remains vertical height.
2026-11-21   0.3.0     Replace ellipse radii with D1/D2 FULL diameters,
                        with owner-defined 5-ft-diameter humanoid default.
===============================================================================
*/

USE [DnD];
GO

IF SCHEMA_ID(N'Rules') IS NULL
    THROW 56500, 'Missing Rules schema. Run Database/database/Rules.sql first.', 1;
GO

IF OBJECT_ID(N'Rules.Monster', N'U') IS NULL
BEGIN
    CREATE TABLE [Rules].[Monster]
    (
        -- Stable identity and immutable dated versions.
        [RecordDate]              DATE           NOT NULL
            CONSTRAINT [DF_Monster_RecordDate]
                DEFAULT (CONVERT(DATE, SYSUTCDATETIME())),
        [RulesetCode]             NVARCHAR(80)   NOT NULL,
        [MonsterCode]             NVARCHAR(80)   NOT NULL,
        [Active]                  BIT            NOT NULL
            CONSTRAINT [DF_Monster_Active] DEFAULT (0),
        [MonsterName]             NVARCHAR(120)  NOT NULL,
        [ParentMonsterCode]       NVARCHAR(80)   NULL,

        -- Rules provenance / approval; base rules are not conflated with overlays.
        [SourceStatus]            NVARCHAR(20)   NOT NULL
            CONSTRAINT [DF_Monster_SourceStatus] DEFAULT (N'Draft'),
        [SourceReference]         NVARCHAR(400)  NOT NULL,
        [HouseRuleOverlayRefs]    NVARCHAR(MAX)  NULL,

        -- Species/variant reference statistics; NOT encounter-instance state.
        [ArmorClass]              SMALLINT       NULL,
        [HitDiceText]             NVARCHAR(40)   NULL,
        [AttackPattern]           NVARCHAR(200)  NULL,
        [DamagePattern]           NVARCHAR(200)  NULL,
        [SaveAs]                  NVARCHAR(100)  NULL,
        [Morale]                  TINYINT        NULL,
        [MovementTurnFeet]       DECIMAL(9,2)   NULL,
        [MovementRoundFeet]      DECIMAL(9,2)   NULL,
        [MovementSpecialText]    NVARCHAR(200)  NULL,
        [Alignment]               NVARCHAR(40)   NULL,
        [XPValue]                 INT            NULL,
        [NumberAppearingText]     NVARCHAR(100)  NULL,
        [TreasureType]            NVARCHAR(100)  NULL,

        -- Separate DM narration and Combat Agent rule interpretation inputs.
        [GeneralDescription]     NVARCHAR(MAX)  NOT NULL,
        [SpecialAttacksFeatures] NVARCHAR(MAX)  NOT NULL,

        -- Optional future Geometry: horizontal oval FULL diameters D1/D2 and height Z (feet).
        [D1Feet]               DECIMAL(9,2)   NULL,
        [D2Feet]               DECIMAL(9,2)   NULL,
        [ZFeet]               DECIMAL(9,2)   NULL,
        [SizeBasis]               NVARCHAR(200)  NULL,

        -- Paths to approved original static assets (not file bytes).
        [IllustrationPath]        NVARCHAR(500)  NULL,
        [MapIconPath]             NVARCHAR(500)  NULL,
        [NotesMarkdown]           NVARCHAR(MAX)  NULL,

        CONSTRAINT [PK_Monster]
            PRIMARY KEY CLUSTERED
                ([RecordDate], [RulesetCode], [MonsterCode]),
        CONSTRAINT [CK_Monster_SourceStatus]
            CHECK ([SourceStatus] IN
                (N'Draft', N'SourceChecked', N'Approved', N'Superseded')),
        CONSTRAINT [CK_Monster_OnlyApprovedActive]
            CHECK ([Active] = 0 OR [SourceStatus] = N'Approved'),
        CONSTRAINT [CK_Monster_Morale]
            CHECK ([Morale] IS NULL OR [Morale] BETWEEN 2 AND 12),
        CONSTRAINT [CK_Monster_Movement]
            CHECK (([MovementTurnFeet] IS NULL OR [MovementTurnFeet] >= 0)
               AND ([MovementRoundFeet] IS NULL OR [MovementRoundFeet] >= 0)),
        CONSTRAINT [CK_Monster_XP]
            CHECK ([XPValue] IS NULL OR [XPValue] >= 0),
        CONSTRAINT [CK_Monster_Dimensions]
            CHECK (([D1Feet] IS NULL OR [D1Feet] > 0)
               AND ([D2Feet] IS NULL OR [D2Feet] > 0)
               AND ([ZFeet] IS NULL OR [ZFeet] > 0)
               AND ([D1Feet] IS NULL OR [D2Feet] IS NULL
                    OR [D1Feet] >= [D2Feet]))
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_Monster_OneActiveVersion]
        ON [Rules].[Monster] ([RulesetCode], [MonsterCode])
        WHERE [Active] = 1;

    PRINT N'Created Rules.Monster (draft schema, zero rows inserted).';
END
ELSE
BEGIN
    -- Creation script, not a migration. Reject a partially compatible table.
    IF EXISTS
    (
        SELECT 1
        FROM (VALUES
            (N'RecordDate'), (N'RulesetCode'), (N'MonsterCode'), (N'Active'),
            (N'MonsterName'), (N'ParentMonsterCode'), (N'SourceStatus'),
            (N'SourceReference'), (N'HouseRuleOverlayRefs'), (N'ArmorClass'),
            (N'HitDiceText'), (N'AttackPattern'), (N'DamagePattern'),
            (N'SaveAs'), (N'Morale'), (N'MovementTurnFeet'),
            (N'MovementRoundFeet'), (N'MovementSpecialText'), (N'Alignment'),
            (N'XPValue'), (N'NumberAppearingText'), (N'TreasureType'),
            (N'GeneralDescription'), (N'SpecialAttacksFeatures'),
            (N'SizeXFeet'), (N'SizeYFeet'), (N'SizeZFeet'), (N'SizeBasis'),
            (N'IllustrationPath'), (N'MapIconPath'), (N'NotesMarkdown')
        ) AS required([ColumnName])
        WHERE COL_LENGTH(N'Rules.Monster', required.[ColumnName]) IS NULL
    )
       OR NOT EXISTS
       (
           SELECT 1
           FROM sys.columns AS c
           JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID(N'Rules.Monster', N'U')
             AND c.name = N'RecordDate' AND ty.name = N'date'
       )
       OR NOT EXISTS
       (
           SELECT 1
           FROM sys.key_constraints AS pk
           JOIN sys.index_columns AS i1
             ON i1.object_id = pk.parent_object_id
            AND i1.index_id = pk.unique_index_id AND i1.key_ordinal = 1
           JOIN sys.columns AS c1
             ON c1.object_id = i1.object_id AND c1.column_id = i1.column_id
           JOIN sys.index_columns AS i2
             ON i2.object_id = pk.parent_object_id
            AND i2.index_id = pk.unique_index_id AND i2.key_ordinal = 2
           JOIN sys.columns AS c2
             ON c2.object_id = i2.object_id AND c2.column_id = i2.column_id
           JOIN sys.index_columns AS i3
             ON i3.object_id = pk.parent_object_id
            AND i3.index_id = pk.unique_index_id AND i3.key_ordinal = 3
           JOIN sys.columns AS c3
             ON c3.object_id = i3.object_id AND c3.column_id = i3.column_id
           WHERE pk.parent_object_id = OBJECT_ID(N'Rules.Monster', N'U')
             AND pk.type = N'PK'
             AND c1.name = N'RecordDate'
             AND c2.name = N'RulesetCode'
             AND c3.name = N'MonsterCode'
       )
       OR NOT EXISTS
       (
           SELECT 1
           FROM sys.indexes AS i
           WHERE i.object_id = OBJECT_ID(N'Rules.Monster', N'U')
             AND i.name = N'UX_Monster_OneActiveVersion'
             AND i.is_unique = 1 AND i.has_filter = 1
       )
    BEGIN
        THROW 56501,
            'Incompatible Rules.Monster exists. If still using X/Y/Z or R1/R2/Z, run Monster_Diameter_Footprint_v0_3_0.sql first.', 1;
    END;

    PRINT N'Rules.Monster already exists; no data or schema changed.';
END;
GO

-- Read-only verification. No seed records are inserted by this script.
SELECT [RulesetCode], [MonsterCode], [MonsterName], [RecordDate],
       [Active], [SourceStatus], [ArmorClass], [HitDiceText]
FROM [Rules].[Monster]
ORDER BY [RulesetCode], [MonsterCode], [RecordDate] DESC;
GO
