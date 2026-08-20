"""Custom color picker button with screen eyedropper support."""
import os
import re
import subprocess

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, GObject

from utils import WORK_DIR

try:
    from PIL import Image as _PILImage
    _PIL_OK = True
except Exception:
    _PILImage = None
    _PIL_OK = False


class ColorPickButton(Gtk.Button):
    """Gtk.ColorButton-compatible swatch button with an on-screen eyedropper.

    Opens a color chooser dialog with a "Pick color from screen…" button
    to sample a color from the screen (KWin ColorPicker / spectacle overlay).

    API: set_rgba()/get_rgba() + "color-set" signal, same as Gtk.ColorButton.
    """

    __gsignals__ = {
        "color-set": (GObject.SignalFlags.RUN_LAST, None, ()),
    }

    def __init__(self):
        super().__init__()
        self._rgba_val = Gdk.RGBA(red=1.0, green=1.0, blue=1.0, alpha=1.0)
        self.set_size_request(48, 26)
        self.set_relief(Gtk.ReliefStyle.NONE)
        self.set_tooltip_text("Color picker (in the dialog: pick a color from the screen)")
        self.connect("draw", self._draw_swatch)
        self.connect("clicked", self._open_chooser)

    def get_rgba(self):
        return self._rgba_val

    def set_rgba(self, rgba):
        self._rgba_val = rgba
        self.queue_draw()

    def _draw_swatch(self, w, cr):
        aw, ah = w.get_allocated_width(), w.get_allocated_height()
        r = self._rgba_val
        cr.set_source_rgba(r.red, r.green, r.blue, r.alpha)
        cr.rectangle(1, 1, aw - 2, ah - 2)
        cr.fill()
        cr.set_source_rgba(0.4, 0.4, 0.4, 1.0)
        cr.rectangle(0.5, 0.5, aw - 1, ah - 1)
        cr.set_line_width(1)
        cr.stroke()
        return False

    def _open_chooser(self, *a):
        dialog = Gtk.ColorChooserDialog(
            title="Select Color",
            transient_for=self.get_toplevel(),
        )
        dialog.set_use_alpha(False)
        dialog.set_rgba(self._rgba_val)
        self._hide_builtin_picker(dialog)
        if _PIL_OK:
            pick = Gtk.Button(label="Pick color from screen…")
            pick.set_tooltip_text("Click a pixel on the screen")
            pick.connect("clicked", self._on_pick_screen, dialog)
            dialog.get_content_area().pack_start(pick, False, False, 0)
        dialog.show_all()
        resp = dialog.run()
        if resp == Gtk.ResponseType.OK:
            self._rgba_val = dialog.get_rgba()
            self.queue_draw()
            self.emit("color-set")
        dialog.destroy()

    @staticmethod
    def _hide_builtin_picker(widget):
        """Hide the built-in eyedropper button of the GTK color chooser
        (in GtkColorEditor), which doesn't work on Wayland."""
        if isinstance(widget, Gtk.Button):
            child = widget.get_child()
            if isinstance(child, Gtk.Image):
                icon = child.get_icon_name()
                name = icon[0] if isinstance(icon, tuple) else None
                if name and ("color-picker" in name or "color-select" in name):
                    widget.set_no_show_all(True)
                    widget.hide()
        try:
            for c in widget.get_children():
                ColorPickButton._hide_builtin_picker(c)
        except Exception:
            pass

    @staticmethod
    def _grab_screen():
        path = os.path.join(WORK_DIR, "eyedrop.png")
        for cmd in (
            ["spectacle", "-b", "-n", "-o", path, "--current"],
            ["import", "-window", "root", path],
        ):
            try:
                subprocess.run(cmd, timeout=15, check=True,
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL)
            except Exception:
                continue
            if os.path.exists(path) and os.path.getsize(path) > 0:
                return path
        return None

    def _on_pick_screen(self, btn, chooser):
        res = self._on_pick_screen_raw()
        if isinstance(res, Gdk.RGBA):
            chooser.set_rgba(res)
            chooser.response(Gtk.ResponseType.OK)
        elif res is None:
            self._pick_overlay(
                lambda c: (chooser.set_rgba(c),
                           chooser.response(Gtk.ResponseType.OK)))

    def _on_pick_screen_raw(self):
        """Screen color sampling: returns RGBA, or None (fallback needed),
        or False (the user cancelled)."""
        try:
            res = self._pick_kwin()
        except Exception as e:
            print("PICKER: kwin exception:", repr(e), file=__import__('sys').stderr)
            res = "unavailable"
        print("PICKER: kwin res =", res, file=__import__('sys').stderr)
        if isinstance(res, Gdk.RGBA):
            return res
        if res == "unavailable":
            return None
        return False

    def _pick_kwin(self):
        """KWin's built-in color picker (Wayland-native, compositor-side)."""
        try:
            out = subprocess.run(
                ["gdbus", "call", "--session",
                 "--dest", "org.kde.KWin.ScreenShot2",
                 "--object-path", "/ColorPicker",
                 "--method", "org.kde.kwin.ColorPicker.pick"],
                timeout=300, capture_output=True, text=True)
        except subprocess.TimeoutExpired:
            return "cancelled"
        except Exception:
            return "unavailable"
        if out.returncode != 0:
            err = out.stdout + out.stderr
            if "ServiceUnknown" in err:
                return "unavailable"
            return "cancelled"
        m = re.search(r"uint32 (\d+)", out.stdout)
        if not m:
            return "cancelled"
        v = int(m.group(1))
        r = (v >> 16) & 0xFF
        g = (v >> 8) & 0xFF
        b = v & 0xFF
        return Gdk.RGBA(r / 255, g / 255, b / 255, 1.0)

    def _pick_overlay(self, on_result):
        path = self._grab_screen()
        if not path:
            return
        try:
            img = _PILImage.open(path).convert("RGB")
        except Exception:
            return
        w, h = img.size
        data = img.tobytes()

        mask = (Gdk.EventMask.POINTER_MOTION_MASK |
                Gdk.EventMask.BUTTON_PRESS_MASK |
                Gdk.EventMask.BUTTON_RELEASE_MASK |
                Gdk.EventMask.KEY_PRESS_MASK)

        picker = Gtk.Window(type=Gtk.WindowType.POPUP)
        picker.set_title("Click a color on the screen (Esc: cancel)")
        picker.set_decorated(False)
        picker.set_can_focus(True)
        picker.set_accept_focus(True)
        picker.set_events(mask)
        disp = Gtk.DrawingArea()
        disp.set_events(mask)
        disp.set_hexpand(True)
        disp.set_vexpand(True)
        disp.set_halign(Gtk.Align.FILL)
        disp.set_valign(Gtk.Align.FILL)
        picker.add(disp)

        pb = GdkPixbuf.Pixbuf.new_from_bytes(
            GLib.Bytes(data), GdkPixbuf.Colorspace.RGB, False, 8, w, h, w * 3)

        magnifier = Gtk.Window(type=Gtk.WindowType.POPUP)
        magnifier.set_decorated(False)
        mag_img = Gtk.Image()
        magnifier.add(mag_img)
        mag_sz, zoom = 120, 6
        magnifier.set_default_size(mag_sz, mag_sz)

        state = {"ox": 0, "oy": 0, "pb": None, "scale": 1.0}

        def on_draw(area, cr):
            cr.set_source_rgba(0, 0, 0, 1)
            cr.paint()
            s = state["pb"]
            if s is not None:
                ox = (area.get_allocated_width() - s.get_width()) // 2
                oy = (area.get_allocated_height() - s.get_height()) // 2
                state["ox"], state["oy"] = ox, oy
                Gdk.cairo_set_source_pixbuf(cr, s, ox, oy)
                cr.paint()
            return False

        def mag_at(ix, iy):
            if ix < 0 or iy < 0 or ix >= w or iy >= h:
                magnifier.hide()
                return
            half = mag_sz // zoom // 2
            sx = max(0, min(w - mag_sz // zoom, ix - half))
            sy = max(0, min(h - mag_sz // zoom, iy - half))
            crop = pb.new_subpixbuf(sx, sy, mag_sz // zoom, mag_sz // zoom)
            z = crop.scale_simple(mag_sz, mag_sz,
                                  GdkPixbuf.InterpType.NEAREST)
            pixels = bytearray(z.get_pixels())
            rowstride = z.get_rowstride()
            nch = 4 if z.get_has_alpha() else 3
            for i in range(mag_sz):
                off = rowstride * (mag_sz // 2) + i * nch
                for c in range(nch):
                    pixels[off + c] = min(255, pixels[off + c] + 90)
                off = rowstride * i + (mag_sz // 2) * nch
                for c in range(nch):
                    pixels[off + c] = min(255, pixels[off + c] + 90)
            zc = GdkPixbuf.Pixbuf.new_from_bytes(
                GLib.Bytes(bytes(pixels)), z.get_colorspace(),
                z.get_has_alpha(), z.get_bits_per_sample(),
                z.get_width(), z.get_height(), z.get_rowstride())
            mag_img.set_from_pixbuf(zc)

        def map_xy(ev):
            ix = int((ev.x - state["ox"]) / state["scale"])
            iy = int((ev.y - state["oy"]) / state["scale"])
            return ix, iy

        def on_motion(wdg, ev):
            ix, iy = map_xy(ev)
            mag_at(ix, iy)
            if not magnifier.get_visible():
                magnifier.show_all()
            magnifier.move(int(ev.x_root) + 18, int(ev.y_root) + 18)
            return False

        closed = {"v": False}

        def _close_picker():
            if closed["v"]:
                return
            closed["v"] = True
            try:
                magnifier.destroy()
            except Exception:
                pass
            try:
                picker.destroy()
            except Exception:
                pass

        def on_press(wdg, ev):
            ix, iy = map_xy(ev)
            if 0 <= ix < w and 0 <= iy < h:
                p = img.getpixel((ix, iy))
                on_result(Gdk.RGBA(p[0] / 255, p[1] / 255,
                                   p[2] / 255, 1.0))
                GLib.idle_add(_close_picker)
            return False

        def on_key(wdg, ev):
            if ev.keyval in (Gdk.KEY_Escape, Gdk.KEY_q, Gdk.KEY_Q):
                GLib.idle_add(_close_picker)
                return True
            return False

        disp.connect("draw", on_draw)
        picker.connect("motion-notify-event", on_motion)
        picker.connect("button-press-event", on_press)
        picker.connect("key-press-event", on_key)
        disp.connect("motion-notify-event", on_motion)
        disp.connect("button-press-event", on_press)

        picker.fullscreen()
        picker.show_all()
        pw = picker.get_window().get_width()
        ph = picker.get_window().get_height()
        scale = max(0.01, min(pw / w, ph / h))
        state["scale"] = scale
        state["pb"] = pb.scale_simple(
            max(1, int(w * scale)), max(1, int(h * scale)),
            GdkPixbuf.InterpType.BILINEAR)
        disp.queue_draw()
        picker.get_window().set_cursor(Gdk.Cursor.new_for_display(
            Gdk.Display.get_default(), Gdk.CursorType.CROSSHAIR))
        picker.grab_focus()
