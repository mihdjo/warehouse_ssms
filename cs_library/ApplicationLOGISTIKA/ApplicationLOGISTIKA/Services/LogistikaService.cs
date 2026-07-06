using ApplicationLOGISTIKA.DataAccess;
using ApplicationLOGISTIKA.Domain;
using System;
using System.Collections.Generic;

namespace ApplicationLOGISTIKA.Services
{
    /*
        Service sloj logističke aplikacije.

        Ova klasa predstavlja posrednički sloj između korisničkog interfejsa
        u Program.cs i repository sloja koji komunicira sa bazom podataka.

        U ovom projektu service sloj uglavnom prosleđuje zahteve ka repository-ju,
        dok se glavna validacija i poslovna pravila nalaze u SQL procedurama
        i trigger-ima u bazi.
    */
    public class LogistikaService
    {
        private readonly LogistikaRepository _repository;

        public LogistikaService(LogistikaRepository repository)
        {
            _repository = repository;
        }

        public List<Proizvod> VratiProizvode()
        {
            return _repository.VratiProizvode();
        }

        public List<Posiljalac> VratiPosiljaoce()
        {
            return _repository.VratiPosiljaoce();
        }

        public List<IsporukaDetaljno> VratiIsporuke()
        {
            return _repository.VratiIsporuke();
        }

        public int DodajProizvod(string naziv, string opis, decimal tezina)
        {
            return _repository.DodajProizvod(naziv, opis, tezina);
        }

        public int DodajPosiljaoca(string nazivKompanije, string email, string telefon)
        {
            return _repository.DodajPosiljaoca(nazivKompanije, email, telefon);
        }

        public int KreirajIsporuku(
            string adresa,
            string napomena,
            DateTime datVreme,
            int idProizvoda,
            int idPosiljaoca)
        {
            return _repository.KreirajIsporuku(
                adresa,
                napomena,
                datVreme,
                idProizvoda,
                idPosiljaoca
            );
        }

        public void PromeniStatusIsporuke(int idIsporuke, string noviStatus)
        {
            _repository.PromeniStatusIsporuke(idIsporuke, noviStatus);
        }

        public List<Proizvod> PretraziProizvodePoOpisu(string tekst)
        {
            return _repository.PretraziProizvodePoOpisu(tekst);
        }

        public List<IsporukaKasnjenje> DijagnostikujKasnjenja(int pragSati)
        {
            return _repository.DijagnostikujKasnjenja(pragSati);
        }
    }
}