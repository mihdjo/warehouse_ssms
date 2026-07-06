USE [IsporukaDB];
GO

/* ============================================================
   02_CreateTables.sql

   Циљ:
   - Креирање физичких табела у impl слоју
   - Дефинисање примарних и страних кључева
   - Дефинисање ограничења
   - Креирање индекса, укључујући Partitioned Clustered Index
   - Креирање табела за историју статуса и CLR audit

   Табеле:
   - impl.tblProizvod
   - impl.tblPosiljalac
   - impl.tblIsporuka
   - impl.tblIstorijaStatusaIsporuke
   - impl.tblAuditIsporukaStatusa

   ============================================================ */

IF OBJECT_ID(N'impl.tblAuditIsporukaStatusa', N'U') IS NOT NULL
    DROP TABLE impl.tblAuditIsporukaStatusa;
GO

IF OBJECT_ID(N'impl.tblIstorijaStatusaIsporuke', N'U') IS NOT NULL
    DROP TABLE impl.tblIstorijaStatusaIsporuke;
GO

IF OBJECT_ID(N'impl.tblIsporuka', N'U') IS NOT NULL
    DROP TABLE impl.tblIsporuka;
GO

IF OBJECT_ID(N'impl.tblProizvod', N'U') IS NOT NULL
    DROP TABLE impl.tblProizvod;
GO

IF OBJECT_ID(N'impl.tblPosiljalac', N'U') IS NOT NULL
    DROP TABLE impl.tblPosiljalac;
GO

/* ============================================================
   ТАБЕЛА ПРОИЗВОДА

   Чува основне податке о производима који се испоручују.
   Називи и опис не смеју бити празни док тежина мора бити 
   позитивна вредност.
   ============================================================ */

CREATE TABLE impl.tblProizvod
(
    IdProizvoda INT IDENTITY(1,1) NOT NULL,
    Naziv NVARCHAR(100) NOT NULL,
    Opis NVARCHAR(1000) NOT NULL,
    Tezina DECIMAL(10,2) NOT NULL,

    CONSTRAINT pk_tblProizvod
        PRIMARY KEY CLUSTERED (IdProizvoda),

    CONSTRAINT ck_tblProizvod_IdProizvoda
        CHECK (IdProizvoda > 0),

    CONSTRAINT ck_tblProizvod_Naziv_NotBlank
        CHECK (LEN(LTRIM(RTRIM(Naziv))) > 0),

    CONSTRAINT ck_tblProizvod_Opis_NotBlank
        CHECK (LEN(LTRIM(RTRIM(Opis))) > 0),

    CONSTRAINT ck_tblProizvod_Tezina_Positive
        CHECK (Tezina > 0)
);
GO

/* ============================================================
   ТАБЕЛА ПОШИЉАЛАЦ

   Чува податке о компанијама које шаљу производе. Електронска
   пошта се проверава кроз CHECK ограничење. Телефон је опциони 
   податак, зато је експлицитно NULL.
   ============================================================ */

CREATE TABLE impl.tblPosiljalac
(
    IdPosiljaoca INT IDENTITY(1,1) NOT NULL,
    NazivKompanije NVARCHAR(150) NOT NULL,
    Email NVARCHAR(150) NOT NULL,
    Telefon NVARCHAR(50) NULL,

    CONSTRAINT pk_tblPosiljalac
        PRIMARY KEY CLUSTERED (IdPosiljaoca),

    CONSTRAINT ck_tblPosiljalac_IdPosiljaoca
        CHECK (IdPosiljaoca > 0),

    CONSTRAINT ck_tblPosiljalac_NazivKompanije_NotBlank
        CHECK (LEN(LTRIM(RTRIM(NazivKompanije))) > 0),

    CONSTRAINT ck_tblPosiljalac_Email_Format
        CHECK (
            LEN(LTRIM(RTRIM(Email))) > 0
            AND CHARINDEX(N'@', Email) > 1
            AND CHARINDEX(N'.', Email) > CHARINDEX(N'@', Email) + 1
        )
);
GO

/* ============================================================
   ТАБЕЛА ИСПОРУКА

   Свака испорука има тачно један производ и једног пошиљаоца.
   StatusIs има почетну вредност "Примљена".
   ============================================================ */

CREATE TABLE impl.tblIsporuka
(
    IdIsporuke INT IDENTITY(1,1) NOT NULL,
    Adresa NVARCHAR(300) NOT NULL,
    Napomena NVARCHAR(MAX) NULL,

    StatusIs NVARCHAR(20) NOT NULL
        CONSTRAINT df_tblIsporuka_StatusIs DEFAULT N'Примљена',

    DatVreme DATETIME2(0) NOT NULL
        CONSTRAINT df_tblIsporuka_DatVreme DEFAULT SYSDATETIME(),

    IdProizvoda INT NOT NULL,
    IdPosiljaoca INT NOT NULL,

    CONSTRAINT pk_tblIsporuka
        PRIMARY KEY NONCLUSTERED (IdIsporuke),

    CONSTRAINT ck_tblIsporuka_IdIsporuke
        CHECK (IdIsporuke > 0),

    CONSTRAINT ck_tblIsporuka_Adresa_NotBlank
        CHECK (LEN(LTRIM(RTRIM(Adresa))) > 0),

    CONSTRAINT ck_tblIsporuka_StatusIs
        CHECK (StatusIs IN 
        (
            N'Примљена',
            N'УТранспорту',
            N'Испоручена',
            N'Враћена'
        )),

    CONSTRAINT fk_tblIsporuka_tblProizvod
        FOREIGN KEY (IdProizvoda)
        REFERENCES impl.tblProizvod(IdProizvoda),

    CONSTRAINT fk_tblIsporuka_tblPosiljalac
        FOREIGN KEY (IdPosiljaoca)
        REFERENCES impl.tblPosiljalac(IdPosiljaoca)
);
GO

/* ============================================================
   PARTITIONED CLUSTERED INDEX

   Табела impl.tblIsporuka се физички организује по DatVreme, 
   чиме се омогућава партиционисање испорука по години.
   ============================================================ */

CREATE CLUSTERED INDEX idx_tblIsporuka_DatVreme_IdIsporuke
ON impl.tblIsporuka(DatVreme, IdIsporuke)
ON psIsporukaPoGodini(DatVreme);
GO


CREATE NONCLUSTERED INDEX idx_tblIsporuka_IdProizvoda
ON impl.tblIsporuka(IdProizvoda);
GO

CREATE NONCLUSTERED INDEX idx_tblIsporuka_IdPosiljaoca
ON impl.tblIsporuka(IdPosiljaoca);
GO

CREATE NONCLUSTERED INDEX idx_tblIsporuka_StatusIs_DatVreme_Covering
ON impl.tblIsporuka
(
    StatusIs,
    DatVreme
)
INCLUDE
(
    Adresa,
    IdProizvoda,
    IdPosiljaoca
)
ON psIsporukaPoGodini(DatVreme);
GO

/* ============================================================
   ТАБЕЛА ИСТОРИЈЕ СТАТУСА ИСПОРУКЕ

   Чува ланац промена статуса. Колона IdPrethodneIstorije
   омогућава рекурзивни приказ тока статуса помоћу 
   CommonTableExpressions приступа. (WITH keyword)
   ============================================================ */

CREATE TABLE impl.tblIstorijaStatusaIsporuke
(
    IdIstorije INT IDENTITY(1,1) NOT NULL,
    IdIsporuke INT NOT NULL,

    StariStatus NVARCHAR(20) NULL,
    NoviStatus NVARCHAR(20) NOT NULL,

    DatVremePromene DATETIME2(0) NOT NULL
        CONSTRAINT df_tblIstorijaStatusaIsporuke_DatVremePromene
        DEFAULT SYSDATETIME(),

    IdPrethodneIstorije INT NULL,

    CONSTRAINT pk_tblIstorijaStatusaIsporuke
        PRIMARY KEY CLUSTERED (IdIstorije),

    CONSTRAINT ck_tblIstorijaStatusaIsporuke_IdIstorije
        CHECK (IdIstorije > 0),

    CONSTRAINT ck_tblIstorijaStatusaIsporuke_IdIsporuke
        CHECK (IdIsporuke > 0),

    CONSTRAINT ck_tblIstorijaStatusaIsporuke_StariStatus
        CHECK (
            StariStatus IS NULL OR
            StariStatus IN
            (
                N'Примљена',
                N'УТранспорту',
                N'Испоручена',
                N'Враћена'
            )
        ),

    CONSTRAINT ck_tblIstorijaStatusaIsporuke_NoviStatus
        CHECK (
            NoviStatus IN
            (
                N'Примљена',
                N'УТранспорту',
                N'Испоручена',
                N'Враћена'
            )
        ),

    CONSTRAINT fk_tblIstorijaStatusaIsporuke_tblIsporuka
        FOREIGN KEY (IdIsporuke)
        REFERENCES impl.tblIsporuka(IdIsporuke),

    CONSTRAINT fk_tblIstorijaStatusaIsporuke_Prethodna
        FOREIGN KEY (IdPrethodneIstorije)
        REFERENCES impl.tblIstorijaStatusaIsporuke(IdIstorije)
);
GO

CREATE NONCLUSTERED INDEX idx_tblIstorijaStatusaIsporuke_IdIsporuke_DatVreme
ON impl.tblIstorijaStatusaIsporuke
(
    IdIsporuke,
    DatVremePromene,
    IdIstorije
)
INCLUDE
(
    StariStatus,
    NoviStatus,
    IdPrethodneIstorije
);
GO


CREATE NONCLUSTERED INDEX idx_tblIstorijaStatusaIsporuke_IdPrethodne
ON impl.tblIstorijaStatusaIsporuke
(
    IdPrethodneIstorije
);
GO

SELECT 
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
WHERE s.name = N'impl'
ORDER BY t.name;
GO

/* ============================================================
   АУДИТ ТАБЕЛА ЗА CLR DML ТРИГЕР

   У ову табелу CLR тригер уписује сваку промену над StatusIs,
   заједно са информацијама о логину, хосту и апликацији.
   ============================================================ */

CREATE TABLE impl.tblAuditIsporukaStatusa
(
    IdAudit INT IDENTITY(1,1) NOT NULL,
    IdIsporuke INT NOT NULL,

    StariStatus NVARCHAR(20) NULL,
    NoviStatus NVARCHAR(20) NOT NULL,

    DatVremeAudit DATETIME2(0) NOT NULL
        CONSTRAINT df_tblAuditIsporukaStatusa_DatVremeAudit
        DEFAULT SYSDATETIME(),

    LoginName NVARCHAR(200) NULL,
    HostName NVARCHAR(200) NULL,
    ApplicationName NVARCHAR(200) NULL,

    CONSTRAINT pk_tblAuditIsporukaStatusa
        PRIMARY KEY CLUSTERED (IdAudit),

    CONSTRAINT ck_tblAuditIsporukaStatusa_IdAudit
        CHECK (IdAudit > 0),

    CONSTRAINT ck_tblAuditIsporukaStatusa_IdIsporuke
        CHECK (IdIsporuke > 0),

    CONSTRAINT ck_tblAuditIsporukaStatusa_StariStatus
        CHECK
        (
            StariStatus IS NULL OR
            StariStatus IN
            (
                N'Примљена',
                N'УТранспорту',
                N'Испоручена',
                N'Враћена'
            )
        ),

    CONSTRAINT ck_tblAuditIsporukaStatusa_NoviStatus
        CHECK
        (
            NoviStatus IN
            (
                N'Примљена',
                N'УТранспорту',
                N'Испоручена',
                N'Враћена'
            )
        ),

    CONSTRAINT fk_tblAuditIsporukaStatusa_tblIsporuka
        FOREIGN KEY (IdIsporuke)
        REFERENCES impl.tblIsporuka(IdIsporuke)
);
GO


CREATE NONCLUSTERED INDEX idx_tblAuditIsporukaStatusa_IdIsporuke_DatVreme
ON impl.tblAuditIsporukaStatusa
(
    IdIsporuke,
    DatVremeAudit
)
INCLUDE
(
    StariStatus,
    NoviStatus,
    LoginName,
    HostName,
    ApplicationName
);
GO

/* ============================================================
   ПРОВЕРА КРЕИРАНИХ ТАБЕЛА
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
   ПРОВЕРА ИНДЕКСА НАД ТАБЕЛОМ impl.tblIsporuka

   Да ли је clustered index над податком DatVreme успешно повезан
   са partition шемом.
   ============================================================ */

SELECT 
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ds.name AS DataSpaceName
FROM sys.indexes AS i
INNER JOIN sys.data_spaces AS ds
    ON i.data_space_id = ds.data_space_id
WHERE i.object_id = OBJECT_ID(N'impl.tblIsporuka')
ORDER BY i.name;
GO


/* ============================================================
   ПРОВЕРА ОГРАНИЧЕЊА У impl СЛОЈУ
   ============================================================ */

SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    c.name AS ConstraintName,
    c.type_desc AS ConstraintType
FROM sys.objects AS c
INNER JOIN sys.tables AS t
    ON c.parent_object_id = t.object_id
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE s.name = N'impl'
  AND c.type IN ('PK', 'F', 'C', 'D')
ORDER BY t.name, c.type_desc, c.name;
GO