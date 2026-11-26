/* AIDM UAT unified registry | SQL Server 2016+ | safe rerun.
   Creates database and schemas only; DOES NOT move/delete existing data. */
USE [master];
GO
IF DB_ID(N'DnD_Test') IS NULL
    EXEC(N'CREATE DATABASE [DnD_Test]');
GO
USE [DnD_Test];
GO
IF SCHEMA_ID(N'Test') IS NULL
    EXEC(N'CREATE SCHEMA [Test] AUTHORIZATION [dbo]');
IF SCHEMA_ID(N'Legacy') IS NULL
    EXEC(N'CREATE SCHEMA [Legacy] AUTHORIZATION [dbo]');
IF SCHEMA_ID(N'UATStage') IS NULL
    EXEC(N'CREATE SCHEMA [UATStage] AUTHORIZATION [dbo]');
GO
PRINT N'DnD_Test, Test, Legacy and UATStage schemas available; no table data changed.';
GO