/*
Golden Braid / AIDM / B1 S15 — Hobgoblin
File: Monster_Mentzer_Basic_Hobgoblin_Insert.sql
Table: DnD.[Rules].[Monster]
Source: Mentzer 1983 Basic Dungeon Masters Rulebook, Hobgoblin, printed p.31; B1 #15 selects species only.
Boundaries: Mentzer species/rolls, NOT B1 fixed counts/HP.
Source species ordinary plus king/bodyguard exception; D1/D2/Z estimated 5/5/6.5.
SourceChecked, inactive species; test definitions are Specified, NOT executed.
Reruns preserve existing species/fixtures; no silent rewriting of records.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL OR COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL OR COL_LENGTH(N'Rules.Monster',N'D1Feet') IS NULL
 THROW 56920, 'Rules.Monster v0.4 missing', 1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS (SELECT 1 FROM [Rules].[Monster] WITH (UPDLOCK,HOLDLOCK) WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'HOBGOBLIN')
 BEGIN
 INSERT INTO [Rules].[Monster] ([RecordDate],[RulesetCode],[MonsterCode],[Active],[MonsterName],[ParentMonsterCode],[SourceStatus],[SourceReference],[HouseRuleOverlayRefs],[ArmorClass],[HitDiceText],[AttackPattern],[DamagePattern],[SaveAs],[Morale],[MovementTurnFeet],[MovementRoundFeet],[MovementSpecialText],[Alignment],[XPValue],[NumberAppearingText],[TreasureType],[GeneralDescription],[SpecialAttacksFeatures],[SpecialEncounterFeatures],[D1Feet],[D2Feet],[ZFeet],[SizeBasis],[IllustrationPath],[MapIconPath],[NotesMarkdown]) VALUES (CONVERT(DATE,SYSUTCDATETIME()),N'MentzerBECMI',N'HOBGOBLIN',0,N'Hobgoblin',NULL,N'SourceChecked',N'Mentzer 1983 Basic Dungeon Masters Rulebook, Hobgoblin, printed p.31; B1 #15 selects species only.',NULL,6,N'1+1',N'1 attack using actually equipped weapon',N'By equipped weapon; no Hobgoblin-specific bonus',N'Fighter 1',8,90,30,N'No daylight Hit-roll penalty; can hunt outdoors.',N'Chaotic',15,N'1-6 normally (4-24 outdoors / suggested dungeon lair)',N'(Q) D',N'Large, intimidating goblin-kin, physically bigger and meaner than goblins. They live underground but hunt outdoors. Describe rough gear, aggressive expressions, armour and the weapons actually carried; group cohesion and kingly hierarchy are narrative context, not automatic attack bonuses.',N'Ordinary Hobgoblin: AC 6, HD 1+1 (1d8+1 each), one normal attack with currently equipped weapon. One legal Hit roll; successful hit deals either 1d6 under standard damage or that weapon''s approved variable damage if configured; no daylight penalty. Its ordinary morale is 8. The KING is a distinct LAIR role: 22 fixed starting HP, attacks on 5-HD monster Hit row, +2 to weapon DAMAGE rolls only (never +2 to hit), ordinary other species attributes unless separately specified. Each of 1-4 BODYGUARDS in the lair has 3-18 HP and attacks on 4-HD Hit row (not 4d8 HP). Do not turn king/bodyguard attack tiers into extra attacks, HP dice, saving throw level or separate species code without a source rule. While the king is alive AND with accompanying Hobgoblins, their morale is 10 instead of 8; if he dies/leaves, morale reverts to 8 for the next normally required morale check, not an additional automatic check. No sunlight penalty or imported goblin/dwarf hostility rule. Resolve two-handed weapon properties from equipped weapon. Do not treat an ordinary patrol as a king''s retinue.',N'Hobgoblins are goblin relatives, bigger and meaner, dwelling underground but frequently hunting outdoors; unlike goblins they have no full-daylight attack penalty. The DM may portray intimidation, guards, patrols, bargaining, retreat, ambush or command hierarchy according to the current scene; do not force combat or predetermine reaction. Mentzer dungeon number appearing 1-6; parenthetical 4-24 is wilderness number and suggested dungeon lair number, not a mandatory total inclusive/exclusive count of the king. A lair has one king and 1-4 bodyguards; whether those exceptional leaders are included in the 4-24 total is not explicit and is a synthetic fixture convention in HOBGOBLIN-T002. Their 10-morale leadership effect depends on living king physically present. A different Hobgoblin group beyond his presence uses morale 8. Standard surprise one d6 per side on 1-2, unless an approved situation changes the procedure. Physical dimensions are estimates and do not impose 5-ft combat occupancy rules.',5,5,6.5,N'AIDM approved humanoid default D1=D2=5ft full diameters; Z=6.5ft rough larger-than-goblin height estimate, not a published measurement.',N'assets/monsters/AIDM_HOBGOBLIN_S15_Stock_Illustration.webp',NULL,N'B1 #15 only selects species, not its fixed 2-5 and HP; use Mentzer 1d6 ordinary and the proposed lair 4d6 dice for 4-24. HOBGOBLIN-T001: ordinary four-person daylight patrol; HOBGOBLIN-T002: synthetic 18-actor lair including 1 king, 2 bodyguards and 15 ordinary Hobgoblins. King/bodyguard physical equipment is fixture-specific. Lair count inclusion unresolved by source: stored as a scenario convention, not universal rule. No Hobgoblin-specific new Build story automatically implied.');
 PRINT N'Inserted Hobgoblin species, SourceChecked/Active=0';
 END
 ELSE PRINT N'Existing Hobgoblin species preserved; no overwrite';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [MonsterCode],[MonsterName],[HitDiceText],[Morale],[D1Feet],[D2Feet],[ZFeet],[SizeBasis],[IllustrationPath] FROM [Rules].[Monster] WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'HOBGOBLIN' ORDER BY [RecordDate] DESC;
GO