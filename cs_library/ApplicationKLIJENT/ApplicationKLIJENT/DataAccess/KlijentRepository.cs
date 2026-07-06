using ApplicationKLIJENT.Domain;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace ApplicationKLIJENT.DataAccess
{
    /*
        Repository sloj klijentske aplikacije.

        Ova klasa komunicira sa bazom isključivo preko api_klijent šeme.
        Klijentska aplikacija zato vidi samo podatke koji su namenjeni klijentu,
        bez direktnog pristupa internim tabelama i logističkim detaljima.
    */
    public class KlijentRepository
    {
        private readonly DbConnectionFactory _connectionFactory;

        public KlijentRepository(DbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        /*
            Vraća sve isporuke koje su dostupne klijentu.
            Podaci se čitaju iz API pogleda api_klijent.ISPORUKE.
        */
        public List<IsporukaKlijent> VratiSveIsporuke()
        {
            List<IsporukaKlijent> isporuke = new List<IsporukaKlijent>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand(
                @"SELECT IdIsporuke, NazivProizvoda, Adresa, StatusIs, DatVreme, Napomena
                  FROM api_klijent.ISPORUKE
                  ORDER BY IdIsporuke;", connection))
            using (SqlDataReader reader = command.ExecuteReader())
            {
                while (reader.Read())
                {
                    isporuke.Add(MapirajIsporuku(reader));
                }
            }

            return isporuke;
        }

        /*
            Vraća broj isporuka po statusu.
        */
        public List<StatusPregled> VratiStatuseIsporuka()
        {
            List<StatusPregled> statusi = new List<StatusPregled>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand(
                @"SELECT StatusIs, BrojIsporuka
                  FROM api_klijent.STATUSI_ISPORUKA
                  ORDER BY StatusIs;", connection))
            using (SqlDataReader reader = command.ExecuteReader())
            {
                while (reader.Read())
                {
                    statusi.Add(new StatusPregled
                    {
                        StatusIs = reader.GetString(0),
                        BrojIsporuka = reader.GetInt32(1)
                    });
                }
            }

            return statusi;
        }

        /*
            Vraća jednu isporuku na osnovu njenog identifikatora.
            Provera postojanja isporuke dodatno se vrši u SQL proceduri.
        */
        public IsporukaKlijent PogledajIsporuku(int idIsporuke)
        {
            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_klijent.PogledajIsporuku", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@idIsporuke", SqlDbType.Int).Value = idIsporuke;

                using (SqlDataReader reader = command.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        return MapirajIsporuku(reader);
                    }
                }
            }

            return null;
        }

        /*
            Vraća samo status i datum/vreme za izabranu isporuku.
        */
        public IsporukaStatus PogledajStatusIsporuke(int idIsporuke)
        {
            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_klijent.PogledajStatusIsporuke", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@idIsporuke", SqlDbType.Int).Value = idIsporuke;

                using (SqlDataReader reader = command.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        return new IsporukaStatus
                        {
                            IdIsporuke = reader.GetInt32(0),
                            StatusIs = reader.GetString(1),
                            DatVreme = reader.GetDateTime(2)
                        };
                    }
                }
            }

            return null;
        }

        /*
            Vraća isporuke filtrirane po statusu.
        */
        public List<IsporukaKlijent> PregledIsporukaPoStatusu(string statusIs)
        {
            List<IsporukaKlijent> isporuke = new List<IsporukaKlijent>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_klijent.PregledIsporukaPoStatusu", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@statusIs", SqlDbType.NVarChar, 20).Value = statusIs;

                using (SqlDataReader reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        isporuke.Add(MapirajIsporuku(reader));
                    }
                }
            }

            return isporuke;
        }

        /*
            Obična tekstualna pretraga isporuka.
            U bazi se koristi LIKE pretraga nad podacima dostupnim klijentu.
        */
        public List<IsporukaKlijent> PretraziIsporuke(string tekst)
        {
            List<IsporukaKlijent> isporuke = new List<IsporukaKlijent>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_klijent.PretraziIsporuke", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@tekst", SqlDbType.NVarChar, 200).Value = tekst;

                using (SqlDataReader reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        isporuke.Add(MapirajIsporuku(reader));
                    }
                }
            }

            return isporuke;
        }

        /*
            Full-Text pretraga isporuka po napomeni.
            SQL procedura koristi CONTAINS nad full-text indeksom.
        */
        public List<IsporukaKlijent> PretraziIsporukeNapomena(string tekst)
        {
            List<IsporukaKlijent> isporuke = new List<IsporukaKlijent>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_klijent.PretraziIsporukeNapomena", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@tekst", SqlDbType.NVarChar, 200).Value = tekst;

                using (SqlDataReader reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        isporuke.Add(MapirajIsporuku(reader));
                    }
                }
            }

            return isporuke;
        }

        /*
            Full-Text NEAR pretraga po napomeni isporuke.
            Koristi se za pronalaženje dve reči koje se nalaze blizu jedna drugoj.
        */
        public List<IsporukaKlijent> PretraziIsporukeNapomenaNear(
            string prvaRec,
            string drugaRec,
            int udaljenost)
        {
            List<IsporukaKlijent> isporuke = new List<IsporukaKlijent>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_klijent.PretraziIsporukeNapomenaNear", connection))
            {
                command.CommandType = CommandType.StoredProcedure;

                command.Parameters.Add("@prvaRec", SqlDbType.NVarChar, 100).Value = prvaRec;
                command.Parameters.Add("@drugaRec", SqlDbType.NVarChar, 100).Value = drugaRec;
                command.Parameters.Add("@udaljenost", SqlDbType.Int).Value = udaljenost;

                using (SqlDataReader reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        isporuke.Add(MapirajIsporuku(reader));
                    }
                }
            }

            return isporuke;
        }

        /*
            Vraća istoriju statusa jedne isporuke.
            Na ovaj način klijent može da vidi tok promene statusa isporuke.
        */
        public List<IstorijaStatusa> PogledajIstorijuStatusa(int idIsporuke)
        {
            List<IstorijaStatusa> istorija = new List<IstorijaStatusa>();

            using (SqlConnection connection = _connectionFactory.CreateOpenConnection())
            using (SqlCommand command = new SqlCommand("api_klijent.PogledajIstorijuStatusa", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@idIsporuke", SqlDbType.Int).Value = idIsporuke;

                using (SqlDataReader reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        istorija.Add(new IstorijaStatusa
                        {
                            Redosled = Convert.ToInt32(reader["Redosled"]),
                            IdIsporuke = Convert.ToInt32(reader["IdIsporuke"]),

                            StariStatus = reader["StariStatus"] == DBNull.Value
                                ? null
                                : reader["StariStatus"].ToString(),

                            NoviStatus = reader["NoviStatus"].ToString(),
                            DatVremePromene = Convert.ToDateTime(reader["DatVremePromene"])
                        });
                    }
                }
            }

            return istorija;
        }

        /*
            Pomoćna metoda za mapiranje reda iz SqlDataReader-a
            u objekat IsporukaKlijent.
        */
        private IsporukaKlijent MapirajIsporuku(SqlDataReader reader)
        {
            return new IsporukaKlijent
            {
                IdIsporuke = reader.GetInt32(0),
                NazivProizvoda = reader.GetString(1),
                Adresa = reader.GetString(2),
                StatusIs = reader.GetString(3),
                DatVreme = reader.GetDateTime(4),
                Napomena = reader.IsDBNull(5) ? null : reader.GetString(5)
            };
        }
    }
}