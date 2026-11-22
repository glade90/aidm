
/*
===============================================================================
FILE MANIFEST
===============================================================================
File name  : dnd.sql
Project    : DnD / Quasqueton Character Collection
Purpose    : Create the DnD database and its initial characters schema
             on SQL Server.

Target     : PEQUOD (SQL Server default instance)
Version    : 0.1.0

CHANGE LOG
Date         Version   Change
-----------  --------  ----------------------------------------------
2026-10-18   0.1.0     Initial script. Create DnD database and
                        characters schema if they do not exist.

===============================================================================
*/

USE [master];
GO

-- Step 1: Create the DnD database.
IF DB_ID(N'DnD') IS NULL
BEGIN
    CREATE DATABASE [DnD];
    PRINT N'Created database [DnD].';
END
ELSE
BEGIN
    PRINT N'Database [DnD] already exists; no change made.';
END;
GO

USE [DnD];
GO

-- Step 2: Create the characters schema.
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = N'characters'
)
BEGIN
    EXEC(N'CREATE SCHEMA [characters] AUTHORIZATION [dbo];');
    PRINT N'Created schema [characters].';
END
ELSE
BEGIN
    PRINT N'Schema [characters] already exists; no change made.';
END;
GO

-- Step 3: Verify our setup.
SELECT
    DB_NAME() AS DatabaseName,
    s.name AS SchemaName
FROM sys.schemas AS s
WHERE s.name = N'characters';
GO
