--translate by stepan_valic
local Translations = {
    error = {
        no_vehicles = "V tomto místě nejsou žádná vozidla!",
        not_impound = "Vaše vozidlo není v úschovně",
        not_owned = "Toto vozidlo nelze uložit",
        not_correct_type = "Tento typ vozidla nelze zde uložit",
        not_enough = "Nedostatek peněz",
        no_garage = "Žádný",
        vehicle_occupied = "Toto vozidlo nelze uložit, protože není prázdné",
    },
    success = {
        vehicle_parked = "Vozidlo uloženo",
    },
    menu = {
        header = {
            house_car = "Dům Garáž %{value}",
            public_car = "Veřejná Garáž %{value}",
            public_sea = "Veřejné Přístaviště %{value}",
            public_air = "Veřejný Hangár %{value}",
            job_car = "Pracovní Garáž %{value}",
            job_sea = "Pracovní Přístaviště %{value}",
            job_air = "Pracovní Hangár %{value}",
            gang_car = "Gang Garáž %{value}",
            gang_sea = "Gang Přístaviště %{value}",
            gang_air = "Gang Hangár %{value}",
            depot_car = "Depo %{value}",
            depot_sea = "Depo %{value}",
            depot_air = "Depo %{value}",
            vehicles = "Dostupná vozidla",
            depot = "%{value} [ $%{value2} ]",
            garage = "%{value} [ %{value2} ]",
        },
        leave = {
            car = "⬅ Odejít z Garáže",
            sea = "⬅ Odejít z Přístaviště",
            air = "⬅ Odejít z Hangáru",
        },
        text = {
            vehicles = "Zobrazit uložená vozidla!",
            depot = "SPZ: %{value}<br>Palivo: %{value2} | Motor: %{value3} | Karoserie: %{value4}",
            garage = "Stav: %{value}<br>Palivo: %{value2} | Motor: %{value3} | Karoserie: %{value4}",
        }
    },
    status = {
        out = "Venku",
        garaged = "V Garáži",
        impound = "Zabaveno policií",
    },
    info = {
        car_e = "E - Garáž",
        sea_e = "E - Přístaviště",
        air_e = "E - Hangár",
        park_e = "E - Uložit Vozidlo",
        house_garage = "Dům garáž",
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})