--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 34_draw_image.lua — PNG rendering with crop, tint, rotate, shape clip
PNG_CACHE = PNG_CACHE or {}
local function is_surface_valid(s)
	return s
		and cairo_surface_status(s) == 0
		and cairo_image_surface_get_width(s) > 0
		and cairo_image_surface_get_height(s) > 0
end
local PNG_DEFAULT = {
	draw_me = true,
	view = nil,
	group = nil,
	click = nil,
	click_view = nil,
	click_toggle = nil,
	path = nil,
	x = 0,
	y = 0,
	width = nil,
	height = nil,
	alpha = 1,
	tint = nil,
	tint_alpha = 1,
	rotate = 0,
	scale_mode = "bilinear",
	shape = nil,
	radius = 0,
	crop = nil,
}
local function apply_png_defaults(m)
	for k, v in pairs(PNG_DEFAULT) do
		if m[k] == nil then
			m[k] = v
		end
	end
end
function draw_png(cr, m)
	apply_png_defaults(m)
	if not conky_window then
		return
	end
	if not draw_allowed(m.draw_me, m.view, m.group) then
		return
	end
	if not m.path then
		return
	end
	local attrs = lfs.attributes(m.path)
	local mtime = attrs and attrs.modification or 0
	local cached = PNG_CACHE[m.path]
	local reload = (not cached) or cached.mtime ~= mtime or not is_surface_valid(cached.surface)
	if reload then
		local img = cairo_image_surface_create_from_png(m.path)
		if cairo_surface_status(img) == 0 then
			PNG_CACHE[m.path] = { surface = img, mtime = mtime }
		else
			cairo_surface_destroy(img)
			return
		end
	end
	local img = PNG_CACHE[m.path].surface
	local iw = cairo_image_surface_get_width(img)
	local ih = cairo_image_surface_get_height(img)
	if iw == 0 or ih == 0 then
		return
	end
	cairo_save(cr)
	local crop_x = m.crop and (m.crop.x or 0) or 0
	local crop_y = m.crop and (m.crop.y or 0) or 0
	local sw = m.crop and (m.crop.w or (iw - crop_x)) or iw
	local sh = m.crop and (m.crop.h or (ih - crop_y)) or ih
	if m.width and not m.height then
		m.height = m.width * (sh / sw)
	elseif m.height and not m.width then
		m.width = m.height * (sw / sh)
	end
	local sx = m.width and (m.width / sw) or 1
	local sy = m.height and (m.height / sh) or 1
	if m.rotate then
		local cx = m.x + (m.width or sw) / 2
		local cy = m.y + (m.height or sh) / 2
		cairo_translate(cr, cx, cy)
		cairo_rotate(cr, math.rad(m.rotate))
		cairo_translate(cr, -cx, -cy)
	end
	cairo_translate(cr, m.x, m.y)
	cairo_scale(cr, sx, sy)
	if m.shape == "circle" then
		local r = math.min(sw, sh) / 2
		cairo_arc(cr, r, r, r, 0, 2 * math.pi)
	elseif m.radius and m.radius > 0 then
		local r = math.min(m.radius, sw / 2, sh / 2)
		cairo_new_sub_path(cr)
		cairo_arc(cr, sw - r, r, r, -math.pi / 2, 0)
		cairo_arc(cr, sw - r, sh - r, r, 0, math.pi / 2)
		cairo_arc(cr, r, sh - r, r, math.pi / 2, math.pi)
		cairo_arc(cr, r, r, r, math.pi, 3 * math.pi / 2)
		cairo_close_path(cr)
	else
		cairo_rectangle(cr, 0, 0, sw, sh)
	end
	cairo_clip(cr)
	local pat = cairo_pattern_create_for_surface(img)
	cairo_pattern_set_extend(pat, CAIRO_EXTEND_NONE)
	if m.scale_mode == "nearest" then
		cairo_pattern_set_filter(pat, CAIRO_FILTER_NEAREST)
	elseif m.scale_mode == "good" then
		cairo_pattern_set_filter(pat, CAIRO_FILTER_GOOD)
	else
		cairo_pattern_set_filter(pat, CAIRO_FILTER_BILINEAR)
	end
	if m.tint then
		local r, g, b, a = hex_to_rgba(m.tint, m.tint_alpha or 1)
		cairo_set_source_rgba(cr, r, g, b, a)
		cairo_mask_surface(cr, img, -crop_x, -crop_y)
	else
		cairo_set_source_surface(cr, img, -crop_x, -crop_y)
		cairo_paint_with_alpha(cr, m.alpha or 1)
	end
	cairo_pattern_destroy(pat)
	cairo_restore(cr)
	return { x = m.x, y = m.y, w = m.width or 0, h = m.height or 0 }
end

