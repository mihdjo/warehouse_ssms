using System.Data.SqlClient;
using Microsoft.SqlServer.Server;

public class IsporukaAuditTrigger
{
    [SqlTrigger(
        Name = "trg_clr_tblIsporuka_AuditStatus",
        Target = "impl.tblIsporuka",
        Event = "FOR UPDATE"
    )]
    public static void AuditStatusChange()
    {
        SqlTriggerContext triggerContext = SqlContext.TriggerContext;

        if (triggerContext == null)
        {
            return;
        }

        if (triggerContext.TriggerAction != TriggerAction.Update)
        {
            return;
        }

        using (SqlConnection connection = new SqlConnection("context connection=true"))
        {
            connection.Open();

            string sql = @"
                INSERT INTO impl.tblAuditIsporukaStatusa
                (
                    IdIsporuke,
                    StariStatus,
                    NoviStatus,
                    DatVremeAudit,
                    LoginName,
                    HostName,
                    ApplicationName
                )
                SELECT
                    i.IdIsporuke,
                    d.StatusIs AS StariStatus,
                    i.StatusIs AS NoviStatus,
                    SYSDATETIME() AS DatVremeAudit,
                    ORIGINAL_LOGIN() AS LoginName,
                    HOST_NAME() AS HostName,
                    APP_NAME() AS ApplicationName
                FROM inserted AS i
                INNER JOIN deleted AS d
                    ON i.IdIsporuke = d.IdIsporuke
                WHERE i.StatusIs <> d.StatusIs;
            ";

            using (SqlCommand command = new SqlCommand(sql, connection))
            {
                command.ExecuteNonQuery();
            }
        }
    }
}