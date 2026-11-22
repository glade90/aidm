/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : CharacterWeaponProficiency_Party_B1_Insert.sql
Repository Path : Database/tables/CharacterWeaponProficiency_Party_B1_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Seed 17 player-approved narrative weapon proficiencies for six characters.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Version         : 1.0.0
Created         : 2026-10-20
Last Modified   : 2026-10-20
Dependencies    : CharacterWeaponProficiency.sql; Weapons_RulesCyclopedia_1991_Insert.sql; six active characters
Source          : D&D Master Players' Book (1985), weapon mastery;
                  D&D Rules Cyclopedia (1991), Chapter 5; B1 party choices.

DESIGN NOTES
- User-selected weapons preserved without numerical modifiers.
- Ralt has TWO dagger rows: thrown and melee use, as requested.
- Sho hand axe and Pell dagger recorded as General (style not stipulated).
- Pell crossbow normalized to LIGHT per existing character equipment.
- Alho flail and both polearm assignments use named campaign descriptors.
- Four fighter proficiencies for Evro are allowed narratively; no slot caps.
- Full transaction, active-parent checks, conflicts fail; rerunnable.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-20   1.0.0     Initial narrative-only weapon catalog and proficiencies.
===============================================================================
*/

USE [DnD];
GO
SET XACT_ABORT ON;
GO
IF OBJECT_ID(N'characters.CharacterWeaponProficiency',N'U') IS NULL
    THROW 56430, 'Missing CharacterWeaponProficiency; run its table script first.', 1;
GO
DECLARE @Assignments TABLE
(
    [CharacterName] NVARCHAR(60) NOT NULL,
    [WeaponCode] NVARCHAR(80) NOT NULL,
    [UseMode] NVARCHAR(20) NOT NULL,
    [NarrativeDescription] NVARCHAR(500) NOT NULL,
    PRIMARY KEY([CharacterName],[WeaponCode],[UseMode])
);
INSERT INTO @Assignments
    ([CharacterName],[WeaponCode],[UseMode],[NarrativeDescription])
VALUES
    (N'Alho', N'FLAIL_GENERAL', N'Melee', N'Familiar with flail technique; narrative only.'),
    (N'Alho', N'POLEARM_GENERAL', N'Melee', N'Trained with a polearm; specific form remains unspecified.'),
    (N'Alho', N'BOW_LONG', N'Missile', N'Comfortable shooting the longbow; no attack bonus.'),
    (N'Evro', N'SWORD_NORMAL', N'Melee', N'Trained with a normal (long) sword.'),
    (N'Evro', N'SWORD_TWO_HANDED', N'Melee', N'Trained with a two-handed sword.'),
    (N'Evro', N'POLEARM_GENERAL', N'Melee', N'Trained with an unspecified polearm.'),
    (N'Evro', N'BOW_LONG', N'Missile', N'Familiar with the longbow.'),
    (N'Sho-Rembo', N'AXE_HAND', N'General', N'Familiar with the hand axe; thrown/melee emphasis not specified.'),
    (N'Sho-Rembo', N'SWORD_SHORT', N'Melee', N'Familiar with the short sword.'),
    (N'Sho-Rembo', N'BOW_SHORT', N'Missile', N'Familiar with the short bow.'),
    (N'Wilberd', N'SLING', N'Missile', N'Comfortable with the sling, his established ranged weapon.'),
    (N'Wilberd', N'MACE', N'Melee', N'Experienced with the mace, his established cleric weapon.'),
    (N'Ralt', N'DAGGER', N'Thrown', N'Experienced at throwing daggers; separate from melee use.'),
    (N'Ralt', N'DAGGER', N'Melee', N'Experienced at close fighting with daggers; separate from throwing.'),
    (N'Pell', N'SWORD_NORMAL', N'Melee', N'Normal (long) sword; no change to rules of combat.'),
    (N'Pell', N'DAGGER', N'General', N'Dagger familiarity, with no particular fighting style specified.'),
    (N'Pell', N'CROSSBOW_LIGHT', N'Missile', N'Refers to his existing light crossbow, not a heavy crossbow.');
IF (SELECT COUNT(*) FROM @Assignments) <> 17
    THROW 56431, 'Expected 17 narrative weapon proficiency assignments.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    IF EXISTS
    (
        SELECT 1 FROM @Assignments a
        LEFT JOIN [characters].[Character] c
          ON c.[CharacterName]=a.[CharacterName] AND c.[Active]=1
        WHERE c.[RecordDate] IS NULL
    )
        THROW 56432, 'One or more active character records are missing.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Assignments a
        LEFT JOIN [Rules].[Weapons] w
          ON w.[WeaponCode]=a.[WeaponCode]
         AND w.[RulesetCode]=N'MentzerBECMI' AND w.[Active]=1 AND w.[NarrativeOnly]=1
        WHERE w.[RecordDate] IS NULL
    )
        THROW 56433, 'One or more weapons missing or inactive; run weapons seed first.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Assignments a
        JOIN [characters].[CharacterWeaponProficiency] p
          ON p.[CharacterName]=a.[CharacterName]
         AND p.[RulesetCode]=N'MentzerBECMI'
         AND p.[WeaponCode]=a.[WeaponCode]
         AND p.[UseMode]=a.[UseMode] AND p.[Active]=1
        WHERE p.[NarrativeOnly]<>1
           OR p.[AcquisitionMethod]<>N'InitialNarrativeAssignment'
           OR p.[NarrativeDescription]<>a.[NarrativeDescription]
    )
        THROW 56434, 'Existing active proficiency differs from player assignments; review history.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Assignments a
        JOIN [characters].[CharacterWeaponProficiency] p
          ON p.[RecordDate]=CONVERT(DATE,SYSUTCDATETIME())
         AND p.[CharacterName]=a.[CharacterName]
         AND p.[RulesetCode]=N'MentzerBECMI'
         AND p.[WeaponCode]=a.[WeaponCode]
         AND p.[UseMode]=a.[UseMode]
         AND p.[Active]=0
        WHERE NOT EXISTS
        (SELECT 1 FROM [characters].[CharacterWeaponProficiency] pa
          WHERE pa.[CharacterName]=a.[CharacterName]
            AND pa.[RulesetCode]=N'MentzerBECMI'
            AND pa.[WeaponCode]=a.[WeaponCode]
            AND pa.[UseMode]=a.[UseMode] AND pa.[Active]=1)
    )
        THROW 56435, 'Inactive same-day version would conflict with DATE primary key.', 1;

    INSERT INTO [characters].[CharacterWeaponProficiency]
        ([RecordDate],[CharacterName],[RulesetCode],[WeaponCode],[UseMode],
         [Active],[CharacterRecordDate],[WeaponRecordDate],
         [NarrativeOnly],[AcquisitionMethod],[LearnedOn],[NarrativeDescription],[NotesMarkdown])
    SELECT CONVERT(DATE,SYSUTCDATETIME()),a.[CharacterName],w.[RulesetCode],
        a.[WeaponCode],a.[UseMode],1,c.[RecordDate],w.[RecordDate],
        1,N'InitialNarrativeAssignment',NULL,a.[NarrativeDescription],
        CASE WHEN a.[WeaponCode]=N'POLEARM_GENERAL'
            THEN N'Polearm subtype is unspecified; a narrative proficiency does not cover every polearm mechanically.'
        WHEN a.[WeaponCode]=N'FLAIL_GENERAL'
            THEN N'Player choice; campaign descriptor absent from the official RC1991 mastery index.'
        WHEN a.[CharacterName]=N'Pell' AND a.[WeaponCode]=N'CROSSBOW_LIGHT'
            THEN N'Player said Crossbow; registered as Light Crossbow using Pell''s established equipment.'
        ELSE NULL END
    FROM @Assignments a
    JOIN [characters].[Character] c
      ON c.[CharacterName]=a.[CharacterName] AND c.[Active]=1
    JOIN [Rules].[Weapons] w
      ON w.[WeaponCode]=a.[WeaponCode]
     AND w.[RulesetCode]=N'MentzerBECMI'
     AND w.[Active]=1 AND w.[NarrativeOnly]=1
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [characters].[CharacterWeaponProficiency] p
        WHERE p.[CharacterName]=a.[CharacterName]
          AND p.[RulesetCode]=N'MentzerBECMI'
          AND p.[WeaponCode]=a.[WeaponCode]
          AND p.[UseMode]=a.[UseMode] AND p.[Active]=1
    );
    DECLARE @Added INT = @@ROWCOUNT;

    IF (SELECT COUNT(*) FROM @Assignments a
          JOIN [characters].[CharacterWeaponProficiency] p
            ON p.[CharacterName]=a.[CharacterName]
           AND p.[RulesetCode]=N'MentzerBECMI'
           AND p.[WeaponCode]=a.[WeaponCode]
           AND p.[UseMode]=a.[UseMode] AND p.[Active]=1)<>17
        THROW 56436, 'Failed to verify all 17 active weapon proficiency records.', 1;
    COMMIT TRANSACTION;
    PRINT CONCAT(N'Added ',@Added,N' proficiencies; 17 active assignments verified. Narrative only.');
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
