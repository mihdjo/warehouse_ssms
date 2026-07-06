USE [IsporukaDB];
GO

/* ============================================================
   03_CreateTriggers.sql

   Циљ: 
   - Имплементација пословних правила која није могуће у потпуности
    решити помоћу декларативног CHECK огрнаичење приступа.
   - Контрола DatVreme вредности
   - Контрола дозвољених прелаза статуса
   - Аутоматско вођење историје статуса испоруке

   Тригери:
   - impl.trg_tblIsporuka_DatVreme
   - impl.trg_tblIsporuka_StatusIs
   - impl.trg_tblIsporuka_IstorijaStatusa

   ============================================================ */

/* ============================================================
   Тригер: impl.trg_tblIsporuka_DatVreme

   Спречава унос или измену испоруке тако да DatVreme буде у 
   будућности. Ово правило се имплементира путем тригера јер
   CHECK ограничење не би требало да користи функције попут 
   SYSDATETIME(), јер јер ова функција недетерминистичка.
   ============================================================ */

CREATE OR ALTER TRIGGER impl.trg_tblIsporuka_DatVreme
ON impl.tblIsporuka
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE DatVreme > SYSDATETIME()
    )
    BEGIN
        THROW 51001, N'Датум и време испоруке не могу бити у будућности.', 1;
    END;
END;
GO

/* ============================================================
   Тригер: impl.trg_tblIsporuka_StatusIs

   Обезбеђује пословно правило тока статуса:
   - нова испорука мора почети као "Примљена"
   - Примљена може прећи само у УТранспорту
   - УТранспорту може прећи у Испоручена или Враћена
   - враћање уназад није дозвољено
   ============================================================ */

CREATE OR ALTER TRIGGER impl.trg_tblIsporuka_StatusIs
ON impl.tblIsporuka
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Нова испорука мора почети као "Примљена".
        Ако корисник не унесе статус, DEFAULT constraint већ поставља "Примљена".
    */
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN deleted d
            ON i.IdIsporuke = d.IdIsporuke
        WHERE d.IdIsporuke IS NULL
          AND i.StatusIs <> N'Примљена'
    )
    BEGIN
        THROW 51002, N'Нова испорука мора имати почетни статус: Примљена.', 1;
    END;

    /*
        Дозвољени прелази:
        Примљена    → УТранспорту
        УТранспорту → Испоручена
        УТранспорту → Враћена
    */
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d
            ON i.IdIsporuke = d.IdIsporuke
        WHERE i.StatusIs <> d.StatusIs
          AND NOT
          (
              d.StatusIs = N'Примљена'
              AND i.StatusIs = N'УТранспорту'
          )
          AND NOT
          (
              d.StatusIs = N'УТранспорту'
              AND i.StatusIs IN (N'Испоручена', N'Враћена')
          )
    )
    BEGIN
        THROW 51003, N'Недозвољен прелаз статуса испоруке.', 1;
    END;
END;
GO

/* ============================================================
   Тригер: impl.trg_tblIsporuka_IstorijaStatusa

   Аутоматски уписује историју статуса.
   Код INSERT-а бележи се почетни статус, док се код UPDATE-а 
   бележе само промене код којих се StatusIS заиста променио.

   Колона IdPrethodneIstorije повезује сваку промену са претходном,
   потребну за рекурзивни ланчани приказ свих промена историје 
   статуса испоруке.
   ============================================================ */

CREATE OR ALTER TRIGGER impl.trg_tblIsporuka_IstorijaStatusa
ON impl.tblIsporuka
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO impl.tblIstorijaStatusaIsporuke
    (
        IdIsporuke,
        StariStatus,
        NoviStatus,
        DatVremePromene,
        IdPrethodneIstorije
    )
    SELECT
        i.IdIsporuke,
        d.StatusIs AS StariStatus,
        i.StatusIs AS NoviStatus,
        SYSDATETIME() AS DatVremePromene,
        prethodna.IdIstorije AS IdPrethodneIstorije
    FROM inserted AS i
    LEFT JOIN deleted AS d
        ON i.IdIsporuke = d.IdIsporuke
    OUTER APPLY
    (
        SELECT TOP 1
            h.IdIstorije
        FROM impl.tblIstorijaStatusaIsporuke AS h
        WHERE h.IdIsporuke = i.IdIsporuke
        ORDER BY
            h.DatVremePromene DESC,
            h.IdIstorije DESC
    ) AS prethodna
    WHERE
        d.IdIsporuke IS NULL
        OR
        (
            d.IdIsporuke IS NOT NULL
            AND i.StatusIs <> d.StatusIs
        );
END;
GO

/* ============================================================
   ПРОВЕРА УНЕТИХ ТРИГЕРА
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