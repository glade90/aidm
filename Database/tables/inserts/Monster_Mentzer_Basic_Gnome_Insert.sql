/* Golden Braid / AIDM / B1 S22 Gnome — species rules
FILE: Monster_Mentzer_Basic_Gnome_Insert.sql
TARGET: PEQUOD / DnD (SQL Server 2016+, Rules.Monster v0.4)
SOURCE: 1983 Mentzer Basic Dungeon Masters Rulebook, Gnome, printed p.30
ONE species row; ordinary, leader, bodyguard and chieftain are separate actor ROLE profiles.
S22 selects species; this file does not alter B1 stocked room 52 or execute tests.
2026-11-22. Rerunnable INSERT ONLY; SourceChecked / Active=0 is not UAT approval.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster', N'U') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'D1Feet') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
 THROW 57320,N'Rules.Monster v0.4 required before Gnome insert',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM [Rules].[Monster] WITH(UPDLOCK,HOLDLOCK)
   WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'GNOME')
 BEGIN
  INSERT INTO [Rules].[Monster]
  ([RecordDate],[RulesetCode],[MonsterCode],[Active],[MonsterName],[ParentMonsterCode],[SourceStatus],[SourceReference],[HouseRuleOverlayRefs],[ArmorClass],[HitDiceText],[AttackPattern],[DamagePattern],[SaveAs],[Morale],[MovementTurnFeet],[MovementRoundFeet],[MovementSpecialText],[Alignment],[XPValue],[NumberAppearingText],[TreasureType],[GeneralDescription],[SpecialAttacksFeatures],[SpecialEncounterFeatures],[D1Feet],[D2Feet],[ZFeet],[SizeBasis],[IllustrationPath],[MapIconPath],[NotesMarkdown])
  VALUES
  (CONVERT(DATE,SYSUTCDATETIME()),
   N'MentzerBECMI',
   N'GNOME',
   0,
   N'Gnome',
   NULL,
   N'SourceChecked',
   N'Mentzer Basic 1983 Dungeon Masters Rulebook, Gnome, printed p.30; B1 S22 used as stocklist species selector. Gnome rules checked against source text, 2026-11-22.',
   NULL,
   5,
   N'1',
   N'1 equipped weapon',
   N'By equipped weapon: standard 1d6 or selected approved Variable Weapon Damage; no Gnome-specific bonus',
   N'Dwarf 1',
   8,
   60,
   20,
   NULL,
   N'Lawful or Neutral',
   10,
   N'1-8 (5-40)',
   N'(P) C',
   N'Gnomes are short, bearded humanoids related to Dwarves, with prominent noses, strong mining and metalsmithing skills, a fondness for gold, gems and machinery, and 90-foot infravision. They favour crossbows and war hammers. They generally like Dwarves and war with Goblins and Kobolds, usually attacking Kobolds on sight. Narrate observable appearance, tools and behaviour without automatically forcing combat or granting a class ability.',
   N'COMBAT: Ordinary Gnome AC5, 1 HD, 1 attack with actually equipped weapon using 1-HD monster hit row, by-weapon damage, Save As Dwarf 1, morale 8, movement 60 ft per exploration turn and 20 ft per combat round. Crossbow uses standard missile ranges, cover and two-handed weapon restrictions as applicable; war hammer uses standard melee rules. No innate racial hit/damage bonus, surprise bonus, automatic attack against Kobolds or special attack. Four DISTINCT combatant role profiles, not extra species rows: ordinary Gnome 1 HD with rolled 1d8 HP; leader 11 fixed HP and attacks as 2 HD (one leader per 20 Gnomes encountered); bodyguard each 10-13 fixed starting HP and attacks as 3 HD (1-6 with lair chieftain); clan chieftain 18 fixed HP and attacks as 4 HD with +1 to DAMAGE, not to hit. The attack-as tier is distinct from actual fixed HP; do not roll 2d8, 3d8, or 4d8 for those specials. A living leader or chieftain in sight raises the morale of Gnomes who can see that figure from 8 to 10; when no qualifying living figure is visible use 8 at the NEXT source-prescribed morale check. No bonus morale check on sight change. Do not invent bodyguard defensive interception, extra attacks, special Kobold targeting bonuses, or Dwarf class features from Save As.',
   N'ENCOUNTER: Intelligent Lawful or Neutral Gnomes can observe, speak, negotiate, mine, defend treasure or withdraw. Mentzer says Gnomes USUALLY attack Kobolds on sight; the Kobold entry says Kobolds hate Gnomes and WILL attack them on sight. Record this reciprocal rivalry as encounter disposition, not Combat engine rules, bonuses or unconditional hostility toward player characters. Other Gnome versus Goblin hostility is background war, without an invented attack-on-sight rule for Goblins. Encounter handles count, group composition, role allocation, actual gear, perception, 90-ft infravision, surprise, Kobold recognition and any structured Combat handoff. Ordinary group 1-8, larger context 5-40; one 11-HP 2-HD-attack leader per 20 Gnomes; lair chieftain 18-HP 4-HD-attack +1 damage with 1-6 bodyguards 10-13 HP attacking as 3 HD. Morale 10 requires actual sight of living leader/chieftain. Default S22 synthetic encounter has only two ordinary Gnomes, no leader, bodyguards or chieftain.',
   NULL,
   NULL,
   NULL,
   N'Gnome geometry not approved: D1/D2/Z omitted rather than invent physical dimensions.',
   N'assets/monsters/AIDM_GNOME_S22_The_Miners_Watch.webp',
   NULL,
   N'S22 The Miners'' Watch, synthetic test encounter: two ordinary Gnomes at 7 and 5 HP (fixed reproducible rolls; these values also match recorded B1 room 52 HP but do not import or alter its room description or deployment). The Gnomes'' gear is one light crossbow and one war hammer. Separate leader and lair role test branches are test cases, NOT actors added to the two-Gnome base scenario. Combat and Encounter specifications are separate; no tests executed. Artwork is illustrative, never a source of rules or geometry.');
  PRINT N'Inserted inactive SourceChecked GNOME species';
 END ELSE PRINT N'Existing GNOME species preserved';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RulesetCode],[MonsterCode],[MonsterName],[SourceStatus],[Active],[ArmorClass],[HitDiceText],[Morale],[MovementTurnFeet],[MovementRoundFeet],[IllustrationPath]
FROM [Rules].[Monster] WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'GNOME';
GO
