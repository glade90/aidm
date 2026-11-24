/*
===============================================================================
DnD — Get Transfer File: adventure / expedition party transfer
Procedure: dbo.usp_GetTransferFile
Database:  DnD (Microsoft SQL Server)
Version:   2.0  | 2026-11-08

Purpose
  Export the current, approved between-expedition state for ANY adventure / module,
  optionally focusing on a particular expedition. Returns one JSON value in
  one row and one column. Does NOT export dungeon-turn or encounter state.

Inputs
  @AdventureCode     Required; e.g. N'B1', N'X1', N'CUSTOM_CAMPAIGN'.
  @ExpeditionNumber   Optional; NULL = all recorded expeditions for the adventure;
                      a number = filter expedition and settlement sections to it.

Important semantics
  - Character identity, attributes, level, abilities, and membership are the
    CURRENT active versions. They are not historic "as-of expedition N" data.
  - Each character's ExpeditionHistory remains complete for the selected adventure
    even when @ExpeditionNumber is provided, preserving transfer context.
  - A specific expedition need not yet exist in the database: the JSON flags this
    condition without suppressing the current character export.
  - Party membership is adventure-scoped, not inferred from an expedition number.
  - Derived PartySummary is the most recent eligible return per character, not
    necessarily the selected expedition's HP/XP; use ExpeditionParticipation for
    expedition-specific figures.
  - No equipment ledger, treasury or in-dungeon state is available in these views.
  - Read-only. No OS file is written. Use SSMS Results to File / save JSON output.

Prerequisites: all 12 current-state views previously deployed.

Run examples
  EXEC [dbo].[usp_GetTransferFile] @AdventureCode = N'B1';
  EXEC [dbo].[usp_GetTransferFile] @AdventureCode = N'B1', @ExpeditionNumber = 12;
  EXEC [dbo].[usp_GetTransferFile] @AdventureCode = N'X1', @ExpeditionNumber = 3;
===============================================================================
*/
USE [DnD];
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_GetTransferFile]
    @AdventureCode   NVARCHAR(100),
    @ExpeditionNumber INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@AdventureCode)), N'') IS NULL
        THROW 57201, 'AdventureCode is required.', 1;
    IF @ExpeditionNumber IS NOT NULL AND @ExpeditionNumber < 1
        THROW 57202, 'ExpeditionNumber must be >= 1 or NULL.', 1;

    SELECT
        (
            SELECT
                N'DnD-InterExpedition-Transfer-v2' AS [TransferFormat],
                SYSUTCDATETIME() AS [ExtractedAtUTC],
                @AdventureCode AS [AdventureCode],
                @ExpeditionNumber AS [RequestedExpeditionNumber],
                N'Current active character records plus recorded expedition history; not an in-dungeon save or an as-of historical character snapshot'
                    AS [SnapshotScope],

                CAST(CASE WHEN EXISTS (
                    SELECT 1 FROM [dbo].[vCurrentAdventure] AS a
                    WHERE a.[AdventureCode] = @AdventureCode
                ) THEN 1 ELSE 0 END AS bit) AS [AdventureExists],

                CAST(CASE WHEN @ExpeditionNumber IS NULL OR EXISTS (
                    SELECT 1 FROM [dbo].[vCurrentExpedition] AS e
                    WHERE e.[AdventureCode] = @AdventureCode
                      AND e.[ExpeditionNumber] = @ExpeditionNumber
                ) THEN 1 ELSE 0 END AS bit) AS [RequestedExpeditionExists],

                (SELECT MAX(e.[ExpeditionNumber])
                 FROM [dbo].[vCurrentExpedition] AS e
                 WHERE e.[AdventureCode] = @AdventureCode) AS [LatestRecordedExpeditionNumber],

                JSON_QUERY((
                    SELECT a.*
                    FROM [dbo].[vCurrentAdventure] AS a
                    WHERE a.[AdventureCode] = @AdventureCode
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                )) AS [Adventure],

                JSON_QUERY((
                    SELECT e.*
                    FROM [dbo].[vCurrentExpedition] AS e
                    WHERE e.[AdventureCode] = @AdventureCode
                      AND (@ExpeditionNumber IS NULL OR e.[ExpeditionNumber] = @ExpeditionNumber)
                    ORDER BY e.[ExpeditionNumber]
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )) AS [Expeditions],

                JSON_QUERY((
                    SELECT s.*
                    FROM [dbo].[vExpeditionSettlementStatus] AS s
                    WHERE s.[AdventureCode] = @AdventureCode
                      AND (@ExpeditionNumber IS NULL OR s.[ExpeditionNumber] = @ExpeditionNumber)
                    ORDER BY s.[ExpeditionNumber]
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )) AS [ExpeditionSettlementStatus],

                JSON_QUERY((
                    SELECT p.*
                    FROM [dbo].[vAdventurePartyState] AS p
                    WHERE p.[AdventureCode] = @AdventureCode
                    ORDER BY p.[InitialExpedition], p.[CharacterName]
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )) AS [CurrentPartySummary],

                JSON_QUERY((
                    SELECT xp.*
                    FROM [characters].[vCurrentExpeditionParticipation] AS xp
                    WHERE xp.[AdventureCode] = @AdventureCode
                      AND (@ExpeditionNumber IS NULL OR xp.[ExpeditionNumber] = @ExpeditionNumber)
                    ORDER BY xp.[ExpeditionNumber], xp.[CharacterName]
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )) AS [SelectedExpeditionParticipation],

                JSON_QUERY((
                    SELECT
                        m.[CharacterName],
                        m.[AdventureCode],
                        m.[RecordDate] AS [MembershipRecordDate],
                        m.[InitialExpedition],
                        m.[CharacterRole],
                        m.[CardImagePath],
                        m.[Notes] AS [MembershipNotes],
                        m.[CharacterRecordDate] AS [MembershipCharacterVersion],
                        m.[AdventureRecordDate] AS [MembershipAdventureVersion],

                        JSON_QUERY((
                            SELECT c.*
                            FROM [characters].[vCurrentCharacter] AS c
                            WHERE c.[CharacterName] = m.[CharacterName]
                            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                        )) AS [IdentityAndAttributes],

                        JSON_QUERY((
                            SELECT lv.*
                            FROM [characters].[vCurrentLevel] AS lv
                            WHERE lv.[CharacterName] = m.[CharacterName]
                            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                        )) AS [CurrentLevelAndRules],

                        JSON_QUERY((
                            SELECT ap.*
                            FROM [characters].[vCurrentAppearance] AS ap
                            WHERE ap.[CharacterName] = m.[CharacterName]
                              AND ap.[Adventure] = m.[AdventureCode]
                            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                        )) AS [Appearance],

                        JSON_QUERY((
                            SELECT lang.*
                            FROM [characters].[vCurrentLanguages] AS lang
                            WHERE lang.[CharacterName] = m.[CharacterName]
                            ORDER BY lang.[LanguageName], lang.[LanguageCode]
                            FOR JSON PATH, INCLUDE_NULL_VALUES
                        )) AS [Languages],

                        JSON_QUERY((
                            SELECT sp.*
                            FROM [characters].[vCurrentSpellbook] AS sp
                            WHERE sp.[CharacterName] = m.[CharacterName]
                            ORDER BY sp.[SpellLevel], sp.[SpellName]
                            FOR JSON PATH, INCLUDE_NULL_VALUES
                        )) AS [Spellbook],

                        JSON_QUERY((
                            SELECT wp.*
                            FROM [characters].[vCurrentWeaponFamiliarity] AS wp
                            WHERE wp.[CharacterName] = m.[CharacterName]
                            ORDER BY wp.[WeaponName], wp.[UseMode]
                            FOR JSON PATH, INCLUDE_NULL_VALUES
                        )) AS [WeaponFamiliarity],

                        JSON_QUERY((
                            SELECT xp.*
                            FROM [characters].[vCurrentExpeditionParticipation] AS xp
                            WHERE xp.[AdventureCode] = m.[AdventureCode]
                              AND xp.[CharacterName] = m.[CharacterName]
                            ORDER BY xp.[ExpeditionNumber]
                            FOR JSON PATH, INCLUDE_NULL_VALUES
                        )) AS [ExpeditionHistory],

                        JSON_QUERY((
                            SELECT xp.*
                            FROM [characters].[vCurrentExpeditionParticipation] AS xp
                            WHERE xp.[AdventureCode] = m.[AdventureCode]
                              AND xp.[CharacterName] = m.[CharacterName]
                              AND xp.[ExpeditionNumber] = @ExpeditionNumber
                            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                        )) AS [RequestedExpeditionRecord]

                    FROM [characters].[vCurrentAdventureMembership] AS m
                    WHERE m.[AdventureCode] = @AdventureCode
                    ORDER BY m.[InitialExpedition], m.[CharacterName]
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )) AS [Characters],

                (SELECT COUNT(*)
                 FROM [characters].[vCurrentAdventureMembership] AS m
                 WHERE m.[AdventureCode] = @AdventureCode) AS [AdventureMemberCount],

                JSON_QUERY((
                    SELECT c.[CharacterName], c.[InitialClass], c.[Race]
                    FROM [characters].[vCurrentCharacter] AS c
                    WHERE NOT EXISTS (
                        SELECT 1
                        FROM [characters].[vCurrentAdventureMembership] AS m
                        WHERE m.[CharacterName] = c.[CharacterName]
                          AND m.[AdventureCode] = @AdventureCode
                    )
                    ORDER BY c.[CharacterName]
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )) AS [ActiveCharactersNotLinkedToAdventure]

            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        ) AS [TransferFileJSON];
END;
GO

-- Uncomment one test call:
-- EXEC [dbo].[usp_GetTransferFile] @AdventureCode = N'B1', @ExpeditionNumber = 12;
-- EXEC [dbo].[usp_GetTransferFile] @AdventureCode = N'B1';
-- EXEC [dbo].[usp_GetTransferFile] @AdventureCode = N'X1', @ExpeditionNumber = 3;
USE [DnD];
EXEC dbo.usp_GetTransferFile
    @AdventureCode = N'B1',
    @ExpeditionNumber = 12;