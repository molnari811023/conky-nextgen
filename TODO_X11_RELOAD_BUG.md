# Conky X11 SIGUSR1 / inotify Reload — own_window_type & hints Bug

## 📌 Probléma leírása
Amikor a Conky futás közben (SIGUSR1 szignál vagy inotify konfiguráció-módosítás hatására) újratöltődik, az `own_window_type` (pl. `dock` ➔ `normal` ➔ `override` ➔ `panel` ➔ `desktop`) vagy az `own_window_hints` módosítása **hatástalan marad**:
- A MATE Marco ablakkezelő felé az ablak mindvégig a legelső indításkori típus marad (pl. `_NET_WM_WINDOW_TYPE_DOCK`).
- A `normal` típusra váltáskor nem jelenik meg az ablakkeret / fejléc.
- Az `override` típusra váltáskor nem áll át az `override_redirect` flag az X11 szerveren.
- Az ablak végig megtartja a kezdeti 32 bites ARGB vizuált és átlátszóságot.

---

## 🔍 Technikai gyökérok (Root Cause)

### 1. `src/output/display-x11.cc`
A PR #2469 (`6caddca32d7b40f93db84b1fd48b8f018177dd0d`) során bevezetett ellenőrzés csak az `own_window` ki/be kapcsolását vizsgálja:
```cpp
#ifdef OWN_WINDOW
  if (window.window == None || window.owned != own_window.get(*state)) {
    // Csak akkor hívja meg a destroy_window()-t, ha own_window true <-> false váltás történt!
    destroy_window();
    fixed_size = fixed_pos = 0;
  }
#endif
```
Ha az `own_window` mindkét konfigurációban `true`, a `destroy_window()` **nem fut le**, az ablak megmarad.

### 2. `src/output/x11.cc`
A `x11_init_window()` függvényben az ablak újrahasznosításakor:
```cpp
if (window.owned) {
  // Csak méretet és alfa értéket olvas ki:
  XGetWindowAttributes(display, window.window, &attr);
  LOG_INFO("reusing existing window {:#x} {}x{} (reload)", window.window, attr.width, attr.height);
} else {
  // ITT VAN AZ EGÉSZ ABLAKINITIALIZÁLÁS:
  // - _NET_WM_WINDOW_TYPE atomok (dock, normal, panel, desktop)
  // - _MOTIF_WM_HINTS (keret / dekoráció)
  // - _NET_WM_STATE (below, sticky, skip_taskbar)
  // - override_redirect flag beállítása
}
```
Az `else` ág teljesen kimarad, és a `window.owned` ágban nincs sem `XChangeProperty`, sem egyéb módosítás.

### 3. `src/output/x11.h`
A `conky_x11_window` struktúra nem tárolja a korábbi `window_type` és `window_hints` értékeket, így a Conky jelenleg észre sem veszi a típusváltást.

---

## 🛠️ Javasolt javítás (Patch terv)

1. A `conky_x11_window` struktúrában el kell tárolni az érvényes `window_type` és `window_hints` értékeket.
2. A `display_output_x11::initialize()` függvényben bővíteni kell a feltételt:
   ```cpp
   if (window.window == None ||
       window.owned != own_window.get(*state) ||
       window.type != own_window_type.get(*state) ||
       window.hints != own_window_hints.get(*state)) {
     destroy_window();
     fixed_size = fixed_pos = 0;
   }
   ```
3. Ha a típus vagy a hintek megváltoznak, tiszta új ablakot kell létrehozni (`destroy_window()`), mert különösen az `override_redirect` és a visual módosítások nem végezhetők el megbízhatóan egy már leképezett (mapped) X11 ablakon.
