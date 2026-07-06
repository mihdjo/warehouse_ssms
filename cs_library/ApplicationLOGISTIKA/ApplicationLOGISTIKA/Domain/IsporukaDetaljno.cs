using System;

namespace ApplicationLOGISTIKA.Domain
{
    /*
    Model detaljnog prikaza isporuke.

    Koristi se u logističkoj aplikaciji za prikaz kompletnih podataka
    o isporuci, proizvodu i pošiljaocu.
    */

    public class IsporukaDetaljno
    {
        public int IdIsporuke { get; set; }
        public string Adresa { get; set; }
        public string Napomena { get; set; }
        public string StatusIs { get; set; }
        public DateTime DatVreme { get; set; }

        public int IdProizvoda { get; set; }
        public string NazivProizvoda { get; set; }
        public string OpisProizvoda { get; set; }
        public decimal Tezina { get; set; }

        public int IdPosiljaoca { get; set; }
        public string NazivKompanije { get; set; }
        public string EmailPosiljaoca { get; set; }
        public string TelefonPosiljaoca { get; set; }
    }
}