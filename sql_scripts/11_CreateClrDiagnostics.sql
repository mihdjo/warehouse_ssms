USE master;
GO

/* ============================================================
   11_CreateClrDiagnostics.sql

   Скрипта задужена за CLR (Common Language Runtime) део пројекта 
   и захтеве:
    1. CLR процедура за Windows Event Log дијагностику кашњења
    2. CLR DML тригер за аудит промене статуса испоруке

   Предуслови:
   - C:\IsporukaCLR\IsporukaClr.dll постоји
   - DLL садржи класе:
        IsporukaDiagnostics
        IsporukaAuditTrigger
   - Event Log source "IsporukaDB_CLR" креиран је путем Powershell-a:
        New-EventLog -LogName Application -Source "IsporukaDB_CLR"
   ============================================================ */


/* ============================================================
   ОМОГУЋАВАЊЕ CLR-A НА SQL СЕРВЕРУ
   ============================================================ */

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
GO

EXEC sp_configure 'clr strict security', 0;
RECONFIGURE;
GO

ALTER DATABASE [IsporukaDB] SET TRUSTWORTHY ON;
GO


USE [IsporukaDB];
GO


/* ============================================================
   CLEANUP ПОСТОЈЕЋИХ CLR ОБЈЕКАТА

   Редослед игра улогу и битан је:
   - прво АПИ процедуре
   - затим spec процедуре
   - затим CLR тригери и ускладиштене процедуре
   - затим assembly
   ============================================================ */

DROP PROCEDURE IF EXISTS api_logistika.DijagnostikujKasnjenja;
GO

DROP PROCEDURE IF EXISTS spec.upr_DijagnostikujKasnjenja;
GO

DROP TRIGGER IF EXISTS impl.trg_clr_tblIsporuka_AuditStatus;
GO

DROP PROCEDURE IF EXISTS spec.upr_ClrUpisiKasnjenje;
GO

DROP ASSEMBLY IF EXISTS IsporukaClr;
GO


/* ============================================================
   РЕГИСТРАЦИЈА CLR ASSEMBLY-ЈА
   ============================================================ */

CREATE ASSEMBLY IsporukaClr
FROM 'C:\IsporukaCLR\IsporukaClr.dll'
WITH PERMISSION_SET = UNSAFE;
GO


/* ============================================================
   CLR ПРОЦЕДУРА ЗА УПИС У WINDOWS EVENT LOG

   C# класа:
   public class IsporukaDiagnostics

   C# метода:
   public static void UpisiKasnjenje(...)
   ============================================================ */

CREATE PROCEDURE spec.upr_ClrUpisiKasnjenje
(
    @idIsporuke INT,
    @statusIs NVARCHAR(20),
    @datVreme NVARCHAR(30),
    @satiKasnjenja INT,
    @pragSati INT
)
AS EXTERNAL NAME IsporukaClr.IsporukaDiagnostics.UpisiKasnjenje;
GO


/* ============================================================
   CLR DML ТРИГЕР ЗА АУДИТ ПРОМЕНЕ СТАТУСА

   C# класа:
   public class IsporukaAuditTrigger

   C# метода:
   public static void AuditStatusChange()

   Napomena:
   Табела impl.tblAuditIsporukaStatusa мора да постоји!!!
   ============================================================ */

IF OBJECT_ID(N'impl.tblAuditIsporukaStatusa', N'U') IS NULL
BEGIN
    THROW 55100, N'Табела impl.tblAuditIsporukaStatusa не постоји. Прво покренути 02_CreateTables.sql.', 1;
END;
GO

CREATE TRIGGER impl.trg_clr_tblIsporuka_AuditStatus
ON impl.tblIsporuka
WITH EXECUTE AS OWNER
AFTER UPDATE
AS EXTERNAL NAME IsporukaClr.IsporukaAuditTrigger.AuditStatusChange;
GO


/* ============================================================
   SPEC ПРОЦЕДУРА ЗА ДИЈАГНОСТИКУ КАШЊЕЊА

   Ова процедура:
   - проналази испоруке које и даље имају статус "Примљена" или "УТранспорту"
   - проверава да ли су старије од задатог прага сати
   - за сваку такву испоруку позива CLR процедуру
   - враћа резултат за приказ у самој апликацији
   ============================================================ */

CREATE OR ALTER PROCEDURE spec.upr_DijagnostikujKasnjenja
(
    @pragSati INT = 24
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @pragSati IS NULL OR @pragSati <= 0
    BEGIN
        THROW 55001, N'Праг кашњења мора бити позитиван број сати.', 1;
    END;

    DECLARE 
        @idIsporuke INT,
        @statusIs NVARCHAR(20),
        @datVreme NVARCHAR(30),
        @satiKasnjenja INT;

    DECLARE kasnjenja_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            i.IdIsporuke,
            i.StatusIs,
            CONVERT(NVARCHAR(30), i.DatVreme, 126) AS DatVreme,
            DATEDIFF(HOUR, i.DatVreme, SYSDATETIME()) AS SatiKasnjenja
        FROM impl.tblIsporuka AS i
        WHERE i.StatusIs IN (N'Примљена', N'УТранспорту')
          AND DATEDIFF(HOUR, i.DatVreme, SYSDATETIME()) >= @pragSati
        ORDER BY i.DatVreme;

    OPEN kasnjenja_cursor;

    FETCH NEXT FROM kasnjenja_cursor
    INTO @idIsporuke, @statusIs, @datVreme, @satiKasnjenja;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC spec.upr_ClrUpisiKasnjenje
            @idIsporuke = @idIsporuke,
            @statusIs = @statusIs,
            @datVreme = @datVreme,
            @satiKasnjenja = @satiKasnjenja,
            @pragSati = @pragSati;

        FETCH NEXT FROM kasnjenja_cursor
        INTO @idIsporuke, @statusIs, @datVreme, @satiKasnjenja;
    END;

    CLOSE kasnjenja_cursor;
    DEALLOCATE kasnjenja_cursor;

    SELECT
        i.IdIsporuke,
        i.StatusIs,
        i.DatVreme,
        DATEDIFF(HOUR, i.DatVreme, SYSDATETIME()) AS SatiOdKreiranja,
        p.Naziv AS NazivProizvoda,
        ps.NazivKompanije
    FROM impl.tblIsporuka AS i
    INNER JOIN impl.tblProizvod AS p
        ON i.IdProizvoda = p.IdProizvoda
    INNER JOIN impl.tblPosiljalac AS ps
        ON i.IdPosiljaoca = ps.IdPosiljaoca
    WHERE i.StatusIs IN (N'Примљена', N'УТранспорту')
      AND DATEDIFF(HOUR, i.DatVreme, SYSDATETIME()) >= @pragSati
    ORDER BY i.DatVreme;
END;
GO


/* ============================================================
   API_LOGISTIKA WRAPPER ЗА ДИЈАГНОСТИКУ КАШЊЕЊА

   WITH EXECUTE AS OWNER је битан јер апликациона улога
   користи само api_logistika, а нема директна права над spec.
   ============================================================ */

CREATE OR ALTER PROCEDURE api_logistika.DijagnostikujKasnjenja
(
    @pragSati INT = 24
)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    EXEC spec.upr_DijagnostikujKasnjenja
        @pragSati = @pragSati;
END;
GO


/* ============================================================
   ДОЗВОЛЕ ЗА АПЛИКАЦИОНЕ УЛОГЕ

   Ако улоге постоје, додељују им се експлицитне дозволе.
   Овај део се користи искључиво када је скрипта покренута пре 
   скрипте за доделу улога. (Не препоручујем.)
   ============================================================ */

IF EXISTS
(
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'DataProviderLOGISTIKA'
)
BEGIN
    GRANT EXECUTE ON OBJECT::api_logistika.DijagnostikujKasnjenja
    TO DataProviderLOGISTIKA;

    GRANT VIEW DEFINITION ON OBJECT::api_logistika.DijagnostikujKasnjenja
    TO DataProviderLOGISTIKA;
END;
GO


/* ============================================================
   ПРОВЕРА ASSEMBLY-ЈА
   ============================================================ */

SELECT
    a.name AS AssemblyName,
    a.permission_set_desc AS PermissionSet
FROM sys.assemblies AS a
WHERE a.name = N'IsporukaClr';
GO


/* ============================================================
   ПРОВЕРА CLR И SQL ПРОЦЕДУРА
   ============================================================ */

SELECT
    s.name AS SchemaName,
    p.name AS ProcedureName,
    p.type_desc AS ProcedureType
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s
    ON p.schema_id = s.schema_id
WHERE p.name IN
(
    N'upr_ClrUpisiKasnjenje',
    N'upr_DijagnostikujKasnjenja',
    N'DijagnostikujKasnjenja'
)
ORDER BY s.name, p.name;
GO


/* ============================================================
   ПРОВЕРА CLR ТРИГЕРА
   ============================================================ */

SELECT
    s.name AS SchemaName,
    tr.name AS TriggerName,
    tr.type_desc AS TriggerType,
    tr.is_disabled AS IsDisabled,
    t.name AS ParentTable
FROM sys.triggers AS tr
INNER JOIN sys.tables AS t
    ON tr.parent_id = t.object_id
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE tr.name = N'trg_clr_tblIsporuka_AuditStatus';
GO