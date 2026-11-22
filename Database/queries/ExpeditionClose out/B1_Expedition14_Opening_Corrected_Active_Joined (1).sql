/*
==============================================================================
B1 Expedition 14 — OPENING / DEPARTURE (SQL Server, DnD on PEQUOD)
Generated 2026-11-12 | Campaign source: B1 Expedition 13 final town save.

PURPOSE
  Create one new B1 Expedition 14 record, and six participation records.
  Do NOT close/modify Expedition 13; do NOT award Expedition 14 XP now.
  Previous Expedition 13 must ALREADY be committed as Closed, with six
  Returned participants carrying the exact final banked XP below.

SAFETY
  - @Apply=0 PREVIEWS ONLY; no changes to database.
  - @Apply=1 INSERTS 1 expedition and 6 character participation records
    atomically. No update/delete of old rows. Re-running after commit fails.
  - Does not touch treasury, barter, gear/inventory, or any character XP cache.
  - ExpeditionStatus='Active', ParticipationStatus='Joined', verified
    against the CHECK constraint definitions supplied by the user.
  - SQL is preview-first and is NOT tested on PEQUOD.
  - Run against a backup/test environment first if available.

TABLETOP START OF EXPEDITION 14
  E13 final banked XP and AFTER-REST HP:
  Wilberd 1208 XP, 6/6 HP; Ralt 1231, 4/4; Sho-Rembo 1033, 9/9;
  Pell 328, 8/8; Alho 118, 8/8; Evro 66, 8/8.
  Town treasury after E13 settlement = 2829 gp 5 sp 4 cp.
  E14 supply purchase: five oil flasks at 2 gp = -10 gp.
  Three empty cooper barrels: 15 gp refundable deposit, as agreed by the
  table on E14 departure. Thus current on-hand common treasury is
  2804 gp 5 sp 4 cp and recoverable barrel deposit is 15 gp.
  Mine cart retained. E14 objective: explore lower caverns and seek ~1000 XP
  (an objective, NOT an award), bring out three full wine barrels.
  Wilberd carries one Cure Light Wounds scroll; Ralt has Magic Missile ready.
  Two older spare oil flasks and 16 torches are provisional, not audited.
  Individual load/encumbrance audit remains UNVERIFIED.
  StartLocation=Town (departure point). Dungeon turn 0; no room moves yet.
==============================================================================
*/
USE [DnD];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply BIT = 1;    -- 0=PREVIEW ONLY, 1=INSERT E14 OPENING RECORDS
DECLARE @AdventureCode NVARCHAR(100) = N'B1';
DECLARE @NewRecordDate DATE = CONVERT(DATE, SYSUTCDATETIME());
DECLARE @OpeningStatus NVARCHAR(60) = N'Active';       -- CK_Expedition_Status verified
DECLARE @ParticipantOpeningStatus NVARCHAR(60) = N'Joined'; -- CK_CharacterExpedition_Status verified

DECLARE @Start TABLE
(
    CharacterName NVARCHAR(60) NOT NULL PRIMARY KEY,
    StartXP INT NOT NULL,
    StartHP SMALLINT NOT NULL
);
INSERT INTO @Start (CharacterName, StartXP, StartHP)
VALUES
    (N'Alho',       118, 8),
    (N'Evro',        66, 8),
    (N'Pell',       328, 8),
    (N'Ralt',      1231, 4),
    (N'Sho-Rembo', 1033, 9),
    (N'Wilberd',   1208, 6);

IF (SELECT COUNT(*) FROM @Start)<>6
    THROW 53401, N'Internal Expedition 14 roster is incomplete.', 1;

PRINT N'Existing B1 expedition rows 12 through 14:';
SELECT AdventureCode, ExpeditionNumber, RecordDate, Active,
       ExpeditionStatus, FinalDungeonTurn, StartLocation, EndLocation
FROM dbo.Expedition
WHERE AdventureCode=@AdventureCode AND ExpeditionNumber IN (12,13,14)
ORDER BY ExpeditionNumber, RecordDate DESC;

PRINT N'Existing Expedition 14 participation rows (must be none):';
SELECT CharacterName, RecordDate, Active, ParticipationStatus
FROM characters.CharacterExpedition
WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=14
ORDER BY CharacterName, RecordDate DESC;

PRINT N'Existing ExpeditionStatus values (E14 new row will use Active):';
SELECT ExpeditionStatus, COUNT(*) AS RowsUsingStatus
FROM dbo.Expedition
WHERE AdventureCode=@AdventureCode
GROUP BY ExpeditionStatus ORDER BY ExpeditionStatus;

PRINT N'Existing ParticipationStatus values (E14 participant rows will use Joined):';
SELECT ParticipationStatus, COUNT(*) AS RowsUsingStatus
FROM characters.CharacterExpedition
WHERE AdventureCode=@AdventureCode
GROUP BY ParticipationStatus ORDER BY ParticipationStatus;

PRINT N'Expedition 13 active participation XP compared with proposed E14 starts:';
SELECT s.CharacterName,
       ce.EndXP AS E13FinalXP,
       s.StartXP AS ProposedE14StartXP,
       s.StartHP AS ProposedE14StartHP,
       ce.ParticipationRole AS CarriedForwardRole,
       ce.ParticipationStatus AS E13ParticipationStatus,
       CASE WHEN ce.EndXP=s.StartXP
                      AND ce.ParticipationStatus=N'Returned'
                      AND ce.CharacterAdventureRecordDate IS NOT NULL
                      AND ce.ParticipationRole IS NOT NULL
            THEN N'OK' ELSE N'NOT READY' END AS Readiness
FROM @Start AS s
LEFT JOIN characters.CharacterExpedition AS ce
  ON ce.CharacterName=s.CharacterName AND ce.AdventureCode=@AdventureCode
 AND ce.ExpeditionNumber=13 AND ce.Active=1
ORDER BY s.CharacterName;

PRINT N'PREVIEW: proposed new expedition and accounting note:';
SELECT 14 AS ExpeditionNumber, @NewRecordDate AS RecordDate,
       @OpeningStatus AS ProposedExpeditionStatus,
       @ParticipantOpeningStatus AS ProposedParticipationStatus,
       N'Town' AS StartLocation, CAST(NULL AS INT) AS FinalDungeonTurn,
       N'2804 gp 5 sp 4 cp (after 10 gp oil + 15 gp refundable barrel deposit)'
           AS CommonTreasury_NoteOnly,
       N'3 empty borrowed barrels; mining cart; lower caverns; target ~1000 XP'
           AS Objective_NoteOnly,
       @Apply AS ApplyEnabled;

IF @Apply=0
BEGIN
    PRINT N'PREVIEW ONLY — NO DATABASE CHANGES. For commit: E13 must be Closed and all six Readiness=OK. New statuses: Active / Joined.';
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    -- The previous expedition must have a single active closed version.
    IF (SELECT COUNT(*) FROM dbo.Expedition WITH (UPDLOCK,HOLDLOCK)
        WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=13
          AND Active=1 AND ExpeditionStatus=N'Closed')<>1
        THROW 53402, N'E13 must be committed with exactly one active Closed expedition row before opening E14.', 1;

    -- Creation is one-shot; any existing E14 version or participant blocks it.
    IF EXISTS (SELECT 1 FROM dbo.Expedition WITH (UPDLOCK,HOLDLOCK)
               WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=14)
       OR EXISTS (SELECT 1 FROM characters.CharacterExpedition WITH (UPDLOCK,HOLDLOCK)
                  WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=14)
        THROW 53403, N'E14 records already exist; refusing to duplicate or overwrite.', 1;

    IF (SELECT COUNT(*) FROM characters.CharacterExpedition WITH (UPDLOCK,HOLDLOCK)
        WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=13
          AND Active=1 AND ParticipationStatus=N'Returned')<>6
        THROW 53404, N'E13 does not have exactly six active Returned participants.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Start AS s
        LEFT JOIN characters.CharacterExpedition AS ce
          ON ce.CharacterName=s.CharacterName
         AND ce.AdventureCode=@AdventureCode
         AND ce.ExpeditionNumber=13 AND ce.Active=1
        WHERE ce.CharacterName IS NULL OR ce.EndXP IS NULL
           OR ce.EndXP<>s.StartXP
           OR ce.CharacterAdventureRecordDate IS NULL
           OR ce.ParticipationRole IS NULL
    )
        THROW 53405, N'E13 final XP or identity/role missing or disagrees with E14 start.', 1;

    IF EXISTS
    (
        SELECT 1 FROM characters.CharacterExpedition AS ce
        LEFT JOIN @Start AS s ON s.CharacterName=ce.CharacterName
        WHERE ce.AdventureCode=@AdventureCode AND ce.ExpeditionNumber=13
          AND ce.Active=1 AND s.CharacterName IS NULL
    )
        THROW 53406, N'Unexpected active E13 character; review roster.', 1;

    IF (SELECT COUNT(*) FROM dbo.Expedition
        WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=13
          AND Active=1 AND AdventureRecordDate IS NOT NULL)<>1
        THROW 53407, N'Cannot carry forward AdventureRecordDate from E13.', 1;

    -- Unknown in-world date is left NULL; real-world record version is today's UTC.
    IF EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id=OBJECT_ID(N'dbo.Expedition')
                 AND name=N'GameStartDate' AND is_nullable=0)
        THROW 53408, N'GameStartDate is mandatory; verify the in-world start date before inserting.', 1;

    -- Database-defined CHECK statuses, verified from user-supplied sys.check_constraints.
    IF @OpeningStatus <> N'Active'
        THROW 53409, N'E14 opening must use ExpeditionStatus=Active.', 1;
    IF @ParticipantOpeningStatus <> N'Joined'
        THROW 53410, N'E14 participants must use ParticipationStatus=Joined.', 1;

    INSERT INTO dbo.Expedition
    (
        RecordDate, AdventureCode, ExpeditionNumber, Active,
        AdventureRecordDate, ExpeditionStatus,
        GameStartDate, GameEndDate, StartLocation, EndLocation,
        FinalDungeonTurn, ClosedAtUtc, SummaryMarkdown, SettlementNotes
    )
    SELECT
        @NewRecordDate, e.AdventureCode, 14, 1,
        e.AdventureRecordDate, @OpeningStatus,
        NULL, NULL, N'Town', NULL,
        NULL, NULL,
        N'B1 Expedition 14 opened. Party departs town to return to Quasqueton, focusing on further lower-cavern exploration and recovering three more barrels of wine. Target about 1000 XP, not yet earned.',
        CONCAT(
          N'Opening state: all six fully healed after E13 town rest. ',
          N'Treasury 2829 gp 5 sp 4 cp before E14 supplies; ',
          N'five oil flasks bought for 10 gp. ',
          N'Three empty barrels borrowed from the established cooper ',
          N'against a 15 gp REFUNDABLE deposit; on-hand treasury ',
          N'2804 gp 5 sp 4 cp; deposit receivable 15 gp. ',
          N'No database treasury or inventory adjustment made by this SQL. ',
          N'Mining cart retained; barrel sale not yet realised. ',
          N'One unused Cure Light Wounds scroll (Wilberd); ',
          N'Magic Missile memorised (Ralt). Two older spare oil flasks ',
          N'and 16 torches are PROVISIONAL pending physical inventory audit. ',
          N'Individual encumbrance/movement UNVERIFIED; reconcile prior ',
          N'to exact dungeon movement. Dungeon turn 0; no XP earned in E14 yet. ',
          N'Default formation: Pell/Alho front; Wilberd/Ralt middle; Evro/Sho rear.'
        )
    FROM dbo.Expedition AS e
    WHERE e.AdventureCode=@AdventureCode AND e.ExpeditionNumber=13
      AND e.Active=1 AND e.ExpeditionStatus=N'Closed';

    IF @@ROWCOUNT<>1
        THROW 53411, N'Expedition 14 master INSERT did not create one row.', 1;

    INSERT INTO characters.CharacterExpedition
    (
        RecordDate, CharacterName, AdventureCode, ExpeditionNumber, Active,
        CharacterAdventureRecordDate, ExpeditionRecordDate,
        ParticipationRole, ParticipationStatus, StartHP, EndHP,
        StartXP, MonsterXP, TreasureXP, OtherXP,
        PrimeRequisiteBonusXP, EndXP, TreasureShareCopper, NotesMarkdown
    )
    SELECT
        @NewRecordDate, ce.CharacterName, @AdventureCode, 14, 1,
        ce.CharacterAdventureRecordDate, @NewRecordDate,
        ce.ParticipationRole, @ParticipantOpeningStatus, s.StartHP, NULL,
        s.StartXP, NULL, NULL, NULL,
        NULL, NULL, NULL,
        CONCAT(N'E14 opening: full ',s.StartHP,N'/',s.StartHP,
               N' HP; banked XP carried from E13: ',s.StartXP,
               N'. No E14 monster/treasure/other/PR/total XP awarded yet. ',
               N'No separate cash allocation or payout.')
    FROM characters.CharacterExpedition AS ce
    JOIN @Start AS s ON s.CharacterName=ce.CharacterName
    WHERE ce.AdventureCode=@AdventureCode AND ce.ExpeditionNumber=13
      AND ce.Active=1 AND ce.ParticipationStatus=N'Returned';

    IF @@ROWCOUNT<>6
        THROW 53412, N'Expedition 14 participants INSERT did not create six rows.', 1;

    IF (SELECT COUNT(*) FROM characters.CharacterExpedition
        WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=14
          AND Active=1 AND EndXP IS NULL)<>6
        THROW 53413, N'E14 post-insert participant validation failed.', 1;

    COMMIT TRANSACTION;
    PRINT N'COMMITTED: E14 opened with one expedition row and six participation rows. No E13 changes; no XP, treasury or inventory writes.';

    SELECT AdventureCode, ExpeditionNumber, RecordDate, Active,
           ExpeditionStatus, StartLocation, FinalDungeonTurn
    FROM dbo.Expedition
    WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=14;
    SELECT CharacterName, ParticipationRole, ParticipationStatus,
           StartHP, EndHP, StartXP, EndXP
    FROM characters.CharacterExpedition
    WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=14 AND Active=1
    ORDER BY CharacterName;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
