/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Ellipse_Footprint_v0_2_0.sql
Repository Path : Database/tables/migrations/Monster_Ellipse_Footprint_v0_2_0.sql
Project         : AIDM / PEQUOD DnD
Purpose         : Preserve an existing Rules.Monster table while changing its
                  physical footprint from X/Y full lengths to R1/R2 radii and
                  Z height, then align the four original inactive draft seeds.
Target Server   : PEQUOD (SQL Server)
Database        : DnD
Schema          : Rules
Table           : Rules.Monster
Version         : 0.2.0
Created         : 2026-11-21
Dependencies    : Database/tables/Monster.sql v0.1.0 OR v0.2.0.
Source          : Mentzer Basic 1983 monster prose pp.27, 28, 35, 37.
                  Horizontal widths and unspecified heights are AIDM estimates.

DESIGN NOTES
- RUN THIS SCRIPT if Rules.Monster v0.1.0 already exists on PEQUOD.
  For a fresh database, run the new v0.2.0 Monster.sql and then the
  four-species seed; THIS MIGRATION IS NOT NEEDED.
- R1 = longer horizontal semi-axis RADIUS; R2 = shorter horizontal semi-axis
  RADIUS; Z = approximate vertical HEIGHT. Feet; major radius >= minor radius.
- For all humans/humanoids the OWNER default footprint is R1=R2=5 ft
  (diameter=10 ft), irrespective of species; this is not a Mentzer rule.
- Renaming SizeXFeet/SizeYFeet/SizeZFeet is accompanied by division by TWO
  of the old X/Y length values. Z is unchanged. This preserves equivalent
  physical extents on arbitrary previously entered records.
- Then amend ONLY the four original INACTIVE SourceChecked draft species
  rows whose SizeBasis matches the old seed. If an owner has edited SizeBasis,
  or approved/activated the row, do NOT overwrite its custom measurements.
- Historic approved values are never replaced by new speculative defaults.
  This script never drops Rules.Monster, its records, PK or active-version index.
- Safe to rerun. It does not populate any missing monster records; run the
  updated four-species seed for a fresh database.

CHANGE LOG
2026-11-21  0.2.0  Convert rectangular footprint to elliptical semiaxes.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'Rules.Monster', N'U') IS NULL
    THROW 56520, 'Rules.Monster does not exist: run Monster.sql v0.2.0 instead.', 1;
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

        EXEC sys.sp_rename N'Rules.Monster.SizeXFeet', N'R1Feet', N'COLUMN';
        EXEC sys.sp_rename N'Rules.Monster.SizeYFeet', N'R2Feet', N'COLUMN';
        EXEC sys.sp_rename N'Rules.Monster.SizeZFeet', N'ZFeet', N'COLUMN';

        -- Existing X/Y fields were FULL lengths; new fields are semi-axis radii.
        EXEC sys.sp_executesql N'
            UPDATE [Rules].[Monster]
               SET [R1Feet] = [R1Feet] / CONVERT(DECIMAL(9,2), 2.0),
                   [R2Feet] = [R2Feet] / CONVERT(DECIMAL(9,2), 2.0);';

        EXEC sys.sp_executesql N'
            ALTER TABLE [Rules].[Monster] WITH CHECK
            ADD CONSTRAINT [CK_Monster_Dimensions] CHECK
            (
                ([R1Feet] IS NULL OR [R1Feet] > 0)
                AND ([R2Feet] IS NULL OR [R2Feet] > 0)
                AND ([ZFeet] IS NULL OR [ZFeet] > 0)
                AND ([R1Feet] IS NULL OR [R2Feet] IS NULL
                     OR [R1Feet] >= [R2Feet])
            );';

        PRINT N'Converted existing Rules.Monster X/Y lengths to R1/R2 radii; Z retained.';
    END
    ELSE IF COL_LENGTH(N'Rules.Monster', N'R1Feet') IS NOT NULL
        AND COL_LENGTH(N'Rules.Monster', N'R2Feet') IS NOT NULL
        AND COL_LENGTH(N'Rules.Monster', N'ZFeet') IS NOT NULL
        AND COL_LENGTH(N'Rules.Monster', N'SizeXFeet') IS NULL
        AND COL_LENGTH(N'Rules.Monster', N'SizeYFeet') IS NULL
        AND COL_LENGTH(N'Rules.Monster', N'SizeZFeet') IS NULL
    BEGIN
        -- Already migrated (or freshly created from the current Monster.sql).
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
                    ([R1Feet] IS NULL OR [R1Feet] > 0)
                    AND ([R2Feet] IS NULL OR [R2Feet] > 0)
                    AND ([ZFeet] IS NULL OR [ZFeet] > 0)
                    AND ([R1Feet] IS NULL OR [R2Feet] IS NULL
                         OR [R1Feet] >= [R2Feet])
                );';

        PRINT N'Rules.Monster ellipse columns already present.';
    END
    ELSE
        THROW 56521, 'Unexpected or mixed Rules.Monster geometry columns; review manually without dropping data.', 1;

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- A separate transaction updates ONLY original, unapproved draft seed rows.
-- A changed/customised SizeBasis is never overwritten. Works after migration
-- because this section is compiled as a fresh SQL Server batch.
BEGIN TRY
    BEGIN TRAN;

    DECLARE @DraftShapes TABLE
    (
        [MonsterCode] NVARCHAR(80) NOT NULL PRIMARY KEY,
        [R1Feet] DECIMAL(9,2) NOT NULL,
        [R2Feet] DECIMAL(9,2) NOT NULL,
        [ZFeet] DECIMAL(9,2) NOT NULL,
        [LegacyBasis] NVARCHAR(200) NULL,
        [NewBasis] NVARCHAR(200) NOT NULL
    );

    INSERT INTO @DraftShapes
    ([MonsterCode], [R1Feet], [R2Feet], [ZFeet], [LegacyBasis], [NewBasis])
    VALUES
    (N'ORC', 5.00, 5.00, 6.00, NULL,
     N'Owner AIDM humanoid convention: R1=R2=5ft (10ft diameter); Z=6ft is approximate standing height, not a Mentzer rule.'),
    (N'GIANT_CENTIPEDE', 0.50, 0.15, 0.20,
     N'Approx. one foot body length from Mentzer descriptive text; Y and Z not sourced.',
     N'Mentzer approx. 1ft body length -> R1=0.5ft; R2=0.15ft and Z=0.2ft estimated for future geometry.'),
    (N'CARRION_CRAWLER', 4.50, 1.50, 3.00,
     N'Approximate length 9 ft and height 3 ft in Mentzer description; width Y not specified; not collision dimensions.',
     N'Mentzer approx. 9ft length and 3ft height -> R1=4.5ft, Z=3ft; R2=1.5ft estimated width.'),
    (N'GIANT_CRAB_SPIDER', 2.50, 2.00, 2.00,
     N'Approximate five-foot body length from Mentzer description; width and height not specified.',
     N'Mentzer approx. 5ft body length -> R1=2.5ft; R2=2ft and Z=2ft estimated for leg span/height.');

    UPDATE m
       SET m.[R1Feet] = d.[R1Feet],
           m.[R2Feet] = d.[R2Feet],
           m.[ZFeet] = d.[ZFeet],
           m.[SizeBasis] = d.[NewBasis]
    FROM [Rules].[Monster] AS m
    JOIN @DraftShapes AS d ON d.[MonsterCode] = m.[MonsterCode]
    WHERE m.[RulesetCode] = N'MentzerBECMI'
      AND m.[SourceStatus] = N'SourceChecked'
      AND m.[Active] = 0
      AND (
            m.[SizeBasis] = d.[LegacyBasis]
            OR (m.[SizeBasis] IS NULL AND d.[LegacyBasis] IS NULL)
          );

    DECLARE @AdjustedDrafts INT = @@ROWCOUNT;
    COMMIT;
    PRINT CONCAT(N'Updated ', @AdjustedDrafts, N' legacy inactive draft shape rows.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

-- Read-only verification of shape extents and provenance.
SELECT [RulesetCode], [MonsterCode], [RecordDate], [Active], [SourceStatus],
       [R1Feet], [R2Feet], [ZFeet], [SizeBasis]
FROM [Rules].[Monster]
WHERE [RulesetCode] = N'MentzerBECMI'
ORDER BY [MonsterCode], [RecordDate] DESC;
GO
