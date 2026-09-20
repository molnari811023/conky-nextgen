/*
 * panel_systray.c — standalone X11 system tray (systray) server
 *
 * Extracted and simplified from AwesomeWM (systray.c + common/xembed.c).
 * Implements the freedesktop system-tray protocol:
 *   - owns the _NET_SYSTEM_TRAY_S<screen> selection
 *   - sends the MANAGER client message to the root window
 *   - docks/embeds tray icons (XEMBED) into its own window
 *   - lays the icons out in a grid (horizontal/vertical, rows, spacing)
 *
 * Copyright © 2008-2009 Julien Danjou <julien@danjou.info>
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Compile:  make
 * Run:      ./panel_systray [--config FILE] [--conky-class NAME] [--right]
 *                          [x] [y] [icon_size] [spacing] [rows] [h|v]
 *
 * Configuration: reads panel_systray.conf from the binary's own directory
 * (or --config FILE). CLI options override the config file. Keys:
 *   conky_class  conky window class to embed into (default none)
 *   right        1 = pin the tray to the host's right edge
 *   x,y          tray offset inside the host (x is the right margin if right=1)
 *   padding      gap in px between the clock and the tray's right edge
 *                (the tray sits left of the clock drawn by Conky; overrides x)
 *   icon_size    per-icon size in px
 *   spacing      gap between icons in px
 *   rows         grid rows (1 = single line)
 *   orientation  h = horizontal, v = vertical
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>

#include <unistd.h>
#include <xcb/xcb.h>
#include <xcb/xcb_icccm.h>

#define SYSTEM_TRAY_REQUEST_DOCK 0

/* ---- XEMBED protocol constants ---- */
#define XEMBED_VERSION                   0
#define XEMBED_MAPPED                    (1 << 0)
#define XEMBED_INFO_FLAGS_ALL            1
#define XEMBED_EMBEDDED_NOTIFY           0
#define XEMBED_WINDOW_ACTIVATE           1
#define XEMBED_WINDOW_DEACTIVATE         2
#define XEMBED_REQUEST_FOCUS             3
#define XEMBED_FOCUS_IN                  4
#define XEMBED_FOCUS_OUT                 5
#define XEMBED_FOCUS_CURRENT             0

/* ---- Embedded window list ---- */
typedef struct
{
    unsigned long version;
    unsigned long flags;
} xembed_info_t;

typedef struct
{
    xcb_window_t   win;
    xembed_info_t  info;
} xembed_window_t;

typedef struct
{
    xembed_window_t *tab;
    int              len;
    int              cap;
} xembed_window_array_t;

/* ---- global state ---- */
static xcb_connection_t  *conn    = NULL;
static xcb_screen_t      *screen  = NULL;
static xcb_window_t       tray_win = 0;
static xcb_atom_t         sel_tray_atom = 0;
static xcb_atom_t         a_net_system_tray_opcode = 0;
static xcb_atom_t         a_kde_wm_system_tray = 0;
static xcb_atom_t         a_manager = 0;
static xcb_atom_t         a_xembed = 0;
static xcb_atom_t         a_xembed_info = 0;
static bool               registered = false;
static bool               running = true;

static xembed_window_array_t embedded = { NULL, 0, 0 };

/* ---- layout config ---- */
static int cfg_x = 0;
static int cfg_y = 0;
static bool cfg_right = false;   /* cfg_x < 0 → align to host right edge */
static bool cfg_center_y = false; /* y = (host_height - tray_height) / 2 */
static int cfg_icon_size = 22;
static int cfg_spacing  = 3;
static int cfg_rows     = 1;
static bool cfg_horizontal = true;
static int cfg_padding  = 10;  /* gap between the clock and the tray's right edge */

static char cfg_conky_class[256] = "";

/* the Conky window the tray is embedded in (for right-alignment) */
static xcb_window_t tray_host = XCB_NONE;

/* ---- atoms ---- */
static xcb_atom_t intern_atom(const char *name)
{
    xcb_intern_atom_cookie_t c = xcb_intern_atom(conn, 0, (uint16_t) strlen(name), name);
    xcb_intern_atom_reply_t *r = xcb_intern_atom_reply(conn, c, NULL);
    xcb_atom_t atom = r ? r->atom : XCB_ATOM_NONE;
    free(r);
    return atom;
}

/* ---- array helpers ---- */
static void emb_push(xcb_window_t win, xembed_info_t *info)
{
    if (embedded.len == embedded.cap)
    {
        embedded.cap = embedded.cap ? embedded.cap * 2 : 8;
        embedded.tab = realloc(embedded.tab, embedded.cap * sizeof(xembed_window_t));
    }
    embedded.tab[embedded.len].win = win;
    embedded.tab[embedded.len].info = *info;
    embedded.len++;
}

static void emb_take(int i)
{
    if (i < 0 || i >= embedded.len) return;
    if (i < embedded.len - 1)
        memmove(&embedded.tab[i], &embedded.tab[i+1],
                (embedded.len - i - 1) * sizeof(xembed_window_t));
    embedded.len--;
}

static xembed_window_t *emb_getbywin(xcb_window_t win)
{
    for (int i = 0; i < embedded.len; i++)
        if (embedded.tab[i].win == win)
            return &embedded.tab[i];
    return NULL;
}

static int emb_num_visible(void)
{
    int n = 0;
    for (int i = 0; i < embedded.len; i++)
        if (embedded.tab[i].info.flags & XEMBED_MAPPED)
            n++;
    return n;
}

/* ---- XEMBED messages ---- */
static void xembed_message_send(xcb_window_t towin, uint32_t message,
                                uint32_t d1, uint32_t d2, uint32_t d3)
{
    xcb_client_message_event_t ev;
    memset(&ev, 0, sizeof(ev));
    ev.response_type = XCB_CLIENT_MESSAGE;
    ev.window = towin;
    ev.format = 32;
    ev.type = a_xembed;
    ev.data.data32[0] = XCB_CURRENT_TIME;
    ev.data.data32[1] = message;
    ev.data.data32[2] = d1;
    ev.data.data32[3] = d2;
    ev.data.data32[4] = d3;
    xcb_send_event(conn, false, towin, XCB_EVENT_MASK_NO_EVENT, (char *) &ev);
}

static void xembed_embedded_notify(xcb_window_t client, uint32_t version)
{
    xembed_message_send(client, XEMBED_EMBEDDED_NOTIFY, 0, tray_win, version);
}

static xcb_get_property_cookie_t xembed_info_get_unchecked(xcb_window_t win)
{
    return xcb_get_property_unchecked(conn, false, win, a_xembed_info,
                                      XCB_GET_PROPERTY_TYPE_ANY, 0, 2);
}

static bool xembed_info_from_reply(xembed_info_t *info, xcb_get_property_reply_t *prop_r)
{
    if (!prop_r || !prop_r->value_len) return false;
    uint32_t *data = (uint32_t *) xcb_get_property_value(prop_r);
    if (!data) return false;
    info->version = data[0];
    info->flags = data[1] & XEMBED_INFO_FLAGS_ALL;
    return true;
}

static bool xembed_info_get_reply(xcb_get_property_cookie_t cookie, xembed_info_t *info)
{
    xcb_get_property_reply_t *prop_r = xcb_get_property_reply(conn, cookie, NULL);
    bool ret = xembed_info_from_reply(info, prop_r);
    free(prop_r);
    return ret;
}

/* ---- layout the tray icons in a grid ---- */

/* fetch the host window's geometry (height used for vertical centering) */
static bool host_geometry(xcb_rectangle_t *out)
{
    if (tray_host == XCB_NONE) return false;
    xcb_get_geometry_cookie_t hg = xcb_get_geometry_unchecked(conn, tray_host);
    xcb_get_geometry_reply_t *gr = xcb_get_geometry_reply(conn, hg, NULL);
    if (!gr) return false;
    if (out)
    {
        out->x = gr->x;
        out->y = gr->y;
        out->width  = gr->width;
        out->height = gr->height;
    }
    free(gr);
    return true;
}

/* effective tray Y: cfg_y normally; centered within the host when configured */
static int effective_tray_y(int tray_h)
{
    if (!cfg_center_y || tray_host == XCB_NONE) return cfg_y;
    xcb_rectangle_t hv;
    if (!host_geometry(&hv)) return cfg_y;
    int y = ((int) hv.height - tray_h) / 2;
    if (y < 0) y = 0;
    return y;
}

/* find the left x (host coords) of the clock text drawn by Conky into the
 * host window, by scanning the right end of the host window for the rightmost
 * cluster of bright pixels (the digital clock). Returns -1 if not found. */
static int host_clock_left(void)
{
    if (tray_host == XCB_NONE) return -1;
    xcb_get_geometry_cookie_t hg = xcb_get_geometry_unchecked(conn, tray_host);
    xcb_get_geometry_reply_t *gr = xcb_get_geometry_reply(conn, hg, NULL);
    if (!gr) return -1;
    uint16_t gw = gr->width, gh = gr->height;
    free(gr);
    if (gw == 0 || gh == 0) return -1;

    /* grab only the right end of the host where the clock lives */
    uint16_t zone = gw > 400 ? 400 : gw;
    int16_t x_off = (int16_t) (gw - zone);

    xcb_get_image_cookie_t ic = xcb_get_image_unchecked(
        conn, XCB_IMAGE_FORMAT_Z_PIXMAP, tray_host, x_off, 0,
        zone, gh, (uint32_t) ~0);
    xcb_get_image_reply_t *img = xcb_get_image_reply(conn, ic, NULL);
    if (!img) return -1;

    uint8_t *data = xcb_get_image_data(img);
    int len = xcb_get_image_data_length(img);
    int bpl = len / (gh ? gh : 1);
    int bpp = bpl / (zone ? zone : 1);
    if (bpp < 4) bpp = 4;   /* 24/32-bit depths are stored 4 bytes/px */

    uint8_t *bright = calloc(zone, sizeof(uint8_t));
    for (int y = 0; y < gh && y * bpl + (zone - 1) * bpp < len; y++)
    {
        const uint8_t *row = data + (size_t) y * bpl;
        for (int x = 0; x < zone; x++)
        {
            const uint8_t *p = row + (size_t) x * bpp;
            int b = p[0], g = p[1], r = p[2];   /* little-endian BGR(A) */
            if (r > 130 || g > 130 || b > 130) bright[x] = 1;
        }
    }

    /* rightmost cluster of bright columns → its left edge */
    int left = -1;
    int i = zone - 1;
    while (i >= 0 && !bright[i]) i--;
    if (i >= 0)
    {
        left = i;
        int gap = 0;
        for (int x = i - 1; x >= 0; x--)
        {
            if (bright[x]) { left = x; gap = 0; }
            else if (++gap > 3) break;
        }
    }

    free(bright);
    free(img);
    if (left < 0) return -1;
    return x_off + left;
}

/* host-coordinate x for a right-aligned tray of width w:
 * sits `padding` px left of the clock, else uses cfg_x as right margin. */
static uint32_t tray_right_x(int w)
{
    int cl = host_clock_left();
    if (cl >= 0 && cl > w + cfg_padding)
        return (uint32_t) (cl - w - cfg_padding);

    xcb_get_geometry_cookie_t hg = xcb_get_geometry_unchecked(conn, tray_host);
    xcb_get_geometry_reply_t *gr = xcb_get_geometry_reply(conn, hg, NULL);
    int gw = gr ? (int) gr->width : 0;
    if (gr) free(gr);
    if (gw > w + cfg_x && cfg_x >= 0)
        return (uint32_t) (gw - w - cfg_x);
    return (uint32_t) (cfg_x > 0 ? cfg_x : 0);
}

static void systray_update(void)
{
    int num_entries = emb_num_visible();
    int cols = (num_entries + cfg_rows - 1) / cfg_rows;
    /* NOTE: xcb_configure_window value order follows the mask BITS:
     *   X, Y, WIDTH, HEIGHT (mask bits 0..3). */
    uint32_t cfg[4] = { 0, 0, 0, 0 };

    int w, h;
    if (cfg_horizontal)
    {
        w = cfg_icon_size * cols + cfg_spacing * (cols - 1);
        h = cfg_icon_size * cfg_rows + cfg_spacing * (cfg_rows - 1);
    }
    else
    {
        w = cfg_icon_size * cfg_rows + cfg_spacing * (cfg_rows - 1);
        h = cfg_icon_size * cols + cfg_spacing * (cols - 1);
    }

    if (w < 0) w = 0;
    if (h < 0) h = 0;

    /* right-aligned: pin the tray next to the clock (or the host's right edge) */
    if (cfg_right && tray_host != XCB_NONE)
    {
        cfg[0] = tray_right_x(w);
        cfg[1] = (uint32_t) effective_tray_y(h);
        cfg[2] = (uint32_t) w;
        cfg[3] = (uint32_t) h;
        xcb_configure_window(conn, tray_win,
                             XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                             XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, cfg);
    }
    else
    {
        cfg[0] = (uint32_t) w;
        cfg[1] = (uint32_t) h;
        xcb_configure_window(conn, tray_win,
                             XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, cfg);
    }

    if (num_entries == 0)
    {
        xcb_unmap_window(conn, tray_win);
        xcb_flush(conn);
        return;
    }
    xcb_map_window(conn, tray_win);

    cfg[0] = cfg[1] = 0;
    cfg[2] = cfg[3] = cfg_icon_size;
    int pos = 0;
    for (int i = 0; i < embedded.len; i++)
    {
        int idx = i; /* no reverse option in this build */
        xembed_window_t *em = &embedded.tab[idx];
        if (!(em->info.flags & XEMBED_MAPPED))
        {
            xcb_unmap_window(conn, em->win);
            continue;
        }
        xcb_configure_window(conn, em->win,
                             XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                             XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
                             (uint32_t[]) { cfg[0], cfg[1], cfg_icon_size, cfg_icon_size });
        xcb_map_window(conn, em->win);

        pos++;
        if (pos % cfg_rows == 0)
        {
            if (cfg_horizontal) { cfg[0] += cfg_icon_size + cfg_spacing; cfg[1] = 0; }
            else                { cfg[0] = 0; cfg[1] += cfg_icon_size + cfg_spacing; }
        }
        else
        {
            if (cfg_horizontal) { cfg[1] += cfg_icon_size + cfg_spacing; }
            else                { cfg[0] += cfg_icon_size + cfg_spacing; }
        }
    }
    xcb_flush(conn);
}

/* ---- dock a tray icon ---- */
static int systray_request_handle(xcb_window_t embed_win)
{
    if (emb_getbywin(embed_win)) return -1;

    const uint32_t select_input[] =
    {
        XCB_EVENT_MASK_STRUCTURE_NOTIFY
            | XCB_EVENT_MASK_PROPERTY_CHANGE
            | XCB_EVENT_MASK_ENTER_WINDOW
    };

    xcb_get_property_cookie_t em_cookie = xembed_info_get_unchecked(embed_win);

    xcb_change_window_attributes(conn, embed_win, XCB_CW_EVENT_MASK, select_input);
    /* auto-reparent back to root if we die */
    xcb_change_save_set(conn, XCB_SET_MODE_INSERT, embed_win);
    xcb_reparent_window(conn, embed_win, tray_win, 0, 0);

    xembed_info_t info = { XEMBED_VERSION, XEMBED_MAPPED };
    if (!xembed_info_get_reply(em_cookie, &info))
    {
        /* sane defaults when the client sets no _XEMBED_INFO */
        info.version = XEMBED_VERSION;
        info.flags = XEMBED_MAPPED;
    }

    xembed_embedded_notify(embed_win, XEMBED_VERSION < info.version ? XEMBED_VERSION : info.version);

    emb_push(embed_win, &info);
    systray_update();
    return 0;
}

/* ---- register the tray: take ownership of the selection + MANAGER msg ---- */
static void systray_register(void)
{
    if (registered) return;
    registered = true;

    xcb_client_message_event_t ev;
    memset(&ev, 0, sizeof(ev));
    ev.response_type = XCB_CLIENT_MESSAGE;
    ev.window = screen->root;
    ev.format = 32;
    ev.type = a_manager;
    ev.data.data32[0] = XCB_CURRENT_TIME;   /* manager timestamp */
    ev.data.data32[1] = sel_tray_atom;
    ev.data.data32[2] = tray_win;
    ev.data.data32[3] = 0;
    ev.data.data32[4] = 0;

    xcb_set_selection_owner(conn, tray_win, sel_tray_atom, XCB_CURRENT_TIME);
    xcb_send_event(conn, false, screen->root, 0xFFFFFF, (char *) &ev);
    xcb_flush(conn);
}

/* ---- XEMBED client message: focus request ---- */
static void xembed_process_client_message(xcb_client_message_event_t *ev)
{
    if (ev->data.data32[1] == XEMBED_REQUEST_FOCUS)
        xembed_message_send(ev->window, XEMBED_FOCUS_IN, XEMBED_FOCUS_CURRENT, 0, 0);
}

/* ---- _NET_SYSTEM_TRAY_OPCODE message: dock request ---- */
static void systray_process_client_message(xcb_client_message_event_t *ev)
{
    if (ev->data.data32[1] == SYSTEM_TRAY_REQUEST_DOCK)
    {
        xcb_get_geometry_cookie_t geom_c = xcb_get_geometry_unchecked(conn, ev->window);
        xcb_get_geometry_reply_t *geom_r = xcb_get_geometry_reply(conn, geom_c, NULL);
        if (!geom_r) return;
        bool on_root = (screen->root == geom_r->root);
        free(geom_r);
        if (on_root)
            systray_request_handle(ev->data.data32[2]);
    }
}

/* ---- XEMBED info property changed: map/unmap the icon ---- */
static void xembed_property_update(xembed_window_t *emwin, xcb_get_property_reply_t *reply)
{
    xembed_info_t info = { 0, 0 };
    if (!xembed_info_from_reply(&info, reply)) return;

    int flags_changed = (int)(info.flags ^ emwin->info.flags);
    if (!flags_changed) return;

    emwin->info.flags = info.flags;
    if (flags_changed & XEMBED_MAPPED)
    {
        if (info.flags & XEMBED_MAPPED)
        {
            xcb_map_window(conn, emwin->win);
            xembed_message_send(emwin->win, XEMBED_WINDOW_ACTIVATE, 0, 0, 0);
        }
        else
        {
            xcb_unmap_window(conn, emwin->win);
            xembed_message_send(emwin->win, XEMBED_WINDOW_DEACTIVATE, 0, 0, 0);
            xembed_message_send(emwin->win, XEMBED_FOCUS_OUT, 0, 0, 0);
        }
        systray_update();
    }
}

/* ---- send a synthetic ConfigureNotify (deny the requested size) ---- */
static void send_synthetic_configure(xcb_window_t win)
{
    xcb_get_geometry_cookie_t gc = xcb_get_geometry_unchecked(conn, win);
    xcb_get_geometry_reply_t *g = xcb_get_geometry_reply(conn, gc, NULL);
    xcb_translate_coordinates_cookie_t tc =
        xcb_translate_coordinates_unchecked(conn, win, tray_win, 0, 0);
    xcb_translate_coordinates_reply_t *t = xcb_translate_coordinates_reply(conn, tc, NULL);
    if (!g || !t) { free(g); free(t); return; }

    xcb_configure_notify_event_t ce;
    memset(&ce, 0, sizeof(ce));
    ce.response_type = XCB_CONFIGURE_NOTIFY;
    ce.event = win;
    ce.window = win;
    ce.above_sibling = XCB_NONE;
    ce.x = t->dst_x;
    ce.y = t->dst_y;
    ce.width = g->width;
    ce.height = g->height;
    ce.border_width = g->border_width;
    ce.override_redirect = false;
    xcb_send_event(conn, false, win, XCB_EVENT_MASK_STRUCTURE_NOTIFY, (char *) &ce);
    free(g);
    free(t);
}

/* ---- event dispatching ---- */
static void handle_event(xcb_generic_event_t *ev)
{
    uint8_t type = ev->response_type & 0x7F;
    switch (type)
    {
      case XCB_CLIENT_MESSAGE:
      {
        xcb_client_message_event_t *e = (void *) ev;
        if (e->type == a_xembed)
            xembed_process_client_message(e);
        else if (e->type == a_net_system_tray_opcode)
            systray_process_client_message(e);
        break;
      }
      case XCB_CONFIGURE_REQUEST:
      {
        xcb_configure_request_event_t *e = (void *) ev;
        /* tray icons must keep their grid size: deny + synthetic notify */
        if (emb_getbywin(e->window))
            send_synthetic_configure(e->window);
        break;
      }
      case XCB_DESTROY_NOTIFY:
      {
        xcb_destroy_notify_event_t *e = (void *) ev;
        for (int i = 0; i < embedded.len; i++)
            if (embedded.tab[i].win == e->window)
            {
                emb_take(i);
                systray_update();
                break;
            }
        break;
      }
      case XCB_REPARENT_NOTIFY:
      {
        xcb_reparent_notify_event_t *e = (void *) ev;
        if (e->parent != tray_win)
            for (int i = 0; i < embedded.len; i++)
                if (embedded.tab[i].win == e->window)
                {
                    xcb_change_save_set(conn, XCB_SET_MODE_DELETE, e->window);
                    emb_take(i);
                    systray_update();
                    break;
                }
        break;
      }
      case XCB_MAP_REQUEST:
      {
        xcb_map_request_event_t *e = (void *) ev;
        xembed_window_t *em = emb_getbywin(e->window);
        if (em)
        {
            xcb_map_window(conn, e->window);
            xembed_message_send(e->window, XEMBED_WINDOW_ACTIVATE, 0, 0, 0);
            /* Qt never sets _XEMBED_INFO; simulate the MAPPED bit */
            em->info.flags |= XEMBED_MAPPED;
            systray_update();
        }
        break;
      }
      case XCB_PROPERTY_NOTIFY:
      {
        xcb_property_notify_event_t *e = (void *) ev;
        if (e->atom == a_xembed_info)
        {
            xembed_window_t *em = emb_getbywin(e->window);
            if (em)
            {
                xcb_get_property_cookie_t c =
                    xcb_get_property_unchecked(conn, false, em->win, a_xembed_info,
                                               XCB_GET_PROPERTY_TYPE_ANY, 0, 2);
                xcb_get_property_reply_t *r = xcb_get_property_reply(conn, c, NULL);
                if (r) { xembed_property_update(em, r); free(r); }
            }
        }
        break;
      }
      case XCB_SELECTION_CLEAR:
      {
        xcb_selection_clear_event_t *e = (void *) ev;
        if (e->selection == sel_tray_atom)
        {
            fprintf(stderr, "panel_systray: lost the systray selection, exiting\n");
            running = false;
        }
        break;
      }
    }
}

static void on_sigint(int sig)
{
    (void) sig;
    running = false;
}

/* ---- find a window by its WM_CLASS (e.g. the Conky panel host) ---- */
static bool window_matches_class(xcb_window_t w, const char *class_name)
{
    xcb_get_property_cookie_t pc =
        xcb_get_property(conn, false, w, XCB_ATOM_WM_CLASS,
                         XCB_GET_PROPERTY_TYPE_ANY, 0, 64);
    xcb_get_property_reply_t *pr = xcb_get_property_reply(conn, pc, NULL);
    bool match = false;
    if (pr && pr->format == 8 && xcb_get_property_value_length(pr) > 0)
    {
        char buf[256];
        int n = xcb_get_property_value_length(pr);
        if (n > (int) sizeof(buf) - 1) n = (int) sizeof(buf) - 1;
        memcpy(buf, xcb_get_property_value(pr), n);
        buf[n] = '\0';
        /* WM_CLASS is "instance\0class\0"; match the class (last part) */
        match = strstr(buf, class_name) != NULL;
    }
    free(pr);
    return match;
}

/* recursive search: the WM may reparent the Conky window into a frame */
static xcb_window_t find_window_by_class(const char *class_name)
{
    xcb_window_t found = XCB_NONE;

    xcb_query_tree_cookie_t qc = xcb_query_tree(conn, screen->root);
    xcb_query_tree_reply_t *qt = xcb_query_tree_reply(conn, qc, NULL);
    if (!qt) return XCB_NONE;

    for (int i = 0; i < qt->children_len && found == XCB_NONE; i++)
    {
        xcb_window_t w = xcb_query_tree_children(qt)[i];
        if (window_matches_class(w, class_name))
        {
            found = w;
            break;
        }
        /* the window we care about may be one level deeper (WM frame) */
        xcb_query_tree_cookie_t qc2 = xcb_query_tree(conn, w);
        xcb_query_tree_reply_t *qt2 = xcb_query_tree_reply(conn, qc2, NULL);
        if (!qt2) continue;
        for (int j = 0; j < qt2->children_len; j++)
        {
            xcb_window_t w2 = xcb_query_tree_children(qt2)[j];
            if (window_matches_class(w2, class_name))
            {
                found = w2;
                break;
            }
        }
        free(qt2);
    }
    free(qt);
    return found;
}

/* ---- config file ---- */
static bool cfg_loaded = false;

/* strip a trailing newline/comment from a config line */
static char *cfg_clean_line(char *line)
{
    char *nl = strchr(line, '\n');
    if (nl) *nl = '\0';
    char *hash = strchr(line, '#');
    if (hash) *hash = '\0';
    /* trim */
    while (*line == ' ' || *line == '\t') line++;
    char *end = line + strlen(line);
    while (end > line && (end[-1] == ' ' || end[-1] == '\t')) *--end = '\0';
    return line;
}

/* read key = value lines from a config file; CLI args override later */
static int cfg_load(const char *path)
{
    FILE *f = fopen(path, "r");
    if (!f)
    {
        fprintf(stderr, "panel_systray: config %s not found, using defaults\n", path);
        return 0;
    }

    char buf[512];
    while (fgets(buf, sizeof(buf), f))
    {
        char *line = cfg_clean_line(buf);
        if (!*line) continue;

        char key[128], val[128];
        if (sscanf(line, "%127s = %127s", key, val) < 2) continue;

        if      (!strcmp(key, "conky_class")) snprintf(cfg_conky_class, sizeof(cfg_conky_class), "%s", val);
        else if (!strcmp(key, "right"))       cfg_right = atoi(val) != 0;
        else if (!strcmp(key, "center_y"))    cfg_center_y = atoi(val) != 0;
        else if (!strcmp(key, "x"))           cfg_x = atoi(val);
        else if (!strcmp(key, "y"))           cfg_y = atoi(val);
        else if (!strcmp(key, "padding"))     cfg_padding = atoi(val);
        else if (!strcmp(key, "icon_size"))   cfg_icon_size = atoi(val);
        else if (!strcmp(key, "spacing"))     cfg_spacing = atoi(val);
        else if (!strcmp(key, "rows"))        cfg_rows = atoi(val);
        else if (!strcmp(key, "orientation")) cfg_horizontal = (val[0] == 'h');
        else
            fprintf(stderr, "panel_systray: ignoring unknown config key '%s'\n", key);
    }
    fclose(f);
    cfg_loaded = true;
    return 1;
}

/* config file next to the binary (./panel_systray.conf for absolute paths) */
static void cfg_default_path(char *out, size_t outsz, const char *argv0)
{
    const char *slash = strrchr(argv0, '/');
    if (slash)
        snprintf(out, outsz, "%.*spanel_systray.conf", (int) (slash - argv0 + 1), argv0);
    else
        snprintf(out, outsz, "panel_systray.conf");
}

int main(int argc, char **argv)
{
    const char *conky_class = NULL;

    /* 1. load the config file (default: panel_systray.conf next to binary) */
    char cfg_path[512];
    const char *conf_arg = NULL;
    for (int a = 1; a < argc - 1; a++)
        if (strcmp(argv[a], "--config") == 0) { conf_arg = argv[a + 1]; break; }
    if (conf_arg)
        cfg_load(conf_arg);
    else
    {
        cfg_default_path(cfg_path, sizeof(cfg_path), argv[0]);
        cfg_load(cfg_path);
    }
    if (cfg_conky_class[0]) conky_class = cfg_conky_class;

    /* 2. CLI options override the config file */
    int i = 1;
    while (i < argc)
    {
        if (strcmp(argv[i], "--conky-class") == 0 && i + 1 < argc)
            conky_class = argv[++i];
        else if (strcmp(argv[i], "--config") == 0 && i + 1 < argc)
            i++;
        else if (strcmp(argv[i], "--right") == 0)
            cfg_right = true;
        else if (argv[i][0] == '-')
            fprintf(stderr, "ignoring unknown option %s\n", argv[i]);
        else
            break;
        i++;
    }
    int pos_args = argc - i;
    if (pos_args > 0) cfg_x = atoi(argv[i + 0]);
    if (cfg_x < 0) { cfg_right = true; cfg_x = 0; }
    if (pos_args > 1) cfg_y = atoi(argv[i + 1]);
    if (pos_args > 2) cfg_icon_size = atoi(argv[i + 2]);
    if (pos_args > 3) cfg_spacing = atoi(argv[i + 3]);
    if (pos_args > 4) cfg_rows = atoi(argv[i + 4]);
    if (pos_args > 5) cfg_horizontal = (argv[i + 5][0] == 'h');

    int default_screen = 0;
    conn = xcb_connect(NULL, &default_screen);
    if (xcb_connection_has_error(conn))
    {
        fprintf(stderr, "panel_systray: cannot connect to X server\n");
        return 1;
    }

    const xcb_setup_t *setup = xcb_get_setup(conn);
    xcb_screen_iterator_t it = xcb_setup_roots_iterator(setup);
    for (int i = 0; i < default_screen && it.rem; i++)
        xcb_screen_next(&it);
    screen = it.data;

    /* intern atoms */
    char atom_name[64];
    snprintf(atom_name, sizeof(atom_name), "_NET_SYSTEM_TRAY_S%d", default_screen);
    sel_tray_atom = intern_atom(atom_name);
    a_net_system_tray_opcode = intern_atom("_NET_SYSTEM_TRAY_OPCODE");
    a_kde_wm_system_tray = intern_atom("_KDE_NET_WM_SYSTEM_TRAY_WINDOW_FOR");
    a_manager = intern_atom("MANAGER");
    a_xembed = intern_atom("_XEMBED");
    a_xembed_info = intern_atom("_XEMBED_INFO");

    /* create the tray window (override-redirect so the WM ignores it) */
    /* If a Conky host window was requested, become its child so the tray
     * follows the panel and sits on top of it. */
    xcb_window_t host = XCB_NONE;
    if (conky_class)
    {
        /* conky may still be starting: poll for its window up to 5s */
        for (int attempt = 0; attempt < 50; attempt++)
        {
            host = find_window_by_class(conky_class);
            if (host != XCB_NONE) break;
            usleep(100000); /* 100ms */
        }
        if (host == XCB_NONE)
            fprintf(stderr, "panel_systray: WARNING: '%s' window not found, "
                    "tray will sit on the root window\n", conky_class);
        else
            fprintf(stderr, "panel_systray: found host window 0x%x\n", host);
    }
    tray_host = host;

    tray_win = xcb_generate_id(conn);
    const uint32_t tray_mask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK | XCB_CW_OVERRIDE_REDIRECT;
    const uint32_t tray_vals[] = { 0x222427,
                                   XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT,
                                   1 };
    xcb_create_window(conn, screen->root_depth, tray_win,
                      host != XCB_NONE ? host : screen->root,
                      cfg_x, cfg_y, cfg_icon_size, cfg_icon_size, 0,
                      XCB_COPY_FROM_PARENT, screen->root_visual,
                      tray_mask, tray_vals);

    const char *title = "panel_systray";
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, tray_win,
                        XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8,
                        (uint32_t) strlen(title), title);
    /* sanity: place the window exactly where Conky draws around it */
    if (cfg_right && host != XCB_NONE)
    {
        uint32_t y = (uint32_t) cfg_y;
        if (cfg_center_y)
            y = (uint32_t) effective_tray_y(cfg_icon_size);
        xcb_configure_window(conn, tray_win,
                             XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y,
                             (uint32_t[]) { tray_right_x(cfg_icon_size), y });
    }
    else
    {
        uint32_t y = (uint32_t) cfg_y;
        if (cfg_center_y)
            y = (uint32_t) effective_tray_y(cfg_icon_size);
        xcb_configure_window(conn, tray_win,
                             XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y,
                             (uint32_t[]) { (uint32_t) cfg_x, y });
    }

    /* Subscribe to root events so dock requests (_NET_SYSTEM_TRAY_OPCODE
     * client messages, sent to root) reach us even though we are not the
     * WM. We must NOT select SUBSTRUCTURE_REDIRECT here (that would clash
     * with the running WM); STRUCTURE_NOTIFY/SUBSTRUCTURE_NOTIFY are
     * sufficient to receive the ClientMessage and follow window state. */
    {
        const uint32_t root_mask = XCB_EVENT_MASK_STRUCTURE_NOTIFY
            | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY
            | XCB_EVENT_MASK_PROPERTY_CHANGE;
        xcb_change_window_attributes(conn, screen->root, XCB_CW_EVENT_MASK, &root_mask);
    }

    xcb_map_window(conn, tray_win);
    systray_register();

    signal(SIGINT, on_sigint);
    signal(SIGTERM, on_sigint);

    fprintf(stderr, "panel_systray: tray selection owned, host=0x%x%s x=%d y=%d size=%d spacing=%d rows=%d (%s)\n",
            host, conky_class ? "" : " (root)", cfg_x, cfg_y, cfg_icon_size,
            cfg_spacing, cfg_rows,
            cfg_horizontal ? "horizontal" : "vertical");

    while (running)
    {
        xcb_generic_event_t *ev = xcb_wait_for_event(conn);
        if (!ev)
        {
            if (xcb_connection_has_error(conn))
            {
                fprintf(stderr, "panel_systray: connection error, exiting\n");
                break;
            }
            continue;
        }
        if (ev->response_type != 0)
            handle_event(ev);
        else
        {
            xcb_generic_error_t *err = (xcb_generic_error_t *) ev;
            fprintf(stderr, "panel_systray: X error opcode=%u code=%u\n",
                    err->error_code, err->major_code);
        }
        free(ev);
    }

    /* clean up: unmap, release the selection */
    xcb_unmap_window(conn, tray_win);
    xcb_set_selection_owner(conn, XCB_NONE, sel_tray_atom, XCB_CURRENT_TIME);
    xcb_destroy_window(conn, tray_win);
    xcb_flush(conn);
    xcb_disconnect(conn);
    return 0;
}