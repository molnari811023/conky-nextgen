# conky-nextgen

Lua/Cairo alapu Conky widget keretrendszer vizualis designer szerkesztovel.

## Inditas

```bash
python3 sh/designer/main.py          # Designer megnyitasa
conky -c clock_cal.conf              # Widget inditas
```

Menteskor a designer automatikusan ujratolti a conky-t (inotify + SIGUSR1 patch).

## Widgetek

| Widget | Leiras |
|---|---|
| `clock_cal` | Ora + naptar |
| `weather` | Időjárás (Open-Meteo API) |
| `info` | Rendszerinformaciok |
| `mem_swap` | Memoria + swap |
| `nvidia` | NVIDIA GPU allapot |

Minden widget 3 fajlbol all: `.conf` (conky konfig), `.lua` (rajzolas + adatok), `.png` (elonezet).

## Szerkezet

```
conky-nextgen/
├── clock_cal.conf/lua/png     # Ora + naptar widget
├── weather.conf/lua/png       # Időjárás widget
├── info.conf/lua/png          # Rendszerinfo widget
├── mem_swap.conf/lua/png      # Memoria widget
├── nvidia.conf/lua/png        # NVIDIA widget
├── lua/
│   ├── core/                  # Keretrendszer mag
│   │   ├── colors.lua         # Breeze Dark szinpalotta
│   │   ├── draw_core.lua      # Fő ciklus, auto-ertelmezes
│   │   ├── mouse.lua          # Egeresemeny kezeles
│   │   ├── translate.lua      # Nyelvi fajlok (.mo)
│   │   └── utils.lua          # Segitofuggvenyek
│   ├── draw/                  # Cairo rajzolo modulok
│   │   ├── background.lua     # Lekerekitett teglalapok
│   │   ├── bar.lua            # Progressz savok
│   │   ├── calendar.lua       # Naptar grid
│   │   ├── clock.lua          # Analog ora
│   │   ├── graph.lua          # Idősoros grafikonok
│   │   ├── image.lua          # PNG megjelenites
│   │   ├── lines.lua          # Vonaltipusok
│   │   ├── rings.lua          # Gyuru mutatok
│   │   ├── svg.lua            # SVG (librsvg)
│   │   └── text.lua           # Szoveg igazitas
│   ├── hardware/              # Hardver informacio modulok
│   │   ├── battery.lua        # Akksi, headset, eger
│   │   ├── core.lua           # DMI, cache, shell
│   │   ├── info.lua           # CPU, NVMe, telepites
│   │   ├── network.lua        # WiFi, publikus IP
│   │   ├── processes.lua      # Top/top_mem
│   │   ├── sensors.lua        # Homerseklet, ventilator
│   │   └── usb.lua            # USB csatlakozas
│   ├── weather/               # Időjárás adat modulok
│   │   ├── air.lua            # Levegominoseg
│   │   ├── alerts.lua         # MeteoAlarm XML
│   │   ├── core.lua           # Adatbetoltes, WMO kodok
│   │   ├── current.lua        # Aktualis időjárás
│   │   ├── daily.lua          # Napi elorejelzes
│   │   ├── hourly.lua         # Oras elorejelzes
│   │   ├── spaceweather.lua   # Naptevekenyseg, aurora
│   │   ├── sunmoon.lua        # Napkelte/nyugta, hold
│   │   └── units.lua          # Mertekegysegek
│   └── nowplaying.lua         # MPRIS lejatszo
├── sh/
│   ├── designer/              # Vizualis szerkeszto (Python/GTK)
│   ├── all_in_one.sh          # Adatlekerdez (egy hivas)
│   └── *.sh                   # Egyeni lekerdezok
├── icons/                     # Időjárás, szel, hold ikonok
├── language/                  # Nyelvek (22)
├── pkg/
│   ├── PKGBUILD               # Arch Linux csomag
│   └── sigusr1-reload.patch   # SIGUSR1 reload patch (X11)
├── debug/                     # Fuggvenytesztek
└── NextGen.md                 # Részletes dokumentacio
```

## SIGUSR1 Reload Patch

A `pkg/sigusr1-reload.patch` javitja a conky X11 viselkedeset SIGUSR1 reload kozben:

- Az ablak nem semmisul meg es nem hoz letre ujat — a meglevot hasznalja
- Az X11 kapcsolat nyitva marad
- A visual/geometry lekerdezese a tenyleges ablak attributumokbol tortenik
- Nincs villanas, nincs tartalom elvesztes

Wayland-on mar alapbol jol mukodik, a patch csak X11-et erinti.

## Konfiguralas

A `conky-startup.sh` inditja az osszes widgetet:

```bash
bash ~/.conky/conky-startup.sh
```

## Kovetelmenyek

- Conky 1.24.3+ (Lua 5.5, Cairo, Imlib2, RSVG)
- Lua konyvtarak: dkjson, lfs
- Rendszer: lm-sensors, playerctl, upower, lsblk
- Python 3.10+ (designerhez)
- GTK3 (designerhez)
