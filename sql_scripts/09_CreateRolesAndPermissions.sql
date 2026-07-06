USE [IsporukaDB];
GO

/* ============================================================
   09_CreateRolesAndPermissions.sql

   Циљ:
   - Креирање апликационих улога за C# апликације
   - Ограничавање приступа тако да апликације користе искључиво
    api слој
   - Забрана директног приступа impl и spec слојевима

   Апликационе улоге:
   - DataProviderLOGISTIKA користи api_logistika
   - DataProviderKLIJENT користи api_klijent   
   ============================================================ */

/* ============================================================
   APPLICATION ROLES
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'DataProviderLOGISTIKA'
      AND type = 'A'
)
BEGIN
    EXEC(N'
        CREATE APPLICATION ROLE DataProviderLOGISTIKA
        WITH PASSWORD = ''SifraZaLogistiku#2026'',
        DEFAULT_SCHEMA = api_logistika;
    ');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'DataProviderKLIJENT'
      AND type = 'A'
)
BEGIN
    EXEC(N'
        CREATE APPLICATION ROLE DataProviderKLIJENT
        WITH PASSWORD = ''SifraZaKlijenta#2026'',
        DEFAULT_SCHEMA = api_klijent;
    ');
END;
GO


/* ============================================================
   DATA PROVIDER LOGISTIKA ДОЗВОЛЕ/ПЕРМИСИЈЕ
   Логистичка апликација користи само api_logistika.
   ============================================================ */

GRANT SELECT ON SCHEMA::api_logistika TO DataProviderLOGISTIKA;
GRANT EXECUTE ON SCHEMA::api_logistika TO DataProviderLOGISTIKA;
GO

DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::impl TO DataProviderLOGISTIKA;
DENY EXECUTE ON SCHEMA::impl TO DataProviderLOGISTIKA;
GO

DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::spec TO DataProviderLOGISTIKA;
DENY EXECUTE ON SCHEMA::spec TO DataProviderLOGISTIKA;
GO

DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::api_klijent TO DataProviderLOGISTIKA;
DENY EXECUTE ON SCHEMA::api_klijent TO DataProviderLOGISTIKA;
GO

/* ============================================================
   DATA PROVIDER KLIJENT ДОЗВОЛЕ/ПЕРМИСИЈЕ
   Клијентска апликација користи само api_klijent.
   ============================================================ */

GRANT SELECT ON SCHEMA::api_klijent TO DataProviderKLIJENT;
GRANT EXECUTE ON SCHEMA::api_klijent TO DataProviderKLIJENT;
GO

DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::impl TO DataProviderKLIJENT;
DENY EXECUTE ON SCHEMA::impl TO DataProviderKLIJENT;
GO

DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::spec TO DataProviderKLIJENT;
DENY EXECUTE ON SCHEMA::spec TO DataProviderKLIJENT;
GO

DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::api_logistika TO DataProviderKLIJENT;
DENY EXECUTE ON SCHEMA::api_logistika TO DataProviderKLIJENT;
GO


/* ============================================================
   ПРОВЕРА КРЕИРАНИХ АПЛИКАЦИОНИХ УЛОГА
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
   ПРОВЕРА ДОЗВОЛА/ПЕРМИСИЈА
   
   Дозволе се додељују на нивоу шема, приказујемо class_desc и 
   експлицитни назив шема над којом је дозвола додељена или 
   забрањена.
   ============================================================ */

SELECT
    dp.name AS PrincipalName,
    perm.state_desc AS PermissionState,
    perm.permission_name AS PermissionName,
    perm.class_desc AS PermissionClass,
    s.name AS SchemaName
FROM sys.database_permissions AS perm
INNER JOIN sys.database_principals AS dp
    ON perm.grantee_principal_id = dp.principal_id
LEFT JOIN sys.schemas AS s
    ON perm.major_id = s.schema_id
WHERE dp.name IN 
(
    N'DataProviderLOGISTIKA',
    N'DataProviderKLIJENT'
)
ORDER BY
    dp.name,
    s.name,
    perm.permission_name,
    perm.state_desc;
GO