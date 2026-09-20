/*
 * test_dock.c — integration test for panel_systray
 *
 * 1. reads the _NET_SYSTEM_TRAY_S0 selection owner
 * 2. creates a tiny XEMBED client window
 * 3. sends SYSTEM_TRAY_REQUEST_DOCK to the root
 * 4. waits for the reparent to happen (poll)
 * 5. prints the result
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <xcb/xcb.h>

#define SYSTEM_TRAY_REQUEST_DOCK 0

static xcb_atom_t intern(xcb_connection_t *c, const char *name)
{
    xcb_intern_atom_cookie_t k = xcb_intern_atom(c, 0, strlen(name), name);
    xcb_intern_atom_reply_t *r = xcb_intern_atom_reply(c, k, NULL);
    xcb_atom_t a = r ? r->atom : XCB_ATOM_NONE;
    free(r);
    return a;
}

int main(void)
{
    int scr = 0;
    xcb_connection_t *c = xcb_connect(NULL, &scr);
    if (xcb_connection_has_error(c)) { fprintf(stderr, "no X\n"); return 1; }

    char name[64];
    snprintf(name, sizeof(name), "_NET_SYSTEM_TRAY_S%d", scr);
    xcb_atom_t tray = intern(c, name);
    xcb_atom_t xembed = intern(c, "_XEMBED");
    xcb_atom_t xembed_info = intern(c, "_XEMBED_INFO");
    xcb_atom_t opcode = intern(c, "_NET_SYSTEM_TRAY_OPCODE");

    xcb_get_selection_owner_cookie_t ok = xcb_get_selection_owner(c, tray);
    xcb_get_selection_owner_reply_t *or_ = xcb_get_selection_owner_reply(c, ok, NULL);
    xcb_window_t owner = or_ ? or_->owner : XCB_NONE;
    free(or_);
    if (owner == XCB_NONE) { fprintf(stderr, "FAIL: nincs tray tulajdonos (S%d)\n", scr); return 1; }
    printf("OK  : tray tulajdonos = 0x%x\n", owner);

    xcb_screen_t *screen = NULL;
    xcb_screen_iterator_t it = xcb_setup_roots_iterator(xcb_get_setup(c));
    for (int i = 0; i < scr && it.rem; i++) xcb_screen_next(&it);
    screen = it.data;

    xcb_window_t win = xcb_generate_id(c);
    xcb_create_window(c, screen->root_depth, win, screen->root, 0, 0, 16, 16, 0,
                      XCB_COPY_FROM_PARENT, screen->root_visual,
                      XCB_CW_BACK_PIXEL, (uint32_t[]) { screen->black_pixel });

    /* XEMBED info: version=0, flags=XEMBED_MAPPED */
    uint32_t info[2] = { 0, 1 };
    xcb_change_property(c, XCB_PROP_MODE_REPLACE, win, xembed_info, xembed_info, 32, 2, info);
    xcb_map_window(c, win);

    /* send SYSTEM_TRAY_REQUEST_DOCK via the opcode atom to root */
    xcb_client_message_event_t ev;
    memset(&ev, 0, sizeof(ev));
    ev.response_type = XCB_CLIENT_MESSAGE;
    ev.format = 32;
    ev.window = win;
    ev.type = opcode;
    ev.data.data32[0] = 0; /* timestamp */
    ev.data.data32[1] = SYSTEM_TRAY_REQUEST_DOCK;
    ev.data.data32[2] = win;
    xcb_send_event(c, 0, screen->root, 0xFFFFFF, (char *) &ev);
    xcb_flush(c);

    /* poll for reparent under <owner> up to 2s */
    xcb_window_t parent = XCB_NONE;
    for (int t = 0; t < 40; t++)
    {
        xcb_query_tree_cookie_t q = xcb_query_tree(c, win);
        xcb_query_tree_reply_t *r = xcb_query_tree_reply(c, q, NULL);
        if (r) { parent = r->parent; free(r); }
        if (parent == owner) break;
        usleep(50000);
    }

    if (parent == owner)
        printf("OK  : ablak megerkezett a tray ala (parent=0x%x)\n", parent);
    else
        printf("FAIL: ablak nem reparentelt a tray-re (parent=0x%x, vartam 0x%x)\n", parent, owner);

    xcb_disconnect(c);
    return parent == owner ? 0 : 1;
}