using ApplicationKLIJENT.DataAccess;
using ApplicationKLIJENT.Domain;
using ApplicationKLIJENT.Services;
using System;
using System.Collections.Generic;
using System.Text;

namespace ApplicationKLIJENT
{
    /*
        Konzolni korisnički interfejs za klijentsku aplikaciju.

        Korisnik kroz meni može da pregleda isporuke, proveri status,
        pretražuje isporuke, koristi Full-Text i NEAR pretragu i pregleda
        istoriju statusa isporuke.

        Aplikacija koristi service i repository sloj, a baza joj je dostupna
        isključivo kroz api_klijent šemu.
    */
    internal class Program
    {
        private static KlijentService _service;

        static void Main(string[] args)
        {
            /*
                UTF-8 se koristi za prikaz teksta u konzoli.

                Windows-1251 se koristi za unos ćirilice, jer klasična Windows
                konzola u nekim slučajevima sa UTF-8 unosom ubacuje NUL karaktere.
            */
            Console.OutputEncoding = Encoding.UTF8;
            Console.InputEncoding = Encoding.GetEncoding(1251);

            DbConnectionFactory factory = new DbConnectionFactory();
            KlijentRepository repository = new KlijentRepository(factory);
            _service = new KlijentService(repository);

            while (true)
            {
                try
                {
                    PrikaziMeni();

                    string izbor = Console.ReadLine();
                    Console.WriteLine();

                    switch (izbor)
                    {
                        case "1":
                            PrikaziSveIsporuke();
                            break;

                        case "2":
                            PogledajIsporuku();
                            break;

                        case "3":
                            PogledajStatusIsporuke();
                            break;

                        case "4":
                            PregledPoStatusu();
                            break;

                        case "5":
                            PretraziIsporuke();
                            break;

                        case "6":
                            FullTextPretragaNapomena();
                            break;

                        case "7":
                            NearPretragaNapomena();
                            break;

                        case "8":
                            PrikaziStatuseIsporuka();
                            break;

                        case "9":
                            PogledajIstorijuStatusa();
                            break;

                        case "0":
                            Console.WriteLine("Излаз из апликације...");
                            return;

                        default:
                            Console.WriteLine("Непозната опција.");
                            break;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine("ГРЕШКА: " + ex.Message);
                }

                Console.WriteLine();
                Console.WriteLine("Притисни ENTER за наставак...");
                Console.ReadLine();
                Console.Clear();
            }
        }

        private static void PrikaziMeni()
        {
            Console.WriteLine("=== ApplicationKLIJENT ===");
            Console.WriteLine("1. Прикажи све испоруке");
            Console.WriteLine("2. Погледај испоруку по ID");
            Console.WriteLine("3. Погледај статус испоруке");
            Console.WriteLine("4. Прикажи испоруке по статусу");
            Console.WriteLine("5. Претрага испорука");
            Console.WriteLine("6. Full-Text претрага по напомени");
            Console.WriteLine("7. NEAR претрага по напомени");
            Console.WriteLine("8. Прикажи број испорука по статусу");
            Console.WriteLine("9. Погледај историју статуса испоруке");
            Console.WriteLine("0. Излаз");
            Console.Write("Избор: ");
        }

        private static void PrikaziSveIsporuke()
        {
            List<IsporukaKlijent> isporuke = _service.VratiSveIsporuke();

            if (isporuke.Count == 0)
            {
                Console.WriteLine("Нема испорука за приказ.");
                return;
            }

            foreach (IsporukaKlijent isporuka in isporuke)
            {
                IspisiIsporuku(isporuka);
            }
        }

        private static void PogledajIsporuku()
        {
            int idIsporuke = ProcitajCeoBroj("ID испоруке: ");

            IsporukaKlijent isporuka = _service.PogledajIsporuku(idIsporuke);

            if (isporuka == null)
            {
                Console.WriteLine("Испорука није пронађена.");
                return;
            }

            IspisiIsporuku(isporuka);
        }

        private static void PogledajStatusIsporuke()
        {
            int idIsporuke = ProcitajCeoBroj("ID испоруке: ");

            IsporukaStatus status = _service.PogledajStatusIsporuke(idIsporuke);

            if (status == null)
            {
                Console.WriteLine("Статус није пронађен.");
                return;
            }

            Console.WriteLine("------------------------------------------------");
            Console.WriteLine($"ID испоруке: {status.IdIsporuke}");
            Console.WriteLine($"Статус: {status.StatusIs}");
            Console.WriteLine($"Датум/време: {status.DatVreme:yyyy-MM-dd HH:mm:ss}");
            Console.WriteLine("------------------------------------------------");
        }

        private static void PregledPoStatusu()
        {
            string statusIs = ProcitajTekst(
                "Статус (Примљена / УТранспорту / Испоручена / Враћена): "
            );

            List<IsporukaKlijent> isporuke = _service.PregledIsporukaPoStatusu(statusIs);

            if (isporuke.Count == 0)
            {
                Console.WriteLine("Нема испорука са изабраним статусом.");
                return;
            }

            foreach (IsporukaKlijent isporuka in isporuke)
            {
                IspisiIsporuku(isporuka);
            }
        }

        private static void PretraziIsporuke()
        {
            string tekst = ProcitajTekst("Текст за претрагу: ");

            List<IsporukaKlijent> isporuke = _service.PretraziIsporuke(tekst);

            if (isporuke.Count == 0)
            {
                Console.WriteLine("Нема резултата.");
                return;
            }

            foreach (IsporukaKlijent isporuka in isporuke)
            {
                IspisiIsporuku(isporuka);
            }
        }

        /*
            Pokreće Full-Text pretragu po napomeni isporuke.
            U bazi se koristi CONTAINS nad full-text indeksom.
        */
        private static void FullTextPretragaNapomena()
        {
            string tekst = ProcitajTekst("Текст за Full-Text претрагу напомене: ");

            List<IsporukaKlijent> isporuke = _service.PretraziIsporukeNapomena(tekst);

            if (isporuke.Count == 0)
            {
                Console.WriteLine("Нема резултата.");
                return;
            }

            foreach (IsporukaKlijent isporuka in isporuke)
            {
                IspisiIsporuku(isporuka);
            }
        }

        /*
            Pokreće Full-Text NEAR pretragu po napomeni.
            Korisnik unosi dve reči i maksimalnu udaljenost između njih.
        */
        private static void NearPretragaNapomena()
        {
            string prvaRec = ProcitajTekst("Прва реч: ");
            string drugaRec = ProcitajTekst("Друга реч: ");
            int udaljenost = ProcitajCeoBroj("Удаљеност: ");

            List<IsporukaKlijent> isporuke =
                _service.PretraziIsporukeNapomenaNear(prvaRec, drugaRec, udaljenost);

            if (isporuke.Count == 0)
            {
                Console.WriteLine("Нема резултата.");
                return;
            }

            foreach (IsporukaKlijent isporuka in isporuke)
            {
                IspisiIsporuku(isporuka);
            }
        }

        private static void PrikaziStatuseIsporuka()
        {
            List<StatusPregled> statusi = _service.VratiStatuseIsporuka();

            if (statusi.Count == 0)
            {
                Console.WriteLine("Нема података о статусима.");
                return;
            }

            Console.WriteLine("БРОЈ ИСПОРУКА ПО СТАТУСУ");
            Console.WriteLine("----------------------------------------");

            foreach (StatusPregled status in statusi)
            {
                Console.WriteLine($"{status.StatusIs}: {status.BrojIsporuka}");
            }

            Console.WriteLine("----------------------------------------");
        }

        private static void PogledajIstorijuStatusa()
        {
            int idIsporuke = ProcitajCeoBroj("ID испоруке: ");

            List<IstorijaStatusa> istorija = _service.PogledajIstorijuStatusa(idIsporuke);

            if (istorija.Count == 0)
            {
                Console.WriteLine("За ову испоруку нема записа историје статуса.");
                return;
            }

            Console.WriteLine();
            Console.WriteLine("ИСТОРИЈА СТАТУСА ИСПОРУКЕ");
            Console.WriteLine("--------------------------------------------------------------------------");
            Console.WriteLine("{0,-8} {1,-18} {2,-18} {3,-20}",
                "Ред.",
                "Стари статус",
                "Нови статус",
                "Датум промене");

            Console.WriteLine("--------------------------------------------------------------------------");

            foreach (IstorijaStatusa zapis in istorija)
            {
                Console.WriteLine("{0,-8} {1,-18} {2,-18} {3,-20}",
                    zapis.Redosled,
                    zapis.StariStatus ?? "NULL",
                    zapis.NoviStatus,
                    zapis.DatVremePromene.ToString("yyyy-MM-dd HH:mm:ss"));
            }

            Console.WriteLine("--------------------------------------------------------------------------");
        }

        private static void IspisiIsporuku(IsporukaKlijent isporuka)
        {
            Console.WriteLine("------------------------------------------------");
            Console.WriteLine($"ID: {isporuka.IdIsporuke}");
            Console.WriteLine($"Производ: {isporuka.NazivProizvoda}");
            Console.WriteLine($"Адреса: {isporuka.Adresa}");
            Console.WriteLine($"Статус: {isporuka.StatusIs}");
            Console.WriteLine($"Датум/време: {isporuka.DatVreme:yyyy-MM-dd HH:mm:ss}");
            Console.WriteLine($"Напомена: {(string.IsNullOrWhiteSpace(isporuka.Napomena) ? "-" : isporuka.Napomena)}");
        }

        /*
            Čita tekstualni unos iz konzole i uklanja nevidljive kontrolne karaktere.
            Ovo je važno zbog problema sa unosom ćirilice u Windows konzoli.
        */
        private static string ProcitajTekst(string poruka, bool dozvoliPrazno = false)
        {
            Console.Write(poruka);

            string unos = Console.ReadLine();

            if (unos == null)
            {
                if (dozvoliPrazno)
                {
                    return null;
                }

                throw new ArgumentException("Унос не сме бити празан.");
            }

            unos = unos.Replace("\0", "");

            StringBuilder builder = new StringBuilder();

            foreach (char c in unos)
            {
                if (!char.IsControl(c))
                {
                    builder.Append(c);
                }
            }

            unos = builder.ToString().Trim();

            if (!dozvoliPrazno && string.IsNullOrWhiteSpace(unos))
            {
                throw new ArgumentException("Унос не сме бити празан.");
            }

            if (dozvoliPrazno && string.IsNullOrWhiteSpace(unos))
            {
                return null;
            }

            return unos;
        }

        private static int ProcitajCeoBroj(string poruka)
        {
            string unos = ProcitajTekst(poruka);

            if (!int.TryParse(unos, out int broj))
            {
                throw new ArgumentException("Унета вредност мора бити цео број.");
            }

            return broj;
        }
    }
}