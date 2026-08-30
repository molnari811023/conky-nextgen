#!/usr/bin/env python3
"""merge_evolution.py — merge email/calendar labels from Evolution's
evolution.mo / evolution-data-server.mo into the conky .po files.

Extra Gmail/Google-specific labels are translated manually for every
language (no English fallback). NOT pushed to GitHub yet — the Google
dashboard must be finished first.

Usage: python3 merge_evolution.py
"""
import os
import subprocess
import re

LANG_DIR = "/usr/share/locale"
PO_DIR = os.path.expanduser("~/.conky/language")

# all 22 conky languages; en has no evolution.mo (it is the source)
MO_LANGS = ["ar","cs","da","de","es","fi","fr","hr","hu","it","ja","ko",
            "nl","pl","pt","ro","ru","sv","tr","uk","zh_CN"]
ALL_LANGS = MO_LANGS + ["en"]

# Curated msgids (must match Evolution's exact msgid strings).
# en = msgid itself (English is the source language).
LABELS = [
    # Mail — folders & views
    "Inbox","Sent","Drafts","Junk","Trash","Archive","Folders",
    # Mail — message
    "From","To","Subject","Date","Bcc","Cc","Priority","Message",
    "Attachment","Attachments","Attachment Properties",
    # Mail — actions & UI
    "Reply","Reply to All","Forward","Attach a file",
    "Compose Message","Save","Close","Account","Accounts","Folder",
    "Search","Labels","Show","Delete",
    # Calendar — views
    "Calendar","Event","Events","Meeting","Appointment","Today",
    "Day","Week","Month","Year","Tasks","Task",
    # Calendar — event properties
    "Start","End","All day:","Summary",
    "Description","Location","Details","Reminders","Busy","Free",
    "Private","Public","Recurring","Recurrence","Categories","Notes",
    # Calendar — actions
    "New","Delete Task","Export","Print…","Undo","Previous","Next",
    # Weekday / month names (for calendar headers)
    "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday",
    "January","February","March","April","May","June","July","August",
    "September","October","November","December",
    # Misc
    "Yes","No","Cancel","OK","Error","Warning","Open","Load",
    "Status","Offline","Done","Completed","Unread Messages",
]

# Evolution additions (email + calendar extras) — must exist in evolution.mo
# or be covered by MANUAL (gaps: ja, ar and any empty translations).
EVO_EXTRA = [
    "Important","Flagged","Category","Label","Select All","Loading",
    "Updated","Refresh","Preferences","Attendee","Attendees","Tentative",
    "Free/Busy","Timezone","UTC","Daily","Weekly","Holiday","Birthday",
    "Anniversary","Out of Office","Yesterday","Now","Task List","To Do",
    "Due date","Assigned","Overdue Tasks","Remove","Clear All","Size",
    "Username:","Accept meeting request","Decline meeting request",
    "Accepted","Declined","Forward message","Address","Email",
    # 21/21 evolution coverage (Tasks/Contacts/Drive extras)
    "Due","Due Date:","Complete","Completed","Completed Tasks",
    "Contact","Contacts","Name","Phone","Fax","Work","Home","Other",
    "Notes","Company","High","Low",
    # partial coverage — topped up manually in MANUAL/GAP
    "Website","Folder","Recent","Archive","Reminder",
]

# Gmail/Google-specific labels that are NOT present in the Evolution
# catalogs. Translated manually for every language (no English fallback).
GMAIL_LABELS = [
    "Starred","Star","Mute","Snooze","Snoozed",
    "Promotions","Updates","Social","Forums","Primary",
    "Sign in","Sign out","Settings",
    "No new mail","No messages","Last updated","Retry",
    "Connected","Disconnected","Sync",
    "No upcoming events","Nothing scheduled",
    "Mark all as read","Agenda","All Mail","Move to",
]

# Google-widget labels (Tasks, Drive, YouTube, Meet, Keep, Chat).
# These are NOT in the Evolution catalogs -> translated manually for every
# language in WIDGET_MANUAL (no English fallback).
WIDGET_LABELS = [
    # Tasks
    "Due today","Overdue","Incomplete","Add task","New task","Edit task",
    "Task details","Task list","To Do list","Subtasks","Medium",
    "Priority: High","Priority: Medium","Priority: Low","Mark complete",
    # Contacts
    "Full name","First name","Last name","Mobile","Job title","Email address",
    # Drive
    "Drive","Storage","Used","Quota","Upload","Download","Recent files",
    "Shared with me","My Drive","Folder size",
    # YouTube
    "Video","Videos","Channel","Channels","Subscription","Subscriptions",
    "Views","Uploads","Latest","Watch","Playlists","Comments",
    # Meet
    "Meeting code","Join","Join now","Ongoing","Ended","History",
    "Past calls","Leave","Participants",
    # Keep
    "Pin","Pinned","Checklist",
    # Chat
    "Space","Spaces","Direct message","Direct messages","Mentions",
    "Thread","Threads","Group chat","Reaction","React",
]

# Manual translations, msgid -> msgstr, per language.
# Used ONLY when the Evolution catalogs do not provide a (non-empty)
# translation for that msgid. en should stay empty (auto msgstr=msgid).
MANUAL = {

 "ar": {
  "Starred":"مميّز بنجمة","Star":"نجمة","Mute":"كتم الصوت","Snooze":"غفوة","Snoozed":"مؤجَّل",
  "Promotions":"عروض","Updates":"تحديثات","Social":"اجتماعي","Forums":"منتديات","Primary":"أساسي",
  "Sign in":"تسجيل الدخول","Sign out":"تسجيل الخروج","Settings":"الإعدادات",
  "No new mail":"لا رسائل جديدة","No messages":"لا رسائل","Last updated":"آخر تحديث","Retry":"إعادة المحاولة",
  "Connected":"متصل","Disconnected":"غير متصل","Sync":"مزامنة",
  "No upcoming events":"لا أحداث قادمة","Nothing scheduled":"لا شيء مجدول",
  "Mark all as read":"تحديد الكل كمقروء","Agenda":"جدول الأعمال","All Mail":"جميع الرسائل","Move to":"نقل إلى",
  "Updated":"تم التحديث","Refresh":"تحديث","Preferences":"التفضيلات",
  "Holiday":"عطلة","To Do":"مهام","Remove":"إزالة",
  "Accept meeting request":"قبول طلب الاجتماع","Decline meeting request":"رفض طلب الاجتماع",
 },
 "cs": {
  "Starred":"S hvězdičkou","Star":"Hvězdička","Mute":"Ztlumit","Snooze":"Odložit","Snoozed":"Odloženo",
  "Promotions":"Propagace","Updates":"Aktualizace","Social":"Sociální","Forums":"Fóra","Primary":"Hlavní",
  "Sign in":"Přihlásit se","Sign out":"Odhlásit se","Settings":"Nastavení",
  "No new mail":"Žádný nový e-mail","No messages":"Žádné zprávy","Last updated":"Poslední aktualizace","Retry":"Zkusit znovu",
  "Connected":"Připojeno","Disconnected":"Odpojeno","Sync":"Synchronizace",
  "No upcoming events":"Žádné nadcházející události","Nothing scheduled":"Nic naplánováno",
  "Mark all as read":"Označit vše jako přečtené","Agenda":"Agenda","All Mail":"Všechen e-mail","Move to":"Přesunout do",
  "Updated":"Aktualizováno","Refresh":"Obnovit","Preferences":"Předvolby",
  "Holiday":"Svátek","To Do":"Úkoly","Remove":"Odebrat",
  "Accept meeting request":"Přijmout žádost o schůzku","Decline meeting request":"Odmítnout žádost o schůzku",
 },
 "da": {
  "Starred":"Med stjerne","Star":"Stjerne","Mute":"Slå lyd fra","Snooze":"Udskyd","Snoozed":"Udskudt",
  "Promotions":"Kampagner","Updates":"Opdateringer","Social":"Socialt","Forums":"Fora","Primary":"Primær",
  "Sign in":"Log ind","Sign out":"Log ud","Settings":"Indstillinger",
  "No new mail":"Ingen ny post","No messages":"Ingen beskeder","Last updated":"Sidst opdateret","Retry":"Prøv igen",
  "Connected":"Forbundet","Disconnected":"Afbrudt","Sync":"Synkronisering",
  "No upcoming events":"Ingen kommende begivenheder","Nothing scheduled":"Intet planlagt",
  "Mark all as read":"Markér alle som læst","Agenda":"Dagsorden","All Mail":"Al post","Move to":"Flyt til",
  "Updated":"Opdateret","Refresh":"Opdater","Preferences":"Indstillinger",
  "Holiday":"Helligdag","To Do":"Opgaver","Remove":"Fjern",
  "Accept meeting request":"Accepter mødeinvitation","Decline meeting request":"Afvis mødeinvitation",
 },
 "de": {
  "Starred":"Markiert","Star":"Stern","Mute":"Stummschalten","Snooze":"Schlummern","Snoozed":"Geschlummert",
  "Promotions":"Werbung","Updates":"Updates","Social":"Soziales","Forums":"Foren","Primary":"Primär",
  "Sign in":"Anmelden","Sign out":"Abmelden","Settings":"Einstellungen",
  "No new mail":"Keine neuen E-Mails","No messages":"Keine Nachrichten","Last updated":"Zuletzt aktualisiert","Retry":"Erneut versuchen",
  "Connected":"Verbunden","Disconnected":"Getrennt","Sync":"Synchronisierung",
  "No upcoming events":"Keine anstehenden Termine","Nothing scheduled":"Nichts geplant",
  "Mark all as read":"Alle als gelesen markieren","Agenda":"Agenda","All Mail":"Alle E-Mails","Move to":"Verschieben nach",
  "Updated":"Aktualisiert","Refresh":"Aktualisieren","Preferences":"Einstellungen",
  "Holiday":"Feiertag","To Do":"Aufgaben","Remove":"Entfernen",
  "Accept meeting request":"Besprechungsanfrage annehmen","Decline meeting request":"Besprechungsanfrage ablehnen",
 },
 "es": {
  "Starred":"Destacado","Star":"Destacar","Mute":"Silenciar","Snooze":"Posponer","Snoozed":"Pospuesto",
  "Promotions":"Promociones","Updates":"Novedades","Social":"Social","Forums":"Foros","Primary":"Principal",
  "Sign in":"Iniciar sesión","Sign out":"Cerrar sesión","Settings":"Configuración",
  "No new mail":"No hay correo nuevo","No messages":"No hay mensajes","Last updated":"Última actualización","Retry":"Reintentar",
  "Connected":"Conectado","Disconnected":"Desconectado","Sync":"Sincronización",
  "No upcoming events":"No hay próximos eventos","Nothing scheduled":"Nada programado",
  "Mark all as read":"Marcar todo como leído","Agenda":"Agenda","All Mail":"Todo el correo","Move to":"Mover a",
  "Updated":"Actualizado","Refresh":"Actualizar","Preferences":"Preferencias",
  "Holiday":"Festivo","To Do":"Tareas","Remove":"Quitar",
  "Accept meeting request":"Aceptar solicitud de reunión","Decline meeting request":"Rechazar solicitud de reunión",
 },
 "fi": {
  "Starred":"Tähdellä merkitty","Star":"Tähti","Mute":"Mykistä","Snooze":"Torkku","Snoozed":"Torkutettu",
  "Promotions":"Tarjoukset","Updates":"Päivitykset","Social":"Sosiaaliset","Forums":"Foorumit","Primary":"Ensisijainen",
  "Sign in":"Kirjaudu sisään","Sign out":"Kirjaudu ulos","Settings":"Asetukset",
  "No new mail":"Ei uutta sähköpostia","No messages":"Ei viestejä","Last updated":"Päivitetty viimeksi","Retry":"Yritä uudelleen",
  "Connected":"Yhdistetty","Disconnected":"Ei yhteyttä","Sync":"Synkronointi",
  "No upcoming events":"Ei tulevia tapahtumia","Nothing scheduled":"Ei aikataulutettua",
  "Mark all as read":"Merkitse kaikki luetuiksi","Agenda":"Esityslista","All Mail":"Kaikki sähköposti","Move to":"Siirrä kohteeseen",
  "Updated":"Päivitetty","Refresh":"Päivitä","Preferences":"Asetukset",
  "Holiday":"Pyhäpäivä","To Do":"Tehtävät","Remove":"Poista",
  "Accept meeting request":"Hyväksy kokouspyyntö","Decline meeting request":"Hylkää kokouspyyntö",
 },
 "fr": {
  "Starred":"Suivi","Star":"Ajouter une étoile","Mute":"Réduire le bruit","Snooze":"Reporter","Snoozed":"Reporté",
  "Promotions":"Promotions","Updates":"Mises à jour","Social":"Réseaux sociaux","Forums":"Forums","Primary":"Principal",
  "Sign in":"Se connecter","Sign out":"Se déconnecter","Settings":"Paramètres",
  "No new mail":"Aucun nouveau message","No messages":"Aucun message","Last updated":"Dernière mise à jour","Retry":"Réessayer",
  "Connected":"Connecté","Disconnected":"Déconnecté","Sync":"Synchronisation",
  "No upcoming events":"Aucun événement à venir","Nothing scheduled":"Rien de prévu",
  "Mark all as read":"Tout marquer comme lu","Agenda":"Ordre du jour","All Mail":"Tous les messages","Move to":"Déplacer vers",
  "Updated":"Mis à jour","Refresh":"Actualiser","Preferences":"Préférences",
  "Holiday":"Jour férié","To Do":"Tâches","Remove":"Supprimer",
  "Accept meeting request":"Accepter la demande de réunion","Decline meeting request":"Refuser la demande de réunion",
 },
 "hr": {
  "Starred":"Označeno zvjezdicom","Star":"Zvjezdica","Mute":"Utišaj","Snooze":"Odgodi","Snoozed":"Odgođeno",
  "Promotions":"Promocije","Updates":"Novosti","Social":"Društvene mreže","Forums":"Forumi","Primary":"Glavno",
  "Sign in":"Prijava","Sign out":"Odjava","Settings":"Postavke",
  "No new mail":"Nema nove pošte","No messages":"Nema poruka","Last updated":"Zadnje ažuriranje","Retry":"Pokušaj ponovno",
  "Connected":"Spojeno","Disconnected":"Prekinuto","Sync":"Sinkronizacija",
  "No upcoming events":"Nema nadolazećih događaja","Nothing scheduled":"Ništa nije zakazano",
  "Mark all as read":"Označi sve kao pročitano","Agenda":"Dnevni red","All Mail":"Sva pošta","Move to":"Premjesti u",
  "Updated":"Ažurirano","Refresh":"Osvježi","Preferences":"Postavke",
  "Holiday":"Praznik","To Do":"Zadaci","Remove":"Ukloni",
  "Accept meeting request":"Prihvati zahtjev za sastanak","Decline meeting request":"Odbij zahtjev za sastanak",
 },
 "hu": {
  "Starred":"Megjelölt","Star":"Csillag","Mute":"Némítás","Snooze":"Szundi","Snoozed":"Elnapolt",
  "Promotions":"Promóciók","Updates":"Frissítések","Social":"Közösségi","Forums":"Fórumok","Primary":"Elsődleges",
  "Sign in":"Bejelentkezés","Sign out":"Kijelentkezés","Settings":"Beállítások",
  "No new mail":"Nincs új levél","No messages":"Nincs üzenet","Last updated":"Utolsó frissítés","Retry":"Újra",
  "Connected":"Kapcsolódva","Disconnected":"Nincs kapcsolat","Sync":"Szinkronizálás",
  "No upcoming events":"Nincs közelgő esemény","Nothing scheduled":"Nincs ütemezett esemény",
  "Mark all as read":"Összes olvasottként megjelölése","Agenda":"Napirend","All Mail":"Összes levél","Move to":"Áthelyezés ide",
  "Updated":"Frissítve","Refresh":"Frissítés","Preferences":"Beállítások",
  "Holiday":"Ünnep","To Do":"Teendők","Remove":"Eltávolítás",
  "Accept meeting request":"Értekezleti meghívó elfogadása","Decline meeting request":"Értekezleti meghívó elutasítása",
 },
 "it": {
  "Starred":"Con stella","Star":"Stella","Mute":"Disattiva audio","Snooze":"Posticipa","Snoozed":"Posticipato",
  "Promotions":"Promozioni","Updates":"Aggiornamenti","Social":"Social","Forums":"Forum","Primary":"Principale",
  "Sign in":"Accedi","Sign out":"Esci","Settings":"Impostazioni",
  "No new mail":"Nessun nuovo messaggio","No messages":"Nessun messaggio","Last updated":"Ultimo aggiornamento","Retry":"Riprova",
  "Connected":"Connesso","Disconnected":"Disconnesso","Sync":"Sincronizzazione",
  "No upcoming events":"Nessun evento imminente","Nothing scheduled":"Niente in programma",
  "Mark all as read":"Segna tutti come letti","Agenda":"Ordine del giorno","All Mail":"Tutti i messaggi","Move to":"Sposta in",
  "Updated":"Aggiornato","Refresh":"Aggiorna","Preferences":"Preferenze",
  "Holiday":"Festa","To Do":"Attività","Remove":"Rimuovi",
  "Accept meeting request":"Accetta richiesta di riunione","Decline meeting request":"Rifiuta richiesta di riunione",
 },
 "ja": {
  "Starred":"スター付き","Star":"スター","Mute":"ミュート","Snooze":"スヌーズ","Snoozed":"スヌーズ済み",
  "Promotions":"プロモーション","Updates":"アップデート","Social":"ソーシャル","Forums":"フォーラム","Primary":"優先",
  "Sign in":"ログイン","Sign out":"ログアウト","Settings":"設定",
  "No new mail":"新しいメールはありません","No messages":"メッセージはありません","Last updated":"最終更新","Retry":"再試行",
  "Connected":"接続済み","Disconnected":"未接続","Sync":"同期",
  "No upcoming events":"予定はありません","Nothing scheduled":"予定されていません",
  "Mark all as read":"すべて既読にする","Agenda":"アジェンダ","All Mail":"すべてのメール","Move to":"移動先",
  "Updated":"更新済み","Refresh":"更新","Preferences":"環境設定",
  "Holiday":"祝日","To Do":"To Do","Remove":"削除",
  "Accept meeting request":"会議のリクエストを承認","Decline meeting request":"会議のリクエストを辞退",
 },
 "ko": {
  "Starred":"별표","Star":"별","Mute":"음소거","Snooze":"스누즈","Snoozed":"스누즈됨",
  "Promotions":"프로모션","Updates":"업데이트","Social":"소셜","Forums":"포럼","Primary":"기본",
  "Sign in":"로그인","Sign out":"로그아웃","Settings":"설정",
  "No new mail":"새 메일 없음","No messages":"메시지 없음","Last updated":"마지막 업데이트","Retry":"다시 시도",
  "Connected":"연결됨","Disconnected":"연결 끊김","Sync":"동기화",
  "No upcoming events":"예정된 일정 없음","Nothing scheduled":"일정 없음",
  "Mark all as read":"모두 읽음으로 표시","Agenda":"안건","All Mail":"모든 메일","Move to":"이동",
  "Updated":"업데이트됨","Refresh":"새로고침","Preferences":"환경설정",
  "Holiday":"공휴일","To Do":"할 일","Remove":"제거",
  "Accept meeting request":"회의 요청 수락","Decline meeting request":"회의 요청 거절",
 },
 "nl": {
  "Starred":"Met ster","Star":"Ster","Mute":"Dempen","Snooze":"Snoozen","Snoozed":"Gesnoozed",
  "Promotions":"Promoties","Updates":"Updates","Social":"Sociaal","Forums":"Forums","Primary":"Primair",
  "Sign in":"Aanmelden","Sign out":"Afmelden","Settings":"Instellingen",
  "No new mail":"Geen nieuwe e-mail","No messages":"Geen berichten","Last updated":"Laatst bijgewerkt","Retry":"Opnieuw proberen",
  "Connected":"Verbonden","Disconnected":"Niet verbonden","Sync":"Synchronisatie",
  "No upcoming events":"Geen aankomende evenementen","Nothing scheduled":"Niets gepland",
  "Mark all as read":"Alles als gelezen markeren","Agenda":"Agenda","All Mail":"Alle e-mail","Move to":"Verplaatsen naar",
  "Updated":"Bijgewerkt","Refresh":"Vernieuwen","Preferences":"Voorkeuren",
  "Holiday":"Feestdag","To Do":"Taken","Remove":"Verwijderen",
  "Accept meeting request":"Vergaderverzoek accepteren","Decline meeting request":"Vergaderverzoek afwijzen",
 },
 "pl": {
  "Starred":"Z gwiazdką","Star":"Gwiazdka","Mute":"Wycisz","Snooze":"Odłóż","Snoozed":"Odłożone",
  "Promotions":"Promocje","Updates":"Aktualizacje","Social":"Społeczności","Forums":"Fora","Primary":"Podstawowe",
  "Sign in":"Zaloguj się","Sign out":"Wyloguj się","Settings":"Ustawienia",
  "No new mail":"Brak nowych wiadomości","No messages":"Brak wiadomości","Last updated":"Ostatnia aktualizacja","Retry":"Spróbuj ponownie",
  "Connected":"Połączono","Disconnected":"Rozłączono","Sync":"Synchronizacja",
  "No upcoming events":"Brak nadchodzących wydarzeń","Nothing scheduled":"Nic zaplanowanego",
  "Mark all as read":"Oznacz wszystkie jako przeczytane","Agenda":"Porządek obrad","All Mail":"Cała poczta","Move to":"Przenieś do",
  "Updated":"Zaktualizowano","Refresh":"Odśwież","Preferences":"Preferencje",
  "Holiday":"Święto","To Do":"Zadania","Remove":"Usuń",
  "Accept meeting request":"Zaakceptuj prośbę o spotkanie","Decline meeting request":"Odrzuć prośbę o spotkanie",
 },
 "pt": {
  "Starred":"Com estrela","Star":"Estrela","Mute":"Silenciar","Snooze":"Adiar","Snoozed":"Adiado",
  "Promotions":"Promoções","Updates":"Atualizações","Social":"Social","Forums":"Fóruns","Primary":"Principal",
  "Sign in":"Iniciar sessão","Sign out":"Terminar sessão","Settings":"Definições",
  "No new mail":"Sem novo e-mail","No messages":"Sem mensagens","Last updated":"Última atualização","Retry":"Tentar novamente",
  "Connected":"Ligado","Disconnected":"Desligado","Sync":"Sincronização",
  "No upcoming events":"Sem próximos eventos","Nothing scheduled":"Nada agendado",
  "Mark all as read":"Marcar tudo como lido","Agenda":"Agenda","All Mail":"Todo o e-mail","Move to":"Mover para",
  "Updated":"Atualizado","Refresh":"Atualizar","Preferences":"Preferências",
  "Holiday":"Feriado","To Do":"Tarefas","Remove":"Remover",
  "Accept meeting request":"Aceitar pedido de reunião","Decline meeting request":"Recusar pedido de reunião",
 },
 "ro": {
  "Starred":"Cu stea","Star":"Stea","Mute":"Dezactivează sunetul","Snooze":"Amână","Snoozed":"Amânat",
  "Promotions":"Promoții","Updates":"Noutăți","Social":"Social","Forums":"Forumuri","Primary":"Principal",
  "Sign in":"Autentifică-te","Sign out":"Deconectează-te","Settings":"Setări",
  "No new mail":"Niciun e-mail nou","No messages":"Niciun mesaj","Last updated":"Ultima actualizare","Retry":"Reîncearcă",
  "Connected":"Conectat","Disconnected":"Deconectat","Sync":"Sincronizare",
  "No upcoming events":"Niciun eveniment viitor","Nothing scheduled":"Nimic programat",
  "Mark all as read":"Marchează toate ca citite","Agenda":"Ordine de zi","All Mail":"Tot e-mailul","Move to":"Mută în",
  "Updated":"Actualizat","Refresh":"Reîncarcă","Preferences":"Preferințe",
  "Holiday":"Sărbătoare","To Do":"Sarcini","Remove":"Elimină",
  "Accept meeting request":"Acceptă cererea de întâlnire","Decline meeting request":"Refuză cererea de întâlnire",
 },
 "ru": {
  "Starred":"Помечено","Star":"Звезда","Mute":"Отключить звук","Snooze":"Отложить","Snoozed":"Отложено",
  "Promotions":"Акции","Updates":"Обновления","Social":"Социальные","Forums":"Форумы","Primary":"Основные",
  "Sign in":"Войти","Sign out":"Выйти","Settings":"Настройки",
  "No new mail":"Нет новых писем","No messages":"Нет сообщений","Last updated":"Последнее обновление","Retry":"Повторить",
  "Connected":"Подключено","Disconnected":"Отключено","Sync":"Синхронизация",
  "No upcoming events":"Нет предстоящих событий","Nothing scheduled":"Ничего не запланировано",
  "Mark all as read":"Отметить все как прочитанные","Agenda":"Повестка дня","All Mail":"Вся почта","Move to":"Переместить в",
  "Updated":"Обновлено","Refresh":"Обновить","Preferences":"Настройки",
  "Holiday":"Праздник","To Do":"Задачи","Remove":"Удалить",
  "Accept meeting request":"Принять запрос о встрече","Decline meeting request":"Отклонить запрос о встрече",
 },
 "sv": {
  "Starred":"Med stjärna","Star":"Stjärna","Mute":"Tysta","Snooze":"Vila","Snoozed":"Pausad",
  "Promotions":"Kampanjer","Updates":"Uppdateringar","Social":"Socialt","Forums":"Forum","Primary":"Primär",
  "Sign in":"Logga in","Sign out":"Logga ut","Settings":"Inställningar",
  "No new mail":"Ingen ny e-post","No messages":"Inga meddelanden","Last updated":"Senast uppdaterad","Retry":"Försök igen",
  "Connected":"Ansluten","Disconnected":"Frånkopplad","Sync":"Synkronisering",
  "No upcoming events":"Inga kommande händelser","Nothing scheduled":"Inget planerat",
  "Mark all as read":"Markera alla som lästa","Agenda":"Dagordning","All Mail":"All e-post","Move to":"Flytta till",
  "Updated":"Uppdaterad","Refresh":"Uppdatera","Preferences":"Inställningar",
  "Holiday":"Helgdag","To Do":"Att göra","Remove":"Ta bort",
  "Accept meeting request":"Acceptera mötesförfrågan","Decline meeting request":"Avvisa mötesförfrågan",
 },
 "tr": {
  "Starred":"Yıldızlı","Star":"Yıldız","Mute":"Sessize al","Snooze":"Ertele","Snoozed":"Ertelendi",
  "Promotions":"Promosyonlar","Updates":"Güncellemeler","Social":"Sosyal","Forums":"Forumlar","Primary":"Birincil",
  "Sign in":"Oturum aç","Sign out":"Oturumu kapat","Settings":"Ayarlar",
  "No new mail":"Yeni e-posta yok","No messages":"Mesaj yok","Last updated":"Son güncelleme","Retry":"Yeniden dene",
  "Connected":"Bağlı","Disconnected":"Bağlı değil","Sync":"Senkronizasyon",
  "No upcoming events":"Yaklaşan etkinlik yok","Nothing scheduled":"Planlanmış etkinlik yok",
  "Mark all as read":"Tümünü okunmuş işaretle","Agenda":"Gündem","All Mail":"Tüm e-posta","Move to":"Şuraya taşı",
  "Updated":"Güncellendi","Refresh":"Yenile","Preferences":"Tercihler",
  "Holiday":"Tatil","To Do":"Yapılacaklar","Remove":"Kaldır",
  "Accept meeting request":"Toplantı isteğini kabul et","Decline meeting request":"Toplantı isteğini reddet",
 },
 "uk": {
  "Starred":"Позначено зіркою","Star":"Зірка","Mute":"Вимкнути звук","Snooze":"Відкласти","Snoozed":"Відкладено",
  "Promotions":"Акції","Updates":"Оновлення","Social":"Соціальні","Forums":"Форуми","Primary":"Основні",
  "Sign in":"Увійти","Sign out":"Вийти","Settings":"Налаштування",
  "No new mail":"Немає нових листів","No messages":"Немає повідомлень","Last updated":"Останнє оновлення","Retry":"Повторити",
  "Connected":"Підключено","Disconnected":"Відключено","Sync":"Синхронізація",
  "No upcoming events":"Немає майбутніх подій","Nothing scheduled":"Нічого не заплановано",
  "Mark all as read":"Позначити все прочитаним","Agenda":"Порядок денний","All Mail":"Всі листи","Move to":"Перемістити в",
  "Updated":"Оновлено","Refresh":"Оновити","Preferences":"Налаштування",
  "Holiday":"Свято","To Do":"Завдання","Remove":"Видалити",
  "Accept meeting request":"Прийняти запит на зустріч","Decline meeting request":"Відхилити запит на зустріч",
 },
 "zh_CN": {
  "Starred":"已加星标","Star":"加星标","Mute":"静音","Snooze":"稍后提醒","Snoozed":"已稍后提醒",
  "Promotions":"促销","Updates":"更新","Social":"社交","Forums":"论坛","Primary":"主要",
  "Sign in":"登录","Sign out":"退出登录","Settings":"设置",
  "No new mail":"没有新邮件","No messages":"没有消息","Last updated":"上次更新","Retry":"重试",
  "Connected":"已连接","Disconnected":"已断开","Sync":"同步",
  "No upcoming events":"没有即将到来的活动","Nothing scheduled":"没有日程安排",
  "Mark all as read":"全部标为已读","Agenda":"议程","All Mail":"所有邮件","Move to":"移至",
  "Updated":"已更新","Refresh":"刷新","Preferences":"偏好设置",
  "Holiday":"节假日","To Do":"待办事项","Remove":"移除",
  "Accept meeting request":"接受会议请求","Decline meeting request":"拒绝会议请求",
 },
}

# Gap fills for generic LABELS words that Evolution keeps under msgctxt
# (so the conky lookup never finds them). Merged into MANUAL.
GAP = {
 "ar": {
  "Message":"رسالة","Error":"خطأ","Load":"تحميل","Open":"فتح",
  "Archive":"أرشيف","Attachment":"مرفق","Save":"حفظ","Close":"إغلاق",
  "Account":"حساب","Accounts":"حسابات","Folder":"مجلد","Search":"بحث",
  "Show":"عرض","Year":"سنة","Export":"تصدير","Print…":"طباعة…",
  "Undo":"تراجع","Offline":"غير متصل",
 },
 "cs": {"Message":"Zpráva","Error":"Chyba","Load":"Načíst","Open":"Otevřít","Reminder":"Připomínka"},
 "da": {"Message":"Besked","Error":"Fejl","Load":"Indlæs","Open":"Åbn","Reminder":"Påmindelse"},
 "de": {"Message":"Nachricht","Error":"Fehler","Load":"Laden","Open":"Öffnen","Reminder":"Erinnerung"},
 "es": {"Message":"Mensaje","Error":"Error","Load":"Cargar","Open":"Abrir","Reminder":"Recordatorio"},
 "fi": {"Message":"Viesti","Error":"Virhe","Load":"Lataa","Open":"Avaa","Reminder":"Muistutus"},
 "fr": {"Message":"Message","Error":"Erreur","Load":"Charger","Open":"Ouvrir","Reminder":"Rappel"},
 "hr": {"Message":"Poruka","Error":"Greška","Load":"Učitaj","Open":"Otvori","Export":"Izvoz","Reminder":"Podsjetnik"},
 "hu": {"Message":"Üzenet","Error":"Hiba","Load":"Betöltés","Open":"Megnyitás","Reminder":"Emlékeztető"},
 "it": {"Message":"Messaggio","Error":"Errore","Load":"Carica","Open":"Apri","Export":"Esporta","Reminder":"Promemoria"},
 "ja": {
  "Message":"メッセージ","Error":"エラー","Load":"読み込み","Open":"開く",
  "Archive":"アーカイブ","Save":"保存","Accounts":"アカウント","Show":"表示",
  "Events":"イベント","Year":"年","Export":"エクスポート","Print…":"印刷…",
  "Undo":"元に戻す","Warning":"警告","Offline":"オフライン",
  "Website":"ウェブサイト","Recent":"最近","Reminder":"リマインダー",
 },
 "ko": {"Message":"메시지","Error":"오류","Load":"불러오기","Open":"열기","Reminder":"알림"},
 "nl": {"Message":"Bericht","Error":"Fout","Load":"Laden","Open":"Openen","Reminder":"Herinnering"},
 "pl": {"Message":"Wiadomość","Error":"Błąd","Load":"Wczytaj","Open":"Otwórz","Reminder":"Przypomnienie"},
 "pt": {"Message":"Mensagem","Error":"Erro","Load":"Carregar","Open":"Abrir","Reminder":"Lembrete"},
 "ro": {"Message":"Mesaj","Error":"Eroare","Load":"Încarcă","Open":"Deschide","Save":"Salvează","Year":"An","Export":"Exportă","Reminder":"Memento"},
 "ru": {"Message":"Сообщение","Error":"Ошибка","Load":"Загрузить","Open":"Открыть","Reminder":"Напоминание"},
 "sv": {"Message":"Meddelande","Error":"Fel","Load":"Läs in","Open":"Öppna","Reminder":"Påminnelse"},
 "tr": {"Message":"Mesaj","Error":"Hata","Load":"Yükle","Open":"Aç","Reminder":"Hatırlatma"},
 "uk": {"Message":"Повідомлення","Error":"Помилка","Load":"Завантажити","Open":"Відкрити","Reminder":"Нагадування"},
 "zh_CN": {"Message":"消息","Error":"错误","Load":"加载","Open":"打开","Reminder":"提醒"},
 "ar": {
  "Message":"رسالة","Error":"خطأ","Load":"تحميل","Open":"فتح",
  "Archive":"أرشيف","Attachment":"مرفق","Save":"حفظ","Close":"إغلاق",
  "Account":"حساب","Accounts":"حسابات","Folder":"مجلد","Search":"بحث",
  "Show":"عرض","Year":"سنة","Export":"تصدير","Print…":"طباعة…",
  "Undo":"تراجع","Offline":"غير متصل",
  "Website":"موقع ويب","Recent":"الأخيرة","Reminder":"تذكير",
 },
}

# Google-widget labels, translated manually for every non-en language.
WIDGET_MANUAL = {
 "ar": {
  "Due today":"مستحق اليوم","Overdue":"متأخر","Incomplete":"غير مكتمل","Add task":"إضافة مهمة",
  "New task":"مهمة جديدة","Edit task":"تعديل مهمة","Task details":"تفاصيل المهمة","Task list":"قائمة المهام",
  "To Do list":"قائمة المهام","Subtasks":"مهام فرعية","Medium":"متوسط",
  "Priority: High":"أولوية: عالية","Priority: Medium":"أولوية: متوسطة","Priority: Low":"أولوية: منخفضة","Mark complete":"وضع علامة مكتمل",
  "Full name":"الاسم الكامل","First name":"الاسم الأول","Last name":"اسم العائلة","Mobile":"جوال","Job title":"المسمى الوظيفي","Email address":"عنوان البريد الإلكتروني",
  "Drive":"محرك الأقراص","Storage":"التخزين","Used":"مستخدم","Quota":"الحصة النسبية","Upload":"رفع","Download":"تنزيل","Recent files":"الملفات الأخيرة",
  "Shared with me":"مشارَك معي","My Drive":"محرّك أقراصي","Folder size":"حجم المجلد",
  "Video":"فيديو","Videos":"فيديوهات","Channel":"قناة","Channels":"قنوات","Subscription":"اشتراك","Subscriptions":"اشتراكات",
  "Views":"المشاهدات","Uploads":"التحميلات","Latest":"الأحدث","Watch":"شاهد","Playlists":"قوائم التشغيل","Comments":"التعليقات",
  "Meeting code":"رمز الاجتماع","Join":"انضم","Join now":"انضم الآن","Ongoing":"جاري","Ended":"انتهى","History":"السجل","Past calls":"المكالمات السابقة","Leave":"مغادرة","Participants":"المشاركون",
  "Pin":"تثبيت","Pinned":"مثبّت","Checklist":"قائمة تحقق",
  "Space":"مساحة","Spaces":"مساحات","Direct message":"رسالة مباشرة","Direct messages":"رسائل مباشرة","Mentions":"ذِكر","Thread":"سلسلة","Threads":"سلاسل","Group chat":"محادثة جماعية","Reaction":"تفاعل","React":"تفاعل",
 },
 "cs": {
  "Due today":"Splatné dnes","Overdue":"Po termínu","Incomplete":"Nedokončeno","Add task":"Přidat úkol",
  "New task":"Nový úkol","Edit task":"Upravit úkol","Task details":"Podrobnosti úkolu","Task list":"Seznam úkolů",
  "To Do list":"Seznam úkolů","Subtasks":"Dílčí úkoly","Medium":"Střední",
  "Priority: High":"Priorita: Vysoká","Priority: Medium":"Priorita: Střední","Priority: Low":"Priorita: Nízká","Mark complete":"Označit jako dokončeno",
  "Full name":"Celé jméno","First name":"Křestní jméno","Last name":"Příjmení","Mobile":"Mobil","Job title":"Pracovní pozice","Email address":"E-mailová adresa",
  "Drive":"Disk","Storage":"Úložiště","Used":"Použito","Quota":"Kvóta","Upload":"Nahrát","Download":"Stáhnout","Recent files":"Nedávné soubory",
  "Shared with me":"Sdíleno se mnou","My Drive":"Můj disk","Folder size":"Velikost složky",
  "Video":"Video","Videos":"Videa","Channel":"Kanál","Channels":"Kanály","Subscription":"Odběr","Subscriptions":"Odběry",
  "Views":"Zhlédnutí","Uploads":"Nahráno","Latest":"Nejnovější","Watch":"Sledovat","Playlists":"Seznamy videí","Comments":"Komentáře",
  "Meeting code":"Kód schůzky","Join":"Připojit","Join now":"Připojit se nyní","Ongoing":"Probíhá","Ended":"Skončeno","History":"Historie","Past calls":"Minulé hovory","Leave":"Odejít","Participants":"Účastníci",
  "Pin":"Připnout","Pinned":"Připnuto","Checklist":"Kontrolní seznam",
  "Space":"Prostor","Spaces":"Prostory","Direct message":"Přímá zpráva","Direct messages":"Přímé zprávy","Mentions":"Zmínky","Thread":"Vlákno","Threads":"Vlákna","Group chat":"Skupinový chat","Reaction":"Reakce","React":"Reagovat",
 },
 "da": {
  "Due today":"Forfalder i dag","Overdue":"Forfalden","Incomplete":"Ufuldstændig","Add task":"Tilføj opgave",
  "New task":"Ny opgave","Edit task":"Rediger opgave","Task details":"Opgavedetaljer","Task list":"Opgaveliste",
  "To Do list":"Gøremålsliste","Subtasks":"Underopgaver","Medium":"Middel",
  "Priority: High":"Prioritet: Høj","Priority: Medium":"Prioritet: Middel","Priority: Low":"Prioritet: Lav","Mark complete":"Markér som fuldført",
  "Full name":"Fulde navn","First name":"Fornavn","Last name":"Efternavn","Mobile":"Mobil","Job title":"Stilling","Email address":"E-mailadresse",
  "Drive":"Drev","Storage":"Lagerplads","Used":"Brugt","Quota":"Kvote","Upload":"Upload","Download":"Download","Recent files":"Seneste filer",
  "Shared with me":"Delt med mig","My Drive":"Mit drev","Folder size":"Mappestørrelse",
  "Video":"Video","Videos":"Videoer","Channel":"Kanal","Channels":"Kanaler","Subscription":"Abonnement","Subscriptions":"Abonnementer",
  "Views":"Visninger","Uploads":"Uploads","Latest":"Seneste","Watch":"Se","Playlists":"Playlister","Comments":"Kommentarer",
  "Meeting code":"Mødekode","Join":"Deltag","Join now":"Deltag nu","Ongoing":"I gang","Ended":"Afsluttet","History":"Historik","Past calls":"Tidligere opkald","Leave":"Forlad","Participants":"Deltagere",
  "Pin":"Fastgør","Pinned":"Fastgjort","Checklist":"Tjekliste",
  "Space":"Rum","Spaces":"Rum","Direct message":"Direkte besked","Direct messages":"Direkte beskeder","Mentions":"Omtaler","Thread":"Tråd","Threads":"Tråde","Group chat":"Gruppechat","Reaction":"Reaktion","React":"Reager",
 },
 "de": {
  "Due today":"Heute fällig","Overdue":"Überfällig","Incomplete":"Unvollständig","Add task":"Aufgabe hinzufügen",
  "New task":"Neue Aufgabe","Edit task":"Aufgabe bearbeiten","Task details":"Aufgabendetails","Task list":"Aufgabenliste",
  "To Do list":"Aufgabenliste","Subtasks":"Unteraufgaben","Medium":"Mittel",
  "Priority: High":"Priorität: Hoch","Priority: Medium":"Priorität: Mittel","Priority: Low":"Priorität: Niedrig","Mark complete":"Als erledigt markieren",
  "Full name":"Vollständiger Name","First name":"Vorname","Last name":"Nachname","Mobile":"Mobil","Job title":"Berufsbezeichnung","Email address":"E-Mail-Adresse",
  "Drive":"Laufwerk","Storage":"Speicher","Used":"Verwendet","Quota":"Kontingent","Upload":"Hochladen","Download":"Herunterladen","Recent files":"Zuletzt verwendete Dateien",
  "Shared with me":"Mit mir geteilt","My Drive":"Mein Laufwerk","Folder size":"Ordnergröße",
  "Video":"Video","Videos":"Videos","Channel":"Kanal","Channels":"Kanäle","Subscription":"Abonnement","Subscriptions":"Abonnements",
  "Views":"Aufrufe","Uploads":"Uploads","Latest":"Neueste","Watch":"Ansehen","Playlists":"Wiedergabelisten","Comments":"Kommentare",
  "Meeting code":"Besprechungscode","Join":"Beitreten","Join now":"Jetzt beitreten","Ongoing":"Läuft","Ended":"Beendet","History":"Verlauf","Past calls":"Vergangene Anrufe","Leave":"Verlassen","Participants":"Teilnehmer",
  "Pin":"Anheften","Pinned":"Angeheftet","Checklist":"Checkliste",
  "Space":"Bereich","Spaces":"Bereiche","Direct message":"Direktnachricht","Direct messages":"Direktnachrichten","Mentions":"Erwähnungen","Thread":"Thread","Threads":"Threads","Group chat":"Gruppenchat","Reaction":"Reaktion","React":"Reagieren",
 },
 "es": {
  "Due today":"Vence hoy","Overdue":"Vencido","Incomplete":"Incompleto","Add task":"Añadir tarea",
  "New task":"Nueva tarea","Edit task":"Editar tarea","Task details":"Detalles de la tarea","Task list":"Lista de tareas",
  "To Do list":"Lista de tareas","Subtasks":"Subtareas","Medium":"Medio",
  "Priority: High":"Prioridad: Alta","Priority: Medium":"Prioridad: Media","Priority: Low":"Prioridad: Baja","Mark complete":"Marcar como completada",
  "Full name":"Nombre completo","First name":"Nombre","Last name":"Apellido","Mobile":"Móvil","Job title":"Puesto de trabajo","Email address":"Dirección de correo",
  "Drive":"Unidad","Storage":"Almacenamiento","Used":"Usado","Quota":"Cuota","Upload":"Subir","Download":"Descargar","Recent files":"Archivos recientes",
  "Shared with me":"Compartido conmigo","My Drive":"Mi unidad","Folder size":"Tamaño de la carpeta",
  "Video":"Vídeo","Videos":"Vídeos","Channel":"Canal","Channels":"Canales","Subscription":"Suscripción","Subscriptions":"Suscripciones",
  "Views":"Reproducciones","Uploads":"Subidas","Latest":"Recientes","Watch":"Ver","Playlists":"Listas de reproducción","Comments":"Comentarios",
  "Meeting code":"Código de reunión","Join":"Unirse","Join now":"Unirse ahora","Ongoing":"En curso","Ended":"Finalizado","History":"Historial","Past calls":"Llamadas anteriores","Leave":"Salir","Participants":"Participantes",
  "Pin":"Fijar","Pinned":"Fijado","Checklist":"Lista de verificación",
  "Space":"Espacio","Spaces":"Espacios","Direct message":"Mensaje directo","Direct messages":"Mensajes directos","Mentions":"Menciones","Thread":"Hilo","Threads":"Hilos","Group chat":"Chat de grupo","Reaction":"Reacción","React":"Reaccionar",
 },
 "fi": {
  "Due today":"Erääntyy tänään","Overdue":"Myöhässä","Incomplete":"Keskeneräinen","Add task":"Lisää tehtävä",
  "New task":"Uusi tehtävä","Edit task":"Muokkaa tehtävää","Task details":"Tehtävän tiedot","Task list":"Tehtävälista",
  "To Do list":"Tehtävälista","Subtasks":"Alitehtävät","Medium":"Keskitaso",
  "Priority: High":"Prioriteetti: Korkea","Priority: Medium":"Prioriteetti: Keski","Priority: Low":"Prioriteetti: Matala","Mark complete":"Merkitse tehdyksi",
  "Full name":"Koko nimi","First name":"Etunimi","Last name":"Sukunimi","Mobile":"Matkapuhelin","Job title":"Työnimike","Email address":"Sähköpostiosoite",
  "Drive":"Asema","Storage":"Tallennus","Used":"Käytetty","Quota":"Kiintiö","Upload":"Lataa","Download":"Lataa","Recent files":"Viimeisimmät tiedostot",
  "Shared with me":"Jaettu kanssani","My Drive":"Oma Drive","Folder size":"Kansion koko",
  "Video":"Video","Videos":"Videot","Channel":"Kanava","Channels":"Kanavat","Subscription":"Tilaus","Subscriptions":"Tilaukset",
  "Views":"Katselut","Uploads":"Lataukset","Latest":"Uusimmat","Watch":"Katso","Playlists":"Soittolistat","Comments":"Kommentit",
  "Meeting code":"Kokouskoodi","Join":"Liity","Join now":"Liity nyt","Ongoing":"Käynnissä","Ended":"Päättynyt","History":"Historia","Past calls":"Aiemmat puhelut","Leave":"Poistu","Participants":"Osallistujat",
  "Pin":"Kiinnitä","Pinned":"Kiinnitetty","Checklist":"Tarkistuslista",
  "Space":"Tila","Spaces":"Tilat","Direct message":"Suora viesti","Direct messages":"Suorat viestit","Mentions":"Maininnat","Thread":"Ketju","Threads":"Ketjut","Group chat":"Ryhmäkeskustelu","Reaction":"Reaktio","React":"Reagoi",
 },
 "fr": {
  "Due today":"À faire aujourd'hui","Overdue":"En retard","Incomplete":"Incomplet","Add task":"Ajouter une tâche",
  "New task":"Nouvelle tâche","Edit task":"Modifier la tâche","Task details":"Détails de la tâche","Task list":"Liste de tâches",
  "To Do list":"Liste de tâches","Subtasks":"Sous-tâches","Medium":"Moyen",
  "Priority: High":"Priorité : Haute","Priority: Medium":"Priorité : Moyenne","Priority: Low":"Priorité : Basse","Mark complete":"Marquer comme terminé",
  "Full name":"Nom complet","First name":"Prénom","Last name":"Nom","Mobile":"Mobile","Job title":"Intitulé du poste","Email address":"Adresse e-mail",
  "Drive":"Disque","Storage":"Stockage","Used":"Utilisé","Quota":"Quota","Upload":"Importer","Download":"Télécharger","Recent files":"Fichiers récents",
  "Shared with me":"Partagé avec moi","My Drive":"Mon Drive","Folder size":"Taille du dossier",
  "Video":"Vidéo","Videos":"Vidéos","Channel":"Chaîne","Channels":"Chaînes","Subscription":"Abonnement","Subscriptions":"Abonnements",
  "Views":"Vues","Uploads":"Importations","Latest":"Récents","Watch":"Regarder","Playlists":"Listes de lecture","Comments":"Commentaires",
  "Meeting code":"Code de réunion","Join":"Rejoindre","Join now":"Rejoindre maintenant","Ongoing":"En cours","Ended":"Terminé","History":"Historique","Past calls":"Appels passés","Leave":"Quitter","Participants":"Participants",
  "Pin":"Épingler","Pinned":"Épinglé","Checklist":"Liste de contrôle",
  "Space":"Espace","Spaces":"Espaces","Direct message":"Message direct","Direct messages":"Messages directs","Mentions":"Mentions","Thread":"Fil","Threads":"Fils","Group chat":"Discussion de groupe","Reaction":"Réaction","React":"Réagir",
 },
 "hr": {
  "Due today":"Dospijeva danas","Overdue":"Zakašnjelo","Incomplete":"Nedovršeno","Add task":"Dodaj zadatak",
  "New task":"Novi zadatak","Edit task":"Uredi zadatak","Task details":"Detalji zadatka","Task list":"Popis zadataka",
  "To Do list":"Popis zadataka","Subtasks":"Podzadaci","Medium":"Srednje",
  "Priority: High":"Prioritet: Visok","Priority: Medium":"Prioritet: Srednji","Priority: Low":"Prioritet: Nizak","Mark complete":"Označi kao dovršeno",
  "Full name":"Puno ime","First name":"Ime","Last name":"Prezime","Mobile":"Mobitel","Job title":"Radno mjesto","Email address":"Adresa e-pošte",
  "Drive":"Disk","Storage":"Pohrana","Used":"Iskorišteno","Quota":"Kvota","Upload":"Prenesi","Download":"Preuzmi","Recent files":"Nedavne datoteke",
  "Shared with me":"Podijeljeno sa mnom","My Drive":"Moj disk","Folder size":"Veličina mape",
  "Video":"Videozapis","Videos":"Videozapisi","Channel":"Kanal","Channels":"Kanali","Subscription":"Pretplata","Subscriptions":"Pretplate",
  "Views":"Pregledi","Uploads":"Prijenos","Latest":"Najnovije","Watch":"Gledaj","Playlists":"Popisi za reprodukciju","Comments":"Komentari",
  "Meeting code":"Kod sastanka","Join":"Pridruži se","Join now":"Pridruži se sada","Ongoing":"U tijeku","Ended":"Završeno","History":"Povijest","Past calls":"Prošli pozivi","Leave":"Napuštanje","Participants":"Sudionici",
  "Pin":"Zakači","Pinned":"Zakačeno","Checklist":"Kontrolni popis",
  "Space":"Prostor","Spaces":"Prostori","Direct message":"Izravna poruka","Direct messages":"Izravne poruke","Mentions":"Spominjanja","Thread":"Nit","Threads":"Niti","Group chat":"Grupni chat","Reaction":"Reakcija","React":"Reagiraj",
 },
 "hu": {
  "Due today":"Ma esedékes","Overdue":"Lejárt","Incomplete":"Befejezetlen","Add task":"Feladat hozzáadása",
  "New task":"Új feladat","Edit task":"Feladat szerkesztése","Task details":"Feladat részletei","Task list":"Feladatlista",
  "To Do list":"Teendőlista","Subtasks":"Alfeladatok","Medium":"Közepes",
  "Priority: High":"Prioritás: Magas","Priority: Medium":"Prioritás: Közepes","Priority: Low":"Prioritás: Alacsony","Mark complete":"Befejezettnek jelölés",
  "Full name":"Teljes név","First name":"Keresztnév","Last name":"Vezetéknév","Mobile":"Mobil","Job title":"Beosztás","Email address":"E-mail cím",
  "Drive":"Meghajtó","Storage":"Tárhely","Used":"Használt","Quota":"Kvóta","Upload":"Feltöltés","Download":"Letöltés","Recent files":"Legutóbbi fájlok",
  "Shared with me":"Velem megosztva","My Drive":"Saját Drive","Folder size":"Mappa mérete",
  "Video":"Videó","Videos":"Videók","Channel":"Csatorna","Channels":"Csatornák","Subscription":"Feliratkozás","Subscriptions":"Feliratkozások",
  "Views":"Megtekintések","Uploads":"Feltöltések","Latest":"Legújabb","Watch":"Megtekintés","Playlists":"Lejátszási listák","Comments":"Hozzászólások",
  "Meeting code":"Értekezleti kód","Join":"Csatlakozás","Join now":"Csatlakozás most","Ongoing":"Folyamatban","Ended":"Vége","History":"Előzmények","Past calls":"Korábbi hívások","Leave":"Kilépés","Participants":"Résztvevők",
  "Pin":"Rögzítés","Pinned":"Rögzítve","Checklist":"Ellenőrzőlista",
  "Space":"Tér","Spaces":"Terek","Direct message":"Közvetlen üzenet","Direct messages":"Közvetlen üzenetek","Mentions":"Említések","Thread":"Szál","Threads":"Szálak","Group chat":"Csoportos csevegés","Reaction":"Reakció","React":"Reagálás",
 },
 "it": {
  "Due today":"Scade oggi","Overdue":"In ritardo","Incomplete":"Incompleto","Add task":"Aggiungi attività",
  "New task":"Nuova attività","Edit task":"Modifica attività","Task details":"Dettagli attività","Task list":"Elenco attività",
  "To Do list":"Elenco attività","Subtasks":"Sottoattività","Medium":"Medio",
  "Priority: High":"Priorità: Alta","Priority: Medium":"Priorità: Media","Priority: Low":"Priorità: Bassa","Mark complete":"Segna come completata",
  "Full name":"Nome completo","First name":"Nome","Last name":"Cognome","Mobile":"Cellulare","Job title":"Qualifica","Email address":"Indirizzo e-mail",
  "Drive":"Unità","Storage":"Archiviazione","Used":"Usato","Quota":"Quota","Upload":"Carica","Download":"Scarica","Recent files":"File recenti",
  "Shared with me":"Condiviso con me","My Drive":"Il mio Drive","Folder size":"Dimensione cartella",
  "Video":"Video","Videos":"Video","Channel":"Canale","Channels":"Canali","Subscription":"Abbonamento","Subscriptions":"Abbonamenti",
  "Views":"Visualizzazioni","Uploads":"Caricamenti","Latest":"Più recenti","Watch":"Guarda","Playlists":"Playlist","Comments":"Commenti",
  "Meeting code":"Codice riunione","Join":"Partecipa","Join now":"Partecipa ora","Ongoing":"In corso","Ended":"Terminato","History":"Cronologia","Past calls":"Chiamate passate","Leave":"Esci","Participants":"Partecipanti",
  "Pin":"Fissa","Pinned":"Fissato","Checklist":"Elenco di controllo",
  "Space":"Spazio","Spaces":"Spazi","Direct message":"Messaggio diretto","Direct messages":"Messaggi diretti","Mentions":"Menzioni","Thread":"Discussione","Threads":"Discussioni","Group chat":"Chat di gruppo","Reaction":"Reazione","React":"Reagisci",
 },
 "ja": {
  "Due today":"今日期限","Overdue":"期限切れ","Incomplete":"未完了","Add task":"タスクを追加",
  "New task":"新しいタスク","Edit task":"タスクを編集","Task details":"タスクの詳細","Task list":"タスクリスト",
  "To Do list":"To Doリスト","Subtasks":"サブタスク","Medium":"中",
  "Priority: High":"優先度: 高","Priority: Medium":"優先度: 中","Priority: Low":"優先度: 低","Mark complete":"完了にする",
  "Full name":"フルネーム","First name":"名","Last name":"姓","Mobile":"携帯電話","Job title":"役職","Email address":"メールアドレス",
  "Drive":"ドライブ","Storage":"ストレージ","Used":"使用中","Quota":"割り当て","Upload":"アップロード","Download":"ダウンロード","Recent files":"最近のファイル",
  "Shared with me":"共有アイテム","My Drive":"マイドライブ","Folder size":"フォルダサイズ",
  "Video":"動画","Videos":"動画","Channel":"チャンネル","Channels":"チャンネル","Subscription":"登録","Subscriptions":"登録チャンネル",
  "Views":"再生回数","Uploads":"アップロード","Latest":"最新","Watch":"見る","Playlists":"プレイリスト","Comments":"コメント",
  "Meeting code":"会議コード","Join":"参加","Join now":"今すぐ参加","Ongoing":"開催中","Ended":"終了","History":"履歴","Past calls":"過去の通話","Leave":"退出","Participants":"参加者",
  "Pin":"ピン留め","Pinned":"ピン留め済み","Checklist":"チェックリスト",
  "Space":"スペース","Spaces":"スペース","Direct message":"ダイレクトメッセージ","Direct messages":"ダイレクトメッセージ","Mentions":"メンション","Thread":"スレッド","Threads":"スレッド","Group chat":"グループチャット","Reaction":"リアクション","React":"リアクション",
 },
 "ko": {
  "Due today":"오늘 마감","Overdue":"기한 지남","Incomplete":"미완료","Add task":"작업 추가",
  "New task":"새 작업","Edit task":"작업 편집","Task details":"작업 세부정보","Task list":"작업 목록",
  "To Do list":"할 일 목록","Subtasks":"하위 작업","Medium":"중간",
  "Priority: High":"우선순위: 높음","Priority: Medium":"우선순위: 중간","Priority: Low":"우선순위: 낮음","Mark complete":"완료로 표시",
  "Full name":"전체 이름","First name":"이름","Last name":"성","Mobile":"휴대전화","Job title":"직함","Email address":"이메일 주소",
  "Drive":"드라이브","Storage":"저장용량","Used":"사용됨","Quota":"할당량","Upload":"업로드","Download":"다운로드","Recent files":"최근 파일",
  "Shared with me":"나와 공유됨","My Drive":"내 드라이브","Folder size":"폴더 크기",
  "Video":"동영상","Videos":"동영상","Channel":"채널","Channels":"채널","Subscription":"구독","Subscriptions":"구독",
  "Views":"조회수","Uploads":"업로드","Latest":"최신","Watch":"시청","Playlists":"재생목록","Comments":"댓글",
  "Meeting code":"회의 코드","Join":"참여","Join now":"지금 참여","Ongoing":"진행 중","Ended":"종료됨","History":"기록","Past calls":"지난 통화","Leave":"나가기","Participants":"참가자",
  "Pin":"고정","Pinned":"고정됨","Checklist":"체크리스트",
  "Space":"공간","Spaces":"공간","Direct message":"다이렉트 메시지","Direct messages":"다이렉트 메시지","Mentions":"멘션","Thread":"스레드","Threads":"스레드","Group chat":"그룹 채팅","Reaction":"반응","React":"반응",
 },
 "nl": {
  "Due today":"Vandaag vervalt","Overdue":"Te laat","Incomplete":"Onvolledig","Add task":"Taak toevoegen",
  "New task":"Nieuwe taak","Edit task":"Taak bewerken","Task details":"Taakdetails","Task list":"Takenlijst",
  "To Do list":"Takenlijst","Subtasks":"Subtaken","Medium":"Gemiddeld",
  "Priority: High":"Prioriteit: Hoog","Priority: Medium":"Prioriteit: Medium","Priority: Low":"Prioriteit: Laag","Mark complete":"Als voltooid markeren",
  "Full name":"Volledige naam","First name":"Voornaam","Last name":"Achternaam","Mobile":"Mobiel","Job title":"Functietitel","Email address":"E-mailadres",
  "Drive":"Station","Storage":"Opslag","Used":"Gebruikt","Quota":"Quota","Upload":"Uploaden","Download":"Downloaden","Recent files":"Recente bestanden",
  "Shared with me":"Gedeeld met mij","My Drive":"Mijn Drive","Folder size":"Mapgrootte",
  "Video":"Video","Videos":"Video's","Channel":"Kanaal","Channels":"Kanalen","Subscription":"Abonnement","Subscriptions":"Abonnementen",
  "Views":"Weergaven","Uploads":"Uploads","Latest":"Nieuwste","Watch":"Bekijk","Playlists":"Afspeellijsten","Comments":"Reacties",
  "Meeting code":"Vergadercode","Join":"Deelnemen","Join now":"Nu deelnemen","Ongoing":"Lopend","Ended":"Beëindigd","History":"Geschiedenis","Past calls":"Eerdere oproepen","Leave":"Verlaten","Participants":"Deelnemers",
  "Pin":"Vastzetten","Pinned":"Vastgezet","Checklist":"Controlelijst",
  "Space":"Ruimte","Spaces":"Ruimtes","Direct message":"Direct bericht","Direct messages":"Directe berichten","Mentions":"Vermeldingen","Thread":"Discussie","Threads":"Discussies","Group chat":"Groepschat","Reaction":"Reactie","React":"Reageren",
 },
 "pl": {
  "Due today":"Wymagane dziś","Overdue":"Zaległe","Incomplete":"Nieukończone","Add task":"Dodaj zadanie",
  "New task":"Nowe zadanie","Edit task":"Edytuj zadanie","Task details":"Szczegóły zadania","Task list":"Lista zadań",
  "To Do list":"Lista zadań","Subtasks":"Podzadania","Medium":"Średni",
  "Priority: High":"Priorytet: Wysoki","Priority: Medium":"Priorytet: Średni","Priority: Low":"Priorytet: Niski","Mark complete":"Oznacz jako ukończone",
  "Full name":"Pełne imię i nazwisko","First name":"Imię","Last name":"Nazwisko","Mobile":"Telefon komórkowy","Job title":"Stanowisko","Email address":"Adres e-mail",
  "Drive":"Dysk","Storage":"Pamięć","Used":"Użyto","Quota":"Limit","Upload":"Prześlij","Download":"Pobierz","Recent files":"Ostatnie pliki",
  "Shared with me":"Udostępnione mi","My Drive":"Mój dysk","Folder size":"Rozmiar folderu",
  "Video":"Wideo","Videos":"Wideo","Channel":"Kanał","Channels":"Kanały","Subscription":"Subskrypcja","Subscriptions":"Subskrypcje",
  "Views":"Wyświetlenia","Uploads":"Przesyłki","Latest":"Najnowsze","Watch":"Oglądaj","Playlists":"Listy odtwarzania","Comments":"Komentarze",
  "Meeting code":"Kod spotkania","Join":"Dołącz","Join now":"Dołącz teraz","Ongoing":"W toku","Ended":"Zakończone","History":"Historia","Past calls":"Poprzednie połączenia","Leave":"Opuść","Participants":"Uczestnicy",
  "Pin":"Przypnij","Pinned":"Przypięte","Checklist":"Lista kontrolna",
  "Space":"Przestrzeń","Spaces":"Przestrzenie","Direct message":"Wiadomość bezpośrednia","Direct messages":"Wiadomości bezpośrednie","Mentions":"Wzmianki","Thread":"Wątek","Threads":"Wątki","Group chat":"Czat grupowy","Reaction":"Reakcja","React":"Zareaguj",
 },
 "pt": {
  "Due today":"Vence hoje","Overdue":"Em atraso","Incomplete":"Incompleto","Add task":"Adicionar tarefa",
  "New task":"Nova tarefa","Edit task":"Editar tarefa","Task details":"Detalhes da tarefa","Task list":"Lista de tarefas",
  "To Do list":"Lista de tarefas","Subtasks":"Subtarefas","Medium":"Médio",
  "Priority: High":"Prioridade: Alta","Priority: Medium":"Prioridade: Média","Priority: Low":"Prioridade: Baixa","Mark complete":"Marcar como concluída",
  "Full name":"Nome completo","First name":"Nome","Last name":"Apelido","Mobile":"Telemóvel","Job title":"Cargo","Email address":"Endereço de e-mail",
  "Drive":"Unidade","Storage":"Armazenamento","Used":"Usado","Quota":"Cota","Upload":"Enviar","Download":"Transferir","Recent files":"Ficheiros recentes",
  "Shared with me":"Partilhado comigo","My Drive":"O meu Drive","Folder size":"Tamanho da pasta",
  "Video":"Vídeo","Videos":"Vídeos","Channel":"Canal","Channels":"Canais","Subscription":"Subscrição","Subscriptions":"Subscrições",
  "Views":"Visualizações","Uploads":"Envios","Latest":"Mais recentes","Watch":"Ver","Playlists":"Listas de reprodução","Comments":"Comentários",
  "Meeting code":"Código de reunião","Join":"Participar","Join now":"Participar agora","Ongoing":"Em curso","Ended":"Terminado","History":"Histórico","Past calls":"Chamadas anteriores","Leave":"Sair","Participants":"Participantes",
  "Pin":"Afixar","Pinned":"Afixado","Checklist":"Lista de verificação",
  "Space":"Espaço","Spaces":"Espaços","Direct message":"Mensagem direta","Direct messages":"Mensagens diretas","Mentions":"Menções","Thread":"Tópico","Threads":"Tópicos","Group chat":"Conversa de grupo","Reaction":"Reação","React":"Reagir",
 },
 "ro": {
  "Due today":"Scade azi","Overdue":"Întârziat","Incomplete":"Incomplet","Add task":"Adaugă sarcină",
  "New task":"Sarcină nouă","Edit task":"Editează sarcina","Task details":"Detalii sarcină","Task list":"Listă de sarcini",
  "To Do list":"Listă de sarcini","Subtasks":"Subsarcini","Medium":"Mediu",
  "Priority: High":"Prioritate: Ridicată","Priority: Medium":"Prioritate: Medie","Priority: Low":"Prioritate: Scăzută","Mark complete":"Marchează ca finalizată",
  "Full name":"Nume complet","First name":"Prenume","Last name":"Nume","Mobile":"Mobil","Job title":"Funcție","Email address":"Adresă de e-mail",
  "Drive":"Disc","Storage":"Stocare","Used":"Folosit","Quota":"Cotă","Upload":"Încarcă","Download":"Descarcă","Recent files":"Fișiere recente",
  "Shared with me":"Partajat cu mine","My Drive":"Discul meu","Folder size":"Dimensiune folder",
  "Video":"Video","Videos":"Videoclipuri","Channel":"Canal","Channels":"Canale","Subscription":"Abonament","Subscriptions":"Abonamente",
  "Views":"Vizualizări","Uploads":"Încărcări","Latest":"Cele mai recente","Watch":"Vizionează","Playlists":"Liste de redare","Comments":"Comentarii",
  "Meeting code":"Cod de întâlnire","Join":"Participă","Join now":"Participă acum","Ongoing":"În desfășurare","Ended":"S-a încheiat","History":"Istoric","Past calls":"Apeluri anterioare","Leave":"Părăsește","Participants":"Participanți",
  "Pin":"Fixare","Pinned":"Fixat","Checklist":"Listă de verificare",
  "Space":"Spațiu","Spaces":"Spații","Direct message":"Mesaj direct","Direct messages":"Mesaje directe","Mentions":"Mențiuni","Thread":"Discuție","Threads":"Discuții","Group chat":"Chat de grup","Reaction":"Reacție","React":"Reacționează",
 },
 "ru": {
  "Due today":"Истекает сегодня","Overdue":"Просрочено","Incomplete":"Незавершено","Add task":"Добавить задачу",
  "New task":"Новая задача","Edit task":"Изменить задачу","Task details":"Детали задачи","Task list":"Список задач",
  "To Do list":"Список дел","Subtasks":"Подзадачи","Medium":"Средний",
  "Priority: High":"Приоритет: высокий","Priority: Medium":"Приоритет: средний","Priority: Low":"Приоритет: низкий","Mark complete":"Отметить выполненным",
  "Full name":"Полное имя","First name":"Имя","Last name":"Фамилия","Mobile":"Мобильный","Job title":"Должность","Email address":"Электронная почта",
  "Drive":"Диск","Storage":"Хранилище","Used":"Использовано","Quota":"Квота","Upload":"Загрузить","Download":"Скачать","Recent files":"Недавние файлы",
  "Shared with me":"Доступные мне","My Drive":"Мой диск","Folder size":"Размер папки",
  "Video":"Видео","Videos":"Видео","Channel":"Канал","Channels":"Каналы","Subscription":"Подписка","Subscriptions":"Подписки",
  "Views":"Просмотры","Uploads":"Загрузки","Latest":"Последние","Watch":"Смотреть","Playlists":"Плейлисты","Comments":"Комментарии",
  "Meeting code":"Код встречи","Join":"Присоединиться","Join now":"Присоединиться сейчас","Ongoing":"Идёт","Ended":"Завершено","History":"История","Past calls":"Прошлые звонки","Leave":"Покинуть","Participants":"Участники",
  "Pin":"Закрепить","Pinned":"Закреплено","Checklist":"Контрольный список",
  "Space":"Пространство","Spaces":"Пространства","Direct message":"Личное сообщение","Direct messages":"Личные сообщения","Mentions":"Упоминания","Thread":"Ветка","Threads":"Ветки","Group chat":"Групповой чат","Reaction":"Реакция","React":"Реагировать",
 },
 "sv": {
  "Due today":"Förfaller idag","Overdue":"Försenad","Incomplete":"Ofullständig","Add task":"Lägg till uppgift",
  "New task":"Ny uppgift","Edit task":"Redigera uppgift","Task details":"Uppgiftsdetaljer","Task list":"Uppgiftslista",
  "To Do list":"Att göra-lista","Subtasks":"Deluppgifter","Medium":"Medium",
  "Priority: High":"Prioritet: Hög","Priority: Medium":"Prioritet: Medel","Priority: Low":"Prioritet: Låg","Mark complete":"Markera som klar",
  "Full name":"Fullständigt namn","First name":"Förnamn","Last name":"Efternamn","Mobile":"Mobil","Job title":"Befattning","Email address":"E-postadress",
  "Drive":"Enhet","Storage":"Lagring","Used":"Använt","Quota":"Kvot","Upload":"Ladda upp","Download":"Ladda ner","Recent files":"Senaste filerna",
  "Shared with me":"Delat med mig","My Drive":"Min Drive","Folder size":"Mappstorlek",
  "Video":"Video","Videos":"Videor","Channel":"Kanal","Channels":"Kanaler","Subscription":"Prenumeration","Subscriptions":"Prenumerationer",
  "Views":"Visningar","Uploads":"Uppladdningar","Latest":"Senaste","Watch":"Titta","Playlists":"Spellistor","Comments":"Kommentarer",
  "Meeting code":"Möteskod","Join":"Gå med","Join now":"Gå med nu","Ongoing":"Pågår","Ended":"Avslutad","History":"Historik","Past calls":"Tidigare samtal","Leave":"Lämna","Participants":"Deltagare",
  "Pin":"Fäst","Pinned":"Fastnålad","Checklist":"Checklista",
  "Space":"Utrymme","Spaces":"Utrymmen","Direct message":"Direktmeddelande","Direct messages":"Direktmeddelanden","Mentions":"Omnämnanden","Thread":"Tråd","Threads":"Trådar","Group chat":"Gruppchatt","Reaction":"Reaktion","React":"Reagera",
 },
 "tr": {
  "Due today":"Bugün son tarih","Overdue":"Gecikmiş","Incomplete":"Tamamlanmamış","Add task":"Görev ekle",
  "New task":"Yeni görev","Edit task":"Görevi düzenle","Task details":"Görev ayrıntıları","Task list":"Görev listesi",
  "To Do list":"Yapılacaklar listesi","Subtasks":"Alt görevler","Medium":"Orta",
  "Priority: High":"Öncelik: Yüksek","Priority: Medium":"Öncelik: Orta","Priority: Low":"Öncelik: Düşük","Mark complete":"Tamamlandı olarak işaretle",
  "Full name":"Tam ad","First name":"Ad","Last name":"Soyad","Mobile":"Cep telefonu","Job title":"Unvan","Email address":"E-posta adresi",
  "Drive":"Sürücü","Storage":"Depolama","Used":"Kullanılan","Quota":"Kota","Upload":"Yükle","Download":"İndir","Recent files":"Son dosyalar",
  "Shared with me":"Benimle paylaşılan","My Drive":"Sürücüm","Folder size":"Klasör boyutu",
  "Video":"Video","Videos":"Videolar","Channel":"Kanal","Channels":"Kanallar","Subscription":"Abonelik","Subscriptions":"Abonelikler",
  "Views":"Görüntülenme","Uploads":"Yüklemeler","Latest":"En yeni","Watch":"İzle","Playlists":"Oynatma listeleri","Comments":"Yorumlar",
  "Meeting code":"Toplantı kodu","Join":"Katıl","Join now":"Şimdi katıl","Ongoing":"Devam ediyor","Ended":"Bitti","History":"Geçmiş","Past calls":"Geçmiş aramalar","Leave":"Ayrıl","Participants":"Katılımcılar",
  "Pin":"Sabitle","Pinned":"Sabitlendi","Checklist":"Kontrol listesi",
  "Space":"Alan","Spaces":"Alanlar","Direct message":"Doğrudan mesaj","Direct messages":"Doğrudan mesajlar","Mentions":"Bahsedilmeler","Thread":"Konu","Threads":"Konular","Group chat":"Grup sohbeti","Reaction":"Tepki","React":"Tepki ver",
 },
 "uk": {
  "Due today":"Термін сьогодні","Overdue":"Протерміновано","Incomplete":"Незавершено","Add task":"Додати завдання",
  "New task":"Нове завдання","Edit task":"Редагувати завдання","Task details":"Деталі завдання","Task list":"Список завдань",
  "To Do list":"Список справ","Subtasks":"Підзавдання","Medium":"Середній",
  "Priority: High":"Пріоритет: високий","Priority: Medium":"Пріоритет: середній","Priority: Low":"Пріоритет: низький","Mark complete":"Позначити виконаним",
  "Full name":"Повне ім'я","First name":"Ім'я","Last name":"Прізвище","Mobile":"Мобільний","Job title":"Посада","Email address":"Електронна пошта",
  "Drive":"Диск","Storage":"Сховище","Used":"Використано","Quota":"Квота","Upload":"Завантажити","Download":"Завантажити","Recent files":"Нещодавні файли",
  "Shared with me":"Доступні мені","My Drive":"Мій диск","Folder size":"Розмір папки",
  "Video":"Відео","Videos":"Відео","Channel":"Канал","Channels":"Канали","Subscription":"Підписка","Subscriptions":"Підписки",
  "Views":"Перегляди","Uploads":"Завантаження","Latest":"Останні","Watch":"Дивитися","Playlists":"Плейлисти","Comments":"Коментарі",
  "Meeting code":"Код зустрічі","Join":"Приєднатися","Join now":"Приєднатися зараз","Ongoing":"Триває","Ended":"Завершено","History":"Історія","Past calls":"Минулі дзвінки","Leave":"Покинути","Participants":"Учасники",
  "Pin":"Закріпити","Pinned":"Закріплено","Checklist":"Контрольний список",
  "Space":"Простір","Spaces":"Простору","Direct message":"Пряме повідомлення","Direct messages":"Прямі повідомлення","Mentions":"Згадки","Thread":"Гілка","Threads":"Гілки","Group chat":"Груповий чат","Reaction":"Реакція","React":"Реагувати",
 },
 "zh_CN": {
  "Due today":"今天到期","Overdue":"已逾期","Incomplete":"未完成","Add task":"添加任务",
  "New task":"新任务","Edit task":"编辑任务","Task details":"任务详情","Task list":"任务列表",
  "To Do list":"待办列表","Subtasks":"子任务","Medium":"中",
  "Priority: High":"优先级：高","Priority: Medium":"优先级：中","Priority: Low":"优先级：低","Mark complete":"标记为完成",
  "Full name":"全名","First name":"名","Last name":"姓","Mobile":"手机","Job title":"职位","Email address":"电子邮件地址",
  "Drive":"云盘","Storage":"存储空间","Used":"已用","Quota":"配额","Upload":"上传","Download":"下载","Recent files":"最近文件",
  "Shared with me":"与我共享","My Drive":"我的云盘","Folder size":"文件夹大小",
  "Video":"视频","Videos":"视频","Channel":"频道","Channels":"频道","Subscription":"订阅","Subscriptions":"订阅",
  "Views":"观看次数","Uploads":"上传","Latest":"最新","Watch":"观看","Playlists":"播放列表","Comments":"评论",
  "Meeting code":"会议代码","Join":"加入","Join now":"立即加入","Ongoing":"进行中","Ended":"已结束","History":"历史记录","Past calls":"过去的通话","Leave":"离开","Participants":"参与者",
  "Pin":"置顶","Pinned":"已置顶","Checklist":"清单",
  "Space":"空间","Spaces":"空间","Direct message":"私信","Direct messages":"私信","Mentions":"提及","Thread":"话题","Threads":"话题","Group chat":"群聊","Reaction":"回应","React":"回应",
 },
}

def merged_manual(lang):
    return {**(MANUAL.get(lang, {})), **(GAP.get(lang, {})),
            **(WIDGET_MANUAL.get(lang, {}))}

# --- parsing helpers ------------------------------------------------

def parse_mo_pairs(mo_path):
    raw = subprocess.run(
        ["msgunfmt", mo_path], capture_output=True, text=True
    ).stdout
    # split only on msgid (strip msgctxt blocks entirely)
    blocks = re.split(r'\n(?=msgid )', raw)
    pairs = {}
    for block in blocks:
        m = re.search(r'^msgid "(.*)"$', block, re.M)
        if not m:
            continue
        msgid = m.group(1).replace('\\"', '"')
        ms = re.search(r'^msgstr "(.*)"$', block, re.M)
        msgstr = ms.group(1).replace('\\"', '"') if ms else ""
        pairs[msgid] = msgstr
    return pairs

def existing_msgids(po_path):
    if not os.path.exists(po_path):
        return set()
    ids = set()
    with open(po_path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r'msgid "(.*)"', line)
            if m:
                ids.add(m.group(1))
    return ids

def strip_section(po_path, marker):
    """Remove the previously appended GMAIL section (marker line to EOF)."""
    if not os.path.exists(po_path):
        return
    lines = open(po_path, encoding="utf-8").read().splitlines(True)
    out, in_section = [], False
    for line in lines:
        if marker in line:
            in_section = True
            continue
        if not in_section:
            out.append(line)
    # trim trailing blank lines
    while out and out[-1].strip() == "":
        out.pop()
    open(po_path, "w", encoding="utf-8").writelines(out)

def append_section(po_path, entries, marker):
    existing = existing_msgids(po_path)
    with open(po_path, "a", encoding="utf-8") as f:
        f.write("\n############################################\n")
        f.write(f"# {marker}\n")
        f.write("############################################\n\n")
        for msgid, msgstr in entries:
            if msgid in existing:
                continue
            f.write(f'msgid "{msgid}"\n')
            f.write(f'msgstr "{msgstr}"\n\n')
            existing.add(msgid)

def build_language_table(lang):
    """msgid -> msgstr merged from evolution + manual (manual wins? no:
    evolution wins; manual only fills gaps)."""
    t = {}
    if lang in MO_LANGS:
        for mo in ("evolution.mo", "evolution-data-server.mo"):
            p = os.path.join(LANG_DIR, lang, "LC_MESSAGES", mo)
            if os.path.exists(p):
                t.update(parse_mo_pairs(p))
    man = merged_manual(lang)
    return t, man

# --- main -----------------------------------------------------------

def main():
    marker = "GOOGLE DASHBOARD"
    all_labels = LABELS + EVO_EXTRA + GMAIL_LABELS + WIDGET_LABELS

    # sanity: every label must resolve for every language (no fallback)
    problems = 0
    for lang in ALL_LANGS:
        t, man = build_language_table(lang)
        for label in all_labels:
            if (t.get(label) or "").strip():
                continue
            if (man.get(label) or "").strip():
                continue
            if lang == "en":
                continue  # en auto msgstr=msgid
            print(f"[HIÁNYZIK] {lang}: {label}")
            problems += 1
    if problems:
        print(f"\n{problems} hiányzó fordítás — javítsd a MANUAL-t!")
        return 1

    total = 0
    for lang in ALL_LANGS:
        t, man = build_language_table(lang)
        entries = []
        for label in all_labels:
            val = t.get(label)
            if not (val or "").strip():
                val = man.get(label, label if lang == "en" else None)
            if val is None:
                continue
            entries.append((label, val))
        po = os.path.join(PO_DIR, f"{lang}.po")
        if not os.path.exists(po):
            print(f"[skip] {lang}: no {lang}.po")
            continue
        strip_section(po, marker)
        append_section(po, entries, marker)
        mo_out = os.path.splitext(po)[0] + ".mo"
        subprocess.run(["msgfmt", po, "-o", mo_out], capture_output=True)
        total += len(entries)
        print(f"[ok] {lang}: +{len(entries)}")
    print(f"\nDone. {total} entries appended total.")

if __name__ == "__main__":
    main()