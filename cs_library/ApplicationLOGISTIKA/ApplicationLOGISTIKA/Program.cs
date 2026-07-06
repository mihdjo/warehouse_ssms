using System;
using System.Globalization;
using System.Text;
using ApplicationLOGISTIKA.DataAccess;
using ApplicationLOGISTIKA.Domain;
using ApplicationLOGISTIKA.Services;

namespace ApplicationLOGISTIKA
{

    /*
    Konzolni korisnički interfejs za logističku aplikaciju.

    Korisnik kroz meni može da pregleda proizvode, pošiljaoce i isporuke,
    dodaje nove podatke, menja status isporuke, koristi Full-Text pretragu
    i pokreće CLR dijagnostiku kašnjenja.

    Aplikacija ne pristupa direktno tabelama u bazi, već sve operacije
    izvršava preko service i repository sloja, koji koriste api_logistika šemu.
    */

    internal class Program
    {
        private static LogistikaService _service;

        static void Main(string[] args)
        {
            /*
            UTF-8 se koristi za prikaz teksta u konzoli.

            Windows-1251 se koristi za unos ćirilice, jer klasična Windows konzola
            u nekim slučajevima sa UTF-8 unosom ubacuje NUL karaktere u tekst.
            */

            Console.OutputEncoding = Encoding.UTF8;
            Console.InputEncoding = Encoding.GetEncoding(1251);
            Console.OutputEncoding = Encoding.UTF8;
            Console.InputEncoding = Encoding.GetEncoding(1251);

            DbConnectionFactory factory = new DbConnectionFactory();
            LogistikaRepository repository = new LogistikaRepository(factory);
            _service = new LogistikaService(repository);

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
                            PrikaziProizvode();
                            break;

                        case "2":
                            PrikaziPosiljaoce();
                            break;

                        case "3":
                            PrikaziIsporuke();
                            break;

                        case "4":
                            DodajProizvod();
                            break;

                        case "5":
                            DodajPosiljaoca();
                            break;

                        case "6":
                            KreirajIsporuku();
                            break;

                        case "7":
                            PromeniStatus();
                            break;

                        case "8":
                            PretraziProizvodeOpis();
                            break;

                        case "9":
                            DijagnostikujKasnjenja();
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
            Console.WriteLine("=== ApplicationLOGISTIKA ===");
            Console.WriteLine("1. Прикажи производе");
            Console.WriteLine("2. Прикажи пошиљаоце");
            Console.WriteLine("3. Прикажи испоруке");
            Console.WriteLine("4. Додај производ");
            Console.WriteLine("5. Додај пошиљаоца");
            Console.WriteLine("6. Креирај испоруку");
            Console.WriteLine("7. Промени статус испоруке");
            Console.WriteLine("8. Full-Text претрага производа по опису");
            Console.WriteLine("9. Дијагностикуј кашњења");
            Console.WriteLine("0. Излаз");
            Console.Write("Избор: ");
        }

        private static void PrikaziProizvode()
        {
            var proizvodi = _service.VratiProizvode();

            if (proizvodi.Count == 0)
            {
                Console.WriteLine("Нема производа за приказ.");
                return;
            }

            Console.WriteLine("ПРОИЗВОДИ");
            Console.WriteLine("------------------------------------------------------------");

            foreach (var p in proizvodi)
            {
                Console.WriteLine($"{p.IdProizvoda}. {p.Naziv} | {p.Opis} | {p.Tezina} kg");
            }

            Console.WriteLine("------------------------------------------------------------");
        }

        private static void PrikaziPosiljaoce()
        {
            var posiljaoci = _service.VratiPosiljaoce();

            if (posiljaoci.Count == 0)
            {
                Console.WriteLine("Нема пошиљалаца за приказ.");
                return;
            }

            Console.WriteLine("ПОШИЉАОЦИ");
            Console.WriteLine("------------------------------------------------------------");

            foreach (var p in posiljaoci)
            {
                Console.WriteLine($"{p.IdPosiljaoca}. {p.NazivKompanije} | {p.Email} | {p.Telefon}");
            }

            Console.WriteLine("------------------------------------------------------------");
        }

        private static void PrikaziIsporuke()
        {
            var isporuke = _service.VratiIsporuke();

            if (isporuke.Count == 0)
            {
                Console.WriteLine("Нема испорука за приказ.");
                return;
            }

            Console.WriteLine("ИСПОРУКЕ");
            Console.WriteLine("------------------------------------------------------------");

            foreach (var i in isporuke)
            {
                Console.WriteLine($"{i.IdIsporuke}. {i.NazivProizvoda} | {i.NazivKompanije} | {i.Adresa} | {i.StatusIs} | {i.DatVreme:yyyy-MM-dd HH:mm:ss}");
            }

            Console.WriteLine("------------------------------------------------------------");
        }

        private static void DodajProizvod()
        {
            string naziv = ProcitajTekst("Назив: ");
            string opis = ProcitajTekst("Опис: ");
            decimal tezina = ProcitajDecimal("Тежина: ");

            int id = _service.DodajProizvod(naziv, opis, tezina);

            Console.WriteLine("Додат производ са ID = " + id);
        }

        private static void DodajPosiljaoca()
        {
            string nazivKompanije = ProcitajTekst("Назив компаније: ");
            string email = ProcitajTekst("Email: ");
            string telefon = ProcitajTekst("Телефон: ", dozvoliPrazno: true);

            int id = _service.DodajPosiljaoca(nazivKompanije, email, telefon);

            Console.WriteLine("Додат пошиљалац са ID = " + id);
        }

        private static void KreirajIsporuku()
        {
            string adresa = ProcitajTekst("Адреса: ");
            string napomena = ProcitajTekst("Напомена: ", dozvoliPrazno: true);

            DateTime datVreme = ProcitajDatumVreme("Датум/време (пример 2025-06-01 10:00:00): ");

            int idProizvoda = ProcitajCeoBroj("ID производа: ");
            int idPosiljaoca = ProcitajCeoBroj("ID пошиљаоца: ");

            int id = _service.KreirajIsporuku(
                adresa,
                napomena,
                datVreme,
                idProizvoda,
                idPosiljaoca
            );

            Console.WriteLine("Креирана испорука са ID = " + id);
        }

        private static void PromeniStatus()
        {
            int idIsporuke = ProcitajCeoBroj("ID испоруке: ");

            string noviStatus = ProcitajTekst(
                "Нови статус (Примљена / УТранспорту / Испоручена / Враћена): "
            );

            _service.PromeniStatusIsporuke(idIsporuke, noviStatus);

            Console.WriteLine("Статус је успешно промењен.");
        }

        /*
        Pokreće Full-Text pretragu proizvoda po opisu.
        U bazi se koristi CONTAINS nad full-text indeksom.
        */

        private static void PretraziProizvodeOpis()
        {
            string tekst = ProcitajTekst("Текст за претрагу: ");

            var rezultati = _service.PretraziProizvodePoOpisu(tekst);

            if (rezultati.Count == 0)
            {
                Console.WriteLine("Нема резултата.");
                return;
            }

            Console.WriteLine("РЕЗУЛТАТИ ПРЕТРАГЕ");
            Console.WriteLine("------------------------------------------------------------");

            foreach (var p in rezultati)
            {
                Console.WriteLine($"{p.IdProizvoda}. {p.Naziv} | {p.Opis} | {p.Tezina} kg");
            }

            Console.WriteLine("------------------------------------------------------------");
        }

        /*
         
        Čita tekstualni unos iz konzole i uklanja nevidljive kontrolne karaktere.
        Ovo je važno zbog problema sa unosom ćirilice u Windows konzoli.

        */
     
        private static void DijagnostikujKasnjenja()
        {
            int pragSati = ProcitajCeoBroj("Праг у сатима: ");

            var kasnjenja = _service.DijagnostikujKasnjenja(pragSati);

            if (kasnjenja.Count == 0)
            {
                Console.WriteLine("Нема испорука које касне преко задатог прага.");
                return;
            }

            Console.WriteLine("ИСПОРУКЕ КОЈЕ КАСНЕ");
            Console.WriteLine("------------------------------------------------------------");

            foreach (var k in kasnjenja)
            {
                Console.WriteLine($"{k.IdIsporuke}. {k.NazivProizvoda} | {k.NazivKompanije} | {k.StatusIs} | {k.SatiOdKreiranja} сати");
            }

            Console.WriteLine("------------------------------------------------------------");
            Console.WriteLine("Провери Windows Event Viewer → Application → Source: IsporukaDB_CLR");
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

            /*
                Uklanja Unicode NUL karaktere.
                Oni su bili uzrok toga da SQL Server čuva tekst,
                ali SSMS prikazuje prazno polje.
            */
            unos = unos.Replace("\0", "");

            /*
                Uklanjamo i ostale kontrolne karaktere koji nisu vidljivi.
            */
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
            string input = ProcitajTekst(poruka);

            if (!int.TryParse(input, out int broj))
            {
                throw new ArgumentException("Унета вредност мора бити цео број.");
            }

            return broj;
        }

        private static decimal ProcitajDecimal(string poruka)
        {
            string input = ProcitajTekst(poruka);

            input = input.Replace(',', '.');

            if (!decimal.TryParse(
                input,
                NumberStyles.Number,
                CultureInfo.InvariantCulture,
                out decimal broj))
            {
                throw new ArgumentException("Унета вредност мора бити децималан број.");
            }

            return broj;
        }

        private static DateTime ProcitajDatumVreme(string poruka)
        {
            string input = ProcitajTekst(poruka);

            string[] formati =
            {
                "yyyy-MM-dd HH:mm:ss",
                "yyyy-MM-ddTHH:mm:ss",
                "yyyy-MM-dd HH:mm",
                "yyyy-MM-dd"
            };

            if (DateTime.TryParseExact(
                input,
                formati,
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out DateTime datum))
            {
                return datum;
            }

            if (DateTime.TryParse(input, out datum))
            {
                return datum;
            }

            throw new ArgumentException("Датум/време није у исправном формату.");
        }
    }
}