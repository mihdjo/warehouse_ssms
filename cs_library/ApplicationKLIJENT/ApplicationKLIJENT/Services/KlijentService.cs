using ApplicationKLIJENT.DataAccess;
using ApplicationKLIJENT.Domain;
using System.Collections.Generic;

namespace ApplicationKLIJENT.Services
{
    /*
        Service sloj klijentske aplikacije.

        Ova klasa predstavlja posrednički sloj između korisničkog interfejsa
        u Program.cs i repository sloja koji pristupa bazi podataka.

        Klijentska aplikacija koristi samo api_klijent šemu, pa korisnik vidi
        ograničen skup podataka namenjen klijentskom prikazu.
    */
    public class KlijentService
    {
        private readonly KlijentRepository _repository;

        public KlijentService(KlijentRepository repository)
        {
            _repository = repository;
        }

        public List<IsporukaKlijent> VratiSveIsporuke()
        {
            return _repository.VratiSveIsporuke();
        }

        public List<StatusPregled> VratiStatuseIsporuka()
        {
            return _repository.VratiStatuseIsporuka();
        }

        public IsporukaKlijent PogledajIsporuku(int idIsporuke)
        {
            return _repository.PogledajIsporuku(idIsporuke);
        }

        public IsporukaStatus PogledajStatusIsporuke(int idIsporuke)
        {
            return _repository.PogledajStatusIsporuke(idIsporuke);
        }

        public List<IsporukaKlijent> PregledIsporukaPoStatusu(string statusIs)
        {
            return _repository.PregledIsporukaPoStatusu(statusIs);
        }

        public List<IsporukaKlijent> PretraziIsporuke(string tekst)
        {
            return _repository.PretraziIsporuke(tekst);
        }

        public List<IsporukaKlijent> PretraziIsporukeNapomena(string tekst)
        {
            return _repository.PretraziIsporukeNapomena(tekst);
        }

        public List<IsporukaKlijent> PretraziIsporukeNapomenaNear(
            string prvaRec,
            string drugaRec,
            int udaljenost)
        {
            return _repository.PretraziIsporukeNapomenaNear(prvaRec, drugaRec, udaljenost);
        }

        public List<IstorijaStatusa> PogledajIstorijuStatusa(int idIsporuke)
        {
            return _repository.PogledajIstorijuStatusa(idIsporuke);
        }
    }
}