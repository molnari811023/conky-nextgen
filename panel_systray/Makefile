CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra
PKGS    := xcb wayland-client gio-2.0 gio-unix-2.0 gobject-2.0 glib-2.0 cairo librsvg-2.0 gtk+-3.0 gdk-pixbuf-2.0 gtk-layer-shell-0 dbusmenu-gtk3-0.4 dbusmenu-glib-0.4

PKG_CFLAGS := $(shell pkg-config --cflags $(PKGS))
PKG_LIBS   := $(shell pkg-config --libs $(PKGS)) -lm

all: panel_systray

wlr-foreign-toplevel-management-unstable-v1-client-protocol.h: wlr-foreign-toplevel-management-unstable-v1.xml
	wayland-scanner client-header $< $@

wlr-foreign-toplevel-management-unstable-v1-protocol.c: wlr-foreign-toplevel-management-unstable-v1.xml
	wayland-scanner private-code $< $@

panel_systray: panel_systray.c wlr-foreign-toplevel-management-unstable-v1-protocol.c wlr-foreign-toplevel-management-unstable-v1-client-protocol.h
	$(CC) $(CFLAGS) $(PKG_CFLAGS) -o $@ panel_systray.c wlr-foreign-toplevel-management-unstable-v1-protocol.c $(PKG_LIBS)

clean:
	rm -f panel_systray

.PHONY: all clean
