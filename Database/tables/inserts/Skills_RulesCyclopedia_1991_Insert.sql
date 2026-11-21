/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Skills_RulesCyclopedia_1991_Insert.sql
Repository Path : Database/tables/Skills_RulesCyclopedia_1991_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert all 62 official Sample Skills Table entries, narrative-only.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Version         : 1.0.0
Created         : 2026-10-19
Last Modified   : 2026-10-19
Dependencies    : Rules.sql; Skills.sql
Source          : D&D Rules Cyclopedia (1991), Chapter 5, p. 82, Sample Skills Table

DESIGN NOTES
- 62 official table entries: STR 3, INT 29, WIS 10, DEX 10, CON 2, CHA 8.
- Art occurs in both Intelligence and Wisdom and has DISTINCT stable codes.
- Skill names/ability associations come from Rules Cyclopedia (1991), NOT
  the 1983 Mentzer Basic Players Manual.
- This is a narrative-only campaign catalog: NO skill checks, bonuses,
  proficiency modifiers, success guarantees, or extra class abilities.
- Original descriptions are short paraphrases, not rule text.
- RulesetCode remains MentzerBECMI for compatibility with DnD campaign tables.
- CatalogCode explicitly records the later 1991 source.
- One active version per ruleset and skill code; new versions must use a
  new RecordDate and deactivate prior version separately after review.
- No DROP/ALTER or silent replacement of existing reference records.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-19   1.0.0     Initial Rules Cyclopedia narrative skill catalog.
===============================================================================
*/

USE [DnD];
GO
SET XACT_ABORT ON;
GO
IF OBJECT_ID(N'Rules.Skills',N'U') IS NULL
    THROW 56210, 'Missing Rules.Skills; run Skills.sql first.', 1;
GO

DECLARE @Catalog TABLE
(
    [SkillCode]            NVARCHAR(80)   NOT NULL PRIMARY KEY,
    [SkillName]            NVARCHAR(120)  NOT NULL,
    [SourceEntry]          NVARCHAR(160)  NOT NULL,
    [AssociatedAbility]    NVARCHAR(20)   NOT NULL,
    [SourceListPosition]   SMALLINT       NOT NULL UNIQUE,
    [ChoicePrompt]         NVARCHAR(160)  NULL,
    [NarrativeDescription] NVARCHAR(600)  NOT NULL
);
INSERT INTO @Catalog
    ([SkillCode],[SkillName],[SourceEntry],[AssociatedAbility],
     [SourceListPosition],[ChoicePrompt],[NarrativeDescription])
VALUES
    (N'INTIMIDATION', N'Intimidation', N'Intimidation', N'Strength', 1, NULL, N'A practiced capacity to appear threatening or formidable.'),
    (N'MUSCLE', N'Muscle', N'Muscle', N'Strength', 2, NULL, N'Experience applying brute physical force to demanding work.'),
    (N'WRESTLING', N'Wrestling', N'Wrestling', N'Strength', 3, NULL, N'Familiarity with grappling styles and close-quarters contests.'),
    (N'ALCHEMY', N'Alchemy', N'Alchemy', N'Intelligence', 4, NULL, N'Knowledge of ordinary alchemical ingredients, mixtures, and laboratory practice.'),
    (N'ALTERNATE_MAGICS', N'Alternate Magics', N'Alternate Magics', N'Intelligence', 5, NULL, N'Familiarity with magical traditions outside the character''s usual studies.'),
    (N'ART_INT', N'Art', N'Art (choose type)', N'Intelligence', 6, N'Artistic medium or discipline', N'Knowledge and technique in a chosen visual or decorative art.'),
    (N'ARTILLERY', N'Artillery', N'Artillery', N'Intelligence', 7, NULL, N'Understanding siege engines, their crews, and battlefield deployment.'),
    (N'CRAFT', N'Craft', N'Craft (choose type)', N'Intelligence', 8, N'Craft or trade', N'Practical familiarity with a chosen manufacturing craft.'),
    (N'DISGUISE', N'Disguise', N'Disguise', N'Intelligence', 9, NULL, N'Knowledge of clothing, makeup, posture, and impersonation.'),
    (N'ENGINEERING', N'Engineering', N'Engineering', N'Intelligence', 10, NULL, N'Understanding structures, machinery, and practical construction.'),
    (N'FIRE_BUILDING', N'Fire-Building', N'Fire-Building', N'Intelligence', 11, NULL, N'Experience preparing and tending fires under varied conditions.'),
    (N'HEALING', N'Healing', N'Healing', N'Intelligence', 12, NULL, N'Mundane familiarity with wounds, illness, and patient care; no automatic healing.'),
    (N'HUNTING', N'Hunting', N'Hunting', N'Intelligence', 13, NULL, N'Knowledge of finding and taking game for food or other purposes.'),
    (N'KNOWLEDGE', N'Knowledge', N'Knowledge (choose type)', N'Intelligence', 14, N'Field of knowledge', N'Education in a chosen subject or body of lore.'),
    (N'LABOR', N'Labor', N'Labor', N'Intelligence', 15, NULL, N'Familiarity with manual occupations, workloads, and work practices.'),
    (N'LANGUAGE', N'Language', N'Language (choose type)', N'Intelligence', 16, N'Specific language', N'Linguistic education; actual known languages belong in CharacterLanguage.'),
    (N'LIP_READING', N'Lip Reading', N'Lip Reading', N'Intelligence', 17, NULL, N'Experience interpreting visible speech from mouth movements.'),
    (N'MAGICAL_ENGINEERING', N'Magical Engineering', N'Magical Engineering', N'Intelligence', 18, NULL, N'Study of enchanted constructions and how magical devices are assembled.'),
    (N'MAPPING_CARTOGRAPHY', N'Mapping/Cartography', N'Mapping/Cartography', N'Intelligence', 19, NULL, N'Practice in drafting, reading, and interpreting maps.'),
    (N'MILITARY_TACTICS', N'Military Tactics', N'Military Tactics', N'Intelligence', 20, NULL, N'Knowledge of formations, battlefield decisions, and maneuver.'),
    (N'MIMICRY', N'Mimicry', N'Mimicry', N'Intelligence', 21, NULL, N'Practice imitating voices, sounds, or manners.'),
    (N'NATURE_LORE', N'Nature Lore', N'Nature Lore', N'Intelligence', 22, NULL, N'Knowledge of plants, wildlife, seasons, and natural phenomena.'),
    (N'NAVIGATION', N'Navigation', N'Navigation', N'Intelligence', 23, NULL, N'Experience determining routes and orientation while traveling.'),
    (N'PLANAR_GEOGRAPHY', N'Planar Geography', N'Planar Geography', N'Intelligence', 24, NULL, N'Scholarship concerning other planes and their imagined geography.'),
    (N'PROFESSION', N'Profession', N'Profession (choose type)', N'Intelligence', 25, N'Profession or occupation', N'Education and experience in a chosen profession.'),
    (N'SCIENCE', N'Science', N'Science (choose type)', N'Intelligence', 26, N'Field of scientific study', N'Study of a selected field of natural or formal inquiry.'),
    (N'SHIPBUILDING', N'Shipbuilding', N'Shipbuilding', N'Intelligence', 27, NULL, N'Understanding boat and ship construction, materials, and maintenance.'),
    (N'SIGNALING', N'Signaling', N'Signaling (choose type)', N'Intelligence', 28, N'Signaling method', N'Experience using a chosen method of visual or audible signals.'),
    (N'SNARES', N'Snares', N'Snares', N'Intelligence', 29, NULL, N'Knowledge of constructing and recognizing hunting snares.'),
    (N'SURVIVAL', N'Survival', N'Survival (choose terrain)', N'Intelligence', 30, N'Terrain or environment', N'Experience securing necessities in a chosen environment.'),
    (N'TRACKING', N'Tracking', N'Tracking', N'Intelligence', 31, NULL, N'Experience interpreting footprints, trails, and other signs of passage.'),
    (N'VETERINARY_HEALING', N'Veterinary Healing', N'Veterinary Healing', N'Intelligence', 32, NULL, N'Mundane knowledge of animal injuries, illness, and care.'),
    (N'ANIMAL_TRAINING', N'Animal Training', N'Animal Training (choose type)', N'Wisdom', 33, N'Animal type', N'Experience handling and teaching a chosen kind of animal.'),
    (N'ART_WIS', N'Art', N'Art (choose type)', N'Wisdom', 34, N'Artistic medium or discipline', N'Instinctive or expressive facility in a chosen art form.'),
    (N'BRAVERY', N'Bravery', N'Bravery', N'Wisdom', 35, NULL, N'Experience maintaining resolve in frightening circumstances.'),
    (N'CAVING', N'Caving', N'Caving', N'Wisdom', 36, NULL, N'Practical familiarity with caves, caverns, and underground travel.'),
    (N'CEREMONY', N'Ceremony', N'Ceremony (choose specific Immortal)', N'Wisdom', 37, N'Specific Immortal', N'Knowledge of observances associated with a chosen Immortal.'),
    (N'DANGER_SENSE', N'Danger Sense', N'Danger Sense', N'Wisdom', 38, NULL, N'Habit of recognizing warning signs and potentially hazardous circumstances.'),
    (N'DETECT_DECEPTION', N'Detect Deception', N'Detect Deception', N'Wisdom', 39, NULL, N'Sensitivity to inconsistent stories and suspicious behavior.'),
    (N'GAMBLING', N'Gambling', N'Gambling', N'Wisdom', 40, NULL, N'Familiarity with games of chance and gambling customs.'),
    (N'LAW_AND_JUSTICE', N'Law and Justice', N'Law and Justice (choose culture)', N'Wisdom', 41, N'Culture or legal tradition', N'Familiarity with the customs and justice system of one culture.'),
    (N'MYSTICISM', N'Mysticism', N'Mysticism', N'Wisdom', 42, NULL, N'Acquaintance with meditative, contemplative, or mystical traditions.'),
    (N'ACROBATICS', N'Acrobatics', N'Acrobatics', N'Dexterity', 43, NULL, N'Practice in balance, tumbling, and bodily coordination.'),
    (N'ALERTNESS', N'Alertness', N'Alertness', N'Dexterity', 44, NULL, N'A habit of noticing changes, movements, and significant details.'),
    (N'BLIND_SHOOTING', N'Blind Shooting', N'Blind Shooting', N'Dexterity', 45, NULL, N'Experience orienting a shot without relying on clear sight; no attack bonus.'),
    (N'CHEATING', N'Cheating', N'Cheating', N'Dexterity', 46, NULL, N'Familiarity with covert manipulation in games or contests.'),
    (N'ESCAPE', N'Escape', N'Escape', N'Dexterity', 47, NULL, N'Practice slipping restraints and finding routes out of confinement.'),
    (N'MOUNTAINEERING', N'Mountaineering', N'Mountaineering', N'Dexterity', 48, NULL, N'Experience with steep terrain, climbing equipment, and mountain travel.'),
    (N'PILOTING', N'Piloting', N'Piloting (choose type)', N'Dexterity', 49, N'Vehicle or vessel type', N'Familiarity guiding a chosen form of vehicle or vessel.'),
    (N'QUICK_DRAW', N'Quick Draw', N'Quick Draw', N'Dexterity', 50, NULL, N'Habit of readying a weapon rapidly; no initiative modifier.'),
    (N'RIDING', N'Riding', N'Riding (choose type)', N'Dexterity', 51, N'Mount type', N'Experience riding and controlling a chosen kind of mount.'),
    (N'STEALTH', N'Stealth', N'Stealth (choose terrain)', N'Dexterity', 52, N'Terrain or environment', N'Practice moving unobtrusively in a chosen environment; no hiding modifier.'),
    (N'ENDURANCE', N'Endurance', N'Endurance', N'Constitution', 53, NULL, N'Experience continuing sustained physical effort or hardship.'),
    (N'FOOD_TASTING', N'Food Tasting', N'Food Tasting', N'Constitution', 54, NULL, N'Practice judging flavors, ingredients, and quality of food and drink.'),
    (N'ACTING', N'Acting', N'Acting', N'Charisma', 55, NULL, N'Practice portraying characters, emotions, and dramatic roles.'),
    (N'BARGAINING', N'Bargaining', N'Bargaining', N'Charisma', 56, NULL, N'Familiarity with negotiation, prices, and commercial customs.'),
    (N'DECEPTION', N'Deception', N'Deception', N'Charisma', 57, NULL, N'Practice maintaining a false account or misleading presentation.'),
    (N'LEADERSHIP', N'Leadership', N'Leadership', N'Charisma', 58, NULL, N'Experience organizing and motivating people.'),
    (N'MUSIC', N'Music', N'Music (choose type)', N'Charisma', 59, N'Musical instrument or musical form', N'Practice in a selected musical form or instrument.'),
    (N'PERSUASION', N'Persuasion', N'Persuasion', N'Charisma', 60, NULL, N'Practice convincing others through conversation and argument.'),
    (N'SINGING', N'Singing', N'Singing', N'Charisma', 61, NULL, N'Experience with vocal musical performance.'),
    (N'STORYTELLING', N'Storytelling', N'Storytelling', N'Charisma', 62, NULL, N'Practice composing and recounting memorable narratives.');

IF (SELECT COUNT(*) FROM @Catalog) <> 62
    THROW 56211, 'Source catalog row count must be exactly 62.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Never overwrite a different active row or silently re-label its source.
    IF EXISTS
    (
        SELECT 1
        FROM @Catalog src
        JOIN [Rules].[Skills] dest
          ON dest.[RulesetCode] = N'MentzerBECMI'
         AND dest.[SkillCode] = src.[SkillCode]
         AND dest.[Active] = 1
        WHERE dest.[CatalogCode] <> N'RC1991_SAMPLE_SKILLS'
           OR dest.[SkillName] <> src.[SkillName]
           OR dest.[SourceEntry] <> src.[SourceEntry]
           OR dest.[AssociatedAbility] <> src.[AssociatedAbility]
           OR dest.[SourceListPosition] <> src.[SourceListPosition]
           OR ISNULL(dest.[ChoicePrompt], N'') <> ISNULL(src.[ChoicePrompt], N'')
           OR dest.[NarrativeOnly] <> 1
    )
        THROW 56212, 'Conflicting active skill row found; existing records were not changed.', 1;

    -- DATE-based versioning cannot insert another row with same key today.
    IF EXISTS
    (
        SELECT 1
        FROM @Catalog src
        JOIN [Rules].[Skills] dest
          ON dest.[RecordDate] = CONVERT(DATE,SYSUTCDATETIME())
         AND dest.[RulesetCode] = N'MentzerBECMI'
         AND dest.[SkillCode] = src.[SkillCode]
         AND dest.[Active] = 0
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [Rules].[Skills] current_version
            WHERE current_version.[RulesetCode] = N'MentzerBECMI'
              AND current_version.[SkillCode] = src.[SkillCode]
              AND current_version.[Active] = 1
        )
    )
        THROW 56213, 'An inactive version for one of these skills already exists today.', 1;

    INSERT INTO [Rules].[Skills]
    (
        [RulesetCode],[SkillCode],[Active],[SkillName],[SourceEntry],
        [AssociatedAbility],[CatalogCode],[SourceListPosition],[ChoicePrompt],
        [NarrativeDescription],[NarrativeOnly],[SourceReference],[NotesMarkdown]
    )
    SELECT
        N'MentzerBECMI',src.[SkillCode],1,src.[SkillName],src.[SourceEntry],
        src.[AssociatedAbility],N'RC1991_SAMPLE_SKILLS',src.[SourceListPosition],
        src.[ChoicePrompt],src.[NarrativeDescription],1,
        N'D&D Rules Cyclopedia (1991), Chapter 5, p. 82, Sample Skills Table',
        N'Imported as a narrative background descriptor only. The original 1991 rules
include mechanical skill checks, but our 1983 Mentzer Basic campaign does not
adopt them. Does not add a language, spell, check, modifier or class feature.'
    FROM @Catalog src
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [Rules].[Skills] existing
        WHERE existing.[RulesetCode] = N'MentzerBECMI'
          AND existing.[SkillCode] = src.[SkillCode]
          AND existing.[Active] = 1
    );

    -- Restrict verification to this specific source list, not future custom skills.
    IF (SELECT COUNT(*)
        FROM [Rules].[Skills]
        WHERE [RulesetCode] = N'MentzerBECMI'
          AND [CatalogCode] = N'RC1991_SAMPLE_SKILLS'
          AND [Active] = 1) <> 62
        THROW 56214, 'Expected 62 active Rules Cyclopedia Sample Skills entries.', 1;

    COMMIT TRANSACTION;
    PRINT N'Rules Cyclopedia Sample Skills catalog: 62 entries ready; no game mechanics enabled.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT [AssociatedAbility],COUNT(*) AS [ActiveSkillEntries]
FROM [Rules].[Skills]
WHERE [RulesetCode] = N'MentzerBECMI'
  AND [CatalogCode] = N'RC1991_SAMPLE_SKILLS'
  AND [Active] = 1
GROUP BY [AssociatedAbility]
ORDER BY CASE [AssociatedAbility]
    WHEN N'Strength' THEN 1 WHEN N'Intelligence' THEN 2
    WHEN N'Wisdom' THEN 3 WHEN N'Dexterity' THEN 4
    WHEN N'Constitution' THEN 5 WHEN N'Charisma' THEN 6 ELSE 7 END;
GO
