/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Languages_Mentzer_Basic_Insert.sql
Repository Path : Database/tables/Languages_Mentzer_Basic_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Populate Rules.Languages with the official Basic catalog.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Table           : Rules.Languages
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Rules.sql; Languages.sql
Source          : 1983 Mentzer Basic D&D Players Manual pp.45-46,51,56;
                  Dungeon Masters Rulebook p.18 (uploaded Core Rules PDF).

DESIGN NOTES
- Exactly 20 numbered entries transcribed from DM Rulebook p.18.
- Common and Lawful/Neutral/Chaotic tongues are 4 additional baseline records.
- 'Other human tongue' is a nonselectable placeholder, not a language.
- 'Ogre or Giant' is one combined source entry, not 2 invented entries.
- ExtraLanguageOption identifies a DM-permitted candidate, not automatic grant.
- NULL WrittenFormAllowed means source does not specify a universal script.
- Alignment tongues are unwritten; cannot be selected by Intelligence bonus.
- DM must approve additional-language choices; no party language grant here.
- Idempotent seed: checks conflicting active rows and refuses to overwrite them.

CHANGE LOG
Date         Version   Change
-----------  --------  --------------------------------------------------------
2026-10-18   1.0.0     Initial approved design proposal and implementation.
===============================================================================
*/
USE [DnD];
GO
SET XACT_ABORT ON;
GO
IF OBJECT_ID(N'Rules.Languages', N'U') IS NULL
    THROW 55110, 'Missing Rules.Languages; run Languages.sql first.', 1;
GO

DECLARE @Catalog TABLE
(
    [LanguageCode] NVARCHAR(50) NOT NULL PRIMARY KEY,
    [LanguageName] NVARCHAR(100) NOT NULL,
    [LanguageKind] NVARCHAR(20) NOT NULL,
    [ListPosition] TINYINT NULL,
    [ExtraLanguageOption] BIT NOT NULL,
    [WrittenFormAllowed] BIT NULL,
    [SourceReference] NVARCHAR(250) NOT NULL,
    [NotesMarkdown] NVARCHAR(MAX) NULL
);

INSERT INTO @Catalog
    ([LanguageCode], [LanguageName], [LanguageKind], [ListPosition],
     [ExtraLanguageOption], [WrittenFormAllowed], [SourceReference], [NotesMarkdown])
VALUES
    (N'COMMON', N'Common', N'Ordinary', NULL, 0, NULL, N'Players Manual p.51', N'Ordinary language shared by most adventurers; typically automatic at character creation.'),
    (N'ALIGN_LAWFUL', N'Lawful', N'Alignment', NULL, 0, 0, N'Players Manual p.56', N'Secret Lawful alignment tongue; never written, and acquired/lost by alignment change.'),
    (N'ALIGN_NEUTRAL', N'Neutral', N'Alignment', NULL, 0, 0, N'Players Manual p.56', N'Secret Neutral alignment tongue; never written, and acquired/lost by alignment change.'),
    (N'ALIGN_CHAOTIC', N'Chaotic', N'Alignment', NULL, 0, 0, N'Players Manual p.56', N'Secret Chaotic alignment tongue; never written, and acquired/lost by alignment change.'),
    (N'BUGBEAR', N'Bugbear', N'Ordinary', 1, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'DOPPLEGANGER', N'Doppleganger', N'Ordinary', 2, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'DRAGON', N'Dragon', N'Ordinary', 3, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'DWARF', N'Dwarf', N'Ordinary', 4, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'ELF', N'Elf', N'Ordinary', 5, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'GARGOYLE', N'Gargoyle', N'Ordinary', 6, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'GNOLL', N'Gnoll', N'Ordinary', 7, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'GNOME', N'Gnome', N'Ordinary', 8, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'GOBLIN', N'Goblin', N'Ordinary', 9, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'HALFLING', N'Halfling', N'Ordinary', 10, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'HARPY', N'Harpy', N'Ordinary', 11, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'HOBGOBLIN', N'Hobgoblin', N'Ordinary', 12, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'KOBOLD', N'Kobold', N'Ordinary', 13, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'LIZARD_MAN', N'Lizard Man', N'Ordinary', 14, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'MEDUSA', N'Medusa', N'Ordinary', 15, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'MINOTAUR', N'Minotaur', N'Ordinary', 16, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'OGRE_OR_GIANT', N'Ogre or Giant', N'Ordinary', 17, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Combined single list entry as printed; DM adjudicates particular Ogre/Giant communication.'),
    (N'ORC', N'Orc', N'Ordinary', 18, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'PIXIE', N'Pixie', N'Ordinary', 19, 1, NULL, N'Dungeon Masters Rulebook p.18', N'Listed as a common language option, subject to DM approval.'),
    (N'OTHER_HUMAN_TONGUE', N'Other human tongue', N'Placeholder', 20, 0, NULL, N'Dungeon Masters Rulebook p.18', N'Generic category; choose a named human language with DM approval instead of assigning this placeholder.');

BEGIN TRY
    BEGIN TRANSACTION;

    -- Do not silently reinterpret prior approved reference versions.
    IF EXISTS
    (
        SELECT 1
        FROM @Catalog AS src
        JOIN [Rules].[Languages] AS dest
          ON dest.[RulesetCode] = N'MentzerBECMI'
         AND dest.[LanguageCode] = src.[LanguageCode]
         AND dest.[Active] = 1
        WHERE dest.[LanguageName] <> src.[LanguageName]
           OR dest.[LanguageKind] <> src.[LanguageKind]
           OR ISNULL(dest.[ListPosition], 0) <> ISNULL(src.[ListPosition], 0)
           OR dest.[ExtraLanguageOption] <> src.[ExtraLanguageOption]
           OR ISNULL(CONVERT(INT, dest.[WrittenFormAllowed]), -1) <>
              ISNULL(CONVERT(INT, src.[WrittenFormAllowed]), -1)
    )
        THROW 55111, 'A live language catalog entry differs from the official seed. Review before modifying.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Catalog AS src
        JOIN [Rules].[Languages] AS dest
          ON dest.[RulesetCode] = N'MentzerBECMI'
         AND dest.[LanguageCode] = src.[LanguageCode]
         AND dest.[RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
         AND dest.[Active] = 0
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [Rules].[Languages] AS active_dest
            WHERE active_dest.[RulesetCode] = N'MentzerBECMI'
              AND active_dest.[LanguageCode] = src.[LanguageCode]
              AND active_dest.[Active] = 1
        )
    )
        THROW 55112, 'An inactive version of a catalog entry exists today. DATE PK prevents replacement today.', 1;

    INSERT INTO [Rules].[Languages]
    (
        [RulesetCode], [LanguageCode], [LanguageName], [Active],
        [LanguageKind], [ListPosition], [ExtraLanguageOption],
        [WrittenFormAllowed], [SourceReference], [NotesMarkdown]
    )
    SELECT
        N'MentzerBECMI', src.[LanguageCode], src.[LanguageName], 1,
        src.[LanguageKind], src.[ListPosition], src.[ExtraLanguageOption],
        src.[WrittenFormAllowed], src.[SourceReference], src.[NotesMarkdown]
    FROM @Catalog AS src
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [Rules].[Languages] AS existing
        WHERE existing.[RulesetCode] = N'MentzerBECMI'
          AND existing.[LanguageCode] = src.[LanguageCode]
          AND existing.[Active] = 1
    );

    PRINT CONCAT(N'New language catalog entries inserted: ', @@ROWCOUNT);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- 20 numbered list entries + Common + 3 alignment languages = 24 records.
SELECT [ListPosition], [LanguageCode], [LanguageName], [LanguageKind],
       [ExtraLanguageOption], [WrittenFormAllowed], [SourceReference]
FROM [Rules].[Languages]
WHERE [RulesetCode] = N'MentzerBECMI' AND [Active] = 1
ORDER BY CASE WHEN [ListPosition] IS NULL THEN 0 ELSE 1 END,
         [ListPosition], [LanguageName];
GO
