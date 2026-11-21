/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Character_Ralt_Insert.sql
Repository Path : Database/tables/Character_Ralt_Insert.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Insert Ralt Gaither identity, final scores and complete Markdown backstory.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : characters
Table           : characters.Character
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Character.sql (v1.1.1+)

DESIGN NOTES
- CharacterName is FIRST NAME Ralt; Surname=Gaither; Moniker=Ralt Gaither.
- Final scores STR11 INT18 WIS7 CON9 DEX14 CHA10; reroll 2+3+2=7.
- Age 29, male, Chaotic; no Prime Requisite exchange.
- Historical Level 1 HP is stored in CharacterLevel, NOT in this table.
- BaseAC=9 is unarmored base, independent of current DEX-adjusted AC 8.
- No image path in Character; adventure-level artwork belongs elsewhere.
- This seed will not overwrite an existing active version.

CHANGE LOG
Date         Version   Change
-----------  --------  -------------------------------------------------------
2026-10-18   1.0.0     Initial Ralt seed; locked abilities, B1 portrait,
                        established history and unsettled Expedition 12.
===============================================================================
*/

USE [DnD];
GO
SET XACT_ABORT ON;
GO


IF OBJECT_ID(N'characters.Character', N'U') IS NULL
    THROW 53200, 'Missing characters.Character; run Character.sql first.', 1;
IF COL_LENGTH(N'characters.Character', N'BackStory') IS NULL
   OR COL_LENGTH(N'characters.Character', N'Surname') IS NULL
   OR COL_LENGTH(N'characters.Character', N'RecordDate') IS NULL
    THROW 53201, 'Existing Character design is incompatible; review migration.', 1;
GO

DECLARE @BackStory NVARCHAR(MAX) =
    CONVERT(NVARCHAR(MAX), N'# Ralt Gaither — The Man Who Would Be God

## A Mind Without Reverence

At twenty-nine, Ralt Gaither regards most people as obstacles, resources, or occasional curiosities. He is exquisitely mannered, sharply dressed, and almost painfully posh. He can speak with polished courtesy while holding another person''s life in contempt. His contempt is not limited to the foolish or the wicked: Ralt believes himself superior to virtually everyone, and has little patience for any authority he has not chosen to exploit.

Ralt has extraordinary Intelligence, but wisdom has never been his strength. He mistakes understanding a thing for having the right to command it. He does not merely want wealth, prestige, a grand tower, or a seat among the world''s powerful. His ambition extends to mastery of the cosmos. In Ralt''s private arithmetic, becoming a god is not blasphemy or fantasy: it is a problem that a sufficiently brilliant magician should eventually be able to solve.

## Ten Years Under Wilberd''s Eye

When Ralt was nineteen, the church associated with Wilberd the Silent was already dealing with him begrudgingly. Wilberd was fifty-seven then. The older cleric saw something worth guiding in the young magic-user, and something dangerous that ought not to be left unattended. Over the following decade he became Ralt''s mentor, restraining influence, patron, and uneasy father figure, trying to direct him toward faith, discipline, patience, and or') 
    + N'der.

Ralt accepts the benefits of this arrangement, not its principles. Wilberd provides direction, protection, contacts, and a mission. Ralt supplies intellect, arcane power, initiative, and the willingness to do what others hesitate to contemplate. Each uses the other. Ralt often gives the party''s visible commands, but Wilberd is the organizer who holds its purpose together. Ralt knows he still needs that structure—even while he secretly resents needing anyone at all.

A betrayal is possible, not inevitable. Ralt''s loyalty may endure only while Wilberd remains useful, and Wilberd knows it. Their unresolved struggle is between knowledge without restraint and wisdom without vanity.

## Manners, Deception, and Power

Ralt''s impeccable manners are a tool. He can flatter, negotiate, conceal his intent, or lie without moral unease if doing so advances his larger design. The lives of strangers have little independent weight in his calculations. He is willing to kill if he believes it necessary to obtain power. Even the survival of everyone else would not satisfy him if someone, somewhere, remained beyond his control.

This is Ralt''s declared character and ambition, not a record that every contemplated cruelty has occurred. His long-term choices remain to be played at the table, not predetermined in the database.

## Quasqueton: Knowledge Beneath the Earth

Ralt has become the company''s principal caller, quartermaster, and treasure'
    + N'r in its exploration of Quasqueton. Ancient books, strange rooms, runes, experiments, and magical writing attract him as strongly as gold attracts ordinary treasure hunters. The magnificence of Room 12—the long-abandoned library, its ornate oaken doors, polished red granite, and the white-stone initials R & Z—offers precisely the sort of lost knowledge he believes he deserves to possess.

In an earlier expedition, a Magic Missile from Ralt killed one of two attacking berserkers in Zelligar''s laboratory. On Expedition 12 he travelled with his familiar collection of daggers, including one distinctive ornate dagger, and continued to direct the practical business of the company while the others fought, searched, and hauled wine barrels from the dungeon.

## The Sixth Kobold

One moment in Quasqueton lays the tension bare. After a kobold prisoner designated K6 had been promised freedom, Ralt would have killed him rather than honor the bargain. Wilberd intervened, stopped the attack, and personally released the prisoner in the Room of Pools. To Ralt, a convenient death was a small matter. To Wilberd, the company''s promise was binding. Neither man forgot the disagreement.

## The Limit of His Power

Ralt is still a first-level Magic-User. His known prepared spell is Magic Missile, and under the adopted house rule he has four maximum hit points rather than his former single hit point. His ambition is vastly larger than his current abi'
    + N'lities. That disparity does not humble him; it offends him. The world, he believes, has simply failed to recognize the person who ought to rule it.

It remains to be seen whether Wilberd can teach Ralt restraint—or whether Ralt will someday attempt to put even the Immortals beneath his will.
';

IF EXISTS (SELECT 1 FROM [characters].[Character]
           WHERE [CharacterName] = N'Ralt' AND [Active] = 1)
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM [characters].[Character]
        WHERE [CharacterName] = N'Ralt' AND [Active] = 1
          AND ([Surname] <> N'Gaither' OR [Race] <> N'Human'
               OR [InitialClass] <> N'Magic-User'
               OR [InitialAlignment] <> N'Chaotic'
               OR [InitialAge] <> 29 OR [Sex] <> N'Male'
               OR [Strength] <> 11 OR [Intelligence] <> 18
               OR [Wisdom] <> 7 OR [Constitution] <> 9
               OR [Dexterity] <> 14 OR [Charisma] <> 10)
    )
        THROW 53202, 'Active Ralt identity conflicts with locked values; no changes made.', 1;
    PRINT N'Active Ralt identity exists and matches essential fields; preserved.';
END
ELSE IF EXISTS
(
    SELECT 1 FROM [characters].[Character]
    WHERE [CharacterName] = N'Ralt'
      AND [RecordDate] = CONVERT(DATE, SYSUTCDATETIME())
)
    THROW 53203, 'Ralt has a Character row today; DATE PK prevents another.', 1;
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
        N'Ralt', 1, N'Gaither', N'Ralt Gaither', N'Human', N'Magic-User',
        N'Male', 29, N'Chaotic',
        11, 18, 7, 9, 14, 10, 9, @BackStory
    );
    PRINT N'Inserted Ralt Gaither identity and backstory.';
END;
GO

SELECT [RecordDate], [CharacterName], [Surname], [Moniker],
       [InitialClass], [InitialAge], [InitialAlignment],
       [Strength], [Intelligence], [Wisdom], [Constitution],
       [Dexterity], [Charisma], [Active], LEN([BackStory]) AS BackStoryCharacters
FROM [characters].[Character]
WHERE [CharacterName] = N'Ralt'
ORDER BY [RecordDate] DESC;
GO
