/*
Golden Braid / AIDM — Mentzer Basic Black Widow Spider
File: Database/tables/inserts/Monster_Mentzer_Basic_Black_Widow_Spider_Insert.sql
Target: PEQUOD DnD.[Rules].[Monster] (v0.4)
Source: 1983 Mentzer Basic DM Rulebook Giant Spider p37, Players Manual Web.
Status: SourceChecked, Active=0 until approval. Idempotent. No B1 stat imports.
*/
USE [DnD];
GO
IF OBJECT_ID(N'Rules.Monster',N'U') IS NULL
 THROW 56670, 'Rules.Monster missing', 1;
IF COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'D1Feet') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'D2Feet') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'ZFeet') IS NULL
 THROW 56671, 'Rules.Monster v0.4 with special Encounter and diameters required', 1;
GO
SET XACT_ABORT ON;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS (SELECT 1 FROM [Rules].[Monster] WITH (UPDLOCK,HOLDLOCK)
                WHERE [RulesetCode]=N'MentzerBECMI'
                  AND [MonsterCode]=N'GIANT_BLACK_WIDOW_SPIDER')
 BEGIN
   INSERT INTO [Rules].[Monster]
   ([RecordDate], [RulesetCode], [MonsterCode], [Active], [MonsterName], [ParentMonsterCode], [SourceStatus], [SourceReference], [HouseRuleOverlayRefs], [ArmorClass], [HitDiceText], [AttackPattern], [DamagePattern], [SaveAs], [Morale], [MovementTurnFeet], [MovementRoundFeet], [MovementSpecialText], [Alignment], [XPValue], [NumberAppearingText], [TreasureType], [GeneralDescription], [SpecialAttacksFeatures], [SpecialEncounterFeatures], [D1Feet], [D2Feet], [ZFeet], [SizeBasis], [IllustrationPath], [MapIconPath], [NotesMarkdown])
   VALUES
   (CONVERT(DATE,SYSUTCDATETIME()),
    N'MentzerBECMI',
    N'GIANT_BLACK_WIDOW_SPIDER',
    0,
    N'Giant Black Widow Spider',
    NULL,
    N'SourceChecked',
    N'Mentzer 1983 Basic Dungeon Masters Rulebook, Giant Spider / Black Widow, printed p.37; Players Manual Web spell.',
    NULL,
    6,
    N'3*',
    N'1 bite',
    N'2d6 + poison',
    N'Fighter 2',
    8,
    60.00,
    20.00,
    N'Within own webs: movement 120ft/turn (40ft/round), otherwise 60ft/turn (20ft/round).',
    N'Neutral',
    50,
    N'1-3 normally; 1-3 in lair',
    N'U',
    N'An enormous carnivorous black spider, approximately six feet long, glossy dark-bodied and carrying a red hourglass mark on its underside. It waits in or near thick webbed underground lairs, surrounded by strands that can obstruct passage and entangle prey. Its movements are deliberate and animal-like. Describe the trapped paths, strands, furtive legs, and prey-driven menace without turning purely descriptive details into automatic effects.',
    N'The Black Widow Spider has one bite attack per eligible combat round, with a normal Hit roll. On a miss, it inflicts no damage, consumes no damage roll and never triggers a poison saving throw. On a successful bite, roll and apply 2d6 normal HP damage, then the ACTUAL bitten victim makes a Saving Throw vs Poison using the victim''s approved save profile. There is NO +2 bonus to this save (that bonus applies to the different Crab Spider species). On a successful save, the victim keeps normal bite damage but avoids venom. On a failed save, apply the generic source-attributed POISONED condition with a pending source-defined lethal deadline ONE DUNGEON TURN after the poisoning, unless successfully prevented/cured by an applicable approved rule. Do not inflict immediate additional venom HP damage or immediate death when the saving throw fails. Duration/timekeeper, treatment, delayed death and persistence belong to the generic poison lifecycle (AIDM-DES-001.7.7). Distinguish 2d6 bite damage from 1d8 Crab Spider bite, and preserve actor ID, one saving throw, time provenance and event log. Webs are NOT an extra bite attack or a ranged web shot: they are static/environmental hazards loaded by Encounter and governed by generic Web spell escape rules. Do not invent automatic web restraint on each bite or treat it as poison.',
    N'A six-foot-long Black Widow Spider with a distinctive red hourglass on its underside normally stays close to its webbed lair. Its lair webs are natural environmental obstacles that may entangle victims and block passage; for CHANCES/TIMES OF BREAKING FREE, Mentzer explicitly refers to the Magic-User Web spell. An average human of Strength 9-12 takes 2d4 dungeon turns to escape; giants and other greatly strong creatures break through in 2 rounds; a wearer of Gauntlets of Ogre Power escapes in 4 rounds. The spider''s webs MAY BE BURNED AWAY. The monster entry does NOT expressly import all of the spell''s fire mechanics: do not automatically import the magical Web spell''s exact two-round burning period, 1d6 burns to occupants, created spell volume, casting range, 48-turn duration, or magic dispel interactions into natural spider silk without source review/approved adjudication. Distinguish web entrapment from combat POISONED; generic WEB_ENTANGLED status and escape geometry belong to Encounter/Geometry/state lifecycle, not a new attack. Black Widow movement is 60 ft per turn / 20 ft per round outside its webs, and 120 ft / 40 ft within webs. Like giant spiders generally, it is carnivorous, rarely intelligent and often flees fire; this provides animal behaviour and tactical avoidance, not a source-defined automatic Hit/AC/fear/morale modifier. Players may threaten with fire, distract, stand off, avoid, retreat or try other approaches; there is no guarantee of intelligent negotiation. Number appearing 1-3 normally and in lair. No Black Widow-specific exception to the usual two-side d6 surprise threshold (1-2) is specified; never borrow Crab Spider camouflage 1-4. Encounter owns the web hazard, spatial exposure, web escape attempts, surprise, threat response and any noncombat choices, and delivers prepared combat roster and adjudicated initial state to Combat. B1 S10 selects this SPECIES only, not its module encounter HP/counts.',
    6.00,
    4.00,
    2.50,
    N'Six-foot length source-backed; four-foot width and two-and-a-half-foot height are owner-approved ellipse model estimates (D1/D2 FULL diameters).',
    N'assets/images/monsters/AIDM_WIDOW_Species_Black_Widow_Illustration.webp',
    NULL,
    N'Mentzer 1983 Basic D&D Dungeon Masters Rulebook, Giant Spider table and Black Widow text, printed p.37; Players Manual second-level Magic-User Web spell for explicitly referenced escape mechanics. Species rules: AC6, HD3*, movement 60(20); in web 120(40); 1 bite for 2d6 plus poison; 1-3 (1-3) appearing; save Fighter2; morale8; treasure U; Neutral; XP50. Successful bite causes Poison save or death 1 turn later. Escape from natural web uses Web spell breakout guidance, but exact transfer of magical spell fire timing/damage is unresolved. Owner-approved modelling size D1=6ft FULL length (source), D2=4ft width and Z=2.5ft height (estimates), not attack reach or official monster size. Current supplied artwork depicts ONE widow only; TWO-widow scenario does not automatically reuse a one-spider illustration as encounter-specific art. Species image is committed to assets/images/monsters/AIDM_WIDOW_Species_Black_Widow_Illustration.webp; scenario of TWO spiders still deliberately has no dedicated encounter picture.');
   PRINT N'Black Widow Spider species inserted, SourceChecked and inactive.';
 END
 ELSE PRINT N'Black Widow Spider species already present; preserved.';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RulesetCode],[MonsterCode],[RecordDate],[MonsterName],
       [ArmorClass],[HitDiceText],[DamagePattern],
       [D1Feet],[D2Feet],[ZFeet],
       [SourceStatus],[Active],[IllustrationPath]
FROM [Rules].[Monster]
WHERE [RulesetCode]=N'MentzerBECMI'
 AND [MonsterCode]=N'GIANT_BLACK_WIDOW_SPIDER'
ORDER BY [RecordDate] DESC;
GO
