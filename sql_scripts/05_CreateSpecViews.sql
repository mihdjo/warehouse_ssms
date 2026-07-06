USE [IsporukaDB];
GO

/* ============================================================
   05_CreateSpecViews.sql

   Циљ:
   - Креирање погледа у spec слоју
   - Сакривање директног приступа impl табелама
   - Припрема података за api_logistika и api_klijent слој

   Погледи:
   - spec.vw_Proizvodi
   - spec.vw_Posiljaoci
   - spec.vw_IsporukeDetaljno
   - spec.vw_IsporukeZaKlijenta
   - spec.vw_IsporukePoStatusu
   - spec.vw_IstorijaStatusaIsporuka
   - spec.vw_AuditIsporukaStatusa
   ============================================================ */

/* ============================================================
   ПОГЛЕД ПРОИЗВОДА

   Користи се као spec слој за приказ производа без директног 
   приступа табели impl.tblProizvod.
   ============================================================ */

CREATE OR ALTER VIEW spec.vw_Proizvodi
AS
SELECT
    p.IdProizvoda,
    p.Naziv,
    p.Opis,
    p.Tezina
FROM impl.tblProizvod AS p;
GO

/* ============================================================
   ПОГЛЕД ПОШИЉАЛАЦА

   Приказује основне податке о пошиљаоцима.
   Овај поглед користи се у логистичком АПИ слоју. (api_logistika)
   ============================================================ */

CREATE OR ALTER VIEW spec.vw_Posiljaoci
AS
SELECT
    ps.IdPosiljaoca,
    ps.NazivKompanije,
    ps.Email,
    ps.Telefon
FROM impl.tblPosiljalac AS ps;
GO

/* ============================================================
   ДЕТАЉАН ПРЕГЛЕД ИСПОРУКА

   Спаја испоруку, производ и пошиљаоца.
   Намењен логистичком делу система јер садржи све податке на 
   једном месту.
   ============================================================ */

CREATE OR ALTER VIEW spec.vw_IsporukeDetaljno
AS
SELECT
    i.IdIsporuke,
    i.Adresa,
    i.Napomena,
    i.StatusIs,
    i.DatVreme,

    p.IdProizvoda,
    p.Naziv AS NazivProizvoda,
    p.Opis AS OpisProizvoda,
    p.Tezina,

    ps.IdPosiljaoca,
    ps.NazivKompanije,
    ps.Email AS EmailPosiljaoca,
    ps.Telefon AS TelefonPosiljaoca
FROM impl.tblIsporuka AS i
INNER JOIN impl.tblProizvod AS p
    ON i.IdProizvoda = p.IdProizvoda
INNER JOIN impl.tblPosiljalac AS ps
    ON i.IdPosiljaoca = ps.IdPosiljaoca;
GO

/* ============================================================
   КЛИЈЕНТСКИ ПОГЛЕД ИСПОРУКА

   Приказује податке потребне клијенту, без осетљивих детаља о 
   пошиљаоцу попут email-а и телефона.
   ============================================================ */

CREATE OR ALTER VIEW spec.vw_IsporukeZaKlijenta
AS
SELECT
    i.IdIsporuke,
    p.Naziv AS NazivProizvoda,
    i.Adresa,
    i.StatusIs,
    i.DatVreme,
    i.Napomena
FROM impl.tblIsporuka AS i
INNER JOIN impl.tblProizvod AS p
    ON i.IdProizvoda = p.IdProizvoda;
GO

/* ============================================================
   АГРЕГИРАНИ ПОГЛЕД ПО СТАТУСУ

   Користи се за преглед броја испорука по статусима.
   ============================================================ */

CREATE OR ALTER VIEW spec.vw_IsporukePoStatusu
AS
SELECT
    i.StatusIs,
    COUNT(*) AS BrojIsporuka
FROM impl.tblIsporuka AS i
GROUP BY i.StatusIs;
GO

/* ============================================================
   ПОГЛЕД ИСТОРИЈЕ СТАТУСА

   Спаја историју статуса са испоруком производом и пошиљаоцем.
   Користи се за преглед тока статуса испоруке.
   ============================================================ */

CREATE OR ALTER VIEW spec.vw_IstorijaStatusaIsporuka
AS
SELECT
    h.IdIstorije,
    h.IdIsporuke,
    h.StariStatus,
    h.NoviStatus,
    h.DatVremePromene,
    h.IdPrethodneIstorije,

    i.Adresa,
    i.StatusIs AS TrenutniStatus,
    i.DatVreme AS DatVremeIsporuke,

    p.IdProizvoda,
    p.Naziv AS NazivProizvoda,

    ps.IdPosiljaoca,
    ps.NazivKompanije
FROM impl.tblIstorijaStatusaIsporuke AS h
INNER JOIN impl.tblIsporuka AS i
    ON h.IdIsporuke = i.IdIsporuke
INNER JOIN impl.tblProizvod AS p
    ON i.IdProizvoda = p.IdProizvoda
INNER JOIN impl.tblPosiljalac AS ps
    ON i.IdPosiljaoca = ps.IdPosiljaoca;
GO

/* ============================================================
   ПОГЛЕД АУДИТ ЗАПИСА

   Приказује податке које CLR DML тригер уписује приликом промене
   StatusIs вредности.
   ============================================================ */

CREATE OR ALTER VIEW spec.vw_AuditIsporukaStatusa
AS
SELECT
    a.IdAudit,
    a.IdIsporuke,
    a.StariStatus,
    a.NoviStatus,
    a.DatVremeAudit,
    a.LoginName,
    a.HostName,
    a.ApplicationName,

    i.Adresa,
    i.StatusIs AS TrenutniStatus,
    p.Naziv AS NazivProizvoda,
    ps.NazivKompanije
FROM impl.tblAuditIsporukaStatusa AS a
INNER JOIN impl.tblIsporuka AS i
    ON a.IdIsporuke = i.IdIsporuke
INNER JOIN impl.tblProizvod AS p
    ON i.IdProizvoda = p.IdProizvoda
INNER JOIN impl.tblPosiljalac AS ps
    ON i.IdPosiljaoca = ps.IdPosiljaoca;
GO

SELECT
    s.name AS SchemaName,
    v.name AS ViewName
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON v.schema_id = s.schema_id
WHERE s.name = N'spec'
ORDER BY v.name;
GO