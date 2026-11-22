/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Character_Evro_Insert.sql
Repository Path : Database/tables/Character_Evro_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Evro's first active character identity/attribute snapshot,
                  including the full portable Markdown backstory.
Target Server   : PEQUOD (default SQL Server instance)
Database        : DnD
Schema          : characters
Table           : characters.Character
Version         : 1.2.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/tables/Character.sql (v1.1.0 or later)
                  Evro_BackStory.md (Markdown master copy; embedded below)

DESIGN DECISIONS
- CharacterName: N'Evro'. RecordDate: UTC DATETIME2(7) at time of insert.
- Active = 1 for the initial approved Evro version.
- No separate CharacterID; composite PK is (RecordDate, CharacterName).
- Seed runs only when no Evro history exists; it NEVER overwrites existing data.
- Future character versions require a separate, reviewed transaction that
  marks the old record inactive and inserts the new one.
- Scores: STR 16, INT 9, WIS 16, CON 12, DEX 11, CHA 9.
- Narrative is preserved as literal Markdown within NVARCHAR(MAX).
- A CLOB is not a native SQL Server type; NVARCHAR(MAX) is used instead.

CHANGE LOG
Date         Version   Change
-----------  --------  --------------------------------------------------------
2026-10-18   1.0.0     Initial Evro seed row with approved backstory.
2026-10-18   1.1.0     Store portable Markdown BackStory; companion .md file.
2026-10-18   1.2.0     Insert RecordDate and Active with versioned character PK.
===============================================================================
*/

USE [DnD];
GO

-- 1. Guard against executing this seed against an old table definition.
IF OBJECT_ID(N'characters.Character', N'U') IS NULL
    THROW 51010, 'characters.Character does not exist; run Character.sql first.', 1;
IF COL_LENGTH(N'characters.Character', N'RecordDate') IS NULL
   OR COL_LENGTH(N'characters.Character', N'Active') IS NULL
    THROW 51011, 'characters.Character does not yet have RecordDate and Active. A migration may be needed.', 1;

-- 2. Initial seed: no historical Evro version must exist.
IF NOT EXISTS
(
    SELECT 1
    FROM [characters].[Character]
    WHERE [CharacterName] = N'Evro'
)
BEGIN
    DECLARE @BackStory NVARCHAR(MAX) =
        CONVERT(NVARCHAR(MAX), N'# Evro the Forgotten

> “A full purse and an empty stomach. That''s all the difference between a gentleman and a beggar.”

## The Man Without a Name

Nobody knows where Evro came from. Least of all Evro himself. He has no surname, no knowledge of his parents, and no certainty that Evro is even his real first name. It is simply what people have called him for as long as he can remember. He is twenty-six years old, or so he believes; he knows no birthday worth celebrating.

## The Streets of Thyatis

His earliest memories are of Thyatis: wet cobblestones, crowded markets, hungry nights, filthy alleyways, and the endless struggle to find enough food to see another day. For many, the imperial capital was a place of wealth and opportunity. For Evro, it was a city where dogs sometimes ate better than children. He slept where the watch would not find him, sometimes beneath wagons or behind the stalls after the market closed.

He grew up among beggars, thieves, abandoned children, drunkards, and desperate laborers. He watched them fight, steal, cheat, and eventually destroy themselves. Some were taken by the watch; others by hunger, sickness, or the gallows. Most simply disappeared. Evro survived.

## The Brute They Underestimated

Even as a boy, he was unusually large and strong. By adulthood he had become a mountain of a man, broad-shouldered and heavily muscled, with coarse dark hair, a thick unruly beard, weather-beaten features, and a collection of old scars. His clothes were usually patched, fur-trimmed when he could get them, and none too clean. People assumed that such a hulking, unkempt fellow must also be a fool.

Evro learned to encourage that assumption.

His greatest advantage was never his strength. It was his cynicism. He learned early that generosity often carried a price, kind words could conceal a knife, and anyone promising something for nothing was probably planning to take everything. People revealed a remarkable amount when they thought the person listening was too stupid to understand. Evro acquired a keen sense for dishonest bargains, impending trouble, and men trying to lure him into a fight on unfavorable terms. He has little formal education, but the streets gave him a sort of wisdom that books rarely teach.

## Appetite and Restraint

Evro eats like an animal. He uses his hands whenever possible, eats quickly and noisily, and regards table manners as an eccentric luxury of people who have never truly been hungry. He is a slob and makes n') +
        N'o attempt to disguise it. Yet there is one indulgence he absolutely refuses: alcohol. He watched too many people trade their last coins, their judgment, and eventually their lives for another drink. He is quite certain he might end up the same way if he ever started. When others raise wine at a celebration, Evro raises water in a tankard.

## A Difficult Friend

Despite his intimidating appearance and rough manner, Evro has a surprisingly lively sense of humor. His jokes are coarse, cynical, and often ill-timed. He enjoys exposing the absurdities of respectable society, preferably within earshot of someone respectable. People who do not know him tend to dislike him and give him a wide berth. Those who do know him sometimes find him enormously entertaining. Evro has learned to accept both reactions.

## A Door of His Own

Evro adventures for money, not for glory, honor, justice, or the romance of ancient ruins. He has never enjoyed financial security and intends to acquire it. He wants enough coin to eat whenever he chooses and to own a door he can close, with a key that belongs to him. He does not dream of ruling a kingdom; he dreams of never needing another man''s charity.

## Quasqueton

When Ralt''s party offered paid work and a share of the treasure at Quasqueton, he accepted a ten-gold-piece advance and joined as a retainer. The expedition was nearly his last: at an upper-level crossroads, a troglodyte tore seven hit points from his eight. He survived, recovered much of his strength after drinking the strange pink liquid from the Room of Pools, and eventually received the plate armor once worn by the fallen Mohag. He gave his enchanted shield to Sho-Rembo and took her ordinary shield; an ordinary sword passed into his hands from other companions. He later helped bring three sealed barrels of wine out of the dungeon.

For the first time, he may have found companions whose company he sometimes enjoys. He would deny the sentiment fiercely, then make a joke about what they owe him. He has not forgotten the important part of the arrangement: his share of the treasure.
';

    INSERT INTO [characters].[Character]
    (
        [CharacterName], [Active], [Surname], [Moniker], [Race], [InitialClass],
        [Sex], [InitialAge], [InitialAlignment],
        [Strength], [Intelligence], [Wisdom], [Constitution],
        [Dexterity], [Charisma], [BaseAC], [BackStory]
    )
    VALUES
    (
        N'Evro', 1, NULL, N'Evro the Forgotten', N'Human', N'Fighter',
        N'Male', 26, N'Neutral',
        16, 9, 16, 12, 11, 9, 9, @BackStory
    );
    PRINT N'Inserted initial active Evro record.';
END
ELSE
BEGIN
    PRINT N'Evro already has a character record; seed skipped without modifying history.';
END;
GO

-- 3. Read-only verification: show every known version of Evro.
SELECT
    [RecordDate], [CharacterName], [Active], [Surname], [Moniker],
    [InitialAge], [InitialAlignment], [Strength], [Intelligence],
    [Wisdom], [Constitution], [Dexterity], [Charisma], [BaseAC],
    LEN([BackStory]) AS BackStoryCharacters
FROM [characters].[Character]
WHERE [CharacterName] = N'Evro'
ORDER BY [RecordDate] DESC;
GO
