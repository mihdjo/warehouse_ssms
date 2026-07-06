USE [IsporukaDB];
GO

/* ============================================================
   10_CreateFullTextSearch.sql

   Скрипта задужена за решење функционалних захтева:
   - Full-Text претрага по опису производа
   - Full-Text претрага по напомени испоруке
   - CONTAINS и NEAR

   Архитектура.
   impl -> spec -> api_logistika / api_klijent
   ============================================================ */


/* ============================================================
   ПРОВЕРА ДА ЛИ ЈЕ FULL-TEXT SEARCH ИНСТАЛИРАН
   ============================================================ */

IF ISNULL(FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'), 0) = 0
BEGIN
    THROW 54001, N'Full-Text Search није инсталиран или није омогућен на SQL Server инстанци.', 1;
END;
GO


/* ============================================================
   БРИСАЊЕ ПРЕТХОДНО КРЕИРАНИХ ПРОЦЕДУРА
   Претходно креиране процедуре биће обрисане због имплементације
   Full-Text приступа.
   ============================================================ */

DROP PROCEDURE IF EXISTS api_logistika.PretraziProizvodeOpis;
DROP PROCEDURE IF EXISTS api_logistika.PretraziIsporukeNapomena;
DROP PROCEDURE IF EXISTS api_logistika.PretraziIsporukeNapomenaNear;

DROP PROCEDURE IF EXISTS api_klijent.PretraziIsporukeNapomena;
DROP PROCEDURE IF EXISTS api_klijent.PretraziIsporukeNapomenaNear;

DROP PROCEDURE IF EXISTS spec.upr_PretraziProizvodeOpisContains;
DROP PROCEDURE IF EXISTS spec.upr_PretraziIsporukeNapomenaContains;
DROP PROCEDURE IF EXISTS spec.upr_PretraziIsporukeNapomenaNear;
GO


/* ============================================================
   FULL-TEXT КАТАЛОГ
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.fulltext_catalogs
    WHERE name = N'ftcIsporukaDB'
)
BEGIN
    CREATE FULLTEXT CATALOG ftcIsporukaDB
    AS DEFAULT;
END;
GO


/* ============================================================
   FULL-TEXT ИНДЕКС НАД impl.tblProizvod(Opis)
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.fulltext_indexes
    WHERE object_id = OBJECT_ID(N'impl.tblProizvod')
)
BEGIN
    CREATE FULLTEXT INDEX ON impl.tblProizvod
    (
        Opis LANGUAGE 0
    )
    KEY INDEX pk_tblProizvod
    ON ftcIsporukaDB
    WITH CHANGE_TRACKING AUTO;
END;
GO


/* ============================================================
   FULL-TEXT ИНДЕКС НАД impl.tblIsporuka(Napomena)
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.fulltext_indexes
    WHERE object_id = OBJECT_ID(N'impl.tblIsporuka')
)
BEGIN
    CREATE FULLTEXT INDEX ON impl.tblIsporuka
    (
        Napomena LANGUAGE 0
    )
    KEY INDEX pk_tblIsporuka
    ON ftcIsporukaDB
    WITH CHANGE_TRACKING AUTO;
END;
GO


/* ============================================================
   SPEC ПРОЦЕДУРА:
     CONTAINS ПРЕТРАГА ПО ОПИСУ ПРОИЗВОДА
   ============================================================ */

CREATE OR ALTER PROCEDURE spec.upr_PretraziProizvodeOpisContains
(
    @tekst NVARCHAR(200)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @uslov NVARCHAR(400);

    IF @tekst IS NULL OR LEN(LTRIM(RTRIM(@tekst))) = 0
    BEGIN
        THROW 54002, N'Текст за Full-Text претрагу производа не сме бити празан.', 1;
    END;

    SET @tekst = REPLACE(LTRIM(RTRIM(@tekst)), N'"', N'');
    SET @uslov = N'"' + @tekst + N'*"';

    SELECT
        p.IdProizvoda,
        p.Naziv,
        p.Opis,
        p.Tezina
    FROM impl.tblProizvod AS p
    WHERE CONTAINS(p.Opis, @uslov)
    ORDER BY p.IdProizvoda;
END;
GO


/* ============================================================
   SPEC ПРОЦЕДУРА:
      CONTAINS ПРЕТРАГА ПО НАПОМЕНИ ИСПОРУКЕ
   ============================================================ */

CREATE OR ALTER PROCEDURE spec.upr_PretraziIsporukeNapomenaContains
(
    @tekst NVARCHAR(200)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @uslov NVARCHAR(400);

    IF @tekst IS NULL OR LEN(LTRIM(RTRIM(@tekst))) = 0
    BEGIN
        THROW 54003, N'Текст за Full-Text претрагу напомене испоруке не сме бити празан.', 1;
    END;

    SET @tekst = REPLACE(LTRIM(RTRIM(@tekst)), N'"', N'');
    SET @uslov = N'"' + @tekst + N'*"';

    SELECT
        i.IdIsporuke,
        p.Naziv AS NazivProizvoda,
        i.Adresa,
        i.StatusIs,
        i.DatVreme,
        i.Napomena
    FROM impl.tblIsporuka AS i
    INNER JOIN impl.tblProizvod AS p
        ON i.IdProizvoda = p.IdProizvoda
    WHERE CONTAINS(i.Napomena, @uslov)
    ORDER BY i.DatVreme DESC;
END;
GO


/* ============================================================
   SPEC ПРОЦЕДУРА:
      NEAR ПРЕТРАГА ПО НАПОМЕНИ ИСПОРУКЕ
   ============================================================ */

CREATE OR ALTER PROCEDURE spec.upr_PretraziIsporukeNapomenaNear
(
    @prvaRec NVARCHAR(100),
    @drugaRec NVARCHAR(100),
    @udaljenost INT = 8
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @uslov NVARCHAR(500);

    IF @prvaRec IS NULL OR LEN(LTRIM(RTRIM(@prvaRec))) = 0
    BEGIN
        THROW 54004, N'Прва реч за NEAR претрагу не сме бити празна.', 1;
    END;

    IF @drugaRec IS NULL OR LEN(LTRIM(RTRIM(@drugaRec))) = 0
    BEGIN
        THROW 54005, N'Друга реч за NEAR претрагу не сме бити празна.', 1;
    END;

    IF @udaljenost IS NULL OR @udaljenost < 1 OR @udaljenost > 50
    BEGIN
        THROW 54006, N'Удаљеност за NEAR претрагу мора бити број између 1 и 50.', 1;
    END;

    SET @prvaRec = REPLACE(LTRIM(RTRIM(@prvaRec)), N'"', N'');
    SET @drugaRec = REPLACE(LTRIM(RTRIM(@drugaRec)), N'"', N'');

    SET @uslov =
        N'NEAR(("'
        + @prvaRec
        + N'", "'
        + @drugaRec
        + N'"), '
        + CAST(@udaljenost AS NVARCHAR(10))
        + N')';

    SELECT
        i.IdIsporuke,
        p.Naziv AS NazivProizvoda,
        i.Adresa,
        i.StatusIs,
        i.DatVreme,
        i.Napomena
    FROM impl.tblIsporuka AS i
    INNER JOIN impl.tblProizvod AS p
        ON i.IdProizvoda = p.IdProizvoda
    WHERE CONTAINS(i.Napomena, @uslov)
    ORDER BY i.DatVreme DESC;
END;
GO


/* ============================================================
   API_LOGISTIKA WRAPPER ПРОЦЕДУРЕ
   ============================================================ */

CREATE OR ALTER PROCEDURE api_logistika.PretraziProizvodeOpis
(
    @tekst NVARCHAR(200)
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_PretraziProizvodeOpisContains
        @tekst = @tekst;
END;
GO


CREATE OR ALTER PROCEDURE api_logistika.PretraziIsporukeNapomena
(
    @tekst NVARCHAR(200)
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_PretraziIsporukeNapomenaContains
        @tekst = @tekst;
END;
GO


CREATE OR ALTER PROCEDURE api_logistika.PretraziIsporukeNapomenaNear
(
    @prvaRec NVARCHAR(100),
    @drugaRec NVARCHAR(100),
    @udaljenost INT = 8
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_PretraziIsporukeNapomenaNear
        @prvaRec = @prvaRec,
        @drugaRec = @drugaRec,
        @udaljenost = @udaljenost;
END;
GO


/* ============================================================
   API_KLIJENT WRAPPER ПРОЦЕДУРЕ
   ============================================================ */
   
CREATE OR ALTER PROCEDURE api_klijent.PretraziIsporukeNapomena
(
    @tekst NVARCHAR(200)
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_PretraziIsporukeNapomenaContains
        @tekst = @tekst;
END;
GO


CREATE OR ALTER PROCEDURE api_klijent.PretraziIsporukeNapomenaNear
(
    @prvaRec NVARCHAR(100),
    @drugaRec NVARCHAR(100),
    @udaljenost INT = 8
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_PretraziIsporukeNapomenaNear
        @prvaRec = @prvaRec,
        @drugaRec = @drugaRec,
        @udaljenost = @udaljenost;
END;
GO


/* ============================================================
   ПРОВЕРА FULL-TEXT КАТАЛОГА
   ============================================================ */

SELECT
    name AS FullTextCatalogName,
    is_default AS IsDefault
FROM sys.fulltext_catalogs
WHERE name = N'ftcIsporukaDB';
GO


/* ============================================================
   ПРОВЕРА FULL-TEXT ИНДЕКСА
   ============================================================ */

SELECT
    OBJECT_SCHEMA_NAME(object_id) AS SchemaName,
    OBJECT_NAME(object_id) AS TableName,
    change_tracking_state_desc AS ChangeTracking
FROM sys.fulltext_indexes
WHERE object_id IN
(
    OBJECT_ID(N'impl.tblProizvod'),
    OBJECT_ID(N'impl.tblIsporuka')
);
GO


/* ============================================================
   ПРОВЕРА КРЕИРАНИХ SPEC FULL-TEXT ПРОЦЕДУРА
   ============================================================ */

SELECT
    s.name AS SchemaName,
    p.name AS ProcedureName
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s
    ON p.schema_id = s.schema_id
WHERE s.name = N'spec'
  AND p.name LIKE N'upr_Pretrazi%'
ORDER BY p.name;
GO


/* ============================================================
   ПРОВЕРА КРЕИРАНИХ API FULL-TEXT ПРОЦЕДУРА
   ============================================================ */

SELECT
    s.name AS SchemaName,
    p.name AS ProcedureName
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s
    ON p.schema_id = s.schema_id
WHERE s.name IN (N'api_logistika', N'api_klijent')
  AND p.name LIKE N'Pretrazi%'
ORDER BY s.name, p.name;
GO