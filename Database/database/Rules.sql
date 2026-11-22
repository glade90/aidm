/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Rules.sql
Repository Path : Database/schemas/Rules.sql
Project         : D&D - Quasqueton Character Collection
Purpose         : Create the Rules schema for official and optional rules catalogs.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : Rules
Table           : (schema only)
Version         : 1.0.0
Created         : 2026-10-18
Last Modified   : 2026-10-18
Dependencies    : Database/database/dnd.sql
Source          : 1983 Mentzer Basic D&D Players Manual pp.45-46,51,56;
                  Dungeon Masters Rulebook p.18 (uploaded Core Rules PDF).

DESIGN NOTES
- Schema name is [Rules] as requested.
- Create once; existing schema is preserved.
- This file does not move existing tables or change dbo.ClassLevel.

CHANGE LOG
Date         Version   Change
-----------  --------  --------------------------------------------------------
2026-10-18   1.0.0     Initial approved design proposal and implementation.
===============================================================================
*/
USE [DnD];
GO

IF SCHEMA_ID(N'Rules') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA [Rules] AUTHORIZATION [dbo];');
    PRINT N'Created schema [Rules].';
END
ELSE
    PRINT N'Schema [Rules] already exists; preserved.';
GO
