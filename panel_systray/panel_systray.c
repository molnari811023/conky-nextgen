#define _GNU_SOURCE
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
#include <stdbool.h>
#include <stdint.h>
#include <locale.h>
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
static uint32_t cfg_bg_color = 0x1d2022; /* match panel background */

static char cfg_conky_class[256] = "";

/* the Conky window the tray is embedded in (for right-alignment) */
static xcb_window_t tray_host = XCB_NONE;
static xcb_window_t tray_toplevel = XCB_NONE;
static xcb_window_t find_window_by_class(const char *class_name);

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

/* fetch the host window's geometry in root coordinates */
static bool host_geometry(xcb_rectangle_t *out)
{
    if (tray_host == XCB_NONE) return false;
    xcb_get_geometry_cookie_t hg = xcb_get_geometry_unchecked(conn, tray_host);
    xcb_get_geometry_reply_t *gr = xcb_get_geometry_reply(conn, hg, NULL);
    if (!gr) return false;

    int root_x = gr->x, root_y = gr->y;
    xcb_translate_coordinates_cookie_t tc =
        xcb_translate_coordinates_unchecked(conn, tray_host, screen->root, 0, 0);
    xcb_translate_coordinates_reply_t *tr = xcb_translate_coordinates_reply(conn, tc, NULL);
    if (tr)
    {
        root_x = tr->dst_x;
        root_y = tr->dst_y;
        free(tr);
    }
    if (out)
    {
        out->x = root_x;
        out->y = root_y;
        out->width  = gr->width;
        out->height = gr->height;
    }
    free(gr);
    return true;
}

/* Walk ancestor chain of a window until reaching a direct child of root */
static xcb_window_t get_toplevel_ancestor(xcb_window_t win)
{
    if (win == XCB_NONE || win == screen->root)
        return XCB_NONE;

    while (win != XCB_NONE && win != screen->root)
    {
        xcb_query_tree_cookie_t c = xcb_query_tree(conn, win);
        xcb_query_tree_reply_t *r = xcb_query_tree_reply(conn, c, NULL);
        if (!r) return XCB_NONE;
        xcb_window_t parent = r->parent;
        free(r);
        if (parent == screen->root)
            return win;
        win = parent;
    }
    return XCB_NONE;
}

static void update_toplevel_ancestor(void)
{
    xcb_window_t old_top = tray_toplevel;
    tray_toplevel = (tray_host != XCB_NONE) ? get_toplevel_ancestor(tray_host) : XCB_NONE;
    if (tray_toplevel != XCB_NONE && tray_toplevel != old_top && tray_toplevel != tray_host)
    {
        const uint32_t top_mask = XCB_EVENT_MASK_STRUCTURE_NOTIFY;
        xcb_change_window_attributes(conn, tray_toplevel, XCB_CW_EVENT_MASK, &top_mask);
    }
}

/* effective tray Y offset inside the host: cfg_y normally; centered when configured */
static int effective_tray_y(int tray_h)
{
    if (!cfg_center_y || tray_host == XCB_NONE) return cfg_y;
    xcb_rectangle_t hv;
    if (!host_geometry(&hv)) return cfg_y;
    int y = ((int) hv.height - tray_h) / 2;
    if (y < 0) y = 0;
    return y;
}

/* absolute root coordinates for the tray window */
static void get_tray_position(int w, int h, int *out_x, int *out_y);

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

static void get_tray_position(int w, int h, int *out_x, int *out_y)
{
    xcb_rectangle_t hv;
    if (tray_host != XCB_NONE && host_geometry(&hv))
    {
        int x_off = cfg_right ? (int) tray_right_x(w) : cfg_x;
        int y_off = effective_tray_y(h);
        *out_x = hv.x + x_off;
        *out_y = hv.y + y_off;
    }
    else
    {
        *out_x = cfg_x;
        *out_y = cfg_y;
    }
}

static void systray_update(void)
{
    int num_entries = emb_num_visible();
    int rows = cfg_rows > 0 ? cfg_rows : 1;
    int cols = (num_entries + rows - 1) / rows;
    if (cols < 1) cols = 1;

    int w, h;
    if (cfg_horizontal)
    {
        w = cfg_icon_size * cols + cfg_spacing * (cols - 1);
        h = cfg_icon_size * rows + cfg_spacing * (rows - 1);
    }
    else
    {
        w = cfg_icon_size * rows + cfg_spacing * (rows - 1);
        h = cfg_icon_size * cols + cfg_spacing * (cols - 1);
    }

    if (w < 1) w = 1;
    if (h < 1) h = 1;

    int tx = 0, ty = 0;
    get_tray_position(w, h, &tx, &ty);
    update_toplevel_ancestor();

    uint32_t cfg[6];
    uint16_t mask = XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                    XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT;
    int idx = 0;
    cfg[idx++] = (uint32_t) tx;
    cfg[idx++] = (uint32_t) ty;
    cfg[idx++] = (uint32_t) w;
    cfg[idx++] = (uint32_t) h;
    if (tray_toplevel != XCB_NONE && tray_toplevel != screen->root)
    {
        mask |= XCB_CONFIG_WINDOW_SIBLING | XCB_CONFIG_WINDOW_STACK_MODE;
        cfg[idx++] = tray_toplevel;
        cfg[idx++] = XCB_STACK_MODE_ABOVE;
    }
    else
    {
        mask |= XCB_CONFIG_WINDOW_STACK_MODE;
        cfg[idx++] = XCB_STACK_MODE_ABOVE;
    }
    xcb_configure_window(conn, tray_win, mask, cfg);
    xcb_clear_area(conn, 0, tray_win, 0, 0, 0, 0);

    if (num_entries == 0)
    {
        xcb_unmap_window(conn, tray_win);
        xcb_flush(conn);
        return;
    }
    xcb_map_window(conn, tray_win);

    int cur_x = 0;
    int cur_y = 0;
    int pos = 0;
    for (int i = 0; i < embedded.len; i++)
    {
        int idx = i;
        xembed_window_t *em = &embedded.tab[idx];
        if (!(em->info.flags & XEMBED_MAPPED))
        {
            xcb_unmap_window(conn, em->win);
            continue;
        }
        uint32_t icon_cfg[4] = { (uint32_t) cur_x, (uint32_t) cur_y, (uint32_t) cfg_icon_size, (uint32_t) cfg_icon_size };
        xcb_configure_window(conn, em->win,
                             XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                             XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
                             icon_cfg);
        xcb_map_window(conn, em->win);

        pos++;
        if (rows == 1)
        {
            /* Strictly 1 single row */
            if (cfg_horizontal)
                cur_x += cfg_icon_size + cfg_spacing;
            else
                cur_y += cfg_icon_size + cfg_spacing;
        }
        else
        {
            if (pos % rows == 0)
            {
                if (cfg_horizontal) { cur_x += cfg_icon_size + cfg_spacing; cur_y = 0; }
                else                { cur_x = 0; cur_y += cfg_icon_size + cfg_spacing; }
            }
            else
            {
                if (cfg_horizontal) { cur_y += cfg_icon_size + cfg_spacing; }
                else                { cur_x += cfg_icon_size + cfg_spacing; }
            }
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
    const uint32_t bg_val = cfg_bg_color;
    xcb_change_window_attributes(conn, embed_win, XCB_CW_BACK_PIXEL, &bg_val);
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
        xcb_window_t dock_win = (xcb_window_t) ev->data.data32[2];
        if (dock_win != XCB_NONE)
            systray_request_handle(dock_win);
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
      case XCB_CONFIGURE_NOTIFY:
      {
        xcb_configure_notify_event_t *e = (void *) ev;
        if (tray_host == XCB_NONE && cfg_conky_class[0])
        {
            xcb_window_t h = find_window_by_class(cfg_conky_class);
            if (h != XCB_NONE)
            {
                tray_host = h;
                update_toplevel_ancestor();
                systray_update();
            }
        }
        else if ((tray_host != XCB_NONE && e->window == tray_host) ||
                 (tray_toplevel != XCB_NONE && e->window == tray_toplevel))
        {
            systray_update();
        }
        break;
      }
      case XCB_MAP_NOTIFY:
      {
        xcb_map_notify_event_t *e = (void *) ev;
        if (tray_host == XCB_NONE && cfg_conky_class[0])
        {
            xcb_window_t h = find_window_by_class(cfg_conky_class);
            if (h != XCB_NONE)
            {
                tray_host = h;
                update_toplevel_ancestor();
                systray_update();
            }
        }
        else if (tray_host != XCB_NONE && (e->window == tray_host || e->window == tray_toplevel))
        {
            systray_update();
        }
        break;
      }
      case XCB_DESTROY_NOTIFY:
      {
        xcb_destroy_notify_event_t *e = (void *) ev;
        if (tray_host != XCB_NONE && (e->window == tray_host || e->window == tray_toplevel))
        {
            fprintf(stderr, "panel_systray: host window destroyed\n");
            tray_host = XCB_NONE;
            tray_toplevel = XCB_NONE;
        }
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
        if (tray_host != XCB_NONE && e->window == tray_host)
        {
            update_toplevel_ancestor();
            systray_update();
        }
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
      case XCB_ENTER_NOTIFY:
      {
        xcb_enter_notify_event_t *e = (void *) ev;
        xembed_window_t *em = emb_getbywin(e->event);
        if (em)
        {
            xembed_message_send(em->win, XEMBED_WINDOW_ACTIVATE, 0, 0, 0);
            xembed_message_send(em->win, XEMBED_FOCUS_IN, XEMBED_FOCUS_CURRENT, 0, 0);
            xcb_flush(conn);
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
        else if (!strcmp(key, "bg_color"))
        {
            if (val[0] == '#') cfg_bg_color = (uint32_t) strtoul(val + 1, NULL, 16);
            else if (val[0] == '0' && (val[1] == 'x' || val[1] == 'X')) cfg_bg_color = (uint32_t) strtoul(val + 2, NULL, 16);
            else cfg_bg_color = (uint32_t) strtoul(val, NULL, 16);
        }
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

static int x11_systray_main(int argc, char **argv)
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
        {
            conky_class = argv[++i];
            snprintf(cfg_conky_class, sizeof(cfg_conky_class), "%s", conky_class);
        }
        else if (strcmp(argv[i], "--config") == 0 && i + 1 < argc)
            i++;
        else if (strcmp(argv[i], "--right") == 0)
            cfg_right = true;
        else if (strcmp(argv[i], "--bg-color") == 0 && i + 1 < argc)
        {
            const char *val = argv[++i];
            if (val[0] == '#') cfg_bg_color = (uint32_t) strtoul(val + 1, NULL, 16);
            else if (val[0] == '0' && (val[1] == 'x' || val[1] == 'X')) cfg_bg_color = (uint32_t) strtoul(val + 2, NULL, 16);
            else cfg_bg_color = (uint32_t) strtoul(val, NULL, 16);
        }
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

    int init_x = 0, init_y = 0;
    get_tray_position(cfg_icon_size, cfg_icon_size, &init_x, &init_y);

    tray_win = xcb_generate_id(conn);
    const uint32_t tray_mask = XCB_CW_BACK_PIXEL | XCB_CW_OVERRIDE_REDIRECT | XCB_CW_EVENT_MASK;
    const uint32_t tray_vals[] = {
        cfg_bg_color,                           /* BACK_PIXEL (bit 1) */
        1,                                      /* OVERRIDE_REDIRECT (bit 9) */
        XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT    /* EVENT_MASK (bit 11) */
    };
    xcb_create_window(conn, screen->root_depth, tray_win,
                      screen->root,
                      init_x, init_y, cfg_icon_size, cfg_icon_size, 0,
                      XCB_COPY_FROM_PARENT, screen->root_visual,
                      tray_mask, tray_vals);

    /* Enforce override-redirect explicitly */
    const uint32_t one = 1;
    xcb_change_window_attributes(conn, tray_win, XCB_CW_OVERRIDE_REDIRECT, &one);

    const char *title = "panel_systray";
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, tray_win,
                        XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8,
                        (uint32_t) strlen(title), title);

    const char *wm_class = "panel_systray\0panel_systray";
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, tray_win,
                        XCB_ATOM_WM_CLASS, XCB_ATOM_STRING, 8,
                        28, wm_class);

    /* Disable picom/compton shadow so no black/dark frame is drawn around the tray */
    uint32_t val_shadow = 0;
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, tray_win,
                        intern_atom("_COMPTON_SHADOW"),
                        XCB_ATOM_CARDINAL, 32, 1, &val_shadow);

    /* Motif WM hints: explicitly no decorations / borderless */
    uint32_t motif_hints[5] = { 2, 0, 0, 0, 0 };
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, tray_win,
                        intern_atom("_MOTIF_WM_HINTS"),
                        intern_atom("_MOTIF_WM_HINTS"), 32, 5, motif_hints);

    /* EWMH: window type DOCK so window managers don't manage it */
    xcb_atom_t a_wm_type = intern_atom("_NET_WM_WINDOW_TYPE");
    xcb_atom_t a_type_dock = intern_atom("_NET_WM_WINDOW_TYPE_DOCK");
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, tray_win,
                        a_wm_type, XCB_ATOM_ATOM, 32, 1, &a_type_dock);

    /* EWMH: exclude from Alt+Tab and taskbars */
    xcb_atom_t a_wm_state = intern_atom("_NET_WM_STATE");
    xcb_atom_t state_atoms[2] = {
        intern_atom("_NET_WM_STATE_SKIP_TASKBAR"),
        intern_atom("_NET_WM_STATE_SKIP_PAGER")
    };
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, tray_win,
                        a_wm_state, XCB_ATOM_ATOM, 32, 2, state_atoms);

    uint32_t orientation = cfg_horizontal ? 0 : 1;
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, tray_win,
                        intern_atom("_NET_SYSTEM_TRAY_ORIENTATION"),
                        XCB_ATOM_CARDINAL, 32, 1, &orientation);

    uint32_t visual_id = screen->root_visual;
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, tray_win,
                        intern_atom("_NET_SYSTEM_TRAY_VISUAL"),
                        XCB_ATOM_VISUALID, 32, 1, &visual_id);

    update_toplevel_ancestor();

    uint32_t init_cfg[6];
    uint16_t init_mask = XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                         XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT;
    int init_idx = 0;
    init_cfg[init_idx++] = (uint32_t) init_x;
    init_cfg[init_idx++] = (uint32_t) init_y;
    init_cfg[init_idx++] = (uint32_t) cfg_icon_size;
    init_cfg[init_idx++] = (uint32_t) cfg_icon_size;
    if (tray_toplevel != XCB_NONE && tray_toplevel != screen->root)
    {
        init_mask |= XCB_CONFIG_WINDOW_SIBLING | XCB_CONFIG_WINDOW_STACK_MODE;
        init_cfg[init_idx++] = tray_toplevel;
        init_cfg[init_idx++] = XCB_STACK_MODE_ABOVE;
    }
    else
    {
        init_mask |= XCB_CONFIG_WINDOW_STACK_MODE;
        init_cfg[init_idx++] = XCB_STACK_MODE_ABOVE;
    }
    xcb_configure_window(conn, tray_win, init_mask, init_cfg);

    if (host != XCB_NONE)
    {
        const uint32_t host_mask = XCB_EVENT_MASK_STRUCTURE_NOTIFY;
        xcb_change_window_attributes(conn, host, XCB_CW_EVENT_MASK, &host_mask);
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

/*
 * Conky NextGen — Universal Wayland Tasklist Daemon
 * Protocol: wlr-foreign-toplevel-management-unstable-v1
 * Author: István Molnár <molnari811023@gmail.com>
 *
 * Works across wlroots / independent Wayland compositors:
 * Sway, Hyprland, Labwc, Wayfire, River, Niri, Miracle.
 *
 * Features:
 * 1. Connects to Wayland wtl_display and binds zwlr_foreign_toplevel_manager_v1 (v3) + wtl_wl_seat.
 * 2. Tracks all open toplevel wtl_windows (title, app_id, activated, minimized, maximized, fullscreen).
 * 3. Resolves each app_id's freedesktop icon (via GDesktopAppInfo + GtkIconTheme) into a
 *    cached PNG in ${XDG_RUNTIME_DIR}/conky_wayland_tasklist/<app_id>.png for Cairo rendering.
 * 4. Atomically exports live window list to ${XDG_RUNTIME_DIR}/conky_wayland_tasklist.tsv.
 * 5. Handles click actions via Unix socket (${XDG_RUNTIME_DIR}/conky_wayland_tasklist.sock)
 *    invoked by `conky_wayland_tasklist --click <id> [button]`:
 *    - Left click (button 1):
 *      if (win->is_activated && !win->is_minimized) -> set_minimized (plus Sway scratchpad support)
 *      else -> unset_minimized + activate(handle, wtl_wl_seat)
 *    - Middle click (button 2): close(handle)
 */

/* --- Wayland Tasklist Module (wlr-foreign-toplevel-management-unstable-v1) --- */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <unistd.h>
#include <errno.h>
#include <poll.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <wayland-client.h>
#include <gio/gio.h>
#include <gio/gdesktopappinfo.h>
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

#include "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"

typedef struct {
    uint32_t id;
    struct zwlr_foreign_toplevel_handle_v1 *handle;
    char *title;
    char *app_id;
    char *icon_png;
    bool is_maximized;
    bool is_minimized;
    bool is_activated;
    bool is_fullscreen;
    bool scratchpad_minimized;
    bool closed;
} wtl_ToplevelWindow;

static struct wl_display *wtl_display = NULL;
static struct wl_registry *wtl_registry = NULL;
static struct zwlr_foreign_toplevel_manager_v1 *wtl_toplevel_manager = NULL;
static struct wl_seat *wtl_wl_seat = NULL;

static GList *wtl_windows = NULL;
static uint32_t wtl_next_window_id = 1;
static bool wtl_running = true;

static char wtl_cache_dir[512];
static char wtl_tsv_path[512];
static char wtl_sock_path[512];

static void wtl_init_paths(void) {
    const char *runtime_dir = getenv("XDG_RUNTIME_DIR");
    if (!runtime_dir || !*runtime_dir) runtime_dir = "/tmp";
    snprintf(wtl_cache_dir, sizeof(wtl_cache_dir), "%s/conky_wayland_tasklist", runtime_dir);
    snprintf(wtl_tsv_path, sizeof(wtl_tsv_path), "%s/conky_wayland_tasklist.tsv", runtime_dir);
    snprintf(wtl_sock_path, sizeof(wtl_sock_path), "%s/conky_wayland_tasklist.sock", runtime_dir);
    mkdir(wtl_cache_dir, 0755);
}

static bool wtl_is_excluded_app(const char *app_id, const char *title) {
    if (app_id && *app_id) {
        if (g_ascii_strcasecmp(app_id, "conky") == 0 ||
            g_ascii_strcasecmp(app_id, "panel_conky") == 0 ||
            g_ascii_strcasecmp(app_id, "conky_wayland_systray") == 0) {
            return true;
        }
    }
    if (title && *title) {
        if (g_ascii_strcasecmp(title, "conky_wayland_systray") == 0) {
            return true;
        }
    }
    return false;
}

static void wtl_sanitize_text(char *str) {
    if (!str) return;
    for (char *p = str; *p; p++) {
        if (*p == '\t' || *p == '\n' || *p == '\r') {
            *p = ' ';
        }
    }
}

/* Resolve app_id to a cached 24x24 PNG icon file for Conky Cairo rendering */
static GdkPixbuf *wtl_lookup_gicon_across_themes(GIcon *gicon, int icon_sz) {
    if (!gicon) return NULL;
    GtkIconTheme *default_theme = gtk_icon_theme_get_default();
    if (default_theme) {
        GtkIconInfo *info = gtk_icon_theme_lookup_by_gicon(
            default_theme, gicon, icon_sz, GTK_ICON_LOOKUP_FORCE_SIZE
        );
        if (info) {
            GdkPixbuf *pb = gtk_icon_info_load_icon(info, NULL);
            g_object_unref(info);
            if (pb) return pb;
        }
    }
    const char *extra_themes[] = { "breeze", "Adwaita", "AdwaitaLegacy", "oxygen", "hicolor", NULL };
    for (int t = 0; extra_themes[t] != NULL; t++) {
        GtkIconTheme *custom = gtk_icon_theme_new();
        gtk_icon_theme_set_custom_theme(custom, extra_themes[t]);
        GtkIconInfo *info = gtk_icon_theme_lookup_by_gicon(
            custom, gicon, icon_sz, GTK_ICON_LOOKUP_FORCE_SIZE
        );
        if (info) {
            GdkPixbuf *pb = gtk_icon_info_load_icon(info, NULL);
            g_object_unref(info);
            g_object_unref(custom);
            if (pb) return pb;
        }
        g_object_unref(custom);
    }
    return NULL;
}

static GdkPixbuf *wtl_lookup_name_across_themes(const char *icon_name, int icon_sz) {
    if (!icon_name || !*icon_name) return NULL;
    GtkIconTheme *default_theme = gtk_icon_theme_get_default();
    if (default_theme) {
        GdkPixbuf *pb = gtk_icon_theme_load_icon(
            default_theme, icon_name, icon_sz, GTK_ICON_LOOKUP_FORCE_SIZE, NULL
        );
        if (pb) return pb;
    }
    const char *extra_themes[] = { "breeze", "Adwaita", "AdwaitaLegacy", "oxygen", "hicolor", NULL };
    for (int t = 0; extra_themes[t] != NULL; t++) {
        GtkIconTheme *custom = gtk_icon_theme_new();
        gtk_icon_theme_set_custom_theme(custom, extra_themes[t]);
        GdkPixbuf *pb = gtk_icon_theme_load_icon(
            custom, icon_name, icon_sz, GTK_ICON_LOOKUP_FORCE_SIZE, NULL
        );
        g_object_unref(custom);
        if (pb) return pb;
    }
    return NULL;
}

static char *wtl_resolve_app_icon_png(const char *app_id) {
    mkdir(wtl_cache_dir, 0755);
    const char *raw_id = (app_id && *app_id) ? app_id : "application-x-executable";
    char safe_id[256];
    snprintf(safe_id, sizeof(safe_id), "%s", raw_id);
    for (size_t i = 0; safe_id[i]; i++) {
        if (safe_id[i] == '/' || safe_id[i] == ':' || safe_id[i] == ' ') {
            safe_id[i] = '_';
        }
    }

    char dest_png[1024];
    snprintf(dest_png, sizeof(dest_png), "%s/%s.png", wtl_cache_dir, safe_id);
    if (access(dest_png, R_OK) == 0) {
        return g_strdup(dest_png);
    }

    GdkPixbuf *pb = NULL;
    const int icon_sz = 24;

    if (app_id && *app_id) {
        char *lower_id = g_ascii_strdown(app_id, -1);
        const char *last_dot = strrchr(app_id, '.');
        char *short_lower = last_dot ? g_ascii_strdown(last_dot + 1, -1) : NULL;

        /* 1. Try GDesktopAppInfo (<app_id>.desktop or <lower_id>.desktop) */
        const char *desktop_candidates[4] = { app_id, lower_id, short_lower, NULL };
        for (int i = 0; i < 3 && !pb; i++) {
            if (!desktop_candidates[i]) continue;
            char desktop_name[300];
            snprintf(desktop_name, sizeof(desktop_name), "%s.desktop", desktop_candidates[i]);
            GDesktopAppInfo *app_info = g_desktop_app_info_new(desktop_name);
            if (app_info) {
                GIcon *gicon = g_app_info_get_icon(G_APP_INFO(app_info));
                if (gicon) {
                    pb = wtl_lookup_gicon_across_themes(gicon, icon_sz);
                }
                g_object_unref(app_info);
            }
        }

        /* 2. Try direct icon name lookup across themes */
        const char *icon_candidates[4] = { app_id, lower_id, short_lower, NULL };
        for (int i = 0; i < 3 && !pb; i++) {
            if (!icon_candidates[i]) continue;
            pb = wtl_lookup_name_across_themes(icon_candidates[i], icon_sz);
        }

        g_free(short_lower);
        g_free(lower_id);
    }

    /* 3. Fallback icon */
    if (!pb) {
        pb = wtl_lookup_name_across_themes("application-x-executable", icon_sz);
    }

    if (pb) {
        gdk_pixbuf_save(pb, dest_png, "png", NULL, NULL);
        g_object_unref(pb);
        return g_strdup(dest_png);
    }
    return g_strdup("");
}

static void wtl_dump_tasklist_files(void) {
    char tmp_path[560];
    snprintf(tmp_path, sizeof(tmp_path), "%s.tmp.%d", wtl_tsv_path, (int)getpid());

    FILE *f = fopen(tmp_path, "w");
    if (!f) return;

    for (GList *l = wtl_windows; l != NULL; l = l->next) {
        wtl_ToplevelWindow *win = (wtl_ToplevelWindow *)l->data;
        if (win->closed) continue;
        if (wtl_is_excluded_app(win->app_id, win->title)) continue;

        const char *state_str = "normal";
        if (win->is_minimized || win->scratchpad_minimized) {
            state_str = "minimize";
        } else if (win->is_activated) {
            state_str = "focus";
        }

        const char *app = (win->app_id && *win->app_id) ? win->app_id : "app";
        const char *icon = (win->icon_png && *win->icon_png) ? win->icon_png : "";
        const char *title = (win->title && *win->title) ? win->title : app;

        fprintf(f, "%u\t%s\t%s\t%s\t%s\n", win->id, app, state_str, icon, title);
    }

    fclose(f);
    rename(tmp_path, wtl_tsv_path);
}

/* Toplevel handle listener callbacks */
static void wtl_handle_toplevel_title(void *data, struct zwlr_foreign_toplevel_handle_v1 *handle, const char *title) {
    (void)handle;
    wtl_ToplevelWindow *win = (wtl_ToplevelWindow *)data;
    g_free(win->title);
    win->title = g_strdup(title ? title : "");
    wtl_sanitize_text(win->title);
}

static void wtl_handle_toplevel_app_id(void *data, struct zwlr_foreign_toplevel_handle_v1 *handle, const char *app_id) {
    (void)handle;
    wtl_ToplevelWindow *win = (wtl_ToplevelWindow *)data;
    g_free(win->app_id);
    win->app_id = g_strdup(app_id ? app_id : "");
    wtl_sanitize_text(win->app_id);

    g_free(win->icon_png);
    win->icon_png = wtl_resolve_app_icon_png(win->app_id);
}

static void wtl_handle_toplevel_output_enter(void *data, struct zwlr_foreign_toplevel_handle_v1 *handle, struct wl_output *output) {
    (void)data; (void)handle; (void)output;
}

static void wtl_handle_toplevel_output_leave(void *data, struct zwlr_foreign_toplevel_handle_v1 *handle, struct wl_output *output) {
    (void)data; (void)handle; (void)output;
}

static void wtl_handle_toplevel_state(void *data, struct zwlr_foreign_toplevel_handle_v1 *handle, struct wl_array *state) {
    (void)handle;
    wtl_ToplevelWindow *win = (wtl_ToplevelWindow *)data;
    win->is_maximized = false;
    win->is_minimized = false;
    win->is_activated = false;
    win->is_fullscreen = false;

    uint32_t *st;
    wl_array_for_each(st, state) {
        if (*st == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MAXIMIZED)  win->is_maximized = true;
        if (*st == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED)  win->is_minimized = true;
        if (*st == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED)  win->is_activated = true;
        if (*st == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_FULLSCREEN) win->is_fullscreen = true;
    }

    if (win->is_activated) {
        win->scratchpad_minimized = false;
    }
}

static void wtl_handle_toplevel_done(void *data, struct zwlr_foreign_toplevel_handle_v1 *handle) {
    (void)data; (void)handle;
    wtl_dump_tasklist_files();
}

static void wtl_handle_toplevel_closed(void *data, struct zwlr_foreign_toplevel_handle_v1 *handle) {
    wtl_ToplevelWindow *win = (wtl_ToplevelWindow *)data;
    win->closed = true;
    zwlr_foreign_toplevel_handle_v1_destroy(handle);
    win->handle = NULL;

    wtl_windows = g_list_remove(wtl_windows, win);
    g_free(win->title);
    g_free(win->app_id);
    g_free(win->icon_png);
    g_free(win);

    wtl_dump_tasklist_files();
}

static void wtl_handle_toplevel_parent(void *data, struct zwlr_foreign_toplevel_handle_v1 *handle,
                                   struct zwlr_foreign_toplevel_handle_v1 *parent) {
    (void)data; (void)handle; (void)parent;
}

static const struct zwlr_foreign_toplevel_handle_v1_listener wtl_toplevel_handle_listener = {
    .title        = wtl_handle_toplevel_title,
    .app_id       = wtl_handle_toplevel_app_id,
    .output_enter = wtl_handle_toplevel_output_enter,
    .output_leave = wtl_handle_toplevel_output_leave,
    .state        = wtl_handle_toplevel_state,
    .done         = wtl_handle_toplevel_done,
    .closed       = wtl_handle_toplevel_closed,
    .parent       = wtl_handle_toplevel_parent,
};

/* Toplevel manager listener callbacks */
static void wtl_handle_manager_toplevel(void *data, struct zwlr_foreign_toplevel_manager_v1 *manager,
                                    struct zwlr_foreign_toplevel_handle_v1 *toplevel) {
    (void)data; (void)manager;
    wtl_ToplevelWindow *win = g_new0(wtl_ToplevelWindow, 1);
    win->id = wtl_next_window_id++;
    win->handle = toplevel;
    win->title = g_strdup("");
    win->app_id = g_strdup("");
    win->icon_png = g_strdup("");

    wtl_windows = g_list_append(wtl_windows, win);
    zwlr_foreign_toplevel_handle_v1_add_listener(toplevel, &wtl_toplevel_handle_listener, win);
}

static void wtl_handle_manager_finished(void *data, struct zwlr_foreign_toplevel_manager_v1 *manager) {
    (void)data;
    zwlr_foreign_toplevel_manager_v1_destroy(manager);
    wtl_toplevel_manager = NULL;
}

static const struct zwlr_foreign_toplevel_manager_v1_listener wtl_toplevel_manager_listener = {
    .toplevel = wtl_handle_manager_toplevel,
    .finished = wtl_handle_manager_finished,
};

/* Registry listener */
static void wtl_handle_registry_global(void *data, struct wl_registry *reg, uint32_t name,
                                   const char *interface, uint32_t version) {
    (void)data;
    if (strcmp(interface, zwlr_foreign_toplevel_manager_v1_interface.name) == 0) {
        uint32_t bind_ver = version < 3 ? version : 3;
        wtl_toplevel_manager = wl_registry_bind(
            reg, name, &zwlr_foreign_toplevel_manager_v1_interface, bind_ver
        );
        zwlr_foreign_toplevel_manager_v1_add_listener(
            wtl_toplevel_manager, &wtl_toplevel_manager_listener, NULL
        );
    } else if (strcmp(interface, wl_seat_interface.name) == 0 && !wtl_wl_seat) {
        wtl_wl_seat = wl_registry_bind(reg, name, &wl_seat_interface, 1);
    }
}

static void wtl_handle_registry_global_remove(void *data, struct wl_registry *reg, uint32_t name) {
    (void)data; (void)reg; (void)name;
}

static const struct wl_registry_listener wtl_registry_listener = {
    .global        = wtl_handle_registry_global,
    .global_remove = wtl_handle_registry_global_remove,
};

/* Execute click command on a tracked toplevel window */
static void wtl_process_window_click(uint32_t target_id, int button) {
    wtl_ToplevelWindow *win = NULL;
    for (GList *l = wtl_windows; l != NULL; l = l->next) {
        wtl_ToplevelWindow *candidate = (wtl_ToplevelWindow *)l->data;
        if (candidate->id == target_id && !candidate->closed && candidate->handle) {
            win = candidate;
            break;
        }
    }
    if (!win) return;

    if (button == 1) {
        /* Compositor-independent hide / show (if / else) using wlr-foreign-toplevel-management-v1 */
        bool is_min = win->is_minimized || win->scratchpad_minimized;
        if (win->is_activated && !is_min) {
            /* Active and visible -> minimize (hide) */
            zwlr_foreign_toplevel_handle_v1_set_minimized(win->handle);
            wl_display_flush(wtl_display);

            /* Sway does not connect request_minimize in sway/tree/view.c; move focused window to scratchpad */
            if (getenv("SWAYSOCK")) {
                win->scratchpad_minimized = true;
                win->is_activated = false;
                if (system("swaymsg move scratchpad >/dev/null 2>&1 &") != 0) {
                    /* ignore */
                }
                wtl_dump_tasklist_files();
            }
        } else {
            /* Minimized or unfocused -> unminimize and activate (focus) */
            if (win->is_minimized) {
                zwlr_foreign_toplevel_handle_v1_unset_minimized(win->handle);
            }
            win->scratchpad_minimized = false;
            if (wtl_wl_seat) {
                /* Note: In Sway (view.c:741), activate() automatically calls root_scratchpad_show()! */
                zwlr_foreign_toplevel_handle_v1_activate(win->handle, wtl_wl_seat);
            }
            wl_display_flush(wtl_display);
            wtl_dump_tasklist_files();
        }
    } else if (button == 2) {
        /* Middle click -> close window */
        zwlr_foreign_toplevel_handle_v1_close(win->handle);
        wl_display_flush(wtl_display);
    } else if (button == 3) {
        /* Right click -> toggle maximize */
        if (win->is_maximized) {
            zwlr_foreign_toplevel_handle_v1_unset_maximized(win->handle);
        } else {
            zwlr_foreign_toplevel_handle_v1_set_maximized(win->handle);
        }
        wl_display_flush(wtl_display);
    }
}

/* Client mode: send click command to wtl_running daemon over Unix socket */
static int wtl_send_click_command(uint32_t target_id, int button) {
    wtl_init_paths();
    int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (fd < 0) return 1;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", wtl_sock_path);

    char msg[64];
    int len = snprintf(msg, sizeof(msg), "%u %d", target_id, button);
    sendto(fd, msg, (size_t)len, 0, (struct sockaddr *)&addr, sizeof(addr));
    close(fd);
    return 0;
}

static int wayland_tasklist_main(int argc, char **argv) {
    if (argc >= 3 && strcmp(argv[1], "--click") == 0) {
        uint32_t target_id = (uint32_t)strtoul(argv[2], NULL, 10);
        int button = (argc >= 4) ? atoi(argv[3]) : 1;
        return wtl_send_click_command(target_id, button);
    }

    wtl_init_paths();
    gtk_init(&argc, &argv);
    setlocale(LC_NUMERIC, "C");

    wtl_display = wl_display_connect(NULL);
    if (!wtl_display) {
        fprintf(stderr, "conky_wayland_tasklist: Failed to connect to Wayland wtl_display\n");
        return 1;
    }

    wtl_registry = wl_display_get_registry(wtl_display);
    wl_registry_add_listener(wtl_registry, &wtl_registry_listener, NULL);
    wl_display_roundtrip(wtl_display);

    if (!wtl_toplevel_manager) {
        fprintf(stderr, "conky_wayland_tasklist: Compositor does not support zwlr_foreign_toplevel_manager_v1\n");
        return 1;
    }

    /* Initial roundtrip to receive all existing wtl_windows */
    wl_display_roundtrip(wtl_display);
    wtl_dump_tasklist_files();

    /* Setup Unix datagram socket for instant click commands from Conky */
    unlink(wtl_sock_path);
    int sock_fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (sock_fd >= 0) {
        struct sockaddr_un addr;
        memset(&addr, 0, sizeof(addr));
        addr.sun_family = AF_UNIX;
        snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", wtl_sock_path);
        bind(sock_fd, (struct sockaddr *)&addr, sizeof(addr));
    }

    int wl_fd = wl_display_get_fd(wtl_display);
    struct pollfd fds[2];
    fds[0].fd = wl_fd;
    fds[0].events = POLLIN;
    fds[1].fd = sock_fd;
    fds[1].events = POLLIN;

    while (wtl_running) {
        while (wl_display_prepare_read(wtl_display) != 0) {
            wl_display_dispatch_pending(wtl_display);
        }
        wl_display_flush(wtl_display);

        int ret = poll(fds, (sock_fd >= 0) ? 2 : 1, -1);
        if (ret < 0) {
            wl_display_cancel_read(wtl_display);
            if (errno == EINTR) continue;
            break;
        }

        if (fds[0].revents & POLLIN) {
            if (wl_display_read_events(wtl_display) < 0) {
                break;
            }
            wl_display_dispatch_pending(wtl_display);
        } else {
            wl_display_cancel_read(wtl_display);
        }

        if (sock_fd >= 0 && (fds[1].revents & POLLIN)) {
            char buf[128] = {0};
            ssize_t n = recv(sock_fd, buf, sizeof(buf) - 1, 0);
            if (n > 0) {
                buf[n] = '\0';
                uint32_t tid = 0;
                int btn = 1;
                if (sscanf(buf, "%u %d", &tid, &btn) >= 1) {
                    wtl_process_window_click(tid, btn);
                }
            }
        }
    }

    if (sock_fd >= 0) close(sock_fd);
    unlink(wtl_sock_path);
    unlink(wtl_tsv_path);
    wl_display_disconnect(wtl_display);
    return 0;
}


/*
 * Conky NextGen — Native Wayland PipeWire/PulseAudio Volume Systray Applet
 * Author: István Molnár <molnari811023@gmail.com>
 *
 * A lightweight, native Wayland StatusNotifierItem + DBusMenu volume control applet
 * replacing X11-only pasystray/volumeicon and heavyweight kmix:
 * - Zero X11 dependencies (pure gio-2.0 + libdbusmenu-glib-0.4 + wpctl)
 * - Scroll wheel / touchpad scroll over icon: +/- 5% volume
 * - Middle click: toggle mute
 * - Left / Right click: native DBusMenu popup (Mute toggle, +10%, -10%, presets, mixer, quit)
 * - Live icon updates (audio-volume-high/medium/low/muted) & tooltip percentage
 */

/* --- Wayland PipeWire/PulseAudio Volume Tray Module --- */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <math.h>
#include <unistd.h>
#include <gio/gio.h>
#include <glib-unix.h>
#include <libdbusmenu-glib/server.h>
#include <libdbusmenu-glib/menuitem.h>

#define wvol_WATCHER_BUS_NAME    "org.kde.StatusNotifierWatcher"
#define wvol_WATCHER_OBJECT_PATH "/StatusNotifierWatcher"
#define wvol_WATCHER_INTERFACE   "org.kde.StatusNotifierWatcher"
#define wvol_SNI_OBJECT_PATH     "/org/conky/volume/sni"
#define wvol_MENU_OBJECT_PATH    "/org/conky/volume/menu"
#define wvol_SNI_INTERFACE       "org.kde.StatusNotifierItem"

static GDBusConnection *wvol_session_bus = NULL;
static GMainLoop *wvol_main_loop = NULL;
static DbusmenuServer *wvol_menu_server = NULL;
static DbusmenuMenuitem *wvol_mi_status = NULL;
static DbusmenuMenuitem *wvol_mi_mute = NULL;

static int wvol_current_volume = 50;
static bool wvol_current_muted = false;
static char wvol_current_icon[64] = "audio-volume-medium";
static char wvol_current_tooltip[128] = "Volume: 50%";

static const gchar wvol_sni_introspection_xml[] =
    "<node>"
    "  <interface name='org.kde.StatusNotifierItem'>"
    "    <method name='Activate'>"
    "      <arg type='i' direction='in' name='x'/>"
    "      <arg type='i' direction='in' name='y'/>"
    "    </method>"
    "    <method name='SecondaryActivate'>"
    "      <arg type='i' direction='in' name='x'/>"
    "      <arg type='i' direction='in' name='y'/>"
    "    </method>"
    "    <method name='ContextMenu'>"
    "      <arg type='i' direction='in' name='x'/>"
    "      <arg type='i' direction='in' name='y'/>"
    "    </method>"
    "    <method name='Scroll'>"
    "      <arg type='i' direction='in' name='delta'/>"
    "      <arg type='s' direction='in' name='orientation'/>"
    "    </method>"
    "    <property name='Category' type='s' access='read'/>"
    "    <property name='Id' type='s' access='read'/>"
    "    <property name='Title' type='s' access='read'/>"
    "    <property name='Status' type='s' access='read'/>"
    "    <property name='IconName' type='s' access='read'/>"
    "    <property name='Menu' type='o' access='read'/>"
    "    <property name='ItemIsMenu' type='b' access='read'/>"
    "    <property name='ToolTip' type='(sa(iiay)ss)' access='read'/>"
    "    <signal name='NewIcon'/>"
    "    <signal name='NewToolTip'/>"
    "    <signal name='NewTitle'/>"
    "    <signal name='NewStatus'>"
    "      <arg type='s' name='status'/>"
    "    </signal>"
    "  </interface>"
    "</node>";

static bool wvol_query_pipewire_volume(int *out_vol, bool *out_muted) {
    FILE *fp = popen("LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null", "r");
    if (!fp) return false;

    char buf[256] = {0};
    if (!fgets(buf, sizeof(buf), fp)) {
        pclose(fp);
        return false;
    }
    pclose(fp);

    for (char *p = buf; *p; p++) {
        if (*p == ',') *p = '.';
    }

    /* Output format: "Volume: 0.65" or "Volume: 0.65 [MUTED]" */
    double v = 0.0;
    if (sscanf(buf, "Volume: %lf", &v) == 1) {
        *out_vol = (int)lround(v * 100.0);
        if (*out_vol < 0) *out_vol = 0;
        if (*out_vol > 150) *out_vol = 150;
        *out_muted = (strstr(buf, "MUTED") != NULL);
        return true;
    }
    return false;
}

static void wvol_update_volume_state(bool force_emit) {
    int new_vol = wvol_current_volume;
    bool new_muted = wvol_current_muted;
    if (!wvol_query_pipewire_volume(&new_vol, &new_muted)) {
        return;
    }

    if (!force_emit && new_vol == wvol_current_volume && new_muted == wvol_current_muted) {
        return;
    }

    wvol_current_volume = new_vol;
    wvol_current_muted = new_muted;

    const char *icon = "audio-volume-high";
    if (wvol_current_muted || wvol_current_volume == 0) {
        icon = "audio-volume-muted";
    } else if (wvol_current_volume < 34) {
        icon = "audio-volume-low";
    } else if (wvol_current_volume < 67) {
        icon = "audio-volume-medium";
    } else {
        icon = "audio-volume-high";
    }
    snprintf(wvol_current_icon, sizeof(wvol_current_icon), "%s", icon);

    if (wvol_current_muted) {
        snprintf(wvol_current_tooltip, sizeof(wvol_current_tooltip), "Volume: Muted (%d%%)", wvol_current_volume);
    } else {
        snprintf(wvol_current_tooltip, sizeof(wvol_current_tooltip), "Volume: %d%%", wvol_current_volume);
    }

    if (wvol_mi_status) {
        dbusmenu_menuitem_property_set(wvol_mi_status, DBUSMENU_MENUITEM_PROP_LABEL, wvol_current_tooltip);
        dbusmenu_menuitem_property_set(wvol_mi_status, DBUSMENU_MENUITEM_PROP_ICON_NAME, wvol_current_icon);
    }
    if (wvol_mi_mute) {
        dbusmenu_menuitem_property_set(
            wvol_mi_mute,
            DBUSMENU_MENUITEM_PROP_LABEL,
            wvol_current_muted ? "Unmute" : "Mute"
        );
        dbusmenu_menuitem_property_set(
            wvol_mi_mute,
            DBUSMENU_MENUITEM_PROP_ICON_NAME,
            wvol_current_muted ? "audio-volume-high" : "audio-volume-muted"
        );
    }

    if (wvol_session_bus) {
        g_dbus_connection_emit_signal(wvol_session_bus, NULL, wvol_SNI_OBJECT_PATH, wvol_SNI_INTERFACE, "NewIcon", NULL, NULL);
        g_dbus_connection_emit_signal(wvol_session_bus, NULL, wvol_SNI_OBJECT_PATH, wvol_SNI_INTERFACE, "NewToolTip", NULL, NULL);
        g_dbus_connection_emit_signal(wvol_session_bus, NULL, wvol_SNI_OBJECT_PATH, wvol_SNI_INTERFACE, "NewTitle", NULL, NULL);
    }
}

static void wvol_adjust_volume_step(int delta_percent) {
    char cmd[192];
    if (delta_percent > 0) {
        snprintf(cmd, sizeof(cmd),
                 "LC_ALL=C wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null; "
                 "LC_ALL=C wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ %d%%+ 2>/dev/null",
                 delta_percent);
    } else if (delta_percent < 0) {
        snprintf(cmd, sizeof(cmd),
                 "LC_ALL=C wpctl set-volume @DEFAULT_AUDIO_SINK@ %d%%- 2>/dev/null",
                 -delta_percent);
    } else {
        return;
    }
    if (system(cmd) == 0) {
        wvol_update_volume_state(true);
    }
}

static void wvol_set_volume_exact(int percent) {
    char cmd[192];
    snprintf(cmd, sizeof(cmd),
             "LC_ALL=C wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null; "
             "LC_ALL=C wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ %d%% 2>/dev/null",
             percent);
    if (system(cmd) == 0) {
        wvol_update_volume_state(true);
    }
}

static void wvol_toggle_mute(void) {
    int cur_v = wvol_current_volume;
    bool cur_m = wvol_current_muted;
    wvol_query_pipewire_volume(&cur_v, &cur_m);
    const char *target = cur_m ? "0" : "1";
    char cmd[128];
    snprintf(cmd, sizeof(cmd), "LC_ALL=C wpctl set-mute @DEFAULT_AUDIO_SINK@ %s 2>/dev/null", target);
    if (system(cmd) == 0) {
        wvol_update_volume_state(true);
    }
}

/* Menu callbacks */
static void wvol_on_menu_mute(DbusmenuMenuitem *mi, guint timestamp, gpointer user_data) {
    (void)mi; (void)timestamp; (void)user_data;
    wvol_toggle_mute();
}

static void wvol_on_menu_step(DbusmenuMenuitem *mi, guint timestamp, gpointer user_data) {
    (void)mi; (void)timestamp;
    int step = GPOINTER_TO_INT(user_data);
    wvol_adjust_volume_step(step);
}

static void wvol_on_menu_preset(DbusmenuMenuitem *mi, guint timestamp, gpointer user_data) {
    (void)mi; (void)timestamp;
    int pct = GPOINTER_TO_INT(user_data);
    wvol_set_volume_exact(pct);
}

static void wvol_on_menu_mixer(DbusmenuMenuitem *mi, guint timestamp, gpointer user_data) {
    (void)mi; (void)timestamp; (void)user_data;
    GError *err = NULL;
    if (!g_spawn_command_line_async("pavucontrol", &err)) {
        if (err) { g_error_free(err); err = NULL; }
        if (!g_spawn_command_line_async("pavucontrol-qt", &err)) {
            if (err) { g_error_free(err); err = NULL; }
            g_spawn_command_line_async("kmix", NULL);
        }
    }
}

static void wvol_on_menu_quit(DbusmenuMenuitem *mi, guint timestamp, gpointer user_data) {
    (void)mi; (void)timestamp; (void)user_data;
    if (wvol_main_loop) g_main_loop_quit(wvol_main_loop);
}

static void wvol_build_dbus_menu(void) {
    wvol_menu_server = dbusmenu_server_new(wvol_MENU_OBJECT_PATH);
    DbusmenuMenuitem *root = dbusmenu_menuitem_new_with_id(0);

    /* 1. Current Volume Status Item (clicking toggles mute) */
    wvol_mi_status = dbusmenu_menuitem_new_with_id(1);
    dbusmenu_menuitem_property_set(wvol_mi_status, DBUSMENU_MENUITEM_PROP_LABEL, wvol_current_tooltip);
    dbusmenu_menuitem_property_set(wvol_mi_status, DBUSMENU_MENUITEM_PROP_ICON_NAME, wvol_current_icon);
    g_signal_connect(wvol_mi_status, DBUSMENU_MENUITEM_SIGNAL_ITEM_ACTIVATED, G_CALLBACK(wvol_on_menu_mute), NULL);
    dbusmenu_menuitem_child_append(root, wvol_mi_status);

    /* 2. Mute Toggle Item (standard menu item so libdbusmenu-gtk3 never echoes a feedback toggle signal) */
    wvol_mi_mute = dbusmenu_menuitem_new_with_id(2);
    dbusmenu_menuitem_property_set(
        wvol_mi_mute,
        DBUSMENU_MENUITEM_PROP_LABEL,
        wvol_current_muted ? "Unmute" : "Mute"
    );
    dbusmenu_menuitem_property_set(
        wvol_mi_mute,
        DBUSMENU_MENUITEM_PROP_ICON_NAME,
        wvol_current_muted ? "audio-volume-high" : "audio-volume-muted"
    );
    g_signal_connect(wvol_mi_mute, DBUSMENU_MENUITEM_SIGNAL_ITEM_ACTIVATED, G_CALLBACK(wvol_on_menu_mute), NULL);
    dbusmenu_menuitem_child_append(root, wvol_mi_mute);

    /* Separator */
    DbusmenuMenuitem *sep1 = dbusmenu_menuitem_new_with_id(3);
    dbusmenu_menuitem_property_set(sep1, DBUSMENU_MENUITEM_PROP_TYPE, "separator");
    dbusmenu_menuitem_child_append(root, sep1);

    /* +10% / -10% */
    DbusmenuMenuitem *mi_up = dbusmenu_menuitem_new_with_id(4);
    dbusmenu_menuitem_property_set(mi_up, DBUSMENU_MENUITEM_PROP_LABEL, "Volume +10%");
    dbusmenu_menuitem_property_set(mi_up, DBUSMENU_MENUITEM_PROP_ICON_NAME, "audio-volume-high");
    g_signal_connect(mi_up, DBUSMENU_MENUITEM_SIGNAL_ITEM_ACTIVATED, G_CALLBACK(wvol_on_menu_step), GINT_TO_POINTER(10));
    dbusmenu_menuitem_child_append(root, mi_up);

    DbusmenuMenuitem *mi_down = dbusmenu_menuitem_new_with_id(5);
    dbusmenu_menuitem_property_set(mi_down, DBUSMENU_MENUITEM_PROP_LABEL, "Volume -10%");
    dbusmenu_menuitem_property_set(mi_down, DBUSMENU_MENUITEM_PROP_ICON_NAME, "audio-volume-low");
    g_signal_connect(mi_down, DBUSMENU_MENUITEM_SIGNAL_ITEM_ACTIVATED, G_CALLBACK(wvol_on_menu_step), GINT_TO_POINTER(-10));
    dbusmenu_menuitem_child_append(root, mi_down);

    /* Separator */
    DbusmenuMenuitem *sep2 = dbusmenu_menuitem_new_with_id(6);
    dbusmenu_menuitem_property_set(sep2, DBUSMENU_MENUITEM_PROP_TYPE, "separator");
    dbusmenu_menuitem_child_append(root, sep2);

    /* Presets: 100%, 75%, 50%, 25% */
    int presets[] = { 100, 75, 50, 25 };
    for (int i = 0; i < 4; i++) {
        DbusmenuMenuitem *mi_p = dbusmenu_menuitem_new_with_id(10 + i);
        char lbl[32];
        snprintf(lbl, sizeof(lbl), "Volume: %d%%", presets[i]);
        dbusmenu_menuitem_property_set(mi_p, DBUSMENU_MENUITEM_PROP_LABEL, lbl);
        g_signal_connect(mi_p, DBUSMENU_MENUITEM_SIGNAL_ITEM_ACTIVATED, G_CALLBACK(wvol_on_menu_preset), GINT_TO_POINTER(presets[i]));
        dbusmenu_menuitem_child_append(root, mi_p);
    }

    /* Separator */
    DbusmenuMenuitem *sep3 = dbusmenu_menuitem_new_with_id(20);
    dbusmenu_menuitem_property_set(sep3, DBUSMENU_MENUITEM_PROP_TYPE, "separator");
    dbusmenu_menuitem_child_append(root, sep3);

    /* Mixer */
    DbusmenuMenuitem *mi_mixer = dbusmenu_menuitem_new_with_id(21);
    dbusmenu_menuitem_property_set(mi_mixer, DBUSMENU_MENUITEM_PROP_LABEL, "Open Audio Mixer...");
    dbusmenu_menuitem_property_set(mi_mixer, DBUSMENU_MENUITEM_PROP_ICON_NAME, "multimedia-volume-control");
    g_signal_connect(mi_mixer, DBUSMENU_MENUITEM_SIGNAL_ITEM_ACTIVATED, G_CALLBACK(wvol_on_menu_mixer), NULL);
    dbusmenu_menuitem_child_append(root, mi_mixer);

    /* Separator */
    DbusmenuMenuitem *sep4 = dbusmenu_menuitem_new_with_id(22);
    dbusmenu_menuitem_property_set(sep4, DBUSMENU_MENUITEM_PROP_TYPE, "separator");
    dbusmenu_menuitem_child_append(root, sep4);

    /* Quit */
    DbusmenuMenuitem *mi_quit = dbusmenu_menuitem_new_with_id(23);
    dbusmenu_menuitem_property_set(mi_quit, DBUSMENU_MENUITEM_PROP_LABEL, "Quit");
    dbusmenu_menuitem_property_set(mi_quit, DBUSMENU_MENUITEM_PROP_ICON_NAME, "application-exit");
    g_signal_connect(mi_quit, DBUSMENU_MENUITEM_SIGNAL_ITEM_ACTIVATED, G_CALLBACK(wvol_on_menu_quit), NULL);
    dbusmenu_menuitem_child_append(root, mi_quit);

    dbusmenu_server_set_root(wvol_menu_server, root);
}

/* SNI D-Bus handlers */
static void wvol_handle_sni_method_call(GDBusConnection *conn, const gchar *sender,
                                   const gchar *object_path, const gchar *interface_name,
                                   const gchar *method_name, GVariant *parameters,
                                   GDBusMethodInvocation *invocation, gpointer user_data) {
    (void)conn; (void)sender; (void)object_path; (void)interface_name; (void)user_data;

    if (g_strcmp0(method_name, "Scroll") == 0) {
        gint delta = 0;
        const gchar *orientation = NULL;
        g_variant_get(parameters, "(i&s)", &delta, &orientation);
        if (delta < 0) {
            wvol_adjust_volume_step(5);
        } else if (delta > 0) {
            wvol_adjust_volume_step(-5);
        }
        g_dbus_method_invocation_return_value(invocation, NULL);
    } else if (g_strcmp0(method_name, "SecondaryActivate") == 0) {
        wvol_toggle_mute();
        g_dbus_method_invocation_return_value(invocation, NULL);
    } else if (g_strcmp0(method_name, "Activate") == 0) {
        /* Return error or let ItemIsMenu=true open the popup menu on left click */
        g_dbus_method_invocation_return_error(
            invocation, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_METHOD, "Use DBusMenu"
        );
    } else if (g_strcmp0(method_name, "ContextMenu") == 0) {
        g_dbus_method_invocation_return_value(invocation, NULL);
    } else {
        g_dbus_method_invocation_return_error(
            invocation, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_METHOD, "Unknown method"
        );
    }
}

static GVariant *wvol_handle_sni_get_property(GDBusConnection *conn, const gchar *sender,
                                         const gchar *object_path, const gchar *interface_name,
                                         const gchar *property_name, GError **error, gpointer user_data) {
    (void)conn; (void)sender; (void)object_path; (void)interface_name; (void)error; (void)user_data;

    if (g_strcmp0(property_name, "Category") == 0) {
        return g_variant_new_string("Hardware");
    } else if (g_strcmp0(property_name, "Id") == 0) {
        return g_variant_new_string("conky-volume");
    } else if (g_strcmp0(property_name, "Title") == 0) {
        return g_variant_new_string(wvol_current_tooltip);
    } else if (g_strcmp0(property_name, "Status") == 0) {
        return g_variant_new_string("Active");
    } else if (g_strcmp0(property_name, "IconName") == 0) {
        return g_variant_new_string(wvol_current_icon);
    } else if (g_strcmp0(property_name, "Menu") == 0) {
        return g_variant_new_object_path(wvol_MENU_OBJECT_PATH);
    } else if (g_strcmp0(property_name, "ItemIsMenu") == 0) {
        return g_variant_new_boolean(TRUE);
    } else if (g_strcmp0(property_name, "ToolTip") == 0) {
        GVariantBuilder pix_builder;
        g_variant_builder_init(&pix_builder, G_VARIANT_TYPE("a(iiay)"));
        return g_variant_new("(sa(iiay)ss)", wvol_current_icon, &pix_builder, wvol_current_tooltip, "Scroll: +/- 5% | Middle Click: Mute");
    }
    return NULL;
}

static const GDBusInterfaceVTable wvol_sni_vtable = {
    wvol_handle_sni_method_call,
    wvol_handle_sni_get_property,
    NULL,
    { 0 }
};

static void wvol_register_with_watcher(void) {
    if (!wvol_session_bus) return;
    g_dbus_connection_call(
        wvol_session_bus,
        wvol_WATCHER_BUS_NAME,
        wvol_WATCHER_OBJECT_PATH,
        wvol_WATCHER_INTERFACE,
        "RegisterStatusNotifierItem",
        g_variant_new("(s)", wvol_SNI_OBJECT_PATH),
        NULL,
        G_DBUS_CALL_FLAGS_NONE,
        2000,
        NULL,
        NULL,
        NULL
    );
}

static void wvol_on_watcher_appeared(GDBusConnection *conn, const gchar *name, const gchar *owner, gpointer user_data) {
    (void)conn; (void)name; (void)owner; (void)user_data;
    wvol_register_with_watcher();
}

static gboolean wvol_on_poll_volume(gpointer user_data) {
    (void)user_data;
    wvol_update_volume_state(false);
    return G_SOURCE_CONTINUE;
}

static gboolean wvol_on_sigterm(gpointer user_data) {
    (void)user_data;
    if (wvol_main_loop) g_main_loop_quit(wvol_main_loop);
    return G_SOURCE_REMOVE;
}

static int wayland_volume_main(void) {
    GError *error = NULL;
    wvol_session_bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (!wvol_session_bus) {
        fprintf(stderr, "conky_wayland_volume: D-Bus error: %s\n", error ? error->message : "unknown");
        return 1;
    }

    wvol_update_volume_state(true);
    wvol_build_dbus_menu();

    GDBusNodeInfo *node = g_dbus_node_info_new_for_xml(wvol_sni_introspection_xml, NULL);
    g_dbus_connection_register_object(
        wvol_session_bus,
        wvol_SNI_OBJECT_PATH,
        node->interfaces[0],
        &wvol_sni_vtable,
        NULL,
        NULL,
        NULL
    );

    g_bus_watch_name_on_connection(
        wvol_session_bus,
        wvol_WATCHER_BUS_NAME,
        G_BUS_NAME_WATCHER_FLAGS_NONE,
        wvol_on_watcher_appeared,
        NULL,
        NULL,
        NULL
    );

    g_timeout_add(1500, wvol_on_poll_volume, NULL);
    g_unix_signal_add(SIGINT, wvol_on_sigterm, NULL);
    g_unix_signal_add(SIGTERM, wvol_on_sigterm, NULL);

    wvol_main_loop = g_main_loop_new(NULL, FALSE);
    g_main_loop_run(wvol_main_loop);
    return 0;
}


/*
 * Conky NextGen — Standalone Native Wayland Systray (SNI + DBusMenu + GTK Layer Shell)
 * Author: István Molnár <molnari811023@gmail.com>
 *
 * Architecture (modeled on Waybar's SNI + gtk-layer-shell tray):
 * 1. Owns org.kde.StatusNotifierWatcher (or acts as StatusNotifierHost if one exists).
 * 2. Anchors a transparent gtk-layer-shell surface at bottom-right over Conky's panel
 *    with exclusive_zone = -1 (so Sway does not push it above Conky's exclusive zone).
 * 3. Uses GtkEventBox per tray item (matching Waybar) so GTK's GtkButton capture-phase
 *    gesture never swallows left-click (button 1) events.
 * 4. Pre-creates DbusmenuGtkMenu upon item registration and attaches it to the item
 *    widget so asynchronous DBusMenu layout fetching completes before user right-clicks.
 * 5. Left-click (Button 1): toggles application window via DBusMenu primary toggle item
 *    for Ayatana/AppIndicator apps (e.g. Deluge "Show Deluge") and SNI Activate(x, y)
 *    for standard Qt/KDE/Electron apps.
 * 6. Right-click (Button 3): pops up the native Wayland xdg_popup GTK menu above the panel.
 * 7. Monitors item D-Bus bus names via g_bus_watch_name_on_connection so closed or
 *    killed applications disappear immediately with zero ghost icons.
 */

/* --- Wayland Systray Module (gtk-layer-shell + SNI + DBusMenu) --- */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <unistd.h>
#include <cairo/cairo.h>
#include <gio/gio.h>
#include <glib-unix.h>
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <librsvg/rsvg.h>
#include <gtk-layer-shell/gtk-layer-shell.h>
#include <libdbusmenu-gtk/menu.h>
#include <libdbusmenu-gtk/client.h>
#include <libdbusmenu-glib/client.h>
#include <libdbusmenu-glib/menuitem.h>

#define WATCHER_BUS_NAME    "org.kde.StatusNotifierWatcher"
#define WATCHER_OBJECT_PATH "/StatusNotifierWatcher"
#define WATCHER_INTERFACE   "org.kde.StatusNotifierWatcher"
#define SNI_INTERFACE       "org.kde.StatusNotifierItem"

#define TRAY_ICON_SIZE      22
#define TRAY_BUTTON_SIZE    28

static int wsni_icon_size = TRAY_ICON_SIZE;
static int wsni_spacing = 4;
static int wsni_margin_right = 70;
static int wsni_margin_bottom = 10;

static void wsni_load_config(const char *argv0) {
    char path[512];
    const char *slash = strrchr(argv0, '/');
    if (slash) snprintf(path, sizeof(path), "%.*spanel_systray.conf", (int)(slash - argv0 + 1), argv0);
    else snprintf(path, sizeof(path), "panel_systray.conf");
    FILE *f = fopen(path, "r");
    if (!f) return;
    char buf[512];
    while (fgets(buf, sizeof(buf), f)) {
        char *hash = strchr(buf, '#');
        if (hash) *hash = '\0';
        char key[128], val[128];
        if (sscanf(buf, " %127[^= \t] = %127s", key, val) == 2) {
            if (strcmp(key, "icon_size") == 0) { int s = atoi(val); if (s >= 12 && s <= 64) wsni_icon_size = s; }
            else if (strcmp(key, "spacing") == 0) { int sp = atoi(val); if (sp >= 0 && sp <= 32) wsni_spacing = sp; }
            else if (strcmp(key, "x") == 0) { int mx = atoi(val); if (mx >= 0) wsni_margin_right = mx; }
        }
    }
    fclose(f);
}

typedef struct {
    char *bus_name;
    char *object_path;
    char *service_id;       /* "<bus_name><object_path>" */
    char *menu_path;
    char *id;
    char *title;
    char *status;
    char *icon_name;
    char *icon_theme_path;
    bool item_is_menu;

    GtkWidget *event_box;
    GtkWidget *image;
    DbusmenuGtkMenu *dbus_menu;

    guint watch_id;
    guint signal_sub_id;
} TrayItem;

static GtkWidget *main_window = NULL;
static GtkWidget *tray_box = NULL;
static GList *tray_items = NULL;
static GDBusConnection *session_bus = NULL;

/* Watcher introspection XML */
static const gchar watcher_introspection_xml[] =
    "<node>"
    "  <interface name='org.kde.StatusNotifierWatcher'>"
    "    <method name='RegisterStatusNotifierItem'>"
    "      <arg type='s' direction='in' name='service'/>"
    "    </method>"
    "    <method name='RegisterStatusNotifierHost'>"
    "      <arg type='s' direction='in' name='service'/>"
    "    </method>"
    "    <property name='RegisteredStatusNotifierItems' type='as' access='read'/>"
    "    <property name='IsStatusNotifierHostRegistered' type='b' access='read'/>"
    "    <property name='ProtocolVersion' type='i' access='read'/>"
    "    <signal name='StatusNotifierItemRegistered'>"
    "      <arg type='s' name='service'/>"
    "    </signal>"
    "    <signal name='StatusNotifierItemUnregistered'>"
    "      <arg type='s' name='service'/>"
    "    </signal>"
    "    <signal name='StatusNotifierHostRegistered'/>"
    "  </interface>"
    "</node>";

static void update_window_visibility(void) {
    if (!main_window) return;
    if (g_list_length(tray_items) > 0) {
        gtk_widget_show_all(main_window);
    } else {
        gtk_widget_hide(main_window);
    }
}

/* Safely destroy a pre-created DbusmenuGtkMenu (see Waybar Item::~Item) */
static void destroy_item_menu(TrayItem *item) {
    if (!item || !item->dbus_menu) return;

    gtk_menu_popdown(GTK_MENU(item->dbus_menu));
    DbusmenuGtkClient *client = dbusmenu_gtkmenu_get_client(item->dbus_menu);
    if (client != NULL) {
        g_signal_handlers_disconnect_by_data(client, item->dbus_menu);
    }
    gtk_widget_destroy(GTK_WIDGET(item->dbus_menu));
    g_object_unref(item->dbus_menu);
    item->dbus_menu = NULL;
}

/* Pre-create DbusmenuGtkMenu as soon as Menu object path is known */
static void ensure_item_menu(TrayItem *item, bool force_recreate) {
    if (!item || !item->menu_path || !*item->menu_path) return;
    if (item->dbus_menu && !force_recreate) return;

    if (item->dbus_menu) {
        destroy_item_menu(item);
    }

    item->dbus_menu = dbusmenu_gtkmenu_new(item->bus_name, item->menu_path);
    if (item->dbus_menu) {
        g_object_ref_sink(G_OBJECT(item->dbus_menu));
        DbusmenuGtkClient *client = dbusmenu_gtkmenu_get_client(item->dbus_menu);
        if (client != NULL) {
            GtkAccelGroup *accel_group = gtk_accel_group_new();
            dbusmenu_gtkclient_set_accel_group(client, accel_group);
            g_object_unref(accel_group);
        }
        gtk_menu_attach_to_widget(GTK_MENU(item->dbus_menu), item->event_box, NULL);
    }
}

static bool item_has_menu_layout(TrayItem *item) {
    if (!item || !item->dbus_menu) return false;
    DbusmenuGtkClient *client = dbusmenu_gtkmenu_get_client(item->dbus_menu);
    if (!client) return false;
    DbusmenuMenuitem *root = dbusmenu_client_get_root(DBUSMENU_CLIENT(client));
    if (!root) return false;
    GList *children = dbusmenu_menuitem_get_children(root);
    return (children != NULL);
}

/* Extract largest ARGB32 IconPixmap from D-Bus a(iiay) and convert to GdkPixbuf */
static void free_pixbuf_buf(guchar *pixels, gpointer data) {
    (void)data;
    g_free(pixels);
}

static GdkPixbuf *extract_pixbuf_from_variant(GVariant *variant, int target_size) {
    if (!variant || !g_variant_is_of_type(variant, G_VARIANT_TYPE("a(iiay)"))) {
        return NULL;
    }

    GVariantIter iter;
    g_variant_iter_init(&iter, variant);
    gint w = 0, h = 0;
    GVariant *bytes_var = NULL;
    gint best_w = 0, best_h = 0;
    guchar *best_rgba = NULL;

    while (g_variant_iter_next(&iter, "(ii@ay)", &w, &h, &bytes_var)) {
        if (w > 0 && h > 0 && bytes_var) {
            gsize n_bytes = g_variant_get_size(bytes_var);
            if (n_bytes >= (gsize)(w * h * 4) && (w * h > best_w * best_h)) {
                const guchar *src = (const guchar *)g_variant_get_data(bytes_var);
                if (src) {
                    g_free(best_rgba);
                    best_rgba = (guchar *)g_malloc(w * h * 4);
                    for (int i = 0; i < w * h * 4; i += 4) {
                        guchar a = src[i + 0];
                        best_rgba[i + 0] = src[i + 1];
                        best_rgba[i + 1] = src[i + 2];
                        best_rgba[i + 2] = src[i + 3];
                        best_rgba[i + 3] = a;
                    }
                    best_w = w;
                    best_h = h;
                }
            }
        }
        if (bytes_var) g_variant_unref(bytes_var);
    }

    if (!best_rgba) return NULL;

    GdkPixbuf *raw = gdk_pixbuf_new_from_data(
        best_rgba, GDK_COLORSPACE_RGB, TRUE, 8,
        best_w, best_h, best_w * 4, free_pixbuf_buf, NULL
    );
    if (!raw) {
        g_free(best_rgba);
        return NULL;
    }

    if (best_w != target_size || best_h != target_size) {
        GdkPixbuf *scaled = gdk_pixbuf_scale_simple(raw, target_size, target_size, GDK_INTERP_BILINEAR);
        g_object_unref(raw);
        return scaled;
    }
    return raw;
}

static GdkPixbuf *load_svg_or_file_pixbuf(const char *path, int size) {
    if (!path || access(path, R_OK) != 0) return NULL;
    size_t len = strlen(path);
    if (len > 4 && g_ascii_strcasecmp(path + len - 4, ".svg") == 0) {
        RsvgHandle *handle = rsvg_handle_new_from_file(path, NULL);
        if (handle) {
            cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size, size);
            cairo_t *cr = cairo_create(surface);
            RsvgRectangle viewport = { 0.0, 0.0, (double)size, (double)size };
            rsvg_handle_render_document(handle, cr, &viewport, NULL);
            cairo_destroy(cr);
            g_object_unref(handle);
            GdkPixbuf *pb = gdk_pixbuf_get_from_surface(surface, 0, 0, size, size);
            cairo_surface_destroy(surface);
            if (pb) return pb;
        }
    }
    return gdk_pixbuf_new_from_file_at_scale(path, size, size, TRUE, NULL);
}

static GdkPixbuf *load_icon_pixbuf(const char *icon_name, const char *theme_path, GVariant *pixmap_var, int size) {
    GdkPixbuf *pb = NULL;

    if (icon_name && *icon_name) {
        /* 1. Direct file path */
        if (icon_name[0] == '/' && access(icon_name, R_OK) == 0) {
            pb = load_svg_or_file_pixbuf(icon_name, size);
            if (pb) return pb;
        }

        /* 2. Custom IconThemePath provided by item */
        if (theme_path && *theme_path) {
            const char *exts[] = { ".svg", ".png", NULL };
            const char *subdirs[] = {
                "",
                "/hicolor/24x24/apps",
                "/hicolor/22x22/apps",
                "/hicolor/48x48/apps",
                "/hicolor/scalable/apps",
                "/hicolor/24x24/status",
                "/hicolor/scalable/status",
                NULL
            };
            char candidate[1024];
            for (int s = 0; subdirs[s] != NULL && !pb; s++) {
                for (int e = 0; exts[e] != NULL && !pb; e++) {
                    snprintf(candidate, sizeof(candidate), "%s%s/%s%s",
                             theme_path, subdirs[s], icon_name, exts[e]);
                    if (access(candidate, R_OK) == 0) {
                        pb = load_svg_or_file_pixbuf(candidate, size);
                    }
                }
            }
            if (pb) return pb;
        }

        /* 3. Explicit breeze-dark & standard paths first (fast in-process librsvg rendering,
         *    and ensures status icons like nm-signal-100 / audio-volume-* are white-on-dark) */
        const char *priority_dirs[] = {
            "/usr/share/icons/breeze-dark/status/22",
            "/usr/share/icons/breeze-dark/status/24",
            "/usr/share/icons/breeze-dark/apps/22",
            "/usr/share/icons/breeze-dark/apps/24",
            "/usr/share/icons/breeze-dark/apps/48",
            "/usr/share/icons/breeze-dark/devices/22",
            "/usr/share/icons/breeze-dark/devices/24",
            NULL
        };
        char candidate[1024];
        for (int i = 0; priority_dirs[i] != NULL && !pb; i++) {
            snprintf(candidate, sizeof(candidate), "%s/%s.svg", priority_dirs[i], icon_name);
            if (access(candidate, R_OK) == 0) {
                pb = load_svg_or_file_pixbuf(candidate, size);
                if (pb) return pb;
            }
            snprintf(candidate, sizeof(candidate), "%s/%s.png", priority_dirs[i], icon_name);
            if (access(candidate, R_OK) == 0) {
                pb = load_svg_or_file_pixbuf(candidate, size);
                if (pb) return pb;
            }
        }

        /* 4. Default GTK Icon Theme (via lookup_icon + load_svg_or_file_pixbuf) */
        GtkIconTheme *theme = gtk_icon_theme_get_default();
        if (theme) {
            GtkIconInfo *info = gtk_icon_theme_lookup_icon(theme, icon_name, size, GTK_ICON_LOOKUP_FORCE_SIZE);
            if (info) {
                const gchar *fname = gtk_icon_info_get_filename(info);
                if (fname) {
                    pb = load_svg_or_file_pixbuf(fname, size);
                }
                if (!pb) {
                    pb = gtk_icon_info_load_icon(info, NULL);
                }
                g_object_unref(info);
                if (pb) return pb;
            }
        }

        /* 5. Fallback explicit paths */
        const char *fallback_dirs[] = {
            "/usr/share/icons/hicolor/scalable/apps",
            "/usr/share/icons/hicolor/scalable/status",
            "/usr/share/icons/hicolor/24x24/apps",
            "/usr/share/icons/hicolor/24x24/status",
            "/usr/share/icons/hicolor/22x22/apps",
            "/usr/share/icons/hicolor/22x22/status",
            "/usr/share/icons/hicolor/48x48/apps",
            "/usr/share/icons/breeze/status/24",
            "/usr/share/icons/breeze/apps/48",
            "/usr/share/pixmaps",
            NULL
        };
        for (int i = 0; fallback_dirs[i] != NULL && !pb; i++) {
            snprintf(candidate, sizeof(candidate), "%s/%s.svg", fallback_dirs[i], icon_name);
            if (access(candidate, R_OK) == 0) {
                pb = load_svg_or_file_pixbuf(candidate, size);
                if (pb) return pb;
            }
            snprintf(candidate, sizeof(candidate), "%s/%s.png", fallback_dirs[i], icon_name);
            if (access(candidate, R_OK) == 0) {
                pb = load_svg_or_file_pixbuf(candidate, size);
                if (pb) return pb;
            }
        }
    }

    /* 5. IconPixmap fallback */
    if (pixmap_var) {
        pb = extract_pixbuf_from_variant(pixmap_var, size);
        if (pb) return pb;
    }

    /* 6. Last resort fallback icon */
    GtkIconTheme *theme = gtk_icon_theme_get_default();
    if (theme) {
        pb = gtk_icon_theme_load_icon(theme, "application-x-executable", size, GTK_ICON_LOOKUP_FORCE_SIZE, NULL);
    }
    return pb;
}

/* Trigger primary toggle action in DBusMenu (used for libappindicator apps like Deluge on left-click) */
static bool trigger_dbusmenu_primary_item(TrayItem *item) {
    if (!item || !item->menu_path || !*item->menu_path) return false;

    gint target_id = 2; /* Standard libappindicator top toggle item ID (e.g. "Show Deluge") */
    if (item->dbus_menu) {
        DbusmenuGtkClient *client = dbusmenu_gtkmenu_get_client(item->dbus_menu);
        if (client) {
            DbusmenuMenuitem *root = dbusmenu_client_get_root(DBUSMENU_CLIENT(client));
            if (root) {
                GList *children = dbusmenu_menuitem_get_children(root);
                for (GList *l = children; l != NULL; l = l->next) {
                    DbusmenuMenuitem *mi = (DbusmenuMenuitem *)l->data;
                    const gchar *type = dbusmenu_menuitem_property_get(mi, DBUSMENU_MENUITEM_PROP_TYPE);
                    bool vis = !dbusmenu_menuitem_property_exist(mi, DBUSMENU_MENUITEM_PROP_VISIBLE) ||
                               dbusmenu_menuitem_property_get_bool(mi, DBUSMENU_MENUITEM_PROP_VISIBLE);
                    bool ena = !dbusmenu_menuitem_property_exist(mi, DBUSMENU_MENUITEM_PROP_ENABLED) ||
                               dbusmenu_menuitem_property_get_bool(mi, DBUSMENU_MENUITEM_PROP_ENABLED);
                    if (g_strcmp0(type, "separator") != 0 && vis && ena) {
                        target_id = dbusmenu_menuitem_get_id(mi);
                        break;
                    }
                }
            }
        }
    }

    GVariant *res = g_dbus_connection_call_sync(
        session_bus,
        item->bus_name,
        item->menu_path,
        "com.canonical.dbusmenu",
        "Event",
        g_variant_new("(isvi)", target_id, "clicked", g_variant_new_int32(0), (guint32)0),
        NULL,
        G_DBUS_CALL_FLAGS_NONE,
        1500,
        NULL,
        NULL
    );
    if (res) {
        g_variant_unref(res);
        return true;
    }
    return false;
}

static gboolean on_item_enter_notify(GtkWidget *widget, GdkEventCrossing *event, gpointer user_data) {
    (void)event;
    (void)user_data;
    gtk_widget_set_state_flags(widget, GTK_STATE_FLAG_PRELIGHT, FALSE);
    return FALSE;
}

static gboolean on_item_leave_notify(GtkWidget *widget, GdkEventCrossing *event, gpointer user_data) {
    (void)event;
    (void)user_data;
    gtk_widget_unset_state_flags(widget, GTK_STATE_FLAG_PRELIGHT);
    return FALSE;
}

static void popup_item_menu(TrayItem *item, GtkWidget *widget, GdkEventButton *event) {
    int root_x = (int)event->x_root;
    int root_y = (int)event->y_root;

    ensure_item_menu(item, false);
    if (item->dbus_menu && item_has_menu_layout(item)) {
        if (item->menu_path && *item->menu_path) {
            g_dbus_connection_call(
                session_bus,
                item->bus_name,
                item->menu_path,
                "com.canonical.dbusmenu",
                "AboutToShow",
                g_variant_new("(i)", 0),
                NULL,
                G_DBUS_CALL_FLAGS_NONE,
                500,
                NULL,
                NULL,
                NULL
            );
        }
        gtk_menu_popup_at_widget(
            GTK_MENU(item->dbus_menu),
            widget,
            GDK_GRAVITY_NORTH_WEST,
            GDK_GRAVITY_SOUTH_WEST,
            (GdkEvent *)event
        );
        return;
    }

    /* Fallback to SNI ContextMenu method */
    g_dbus_connection_call(
        session_bus,
        item->bus_name,
        item->object_path,
        SNI_INTERFACE,
        "ContextMenu",
        g_variant_new("(ii)", root_x, root_y),
        NULL,
        G_DBUS_CALL_FLAGS_NONE,
        1500,
        NULL,
        NULL,
        NULL
    );
}

static double smooth_scroll_acc_y = 0.0;
static double smooth_scroll_acc_x = 0.0;

static gboolean on_item_scroll(GtkWidget *widget, GdkEventScroll *event, gpointer user_data) {
    (void)widget;
    TrayItem *item = (TrayItem *)user_data;
    if (!item) return FALSE;

    int dx = 0, dy = 0;
    switch (event->direction) {
        case GDK_SCROLL_UP:
            dy = 120;
            break;
        case GDK_SCROLL_DOWN:
            dy = -120;
            break;
        case GDK_SCROLL_LEFT:
            dx = -120;
            break;
        case GDK_SCROLL_RIGHT:
            dx = 120;
            break;
        case GDK_SCROLL_SMOOTH:
            smooth_scroll_acc_y += event->delta_y;
            smooth_scroll_acc_x += event->delta_x;
            if (smooth_scroll_acc_y <= -0.25) {
                dy = 120;
                smooth_scroll_acc_y = 0.0;
            } else if (smooth_scroll_acc_y >= 0.25) {
                dy = -120;
                smooth_scroll_acc_y = 0.0;
            }
            if (smooth_scroll_acc_x <= -0.25) {
                dx = -120;
                smooth_scroll_acc_x = 0.0;
            } else if (smooth_scroll_acc_x >= 0.25) {
                dx = 120;
                smooth_scroll_acc_x = 0.0;
            }
            break;
        default:
            break;
    }

    if (dy != 0) {
        g_dbus_connection_call(
            session_bus,
            item->bus_name,
            item->object_path,
            SNI_INTERFACE,
            "Scroll",
            g_variant_new("(is)", dy, "vertical"),
            NULL,
            G_DBUS_CALL_FLAGS_NONE,
            1000,
            NULL,
            NULL,
            NULL
        );
        return TRUE;
    }
    if (dx != 0) {
        g_dbus_connection_call(
            session_bus,
            item->bus_name,
            item->object_path,
            SNI_INTERFACE,
            "Scroll",
            g_variant_new("(is)", dx, "horizontal"),
            NULL,
            G_DBUS_CALL_FLAGS_NONE,
            1000,
            NULL,
            NULL,
            NULL
        );
        return TRUE;
    }
    return FALSE;
}

static gboolean on_item_button_press(GtkWidget *widget, GdkEventButton *event, gpointer user_data) {
    TrayItem *item = (TrayItem *)user_data;
    if (!item || event->type != GDK_BUTTON_PRESS) return FALSE;

    int root_x = (int)event->x_root;
    int root_y = (int)event->y_root;

    /* Right click (Button 3): Always open native Wayland popup menu */
    if (event->button == 3) {
        popup_item_menu(item, widget, event);
        return TRUE;
    }

    /* Left click (Button 1):
     * 1. If ItemIsMenu is true, open the DBusMenu directly.
     * 2. Otherwise call SNI Activate(x, y) (for Qt/KDE/Electron apps like Telegram, VLC, Discord).
     * 3. If Activate returns a D-Bus error (e.g. UnknownMethod on libayatana-appindicator apps
     *    such as Deluge, nm-applet, blueman-applet), fall back to opening the DBusMenu!
     */
    if (event->button == 1) {
        if (item->item_is_menu) {
            popup_item_menu(item, widget, event);
            return TRUE;
        }

        GError *err = NULL;
        GVariant *res = g_dbus_connection_call_sync(
            session_bus,
            item->bus_name,
            item->object_path,
            SNI_INTERFACE,
            "Activate",
            g_variant_new("(ii)", root_x, root_y),
            NULL,
            G_DBUS_CALL_FLAGS_NONE,
            800,
            NULL,
            &err
        );
        if (res) {
            g_variant_unref(res);
            return TRUE;
        }
        if (err) {
            g_error_free(err);
        }

        /* Activate is not supported by this app (e.g. Deluge / Ayatana) -> open the menu! */
        popup_item_menu(item, widget, event);
        return TRUE;
    }

    /* Middle click (Button 2): Trigger primary toggle item or SecondaryActivate */
    if (event->button == 2) {
        if (trigger_dbusmenu_primary_item(item)) {
            return TRUE;
        }
        g_dbus_connection_call(
            session_bus,
            item->bus_name,
            item->object_path,
            SNI_INTERFACE,
            "SecondaryActivate",
            g_variant_new("(ii)", root_x, root_y),
            NULL,
            G_DBUS_CALL_FLAGS_NONE,
            1500,
            NULL,
            NULL,
            NULL
        );
        return TRUE;
    }

    return FALSE;
}

static void on_get_all_properties_reply(GObject *source_object, GAsyncResult *res, gpointer user_data) {
    GDBusConnection *conn = G_DBUS_CONNECTION(source_object);
    TrayItem *item = (TrayItem *)user_data;

    GError *error = NULL;
    GVariant *props = g_dbus_connection_call_finish(conn, res, &error);
    if (error) {
        g_error_free(error);
        return;
    }

    /* Verify item is still alive in tray_items list */
    if (!g_list_find(tray_items, item)) {
        g_variant_unref(props);
        return;
    }

    GVariant *dict = NULL;
    g_variant_get(props, "(@a{sv})", &dict);

    char *new_menu_path = NULL;
    char *attention_icon_name = NULL;
    char *tooltip_text = NULL;
    GVariant *pixmaps = NULL;
    GVariant *attention_pixmaps = NULL;

    g_free(item->id);              item->id = NULL;
    g_free(item->title);           item->title = NULL;
    g_free(item->status);          item->status = NULL;
    g_free(item->icon_name);       item->icon_name = NULL;
    g_free(item->icon_theme_path); item->icon_theme_path = NULL;

    GVariantIter iter;
    g_variant_iter_init(&iter, dict);
    const gchar *key;
    GVariant *val;
    while (g_variant_iter_next(&iter, "{&sv}", &key, &val)) {
        if (g_strcmp0(key, "Id") == 0 && g_variant_is_of_type(val, G_VARIANT_TYPE_STRING)) {
            item->id = g_variant_dup_string(val, NULL);
        } else if (g_strcmp0(key, "Title") == 0 && g_variant_is_of_type(val, G_VARIANT_TYPE_STRING)) {
            item->title = g_variant_dup_string(val, NULL);
        } else if (g_strcmp0(key, "Status") == 0 && g_variant_is_of_type(val, G_VARIANT_TYPE_STRING)) {
            item->status = g_variant_dup_string(val, NULL);
        } else if (g_strcmp0(key, "IconName") == 0 && g_variant_is_of_type(val, G_VARIANT_TYPE_STRING)) {
            item->icon_name = g_variant_dup_string(val, NULL);
        } else if (g_strcmp0(key, "AttentionIconName") == 0 && g_variant_is_of_type(val, G_VARIANT_TYPE_STRING)) {
            attention_icon_name = g_variant_dup_string(val, NULL);
        } else if (g_strcmp0(key, "IconThemePath") == 0 && g_variant_is_of_type(val, G_VARIANT_TYPE_STRING)) {
            item->icon_theme_path = g_variant_dup_string(val, NULL);
        } else if (g_strcmp0(key, "Menu") == 0) {
            if (g_variant_is_of_type(val, G_VARIANT_TYPE_OBJECT_PATH) ||
                g_variant_is_of_type(val, G_VARIANT_TYPE_STRING)) {
                new_menu_path = g_variant_dup_string(val, NULL);
            }
        } else if (g_strcmp0(key, "ItemIsMenu") == 0 && g_variant_is_of_type(val, G_VARIANT_TYPE_BOOLEAN)) {
            item->item_is_menu = g_variant_get_boolean(val);
        } else if (g_strcmp0(key, "IconPixmap") == 0) {
            pixmaps = g_variant_ref(val);
        } else if (g_strcmp0(key, "AttentionIconPixmap") == 0) {
            attention_pixmaps = g_variant_ref(val);
        } else if (g_strcmp0(key, "ToolTip") == 0 && g_variant_is_of_type(val, G_VARIANT_TYPE("(sa(iiay)ss)"))) {
            const gchar *tt_title = NULL;
            const gchar *tt_desc = NULL;
            g_variant_get_child(val, 2, "&s", &tt_title);
            g_variant_get_child(val, 3, "&s", &tt_desc);
            if (tt_title && *tt_title && tt_desc && *tt_desc) {
                tooltip_text = g_strdup_printf("%s\n%s", tt_title, tt_desc);
            } else if (tt_title && *tt_title) {
                tooltip_text = g_strdup(tt_title);
            } else if (tt_desc && *tt_desc) {
                tooltip_text = g_strdup(tt_desc);
            }
        }
        g_variant_unref(val);
    }
    g_variant_unref(dict);
    g_variant_unref(props);

    /* Update icon pixbuf (use AttentionIcon if Status == NeedsAttention) */
    bool needs_attention = (item->status && g_ascii_strcasecmp(item->status, "NeedsAttention") == 0);
    const char *chosen_icon = (needs_attention && attention_icon_name && *attention_icon_name)
                              ? attention_icon_name : item->icon_name;
    GVariant *chosen_pixmap = (needs_attention && attention_pixmaps)
                              ? attention_pixmaps : pixmaps;

    GdkPixbuf *pb = load_icon_pixbuf(chosen_icon, item->icon_theme_path, chosen_pixmap, wsni_icon_size);
    g_free(attention_icon_name);
    if (pixmaps) g_variant_unref(pixmaps);
    if (attention_pixmaps) g_variant_unref(attention_pixmaps);
    if (pb) {
        gtk_image_set_from_pixbuf(GTK_IMAGE(item->image), pb);
        g_object_unref(pb);
    }

    /* Update tooltip (prefer ToolTip struct, fallback to Title or Id) */
    const char *tip = (tooltip_text && *tooltip_text) ? tooltip_text
                      : ((item->title && *item->title) ? item->title : item->id);
    if (tip && *tip) {
        gtk_widget_set_tooltip_text(item->event_box, tip);
    }
    g_free(tooltip_text);

    /* Pre-create DBusMenu immediately when Menu path is discovered or changed */
    if (new_menu_path && *new_menu_path) {
        bool menu_changed = (g_strcmp0(item->menu_path, new_menu_path) != 0);
        g_free(item->menu_path);
        item->menu_path = new_menu_path;
        ensure_item_menu(item, menu_changed);
    } else {
        g_free(new_menu_path);
    }

    update_window_visibility();
}

static void refresh_item_properties(TrayItem *item) {
    if (!item || !item->bus_name) return;

    g_dbus_connection_call(
        session_bus,
        item->bus_name,
        item->object_path,
        "org.freedesktop.DBus.Properties",
        "GetAll",
        g_variant_new("(s)", SNI_INTERFACE),
        G_VARIANT_TYPE("(a{sv})"),
        G_DBUS_CALL_FLAGS_NONE,
        2000,
        NULL,
        on_get_all_properties_reply,
        item
    );
}

static void on_item_signal(GDBusConnection *conn, const gchar *sender,
                           const gchar *object_path, const gchar *interface_name,
                           const gchar *signal_name, GVariant *parameters,
                           gpointer user_data) {
    (void)conn;
    (void)sender;
    (void)object_path;
    (void)interface_name;
    (void)parameters;

    TrayItem *item = (TrayItem *)user_data;
    if (g_str_has_prefix(signal_name, "New")) {
        refresh_item_properties(item);
    }
}

static void remove_tray_item_node(TrayItem *item) {
    if (!item) return;

    tray_items = g_list_remove(tray_items, item);

    if (item->watch_id > 0) {
        g_bus_unwatch_name(item->watch_id);
        item->watch_id = 0;
    }
    if (item->signal_sub_id > 0) {
        g_dbus_connection_signal_unsubscribe(session_bus, item->signal_sub_id);
        item->signal_sub_id = 0;
    }

    if (session_bus && item->service_id) {
        g_dbus_connection_emit_signal(
            session_bus,
            NULL,
            WATCHER_OBJECT_PATH,
            WATCHER_INTERFACE,
            "StatusNotifierItemUnregistered",
            g_variant_new("(s)", item->service_id),
            NULL
        );
    }

    destroy_item_menu(item);

    if (item->event_box) {
        gtk_widget_destroy(item->event_box);
        item->event_box = NULL;
    }

    g_free(item->bus_name);
    g_free(item->object_path);
    g_free(item->service_id);
    g_free(item->menu_path);
    g_free(item->id);
    g_free(item->title);
    g_free(item->status);
    g_free(item->icon_name);
    g_free(item->icon_theme_path);
    g_free(item);

    update_window_visibility();
}

static void on_item_vanished(GDBusConnection *conn, const gchar *name, gpointer user_data) {
    (void)conn;
    (void)name;
    TrayItem *item = (TrayItem *)user_data;
    remove_tray_item_node(item);
}

static void add_tray_item(const char *service, const char *explicit_path) {
    if (!service || !*service) return;

    char bus_name[256] = {0};
    char obj_path[256] = {0};

    const char *slash = strchr(service, '/');
    if (slash && (!explicit_path || !*explicit_path)) {
        size_t bus_len = (size_t)(slash - service);
        if (bus_len >= sizeof(bus_name)) bus_len = sizeof(bus_name) - 1;
        memcpy(bus_name, service, bus_len);
        bus_name[bus_len] = '\0';
        snprintf(obj_path, sizeof(obj_path), "%s", slash);
    } else {
        snprintf(bus_name, sizeof(bus_name), "%s", service);
        snprintf(obj_path, sizeof(obj_path), "%s",
                 (explicit_path && *explicit_path) ? explicit_path : "/StatusNotifierItem");
    }

    if (!bus_name[0] || !g_dbus_is_name(bus_name) || !g_variant_is_object_path(obj_path)) {
        return;
    }

    for (GList *l = tray_items; l != NULL; l = l->next) {
        TrayItem *existing = (TrayItem *)l->data;
        if (g_strcmp0(existing->bus_name, bus_name) == 0 &&
            g_strcmp0(existing->object_path, obj_path) == 0) {
            refresh_item_properties(existing);
            return;
        }
    }

    TrayItem *item = g_new0(TrayItem, 1);
    item->bus_name = g_strdup(bus_name);
    item->object_path = g_strdup(obj_path);
    item->service_id = g_strdup_printf("%s%s", bus_name, obj_path);

    /* Use GtkEventBox (matching Waybar) so left-click (button 1) is never swallowed by GtkButton */
    item->event_box = gtk_event_box_new();
    gtk_event_box_set_visible_window(GTK_EVENT_BOX(item->event_box), TRUE);
    gtk_event_box_set_above_child(GTK_EVENT_BOX(item->event_box), TRUE);
    gtk_widget_set_size_request(item->event_box, TRAY_BUTTON_SIZE, TRAY_BUTTON_SIZE);
    gtk_widget_add_events(
        item->event_box,
        GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK |
        GDK_ENTER_NOTIFY_MASK | GDK_LEAVE_NOTIFY_MASK |
        GDK_SCROLL_MASK | GDK_SMOOTH_SCROLL_MASK
    );

    GtkStyleContext *sc = gtk_widget_get_style_context(item->event_box);
    gtk_style_context_add_class(sc, "tray-item");

    item->image = gtk_image_new();
    gtk_container_add(GTK_CONTAINER(item->event_box), item->image);

    g_signal_connect(item->event_box, "button-press-event", G_CALLBACK(on_item_button_press), item);
    g_signal_connect(item->event_box, "scroll-event", G_CALLBACK(on_item_scroll), item);
    g_signal_connect(item->event_box, "enter-notify-event", G_CALLBACK(on_item_enter_notify), item);
    g_signal_connect(item->event_box, "leave-notify-event", G_CALLBACK(on_item_leave_notify), item);

    gtk_box_pack_end(GTK_BOX(tray_box), item->event_box, FALSE, FALSE, 2);
    gtk_widget_show_all(item->event_box);

    tray_items = g_list_append(tray_items, item);

    item->watch_id = g_bus_watch_name_on_connection(
        session_bus,
        item->bus_name,
        G_BUS_NAME_WATCHER_FLAGS_NONE,
        NULL,
        on_item_vanished,
        item,
        NULL
    );

    item->signal_sub_id = g_dbus_connection_signal_subscribe(
        session_bus,
        item->bus_name,
        SNI_INTERFACE,
        NULL,
        item->object_path,
        NULL,
        G_DBUS_SIGNAL_FLAGS_NONE,
        on_item_signal,
        item,
        NULL
    );

    refresh_item_properties(item);
}

/* Watcher D-Bus method & property handlers */
static void handle_watcher_method_call(GDBusConnection *conn, const gchar *sender,
                                       const gchar *object_path, const gchar *interface_name,
                                       const gchar *method_name, GVariant *parameters,
                                       GDBusMethodInvocation *invocation, gpointer user_data) {
    (void)object_path;
    (void)interface_name;
    (void)user_data;

    if (g_strcmp0(method_name, "RegisterStatusNotifierItem") == 0) {
        const char *service = NULL;
        g_variant_get(parameters, "(&s)", &service);

        char *actual_bus = NULL;
        char *actual_path = NULL;
        if (service[0] == '/') {
            actual_bus = g_strdup(sender);
            actual_path = g_strdup(service);
        } else if (const char *slash = strchr(service, '/')) {
            actual_bus = g_strndup(service, (gsize)(slash - service));
            actual_path = g_strdup(slash);
        } else {
            actual_bus = g_strdup(service);
            actual_path = g_strdup("/StatusNotifierItem");
        }

        /* Return immediately to caller BEFORE querying properties to avoid D-Bus deadlock
         * with synchronous clients (e.g. blueman-tray call_sync) */
        g_dbus_method_invocation_return_value(invocation, NULL);
        add_tray_item(actual_bus, actual_path);

        char *combined = g_strdup_printf("%s%s", actual_bus, actual_path);
        g_dbus_connection_emit_signal(
            conn,
            NULL,
            WATCHER_OBJECT_PATH,
            WATCHER_INTERFACE,
            "StatusNotifierItemRegistered",
            g_variant_new("(s)", combined),
            NULL
        );
        g_free(combined);
        g_free(actual_bus);
        g_free(actual_path);
    } else if (g_strcmp0(method_name, "RegisterStatusNotifierHost") == 0) {
        g_dbus_method_invocation_return_value(invocation, NULL);
        g_dbus_connection_emit_signal(
            conn,
            NULL,
            WATCHER_OBJECT_PATH,
            WATCHER_INTERFACE,
            "StatusNotifierHostRegistered",
            NULL,
            NULL
        );
    } else {
        g_dbus_method_invocation_return_error(
            invocation, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_METHOD, "Unknown method"
        );
    }
}

static GVariant *handle_watcher_get_property(GDBusConnection *conn, const gchar *sender,
                                             const gchar *object_path, const gchar *interface_name,
                                             const gchar *property_name, GError **error, gpointer user_data) {
    (void)conn;
    (void)sender;
    (void)object_path;
    (void)interface_name;
    (void)error;
    (void)user_data;

    if (g_strcmp0(property_name, "RegisteredStatusNotifierItems") == 0) {
        GVariantBuilder builder;
        g_variant_builder_init(&builder, G_VARIANT_TYPE("as"));
        for (GList *l = tray_items; l != NULL; l = l->next) {
            TrayItem *item = (TrayItem *)l->data;
            g_variant_builder_add(&builder, "s", item->service_id);
        }
        return g_variant_builder_end(&builder);
    } else if (g_strcmp0(property_name, "IsStatusNotifierHostRegistered") == 0) {
        return g_variant_new_boolean(TRUE);
    } else if (g_strcmp0(property_name, "ProtocolVersion") == 0) {
        return g_variant_new_int32(0);
    }
    return NULL;
}

static const GDBusInterfaceVTable watcher_vtable = {
    handle_watcher_method_call,
    handle_watcher_get_property,
    NULL,
    { 0 }
};

/* Transparency & Cursor setup */
static gboolean on_window_draw(GtkWidget *widget, cairo_t *cr, gpointer user_data) {
    (void)widget;
    (void)user_data;
    cairo_save(cr);
    cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.0);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_paint(cr);
    cairo_restore(cr);
    return FALSE;
}

static void on_window_realize(GtkWidget *widget, gpointer user_data) {
    (void)user_data;
    GdkWindow *gdk_win = gtk_widget_get_window(widget);
    if (gdk_win) {
        GdkDisplay *display = gdk_window_get_display(gdk_win);
        GdkCursor *cursor = gdk_cursor_new_from_name(display, "default");
        if (!cursor) cursor = gdk_cursor_new_for_display(display, GDK_LEFT_PTR);
        if (cursor) {
            gdk_window_set_cursor(gdk_win, cursor);
            g_object_unref(cursor);
        }
    }
}

static void on_watcher_name_acquired(GDBusConnection *conn, const gchar *name, gpointer user_data) {
    (void)name;
    (void)user_data;
    g_dbus_connection_emit_signal(
        conn,
        NULL,
        WATCHER_OBJECT_PATH,
        WATCHER_INTERFACE,
        "StatusNotifierHostRegistered",
        NULL,
        NULL
    );
}

static void on_watcher_get_items_reply(GObject *source_object, GAsyncResult *res, gpointer user_data) {
    (void)user_data;
    GError *err = NULL;
    GVariant *ret = g_dbus_connection_call_finish(G_DBUS_CONNECTION(source_object), res, &err);
    if (!ret) {
        if (err) g_error_free(err);
        return;
    }
    GVariant *inner = NULL;
    g_variant_get(ret, "(v)", &inner);
    if (inner && g_variant_is_of_type(inner, G_VARIANT_TYPE_STRING_ARRAY)) {
        GVariantIter iter;
        g_variant_iter_init(&iter, inner);
        const gchar *service = NULL;
        while (g_variant_iter_next(&iter, "&s", &service)) {
            if (service && *service) {
                add_tray_item(service, NULL);
            }
        }
    }
    if (inner) g_variant_unref(inner);
    g_variant_unref(ret);
}

static void on_external_watcher_signal(GDBusConnection *conn, const gchar *sender,
                                       const gchar *object_path, const gchar *interface_name,
                                       const gchar *signal_name, GVariant *parameters,
                                       gpointer user_data) {
    (void)conn; (void)sender; (void)object_path; (void)interface_name; (void)user_data;
    if (g_strcmp0(signal_name, "StatusNotifierItemRegistered") == 0) {
        const gchar *service = NULL;
        g_variant_get(parameters, "(&s)", &service);
        if (service && *service) {
            add_tray_item(service, NULL);
        }
    } else if (g_strcmp0(signal_name, "StatusNotifierItemUnregistered") == 0) {
        const gchar *service = NULL;
        g_variant_get(parameters, "(&s)", &service);
        if (service && *service) {
            for (GList *l = tray_items; l != NULL; l = l->next) {
                TrayItem *it = (TrayItem *)l->data;
                if (g_strcmp0(it->service_id, service) == 0 || g_strcmp0(it->bus_name, service) == 0) {
                    remove_tray_item_node(it);
                    break;
                }
            }
        }
    }
}

static void on_external_watcher_appeared(GDBusConnection *conn, const gchar *name,
                                         const gchar *name_owner, gpointer user_data) {
    (void)name; (void)name_owner;
    const char *host_name = (const char *)user_data;
    g_dbus_connection_call(
        conn,
        WATCHER_BUS_NAME,
        WATCHER_OBJECT_PATH,
        WATCHER_INTERFACE,
        "RegisterStatusNotifierHost",
        g_variant_new("(s)", host_name ? host_name : "org.kde.StatusNotifierHost"),
        NULL,
        G_DBUS_CALL_FLAGS_NONE,
        1500,
        NULL,
        NULL,
        NULL
    );
    g_dbus_connection_call(
        conn,
        WATCHER_BUS_NAME,
        WATCHER_OBJECT_PATH,
        "org.freedesktop.DBus.Properties",
        "Get",
        g_variant_new("(ss)", WATCHER_INTERFACE, "RegisteredStatusNotifierItems"),
        G_VARIANT_TYPE("(v)"),
        G_DBUS_CALL_FLAGS_NONE,
        1500,
        NULL,
        on_watcher_get_items_reply,
        NULL
    );
}

static gboolean on_unix_signal(gpointer user_data) {
    (void)user_data;
    while (tray_items != NULL) {
        remove_tray_item_node((TrayItem *)tray_items->data);
    }
    gtk_main_quit();
    return G_SOURCE_REMOVE;
}

static int wayland_systray_main(int argc, char **argv) {
    wsni_load_config(argv[0]);
    gtk_init(&argc, &argv);
    setlocale(LC_NUMERIC, "C");

    GError *error = NULL;
    session_bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (!session_bus) {
        fprintf(stderr, "conky_wayland_systray: Failed to connect to D-Bus: %s\n",
                error ? error->message : "unknown");
        return 1;
    }

    main_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(main_window), "conky_wayland_systray");
    gtk_window_set_decorated(GTK_WINDOW(main_window), FALSE);
    gtk_widget_add_events(main_window, GDK_SCROLL_MASK | GDK_SMOOTH_SCROLL_MASK);

    /* Configure RGBA visual for full transparency over Conky's panel */
    GdkScreen *screen = gtk_widget_get_screen(main_window);
    GdkVisual *visual = gdk_screen_get_rgba_visual(screen);
    if (visual) {
        gtk_widget_set_visual(main_window, visual);
    }
    gtk_widget_set_app_paintable(main_window, TRUE);
    g_signal_connect(main_window, "draw", G_CALLBACK(on_window_draw), NULL);
    g_signal_connect(main_window, "realize", G_CALLBACK(on_window_realize), NULL);

    /* Wayland Layer Shell setup:
     * - LAYER_OVERLAY sits above Conky's LAYER_TOP panel
     * - exclusive_zone = -1 ignores Conky's 42px exclusive zone so Sway anchors us
     *   directly on top of the bottom-right corner of the Conky panel!
     */
    gtk_layer_init_for_window(GTK_WINDOW(main_window));
    gtk_layer_set_layer(GTK_WINDOW(main_window), GTK_LAYER_SHELL_LAYER_OVERLAY);
    gtk_layer_set_exclusive_zone(GTK_WINDOW(main_window), -1);
    gtk_layer_set_keyboard_mode(GTK_WINDOW(main_window), GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);
    gtk_layer_set_namespace(GTK_WINDOW(main_window), "conky-systray");

    gtk_layer_set_anchor(GTK_WINDOW(main_window), GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(main_window), GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
    gtk_layer_set_margin(GTK_WINDOW(main_window), GTK_LAYER_SHELL_EDGE_BOTTOM, wsni_margin_bottom);
    gtk_layer_set_margin(GTK_WINDOW(main_window), GTK_LAYER_SHELL_EDGE_RIGHT, wsni_margin_right);

    GtkCssProvider *css = gtk_css_provider_new();
    gtk_css_provider_load_from_data(css,
        "window { background-color: transparent; }"
        ".tray-item { background-color: transparent; border-radius: 5px; padding: 2px; }"
        ".tray-item:hover { background-color: rgba(61, 174, 233, 0.28); }",
        -1, NULL);
    gtk_style_context_add_provider_for_screen(
        screen,
        GTK_STYLE_PROVIDER(css),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION
    );
    g_object_unref(css);

    tray_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, wsni_spacing);
    gtk_container_add(GTK_CONTAINER(main_window), tray_box);

    /* Register StatusNotifierHost and StatusNotifierWatcher on D-Bus */
    static char host_name[128];
    snprintf(host_name, sizeof(host_name), "org.kde.StatusNotifierHost-%d", (int)getpid());
    g_bus_own_name_on_connection(
        session_bus, host_name, G_BUS_NAME_OWNER_FLAGS_NONE,
        NULL, NULL, NULL, NULL
    );

    GDBusNodeInfo *node = g_dbus_node_info_new_for_xml(watcher_introspection_xml, NULL);
    g_dbus_connection_register_object(
        session_bus,
        WATCHER_OBJECT_PATH,
        node->interfaces[0],
        &watcher_vtable,
        NULL,
        NULL,
        NULL
    );

    g_bus_own_name_on_connection(
        session_bus,
        WATCHER_BUS_NAME,
        G_BUS_NAME_OWNER_FLAGS_ALLOW_REPLACEMENT | G_BUS_NAME_OWNER_FLAGS_REPLACE,
        on_watcher_name_acquired,
        NULL,
        NULL,
        NULL
    );

    /* Also subscribe as a StatusNotifierHost client in case an external watcher
     * (such as kded6 / kded5) already owns org.kde.StatusNotifierWatcher */
    g_dbus_connection_signal_subscribe(
        session_bus,
        WATCHER_BUS_NAME,
        WATCHER_INTERFACE,
        NULL,
        WATCHER_OBJECT_PATH,
        NULL,
        G_DBUS_SIGNAL_FLAGS_NONE,
        on_external_watcher_signal,
        NULL,
        NULL
    );
    g_bus_watch_name_on_connection(
        session_bus,
        WATCHER_BUS_NAME,
        G_BUS_NAME_WATCHER_FLAGS_NONE,
        on_external_watcher_appeared,
        NULL,
        host_name,
        NULL
    );

    g_unix_signal_add(SIGINT, on_unix_signal, NULL);
    g_unix_signal_add(SIGTERM, on_unix_signal, NULL);

    update_window_visibility();
    gtk_main();
    return 0;
}


#include <sys/prctl.h>
#include <sys/wait.h>

/* =========================================================================
 * UNIFIED ENTRY POINT: Automatic Wayland vs X11 Dispatcher
 * ========================================================================= */
int main(int argc, char **argv)
{
    if (argc >= 3 && strcmp(argv[1], "--click") == 0) {
        return wayland_tasklist_main(argc, argv);
    }
    if (argc >= 2 && strcmp(argv[1], "--tasklist-daemon") == 0) {
        return wayland_tasklist_main(1, argv);
    }
    if (argc >= 2 && strcmp(argv[1], "--volume-daemon") == 0) {
        return wayland_volume_main();
    }

    const char *wayland_display = getenv("WAYLAND_DISPLAY");
    const char *xdg_session = getenv("XDG_SESSION_TYPE");
    bool is_wayland = (wayland_display && *wayland_display) ||
                      (xdg_session && strcmp(xdg_session, "wayland") == 0);
    bool spawn_helpers = true;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--wayland") == 0) is_wayland = true;
        else if (strcmp(argv[i], "--x11") == 0) is_wayland = false;
        else if (strcmp(argv[i], "--no-helpers") == 0) spawn_helpers = false;
    }

    if (is_wayland) {
        if (spawn_helpers) {
            pid_t tl_pid = fork();
            if (tl_pid == 0) {
                prctl(PR_SET_PDEATHSIG, SIGTERM);
                exit(wayland_tasklist_main(1, argv));
            }
            pid_t vol_pid = fork();
            if (vol_pid == 0) {
                prctl(PR_SET_PDEATHSIG, SIGTERM);
                exit(wayland_volume_main());
            }
        }
        return wayland_systray_main(argc, argv);
    } else {
        return x11_systray_main(argc, argv);
    }
}
