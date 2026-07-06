USE [IsporukaDB];
GO

/* ============================================================
   08_CreateApiKlijent.sql

   Циљ:
   - Креирање јавног АПИ слоја за клијентску апликацију
   - Омогућавање прегледа и претраге испорука
   - Сакривање логистичких и интерних података од клијента

   Правила именовања:
   - api_* views      = UPPER_CASE
   - api_* procedure  = PascalCase
   - api_* parameters = camelCase

   Напомена:
   Клијентски АПИ не излаже пуне податке о пошиљаоцу. Процедуре
   користе WITH EXECUTE AS OWNER због рада преко апликационе
   улоге DataProviderKLIJENT.
   ============================================================ */
   
/* ============================================================
   АПИ КЛИЈЕНТ - ПОГЛЕДИ
   ============================================================ */

CREATE OR ALTER VIEW api_klijent.ISPORUKE
AS
SELECT
    IdIsporuke,
    NazivProizvoda,
    Adresa,
    StatusIs,
    DatVreme,
    Napomena
FROM spec.vw_IsporukeZaKlijenta;
GO


CREATE OR ALTER VIEW api_klijent.STATUSI_ISPORUKA
AS
SELECT
    StatusIs,
    BrojIsporuka
FROM spec.vw_IsporukePoStatusu;
GO


/* ============================================================
   АПИ КЛИЈЕНТ - ПРОЦЕДУРЕ
   ============================================================ */

CREATE OR ALTER PROCEDURE api_klijent.PogledajIsporuku
(
    @idIsporuke INT
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF @idIsporuke IS NULL OR @idIsporuke <= 0
    BEGIN
        THROW 53001, N'Ид испоруке мора бити цео број већи од нуле.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM spec.vw_IsporukeZaKlijenta
        WHERE IdIsporuke = @idIsporuke
    )
    BEGIN
        THROW 53002, N'Испорука са прослеђеним идентификатором не постоји.', 1;
    END;

    SELECT
        IdIsporuke,
        NazivProizvoda,
        Adresa,
        StatusIs,
        DatVreme,
        Napomena
    FROM spec.vw_IsporukeZaKlijenta
    WHERE IdIsporuke = @idIsporuke;
END;
GO


CREATE OR ALTER PROCEDURE api_klijent.PogledajStatusIsporuke
(
    @idIsporuke INT
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF @idIsporuke IS NULL OR @idIsporuke <= 0
    BEGIN
        THROW 53003, N'Ид испоруке мора бити цео број већи од нуле.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM spec.vw_IsporukeZaKlijenta
        WHERE IdIsporuke = @idIsporuke
    )
    BEGIN
        THROW 53004, N'Испорука са прослеђеним идентификатором не постоји.', 1;
    END;

    SELECT
        IdIsporuke,
        StatusIs,
        DatVreme
    FROM spec.vw_IsporukeZaKlijenta
    WHERE IdIsporuke = @idIsporuke;
END;
GO


CREATE OR ALTER PROCEDURE api_klijent.PretraziIsporuke
(
    @tekst NVARCHAR(200)
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF @tekst IS NULL OR LEN(LTRIM(RTRIM(@tekst))) = 0
    BEGIN
        THROW 53005, N'Текст за претрагу не сме бити празан.', 1;
    END;

    SET @tekst = LTRIM(RTRIM(@tekst));

    SELECT
        IdIsporuke,
        NazivProizvoda,
        Adresa,
        StatusIs,
        DatVreme,
        Napomena
    FROM spec.vw_IsporukeZaKlijenta
    WHERE 
        NazivProizvoda LIKE N'%' + @tekst + N'%'
        OR Adresa LIKE N'%' + @tekst + N'%'
        OR Napomena LIKE N'%' + @tekst + N'%'
    ORDER BY DatVreme DESC;
END;
GO


CREATE OR ALTER PROCEDURE api_klijent.PregledIsporukaPoStatusu
(
    @statusIs NVARCHAR(20)
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF @statusIs IS NULL OR LEN(LTRIM(RTRIM(@statusIs))) = 0
    BEGIN
        THROW 53006, N'Статус испоруке не сме бити празан.', 1;
    END;

    SET @statusIs = LTRIM(RTRIM(@statusIs));

    IF @statusIs NOT IN 
    (
        N'Примљена',
        N'УТранспорту',
        N'Испоручена',
        N'Враћена'
    )
    BEGIN
        THROW 53007, N'Статус испоруке није дозвољен.', 1;
    END;

    SELECT
        IdIsporuke,
        NazivProizvoda,
        Adresa,
        StatusIs,
        DatVreme,
        Napomena
    FROM spec.vw_IsporukeZaKlijenta
    WHERE StatusIs = @statusIs
    ORDER BY DatVreme DESC;
END;
GO

CREATE OR ALTER PROCEDURE api_klijent.PogledajIstorijuStatusa
(
    @idIsporuke INT
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF @idIsporuke IS NULL OR @idIsporuke <= 0
    BEGIN
        THROW 57003, N'Ид испоруке мора бити цео број већи од нуле.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM spec.vw_IsporukeZaKlijenta
        WHERE IdIsporuke = @idIsporuke
    )
    BEGIN
        THROW 57004, N'Испорука са прослеђеним идентификатором не постоји.', 1;
    END;

    SELECT
        l.Redosled,
        l.IdIsporuke,
        l.StariStatus,
        l.NoviStatus,
        l.DatVremePromene
    FROM spec.fnt_LanacStatusaIsporuke(@idIsporuke) AS l
    ORDER BY l.Redosled;
END;
GO

/* ============================================================
   ПРОВЕРА КРЕИРАНИХ АПИ ОБЈЕКАТА
   ============================================================ */

SELECT
    s.name AS SchemaName,
    v.name AS ViewName
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON v.schema_id = s.schema_id
WHERE s.name = N'api_klijent'
ORDER BY v.name;
GO

SELECT
    s.name AS SchemaName,
    p.name AS ProcedureName
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s
    ON p.schema_id = s.schema_id
WHERE s.name = N'api_klijent'
ORDER BY p.name;
GO