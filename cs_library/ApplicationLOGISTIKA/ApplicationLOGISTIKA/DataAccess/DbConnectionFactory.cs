using System.Data;
using System.Data.SqlClient;

namespace ApplicationLOGISTIKA.DataAccess
{
    /*
        Klasa zadužena za kreiranje SQL konekcije ka bazi IsporukaDB.

        Nakon otvaranja konekcije aktivira se application role
        DataProviderLOGISTIKA. Na taj način aplikacija pristupa isključivo
        objektima iz api_logistika šeme, bez direktnog pristupa impl i spec sloju.
    */
    public class DbConnectionFactory
    {
        private readonly string _connectionString;
        private readonly string _applicationRoleName;
        private readonly string _applicationRolePassword;

        public DbConnectionFactory()
        {
            _connectionString =
                @"Data Source=localhost\MSSQLSERVER02;" +
                @"Initial Catalog=IsporukaDB;" +
                @"Integrated Security=True;" +
                @"Encrypt=True;" +
                @"TrustServerCertificate=True;" +
                @"Pooling=False;";

            _applicationRoleName = "DataProviderLOGISTIKA";
            _applicationRolePassword = "SifraZaLogistiku#2026";
        }

        /*
            Kreira i otvara konekciju, a zatim aktivira application role.
            Pooling je isključen jer application role menja bezbednosni kontekst
            konekcije do njenog zatvaranja.
        */
        public SqlConnection CreateOpenConnection()
        {
            SqlConnection connection = new SqlConnection(_connectionString);
            connection.Open();

            ActivateApplicationRole(connection);

            return connection;
        }

        /*
            Aktivira SQL Server application role pomoću sistemske procedure
            sp_setapprole. Nakon ovoga konekcija radi kao DataProviderLOGISTIKA.
        */
        private void ActivateApplicationRole(SqlConnection connection)
        {
            using (SqlCommand command = new SqlCommand("sp_setapprole", connection))
            {
                command.CommandType = CommandType.StoredProcedure;

                command.Parameters.Add("@rolename", SqlDbType.NVarChar, 128).Value =
                    _applicationRoleName;

                command.Parameters.Add("@password", SqlDbType.NVarChar, 128).Value =
                    _applicationRolePassword;

                command.ExecuteNonQuery();
            }
        }
    }
}