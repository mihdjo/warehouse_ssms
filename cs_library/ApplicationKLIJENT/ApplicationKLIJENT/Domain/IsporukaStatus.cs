using System;

namespace ApplicationKLIJENT.Domain
{
    /*
        Model za prikaz statusa jedne isporuke.

        Koristi se kada klijent želi da proveri samo trenutni status
        i datum/vreme evidentiranja isporuke.
    */
    public class IsporukaStatus
    {
        public int IdIsporuke { get; set; }
        public string StatusIs { get; set; }
        public DateTime DatVreme { get; set; }
    }
}