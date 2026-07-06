USE [IsporukaDB];
GO

EXEC spec.upr_DodajProizvod
    @naziv = N'USB кабл',
    @opis = N'Кабл за пренос података и пуњење уређаја.',
    @tezina = 0.10;
GO

EXEC spec.upr_DodajPosiljaoca
    @nazivKompanije = N'Експрес Курир',
    @email = N'kontakt@ekspreskurir.rs',
    @telefon = N'060-333-444';
GO

EXEC spec.upr_KreirajIsporuku
    @adresa = N'Немањина 11, Београд',
    @napomena = N'Испоруку оставити на пријавници.',
    @datVreme = '2025-06-01T10:00:00',
    @idProizvoda = 4,
    @idPosiljaoca = 3;
GO

EXEC spec.upr_PromeniStatusIsporuke
    @idIsporuke = 4,
    @noviStatus = N'УТранспорту';
GO

SELECT *
FROM spec.vw_IsporukeDetaljno
ORDER BY IdIsporuke;
GO

-- Naredni test pada
--USE [IsporukaDB];
--GO

--EXEC spec.upr_DodajProizvod
  --  @naziv = N'',
  --  @opis = N'Тест опис',
  --  @tezina = 1.00;
-- GO