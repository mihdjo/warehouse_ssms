namespace ApplicationLOGISTIKA.Domain
{
    /*
    Model klase Posiljalac.

    Predstavlja kompaniju koja šalje pošiljku.
    Logistička aplikacija ima pristup i kontakt podacima pošiljaoca.
    */

    public class Posiljalac
    {
        public int IdPosiljaoca { get; set; }
        public string NazivKompanije { get; set; }
        public string Email { get; set; }
        public string Telefon { get; set; }
    }
}