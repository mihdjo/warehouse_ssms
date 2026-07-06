USE [IsporukaDB];
GO

DECLARE @novaIsporuka TABLE
(
    IdIsporuke INT
);

INSERT INTO @novaIsporuka
EXEC api_logistika.KreirajIsporuku
    @adresa = N'Тест адреса 100, Београд',
    @napomena = N'Тест испорука за проверу историје статуса.',
    @datVreme = '2025-06-15T10:00:00',
    @idProizvoda = 1,
    @idPosiljaoca = 1;

DECLARE @idIsporuke INT =
(
    SELECT TOP 1 IdIsporuke
    FROM @novaIsporuka
);

EXEC api_logistika.PromeniStatusIsporuke
    @idIsporuke = @idIsporuke,
    @noviStatus = N'УТранспорту';

EXEC api_logistika.PromeniStatusIsporuke
    @idIsporuke = @idIsporuke,
    @noviStatus = N'Испоручена';

EXEC api_logistika.PregledIstorijeStatusa
    @idIsporuke = @idIsporuke;
GO