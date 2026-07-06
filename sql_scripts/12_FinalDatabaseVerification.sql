USE [IsporukaDB];
GO

/* ============================================================
   ПРОВЕРА БАЗЕ И КОЛАЦИЈЕ
   ============================================================ */

SELECT
    DB_NAME() AS DatabaseName,
    DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS DatabaseCollation;
GO


/* ============================================================
   ПРОВЕРА ШЕМА
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


/* ============================================================
   ПРОВЕРА ТАБЕЛА
   ============================================================ */

SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE s.name = N'impl'
ORDER BY t.name;
GO


/* ============================================================
   ПРОВЕРА CHECK, PK I FK ОГРАНИЧЕЊА
   ============================================================ */

SELECT
    OBJECT_SCHEMA_NAME(parent_object_id) AS SchemaName,
    OBJECT_NAME(parent_object_id) AS TableName,
    name AS ConstraintName,
    type_desc AS ConstraintType
FROM sys.objects
WHERE type IN ('C', 'PK', 'F')
  AND OBJECT_SCHEMA_NAME(parent_object_id) = N'impl'
ORDER BY TableName, ConstraintType, ConstraintName;
GO


/* ============================================================
   ПРОВЕРА ТРИГЕРА
   ============================================================ */

SELECT
    s.name AS SchemaName,
    tr.name AS TriggerName,
    tr.type_desc AS TriggerType,
    t.name AS TableName,
    tr.is_disabled AS IsDisabled
FROM sys.triggers AS tr
INNER JOIN sys.tables AS t
    ON tr.parent_id = t.object_id
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE s.name = N'impl'
ORDER BY tr.name;
GO

/* ============================================================
   ПРОВЕРА PARTITION ФУНКЦИЈЕ И PARTITION ШЕМЕ
   ============================================================ */

SELECT
    pf.name AS PartitionFunctionName,
    ps.name AS PartitionSchemeName
FROM sys.partition_functions AS pf
INNER JOIN sys.partition_schemes AS ps
    ON pf.function_id = ps.function_id
WHERE pf.name = N'pfIsporukaPoGodini';
GO


/* ============================================================
   ПРОВЕРА ИНДЕКСА НАД ИСПОРУКОМ
   ============================================================ */

SELECT
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ds.name AS DataSpaceName
FROM sys.indexes AS i
INNER JOIN sys.data_spaces AS ds
    ON i.data_space_id = ds.data_space_id
WHERE i.object_id = OBJECT_ID(N'impl.tblIsporuka')
ORDER BY i.index_id;
GO


/* ============================================================
   ПРОВЕРА SPEC ПОГЛЕДА
   ============================================================ */

SELECT
    s.name AS SchemaName,
    v.name AS ViewName
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON v.schema_id = s.schema_id
WHERE s.name = N'spec'
ORDER BY v.name;
GO


/* ============================================================
   ПРОВЕРА SPEC ПРОЦЕДУРА И ФУНКЦИЈА
   ============================================================ */

SELECT
    s.name AS SchemaName,
    o.name AS ObjectName,
    o.type_desc AS ObjectType
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
    ON o.schema_id = s.schema_id
WHERE s.name = N'spec'
  AND
  (
      o.type IN ('P', 'PC', 'FN', 'IF', 'TF')
  )
ORDER BY o.type_desc, o.name;
GO

/* ============================================================
   ПРОВЕРА API_LOGISTIKA ОБЈЕКАТА
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


/* ============================================================
   ПРОВЕРА API_KLIJENT ОБЈЕКАТА
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


/* ============================================================
   ПРОВЕРА АПЛИКАЦИОНИХ УЛОГА
   ============================================================ */

SELECT
    name AS PrincipalName,
    type_desc AS PrincipalType,
    default_schema_name AS DefaultSchema
FROM sys.database_principals
WHERE name IN
(
    N'DataProviderLOGISTIKA',
    N'DataProviderKLIJENT'
)
ORDER BY name;
GO


/* ============================================================
   ПРОВЕРА FULL-TEXT ОБЈЕКАТА
   ============================================================ */

SELECT
    FULLTEXTSERVICEPROPERTY('IsFullTextInstalled') AS IsFullTextInstalled;
GO

SELECT
    name AS FullTextCatalogName,
    is_default AS IsDefault
FROM sys.fulltext_catalogs
WHERE name = N'ftcIsporukaDB';
GO

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
   ПРОВЕРА CLR ASSEMBLY-ЈА И ПРОЦЕДУРА
   ============================================================ */

SELECT
    name AS AssemblyName,
    permission_set_desc AS PermissionSet
FROM sys.assemblies
WHERE name = N'IsporukaClr';
GO

SELECT
    s.name AS SchemaName,
    p.name AS ProcedureName
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

/* ============================================================
   ПРОВЕРА ДЕМО ПОДАТАКА
   ============================================================ */

SELECT *
FROM api_logistika.PROIZVODI
ORDER BY IdProizvoda;
GO

SELECT *
FROM api_logistika.POSILJAOCI
ORDER BY IdPosiljaoca;
GO

SELECT *
FROM api_logistika.ISPORUKE_DETALJNO
ORDER BY IdIsporuke;
GO


/* ============================================================
   ТЕСТ FULL-TEXT ПРОЦЕДУРА
   ============================================================ */

EXEC api_logistika.PretraziProizvodeOpis
    @tekst = N'пословну';
GO

EXEC api_klijent.PretraziIsporukeNapomena
    @tekst = N'брзу';
GO

EXEC api_klijent.PretraziIsporukeNapomenaNear
    @prvaRec = N'брзу',
    @drugaRec = N'испоруку',
    @udaljenost = 5;
GO


/* ============================================================
   ТЕСТ CLR ДИЈАГНОСТИКЕ
   ============================================================ */

EXEC api_logistika.DijagnostikujKasnjenja
    @pragSati = 24;
GO

/*
    Напомена:
    Такође се уписује запис и у Windows Event Log за сваку испоруку 
    која касни дуже од задатог прага.
*/

/* ============================================================
   ТЕСТ ИСТОРИЈЕ СТАТУСА И РЕКУРЗИВНЕ ФУНКЦИЈЕ (CTE)
   ============================================================ */

EXEC api_logistika.PregledIstorijeStatusa
    @idIsporuke = 1;
GO

/* ============================================================
   ТЕСТ FOR XML PATH ДОКУМЕНТА ИСПОРУКЕ
   ============================================================ */

EXEC api_logistika.GenerisiXmlIsporuke
    @idIsporuke = 1;
GO

/* ============================================================
   ТЕСТ CLR AUDIT ТРИГЕРА

   Креира се нова тест испорука и потом се мењају статуси.
   CLR тригер треба да упише аудит записе.
   ============================================================ */

DECLARE @novaIsporuka TABLE
(
    IdIsporuke INT
);

INSERT INTO @novaIsporuka
EXEC api_logistika.KreirajIsporuku
    @adresa = N'Финална провера CLR audit trigger-а, Београд',
    @napomena = N'Тест испорука за финалну проверу audit trigger-а.',
    @datVreme = '2025-06-20T10:00:00',
    @idProizvoda = 1,
    @idPosiljaoca = 1;

DECLARE @idIsporukeAuditTest INT =
(
    SELECT TOP 1 IdIsporuke
    FROM @novaIsporuka
);

EXEC api_logistika.PromeniStatusIsporuke
    @idIsporuke = @idIsporukeAuditTest,
    @noviStatus = N'УТранспорту';

EXEC api_logistika.PromeniStatusIsporuke
    @idIsporuke = @idIsporukeAuditTest,
    @noviStatus = N'Испоручена';

EXEC api_logistika.PregledAuditStatusa
    @idIsporuke = @idIsporukeAuditTest;
GO

/* ============================================================
   ТЕСТ ДМВ ПРОЦЕДУРЕ

   Напомена:
   Покренути нови упит у SSMS и уписати прво команду:
   WAITFOR DELAY '00:00:30';
   Потом покренути доњи код.
   ============================================================ */

EXEC api_logistika.AktivniUpiti;
GO

/* ============================================================
   БЕЗБЕДОНОСНА ПРОВЕРА АПЛИКАЦИОНИХ УЛОГА
   ============================================================ */
 /* ============================================================
   DataProviderLOGISTIKA
   ============================================================ */

    EXEC sp_setapprole
    @rolename = N'DataProviderLOGISTIKA',
    @password = N'Logistika#2026!StrongPass';
    GO

    -- Треба да ради
    SELECT *
    FROM api_logistika.PROIZVODI;
    GO

    -- Треба да падне: permission denied
    SELECT *
    FROM impl.tblProizvod;
    GO

    -- Треба да падне: permission denied
    SELECT *
    FROM spec.vw_Proizvodi;
    GO

  /* ============================================================
   DataProviderKLIJENT
   ============================================================ */

    EXEC sp_setapprole
        @rolename = N'DataProviderKLIJENT',
        @password = N'Klijent#2026!StrongPass';
    GO

    -- Треба да ради
    SELECT *
    FROM api_klijent.ISPORUKE;
    GO

    -- Треба да падне: permission denied
    SELECT *
    FROM api_logistika.ISPORUKE_DETALJNO;
    GO

    -- Треба да падне: permission denied
    SELECT *
    FROM impl.tblIsporuka;
    GO

    -- Треба да падне: permission denied
    SELECT *
    FROM spec.vw_IsporukeDetaljno;
    GO