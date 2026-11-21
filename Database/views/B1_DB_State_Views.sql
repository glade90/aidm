/*
B1 — Quasqueton: inter-expedition read-model views
Target: Microsoft SQL Server, database [DnD], default instance PEQUOD
Created: 2026-11-08

PURPOSE
- Read the latest approved/versioned character, adventure and expedition rows.
- Report character state at the last recorded expedition RETURN, not during a dungeon turn.
- Leave unavailable/unfinished data NULL; never infer HP recovery, XP, AC, spells prepared,
  individual carried inventory or treasury balances.
- CharacterSkill, inventory and treasury tables are not among the supplied definitions.

INSTALL
- Execute in SSMS against PEQUOD / [DnD] AFTER the 15 supplied table scripts.
- Only creates or alters VIEWS; it does not insert, update, delete or migrate game data.
- View names are generic for reuse with adventures other than B1.
- Run B1_DB_State_Checks.sql afterward to see whether party data was ever inserted.
*/
USE [DnD];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Preflight: avoid partial deployment if one of the source tables is absent.
IF SCHEMA_ID(N'characters') IS NULL OR SCHEMA_ID(N'Rules') IS NULL
    THROW 57000, 'Missing characters/Rules schema. Install original table definitions first.', 1;
IF EXISTS (
 SELECT 1 FROM (VALUES
 (N'dbo.Adventure'),(N'dbo.Expedition'),(N'dbo.ClassLevel'),
 (N'characters.Character'),(N'characters.CharacterAdventure'),
 (N'characters.CharacterAppearance'),(N'characters.CharacterExpedition'),
 (N'characters.CharacterLevel'),(N'characters.CharacterLanguage'),
 (N'characters.CharacterSpell'),(N'characters.CharacterWeaponProficiency'),
 (N'Rules.Languages'),(N'Rules.Spells'),(N'Rules.Weapons')
 ) AS T(ObjectName) WHERE OBJECT_ID(T.ObjectName, N'U') IS NULL
)
    THROW 57001, 'A required source table is missing. Deploy all relevant tables first.', 1;
GO

CREATE OR ALTER VIEW [dbo].[vCurrentAdventure]
AS
 SELECT [RecordDate], [AdventureCode], [AdventureName], [AdventureType],
        [ModuleCode], [ModuleTitle], [Publisher], [Ruleset], [RulesNotes],
        [PlayerSummary], [AdventureStatus], [Notes]
 FROM [dbo].[Adventure]
 WHERE [Active] = 1;
GO

CREATE OR ALTER VIEW [dbo].[vCurrentExpedition]
AS
 SELECT [RecordDate], [AdventureCode], [ExpeditionNumber], [AdventureRecordDate],
        [ExpeditionStatus], [GameStartDate], [GameEndDate], [StartLocation],
        [EndLocation], [FinalDungeonTurn], [ClosedAtUtc],
        [SummaryMarkdown], [SettlementNotes]
 FROM [dbo].[Expedition]
 WHERE [Active] = 1;
GO

CREATE OR ALTER VIEW [characters].[vCurrentCharacter]
AS
 SELECT [RecordDate], [CharacterName], [Surname], [Moniker], [Race],
        [InitialClass], [Sex], [InitialAge], [InitialAlignment],
        [Strength], [Intelligence], [Wisdom], [Constitution],
        [Dexterity], [Charisma], [BaseAC], [BackStory]
 FROM [characters].[Character]
 WHERE [Active] = 1;
GO

-- Old attained levels remain active. Choose the HIGHEST active level per character.
-- ClassLevel joins via the original immutable parent version, not its latest row.
CREATE OR ALTER VIEW [characters].[vCurrentLevel]
AS
 WITH Ranked AS (
  SELECT cl.*, ROW_NUMBER() OVER (
      PARTITION BY cl.[CharacterName]
      ORDER BY cl.[Level] DESC, cl.[RecordDate] DESC
  ) AS rn
  FROM [characters].[CharacterLevel] AS cl
  WHERE cl.[Active] = 1
 )
 SELECT cl.[CharacterName], cl.[RecordDate] AS [CharacterLevelRecordDate],
        cl.[CharacterRecordDate], cl.[RulesetCode], cl.[Class], cl.[Level],
        cl.[MaxHP], cl.[HPGained], cl.[HPDeterminationMethod],
        cl.[ConstitutionHPBonusPerDie], cl.[PrimeRequisiteXPBonusPct],
        cl.[SaveDeathPoison], cl.[SaveMagicWands],
        cl.[SaveParalysisStone], cl.[SaveDragonBreath],
        cl.[SaveRodsStavesSpells], cl.[WisdomMagicSaveBonus],
        cl.[XPWhenReached], cl.[LevelReachedOn],
        rules.[Title] AS [ClassTitle], rules.[PrimeRequisite],
        rules.[MinXP] AS [LevelMinXP], rules.[MaxXP] AS [LevelMaxXP]
 FROM Ranked AS cl
 LEFT JOIN [dbo].[ClassLevel] AS rules
   ON rules.[RecordDate] = cl.[ClassLevelRecordDate]
  AND rules.[RulesetCode] = cl.[RulesetCode]
  AND rules.[Class] = cl.[Class]
  AND rules.[Level] = cl.[Level]
 WHERE cl.rn = 1;
GO

CREATE OR ALTER VIEW [characters].[vCurrentAppearance]
AS
 SELECT [RecordDate], [CharacterName], [Adventure],
        [HeightDescription], [BuildDescription], [HairColor],
        [HairDescription], [FacialHair], [EyeColor], [FaceDescription],
        [Scars], [OverallImpression], [AppearanceNotes]
 FROM [characters].[CharacterAppearance]
 WHERE [Active] = 1;
GO

CREATE OR ALTER VIEW [characters].[vCurrentAdventureMembership]
AS
 SELECT [RecordDate], [CharacterName], [AdventureCode],
        [CharacterRecordDate], [AdventureRecordDate], [InitialExpedition],
        [CharacterRole], [CardImagePath], [Notes]
 FROM [characters].[CharacterAdventure]
 WHERE [Active] = 1;
GO

CREATE OR ALTER VIEW [characters].[vCurrentExpeditionParticipation]
AS
 SELECT [RecordDate], [CharacterName], [AdventureCode], [ExpeditionNumber],
        [CharacterAdventureRecordDate], [ExpeditionRecordDate],
        [ParticipationRole], [ParticipationStatus],
        [StartHP], [EndHP], [StartXP], [MonsterXP],
        [TreasureXP], [OtherXP], [PrimeRequisiteBonusXP], [EndXP],
        [TreasureShareCopper], [NotesMarkdown]
 FROM [characters].[CharacterExpedition]
 WHERE [Active] = 1;
GO

-- Permanent knowledge only: spellbook entries, NOT spells prepared or used.
CREATE OR ALTER VIEW [characters].[vCurrentSpellbook]
AS
 SELECT cs.[CharacterName], cs.[RulesetCode], cs.[SpellClass],
        cs.[SpellLevel], cs.[SpellCode], s.[SpellName],
        cs.[AcquisitionMethod], cs.[LearnedOn],
        cs.[SpellbookDescription], cs.[NotesMarkdown],
        cs.[RecordDate] AS [SpellbookRecordDate]
 FROM [characters].[CharacterSpell] AS cs
 LEFT JOIN [Rules].[Spells] AS s
   ON s.[RecordDate] = cs.[SpellRecordDate]
  AND s.[RulesetCode] = cs.[RulesetCode]
  AND s.[SpellClass] = cs.[SpellClass]
  AND s.[SpellLevel] = cs.[SpellLevel]
  AND s.[SpellCode] = cs.[SpellCode]
 WHERE cs.[Active] = 1;
GO

CREATE OR ALTER VIEW [characters].[vCurrentLanguages]
AS
 SELECT cl.[CharacterName], cl.[RulesetCode], cl.[LanguageCode],
        lang.[LanguageName], lang.[LanguageKind],
        cl.[AcquisitionMethod], cl.[CanSpeak], cl.[CanRead], cl.[CanWrite],
        cl.[LearnedOn], cl.[NotesMarkdown],
        cl.[RecordDate] AS [CharacterLanguageRecordDate]
 FROM [characters].[CharacterLanguage] AS cl
 LEFT JOIN [Rules].[Languages] AS lang
   ON lang.[RecordDate] = cl.[LanguageRecordDate]
  AND lang.[RulesetCode] = cl.[RulesetCode]
  AND lang.[LanguageCode] = cl.[LanguageCode]
 WHERE cl.[Active] = 1;
GO

-- Narrative-only familiarity. DOES NOT grant mastery levels or attack modifiers.
CREATE OR ALTER VIEW [characters].[vCurrentWeaponFamiliarity]
AS
 SELECT cw.[CharacterName], cw.[RulesetCode], cw.[WeaponCode],
        w.[WeaponName], w.[WeaponFamily], w.[PrimaryUse], cw.[UseMode],
        cw.[AcquisitionMethod], cw.[LearnedOn],
        cw.[NarrativeDescription], cw.[NotesMarkdown],
        cw.[RecordDate] AS [CharacterWeaponRecordDate]
 FROM [characters].[CharacterWeaponProficiency] AS cw
 LEFT JOIN [Rules].[Weapons] AS w
   ON w.[RecordDate] = cw.[WeaponRecordDate]
  AND w.[RulesetCode] = cw.[RulesetCode]
  AND w.[WeaponCode] = cw.[WeaponCode]
 WHERE cw.[Active] = 1;
GO

/*
BETWEEN-EXPEDITIONS PARTY STATE
- One row for each approved character/adventure membership.
- LastReturnHP is from the newest recorded RETURN/DEATH of an expedition marked
  Settlement or Closed. It does NOT account for later town healing.
- EndXP is NULL until formally awarded, even when StartXP was recorded.
- BaseAC is an identity-table field, NOT armour-adjusted combat AC.
- Party money, worn gear, oil, torches and carried ammunition are NOT represented.
- Joining an adventure is distinct from a documented expedition participation.
*/
CREATE OR ALTER VIEW [dbo].[vAdventurePartyState]
AS
 SELECT ca.[AdventureCode], a.[AdventureName], ca.[CharacterName],
        c.[Moniker], c.[Race], c.[InitialClass], c.[InitialAlignment],
        c.[Sex], c.[Strength], c.[Intelligence], c.[Wisdom],
        c.[Constitution], c.[Dexterity], c.[Charisma],
        c.[BaseAC] AS [CharacterTableBaseAC_NotEquippedAC],
        ca.[InitialExpedition], ca.[CharacterRole], ca.[CardImagePath],
        lvl.[Class] AS [CurrentClass], lvl.[Level] AS [CurrentLevel],
        lvl.[ClassTitle], lvl.[MaxHP], lvl.[PrimeRequisiteXPBonusPct],
        lvl.[SaveDeathPoison], lvl.[SaveMagicWands],
        lvl.[SaveParalysisStone], lvl.[SaveDragonBreath],
        lvl.[SaveRodsStavesSpells],
        ret.[ExpeditionNumber] AS [LastReturnExpeditionNumber],
        ret.[ExpeditionStatus] AS [LastReturnExpeditionStatus],
        ret.[ParticipationStatus] AS [LastParticipationStatus],
        ret.[StartHP] AS [LastExpeditionStartHP],
        ret.[EndHP] AS [LastReturnHP_BeforeTownRest],
        ret.[StartXP] AS [LastExpeditionStartXP],
        ret.[EndXP] AS [LastExpeditionSettledEndXP],
        ret.[MonsterXP], ret.[TreasureXP], ret.[OtherXP],
        ret.[PrimeRequisiteBonusXP], ret.[TreasureShareCopper],
        CASE WHEN ret.[ExpeditionNumber] IS NULL THEN N'NO_RETURN_RECORD'
             WHEN ret.[EndXP] IS NULL THEN N'XP_NOT_RECORDED'
             ELSE N'XP_RECORDED' END AS [XPRecordStatus],
        CASE WHEN c.[CharacterName] IS NULL THEN 0 ELSE 1 END AS [HasActiveIdentity],
        CASE WHEN lvl.[CharacterName] IS NULL THEN 0 ELSE 1 END AS [HasActiveLevel],
        CASE WHEN app.[CharacterName] IS NULL THEN 0 ELSE 1 END AS [HasActiveAppearance]
 FROM [characters].[vCurrentAdventureMembership] AS ca
 LEFT JOIN [dbo].[vCurrentAdventure] AS a
   ON a.[AdventureCode] = ca.[AdventureCode]
 LEFT JOIN [characters].[vCurrentCharacter] AS c
   ON c.[CharacterName] = ca.[CharacterName]
 LEFT JOIN [characters].[vCurrentLevel] AS lvl
   ON lvl.[CharacterName] = ca.[CharacterName]
 LEFT JOIN [characters].[vCurrentAppearance] AS app
   ON app.[CharacterName] = ca.[CharacterName]
  AND app.[Adventure] = ca.[AdventureCode]
 OUTER APPLY (
   SELECT TOP (1) ce.[ExpeditionNumber], ce.[ParticipationStatus],
          ce.[StartHP], ce.[EndHP], ce.[StartXP], ce.[EndXP],
          ce.[MonsterXP], ce.[TreasureXP], ce.[OtherXP],
          ce.[PrimeRequisiteBonusXP], ce.[TreasureShareCopper],
          e.[ExpeditionStatus]
   FROM [characters].[vCurrentExpeditionParticipation] AS ce
   JOIN [dbo].[vCurrentExpedition] AS e
     ON e.[AdventureCode] = ce.[AdventureCode]
    AND e.[ExpeditionNumber] = ce.[ExpeditionNumber]
   WHERE ce.[AdventureCode] = ca.[AdventureCode]
     AND ce.[CharacterName] = ca.[CharacterName]
     AND e.[ExpeditionStatus] IN (N'Settlement', N'Closed')
     AND ce.[ParticipationStatus] IN (N'Returned',N'Died',N'Withdrew',N'Missing')
   ORDER BY ce.[ExpeditionNumber] DESC, ce.[RecordDate] DESC
 ) AS ret;
GO

-- Settlement check at expedition granularity. An empty participation list is NOT success.
CREATE OR ALTER VIEW [dbo].[vExpeditionSettlementStatus]
AS
 SELECT e.[AdventureCode], e.[ExpeditionNumber], e.[ExpeditionStatus],
        e.[FinalDungeonTurn], e.[EndLocation], e.[ClosedAtUtc],
        COUNT(ce.[CharacterName]) AS [ParticipantRows],
        SUM(CASE WHEN ce.[ParticipationStatus] = N'Returned' THEN 1 ELSE 0 END)
            AS [ReturnedCharacters],
        SUM(CASE WHEN ce.[CharacterName] IS NOT NULL AND ce.[EndHP] IS NULL THEN 1 ELSE 0 END)
            AS [MissingEndHP],
        SUM(CASE WHEN ce.[CharacterName] IS NOT NULL AND ce.[EndXP] IS NULL THEN 1 ELSE 0 END)
            AS [MissingEndXP],
        SUM(CASE WHEN ce.[CharacterName] IS NOT NULL AND ce.[StartXP] IS NULL THEN 1 ELSE 0 END)
            AS [MissingStartXP],
        CASE WHEN COUNT(ce.[CharacterName]) = 0 THEN N'NO_PARTICIPATION_ROWS'
             WHEN SUM(CASE WHEN ce.[EndHP] IS NULL OR ce.[EndXP] IS NULL
                           THEN 1 ELSE 0 END) > 0 THEN N'INCOMPLETE'
             ELSE N'HP_AND_XP_RECORDED' END AS [DataReadiness]
 FROM [dbo].[vCurrentExpedition] AS e
 LEFT JOIN [characters].[vCurrentExpeditionParticipation] AS ce
   ON ce.[AdventureCode] = e.[AdventureCode]
  AND ce.[ExpeditionNumber] = e.[ExpeditionNumber]
 GROUP BY e.[AdventureCode],e.[ExpeditionNumber],e.[ExpeditionStatus],
          e.[FinalDungeonTurn],e.[EndLocation],e.[ClosedAtUtc];
GO

PRINT N'Inter-expedition views are installed. Run B1_DB_State_Checks.sql next.';
GO
