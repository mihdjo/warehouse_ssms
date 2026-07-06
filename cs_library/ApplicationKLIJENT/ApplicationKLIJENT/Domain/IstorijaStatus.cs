using System;

namespace ApplicationKLIJENT.Domain
{
    /*
        Model jednog zapisa iz istorije statusa isporuke.

        Prikazuje redosled promene statusa, prethodni status,
        novi status i vreme kada je promena evidentirana.
    */
    public class IstorijaStatusa
    {
        public int Redosled { get; set; }
        public int IdIsporuke { get; set; }
        public string StariStatus { get; set; }
        public string NoviStatus { get; set; }
        public DateTime DatVremePromene { get; set; }
    }
}