/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Monster_Mentzer_Basic_Gnoll_Insert.sql
Repository Path : Database/tables/inserts/Monster_Mentzer_Basic_Gnoll_Insert.sql
Project         : Golden Braid / AIDM / AIDM-DES-001.7
Target          : PEQUOD, DnD.[Rules].[Monster] v0.4
Version         : 0.1.0, SourceChecked, Active=0
Source          : Mentzer 1983 Basic Dungeon Masters Rulebook, Gnoll, p.30
B1 Boundary     : S12 selects the species only; no B1 counts, HP or equipment
Dependencies    : Rules.Monster v0.4 with SpecialEncounterFeatures and D1/D2/Z
Rerun behaviour : Insert only if species absent; never overwrite past versions
===============================================================================
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL
 THROW 56800,N'Rules.Monster table missing; install schema first.',1;
IF COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'D1Feet') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'D2Feet') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
 THROW 56801,N'Rules.Monster v0.4 (encounter features/full diameters) required.',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS
 (
   SELECT 1 FROM [Rules].[Monster] WITH (UPDLOCK,HOLDLOCK)
   WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'GNOLL'
 )
 BEGIN
  INSERT INTO [Rules].[Monster]
  ([RecordDate], [RulesetCode], [MonsterCode], [Active], [MonsterName], [ParentMonsterCode], [SourceStatus], [SourceReference], [HouseRuleOverlayRefs], [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern], [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet], [MovementSpecialText], [Alignment], [XPValue], [NumberAppearingText], [TreasureType], [GeneralDescription], [SpecialAttacksFeatures], [SpecialEncounterFeatures], [D1Feet], [D2Feet], [ZFeet], [SizeBasis], [IllustrationPath], [MapIconPath], [NotesMarkdown])
  VALUES
  (CONVERT(DATE,SYSUTCDATETIME()),
   N'MentzerBECMI',
   N'GNOLL',
   0,
   N'Gnoll',
   NULL,
   N'SourceChecked',
   N'1983 Mentzer Basic Dungeon Masters Rulebook, Gnoll, printed p.30.',
   NULL,
   5,
   N'2',
   N'1 weapon',
   N'By weapon + 1',
   N'Fighter 2',
   8,
   90.00,
   30.00,
   N'Normal humanoid movement: 90 feet per turn, 30 feet per combat round.',
   N'Chaotic',
   20,
   N'1-6 normally; 3-18 in lair',
   N'(P) D',
   N'A broad-shouldered, hyena-headed humanoid with rough fur, sharp teeth and a predatory grin, equipped with stolen or scavenged weapons and coarse clothing. Gnolls are bullies and raiders, opportunistic thieves who prefer taking valuables by force or intimidation. Describe possible snarls, threats and improvised negotiations without assuming a magical fear aura. Their rumoured magical ancestry is lore rather than an established mechanical trait.',
   N'An ordinary Gnoll has exactly one attack with an actually equipped weapon, attacking as a 2 Hit Dice monster. It can use all weapons; weapon selection is supplied by Encounter or the approved actor loadout, NOT inferred from the species record. On a successful legal attack, roll that weapon''s approved damage dice and add the source-defined +1 to DAMAGE ONLY; never add +1 to the Hit roll, Armor Class, initiative, saving throws or morale. A miss neither rolls nor applies damage. Do not invent universal Gnoll weapon stats, magical attacks, poison or bonus attacks. LEADER RULE: for every 20 Gnolls encountered, one leader has fixed 16 HP and attacks on the 3 Hit Dice monster attack row. A leader does not become 3 HD for rolling hit points: use the fixed 16 HP. Leader retains the normal Gnoll by-weapon +1 damage rule; no automatic leader-specific morale aura is specified. Track species role/attack-table tier independently from current/fixed HP; no leadership variant may appear by default in a 1-6 ordinary or 3-18 lair roll.',
   N'Gnolls are hyena-like humanoids of low intelligence, strongly built, able to use all weapons. They dislike work and tend to bully and steal; a confrontation can involve robbery, threat, intimidation, bargaining, evasive manoeuvres, retreat, a stand-off, or an attack. Treat these as qualitative behaviour and player-facing opportunities, not guaranteed negotiation success or prescribed combat. Their origin as a gnome/troll magical cross is a RUMOUR, not an actual transformation or special rule. Encounter resolves the actual equipped weapons and actions; no universal weapon assumption. Number appearing: 1-6 ordinarily and 3-18 in the lair. For EVERY 20 gnolls encountered, one is a leader with 16 fixed HP and 3 HD attack-table tier; do not invent one when group size is 4. Morale is 8 and no source-defined leader morale modifier applies. No Gnoll-specific surprise threshold: use normal one d6 per side, surprised on 1-2 unless a separately established, approved scene exception applies. Ambush/avoidance, stealing and retreat are contextual decisions; neither fear nor forced player conflict is automatically imposed. B1 stocked entry S12 selects Gnoll as a species for Mentzer review only; B1 encounter counts/HP never enter this catalogue. Encounter constructs an individual roster and supplies it to Combat with approved rules and character attributes; Combat must not query SQL.',
   5.00,
   5.00,
   7.00,
   N'Owner-approved humanoid model: D1/D2 5ft FULL diameters; Z 7ft estimated (not source).',
   N'assets/images/monsters/AIDM_GNOLL_Species_Snarling_Gnoll_Illustration.webp',
   NULL,
   N'Original 1983 Mentzer Basic Dungeon Masters Rulebook, Gnoll entry, printed p.30: AC 5; HD 2; Move 90 (30); 1 weapon; Damage by weapon +1; appearing 1-6 (3-18); Save Fighter 2; Morale 8; Treasure (P) D; Chaotic; XP 20. Every 20 Gnolls, one leader fixed 16 HP attacking as 3 HD. D1=5ft and D2=5ft are approved full humanoid footprint DIAMETERS; Z=7ft is an AIDM estimate, not source stat. Fixture GNOLL-T001 count 1d6=4, four individually rolled 2d8 HP [5,14,9,10], no leader; separate eventual 20-Gnoll test needed for leadership. Original generated artwork portrays ONE representative Gnoll, so a four-Gnoll scenario has no exact-count illustration. SourceChecked and Active=0 until owner approval; SQL insertion is not SQL Server execution.');
  PRINT N'Inserted Gnoll SourceChecked inactive species.';
 END
 ELSE PRINT N'Gnoll species already exists; preserved without alteration.';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT > 0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RecordDate],[RulesetCode],[MonsterCode],[MonsterName],[SourceStatus],
       [Active],[ArmorClass],[HitDiceText],[AttackPattern],[DamagePattern],
       [D1Feet],[D2Feet],[ZFeet],[IllustrationPath]
FROM [Rules].[Monster]
WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'GNOLL'
ORDER BY [RecordDate] DESC;
GO
