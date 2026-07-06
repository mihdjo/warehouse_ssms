USE [IsporukaDB];
GO

/* ============================================================
   06_CreateSpecProcedures.sql

   Циљ:
   - Креирање процедура и функција у spec слоју
   - Централизација пословне логике
   - Валидација улазних параметара и бацање јединствених изузетака
   - Рад над impl табелама без директног приступа из апликација

   Објекти:
   - spec.upr_DodajProizvod
   - spec.upr_DodajPosiljaoca
   - spec.upr_KreirajIsporuku
   - spec.upr_PromeniStatusIsporuke
   - spec.upr_AzurirajNapomenu
   - spec.upr_ObrisiIsporuku
   - spec.fnt_LanacStatusaIsporuke
   - spec.upr_GenerisiXmlIsporuke
   - spec.upr_AktivniUpiti
   ============================================================ */

/* ============================================================
   ПРОЦЕДУРЕ ЗА УНОС ОСНОВНИХ ЕНТИТЕТА

   Ове процедуре валидирају улазне вредности и затим уписују
   производе, пошиљаоце и испоруке у impl табеле.
   ============================================================ */

CREATE OR ALTER PROCEDURE spec.upr_DodajProizvod
(
    @naziv NVARCHAR(100),
    @opis NVARCHAR(1000),
    @tezina DECIMAL(10,2)
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @naziv IS NULL OR LEN(LTRIM(RTRIM(@naziv))) = 0
    BEGIN
        THROW 52001, N'Назив производа не сме бити празан.', 1;
    END;

    IF @opis IS NULL OR LEN(LTRIM(RTRIM(@opis))) = 0
    BEGIN
        THROW 52002, N'Опис производа не сме бити празан.', 1;
    END;

    IF @tezina IS NULL OR @tezina <= 0
    BEGIN
        THROW 52003, N'Тежина производа мора бити позитивна вредност.', 1;
    END;

    INSERT INTO impl.tblProizvod
    (
        Naziv,
        Opis,
        Tezina
    )
    VALUES
    (
        LTRIM(RTRIM(@naziv)),
        LTRIM(RTRIM(@opis)),
        @tezina
    );

    SELECT 
        CAST(SCOPE_IDENTITY() AS INT) AS IdProizvoda;
END;
GO


CREATE OR ALTER PROCEDURE spec.upr_DodajPosiljaoca
(
    @nazivKompanije NVARCHAR(150),
    @email NVARCHAR(150),
    @telefon NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @nazivKompanije IS NULL OR LEN(LTRIM(RTRIM(@nazivKompanije))) = 0
    BEGIN
        THROW 52004, N'Назив компаније пошиљаоца не сме бити празан.', 1;
    END;

    IF @email IS NULL 
       OR LEN(LTRIM(RTRIM(@email))) = 0
       OR CHARINDEX(N'@', @email) <= 1
       OR CHARINDEX(N'.', @email) <= CHARINDEX(N'@', @email) + 1
    BEGIN
        THROW 52005, N'Е-маил пошиљаоца мора бити у исправном формату.', 1;
    END;

    INSERT INTO impl.tblPosiljalac
    (
        NazivKompanije,
        Email,
        Telefon
    )
    VALUES
    (
        LTRIM(RTRIM(@nazivKompanije)),
        LTRIM(RTRIM(@email)),
        NULLIF(LTRIM(RTRIM(@telefon)), N'')
    );

    SELECT 
        CAST(SCOPE_IDENTITY() AS INT) AS IdPosiljaoca;
END;
GO


CREATE OR ALTER PROCEDURE spec.upr_KreirajIsporuku
(
    @adresa NVARCHAR(300),
    @napomena NVARCHAR(MAX) = NULL,
    @datVreme DATETIME2(0) = NULL,
    @idProizvoda INT,
    @idPosiljaoca INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @adresa IS NULL OR LEN(LTRIM(RTRIM(@adresa))) = 0
    BEGIN
        THROW 52006, N'Адреса испоруке не сме бити празна.', 1;
    END;

    IF @datVreme IS NULL
    BEGIN
        SET @datVreme = SYSDATETIME();
    END;

    IF @datVreme > SYSDATETIME()
    BEGIN
        THROW 52007, N'Датум и време испоруке не могу бити у будућности.', 1;
    END;

    IF @idProizvoda IS NULL OR @idProizvoda <= 0
    BEGIN
        THROW 52008, N'Ид производа мора бити цео број већи од нуле.', 1;
    END;

    IF @idPosiljaoca IS NULL OR @idPosiljaoca <= 0
    BEGIN
        THROW 52009, N'Ид пошиљаоца мора бити цео број већи од нуле.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM impl.tblProizvod
        WHERE IdProizvoda = @idProizvoda
    )
    BEGIN
        THROW 52010, N'Производ са прослеђеним идентификатором не постоји.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM impl.tblPosiljalac
        WHERE IdPosiljaoca = @idPosiljaoca
    )
    BEGIN
        THROW 52011, N'Пошиљалац са прослеђеним идентификатором не постоји.', 1;
    END;

    INSERT INTO impl.tblIsporuka
    (
        Adresa,
        Napomena,
        DatVreme,
        IdProizvoda,
        IdPosiljaoca
    )
    VALUES
    (
        LTRIM(RTRIM(@adresa)),
        NULLIF(LTRIM(RTRIM(@napomena)), N''),
        @datVreme,
        @idProizvoda,
        @idPosiljaoca
    );

    SELECT 
        CAST(SCOPE_IDENTITY() AS INT) AS IdIsporuke;
END;
GO

/* ============================================================
   ПРОМЕНА СТАТУСА ИСПОРУКЕ
   
   Процедура проверава да ли нови статус прати дозвољени ток:
   Примљена → УТранспорту → Испоручена / Враћена.
   Додатна заштита постоји и кроз тригер у impl слоју!
   ============================================================ */

CREATE OR ALTER PROCEDURE spec.upr_PromeniStatusIsporuke
(
    @idIsporuke INT,
    @noviStatus NVARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @trenutniStatus NVARCHAR(20);

    IF @idIsporuke IS NULL OR @idIsporuke <= 0
    BEGIN
        THROW 52012, N'Ид испоруке мора бити цео број већи од нуле.', 1;
    END;

    IF @noviStatus IS NULL OR LEN(LTRIM(RTRIM(@noviStatus))) = 0
    BEGIN
        THROW 52013, N'Нови статус испоруке не сме бити празан.', 1;
    END;

    SET @noviStatus = LTRIM(RTRIM(@noviStatus));

    IF @noviStatus NOT IN 
    (
        N'Примљена',
        N'УТранспорту',
        N'Испоручена',
        N'Враћена'
    )
    BEGIN
        THROW 52014, N'Нови статус испоруке није дозвољен.', 1;
    END;

    SELECT 
        @trenutniStatus = StatusIs
    FROM impl.tblIsporuka
    WHERE IdIsporuke = @idIsporuke;

    IF @trenutniStatus IS NULL
    BEGIN
        THROW 52015, N'Испорука са прослеђеним идентификатором не постоји.', 1;
    END;

    IF @trenutniStatus = @noviStatus
    BEGIN
        SELECT 
            @idIsporuke AS IdIsporuke,
            @trenutniStatus AS StatusIs;

        RETURN;
    END;

    IF NOT
    (
        (@trenutniStatus = N'Примљена' AND @noviStatus = N'УТранспорту')
        OR
        (@trenutniStatus = N'УТранспорту' AND @noviStatus IN (N'Испоручена', N'Враћена'))
    )
    BEGIN
        THROW 52016, N'Недозвољен прелаз статуса испоруке.', 1;
    END;

    UPDATE impl.tblIsporuka
    SET StatusIs = @noviStatus
    WHERE IdIsporuke = @idIsporuke;

    SELECT 
        IdIsporuke,
        StatusIs
    FROM impl.tblIsporuka
    WHERE IdIsporuke = @idIsporuke;
END;
GO

/* ============================================================
   ПАРЦИЈАЛНО АЖУРИРАЊЕ НАПОМЕНЕ

   Користи .WRITE над колоном Napomena NVARCHAR(MAX).
   Ако је позиција NULL, текст се додаје на крај постојеће напомене.
   ============================================================ */

CREATE OR ALTER PROCEDURE spec.upr_AzurirajNapomenu
(
    @idIsporuke INT,
    @tekst NVARCHAR(MAX),
    @pozicija INT = NULL,
    @duzina INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @idIsporuke IS NULL OR @idIsporuke <= 0
    BEGIN
        THROW 56001, N'Ид испоруке мора бити цео број већи од нуле.', 1;
    END;

    IF @tekst IS NULL
    BEGIN
        THROW 56002, N'Текст за ажурирање напомене не сме бити NULL.', 1;
    END;

    IF @pozicija IS NOT NULL AND @pozicija < 0
    BEGIN
        THROW 56003, N'Позиција за .WRITE ажурирање не сме бити негативна.', 1;
    END;

    IF @duzina IS NULL OR @duzina < 0
    BEGIN
        THROW 56004, N'Дужина за .WRITE ажурирање не сме бити негативна.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM impl.tblIsporuka
        WHERE IdIsporuke = @idIsporuke
    )
    BEGIN
        THROW 56005, N'Испорука са прослеђеним идентификатором не постоји.', 1;
    END;

    /*
        .WRITE ради над NVARCHAR(MAX), али ако је вредност NULL,
        прво је постављамо на празан текст.
    */
    UPDATE impl.tblIsporuka
    SET Napomena = N''
    WHERE IdIsporuke = @idIsporuke
      AND Napomena IS NULL;

    /*
        Ако је @pozicija NULL, текст се додаје на крај.
        Ако је @pozicija задата, врши се парцијална измена од те позиције.
    */
    IF @pozicija IS NULL
    BEGIN
        UPDATE impl.tblIsporuka
        SET Napomena .WRITE(@tekst, NULL, 0)
        WHERE IdIsporuke = @idIsporuke;
    END
    ELSE
    BEGIN
        UPDATE impl.tblIsporuka
        SET Napomena .WRITE(@tekst, @pozicija, @duzina)
        WHERE IdIsporuke = @idIsporuke;
    END;

    SELECT
        IdIsporuke,
        Napomena
    FROM impl.tblIsporuka
    WHERE IdIsporuke = @idIsporuke;
END;
GO

CREATE OR ALTER PROCEDURE spec.upr_ObrisiIsporuku
(
    @idIsporuke INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @idIsporuke IS NULL OR @idIsporuke <= 0
    BEGIN
        THROW 52017, N'Ид испоруке мора бити цео број већи од нуле.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM impl.tblIsporuka
        WHERE IdIsporuke = @idIsporuke
    )
    BEGIN
        THROW 52018, N'Испорука са прослеђеним идентификатором не постоји.', 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        /*
            Аудит записи зависе од испоруке, па се бришу пре саме испоруке.
        */
        DELETE FROM impl.tblAuditIsporukaStatusa
        WHERE IdIsporuke = @idIsporuke;

        /*
            Историја статуса има self-reference преко IdPrethodneIstorije.
            Зато се брише од краја ланца ка почетку.
        */
        WHILE EXISTS
        (
            SELECT 1
            FROM impl.tblIstorijaStatusaIsporuke
            WHERE IdIsporuke = @idIsporuke
        )
        BEGIN
            DELETE h
            FROM impl.tblIstorijaStatusaIsporuke AS h
            WHERE h.IdIsporuke = @idIsporuke
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM impl.tblIstorijaStatusaIsporuke AS dete
                  WHERE dete.IdPrethodneIstorije = h.IdIstorije
              );
        END;

        DELETE FROM impl.tblIsporuka
        WHERE IdIsporuke = @idIsporuke;

        COMMIT TRANSACTION;

        SELECT 
            @idIsporuke AS ObrisanIdIsporuke;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        THROW;
    END CATCH;
END;
GO

/* ============================================================
   Рекурзивна функција за ланац статуса помоћу CTE приступа

   Функција прати IdPrethodneIstorije и враћа редослед промена
   статуса за једну испоруку.

   Моћна комбинација кључних речи WITH и UNION ALL даје информације
   од великог значаја за пословање.
   ============================================================ */

CREATE OR ALTER FUNCTION spec.fnt_LanacStatusaIsporuke
(
    @idIsporuke INT
)
RETURNS TABLE
AS
RETURN
(
    WITH LanacStatusa AS
    (
        SELECT
            h.IdIstorije,
            h.IdIsporuke,
            h.StariStatus,
            h.NoviStatus,
            h.DatVremePromene,
            h.IdPrethodneIstorije,
            1 AS Redosled
        FROM impl.tblIstorijaStatusaIsporuke AS h
        WHERE h.IdIsporuke = @idIsporuke
          AND h.IdPrethodneIstorije IS NULL

        UNION ALL  

        SELECT
            h.IdIstorije,
            h.IdIsporuke,
            h.StariStatus,
            h.NoviStatus,
            h.DatVremePromene,
            h.IdPrethodneIstorije,
            ls.Redosled + 1 AS Redosled
        FROM impl.tblIstorijaStatusaIsporuke AS h
        INNER JOIN LanacStatusa AS ls
            ON h.IdPrethodneIstorije = ls.IdIstorije
        WHERE h.IdIsporuke = @idIsporuke
    )
    SELECT
        Redosled,
        IdIstorije,
        IdIsporuke,
        StariStatus,
        NoviStatus,
        DatVremePromene,
        IdPrethodneIstorije
    FROM LanacStatusa
);
GO

/* ============================================================
   FOR XML PATH документ испоруке.

   Генерише XML документ за партнерске системе са уграђеним
   подацима о испоруци, производу, пошиљаоцу и историји статуса.
   ============================================================ */

CREATE OR ALTER PROCEDURE spec.upr_GenerisiXmlIsporuke
(
    @idIsporuke INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @idIsporuke IS NULL OR @idIsporuke <= 0
    BEGIN
        THROW 58001, N'Ид испоруке мора бити цео број већи од нуле.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM impl.tblIsporuka
        WHERE IdIsporuke = @idIsporuke
    )
    BEGIN
        THROW 58002, N'Испорука са прослеђеним идентификатором не постоји.', 1;
    END;

    SELECT
    (
        SELECT
            i.IdIsporuke AS [@Id],
            i.StatusIs AS [Status],
            CONVERT(NVARCHAR(19), i.DatVreme, 126) AS [DatVreme],
            i.Adresa AS [Adresa],
            i.Napomena AS [Napomena],

            (
                SELECT
                    p.IdProizvoda AS [@Id],
                    p.Naziv AS [Naziv],
                    p.Opis AS [Opis],
                    p.Tezina AS [Tezina]
                FROM impl.tblProizvod AS p
                WHERE p.IdProizvoda = i.IdProizvoda
                FOR XML PATH('Proizvod'), TYPE
            ),

            (
                SELECT
                    ps.IdPosiljaoca AS [@Id],
                    ps.NazivKompanije AS [NazivKompanije],
                    ps.Email AS [Email],
                    ps.Telefon AS [Telefon]
                FROM impl.tblPosiljalac AS ps
                WHERE ps.IdPosiljaoca = i.IdPosiljaoca
                FOR XML PATH('Posiljalac'), TYPE
            ),

            (
                SELECT
                    h.IdIstorije AS [@Id],
                    h.StariStatus AS [StariStatus],
                    h.NoviStatus AS [NoviStatus],
                    CONVERT(NVARCHAR(19), h.DatVremePromene, 126) AS [DatVremePromene],
                    h.IdPrethodneIstorije AS [IdPrethodneIstorije]
                FROM impl.tblIstorijaStatusaIsporuke AS h
                WHERE h.IdIsporuke = i.IdIsporuke
                ORDER BY h.DatVremePromene, h.IdIstorije
                FOR XML PATH('PromenaStatusa'), ROOT('IstorijaStatusa'), TYPE
            )

        FROM impl.tblIsporuka AS i
        WHERE i.IdIsporuke = @idIsporuke
        FOR XML PATH('Isporuka'), ROOT('DokumentIsporuke'), TYPE
    ) AS XmlDokumentIsporuke;
END;
GO

/* ============================================================
   DMV процедура за активне упите

   Користи се sys.dm_exec_requests и sys.dm_exec_sql_text за приказ
   тренутно активних SQL захтева.
   ============================================================ */

CREATE OR ALTER PROCEDURE spec.upr_AktivniUpiti
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.session_id AS SessionId,
        r.request_id AS RequestId,
        r.status AS StatusZahteva,
        r.command AS Komanda,
        r.cpu_time AS CpuTimeMs,
        r.total_elapsed_time AS UkupnoTrajanjeMs,
        r.reads AS BrojCitanja,
        r.writes AS BrojPisanja,
        r.logical_reads AS LogickaCitanja,
        r.wait_type AS TipCekanja,
        r.wait_time AS VremeCekanjaMs,
        r.blocking_session_id AS BlokiraGaSessionId,
        DB_NAME(r.database_id) AS NazivBaze,
        SUBSTRING
        (
            st.text,
            (r.statement_start_offset / 2) + 1,
            (
                (
                    CASE r.statement_end_offset
                        WHEN -1 THEN DATALENGTH(st.text)
                        ELSE r.statement_end_offset
                    END - r.statement_start_offset
                ) / 2
            ) + 1
        ) AS TrenutniSqlIskaz,
        st.text AS KompletanSqlTekst
    FROM sys.dm_exec_requests AS r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
    WHERE r.session_id <> @@SPID
    ORDER BY r.total_elapsed_time DESC;
END;
GO

/* ============================================================
   ПРОВЕРА СПЕЦ ПРОЦЕДУРА И ФУНКЦИЈА
   ============================================================ */

SELECT
    s.name AS SchemaName,
    o.name AS ObjectName,
    o.type_desc AS ObjectType
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
    ON o.schema_id = s.schema_id
WHERE s.name = N'spec'
  AND o.name IN
  (
      N'upr_DodajProizvod',
      N'upr_DodajPosiljaoca',
      N'upr_KreirajIsporuku',
      N'upr_PromeniStatusIsporuke',
      N'upr_AzurirajNapomenu',
      N'upr_ObrisiIsporuku',
      N'fnt_LanacStatusaIsporuke',
      N'upr_GenerisiXmlIsporuke',
      N'upr_AktivniUpiti'
  )
ORDER BY o.type_desc, o.name;
GO