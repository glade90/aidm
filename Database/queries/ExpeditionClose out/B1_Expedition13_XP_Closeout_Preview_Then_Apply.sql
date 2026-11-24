/*
  B1 Expedition 13: CREATE the missing expedition DIRECTLY AS CLOSED.
  Why: prior E13 script (53103) requires a pre-existing Settlement record.
  Because version RecordDate is DATE, staging + closing on the same day may
  collide; a single final insertion is appropriate for this missing record.

  SAFETY: @Apply=0 previews without writes. @Apply=1 inserts 1 master + 6
  participant rows in one transaction, only after E12 is Closed and XP agrees.
  There is no UPDATE/DELETE and no write to the treasury, inventory, or XP cache.
  Any existing E13 row blocks insertion. Make a database backup before writes.

  After-rest HP are known; start-of-E13 HP and dungeon-return HP are not
  explicitly verified in the supplied settlement. Both remain NULL by default,
  with after-rest HP in notes. Set @UseFullHPAsStart=1 ONLY if independently
  verified that all six entered Expedition 13 at full HP.
*/
USE [DnD];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply bit=0;                    -- PREVIEW=0; WRITE=1
DECLARE @UseFullHPAsStart bit=0;         -- leave 0 unless verified
DECLARE @Day date=CONVERT(date,SYSUTCDATETIME());
DECLARE @A nvarchar(100)=N'B1';

DECLARE @Awards TABLE (
  CharacterName nvarchar(60) PRIMARY KEY,
  PriorXP int NOT NULL, MonsterXP int NOT NULL, TreasureXP int NOT NULL,
  PRBonusXP int NOT NULL, FinalXP int NOT NULL, FullHP smallint NOT NULL
);
INSERT INTO @Awards VALUES
 (N'Alho',59,44,15,0,118,8),
 (N'Evro',33,22,8,3,66,8),
 (N'Pell',298,22,8,0,328,8),
 (N'Ralt',1167,44,15,5,1231,4),
 (N'Sho-Rembo',974,45,14,0,1033,9),
 (N'Wilberd',1144,44,15,5,1208,6);

IF (SELECT COUNT(*) FROM @Awards)<>6 OR
   (SELECT SUM(MonsterXP) FROM @Awards)<>221 OR
   (SELECT SUM(TreasureXP) FROM @Awards)<>75 OR
   (SELECT SUM(PRBonusXP) FROM @Awards)<>13 OR
   EXISTS (SELECT 1 FROM @Awards WHERE PriorXP+MonsterXP+TreasureXP+PRBonusXP<>FinalXP)
  THROW 53201,N'Expected XP allocations failed internal checks.',1;

PRINT 'PREVIEW: E12 status (must be Closed before writing E13)';
SELECT ExpeditionNumber,RecordDate,Active,ExpeditionStatus
FROM dbo.Expedition WHERE AdventureCode=@A AND ExpeditionNumber=12 AND Active=1;

PRINT 'PREVIEW: E13 existing records (must be none)';
SELECT ExpeditionNumber,RecordDate,Active,ExpeditionStatus
FROM dbo.Expedition WHERE AdventureCode=@A AND ExpeditionNumber=13;

PRINT 'PREVIEW: E12 banked XP vs proposed E13 awards';
SELECT a.CharacterName, ce.EndXP AS E12EndXP, a.PriorXP AS ExpectedE13StartXP,
       a.MonsterXP, a.TreasureXP, a.PRBonusXP, a.FinalXP AS E13EndXP,
       CASE WHEN ce.EndXP=a.PriorXP THEN N'OK' ELSE N'NOT READY' END AS XPCheck,
       CASE WHEN @UseFullHPAsStart=1 THEN a.FullHP ELSE NULL END AS ProposedStartHP,
       CAST(NULL AS smallint) AS ReturnEndHP_Unverified,
       a.FullHP AS KnownHPAfterTownRest
FROM @Awards a
LEFT JOIN characters.CharacterExpedition ce
 ON ce.CharacterName=a.CharacterName AND ce.AdventureCode=@A
 AND ce.ExpeditionNumber=12 AND ce.Active=1
ORDER BY a.CharacterName;

IF @Apply=0
BEGIN
  PRINT 'PREVIEW ONLY. No database changes. Review E12 Closed and XPCheck=OK, then set @Apply=1.';
  RETURN;
END;

BEGIN TRY
  BEGIN TRANSACTION;
  IF (SELECT COUNT(*) FROM dbo.Expedition WITH (UPDLOCK,HOLDLOCK)
      WHERE AdventureCode=@A AND ExpeditionNumber=12
        AND Active=1 AND ExpeditionStatus=N'Closed')<>1
    THROW 53202,N'Expedition 12 is not Closed. Commit its closeout first.',1;

  IF EXISTS (SELECT 1 FROM dbo.Expedition WITH (UPDLOCK,HOLDLOCK)
             WHERE AdventureCode=@A AND ExpeditionNumber=13)
     OR EXISTS (SELECT 1 FROM characters.CharacterExpedition WITH (UPDLOCK,HOLDLOCK)
                WHERE AdventureCode=@A AND ExpeditionNumber=13)
    THROW 53203,N'Expedition 13 already exists (in whole or in part); refusing duplicates.',1;

  IF (SELECT COUNT(*) FROM characters.CharacterExpedition WITH (UPDLOCK,HOLDLOCK)
      WHERE AdventureCode=@A AND ExpeditionNumber=12
        AND Active=1 AND ParticipationStatus=N'Returned')<>6
    THROW 53204,N'E12 does not contain exactly six active Returned participants.',1;

  IF EXISTS (SELECT 1 FROM @Awards a LEFT JOIN characters.CharacterExpedition ce
             ON ce.CharacterName=a.CharacterName AND ce.AdventureCode=@A
             AND ce.ExpeditionNumber=12 AND ce.Active=1
             WHERE ce.CharacterName IS NULL OR ce.EndXP IS NULL
                OR ce.EndXP<>a.PriorXP OR ce.CharacterAdventureRecordDate IS NULL
                OR ce.ParticipationRole IS NULL)
    THROW 53205,N'E12 character identity, role or final XP does not match E13 starting XP.',1;

  IF EXISTS (SELECT 1 FROM characters.CharacterExpedition ce
             LEFT JOIN @Awards a ON a.CharacterName=ce.CharacterName
             WHERE ce.AdventureCode=@A AND ce.ExpeditionNumber=12
               AND ce.Active=1 AND a.CharacterName IS NULL)
    THROW 53206,N'Unexpected active E12 participant.',1;

  IF (SELECT COUNT(*) FROM dbo.Expedition
      WHERE AdventureCode=@A AND ExpeditionNumber=12 AND Active=1
        AND AdventureRecordDate IS NOT NULL)<>1
    THROW 53207,N'E12 AdventureRecordDate relationship unavailable.',1;

  IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.Expedition')
       AND name IN (N'GameStartDate',N'GameEndDate') AND is_nullable=0)
    THROW 53208,N'DB requires dates; actual E13 in-world start/end dates unverified.',1;

  IF @UseFullHPAsStart=0 AND EXISTS
     (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'characters.CharacterExpedition')
      AND name=N'StartHP' AND is_nullable=0)
    THROW 53209,N'DB requires E13 StartHP; verify the actual six start HP first.',1;

  INSERT INTO dbo.Expedition
   (RecordDate,AdventureCode,ExpeditionNumber,Active,AdventureRecordDate,
    ExpeditionStatus,GameStartDate,GameEndDate,StartLocation,EndLocation,
    FinalDungeonTurn,ClosedAtUtc,SummaryMarkdown,SettlementNotes)
  SELECT @Day,e.AdventureCode,13,1,e.AdventureRecordDate,N'Closed',
         NULL,NULL,N'Town',N'Town',74,CONVERT(datetime2(0),SYSUTCDATETIME()),
         N'B1 Expedition 13: six adventurers returned from Quasqueton at dungeon Turn 74; fourteen days of rest and magic-item identification completed.',
         CONCAT(N'Final E13 settlement: monster XP 221 (early 95, Room 51 orcs 30, stairway orcs 60, troglodyte 30, centipede 6); ',
                N'treasure XP 75 (three barrels at 25 gp); 97 cp recovered but no extra whole XP; 15 gp deposit refund 0 XP; ',
                N'Chain Mail +1 kept/unassigned 0 XP; cart previously settled in E12, not awarded again. ',
                N'Four full XP shares plus two half retainer shares, PR bonus total 13. ',
                N'Three barrels returned to cooper, cart kept, Magister Orsel Vane identification fee 50 gp. ',
                N'Common treasury after settlement 2829 gp 5 sp 4 cp. No cash entitlements paid or assigned. ',
                N'After 14 days, all six at full HP. Exact dungeon-return HP unverified (EndHP NULL). ',
                N'No treasury, gear, or standalone character XP cache modifications made.')
  FROM dbo.Expedition e
  WHERE e.AdventureCode=@A AND e.ExpeditionNumber=12
    AND e.Active=1 AND e.ExpeditionStatus=N'Closed';
  IF @@ROWCOUNT<>1 THROW 53210,N'New E13 master insertion failed.',1;

  INSERT INTO characters.CharacterExpedition
    (RecordDate,CharacterName,AdventureCode,ExpeditionNumber,Active,
     CharacterAdventureRecordDate,ExpeditionRecordDate,ParticipationRole,
     ParticipationStatus,StartHP,EndHP,StartXP,MonsterXP,TreasureXP,
     OtherXP,PrimeRequisiteBonusXP,EndXP,TreasureShareCopper,NotesMarkdown)
  SELECT @Day,ce.CharacterName,@A,13,1,ce.CharacterAdventureRecordDate,@Day,
         ce.ParticipationRole,N'Returned',
         CASE WHEN @UseFullHPAsStart=1 THEN a.FullHP ELSE NULL END,
         NULL,ce.EndXP,a.MonsterXP,a.TreasureXP,0,a.PRBonusXP,a.FinalXP,
         NULL,
         CONCAT(N'E13 XP: monster ',a.MonsterXP,N'; treasure ',a.TreasureXP,
                N'; PR bonus ',a.PRBonusXP,N'; final XP ',a.FinalXP,N'. ',
                N'StartHP ',CASE WHEN @UseFullHPAsStart=1 THEN N'verified full' ELSE N'not verified (NULL)' END,
                N'; EndHP at dungeon return UNVERIFIED (NULL). After 14 days in town: ',
                a.FullHP,N'/',a.FullHP,N' HP. Individual cash payout/entitlement not recorded.')
  FROM characters.CharacterExpedition ce
  JOIN @Awards a ON a.CharacterName=ce.CharacterName
  WHERE ce.AdventureCode=@A AND ce.ExpeditionNumber=12
    AND ce.Active=1 AND ce.ParticipationStatus=N'Returned';
  IF @@ROWCOUNT<>6 THROW 53211,N'New E13 participant insertion did not produce six rows.',1;

  COMMIT TRANSACTION;
  PRINT 'COMMITTED: 1 new Closed E13 expedition and 6 participant records; E12 unchanged.';
  SELECT AdventureCode,ExpeditionNumber,RecordDate,Active,ExpeditionStatus
  FROM dbo.Expedition WHERE AdventureCode=@A AND ExpeditionNumber=13;
  SELECT CharacterName,StartXP,MonsterXP,TreasureXP,PrimeRequisiteBonusXP,
         EndXP,StartHP,EndHP
  FROM characters.CharacterExpedition
  WHERE AdventureCode=@A AND ExpeditionNumber=13 AND Active=1
  ORDER BY CharacterName;
END TRY
BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
GO
