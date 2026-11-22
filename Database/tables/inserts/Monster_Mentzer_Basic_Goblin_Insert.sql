/*
===============================================================================
Golden Braid / AIDM / B1 S16 — Goblin (1983 Mentzer Basic)
FILE: Monster_Mentzer_Basic_Goblin_Insert.sql
TARGET: DnD.[Rules].[Monster] (PEQUOD, SQL Server 2016+)
SOURCE: Mentzer Dungeon Masters Rulebook, Goblin, printed p.31.
        B1 In Search of the Unknown #16 selects species ONLY;
        module-defined count, HP and scene are not imported.
NOTES: 2026-11-22. Rerunnable inserts never overwrite existing catalogue
       or test records. SourceChecked and Specified are NOT approval, test
       execution or user acceptance. SQL is not executed by commit.
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL OR COL_LENGTH(N'Rules.Monster',N'SpecialAttacksFeatures') IS NULL OR COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL OR COL_LENGTH(N'Rules.Monster',N'D1Feet') IS NULL OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
 THROW 56940,'Rules.Monster v0.4 required before Goblin insert',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS (SELECT 1 FROM [Rules].[Monster] WITH (UPDLOCK,HOLDLOCK) WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'GOBLIN')
 BEGIN
  INSERT INTO [Rules].[Monster] ([RecordDate],[RulesetCode],[MonsterCode],[Active],[MonsterName],[ParentMonsterCode],[SourceStatus],[SourceReference],[HouseRuleOverlayRefs],[ArmorClass],[HitDiceText],[AttackPattern],[DamagePattern],[SaveAs],[Morale],[MovementTurnFeet],[MovementRoundFeet],[MovementSpecialText],[Alignment],[XPValue],[NumberAppearingText],[TreasureType],[GeneralDescription],[SpecialAttacksFeatures],[SpecialEncounterFeatures],[D1Feet],[D2Feet],[ZFeet],[SizeBasis],[IllustrationPath],[MapIconPath],[NotesMarkdown])
  VALUES (CONVERT(DATE,SYSUTCDATETIME()),N'MentzerBECMI',N'GOBLIN',0,N'Goblin',NULL,N'SourceChecked',N'Mentzer Basic 1983 Dungeon Masters Rulebook, Goblin, printed p.31; B1 In Search of the Unknown stocked entry 16 used for sequence only.',NULL,6,N'1-1',N'1 attack using an actually equipped weapon',N'By equipped weapon; no innate Goblin bonus',N'Normal Man',7,90,30,NULL,N'Chaotic',5,N'2-8 dungeon room; (6-60) wilderness or suggested dungeon lair',N'(R) C',N'Goblins are small, ugly, human-like underground dwellers with pale earthy skin, from chalky tan to livid gray. Their eyes are red and may glow in weak light. Portray wary, furtive, quarrelsome or aggressive individuals carrying the weapons and armour actually present in the encounter. They are approximately four feet tall under the owner-approved AIDM estimate, with a 5-foot circular descriptive spatial footprint. Do not infer magical fear, poison, innate damage bonuses or automatic surprise advantage from their appearance.',N'ORDINARY GOBLIN COMBAT (Mentzer Basic): AC 6, HD 1-1 (one d8 minus 1 HP, minimum 1), one attack per eligible round with its ACTUALLY EQUIPPED weapon; Save As Normal Man. On a legal hit use ordinary 1d6 weapon damage or the equipped weapon''s approved Variable Weapon Damage value when that optional rule is enabled. No innate Goblin damage, Hit, Armor Class, initiative, or saving throw bonus. FULL DAYLIGHT MODIFIER: ordinary Goblins take exactly -1 to the HIT ROLL in full daylight, not to damage, Armor Class, saving throws, morale, surprise or movement. Do not apply this penalty merely because torches, lanterns, or other artificial light illuminate an underground dungeon; full daylight is the specified condition. Do not accidentally transfer the daylight penalty to Hobgoblins. Ordinary Goblin morale is 7; no leader is present in GOBLIN-T001. ROYAL LAIR EXCEPTIONS (documented species rules, NOT populated as a S16 fixture): the Goblin KING has exactly 15 HP, attacks on the THREE-HD monster attack row, and adds +1 to weapon DAMAGE only, not to Hit rolls; the KING suffers NO full-daylight Hit penalty. The king has TWO to TWELVE BODYGUARDS, each 2-12 HP and attacking on the TWO-HD monster attack row; those bodyguards also have NO daylight Hit penalty. Royal profiles refer to their attack-table tier and fixed/special HP; do not silently reroll them as 3d8 or 2d8 or grant multiple attacks. When a living king is WITH Goblins, their morale is 9 instead of 7. On death/absence, use 7 at the next normally due morale check; do not generate an extra check. Resolve equipped two-handed and missile weapon restrictions, normal modifiers, and damage mode from the canonical Mentzer weapon data, not from invented Goblin species traits. Hostility to dwarves is Encounter/reaction behaviour ONLY, not an extra Combat Hit or damage bonus.',N'Goblins inhabit underground dungeons and have INFRAVISION 90 feet, which Encounter/Geometry uses for line-of-sight and detection; it is not a Hit-roll modifier or a guaranteed ambush. Goblins HATE DWARVES and attack dwarves on sight according to their source description; model this as encounter intent/reaction, not a mandatory bypass of player agency, a racial attack bonus or compulsory combat if avoidance is possible. Their number appearing is 2-8 ordinarily and (6-60) in wilderness / suggested dungeon lair. In OUTDOOR encounters there is a 20 percent chance that one in every four Goblins rides a DIRE WOLF; this does not apply to the indoor GOBLIN-T001 scene. Dire Wolf selection, mounted position, rider/mount actor identities and movement are Encounter/Geometry responsibilities; do not invent mounted combat bonuses. A lair has a Goblin KING and 2-12 bodyguards, with leader-presence/court composition supplied explicitly by Encounter only when a lair is actually designed. The king and bodyguards have daylight Combat exceptions documented in SpecialAttacksFeatures. For an ordinary encounter without the king, base morale is 7 and no special leader actor appears. An ordinary dungeon encounter uses one normal d6 surprise roll PER SIDE, surprised on 1-2, unless a separately supported scene rule changes it. Encounter determines approach, parley opportunity, ambush plausibility, retreat, positioning and target selection from the fiction and player intentions, not invented automatic mechanics. AIDM S16 test fixture is ONE non-lair torchlit dungeon encounter; the later B1 S25 Goblin entry is not merged into this fixture.',5.0,5.0,4.0,N'Owner-approved humanoid D1=D2=5ft full diameters; Z=4ft estimated Goblin height, not a stated Mentzer measurement.',N'assets/monsters/AIDM_GOBLIN_S16_Dungeon_Stock_Illustration.webp',NULL,N'Owner approved Z=4ft and one normal non-lair Goblin scenario. Related future B1 stocked entry S25 has its own placement but does not create a new Goblin species. One ordinary test fixture GOBLIN-T001, with no king, bodyguards or wolves. Royal combat exceptions documented only. No new Goblin-only build story implied.');
  PRINT N'Inserted inactive source-checked Goblin species';
 END
 ELSE PRINT N'Existing Goblin species preserved; not overwritten';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RecordDate],[RulesetCode],[MonsterCode],[MonsterName],[SourceStatus],[Active],[ArmorClass],[HitDiceText],[Morale],[D1Feet],[D2Feet],[ZFeet],[IllustrationPath],LEN([SpecialAttacksFeatures]) AS [CombatFeatureChars]
FROM [Rules].[Monster]
WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'GOBLIN'
ORDER BY [RecordDate] DESC;
GO