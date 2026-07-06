USE [IsporukaDB];
GO

EXEC api_logistika.PretraziProizvodeOpis
    @tekst = N'пословну';
GO

EXEC api_klijent.PretraziIsporukeNapomena
    @tekst = N'брзу';
GO

EXEC api_klijent.PretraziIsporukeNapomenaNear
    @prvaRec = N'брзу',
    @drugaRec = N'испоруку',
    @udaljenost = 5;
GO