/*
Golden Braid / AIDM — Normal Bat species
Repository path: Database/tables/inserts/Monster_Mentzer_Basic_Normal_Bat_Insert.sql
Source: Frank Mentzer, 1983 D&D Basic Dungeon Masters Rulebook,
        printed p.25, Bat / Normal Bats (the original table headers
        appear reversed; 1/4-HD/confusion is NORMAL, 2-HD/bite is GIANT).
NOT B1: no B1 scene, swarm probabilities, room triggers or scripted features.
SourceChecked and Specified mean review-quality data, NOT executable UAT.
2026-11-22; idempotent INSERT-ONLY. No updates to existing data.
*/
USE [DnD];
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'Rules.Monster', N'U') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'SpecialEncounterFeatures') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'D1Feet') IS NULL
 OR COL_LENGTH(N'Rules.Monster',N'HouseRuleOverlayRefs') IS NULL
 THROW 57410,N'Rules.Monster v0.4 is required before inserting Normal Bat',1;
GO
BEGIN TRY
 BEGIN TRAN;
 IF NOT EXISTS
 (SELECT 1 FROM [Rules].[Monster] WITH(UPDLOCK,HOLDLOCK)
  WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'NORMAL_BAT')
 BEGIN
  INSERT INTO [Rules].[Monster]
(
    [RecordDate],
    [RulesetCode],
    [MonsterCode],
    [Active],
    [MonsterName],
    [ParentMonsterCode],
    [SourceStatus],
    [SourceReference],
    [HouseRuleOverlayRefs],
    [ArmorClass],
    [HitDiceText],
    [AttackPattern],
    [DamagePattern],
    [SaveAs],
    [Morale],
    [MovementTurnFeet],
    [MovementRoundFeet],
    [MovementSpecialText],
    [Alignment],
    [XPValue],
    [NumberAppearingText],
    [TreasureType],
    [GeneralDescription],
    [SpecialAttacksFeatures],
    [SpecialEncounterFeatures],
    [D1Feet],
    [D2Feet],
    [ZFeet],
    [SizeBasis],
    [IllustrationPath],
    [MapIconPath],
    [NotesMarkdown]
)
VALUES
(    CONVERT(DATE,SYSUTCDATETIME()),
    N'MentzerBECMI',
    N'NORMAL_BAT',
    0,
    N'Normal Bat',
    NULL,
    N'SourceChecked',
    N'1983 Mentzer D&D Basic Dungeon Masters Rulebook, Bat, printed p.25; printed two-column Normal/Giant headings appear transposed. Description and 1/4-HD confusion entry identify Normal Bats.',
    NULL,
    6,
    N'1/4 (1 HP)',
    N'Confusion; minimum 10 bats flying about one character''s head',
    N'Nil; no ordinary damaging bite attack',
    N'Normal Man',
    6,
    9,
    3,
    N'FLY 120 ft / dungeon turn, 40 ft / combat round; 9/3 is ground movement.',
    N'Neutral',
    5,
    N'1-100 (1-100)',
    N'Nil',
    N'Normal bats are small, nocturnal, flying insectivores commonly found in caves and abandoned buildings. They navigate by echolocation despite very weak eyes. They do not normally attack people, though groups may circle a character''s head. These are intrinsic species characteristics, not a scripted scene or a mandatory combat encounter.',
    N'COMBAT (Mentzer Basic p25): Normal Bat AC6, 1/4 HD with exactly 1 HP each; Attack: Confusion, Damage: Nil. At least TEN bats must be actively circling one character to confuse THAT character; ten total bats elsewhere in a room do not automatically confuse anyone. The confused victim suffers -2 on Hit Rolls AND -2 on Saving Throws, and cannot cast spells. The Bat entry supplies no attack Hit roll, confusion saving throw, normal bite damage, stacking formula, onset probability, duration, or explicit ending rule; do not invent them. The generic CONFUSED state must carry this BAT-specific effect profile and source; it is separate from CHARMED, NAUSEATED, PARALYZED and POISONED. One bat has 1 HP and is a separate target; a group is NOT a single 100-HP combatant. Morale 6: NORMAL bats check morale EACH combat round unless controlled or summoned; use ordinary 2d6 morale outcomes (over 6 => attempt withdrawal), not additional ordinary triggers. Silence 15'' Radius effectively BLINDS bats by disrupting echolocation; basic blindness prevents movement and attack, unless owner separately adopts the printed optional blind-combat rules. Sight-dependent spells such as Light do not blind Normal Bats.',
    N'ENCOUNTER (Mentzer Basic p25): Nocturnal insectivores inhabit caves and abandoned structures; they may be active in dark dungeons in daylight. Bats find their way by sound/echo, not sight. Spells affecting sight (e.g., Light) have no effect on bats'' ability to perceive; Silence 15'' Radius effectively blinds them when actually within the spell radius. Ground move 9 ft/turn (3 ft/round); flying move 120 ft/turn (40 ft/round). Number appearing 1-100 (1-100) is chosen for an actual encounter; do not force hostility, agitation, one fixed group formation or which character is circled. The Encounter Engine decides actual bat presence, positions, circling counts per victim, surprise, reaction and any COMBAT handoff. Their only special attack is the source-defined confusion effect; no general attack on humans. No source-specific swarm room light/noise trigger or automatic wandering-monster consequences are intrinsic species abilities.',
    NULL,
    NULL,
    NULL,
    N'No source-verified normal-bat body dimensions; geometry left NULL rather than inventing size or flight reach.',
    N'assets/monsters/AIDM_NORMAL_BAT_Species_Cavern_Illustration.webp',
    NULL,
    N'Generic normal-bat catalogue; separately recorded synthetic fixture NORMAL_BAT-T001 contains 93 individual 1-HP bats, not a swarm HP pool. No house rules have been approved for Normal Bats. Unspecified confusion expiry and removal after dispersion are deferred to future owner ruling. Condition implementation tracked by AIDM-DES-001.7.11, outside this species insert. Species SourceChecked/Active=0; artwork is illustrative only.'
);
  PRINT N'Inserted inactive SourceChecked NORMAL_BAT species';
 END
 ELSE PRINT N'Existing NORMAL_BAT species preserved';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
SELECT [RecordDate],[RulesetCode],[MonsterCode],[MonsterName],[SourceStatus],
       [Active],[ArmorClass],[HitDiceText],[Morale],[MovementTurnFeet],
       [MovementRoundFeet],[MovementSpecialText],[IllustrationPath]
FROM [Rules].[Monster]
WHERE [RulesetCode]=N'MentzerBECMI' AND [MonsterCode]=N'NORMAL_BAT'
ORDER BY [RecordDate] DESC;
GO
