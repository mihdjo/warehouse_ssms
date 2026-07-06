using System.Data;
using System.Data.SqlClient;

namespace ApplicationKLIJENT.DataAccess
{
    /*
        Klasa zadužena za kreiranje SQL konekcije ka bazi IsporukaDB.

        Nakon otvaranja konekcije aktivira se application role
        DataProviderKLIJENT. Time se klijentskoj aplikaciji omogućava pristup
        samo objektima iz api_klijent šeme, bez pristupa impl, spec i
        api_logistika sloju.
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

            _applicationRoleName = "DataProviderKLIJENT";
            _applicationRolePassword = "Klijent#2026!StrongPass";
        }

        /*
            Kreira i otvara SQL konekciju, a zatim aktivira application role.

            Pooling je isključen jer sp_setapprole menja bezbednosni kontekst
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
            sp_setapprole. Nakon ovoga konekcija radi kao DataProviderKLIJENT.
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