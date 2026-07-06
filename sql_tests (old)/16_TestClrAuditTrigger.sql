USE [IsporukaDB];
GO

DECLARE @novaIsporuka TABLE
(
    IdIsporuke INT
);

INSERT INTO @novaIsporuka
EXEC api_logistika.KreirajIsporuku
    @adresa = N'CLR audit тест адреса, Београд',
    @napomena = N'Испорука за проверу CLR DML trigger audit-a.',
    @datVreme = '2025-06-20T10:00:00',
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

EXEC api_logistika.PregledAuditStatusa
    @idIsporuke = @idIsporuke;
GO