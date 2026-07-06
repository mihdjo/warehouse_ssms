using System;

namespace ApplicationKLIJENT.Domain
{
    /*
        Model isporuke za klijentski prikaz.

        Sadrži samo podatke koje klijent sme da vidi:
        proizvod, adresu, status, datum/vreme i napomenu.
        Ne sadrži interne logističke podatke niti kontakt podatke pošiljaoca.
    */
    public class IsporukaKlijent
    {
        public int IdIsporuke { get; set; }
        public string NazivProizvoda { get; set; }
        public string Adresa { get; set; }
        public string StatusIs { get; set; }
        public DateTime DatVreme { get; set; }
        public string Napomena { get; set; }
    }
}