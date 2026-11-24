/* Golden Braid AIDM B1 S21 Ochre Jelly — species
FILE: Monster_Mentzer_Basic_Ochre_Jelly_Insert.sql
TARGET: PEQUOD / DnD (SQL Server 2016+)
SOURCE: Mentzer Basic 1983 DM Rulebook, Ochre Jelly, printed p.35.
B1 S21 selects species only. The Seeping Passage is a separate synthetic fixture.
2026-11-22. Idempotent INSERT-ONLY; source-checked and specified != deployed or tested.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL OR COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
 THROW 57210,'Rules.Monster v0.4 required before Ochre Jelly insert',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM [Rules].[Monster] WITH(UPDLOCK,HOLDLOCK) WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'OCHRE_JELLY')
 BEGIN
  INSERT INTO [Rules].[Monster] ([RecordDate],[RulesetCode],[MonsterCode],[Active],[MonsterName],[ParentMonsterCode],[SourceStatus],[SourceReference],[HouseRuleOverlayRefs],[ArmorClass],[HitDiceText],[AttackPattern],[DamagePattern],[SaveAs],[Morale],[MovementTurnFeet],[MovementRoundFeet],[MovementSpecialText],[Alignment],[XPValue],[NumberAppearingText],[TreasureType],[GeneralDescription],[SpecialAttacksFeatures],[SpecialEncounterFeatures],[D1Feet],[D2Feet],[ZFeet],[SizeBasis],[IllustrationPath],[MapIconPath],[NotesMarkdown])
  VALUES (CONVERT(DATE,SYSUTCDATETIME()),N'MentzerBECMI',N'OCHRE_JELLY',0,N'Ochre Jelly',NULL,N'SourceChecked',N'Mentzer Basic 1983 Dungeon Masters Rulebook, Ochre Jelly, printed p.35. B1 monster stocklist #21 identifies species only.',N'AIDM owner-approved 22 Nov 2026: one-generation limit on splitting; offspring cannot create further offspring. Source rules otherwise unchanged.',8,N'5*',N'1',N'2d6 against exposed flesh; smaller offspring inflict half of normal damage',N'Fighter 3',12,30,10,N'Can seep through small cracks',N'Neutral',300,N'1 (0)',N'Nil',N'An ochre-coloured giant amoeba, an amorphous yellow-brown mass. Appearance and location are described from observable circumstances; no scripted scene, creature identification, player action, surprise, or predetermined combat. No unapproved dimensions are asserted.',N'OCHRE JELLY COMBAT (Mentzer Basic, printed p.35): AC 8; 5* HD; one attack for 2d6 damage to exposed flesh; Fighter 3 saving throws; morale 12. Fire and cold can damage it normally according to their separately validated attack/effect rules. Successful weapon or lightning attacks do NOT cause ordinary HP damage: they cause 2-5 smaller Ochre Jellies, modelled as 1d4+1, each 2 HD, with independently generated 2d8 HP; offspring deal half normal damage. An attack that misses triggers no splitting. The original Jelly is replaced by its offspring in the existing combat roster. Their creation grants no bonus actions or extra initiative rolls. Owner-approved HOUSE RULE OVERLAY: splitting is limited to one generation; offspring do not split further. Since source says only fire/cold harm this creature, a weapon hit against an offspring neither damages nor splits it without a separately approved rule. The Combat Agent must use the normal shared sequence with externally supplied dice, effects and roster changes, never a special hard-coded Jelly combat algorithm. Wood, leather and cloth may be destroyed in one round when exposed to the Jelly; no damage to metal or stone is inferred.',N'OCHRE JELLY ENCOUNTER (species properties only): amorphous creature can seep through small cracks; can destroy exposed wood, leather and cloth in one round, but cannot eat through metal or stone. Whether and when contact, discovery, avoidance, investigation, retreat, surprise, property damage or escalation occurs is determined from actual circumstances and player intentions by the future Encounter Engine. No species-level scripted ambush, seeping location, compulsory attack, dialogue, room layout or auto-surprise. Number Appearing is 1 (0), treasure Nil.',NULL,NULL,NULL,N'No owner-approved D1/D2/Z for non-humanoid Ochre Jelly; NULL rather than invented geometry.',N'assets/monsters/AIDM_OCHRE_JELLY_S21_The_Seeping_Passage.webp',NULL,N'Species-level rules only. S21 The Seeping Passage is an independent encounter test fixture. Illustration path is reserved and needs the separately approved colour WebP uploaded. 12 COMBAT and 6 ENCOUNTER tests specified; nothing executed.');
  PRINT N'Inserted inactive SourceChecked Ochre Jelly species';
 END ELSE PRINT N'Existing Ochre Jelly species preserved';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RulesetCode],[MonsterCode],[MonsterName],[SourceStatus],[Active],[ArmorClass],[HitDiceText],[Morale],[MovementTurnFeet],[MovementRoundFeet],[D1Feet],[D2Feet],[ZFeet],[IllustrationPath]
FROM [Rules].[Monster] WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'OCHRE_JELLY';
GO
