"""
gradient_gen.py — Standalone gradient / palette generator (no Lua writes).

Color math + formatting used by the designer's "Gradient" tab.
All output follows the framework's gradient-stop format:
    { { 0.0, "#rrggbb", 1 }, { 1.0, "#rrggbb", 1 } }
"""

import math


# ═══ COLOR MATH ═══

def hex_to_rgb(h):
    """'#rrggbb' / 'rrggbb' / '#rgb' → (r, g, b) in 0..255."""
    h = h.strip().lstrip('#')
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    if len(h) != 6:
        return (0, 0, 0)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(r, g, b):
    """(r, g, b) in 0..255 → '#rrggbb'."""
    return '#{:02x}{:02x}{:02x}'.format(
        max(0, min(255, int(round(r)))),
        max(0, min(255, int(round(g)))),
        max(0, min(255, int(round(b)))),
    )


def mix(c1, c2, t):
    """Linear RGB mix between two (r,g,b) tuples (0..255)."""
    return tuple(a + (b - a) * t for a, b in zip(c1, c2))


# ═══ OKLab INTERPOLATION ═══
# Perceptual interpolation so generated gradients have correct midpoints
# (mirrors the OKLab sampling in cairo_helpers / utils.lua).

def _srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _linear_to_srgb(c):
    c = 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
    return max(0.0, min(1.0, c)) * 255.0


def _oklab(r, g, b):
    r, g, b = _srgb_to_linear(r), _srgb_to_linear(g), _srgb_to_linear(b)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def _srgb(L, a, bb):
    l = L + 0.3963377774 * a + 0.2158037573 * bb
    m = L - 0.1055613458 * a - 0.0638541728 * bb
    s = L - 0.0894841775 * a - 1.2914855480 * bb
    l, m, s = l ** 3, m ** 3, s ** 3
    return (_linear_to_srgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            _linear_to_srgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            _linear_to_srgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))


def mix_oklab(c1, c2, t):
    """Mix two (r,g,b) tuples (0..255) in OKLab space."""
    o1 = _oklab(*c1)
    o2 = _oklab(*c2)
    return _srgb(*(a + (b - a) * t for a, b in zip(o1, o2)))


# ═══ INTERPOLATION MODES ═══

MODES = [
    ("linear", "Linear"),
    ("log", "Logarithmic"),
    ("exp", "Exponential"),
    ("sine", "Sine"),
]


def remap_t(t, mode):
    """Remap 0..1 progress by interpolation mode."""
    t = max(0.0, min(1.0, t))
    if mode == "log":          # slow start, fast end
        return math.log(1 + t * (math.e - 1)) / math.log(math.e)
    if mode == "exp":          # fast start, slow end
        return (math.exp(t) - 1) / (math.e - 1)
    if mode == "sine":         # ease in-out
        return (1 - math.cos(t * math.pi)) / 2
    return t                   # linear


# ═══ STOPS ═══

def normalize_stops(stops):
    """Normalize to sorted list of (pos, '#rrggbb', alpha) tuples."""
    out = []
    for s in stops:
        try:
            if len(s) >= 3:
                pos, hexc, alpha = float(s[0]), str(s[1]), float(s[2])
            elif len(s) == 2:
                pos, hexc, alpha = float(s[0]), str(s[1]), 1.0
            else:
                continue
        except (ValueError, TypeError):
            continue
        out.append((max(0.0, min(1.0, pos)), hexc, max(0.0, min(1.0, alpha))))
    out.sort(key=lambda x: x[0])
    merged = []
    for s in out:
        if merged and merged[-1][0] == s[0]:
            merged[-1] = s
        else:
            merged.append(s)
    return merged


def sample_stops(stops, t, mode="linear"):
    """Sample gradient at t (0..1) → (r, g, b, a), channels 0..255 / 0..1."""
    s = normalize_stops(stops)
    if not s:
        return (0, 0, 0, 1)
    t = remap_t(t, mode)
    if t <= s[0][0]:
        rgb = hex_to_rgb(s[0][1])
        return (rgb[0], rgb[1], rgb[2], s[0][2])
    if t >= s[-1][0]:
        rgb = hex_to_rgb(s[-1][1])
        return (rgb[0], rgb[1], rgb[2], s[-1][2])
    for i in range(len(s) - 1):
        p0, h0, a0 = s[i]
        p1, h1, a1 = s[i + 1]
        if p0 <= t <= p1:
            f = (t - p0) / ((p1 - p0) or 1.0)
            rgb = mix_oklab(hex_to_rgb(h0), hex_to_rgb(h1), f)
            a = a0 + (a1 - a0) * f
            return (rgb[0], rgb[1], rgb[2], a)
    return (0, 0, 0, 1)


def discrete_swatches(stops, n, mode="linear"):
    """n discrete colors sampled across the gradient."""
    if n < 1:
        return []
    if n == 1:
        return [sample_stops(stops, 0.5, mode)]
    return [sample_stops(stops, i / (n - 1), mode) for i in range(n)]


# ═══ FORMATTING ═══

def _fmt_alpha(a):
    if abs(a - round(a)) < 1e-6:
        return str(int(round(a)))
    return '{:.2f}'.format(a)


def format_lua_stops(stops):
    """Gradient stops → Lua table string (THEMES block)."""
    parts = []
    for pos, hexc, alpha in normalize_stops(stops):
        parts.append('{{ {:.2f}, "{}", {} }}'.format(pos, hexc, _fmt_alpha(alpha)))
    return '{{ ' + ', '.join(parts) + ' }}'


def format_hex_palette(swatches):
    """List of (r,g,b,a) → '#rrggbb' comma-separated list."""
    return ', '.join(rgb_to_hex(*sw[:3]) for sw in swatches)


# ═══ SHADES / TINTS ═══

def shade_colors(hexc, steps=8):
    """Shades of a single color: darker → base → lighter.
    Returns list of (r, g, b, 1) tuples."""
    base = hex_to_rgb(hexc)
    if steps < 2:
        return [(base[0], base[1], base[2], 1)]
    out = []
    for i in range(steps):
        t = i / (steps - 1)
        if t < 0.5:
            col = mix((0, 0, 0), base, t * 2)
        elif t > 0.5:
            col = mix(base, (255, 255, 255), (t - 0.5) * 2)
        else:
            col = base
        out.append((col[0], col[1], col[2], 1))
    return out
