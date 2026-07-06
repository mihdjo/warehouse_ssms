USE master;
GO

/* ============================================================
   00_CreateDatabaseAndSchemas.sql

   Циљ:
   - Креирање базе података IsporukaDB
   - Подешавање колације за српску ћирилицу
   - Креирање основних шема

   Архитектура:
   impl -> spec -> api_logistika / api_klijent
   ============================================================ */


/* ============================================================
   КРЕИРАЊЕ БАЗЕ ПОДАТАКА

   База се креира једино уколико већ не постоји.
   Колација Serbian_Cyrillic_100_CI_AS омогућава подршку
   за српску ћирилицу
   ============================================================ */

IF DB_ID(N'IsporukaDB') IS NULL
BEGIN
    CREATE DATABASE [IsporukaDB]
    COLLATE Serbian_Cyrillic_100_CI_AS;
END;
GO


/* ============================================================
   ПОДЕШАВАЊЕ Recovery mode
   ============================================================ */

ALTER DATABASE [IsporukaDB]
SET RECOVERY SIMPLE;
GO


USE [IsporukaDB];
GO


/* ============================================================
   КРЕИРАЊЕ ШЕМА ЗА СЛОЈЕВИТУ АРХИТЕКТУРУ

   impl         - физичка имплементација: табеле, индекси и тригери
   spec         - унутрашњи слој: процедуре, функције и погледи
   api_logistika - јавни АПИ за логистичку апликацију
   api_klijent   - јавни АПИ за клијентску апликацију
   ============================================================ */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'impl')
BEGIN 
    EXEC(N'CREATE SCHEMA impl');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'spec')
BEGIN
    EXEC(N'CREATE SCHEMA spec');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'api_logistika')
BEGIN
    EXEC(N'CREATE SCHEMA api_logistika');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'api_klijent')
BEGIN
    EXEC(N'CREATE SCHEMA api_klijent');
END;
GO


/* ============================================================
   ПРОВЕРА БАЗЕ И КОЛАЦИЈЕ
   ============================================================ */

SELECT 
    DB_NAME() AS DatabaseName,
    DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS DatabaseCollation;
GO


/* ============================================================
   ПРОВЕРА КРЕИРАНИХ ШЕМА
   ============================================================ */

SELECT
    name AS SchemaName
FROM sys.schemas
WHERE name IN
(
    N'impl',
    N'spec',
    N'api_logistika',
    N'api_klijent'
)
ORDER BY name;
GO