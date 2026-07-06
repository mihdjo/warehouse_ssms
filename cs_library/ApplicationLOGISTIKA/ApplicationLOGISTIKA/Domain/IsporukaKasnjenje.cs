using System;

namespace ApplicationLOGISTIKA.Domain
{
    /*
        Model isporuke koja kasni.

        Koristi se za prikaz rezultata CLR dijagnostike kašnjenja,
        odnosno isporuka koje su duže od zadatog praga u statusu
        Примљена ili УТранспорту.
    */

    public class IsporukaKasnjenje
    {
        public int IdIsporuke { get; set; }
        public string StatusIs { get; set; }
        public DateTime DatVreme { get; set; }
        public int SatiOdKreiranja { get; set; }
        public string NazivProizvoda { get; set; }
        public string NazivKompanije { get; set; }
    }
}