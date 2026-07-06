namespace ApplicationKLIJENT.Domain
{
    /*
        Model za zbirni prikaz broja isporuka po statusu.

        Koristi se za pregled koliko isporuka postoji u svakom statusu.
    */
    public class StatusPregled
    {
        public string StatusIs { get; set; }
        public int BrojIsporuka { get; set; }
    }
}