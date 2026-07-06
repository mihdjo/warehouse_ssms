using System;
using System.Diagnostics;
using Microsoft.SqlServer.Server;
using System.Data.SqlTypes;

public class IsporukaDiagnostics
{
    [SqlProcedure]
    public static void UpisiKasnjenje(
        SqlInt32 idIsporuke,
        SqlString statusIs,
        SqlString datVreme,
        SqlInt32 satiKasnjenja,
        SqlInt32 pragSati
    )
    {
        string source = "IsporukaDB_CLR";

        string message =
            "Dijagnostika kasnjenja isporuke" + Environment.NewLine +
            "--------------------------------" + Environment.NewLine +
            "IdIsporuke: " + idIsporuke.Value + Environment.NewLine +
            "Status: " + statusIs.Value + Environment.NewLine +
            "DatVreme: " + datVreme.Value + Environment.NewLine +
            "Sati kasnjenja: " + satiKasnjenja.Value + Environment.NewLine +
            "Prag sati: " + pragSati.Value + Environment.NewLine +
            "Vreme dijagnostike: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");

        EventLog.WriteEntry(
            source,
            message,
            EventLogEntryType.Warning
        );

        SqlContext.Pipe.Send(
            "Windows Event Log zapis je kreiran za isporuku ID = "
            + idIsporuke.Value
        );
    }
}