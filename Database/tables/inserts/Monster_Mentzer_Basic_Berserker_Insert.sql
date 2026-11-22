/* Golden Braid / AIDM / B1 supplementary S26 Berserker species
FILE: Monster_Mentzer_Basic_Berserker_Insert.sql
TARGET: PEQUOD / DnD (SQL Server 2016+)
SOURCE: 1983 Mentzer Basic Dungeon Masters Rulebook, Berserker printed p.27;
        B1 In Search of the Unknown upper wandering table and Room 54.
DATE: 2026-11-22. SourceChecked/inactive. Idempotent INSERT-ONLY; no UAT/execution.
House rule: natural-1 melee Wild Swing with random eligible ally.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'HouseRuleOverlayRefs') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
 THROW 57300,'Rules.Monster v0.4 required before Berserker insert',1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS (SELECT 1 FROM [Rules].[Monster] WITH (UPDLOCK,HOLDLOCK)
                WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'BERSERKER')
 BEGIN
  INSERT INTO [Rules].[Monster] ([RecordDate],[RulesetCode],[MonsterCode],[Active],[MonsterName],[ParentMonsterCode],[SourceStatus],[SourceReference],[HouseRuleOverlayRefs],[ArmorClass],[HitDiceText],[AttackPattern],[DamagePattern],[SaveAs],[Morale],[MovementTurnFeet],[MovementRoundFeet],[MovementSpecialText],[Alignment],[XPValue],[NumberAppearingText],[TreasureType],[GeneralDescription],[SpecialAttacksFeatures],[SpecialEncounterFeatures],[D1Feet],[D2Feet],[ZFeet],[SizeBasis],[IllustrationPath],[MapIconPath],[NotesMarkdown])
  VALUES (CONVERT(DATE,SYSUTCDATETIME()),N'MentzerBECMI',N'BERSERKER',0,N'Berserker',NULL,N'SourceChecked',N'Mentzer Basic 1983 Dungeon Masters Rulebook, Berserker, printed p.27. B1 In Search of the Unknown upper wandering table and Room 54 are separate encounter contexts.',N'OWNER-APPROVED AIDM HOUSE RULE 2026-11-22: WILD SWING. An unmodified natural 1 on a Berserker melee attack always misses original target; if one or more active allied combatants other than self are within actual melee reach, select exactly one uniformly at random and automatically hit that ally for ordinary equipped-weapon damage. No ally in reach => ordinary miss. No second Hit roll. Does not apply to ranged attacks. This is an overlay, not printed Mentzer.',7,N'1+1*',N'1 equipped weapon per eligible round',N'By equipped weapon (normal 1d6 or canonical optional variable weapon damage)',N'Fighter 1',12,120,40,NULL,N'Neutral',19,N'1-6 (3-30)',N'(P) B',N'Ordinary human berserk fighters, often wild-eyed and tense, wearing clothing, armour and carrying equipment appropriate to the actual encounter. They can speak and react normally before a fight begins. Once fighting, they become unrelenting, sometimes swinging recklessly at comrades; narrate such frenzy without magical berserk transformation, poison, fear aura, or additional attacks.',N'BERSERKER COMBAT - Mentzer Basic 1983 p.27: AC7, HD1+1*, one attack with actually equipped weapon, by-weapon damage, Save As Fighter1, Morale12, 120ft/turn and 40ft/round movement in base species. When attacking a HUMAN OR HUMAN-LIKE creature (examples in source: kobolds, goblins and orcs), apply exactly +2 to the BERSERKER HIT ROLL, not weapon damage, Armor Class, initiative or saving throws. Do not assume all targets qualify; use validated target-type facts. Morale12: NO generic morale rolls and no voluntary surrender or withdrawal once battle begins; berserkers do not take prisoners. Source says they SOMETIMES attack comrades in blind rage but does not supply a random mechanism. APPROVED HOUSE RULE - WILD SWING: only on a MELEE attack with UNMODIFIED natural d20=1, the original target is missed EVEN IF +2 to-Hit applies; determine all other alive/active allied combatants within validated melee reach, choose one uniformly at random using recorded deterministic selection dice/entropy, automatically hit it, roll ordinary equipped melee weapon damage once; do not make a second Hit roll. Zero eligible allies means miss with no damage; do not damage self, target or any ally out of reach. Natural d20=2 or greater follows normal Hit procedure. RANGED d20=1 is an ordinary miss and does not use Wild Swing. Actor intent/eligible targeting from DM/agent is still subject to Combat validation and auditing; no special Berserker combat algorithm, extra attacks, friendly-fire splash or new status. B1 upper wandering movement override 90/30 and B1 Room54 guardian fixed HP4 are ENCOUNTER values, never the default species rules.',N'BERSERKER ENCOUNTER: Reactions are determined NORMALLY before fighting. The berserker may talk, bargain, threaten, stand off or be avoided. After combat actually starts, they fight to death, never surrender or take prisoners; blind rage may involve attacking comrades, but the chance/selection of intentional target changes is not prescribed by Mentzer. Separate from the owner-approved natural-1 Wild Swing in COMBAT. Standard one d6 surprise check per side when relevant, not an automatic ambush. Mentzer number appearing 1-6 normally, 3-30 in lair; treasure (P) B. B1 upper-level wandering monster table lists 1-2 Berserkers (HP5,4) and movement 90/30; use these only in BERSERKER-T001. B1 ROOM54 scripted treasure guardians are TWO magical human-statue figures, AC7 and fixed HP4 each, holding swords and activated only when valuables are actually touched/disturbed; their presence, state and trigger are part of scene/Encounter and confer no undocumented immunity, spell ability or surprise bonus. They fight to death upon activation and carry no individual treasure. Actual positions and reach are scene facts, not drawn from illustration.',5,5,6,N'Owner-approved human/humanoid D1=D2 full 5ft diameters, Z=6ft approximate human height; not Mentzer measurements or fixed combat reach.',N'assets/monsters/AIDM_BERSERKER_S26_Dungeon_Stock_Illustration.webp',NULL,N'B1 Berserkers are outside numbered 25-stocklist and support full B1 playthrough. Two scenario rows: BERSERKER-T001 upper level wandering HP5/4, synthetic weapons and surprise; BERSERKER-T002 Room54 two guardians HP4/4 and activation trigger. House-rule +2 is to Hit versus HUMAN-LIKE targets, and natural-1 Wild Swing overrides it. Artwork is generic stock only. SourceChecked/Active=0; insert scripts specify test cases but do not execute them or mark UAT.');
  PRINT N'Inserted inactive SourceChecked Berserker species';
 END
 ELSE PRINT N'Existing Berserker species preserved; no overwrite';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RulesetCode],[MonsterCode],[MonsterName],[SourceStatus],[Active],
 [ArmorClass],[HitDiceText],[DamagePattern],[Morale],[MovementTurnFeet],
 [MovementRoundFeet],[D1Feet],[D2Feet],[ZFeet],[IllustrationPath]
FROM [Rules].[Monster]
WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'BERSERKER';
GO
