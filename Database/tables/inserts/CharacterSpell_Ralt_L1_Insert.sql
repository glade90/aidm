/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterSpell_Ralt_L1_Insert.sql
Repository Path : Database/tables/CharacterSpell_Ralt_L1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Register Ralt Gaither starting spellbook: Read Magic and Magic Missile.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Table           : characters.CharacterSpell
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character_Ralt_Insert.sql; Spells.sql; Spells_Mentzer_Basic_L1_Insert.sql; CharacterSpell.sql
Source          : 1983 Mentzer D&D Basic Players Manual, printed pp. 25-27, 35, 38-41; DM Rulebook p. 18.

DESIGN NOTES
- User approved two starting spellbook spells: Read Magic and Magic Missile.
- Both are permanent book entries, not prepared or cast spells.
- Starts with one Magic-User spell slot; slot rules remain in dbo.ClassLevel.
- Ralt's Expedition 12 spell preparation stays historically Magic Missile.
- Spellbook itself is not yet modeled as a separate inventory object.
- Seed is safe to rerun: verifies existing entries, never overwrites.
- Active version dates for Character and Spell are resolved at execution.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.0.0     Initial implementation and source-checked design.
===============================================================================
*/

USE [DnD];
GO
IF OBJECT_ID(N'characters.CharacterSpell',N'U') IS NULL
    THROW 56030, 'CharacterSpell missing; run CharacterSpell.sql first.', 1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
    BEGIN TRAN;
    DECLARE @CharacterDate DATE;
    SELECT @CharacterDate=[RecordDate]
    FROM [characters].[Character]
    WHERE [CharacterName]=N'Ralt' AND [Active]=1
      AND [InitialClass]=N'Magic-User' AND [Intelligence]=18;
    IF @CharacterDate IS NULL
        THROW 56031, 'No approved active Ralt Magic-User with INT 18; run Character_Ralt_Insert.sql.', 1;

    DECLARE @Expected TABLE ([SpellCode] NVARCHAR(60) PRIMARY KEY);
    INSERT INTO @Expected ([SpellCode]) VALUES (N'READ_MAGIC'),(N'MAGIC_MISSILE');

    IF (SELECT COUNT(*)
        FROM [Rules].[Spells] s JOIN @Expected e ON e.[SpellCode]=s.[SpellCode]
        WHERE s.[RulesetCode]=N'MentzerBECMI'
          AND s.[SpellClass]=N'Magic-User' AND s.[SpellLevel]=1 AND s.[Active]=1)<>2
        THROW 56032, 'Both active Level 1 Magic-User spells are required in Rules.Spells.', 1;

    IF EXISTS
    (
        SELECT 1 FROM [characters].[CharacterSpell] cs
        JOIN @Expected e ON e.[SpellCode]=cs.[SpellCode]
        WHERE cs.[CharacterName]=N'Ralt' AND cs.[RulesetCode]=N'MentzerBECMI'
          AND cs.[SpellClass]=N'Magic-User' AND cs.[SpellLevel]=1
          AND cs.[Active]=1
          AND cs.[AcquisitionMethod]<>N'StartingTeacher'
    )
        THROW 56033, 'Existing Ralt spellbook entry has different provenance. Review before changing.', 1;

    IF EXISTS
    (
        SELECT 1 FROM [characters].[CharacterSpell] cs
        JOIN @Expected e ON e.[SpellCode]=cs.[SpellCode]
        WHERE cs.[CharacterName]=N'Ralt' AND cs.[RulesetCode]=N'MentzerBECMI'
          AND cs.[SpellClass]=N'Magic-User' AND cs.[SpellLevel]=1
          AND cs.[RecordDate]=CONVERT(DATE,SYSUTCDATETIME())
          AND cs.[Active]=0
    )
        THROW 56034, 'A retired Ralt spell version already exists today. DATE key disallows another.', 1;

    INSERT INTO [characters].[CharacterSpell]
    ([CharacterName],[RulesetCode],[SpellClass],[SpellLevel],[SpellCode],
     [Active],[CharacterRecordDate],[SpellRecordDate],[AcquisitionMethod],
     [LearnedOn],[SpellbookDescription],[NotesMarkdown])
    SELECT N'Ralt',s.[RulesetCode],s.[SpellClass],s.[SpellLevel],s.[SpellCode],
           1,@CharacterDate,s.[RecordDate],N'StartingTeacher',NULL,
           N'Ralt Gaither original spellbook',
           CASE WHEN s.[SpellCode]=N'READ_MAGIC' THEN
               N'## Ralt original spellbook

Read Magic is the standard first spell assigned by the DM under Mentzer Basic DM Rulebook p.18. Added retroactively to record the original spellbook; it was NOT prepared in the documented expeditions when Magic Missile was prepared.'
           ELSE
               N'## Ralt original spellbook

Magic Missile is the established second starting spell. Its spellbook presence is permanent while the book exists; preparation and casting are tracked separately in expedition notes.'
           END
    FROM [Rules].[Spells] s
    JOIN @Expected e ON e.[SpellCode]=s.[SpellCode]
    WHERE s.[RulesetCode]=N'MentzerBECMI' AND s.[SpellClass]=N'Magic-User'
      AND s.[SpellLevel]=1 AND s.[Active]=1
      AND NOT EXISTS
      (
          SELECT 1 FROM [characters].[CharacterSpell] cs
          WHERE cs.[CharacterName]=N'Ralt' AND cs.[RulesetCode]=s.[RulesetCode]
            AND cs.[SpellClass]=s.[SpellClass] AND cs.[SpellLevel]=s.[SpellLevel]
            AND cs.[SpellCode]=s.[SpellCode] AND cs.[Active]=1
      );
    PRINT CONCAT(N'Inserted ',@@ROWCOUNT,N' starting spellbook entries for Ralt.');
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
GO
SELECT cs.[RecordDate],cs.[CharacterName],s.[SpellName],
       cs.[AcquisitionMethod],cs.[SpellbookDescription],cs.[Active]
FROM [characters].[CharacterSpell] cs
JOIN [Rules].[Spells] s
  ON cs.[SpellRecordDate]=s.[RecordDate]
 AND cs.[RulesetCode]=s.[RulesetCode]
 AND cs.[SpellClass]=s.[SpellClass]
 AND cs.[SpellLevel]=s.[SpellLevel]
 AND cs.[SpellCode]=s.[SpellCode]
WHERE cs.[CharacterName]=N'Ralt'
ORDER BY s.[SpellName],cs.[RecordDate] DESC;
GO
