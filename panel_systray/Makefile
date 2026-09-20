CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra
PKGS    := xcb

panel_systray: panel_systray.c
	$(CC) $(CFLAGS) -o $@ $< $(shell pkg-config --cflags --libs $(PKGS))

clean:
	rm -f panel_systray

.PHONY: clean