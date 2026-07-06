USE [IsporukaDB];
GO

/* ============================================================
   07_CreateApiLogistika.sql

   Циљ:
   - Креирање јавног АПИ слоја за логистичку апликацију
   - Омогућавање рада над производима, пошиљаоцима и испорукама
   - Сакривање spec и impl од апликације

   Правила именовања:
   - api_* views      = UPPER_CASE
   - api_* procedure  = PascalCase
   - api_* parameters = camelCase

   Процедуре користе WITH EXECUTE AS OWNER да би апликациона улога
   могла да користи api_logistika без директних права над
   spec и impl слојевима.
   ============================================================ */ 

/* ============================================================
   АПИ ЛОГИСТИКА - ПОГЛЕДИ
   ============================================================ */

CREATE OR ALTER VIEW api_logistika.PROIZVODI
AS
SELECT
    IdProizvoda,
    Naziv,
    Opis,
    Tezina
FROM spec.vw_Proizvodi;
GO


CREATE OR ALTER VIEW api_logistika.POSILJAOCI
AS
SELECT
    IdPosiljaoca,
    NazivKompanije,
    Email,
    Telefon
FROM spec.vw_Posiljaoci;
GO


CREATE OR ALTER VIEW api_logistika.ISPORUKE_DETALJNO
AS
SELECT
    IdIsporuke,
    Adresa,
    Napomena,
    StatusIs,
    DatVreme,
    IdProizvoda,
    NazivProizvoda,
    OpisProizvoda,
    Tezina,
    IdPosiljaoca,
    NazivKompanije,
    EmailPosiljaoca,
    TelefonPosiljaoca
FROM spec.vw_IsporukeDetaljno;
GO


CREATE OR ALTER VIEW api_logistika.ISPORUKE_PO_STATUSU
AS
SELECT
    StatusIs,
    BrojIsporuka
FROM spec.vw_IsporukePoStatusu;
GO


/* ============================================================
   АПИ ЛОГИСТИКА - ПРОЦЕДУРЕ
   ============================================================ */

CREATE OR ALTER PROCEDURE api_logistika.DodajProizvod
(
    @naziv NVARCHAR(100),
    @opis NVARCHAR(1000),
    @tezina DECIMAL(10,2)
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_DodajProizvod
        @naziv = @naziv,
        @opis = @opis,
        @tezina = @tezina;
END;
GO


CREATE OR ALTER PROCEDURE api_logistika.DodajPosiljaoca
(
    @nazivKompanije NVARCHAR(150),
    @email NVARCHAR(150),
    @telefon NVARCHAR(50) = NULL
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_DodajPosiljaoca
        @nazivKompanije = @nazivKompanije,
        @email = @email,
        @telefon = @telefon;
END;
GO


CREATE OR ALTER PROCEDURE api_logistika.KreirajIsporuku
(
    @adresa NVARCHAR(300),
    @napomena NVARCHAR(MAX) = NULL,
    @datVreme DATETIME2(0) = NULL,
    @idProizvoda INT,
    @idPosiljaoca INT
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_KreirajIsporuku
        @adresa = @adresa,
        @napomena = @napomena,
        @datVreme = @datVreme,
        @idProizvoda = @idProizvoda,
        @idPosiljaoca = @idPosiljaoca;
END;
GO


CREATE OR ALTER PROCEDURE api_logistika.PromeniStatusIsporuke
(
    @idIsporuke INT,
    @noviStatus NVARCHAR(20)
)
AS
WITH EXECUTE AS OWNER
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_PromeniStatusIsporuke
        @idIsporuke = @idIsporuke,
        @noviStatus = @noviStatus;
END;
GO

CREATE OR ALTER PROCEDURE api_logistika.AzurirajNapomenu
(
    @idIsporuke INT,
    @tekst NVARCHAR(MAX),
    @pozicija INT = NULL,
    @duzina INT = 0
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_AzurirajNapomenu
        @idIsporuke = @idIsporuke,
        @tekst = @tekst,
        @pozicija = @pozicija,
        @duzina = @duzina;
END;
GO

CREATE OR ALTER PROCEDURE api_logistika.ObrisiIsporuku
(
    @idIsporuke INT
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_ObrisiIsporuku
        @idIsporuke = @idIsporuke;
END;
GO

CREATE OR ALTER PROCEDURE api_logistika.PregledIstorijeStatusa
(
    @idIsporuke INT
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF @idIsporuke IS NULL OR @idIsporuke <= 0
    BEGIN
        THROW 57001, N'Ид испоруке мора бити цео број већи од нуле.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM spec.vw_IsporukeDetaljno
        WHERE IdIsporuke = @idIsporuke
    )
    BEGIN
        THROW 57002, N'Испорука са прослеђеним идентификатором не постоји.', 1;
    END;

    SELECT
        l.Redosled,
        l.IdIstorije,
        l.IdIsporuke,
        l.StariStatus,
        l.NoviStatus,
        l.DatVremePromene,
        l.IdPrethodneIstorije
    FROM spec.fnt_LanacStatusaIsporuke(@idIsporuke) AS l
    ORDER BY l.Redosled;
END;
GO

CREATE OR ALTER PROCEDURE api_logistika.GenerisiXmlIsporuke
(
    @idIsporuke INT
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_GenerisiXmlIsporuke
        @idIsporuke = @idIsporuke;
END;
GO

CREATE OR ALTER PROCEDURE api_logistika.PregledAuditStatusa
(
    @idIsporuke INT = NULL
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF @idIsporuke IS NOT NULL AND @idIsporuke <= 0
    BEGIN
        THROW 59001, N'Ид испоруке мора бити цео број већи од нуле.', 1;
    END;

    SELECT
        IdAudit,
        IdIsporuke,
        StariStatus,
        NoviStatus,
        DatVremeAudit,
        LoginName,
        HostName,
        ApplicationName,
        NazivProizvoda,
        NazivKompanije
    FROM spec.vw_AuditIsporukaStatusa
    WHERE @idIsporuke IS NULL
       OR IdIsporuke = @idIsporuke
    ORDER BY DatVremeAudit DESC, IdAudit DESC;
END;
GO

CREATE OR ALTER PROCEDURE api_logistika.AktivniUpiti
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_AktivniUpiti;
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
WHERE s.name = N'api_logistika'
ORDER BY v.name;
GO

SELECT
    s.name AS SchemaName,
    p.name AS ProcedureName
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s
    ON p.schema_id = s.schema_id
WHERE s.name = N'api_logistika'
ORDER BY p.name;
GO