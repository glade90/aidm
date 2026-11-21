/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Character_Sho-Rembo_Insert.sql
Repository Path : Database/tables/Character_Sho-Rembo_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Sho's immutable character identity and full Markdown history.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : characters
Table           : characters.Character
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql (version 1.1.1)

DESIGN NOTES
- Sho is a female Halfling, Neutral, and was previously Brandon's retainer.
- INITIAL AGE 25 IS PROVISIONAL, chosen to make required InitialAge runnable.
  Confirm or edit @InitialAge BEFORE executing; historical age not established.
- First adventure/expedition information belongs in CharacterAdventure.
- Scores 9/11/9/18/9/15 are final after the unsuccessful 3d6 reroll.
- BackStory is stored as Markdown in NVARCHAR(MAX), no image link.
- No existing active record is overwritten. If one differs, stop for review.

CHANGE LOG
Date         Version   Change
-----------  --------  ------------------------------------------------------
2026-10-18   1.0.0     Initial Sho-Rembo insert, reflecting approved character
                        concept and expedition records.
===============================================================================
*/

USE [DnD];
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'characters.Character', N'U') IS NULL
    THROW 52100, 'Missing characters.Character.', 1;
GO

DECLARE @InitialAge SMALLINT = 25; -- PROVISIONAL: user has not yet specified Sho's age.
DECLARE @BackStory NVARCHAR(MAX) =
    CONVERT(NVARCHAR(MAX), N'# Sho-Rembo — The Laughing Arrow

## The Family That Never Ended

Sho-Rembo grew up on a farm where the dinner table was seldom large enough and nobody could remember who had borrowed the last clean plate. She is one of **eighteen children**—seventeen brothers and sisters—and claims, with a straight face, to have **182 cousins**. Anyone who doubts the number is invited to attend the next family gathering and count them. Sho recommends bringing a tent.

The farm was not an unhappy place. Quite the opposite. It was loud, muddy, busy, full of arguments that lasted five minutes and stories that lasted five hours. Everyone worked. Everyone ate. Everyone had an opinion. A child who wanted to be heard had to learn to speak clearly, speak amusingly, or climb onto the table. Sho became good at all three.

She learned to mend fences, handle animals, barter at markets, drive a cart, carry more than seemed reasonable for someone her size, and spot trouble before it spoiled the harvest. She also learned that even a fine farm can feel too small to contain an ambitious imagination.

## The Bow and the Laugh

Sho took naturally to shooting. Farm life supplied the practice: targets nailed to old boards, small game beyond the fields, and contests with siblings who could never agree on the rules. She considers herself a first-rate archer, and years of repetition have given her confidence with a bow. Her ordinary Dexterity score does not tell the whole story of that practiced skill—but it does not grant her any invented game bonus, either. The Halfling''s normal missile advantage is the one she')
        + N' has earned under the rules.

She was never the strongest child in the family, and she knows it. Her talent is staying power. She can keep working after others are tired, take a knock that would flatten a larger traveller, and return to the conversation with a joke. Sho believes that people underestimate the usefulness of a small person who refuses to stay down.

Then there is the laughter. Sho talks easily to strangers, befriends innkeepers, and remembers the names of people''s children. When the party needs a friendly voice rather than a threat, hers is often the first one heard. She loves people, teasing, stories, hearty steaks and proper ale. A table with good company around it is as precious to her as a bag of coin.

## Brandon''s Retainer

Sho did not enter Quasqueton as a grand hero. By the party''s present recollection, she first joined **Brandon''s service around B1 Expedition 3**, hired as a retainer. The expedition number remains provisional until we reconcile the older records. She brought a willingness to work, an experienced bow hand, an irrepressible sense of humour, and an astonishing resistance to hardship.

The work changed her. What began as employment became a place in the company. At some later, not-yet-dated point, Sho ceased to be simply Brandon''s hired help and became a player character in her own right. Brandon''s death is part of the company''s history, but it did not end Sho''s story. She stayed.

The others discovered that she could stand in the front line with hand axe and shield when a fighter needed relief, or fall back to the middle ranks and shoot '
        + N'when a bow was available. Her strength was never tremendous; her endurance was. She was willing to move wherever the line was thinnest, sometimes spelling the much bigger Evro or Alho.

## Quasqueton

She has already earned her place in the caverns. In Zelligar''s laboratory she felled a wandering berserker with her hand axe. In Rogahn''s old training room she climbed a hanging rope to inspect the ceiling. On Expedition 12, when giant rats attacked the barrel-hauling party, Sho struck down a rat even as its bite tore into her. She survived without contracting disease and later recovered after drinking from the strange healing pool.

Sho calls such incidents ''occupational hazards''—a phrase she delivers with a grin, preferably from a chair near the fire. Nevertheless, she has learned caution in the dungeon. Laughing at danger does not mean being blind to it.

Her bow and arrows have since been passed along to Alho. For now Sho carries her **hand axe** and **Evro''s former enchanted shield**, supported by plate armour. Being an expert and enthusiastic archer does not mean that she currently possesses a bow.

## A Castle Full of Farms

Sho''s dream is not to become queen or to sit in a glittering court. She wants **a castle of her own, surrounded by farms of her own**: good earth, orchards, livestock, warm kitchens, room for visiting relatives, a well-stocked cellar, and a dining hall long enough for everyone to squeeze onto its benches. She knows the difference between ruling land and caring for it. She intends to do both.

Her ambition is therefore quite practical, at least by ad'
        + N'venturers'' standards: survive the dungeon, bring home treasure, buy land, and build something that lasts. Her enormous family will probably come to visit. Sho has already begun worrying about where to put the 182 cousins.

Until then, she will keep volunteering for the awkward jobs, talking the company out of trouble when she can, and fighting her way out when she cannot. She may be the shortest person in a room, but she is rarely the quietest—or the easiest to put down.
';

IF EXISTS (SELECT 1 FROM [characters].[Character]
           WHERE [CharacterName] = N'Sho-Rembo' AND [Active] = 1)
BEGIN
    IF EXISTS
    (
       SELECT 1 FROM [characters].[Character]
       WHERE [CharacterName] = N'Sho-Rembo' AND [Active] = 1
         AND ([InitialClass] <> N'Halfling' OR [Race] <> N'Halfling'
              OR [Strength] <> 9 OR [Intelligence] <> 11
              OR [Wisdom] <> 9 OR [Constitution] <> 18
              OR [Dexterity] <> 9 OR [Charisma] <> 15
              OR [InitialAlignment] <> N'Neutral' OR [InitialAge] <> @InitialAge)
    )
        THROW 52101, 'An active Sho-Rembo identity exists with different data. Review; do not overwrite.', 1;
    PRINT N'Active Sho-Rembo identity already exists; nothing inserted.';
END
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[Character]
    WHERE [CharacterName] = N'Sho-Rembo'
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 52102, 'Sho already has a character version dated today; DATE PK disallows a second.', 1;
ELSE
BEGIN
    INSERT INTO [characters].[Character]
    (
        [CharacterName], [Active], [Surname], [Moniker], [Race],
        [InitialClass], [Sex], [InitialAge], [InitialAlignment],
        [Strength], [Intelligence], [Wisdom], [Constitution],
        [Dexterity], [Charisma], [BaseAC], [BackStory]
    )
    VALUES
    (
        N'Sho-Rembo', 1, NULL, N'Sho-Rembo', N'Halfling',
        N'Halfling', N'Female', @InitialAge, N'Neutral',
        9, 11, 9, 18, 9, 15, 9, @BackStory
    );
    PRINT N'Inserted Sho-Rembo Character identity.';
END;
GO
SELECT [RecordDate], [CharacterName], [Moniker], [InitialClass],
       [InitialAge], [Strength], [Intelligence], [Wisdom],
       [Constitution], [Dexterity], [Charisma], [Active]
FROM [characters].[Character]
WHERE [CharacterName] = N'Sho-Rembo';
GO
