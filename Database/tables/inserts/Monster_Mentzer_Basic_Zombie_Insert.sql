/* Golden Braid AIDM B1 S18 Zombie — species
FILE: Monster_Mentzer_Basic_Zombie_Insert.sql
TARGET: DnD.[Rules].[Monster] (PEQUOD SQL Server 2016+)
SOURCE: 1983 Mentzer Basic Dungeon Masters Rulebook, Zombie printed p.39.
B1 stocklist selects species only; synthetic encounter is independent.
2026-11-22. Idempotent insert-only; Specified/SourceChecked NOT execution, approval or UAT.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL OR COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
 THROW 57180,'Rules.Monster v0.4 required before Zombie insert',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS (SELECT 1 FROM [Rules].[Monster] WITH(UPDLOCK,HOLDLOCK) WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'ZOMBIE')
 BEGIN
  INSERT INTO [Rules].[Monster] ([RecordDate],[RulesetCode],[MonsterCode],[Active],[MonsterName],[ParentMonsterCode],[SourceStatus],[SourceReference],[HouseRuleOverlayRefs],[ArmorClass],[HitDiceText],[AttackPattern],[DamagePattern],[SaveAs],[Morale],[MovementTurnFeet],[MovementRoundFeet],[MovementSpecialText],[Alignment],[XPValue],[NumberAppearingText],[TreasureType],[GeneralDescription],[SpecialAttacksFeatures],[SpecialEncounterFeatures],[D1Feet],[D2Feet],[ZFeet],[SizeBasis],[IllustrationPath],[MapIconPath],[NotesMarkdown])
  VALUES (CONVERT(DATE,SYSUTCDATETIME()),N'MentzerBECMI',N'ZOMBIE',0,N'Zombie',NULL,N'SourceChecked',N'Mentzer Basic 1983 Dungeon Masters Rulebook, Zombie, printed p.39; B1 monster stocklist entry #18 is species selector only.',NULL,8,N'2',N'1 claw or 1 actually equipped weapon',N'Claw 1d8; weapon by weapon rule',N'Fighter 1',12,90,30,NULL,N'Chaotic',20,N'2-8 (4-24)',N'Nil',N'Zombies are mindless, magically animated dead humans or demi-humans. Their movement and motions are stiff and ponderous. Their appearance is desiccated flesh, ragged clothing and vacant expressions; they can act as silent guardians under simple instructions from an evil magic-user or cleric. AIDM human-size modelling uses D1=5 feet, D2=5 feet and Z=6 feet, not published monster geometry. Do not invent contagion, disease, bites, transformation, toxin, supernatural fear or treasure from their appearance.',N'ZOMBIE COMBAT — Mentzer Basic 1983, printed p.39. AC 8, HD 2 (2d8 individual HP), attacks once per eligible round by CLAW for 1d8 damage OR with the ACTUALLY EQUIPPED WEAPON for its normal Mentzer weapon damage; use 1d6 generic standard weapon damage or approved Variable Weapon Damage when that option is in force. Attack as 2 HD monster; Save As Fighter 1; Morale 12; no additional attacks, disease, poisoned condition, infection or zombie transformation. UNDEAD: immune to Sleep and Charm; susceptible to Cleric Turn Undead handled by shared Turning integration, not in this monster combat fixture. An externally supported immunity beyond Sleep/Charm must have its own canonical rules source; do not infer poison immunity or other immunities from artwork or fantasy tropes. DELAYED INITIATIVE — owner-approved interpretation of the Mentzer slow Zombie/two-handed weapon initiative rule: roll ordinary side initiative 1d6 per side. Resolve ordinary eligible combatants first; Zombies and eligible two-handed-weapon users act in a delayed group. Within the delayed group, the side with higher side initiative acts first, and ties resolve simultaneously. Do not give Zombies an extra initiative die; do not conflate surprise with initiative. A two-handed weapon remains delayed even when used by an otherwise ordinary actor. Once an actor is destroyed before its action, it cannot attack; simultaneity is preserved for tied actions under the common engine.',N'ZOMBIE ENCOUNTER — Source Number Appearing 2-8 normally, (4-24) parenthetical. Zombies are mindless, unintelligent undead that may be commanded by a magic-user or cleric to guard a location or object. Encounter/DM interprets simple standing guarding orders, observed intrusions, distance, retreat, visibility, and player intention without inventing negotiation intelligence or automatic initiative before normal encounter procedure. Standard surprise: one d6 per side, surprised on 1-2 absent a verified special rule; surprise is an Encounter phase and is distinct from Combat initiative. Zombies may attack living intruders when their standing instructions call for it but the scene, not art, determines positioning and triggers. They have Treasure Type Nil; a guarded coffer belongs to the location/scene, not individual zombies'' carried treasure. Turn Undead routing is separate shared cleric/Encounter integration (AIDM-DES-001.7.10). S18 ZOMBIE-T001 consists of exactly four independent Zombies, two claws, two swords; 34 HP total; no B1 preassigned HP/count used.',5,5,6,N'Owner-established humanoid D1=D2=5 ft full diameters and human-scale estimated height Z=6 ft, following Skeleton precedent; not published Mentzer dimensions.',N'assets/monsters/AIDM_ZOMBIE_S18_Dungeon_Stock_Illustration.webp',NULL,N'S18 The Silent Guardians: 4 ordinary Zombies 7/8/10/9 HP (34 total); 14 Combat and 6 Encounter specified cases; 1 deferred Turn Undead integration case. Approved stock artwork shows two claw attackers, two equipped swords and guarded coffer. All source/case records are not execution or owner UAT.');
  PRINT N'Inserted inactive SourceChecked Zombie species';
 END ELSE PRINT N'Existing Zombie species preserved';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RulesetCode],[MonsterCode],[MonsterName],[SourceStatus],[Active],[ArmorClass],[HitDiceText],[Morale],[MovementTurnFeet],[MovementRoundFeet],[D1Feet],[D2Feet],[ZFeet],[IllustrationPath]
FROM [Rules].[Monster] WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'ZOMBIE';
GO
