namespace ApplicationLOGISTIKA.Domain
{
    /*
    Model klase Proizvod.

    Predstavlja jedan proizvod iz baze podataka sa osnovnim podacima:
    naziv, opis i težina.
    */

    public class Proizvod
    {
        public int IdProizvoda { get; set; }
        public string Naziv { get; set; }
        public string Opis { get; set; }
        public decimal Tezina { get; set; }
    }
}