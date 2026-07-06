USE [IsporukaDB];
GO

SELECT *
FROM api_klijent.ISPORUKE
ORDER BY IdIsporuke;
GO

SELECT *
FROM api_klijent.STATUSI_ISPORUKA;
GO

EXEC api_klijent.PogledajIsporuku
    @idIsporuke = 1;
GO

EXEC api_klijent.PogledajStatusIsporuke
    @idIsporuke = 1;
GO

EXEC api_klijent.PregledIsporukaPoStatusu
    @statusIs = N'УТранспорту';
GO

EXEC api_klijent.PretraziIsporuke
    @tekst = N'Београд';
GO

--FAIL CASE

--USE [IsporukaDB];
-- GO
--
-- EXEC api_klijent.PogledajIsporuku
--    @idIsporuke = -1;
--GO