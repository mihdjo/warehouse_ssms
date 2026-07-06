USE [IsporukaDB];
GO

/* ============================================================
   01_CreatePartitioning.sql

   Циљ:
   - Креирање partition функције за поделу испорука по години
   - Креирање partition шеме за табелу impl.tblIsporuka

   ============================================================ */


/* ============================================================
   PARTITION FUNCTION

   pfIsporukaPoGodini дели податке по вредности DatVreme.
   Користи се RANGE RIGHT, што значи да гранична вредност припада
   десној партицији

   Пример: "2025-01-01" припада партицији за 2025. годину.
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1 
    FROM sys.partition_functions
    WHERE name = N'pfIsporukaPoGodini'
)
BEGIN 
    EXEC(N'
        CREATE PARTITION FUNCTION pfIsporukaPoGodini (DATETIME2(0))
        AS RANGE RIGHT FOR VALUES
        (
            ''2023-01-01'',
            ''2024-01-01'',
            ''2025-01-01'',
            ''2026-01-01'',
            ''2027-01-01'',
            ''2028-01-01''
        );
    ');
END;
GO


/* ============================================================
   PARTITION SCHEME
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.partition_schemes
    WHERE name = N'psIsporukaPoGodini'
)
BEGIN
    EXEC(N'
        CREATE PARTITION SCHEME psIsporukaPoGodini
        AS PARTITION pfIsporukaPoGodini
        ALL TO ([PRIMARY]);
    ');
END;
GO


/* ============================================================
   ПРОВЕРА PartitionFunction и PartitionScheme
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
   ПРОВЕРА ГРАНИЧНИХ ВРЕДНОСТИ
   ============================================================ */

SELECT
    pf.name AS PartitionFunctionName,
    prv.boundary_id AS BoundaryId,
    CONVERT(DATETIME2(0), prv.value) AS BoundaryValue
FROM sys.partition_functions AS pf
INNER JOIN sys.partition_range_values AS prv
    ON pf.function_id = prv.function_id
WHERE pf.name = N'pfIsporukaPoGodini'
ORDER BY prv.boundary_id;
GO