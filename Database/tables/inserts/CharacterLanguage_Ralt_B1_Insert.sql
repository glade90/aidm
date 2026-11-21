/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterLanguage_Ralt_B1_Insert.sql
Repository Path : Database/tables/CharacterLanguage_Ralt_B1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Add Ralt's five approved starting languages:
                  Common, Chaotic, Orc, Harpy, Hobgoblin.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterLanguage
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character_Ralt_Insert.sql; Rules.sql; Languages.sql;
                  Languages_Mentzer_Basic_Insert.sql; CharacterLanguage.sql
Sources         : 1983 Mentzer Basic Players Manual pp. 51, 56;
                  Dungeon Masters Rulebook p. 18; user-approved rolls.

DESIGN NOTES
- Name in Character table is Ralt, surname Gaither.
- INT 18: three extra languages. Orc was chosen; rolls 11 and 12
  yielded Harpy and Hobgoblin under the printed numbered catalog.
- Those random selections are a player-approved method, not a required
  official rule. All three bonus tongues can be spoken/read/written.
- Chaotic alignment language comprises secret speech/signs/passwords;
  it is NEVER written and changes when alignment changes.
- No historical LearnedOn date was established: NULL.
- The script is idempotent if existing records match; conflicting live
  records and same-day inactive version collisions cause an error.
- Does not depend on any other party member being in the database.

CHANGE LOG
Date         Version  Change
-----------  -------  ---------------------------------------------------------
2026-10-18   1.0.0    Insert Ralt's Common, Chaotic, Orc, Harpy, Hobgoblin.
===============================================================================
*/
USE [DnD];
GO
SET XACT_ABORT ON;
GO
IF OBJECT_ID(N'characters.CharacterLanguage', N'U') IS NULL
    THROW 55300, 'Missing characters.CharacterLanguage. Run its CREATE script first.', 1;
IF OBJECT_ID(N'Rules.Languages', N'U') IS NULL
    THROW 55301, 'Missing Rules.Languages. Run language catalog scripts first.', 1;
GO

DECLARE @RaltDate DATE;
SELECT @RaltDate = RecordDate
FROM [characters].[Character]
WHERE CharacterName = N'Ralt' AND Active = 1
  AND InitialAlignment = N'Chaotic' AND Intelligence = 18;
IF @RaltDate IS NULL
    THROW 55302, 'Ralt must have an active Chaotic character record with Intelligence 18.', 1;

DECLARE @Selections TABLE
(
    LanguageCode NVARCHAR(50) NOT NULL PRIMARY KEY,
    AcquisitionMethod NVARCHAR(30) NOT NULL,
    CanSpeak BIT NOT NULL,
    CanRead BIT NOT NULL,
    CanWrite BIT NOT NULL,
    NotesMarkdown NVARCHAR(MAX) NULL
);
INSERT INTO @Selections
    (LanguageCode, AcquisitionMethod, CanSpeak, CanRead, CanWrite, NotesMarkdown)
VALUES
    (N'COMMON', N'StartingCommon', 1, 1, 1,
     N'Common language known automatically at character creation.'),
    (N'ALIGN_CHAOTIC', N'StartingAlignment', 1, 0, 0,
     N'Secret unwritten Chaotic alignment language, known automatically. Cannot be learned except by a change to Chaotic alignment.'),
    (N'ORC', N'IntelligenceBonus', 1, 1, 1,
     N'First INT 18 bonus tongue, chosen by player: Orc.'),
    (N'HARPY', N'IntelligenceBonus', 1, 1, 1,
     N'Second INT 18 bonus tongue, player roll 11: Harpy.'),
    (N'HOBGOBLIN', N'IntelligenceBonus', 1, 1, 1,
     N'Third INT 18 bonus tongue, player roll 12: Hobgoblin.');

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1 FROM @Selections s
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [Rules].[Languages] l
            WHERE l.RulesetCode = N'MentzerBECMI'
              AND l.LanguageCode = s.LanguageCode
              AND l.Active = 1 AND l.LanguageKind <> N'Placeholder'
        )
    )
        THROW 55303, 'One or more required active catalog languages are missing.', 1;

    IF EXISTS
    (
        SELECT 1 FROM [characters].[CharacterLanguage]
        WHERE CharacterName = N'Ralt' AND RulesetCode = N'MentzerBECMI'
          AND Active = 1
          AND LanguageCode IN (N'ALIGN_LAWFUL', N'ALIGN_NEUTRAL')
    )
        THROW 55304, 'Ralt has a conflicting active alignment language. Manual review required.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM [characters].[CharacterLanguage] cl
        JOIN @Selections s ON s.LanguageCode = cl.LanguageCode
        WHERE cl.CharacterName = N'Ralt' AND cl.RulesetCode = N'MentzerBECMI'
          AND cl.Active = 1
          AND (cl.AcquisitionMethod <> s.AcquisitionMethod
               OR cl.CanSpeak <> s.CanSpeak
               OR ISNULL(CONVERT(INT, cl.CanRead), -1) <> CONVERT(INT, s.CanRead)
               OR ISNULL(CONVERT(INT, cl.CanWrite), -1) <> CONVERT(INT, s.CanWrite))
    )
        THROW 55305, 'Existing active Ralt language data differs. Never overwrite automatically.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Selections s
        JOIN [characters].[CharacterLanguage] cl ON cl.LanguageCode = s.LanguageCode
        WHERE cl.CharacterName = N'Ralt' AND cl.RulesetCode = N'MentzerBECMI'
          AND cl.RecordDate = CONVERT(DATE, SYSUTCDATETIME()) AND cl.Active = 0
          AND NOT EXISTS
          (
              SELECT 1 FROM [characters].[CharacterLanguage] already
              WHERE already.CharacterName = N'Ralt'
                AND already.RulesetCode = N'MentzerBECMI'
                AND already.LanguageCode = s.LanguageCode AND already.Active = 1
          )
    )
        THROW 55306, 'An inactive Ralt language version exists today. DATE key prevents replacement.', 1;

    INSERT INTO [characters].[CharacterLanguage]
    (
        CharacterName, RulesetCode, LanguageCode, Active,
        CharacterRecordDate, LanguageRecordDate,
        AcquisitionMethod, LearnedOn, CanSpeak, CanRead, CanWrite,
        NotesMarkdown
    )
    SELECT N'Ralt', N'MentzerBECMI', s.LanguageCode, 1,
           @RaltDate, l.RecordDate,
           s.AcquisitionMethod, NULL,
           s.CanSpeak, s.CanRead, s.CanWrite, s.NotesMarkdown
    FROM @Selections s
    JOIN [Rules].[Languages] l
      ON l.RulesetCode = N'MentzerBECMI'
     AND l.LanguageCode = s.LanguageCode AND l.Active = 1
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [characters].[CharacterLanguage] prior
        WHERE prior.CharacterName = N'Ralt'
          AND prior.RulesetCode = N'MentzerBECMI'
          AND prior.LanguageCode = s.LanguageCode AND prior.Active = 1
    );
    PRINT CONCAT(N'Ralt language rows inserted: ', @@ROWCOUNT);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Verify the five selected languages.
SELECT cl.CharacterName, l.LanguageName, cl.AcquisitionMethod,
       cl.CanSpeak, cl.CanRead, cl.CanWrite, cl.NotesMarkdown
FROM [characters].[CharacterLanguage] cl
JOIN [Rules].[Languages] l
  ON l.RecordDate = cl.LanguageRecordDate
 AND l.RulesetCode = cl.RulesetCode
 AND l.LanguageCode = cl.LanguageCode
WHERE cl.CharacterName = N'Ralt'
  AND cl.RulesetCode = N'MentzerBECMI' AND cl.Active = 1
ORDER BY CASE WHEN cl.AcquisitionMethod = N'StartingCommon' THEN 0
              WHEN cl.AcquisitionMethod = N'StartingAlignment' THEN 1
              ELSE 2 END,
         l.LanguageName;
GO
