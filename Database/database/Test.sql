/*
===============================================================================
FILE MANIFEST
===============================================================================
File Name       : Test.sql
Repository Path : Database/database/Test.sql
Project         : Golden Braid / AIDM
Purpose         : Create the dedicated schema for test scenario definitions,
                  test case definitions and future test run/results.
Target Server   : PEQUOD (SQL Server default instance)
Database        : DnD
Schema          : [Test]
Version         : 1.0.0
Created         : 2026-11-21
Dependencies    : Database/database/dnd.sql

DESIGN NOTES
- Rules.Monster remains the canonical game rules catalogue.
- Test.MonsterTestScenario holds one row per encounter fixture.
- Test.MonsterTestCase holds many test definitions per scenario.
- This script creates no tables, rows or test results.
- Safe to execute repeatedly; no destructive changes.
===============================================================================
*/
USE [DnD];
GO

IF SCHEMA_ID(N'Test') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA [Test] AUTHORIZATION [dbo];');
    PRINT N'Created schema [Test].';
END
ELSE
    PRINT N'Schema [Test] already exists; preserved.';
GO
