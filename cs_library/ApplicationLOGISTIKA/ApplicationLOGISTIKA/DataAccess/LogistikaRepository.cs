using ApplicationLOGISTIKA.Domain;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace ApplicationLOGISTIKA.DataAccess
{
    /*
        Repository sloj za logističku aplikaciju.

        Ova klasa komunicira sa bazom isključivo preko api_logistika šeme.
        Ne koristi direktno impl ni spec objekte, čime se poštuje SSS arhitektura
        i ograničenje pristupa preko application role DataProviderLOGISTIKA.
    */
    public class LogistikaRepository
    {
        private readonly DbConnectionFactory _connectionFactory;

        public LogistikaRepository(DbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        /*
            Vraća sve proizvode preko API pogleda api_logistika.PROIZVODI.
        */
        public List<Proizvod> VratiProizvode()
        {
            List<Proizvod> proizvodi = new List<Proizvod>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand(
                @"SELECT IdProizvoda, Naziv, Opis, Tezina
                  FROM api_logistika.PROIZVODI
                  ORDER BY IdProizvoda;", connection))
            using (SqlDataReader reader = command.ExecuteReader())
            {
                while (reader.Read())
                {
                    proizvodi.Add(MapirajProizvod(reader));
                }
            }

            return proizvodi;
        }

        /*
            Vraća sve pošiljaoce preko API pogleda api_logistika.POSILJAOCI.
        */
        public List<Posiljalac> VratiPosiljaoce()
        {
            List<Posiljalac> posiljaoci = new List<Posiljalac>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand(
                @"SELECT IdPosiljaoca, NazivKompanije, Email, Telefon
                  FROM api_logistika.POSILJAOCI
                  ORDER BY IdPosiljaoca;", connection))
            using (SqlDataReader reader = command.ExecuteReader())
            {
                while (reader.Read())
                {
                    posiljaoci.Add(new Posiljalac
                    {
                        IdPosiljaoca = reader.GetInt32(0),
                        NazivKompanije = reader.GetString(1),
                        Email = reader.GetString(2),
                        Telefon = reader.IsDBNull(3) ? null : reader.GetString(3)
                    });
                }
            }

            return posiljaoci;
        }

        /*
            Vraća detaljan prikaz isporuka za logističku aplikaciju.
            Ovaj API pogled uključuje podatke o isporuci, proizvodu i pošiljaocu.
        */
        public List<IsporukaDetaljno> VratiIsporuke()
        {
            List<IsporukaDetaljno> isporuke = new List<IsporukaDetaljno>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand(
                @"SELECT IdIsporuke, Adresa, Napomena, StatusIs, DatVreme,
                         IdProizvoda, NazivProizvoda, OpisProizvoda, Tezina,
                         IdPosiljaoca, NazivKompanije, EmailPosiljaoca, TelefonPosiljaoca
                  FROM api_logistika.ISPORUKE_DETALJNO
                  ORDER BY IdIsporuke;", connection))
            using (SqlDataReader reader = command.ExecuteReader())
            {
                while (reader.Read())
                {
                    isporuke.Add(MapirajIsporukuDetaljno(reader));
                }
            }

            return isporuke;
        }

        /*
            Dodaje novi proizvod pozivom API procedure.
            Validacija se dodatno obavlja u proceduri u bazi.
        */
        public int DodajProizvod(string naziv, string opis, decimal tezina)
        {
            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_logistika.DodajProizvod", connection))
            {
                command.CommandType = CommandType.StoredProcedure;

                command.Parameters.Add("@naziv", SqlDbType.NVarChar, 100).Value = naziv;
                command.Parameters.Add("@opis", SqlDbType.NVarChar, 1000).Value = opis;

                SqlParameter tezinaParam = command.Parameters.Add("@tezina", SqlDbType.Decimal);
                tezinaParam.Precision = 10;
                tezinaParam.Scale = 2;
                tezinaParam.Value = tezina;

                object result = command.ExecuteScalar();
                return Convert.ToInt32(result);
            }
        }

        /*
            Dodaje novog pošiljaoca pozivom API procedure.
        */
        public int DodajPosiljaoca(string nazivKompanije, string email, string telefon)
        {
            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_logistika.DodajPosiljaoca", connection))
            {
                command.CommandType = CommandType.StoredProcedure;

                command.Parameters.Add("@nazivKompanije", SqlDbType.NVarChar, 150).Value =
                    nazivKompanije;

                command.Parameters.Add("@email", SqlDbType.NVarChar, 150).Value =
                    email;

                command.Parameters.Add("@telefon", SqlDbType.NVarChar, 50).Value =
                    string.IsNullOrWhiteSpace(telefon) ? (object)DBNull.Value : telefon;

                object result = command.ExecuteScalar();
                return Convert.ToInt32(result);
            }
        }

        /*
            Kreira novu isporuku.
            Napomena se šalje kao NVARCHAR(MAX), jer se u bazi koristi za .WRITE ažuriranje.
        */
        public int KreirajIsporuku(
            string adresa,
            string napomena,
            DateTime datVreme,
            int idProizvoda,
            int idPosiljaoca)
        {
            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_logistika.KreirajIsporuku", connection))
            {
                command.CommandType = CommandType.StoredProcedure;

                command.Parameters.Add("@adresa", SqlDbType.NVarChar, 300).Value = adresa;

                command.Parameters.Add("@napomena", SqlDbType.NVarChar, -1).Value =
                    string.IsNullOrWhiteSpace(napomena) ? (object)DBNull.Value : napomena;

                SqlParameter datVremeParam = command.Parameters.Add("@datVreme", SqlDbType.DateTime2);
                datVremeParam.Scale = 0;
                datVremeParam.Value = datVreme;

                command.Parameters.Add("@idProizvoda", SqlDbType.Int).Value = idProizvoda;
                command.Parameters.Add("@idPosiljaoca", SqlDbType.Int).Value = idPosiljaoca;

                object result = command.ExecuteScalar();
                return Convert.ToInt32(result);
            }
        }

        /*
            Menja status isporuke kroz API proceduru.
            Dozvoljeni tok statusa dodatno čuvaju procedura i trigger u bazi.
        */
        public void PromeniStatusIsporuke(int idIsporuke, string noviStatus)
        {
            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_logistika.PromeniStatusIsporuke", connection))
            {
                command.CommandType = CommandType.StoredProcedure;

                command.Parameters.Add("@idIsporuke", SqlDbType.Int).Value = idIsporuke;
                command.Parameters.Add("@noviStatus", SqlDbType.NVarChar, 20).Value = noviStatus;

                command.ExecuteNonQuery();
            }
        }

        /*
            Full-Text pretraga proizvoda po opisu.
            Poziva API proceduru koja koristi CONTAINS nad full-text indeksom.
        */
        public List<Proizvod> PretraziProizvodePoOpisu(string tekst)
        {
            List<Proizvod> proizvodi = new List<Proizvod>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_logistika.PretraziProizvodeOpis", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@tekst", SqlDbType.NVarChar, 200).Value = tekst;

                using (SqlDataReader reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        proizvodi.Add(MapirajProizvod(reader));
                    }
                }
            }

            return proizvodi;
        }

        /*
            Pokreće CLR dijagnostiku kašnjenja.

            SQL procedura može da vrati dodatne poruke iz CLR dela, pa se prolazi
            kroz više result set-ova dok se ne pronađe onaj koji sadrži podatke
            o isporukama koje kasne.
        */
        public List<IsporukaKasnjenje> DijagnostikujKasnjenja(int pragSati)
        {
            List<IsporukaKasnjenje> kasnjenja = new List<IsporukaKasnjenje>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_logistika.DijagnostikujKasnjenja", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@pragSati", SqlDbType.Int).Value = pragSati;

                using (SqlDataReader reader = command.ExecuteReader())
                {
                    do
                    {
                        if (DaLiJeResultSetKasnjenja(reader))
                        {
                            while (reader.Read())
                            {
                                kasnjenja.Add(new IsporukaKasnjenje
                                {
                                    IdIsporuke = Convert.ToInt32(reader["IdIsporuke"]),
                                    StatusIs = reader["StatusIs"].ToString(),
                                    DatVreme = Convert.ToDateTime(reader["DatVreme"]),
                                    SatiOdKreiranja = Convert.ToInt32(reader["SatiOdKreiranja"]),
                                    NazivProizvoda = reader["NazivProizvoda"].ToString(),
                                    NazivKompanije = reader["NazivKompanije"].ToString()
                                });
                            }

                            break;
                        }
                    }
                    while (reader.NextResult());
                }
            }

            return kasnjenja;
        }

        private Proizvod MapirajProizvod(SqlDataReader reader)
        {
            return new Proizvod
            {
                IdProizvoda = reader.GetInt32(0),
                Naziv = reader.GetString(1),
                Opis = reader.GetString(2),
                Tezina = reader.GetDecimal(3)
            };
        }

        private IsporukaDetaljno MapirajIsporukuDetaljno(SqlDataReader reader)
        {
            return new IsporukaDetaljno
            {
                IdIsporuke = reader.GetInt32(0),
                Adresa = reader.GetString(1),
                Napomena = reader.IsDBNull(2) ? null : reader.GetString(2),
                StatusIs = reader.GetString(3),
                DatVreme = reader.GetDateTime(4),

                IdProizvoda = reader.GetInt32(5),
                NazivProizvoda = reader.GetString(6),
                OpisProizvoda = reader.GetString(7),
                Tezina = reader.GetDecimal(8),

                IdPosiljaoca = reader.GetInt32(9),
                NazivKompanije = reader.GetString(10),
                EmailPosiljaoca = reader.GetString(11),
                TelefonPosiljaoca = reader.IsDBNull(12) ? null : reader.GetString(12)
            };
        }

        private bool DaLiJeResultSetKasnjenja(SqlDataReader reader)
        {
            if (reader.FieldCount < 6)
            {
                return false;
            }

            try
            {
                reader.GetOrdinal("IdIsporuke");
                reader.GetOrdinal("StatusIs");
                reader.GetOrdinal("DatVreme");
                reader.GetOrdinal("SatiOdKreiranja");
                reader.GetOrdinal("NazivProizvoda");
                reader.GetOrdinal("NazivKompanije");

                return true;
            }
            catch (IndexOutOfRangeException)
            {
                return false;
            }
        }
    }
}