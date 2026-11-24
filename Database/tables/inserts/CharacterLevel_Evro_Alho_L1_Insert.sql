/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterLevel_Evro_Alho_L1_Insert.sql
Repository Path : Database/tables/CharacterLevel_Evro_Alho_L1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Level 1 Fighter snapshots for Evro and Alho using house rules.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Version         : 1.1.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql; ClassLevel.sql; ClassLevel_Mentzer_Basic_Insert.sql; CharacterLevel.sql
Source          : 1983 Mentzer D&D Basic Rules, user-supplied PDF (reference seed).

DESIGN NOTES
- Both joined B1 in Expedition 12, but reached level 1 before joining:
  no invented LevelReachedOn or level-gain expedition.
- Retroactive maximum FIRST hit die: Fighter 1d8 = 8 HP for both.
- Evro STR16 => +10% XP; WIS16 => +2 saves vs magic; CON12 => 0 HP.
- Alho STR12 => 0% XP; WIS9 => 0 vs magic; CON11 => 0 HP.
- The five savings fields copy class baseline target numbers (12/13/14/15/16)
  before situational WisdomMagicSaveBonus; magic equipment excluded.
- If either active level 1 snapshot exists and differs, throw rather than
  overwrite. Original XP at initial level 1 recorded as 0.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.1.0     Align seed with dbo.ClassLevel and personal stat modifiers.
===============================================================================
*/

USE [DnD];
GO

IF OBJECT_ID(N'characters.CharacterLevel', N'U') IS NULL
    THROW 51930, 'Missing characters.CharacterLevel; run CharacterLevel.sql first.', 1;
IF OBJECT_ID(N'dbo.ClassLevel', N'U') IS NULL
    THROW 51931, 'Missing dbo.ClassLevel; run the ClassLevel scripts first.', 1;
GO

SET XACT_ABORT ON;
DECLARE @Seed TABLE
(
    CharacterName NVARCHAR(60) PRIMARY KEY,
    MaxHP SMALLINT NOT NULL,
    XPWhenReached INT NOT NULL,
    PrimeRequisiteXPBonusPct SMALLINT NOT NULL,
    WisdomMagicSaveBonus SMALLINT NOT NULL,
    ConstitutionHPBonusPerDie SMALLINT NOT NULL,
    NotesMarkdown NVARCHAR(MAX) NOT NULL
);

INSERT INTO @Seed
    (CharacterName, MaxHP, XPWhenReached, PrimeRequisiteXPBonusPct,
     WisdomMagicSaveBonus, ConstitutionHPBonusPerDie, NotesMarkdown)
VALUES
    (N'Evro', 8, 0, 10, 2, 0,
     N'# Evro — Level 1
Human Fighter. Joined the B1 campaign in Expedition 12 with Alho after approximately two years of prior adventuring together. Max 8 HP follows the retroactive first-Hit-Die house rule. His Wisdom +2 applies to applicable saves against magical effects; it is not universally subtracted from each printed saving throw. Current injuries belong in CharacterExpedition, not here.'),
    (N'Alho', 8, 0, 0, 0, 0,
     N'# Alho — Level 1
Human Fighter. Joined the B1 campaign in Expedition 12 with Evro. Max 8 HP follows the retroactive first-Hit-Die house rule. Her Wisdom 9 and Constitution 11 give no saving throw or HP adjustment. XP from Expedition 12 is pending.');

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1 FROM @Seed AS s
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [characters].[Character] AS c
            WHERE c.[CharacterName] = s.CharacterName AND c.[Active] = 1
              AND c.[InitialClass] = N'Fighter'
        )
    )
        THROW 51932, 'Missing active Evro/Alho Fighter identity. Insert characters first.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Seed AS s
        JOIN [characters].[Character] AS c
            ON c.[CharacterName] = s.CharacterName AND c.[Active] = 1
        WHERE (s.CharacterName = N'Evro' AND
                (c.[Strength] <> 16 OR c.[Wisdom] <> 16 OR c.[Constitution] <> 12))
           OR (s.CharacterName = N'Alho' AND
                (c.[Strength] <> 12 OR c.[Wisdom] <> 9 OR c.[Constitution] <> 11))
    )
        THROW 51933, 'Stored ability scores differ from the confirmed Evro/Alho rebuild; review before level seed.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM [dbo].[ClassLevel]
        WHERE [RulesetCode] = N'MentzerBECMI'
          AND [Class] = N'Fighter' AND [Level] = 1 AND [Active] = 1
    )
        THROW 51934, 'Missing MentzerBECMI Fighter level 1 ClassLevel reference.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Seed AS s
        JOIN [characters].[CharacterLevel] AS cl
          ON cl.[CharacterName] = s.CharacterName
         AND cl.[Level] = 1 AND cl.[Active] = 1
        WHERE cl.[MaxHP] <> s.[MaxHP]
           OR cl.[Class] <> N'Fighter'
           OR cl.[RulesetCode] <> N'MentzerBECMI'
           OR cl.[PrimeRequisiteXPBonusPct] <> s.[PrimeRequisiteXPBonusPct]
           OR cl.[WisdomMagicSaveBonus] <> s.[WisdomMagicSaveBonus]
    )
        THROW 51935, 'Existing active Level 1 snapshot differs; do not overwrite.', 1;

    INSERT INTO [characters].[CharacterLevel]
    (
        [CharacterName], [Level], [Active],
        [CharacterRecordDate], [ClassLevelRecordDate], [RulesetCode], [Class],
        [XPWhenReached], [MaxHP], [HPGained], [HPDeterminationMethod],
        [ConstitutionHPBonusPerDie], [PrimeRequisiteXPBonusPct],
        [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone],
        [SaveDragonBreath], [SaveRodsStavesSpells], [WisdomMagicSaveBonus],
        [NotesMarkdown]
    )
    SELECT
        s.[CharacterName], 1, 1,
        c.[RecordDate], l.[RecordDate], l.[RulesetCode], l.[Class],
        s.[XPWhenReached], s.[MaxHP], s.[MaxHP],
        N'Maximum first Fighter d8; retroactive campaign house rule',
        s.[ConstitutionHPBonusPerDie], s.[PrimeRequisiteXPBonusPct],
        l.[SaveDeathPoison], l.[SaveMagicWands], l.[SaveParalysisStone],
        l.[SaveDragonBreath], l.[SaveRodsStavesSpells], s.[WisdomMagicSaveBonus],
        s.[NotesMarkdown]
    FROM @Seed AS s
    JOIN [characters].[Character] AS c
      ON c.[CharacterName] = s.[CharacterName] AND c.[Active] = 1
    JOIN [dbo].[ClassLevel] AS l
      ON l.[RulesetCode] = N'MentzerBECMI'
     AND l.[Class] = c.[InitialClass]
     AND l.[Level] = 1 AND l.[Active] = 1
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [characters].[CharacterLevel] AS existing
        WHERE existing.[CharacterName] = s.[CharacterName]
          AND existing.[Level] = 1 AND existing.[Active] = 1
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT [CharacterName], [Class], [Level], [MaxHP],
       [PrimeRequisiteXPBonusPct], [WisdomMagicSaveBonus],
       [SaveDeathPoison], [SaveMagicWands], [SaveParalysisStone],
       [SaveDragonBreath], [SaveRodsStavesSpells]
FROM [characters].[CharacterLevel]
WHERE [CharacterName] IN (N'Evro', N'Alho') AND [Level] = 1 AND [Active] = 1
ORDER BY [CharacterName];
GO
