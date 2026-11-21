

-- SELECT * FROM [dbo].[Expedition] WHERE Active = 1 AND AdventureCode = N'B1' ORDER BY ExpeditionNumber;
-- SELECT * FROM [characters].[CharacterExpedition] WHERE Active = 1 AND AdventureCode = N'B1' ORDER BY ExpeditionNumber, CharacterName;
-- SELECT CharacterName, ExpeditionNumber, StartHP, EndHP, StartXP, MonsterXP, TreasureXP, PrimeRequisiteBonusXP, EndXP FROM [characters].[CharacterExpedition] WHERE Active = 1 AND AdventureCode = N'B1' ORDER BY ExpeditionNumber, CharacterName;

-- RULES REFERENCE
-- SELECT * FROM [dbo].[ClassLevel] WHERE Active = 1 ORDER BY Class, Level;
-- SELECT * FROM [Rules].[Languages] WHERE Active = 1 ORDER BY LanguageName;
-- SELECT * FROM [Rules].[Spells] WHERE Active = 1 ORDER BY SpellClass, SpellLevel, SpellName;
-- SELECT * FROM [Rules].[Skills] WHERE Active = 1 ORDER BY AssociatedAbility, SkillName;
-- SELECT * FROM [Rules].[Weapons] WHERE Active = 1 ORDER BY WeaponName;

-- QUICK COUNTS
-- SELECT COUNT(*) AS ActiveCharacters FROM [characters].[Character] WHERE Active = 1;
-- SELECT COUNT(*) AS B1PartyMembers FROM [characters].[CharacterAdventure] WHERE Active = 1 AND AdventureCode = N'B1';
-- SELECT COUNT(*) AS B1Expeditions FROM [dbo].[Expedition] WHERE Active = 1 AND AdventureCode = N'B1';

-- HISTORICAL VERSIONS
--SELECT * FROM [characters].[Character] ORDER BY CharacterName, RecordDate DESC;
--SELECT * FROM [characters].[CharacterLevel] ORDER BY CharacterName, Level, RecordDate DESC;
--SELECT * FROM [characters].[CharacterExpedition] WHERE AdventureCode = N'B1' ORDER BY ExpeditionNumber, CharacterName, RecordDate DESC;


-- PARTY STATE
-- SELECT * FROM [dbo].[vAdventurePartyState] WHERE AdventureCode = N'B1';
-- SELECT * FROM [dbo].[vExpeditionSettlementStatus];

-- ADVENTURES AND EXPEDITIONS
-- SELECT * FROM [dbo].[vCurrentAdventure];
-- SELECT * FROM [dbo].[vCurrentExpedition];

-- CHARACTERS
-- SELECT * FROM [characters].[vCurrentCharacter];
-- SELECT * FROM [characters].[vCurrentLevel];
-- SELECT * FROM [characters].[vCurrentAppearance];
-- SELECT * FROM [characters].[vCurrentAdventureMembership];
-- SELECT * FROM [characters].[vCurrentExpeditionParticipation];

-- CHARACTER ABILITIES AND PROFICIENCIES
-- SELECT * FROM [characters].[vCurrentSpellbook];
-- SELECT * FROM [characters].[vCurrentLanguages];
-- SELECT * FROM [characters].[vCurrentWeaponFamiliarity];

-- FULL PARTY TRANSFER
--select * from Characters.CharacterSpell --where CharacterName in (select CharacterName from Characters.CharacterAdventure where AdventureCode = 'B1' and Active = 1) and Active = 1   