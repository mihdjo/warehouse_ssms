USE [IsporukaDB];
GO

/* ============================================================
   04_SeedDemoData.sql

   Циљ:
   - Брисање већ постојећих demo података
   - Ресетовање identity вредности
   - Унос почетних производа, пошиљалаца и испорука
   - Промена статуса испорука кроз дозвољени ток

   Напомена:
   Како су тригери већ креирани у претходној скрипти, 
   унос и измене испорука аутоматски пуне 
   табелу impl.tblIstorijaStatusaIsporuke

   ============================================================ */
   
/* ============================================================
   БРИСАЊЕ ПОСТОЈЕЋИХ ПОДАТАКА

   Редослед је битан због страних кључева:
   прво се бришу зависне табеле, а потом главне. (реф. интегритет!)
   ============================================================ */   
   
DELETE FROM impl.tblAuditIsporukaStatusa;
DELETE FROM impl.tblIstorijaStatusaIsporuke;
DELETE FROM impl.tblIsporuka;
DELETE FROM impl.tblProizvod;
DELETE FROM impl.tblPosiljalac;
GO

/* ============================================================
   РЕСЕТОВАЊЕ IDENTITY ВРЕДНОСТИ

   Identity вредности ресетују се да би демо подаци увек имали
   исте идентификаторе.
   ============================================================ */

DBCC CHECKIDENT ('impl.tblAuditIsporukaStatusa', RESEED, 0);
DBCC CHECKIDENT ('impl.tblIstorijaStatusaIsporuke', RESEED, 0);
DBCC CHECKIDENT ('impl.tblIsporuka', RESEED, 0);
DBCC CHECKIDENT ('impl.tblProizvod', RESEED, 0);
DBCC CHECKIDENT ('impl.tblPosiljalac', RESEED, 0);
GO

/* ============================================================
   УНОС ДЕМО ПОШИЉАЛАЦА
   ============================================================ */

SET IDENTITY_INSERT impl.tblPosiljalac ON;
GO

INSERT INTO impl.tblPosiljalac
(
    IdPosiljaoca,
    NazivKompanije,
    Email,
    Telefon
)
VALUES
(
    1,
    N'Технологија Д.О.О.',
    N'info@tehnologija.rs',
    N'011-123-4567'
),
(
    2,
    N'БрзаДостава',
    N'dostava@brzadostava.rs',
    N'064-111-2222'
);
GO

SET IDENTITY_INSERT impl.tblPosiljalac OFF;
GO

/* ============================================================
   УНОС ДЕМО ПРОИЗВОДА
   ============================================================ */

SET IDENTITY_INSERT impl.tblProizvod ON;
GO

INSERT INTO impl.tblProizvod
(
    IdProizvoda,
    Naziv,
    Opis,
    Tezina
)
VALUES
(
    1,
    N'Лаптоп Dell',
    N'Лаптоп за пословну употребу, серија Latitude',
    2.50
),
(
    2,
    N'Мобилни телефон',
    N'Паметни телефон средње класе',
    0.18
),
(
    3,
    N'Монитор 27 инча',
    N'IPS панел, Full HD, 75Hz освежавање',
    4.20
);
GO

SET IDENTITY_INSERT impl.tblProizvod OFF;
GO

/* ============================================================
   УНОС ДЕМО ИСПОРУКА

   StatusIs се не уноси експлицитно, већ се користи DEFAULT
   вредност "Примљена".
   ============================================================ */

SET IDENTITY_INSERT impl.tblIsporuka ON;
GO

INSERT INTO impl.tblIsporuka
(
    IdIsporuke,
    IdProizvoda,
    IdPosiljaoca,
    Adresa,
    Napomena,
    DatVreme
)
VALUES
(
    1,
    1,
    1,
    N'Кнез Михаилова 10, Београд',
    N'Испорука за пословног корисника.',
    '2025-03-10T14:30:00'
),
(
    2,
    2,
    1,
    N'Булевар Краља Александра 50, Нови Сад',
    N'Клијент захтева брзу испоруку.',
    '2025-04-15T09:00:00'
),
(
    3,
    3,
    2,
    N'Змај Јовина 3, Крагујевац',
    N'Пажљиво руковати због осетљиве опреме.',
    '2025-05-01T11:15:00'
);
GO

SET IDENTITY_INSERT impl.tblIsporuka OFF;
GO

/* ============================================================
   ПРОМЕНА СТАТУСА КРОЗ ДОЗВОЉЕНИ ТОК

   Овим се тестира тригер impl.trg_tblIsporuka_StatusIs, а 
   истовремено се пуни табела историје статуса.
   ============================================================ */
   
-- Испорука 1: Примљена -> УТранспорту -> Испоручена
UPDATE impl.tblIsporuka
SET StatusIs = N'УТранспорту'
WHERE IdIsporuke = 1;
GO

UPDATE impl.tblIsporuka
SET StatusIs = N'Испоручена'
WHERE IdIsporuke = 1;
GO

-- Испорука 2: Примљена -> УТранспорту
UPDATE impl.tblIsporuka
SET StatusIs = N'УТранспорту'
WHERE IdIsporuke = 2;
GO

-- Испорука 3 остаје Примљена

/* ============================================================
   ПРОВЕРА ДЕМО ПОДАТАКА
   ============================================================ */

SELECT
    IdProizvoda,
    Naziv,
    Opis,
    Tezina
FROM impl.tblProizvod
ORDER BY IdProizvoda;
GO

SELECT
    IdPosiljaoca,
    NazivKompanije,
    Email,
    Telefon
FROM impl.tblPosiljalac
ORDER BY IdPosiljaoca;
GO

SELECT
    IdIsporuke,
    IdProizvoda,
    IdPosiljaoca,
    Adresa,
    StatusIs,
    DatVreme,
    Napomena
FROM impl.tblIsporuka
ORDER BY IdIsporuke;
GO

SELECT
    IdIstorije,
    IdIsporuke,
    StariStatus,
    NoviStatus,
    DatVremePromene,
    IdPrethodneIstorije
FROM impl.tblIstorijaStatusaIsporuke
ORDER BY IdIsporuke, IdIstorije;
GO

/* ============================================================
   ДОДАТАК: ЧИШЋЕЊЕ АУДИТ ТАБЕЛЕ

   Аудит се тестира посебном скриптом након креирања CLR тригера.
   Овај део искључиво служи при поновном ручном покретању свих скрипти.
   ============================================================ */

DELETE FROM impl.tblAuditIsporukaStatusa;
GO

DBCC CHECKIDENT ('impl.tblAuditIsporukaStatusa', RESEED, 0);
GO