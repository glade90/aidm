/*
===============================================================================
B1 Expedition 12 — XP and HP closeout (version-preserving SQL Server script)
Database: DnD on PEQUOD
Generated: 2026-11-08

READ FIRST:
- Default @Apply = 0 only PREVIEWS proposed awards; it changes nothing.
- Finalisation requires setting BOTH @Apply=1 and @ApproveHalfShareTreasure=1.
- @ApproveHalfShareTreasure means: for THIS settlement, use half-share
  retainers (Pell and Evro) for BOTH monster XP and treasure XP/cash entitlements.
  Monster half-shares are from Mentzer Basic; the actual contractual TREASURE
  arrangements have not been independently established from the transcripts.
  Do not approve that convention unless it matches the party's agreement.
- Current MaxHP was revised under the maximum-first-hit-die house rule; EndHP
  here is the historical HP at town return BEFORE rest: Ralt 1, Wilberd 5,
  Sho-Rembo 2, Pell 4, Alho 4, Evro 7.
- 50 gp of treasure XP comes from an APPROVED PROVISIONAL VALUE for the working
  recovered mining cart. This is an in-kind asset; it was NOT sold, so NO
  50 gp is added to cash, and it is not included in TreasureShareCopper.
- Cash receipts eligible for Exp12 settlement = 75 gp wine + 15 gp goblet +
  34 ep (17 gp) + 27 cp = 10,727 cp. The 15 gp deposit refund, 400 gp from
  previously recovered tapestries, and Sho's pre-existing 97 cp are excluded.
- The existing common treasury balance does NOT change. TreasureShareCopper
  records settlement allocations/entitlements, not proof of cash payout.
- Ralt's corrected Magic Missile / Read Magic spellbook entries are independent.
- Evro's revised Strength-16 / +10% prime-requisite XP bonus is assumed to
  apply at this settlement. If the rebuild should be future-only, set
  @ApplyEvroCurrentPRBonus=0 before previewing/applying.
- No database connection is available to test execution. PREVIEW FIRST.

AWARD BASIS
  Monster XP: 30 troglodyte +15 rats +25 goblins +39 stirges +20 orcs
            +10 conquered kobolds K2/K6 = 139.
  Treasure XP: 75 wine +15 goblet +17 goblin ep +0.27 orc copper
             +50 recovered cart = 157.27 gp; 157 WHOLE XP allocated.
  4 player characters at 1 share each + 2 retainers at 1/2 share each
    = 5 full-share equivalents.
  Per player character = 59 XP before prime requisite bonus.
  Per retainer = 30 XP before prime requisite bonus.
  Integer component rounding (keeps totals exactly 139/157):
    Wilberd  28 monster +31 treasure =59
    Ralt     28 monster +31 treasure =59
    Sho      27 monster +32 treasure =59
    Alho     28 monster +31 treasure =59
    Pell     14 monster +16 treasure =30
    Evro     14 monster +16 treasure =30
  Base 296 XP; +10% INT/WIS/STR bonus truncated to integer as in Mentzer.
===============================================================================
*/
USE [DnD];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @AdventureCode NVARCHAR(100) = N'B1';
DECLARE @ExpeditionNumber INT = 12;
DECLARE @NewRecordDate DATE = CONVERT(DATE, SYSUTCDATETIME());
DECLARE @Apply BIT = 1;                          -- 0=PREVIEW; 1=WRITE and CLOSE
DECLARE @ApproveHalfShareTreasure BIT = 1;       -- change to 1 ONLY if approved
DECLARE @ApplyEvroCurrentPRBonus BIT = 1;       -- 0 if post-expedition rebuild is future-only

DECLARE @Awards TABLE
(
    CharacterName NVARCHAR(60) NOT NULL PRIMARY KEY,
    MonsterXP INT NOT NULL,
    TreasureXP INT NOT NULL,
    EndHP SMALLINT NOT NULL,
    TreasureShareCopper BIGINT NOT NULL,
    ExpectedPRBonusPct INT NOT NULL
);
INSERT INTO @Awards
    (CharacterName, MonsterXP, TreasureXP, EndHP,
     TreasureShareCopper, ExpectedPRBonusPct)
VALUES
    (N'Alho',       28, 31, 4, 2145,  0),
    (N'Evro',       14, 16, 7, 1073, 10),
    (N'Pell',       14, 16, 4, 1073,  0),
    (N'Ralt',       28, 31, 1, 2145, 10),
    (N'Sho-Rembo',  27, 32, 2, 2146,  0),
    (N'Wilberd',    28, 31, 5, 2145, 10);

-- All value checks refer to the EXISTING active data, not the old JSON file.
IF (SELECT SUM(MonsterXP) FROM @Awards) <> 139
   OR (SELECT SUM(TreasureXP) FROM @Awards) <> 157
   OR (SELECT SUM(TreasureShareCopper) FROM @Awards) <> 10727
    THROW 52101, N'Proposed XP/treasure totals do not reconcile.', 1;

IF (SELECT COUNT(*) FROM dbo.Expedition
    WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=@ExpeditionNumber
      AND Active=1 AND ExpeditionStatus=N'Settlement') <> 1
    THROW 52102, N'Expected exactly one active B1 Expedition 12 in Settlement status.', 1;

IF EXISTS (SELECT 1 FROM dbo.Expedition
           WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=@ExpeditionNumber
             AND Active=1 AND (FinalDungeonTurn IS NULL OR FinalDungeonTurn<>74
                              OR EndLocation IS NULL OR EndLocation<>N'Town'))
    THROW 52118, N'Expedition return turn/location differs from the saved closeout; re-audit first.', 1;

IF (SELECT COUNT(*) FROM characters.CharacterExpedition
    WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=@ExpeditionNumber
      AND Active=1 AND ParticipationStatus=N'Returned') <> 6
    THROW 52103, N'Expected exactly six active returned participants.', 1;

IF EXISTS (
    SELECT 1 FROM @Awards AS a
    LEFT JOIN characters.CharacterExpedition AS ce
      ON ce.CharacterName=a.CharacterName AND ce.AdventureCode=@AdventureCode
     AND ce.ExpeditionNumber=@ExpeditionNumber AND ce.Active=1
    WHERE ce.CharacterName IS NULL
)
    THROW 52104, N'An expected participant is absent.', 1;

IF EXISTS (
    SELECT 1 FROM characters.CharacterExpedition AS ce
    LEFT JOIN @Awards AS a ON a.CharacterName=ce.CharacterName
    WHERE ce.AdventureCode=@AdventureCode AND ce.ExpeditionNumber=@ExpeditionNumber
      AND ce.Active=1 AND a.CharacterName IS NULL
)
    THROW 52105, N'Unexpected active participant(s); review allocation.', 1;

IF EXISTS (
    SELECT 1 FROM characters.CharacterExpedition AS ce
    WHERE ce.AdventureCode=@AdventureCode AND ce.ExpeditionNumber=@ExpeditionNumber
      AND ce.Active=1 AND (
        (ce.StartXP IS NULL AND ce.CharacterName<>N'Alho')
        OR (ce.CharacterName=N'Alho' AND ce.StartXP IS NOT NULL AND ce.StartXP<>0)
        OR (ce.EndHP IS NOT NULL AND ce.EndHP <>
            (SELECT a.EndHP FROM @Awards AS a WHERE a.CharacterName=ce.CharacterName))
        OR ce.EndXP IS NOT NULL OR ce.MonsterXP IS NOT NULL
        OR ce.TreasureXP IS NOT NULL OR ce.PrimeRequisiteBonusXP IS NOT NULL
        OR (ce.OtherXP IS NOT NULL AND ce.OtherXP<>0)
        OR (ce.TreasureShareCopper IS NOT NULL AND ce.TreasureShareCopper <>
            (SELECT a.TreasureShareCopper FROM @Awards AS a WHERE a.CharacterName=ce.CharacterName))
      )
)
    THROW 52106, N'Existing participation contains unexpected XP or HP; do not overwrite.', 1;

IF EXISTS (
    SELECT 1 FROM @Awards AS a
    JOIN characters.vCurrentLevel AS lvl ON lvl.CharacterName=a.CharacterName
    WHERE lvl.PrimeRequisiteXPBonusPct <> a.ExpectedPRBonusPct
)
    THROW 52107, N'Current prime-requisite bonuses have changed; re-audit before applying.', 1;

DECLARE @Resolved TABLE
(
    CharacterName NVARCHAR(60) NOT NULL PRIMARY KEY,
    StartXP INT NOT NULL,
    EndHP SMALLINT NOT NULL,
    MonsterXP INT NOT NULL,
    TreasureXP INT NOT NULL,
    OtherXP INT NOT NULL,
    PrimeRequisiteBonusXP INT NOT NULL,
    EndXP INT NOT NULL,
    TreasureShareCopper BIGINT NOT NULL
);

INSERT INTO @Resolved
    (CharacterName, StartXP, EndHP, MonsterXP, TreasureXP,
     OtherXP, PrimeRequisiteBonusXP, EndXP, TreasureShareCopper)
SELECT
    a.CharacterName,
    COALESCE(ce.StartXP, 0),
    a.EndHP,
    a.MonsterXP,
    a.TreasureXP,
    0,
    bonus.BonusXP,
    COALESCE(ce.StartXP, 0) + a.MonsterXP + a.TreasureXP + bonus.BonusXP,
    a.TreasureShareCopper
FROM @Awards AS a
JOIN characters.CharacterExpedition AS ce
  ON ce.CharacterName=a.CharacterName AND ce.AdventureCode=@AdventureCode
 AND ce.ExpeditionNumber=@ExpeditionNumber AND ce.Active=1
JOIN characters.vCurrentLevel AS lvl ON lvl.CharacterName=a.CharacterName
CROSS APPLY
(
    SELECT CASE WHEN a.CharacterName=N'Evro' AND @ApplyEvroCurrentPRBonus=0
                THEN 0
                ELSE (a.MonsterXP+a.TreasureXP)*lvl.PrimeRequisiteXPBonusPct/100
           END AS BonusXP
) AS bonus;

PRINT N'PROPOSED XP ALLOCATION — inspect before finalising';
SELECT CharacterName, StartXP, MonsterXP, TreasureXP, OtherXP,
       PrimeRequisiteBonusXP, EndXP, EndHP, TreasureShareCopper,
       CASE WHEN CharacterName=N'Wilberd' THEN 1500-EndXP END
           AS WilberdXPRemainingToLevel2
FROM @Resolved
ORDER BY CASE CharacterName
           WHEN N'Wilberd' THEN 1 WHEN N'Ralt' THEN 2
           WHEN N'Sho-Rembo' THEN 3 WHEN N'Alho' THEN 4
           WHEN N'Pell' THEN 5 ELSE 6 END;

IF (SELECT COUNT(*) FROM @Resolved) <> 6
    THROW 52117, N'Could not resolve six participants with valid current level rows.', 1;

IF @Apply = 0
BEGIN
    PRINT N'PREVIEW ONLY. No rows changed. To commit, confirm treasure share terms and set @ApproveHalfShareTreasure=1 AND @Apply=1.';
    RETURN;
END;

IF @ApproveHalfShareTreasure <> 1
    THROW 52108, N'Cannot close: party/retainer treasure half-shares not approved. Set @ApproveHalfShareTreasure=1 only after acceptance.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @OldExpRecordDate DATE;
    SELECT @OldExpRecordDate=e.RecordDate
    FROM dbo.Expedition AS e WITH (UPDLOCK, HOLDLOCK)
    WHERE e.AdventureCode=@AdventureCode
      AND e.ExpeditionNumber=@ExpeditionNumber
      AND e.Active=1 AND e.ExpeditionStatus=N'Settlement';

    IF @OldExpRecordDate IS NULL
        THROW 52109, N'Expedition changed since preview; aborting.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Expedition
               WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=@ExpeditionNumber
                 AND RecordDate=@NewRecordDate)
        THROW 52110, N'Expedition already has a version on today''s UTC DATE; choose a later UTC date or migrate to datetime2 versioning.', 1;

    IF EXISTS (SELECT 1 FROM characters.CharacterExpedition
               WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=@ExpeditionNumber
                 AND RecordDate=@NewRecordDate)
        THROW 52111, N'Participation already has a version on today''s UTC DATE; cannot append same-day versions.', 1;

    DECLARE @OldParticipation TABLE
    (
        CharacterName NVARCHAR(60) NOT NULL PRIMARY KEY,
        RecordDate DATE NOT NULL
    );

    INSERT INTO @OldParticipation (CharacterName, RecordDate)
    SELECT ce.CharacterName, ce.RecordDate
    FROM characters.CharacterExpedition AS ce WITH (UPDLOCK, HOLDLOCK)
    WHERE ce.AdventureCode=@AdventureCode
      AND ce.ExpeditionNumber=@ExpeditionNumber
      AND ce.Active=1;

    IF (SELECT COUNT(*) FROM @OldParticipation)<>6
        THROW 52112, N'Participant set changed since preview; aborting.', 1;

    -- Preserve the existing expedition version, setting it inactive.
    UPDATE dbo.Expedition
       SET Active=0
     WHERE RecordDate=@OldExpRecordDate
       AND AdventureCode=@AdventureCode AND ExpeditionNumber=@ExpeditionNumber
       AND Active=1;

    INSERT INTO dbo.Expedition
    (
        RecordDate, AdventureCode, ExpeditionNumber, Active,
        AdventureRecordDate, ExpeditionStatus,
        GameStartDate, GameEndDate, StartLocation, EndLocation,
        FinalDungeonTurn, ClosedAtUtc, SummaryMarkdown, SettlementNotes
    )
    SELECT
        @NewRecordDate, e.AdventureCode, e.ExpeditionNumber, 1,
        e.AdventureRecordDate, N'Closed',
        e.GameStartDate, e.GameEndDate, e.StartLocation, e.EndLocation,
        e.FinalDungeonTurn, CONVERT(DATETIME2(0),SYSUTCDATETIME()),
        CONCAT(e.SummaryMarkdown,
               NCHAR(13),NCHAR(10),NCHAR(13),NCHAR(10),
               N'Expedition 12 XP/HP settlement recorded; all six returned.'),
        CONCAT(
            N'## Settlement completed',NCHAR(13),NCHAR(10),NCHAR(13),NCHAR(10),
            N'Monster XP 139: troglodyte 30; rats 15; goblins 25; stirges 39; orcs 20; conquered kobolds K2/K6 10. ',
            N'Turn-74 alleged three-orc encounter was VOID and earns zero.',NCHAR(13),NCHAR(10),
            N'Treasure XP 157 (whole XP from 157.27 gp): wine 75; goblet 15; electrum 17; copper 0.27; ',
            N'cart 50 gp appraised salvage value. Cart retained, not sold; 50 gp not paid into treasury. ',
            N'Deposit refund 15 gp, earlier tapestries 400 gp and pre-existing Sho copper excluded.',NCHAR(13),NCHAR(10),
            N'Four PCs take full shares and Pell/Evro half-shares for this settlement; ',
            N'per PC 59 and per retainer 30 base XP. Integer components apportioned to preserve totals; ',
            N'PR bonuses truncated to integer; Evro current PR bonus applied: ',
            CASE WHEN @ApplyEvroCurrentPRBonus=1 THEN N'YES' ELSE N'NO' END, N'.',NCHAR(13),NCHAR(10),
            N'Cash portion 10,727 copper allocated as settlement entitlements in CharacterExpedition; ',
            N'common treasury has not been debited or physically paid out.',NCHAR(13),NCHAR(10),
            N'EndHP captures dungeon-return HP before town rest and before historical HP maximum migration. ',
            N'Rest, spells, gear and next expedition are NOT processed here.'
        )
    FROM dbo.Expedition AS e
    WHERE e.RecordDate=@OldExpRecordDate AND e.AdventureCode=@AdventureCode
      AND e.ExpeditionNumber=@ExpeditionNumber;

    IF @@ROWCOUNT<>1
        THROW 52113, N'Could not append exactly one closed expedition version.', 1;

    UPDATE ce
       SET ce.Active=0
    FROM characters.CharacterExpedition AS ce
    JOIN @OldParticipation AS old
      ON old.RecordDate=ce.RecordDate AND old.CharacterName=ce.CharacterName
    WHERE ce.AdventureCode=@AdventureCode AND ce.ExpeditionNumber=@ExpeditionNumber
      AND ce.Active=1;

    IF @@ROWCOUNT<>6
        THROW 52114, N'Could not deactivate exactly six participation versions.', 1;

    INSERT INTO characters.CharacterExpedition
    (
        RecordDate, CharacterName, AdventureCode, ExpeditionNumber, Active,
        CharacterAdventureRecordDate, ExpeditionRecordDate,
        ParticipationRole, ParticipationStatus, StartHP, EndHP,
        StartXP, MonsterXP, TreasureXP, OtherXP,
        PrimeRequisiteBonusXP, EndXP, TreasureShareCopper, NotesMarkdown
    )
    SELECT
        @NewRecordDate, ce.CharacterName, ce.AdventureCode, ce.ExpeditionNumber, 1,
        ce.CharacterAdventureRecordDate, @NewRecordDate,
        ce.ParticipationRole, ce.ParticipationStatus, ce.StartHP, r.EndHP,
        r.StartXP, r.MonsterXP, r.TreasureXP, r.OtherXP,
        r.PrimeRequisiteBonusXP, r.EndXP, r.TreasureShareCopper,
        CONCAT(ce.NotesMarkdown, NCHAR(13),NCHAR(10),NCHAR(13),NCHAR(10),
               N'## Expedition 12 settlement',NCHAR(13),NCHAR(10),
               N'Monster XP: ',r.MonsterXP,N'; treasure XP: ',r.TreasureXP,
               N'; other XP: ',r.OtherXP,N'; PR bonus XP: ',r.PrimeRequisiteBonusXP,
               N'; final XP: ',r.EndXP,N'. Return HP before rest: ',r.EndHP,N'.',
               NCHAR(13),NCHAR(10),
               N'Allocated liquid treasure entitlement: ',r.TreasureShareCopper,
               N' cp, not yet physically paid; cart value assigned for XP only.')
    FROM characters.CharacterExpedition AS ce
    JOIN @OldParticipation AS old
      ON old.CharacterName=ce.CharacterName AND old.RecordDate=ce.RecordDate
    JOIN @Resolved AS r ON r.CharacterName=ce.CharacterName
    WHERE ce.AdventureCode=@AdventureCode
      AND ce.ExpeditionNumber=@ExpeditionNumber AND ce.Active=0;

    IF @@ROWCOUNT<>6
        THROW 52115, N'Could not append exactly six new participant versions.', 1;

    IF EXISTS (
        SELECT 1 FROM characters.CharacterExpedition
        WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=@ExpeditionNumber
          AND Active=1 AND (EndHP IS NULL OR StartXP IS NULL OR EndXP IS NULL)
    )
        THROW 52116, N'New active participant settlement remains incomplete.', 1;

    COMMIT TRANSACTION;
    PRINT N'COMMITTED: versioned B1 Expedition 12 and six participant settlements.';

    SELECT * FROM dbo.vExpeditionSettlementStatus
    WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=@ExpeditionNumber;
    SELECT CharacterName, StartXP, MonsterXP, TreasureXP,
           PrimeRequisiteBonusXP, EndXP, EndHP, TreasureShareCopper
    FROM characters.vCurrentExpeditionParticipation
    WHERE AdventureCode=@AdventureCode AND ExpeditionNumber=@ExpeditionNumber
    ORDER BY CharacterName;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
