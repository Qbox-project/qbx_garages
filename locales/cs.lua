local Translations = {
    chyba = {
        no_vehicles = "V této lokalitě nejsou žádná vozidla!",
        not_impound = "Vaše vozidlo není odtaženo",
        not_owned = "Toto vozidlo nelze uložit",
        not_correct_type = "Tento typ vozidla zde nelze uložit",
        not_enough = "Nedostatek peněz",
        no_garage = "Žádný",
        vehicle_occupied = "Toto vozidlo nelze uložit, protože někdo sedí uvnitř",
    },
    success = {
        vehicle_parked = "Vozidlo uloženo",
    },
    menu = {
        header = {
            house_car = "Garáž domu %{value}",
            public_car = "Veřejná garáž %{value}",
            public_sea = "Veřejná loděnice %{value}",
            public_air = "Veřejný hangár %{value}",
            job_car = "Garáž zaměstnanců %{value}",
            job_sea = "Loděnice zaměstnanců %{value}",
            job_air = "Hangár zaměstnanců %{value}",
            gang_car = "Gangsterská garáž %{value}",
            gang_sea = "Gangsterská loděnice %{value}",
            gang_air = "Gangsterský hangár %{value}",
            depot_car = "Depo %{value}",
            depot_sea = "Depo %{value}",
            depot_air = "Depo %{value}",
            vehicles = "Dostupná vozidla",
            depot = "%{value} [ $%{value2} ]",
            garage = "%{value} [ %{value2} ]",
        },
        leave = {
            car = "⬅ Opustit garáž",
            sea = "⬅ Opustit loděnici",
            air = "⬅ Opustit hangár",
        },
        text = {
            vehicles = "Zobrazit uložená vozidla!",
            depot = "SPZ: %{value}<br>Palivo: %{value2} | Motor: %{value3} | Karoserie: %{value4}",
            garage = "Stav: %{value}<br>Palivo: %{value2} | Motor: %{value3} | Karoserie: %{value4}",
        }
    },
    status = {
        out = "Venku",
        garaged = "Zaparkováno",
        impound = "Zabaveno policií",
    },
    info = {
        car_e = "E - Garáž",
        sea_e = "E - Loděnice",
        air_e = "E - Hangár",
        park_e = "E - Uklidit vozidlo",
        house_garage = "Garáž domu",
    }
}

if GetConvar('qb_locale', 'en') == 'cs' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end