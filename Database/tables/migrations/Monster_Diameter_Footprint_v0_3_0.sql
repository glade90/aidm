/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Diameter_Footprint_v0_3_0.sql
Repository Path : Database/tables/migrations/Monster_Diameter_Footprint_v0_3_0.sql
Project         : AIDM / PEQUOD DnD
Purpose         : Convert older monster shape fields to elliptical FULL diameters
                  D1Feet/D2Feet plus vertical height ZFeet, preserving records.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Table           : Rules.Monster
Version         : 0.3.0 (OWNER REVIEW)
Created         : 2026-11-21
Dependencies    : Existing Rules.Monster v0.1 or v0.2; for fresh databases
                  use updated Database/tables/Monster.sql v0.3 instead.

DESIGN NOTES
- D1Feet is the LONGER horizontal ellipse diameter and D2Feet the SHORTER
  horizontal diameter (feet); ZFeet is approximate creature HEIGHT.
- Owner now specifies 5-foot DIAMETER circular default for humans/humanoids;
  this supersedes prior 5-foot RADIUS / 10-foot diameter convention.
- Source-described lengths: ~1 ft Giant Centipede, ~9 ft Carrion Crawler,
  ~5 ft Giant Crab Spider; source gives Crawler height ~3 ft.
  Other widths/heights and Orc height are explicitly AIDM estimates.
- Supports both prior database shapes in ONE migration:
   * v0.1 SizeXFeet/SizeYFeet/SizeZFeet were full extents: rename only.
   * v0.2 R1Feet/R2Feet/ZFeet were radii: rename and DOUBLE both radii.
   * v0.3 D1Feet/D2Feet/ZFeet: no geometry column/value changes.
- The radius-to-diameter conversion preserves physical sizes for arbitrary
  existing records. It does not silently replace other user-approved geometry.
- ONLY the four original INACTIVE SourceChecked rows matching the previous
  untouched seed's SizeBasis are assigned the revised owner-approved/default
  draft dimensions below. Custom and Approved rows are left intact.
- Non-destructive, rerunnable, does NOT add new species or execute a seed.
- DO NOT run the older Monster_Ellipse_Footprint_v0_2_0.sql when upgrading
  directly to v0.3. This one migration covers both old forms.
- A preexisting reversed major/minor shape may fail the CHECK: transaction
  rolls back; manual data review is then required, not silent dimensional loss.

CHANGE LOG
2026-11-21  0.3.0  Convert monster footprints to D1/D2 FULL diameters.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'Rules.Monster', N'U') IS NULL
    THROW 56530, 'Rules.Monster does not yet exist. Run Monster.sql v0.3.0, then four-species seed; skip migration.', 1;
GO

SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRAN;

    IF COL_LENGTH(N'Rules.Monster', N'SizeXFeet') IS NOT NULL
       AND COL_LENGTH(N'Rules.Monster', N'SizeYFeet') IS NOT NULL
       AND COL_LENGTH(N'Rules.Monster', N'SizeZFeet') IS NOT NULL
       AND COL_LENGTH(N'Rules.Monster', N'R1Feet') IS NULL
       AND COL_LENGTH(N'Rules.Monster', N'R2Feet') IS NULL
       AND COL_LENGTH(N'Rules.Monster', N'D1Feet') IS NULL
       AND COL_LENGTH(N'Rules.Monster', N'D2Feet') IS NULL
       AND COL_LENGTH(N'Rules.Monster', N'ZFeet') IS NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1 FROM sys.check_constraints
            WHERE parent_object_id = OBJECT_ID(N'Rules.Monster', N'U')
              AND name = N'CK_Monster_Dimensions'
        )
            ALTER TABLE [Rules].[Monster]
                DROP CONSTRAINT [CK_Monster_Dimensions];

        -- v0.1 X/Y were complete extents, not radii. Do not rescale.
        EXEC sys.sp_rename N'Rules.Monster.SizeXFeet', N'D1Feet', N'COLUMN';
        EXEC sys.sp_rename N'Rules.Monster.SizeYFeet', N'D2Feet', N'COLUMN';
        EXEC sys.sp_rename N'Rules.Monster.SizeZFeet', N'ZFeet', N'COLUMN';
        PRINT N'Converted v0.1 X/Y/Z full extents to D1/D2/Z.';
    END
    ELSE IF COL_LENGTH(N'Rules.Monster', N'R1Feet') IS NOT NULL
        AND COL_LENGTH(N'Rules.Monster', N'R2Feet') IS NOT NULL
        AND COL_LENGTH(N'Rules.Monster', N'ZFeet') IS NOT NULL
        AND COL_LENGTH(N'Rules.Monster', N'SizeXFeet') IS NULL
        AND COL_LENGTH(N'Rules.Monster', N'SizeYFeet') IS NULL
        AND COL_LENGTH(N'Rules.Monster', N'D1Feet') IS NULL
        AND COL_LENGTH(N'Rules.Monster', N'D2Feet') IS NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1 FROM sys.check_constraints
            WHERE parent_object_id = OBJECT_ID(N'Rules.Monster', N'U')
              AND name = N'CK_Monster_Dimensions'
        )
            ALTER TABLE [Rules].[Monster]
                DROP CONSTRAINT [CK_Monster_Dimensions];

        EXEC sys.sp_rename N'Rules.Monster.R1Feet', N'D1Feet', N'COLUMN';
        EXEC sys.sp_rename N'Rules.Monster.R2Feet', N'D2Feet', N'COLUMN';

        -- v0.2 stored RADIUS, so multiply by 2 to preserve overall extent.
        -- Run in dynamic SQL to compile against the renamed columns.
        EXEC sys.sp_executesql N'
            UPDATE [Rules].[Monster]
               SET [D1Feet] = [D1Feet] * CONVERT(DECIMAL(9,2), 2.00),
                   [D2Feet] = [D2Feet] * CONVERT(DECIMAL(9,2), 2.00);';

        PRINT N'Converted v0.2 R1/R2 radii to D1/D2 full diameters.';
    END
    ELSE IF COL_LENGTH(N'Rules.Monster', N'D1Feet') IS NOT NULL
        AND COL_LENGTH(N'Rules.Monster', N'D2Feet') IS NOT NULL
        AND COL_LENGTH(N'Rules.Monster', N'ZFeet') IS NOT NULL
        AND COL_LENGTH(N'Rules.Monster', N'R1Feet') IS NULL
        AND COL_LENGTH(N'Rules.Monster', N'R2Feet') IS NULL
        AND COL_LENGTH(N'Rules.Monster', N'SizeXFeet') IS NULL
        AND COL_LENGTH(N'Rules.Monster', N'SizeYFeet') IS NULL
        AND COL_LENGTH(N'Rules.Monster', N'SizeZFeet') IS NULL
    BEGIN
        PRINT N'Rules.Monster v0.3 diameter columns already present.';
    END
    ELSE
        THROW 56531, 'Mixed or unsupported Monster geometry columns. Stop and review without dropping data.', 1;

    -- Reassert the FULL-diameter, longer-first semantic constraints.
    IF NOT EXISTS
    (
        SELECT 1 FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'Rules.Monster', N'U')
          AND name = N'CK_Monster_Dimensions'
    )
        EXEC sys.sp_executesql N'
            ALTER TABLE [Rules].[Monster] WITH CHECK
            ADD CONSTRAINT [CK_Monster_Dimensions] CHECK
            (
                ([D1Feet] IS NULL OR [D1Feet] > 0)
                AND ([D2Feet] IS NULL OR [D2Feet] > 0)
                AND ([ZFeet] IS NULL OR [ZFeet] > 0)
                AND ([D1Feet] IS NULL OR [D2Feet] IS NULL
                     OR [D1Feet] >= [D2Feet])
            );';

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- A separate batch follows rename to permit SQL Server to bind D1/D2 at
-- compilation time. Only untouched, inactive, pre-v0.3 seed rows are updated.
BEGIN TRY
    BEGIN TRAN;

    DECLARE @DraftShapes TABLE
    (
        [MonsterCode] NVARCHAR(80) NOT NULL PRIMARY KEY,
        [D1Feet] DECIMAL(9,2) NOT NULL,
        [D2Feet] DECIMAL(9,2) NOT NULL,
        [ZFeet] DECIMAL(9,2) NOT NULL,
        [OldBasisV01] NVARCHAR(200) NULL,
        [OldBasisV02] NVARCHAR(200) NOT NULL,
        [NewBasisV03] NVARCHAR(200) NOT NULL
    );

    INSERT INTO @DraftShapes
    ([MonsterCode], [D1Feet], [D2Feet], [ZFeet],
     [OldBasisV01], [OldBasisV02], [NewBasisV03])
    VALUES
    (N'ORC', 5.00, 5.00, 6.00,
     NULL,
     N'Owner AIDM humanoid convention: R1=R2=5ft (10ft diameter); Z=6ft is approximate standing height, not a Mentzer rule.',
     N'Owner AIDM humanoid default: circular D1=D2=5ft diameter; Z=6ft is estimated standing height, not a Mentzer mechanic.'),
    (N'GIANT_CENTIPEDE', 1.00, 0.30, 0.20,
     N'Approx. one foot body length from Mentzer descriptive text; Y and Z not sourced.',
     N'Mentzer approx. 1ft body length -> R1=0.5ft; R2=0.15ft and Z=0.2ft estimated for future geometry.',
     N'Mentzer approx. 1ft body length -> D1=1ft; D2=0.3ft width and Z=0.2ft height are AIDM estimates.'),
    (N'CARRION_CRAWLER', 9.00, 3.00, 3.00,
     N'Approximate length 9 ft and height 3 ft in Mentzer description; width Y not specified; not collision dimensions.',
     N'Mentzer approx. 9ft length and 3ft height -> R1=4.5ft, Z=3ft; R2=1.5ft estimated width.',
     N'Mentzer approx. 9ft length and 3ft height -> D1=9ft, Z=3ft; D2=3ft width is an AIDM estimate.'),
    (N'GIANT_CRAB_SPIDER', 5.00, 4.00, 2.00,
     N'Approximate five-foot body length from Mentzer description; width and height not specified.',
     N'Mentzer approx. 5ft body length -> R1=2.5ft; R2=2ft and Z=2ft estimated for leg span/height.',
     N'Mentzer approx. 5ft body length -> D1=5ft; D2=4ft width and Z=2ft height are AIDM estimates.');

    UPDATE m
       SET [D1Feet] = d.[D1Feet],
           [D2Feet] = d.[D2Feet],
           [ZFeet] = d.[ZFeet],
           [SizeBasis] = d.[NewBasisV03]
    FROM [Rules].[Monster] AS m
    INNER JOIN @DraftShapes AS d ON d.[MonsterCode] = m.[MonsterCode]
    WHERE m.[RulesetCode] = N'MentzerBECMI'
      AND m.[SourceStatus] = N'SourceChecked'
      AND m.[Active] = 0
      AND
      (
            (d.[OldBasisV01] IS NULL AND m.[SizeBasis] IS NULL)
            OR m.[SizeBasis] = d.[OldBasisV01]
            OR m.[SizeBasis] = d.[OldBasisV02]
      );

    DECLARE @UpdatedDrafts INT = @@ROWCOUNT;
    COMMIT;
    PRINT CONCAT(N'Converted ', @UpdatedDrafts,
                 N' matching inactive draft species to diameter convention.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SELECT [RulesetCode], [MonsterCode], [RecordDate], [Active], [SourceStatus],
       [D1Feet], [D2Feet], [ZFeet], [SizeBasis]
FROM [Rules].[Monster]
WHERE [RulesetCode] = N'MentzerBECMI'
ORDER BY [MonsterCode], [RecordDate] DESC;
GO
