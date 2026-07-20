--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- draw/image.lua — PNG rendering with crop, tint, rotate, shape clip
-- Pattern matrix-based scaling (no cairo_scale on cr).
PNG_CACHE = PNG_CACHE or {}
TINT_CACHE = TINT_CACHE or {}

if not rounded_rect_path then
	function rounded_rect_path(cr, x, y, w, h, r)
		r = math.min(r, w / 2, h / 2)
		cairo_new_sub_path(cr)
		cairo_arc(cr, x + w - r, y + r, r, -math.pi / 2, 0)
		cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi / 2)
		cairo_arc(cr, x + r, y + h - r, r, math.pi / 2, math.pi)
		cairo_arc(cr, x + r, y + r, r, math.pi, 3 * math.pi / 2)
		cairo_close_path(cr)
	end
end

local function is_surface_valid(s)
	return s
		and cairo_surface_status(s) == 0
		and cairo_image_surface_get_width(s) > 0
		and cairo_image_surface_get_height(s) > 0
end
local PNG_DEFAULT = {
	view = nil,
	group = nil,
	click = nil,
	click_view = nil,
	click_toggle = nil,
	hover_view = nil,
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
	if not conky_window then return end
	if not draw_allowed(m.view, m.group) then return end
	if not m.path then return end

	local attrs = lfs.attributes(m.path)
	local mtime = attrs and attrs.modification or 0
	local cached = PNG_CACHE[m.path]
	local reload = (not cached) or cached.mtime ~= mtime or not is_surface_valid(cached.surface)
	if reload then
		for key, cache_item in pairs(TINT_CACHE) do
			if key:sub(1, #m.path + 1) == m.path .. "_" then
				if cache_item.surface then
					cairo_surface_destroy(cache_item.surface)
				end
				TINT_CACHE[key] = nil
			end
		end

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
	if iw == 0 or ih == 0 then return end

	local crop_x = m.crop and (m.crop.x or 0) or 0
	local crop_y = m.crop and (m.crop.y or 0) or 0
	local sw = m.crop and (m.crop.w or (iw - crop_x)) or iw
	local sh = m.crop and (m.crop.h or (ih - crop_y)) or ih

	if m.width and not m.height then
		m.height = m.width * (sh / sw)
	elseif m.height and not m.width then
		m.width = m.height * (sw / sh)
	end
	local w = m.width or sw
	local h = m.height or sh

	cairo_save(cr)

	cairo_translate(cr, m.x, m.y)

	if m.rotate and m.rotate ~= 0 then
		cairo_translate(cr, w / 2, h / 2)
		cairo_rotate(cr, math.rad(m.rotate))
		cairo_translate(cr, -w / 2, -h / 2)
	end

	if m.shape == "circle" then
		local r = math.min(w, h) / 2
		cairo_arc(cr, w / 2, h / 2, r, 0, 2 * math.pi)
		cairo_clip(cr)
	elseif m.radius and m.radius > 0 then
		rounded_rect_path(cr, 0, 0, w, h, m.radius)
		cairo_clip(cr)
	else
		cairo_rectangle(cr, 0, 0, w, h)
		cairo_clip(cr)
	end

	local pat = cairo_pattern_create_for_surface(img)
	cairo_pattern_set_extend(pat, CAIRO_EXTEND_NONE)
	if m.scale_mode == "nearest" then
		cairo_pattern_set_filter(pat, CAIRO_FILTER_NEAREST)
	elseif m.scale_mode == "good" then
		cairo_pattern_set_filter(pat, CAIRO_FILTER_GOOD)
	else
		cairo_pattern_set_filter(pat, CAIRO_FILTER_BILINEAR)
	end

	local matrix = cairo_matrix_t:create()
	cairo_matrix_init_identity(matrix)
	cairo_matrix_translate(matrix, crop_x, crop_y)
	cairo_matrix_scale(matrix, sw / w, sh / h)
	cairo_pattern_set_matrix(pat, matrix)

	cairo_set_source(cr, pat)

	if m.tint then
		local tint_key = string.format("%s_%dx%d_%s_%.2f", m.path, w, h, m.tint, m.tint_alpha or 1)
		local t_cached = TINT_CACHE[tint_key]
		if not t_cached or not is_surface_valid(t_cached.surface) then
			local surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h)
			local tmp_cr = cairo_create(surf)
			local tmp_pat = cairo_pattern_create_for_surface(img)
			cairo_pattern_set_extend(tmp_pat, CAIRO_EXTEND_NONE)
			if m.scale_mode == "nearest" then
				cairo_pattern_set_filter(tmp_pat, CAIRO_FILTER_NEAREST)
			elseif m.scale_mode == "good" then
				cairo_pattern_set_filter(tmp_pat, CAIRO_FILTER_GOOD)
			else
				cairo_pattern_set_filter(tmp_pat, CAIRO_FILTER_BILINEAR)
			end
			local tmp_matrix = cairo_matrix_t:create()
			cairo_matrix_init_identity(tmp_matrix)
			cairo_matrix_translate(tmp_matrix, crop_x, crop_y)
			cairo_matrix_scale(tmp_matrix, sw / w, sh / h)
			cairo_pattern_set_matrix(tmp_pat, tmp_matrix)
			local r_t, g_t, b_t, a_t = hex_to_rgba(m.tint, m.tint_alpha or 1)
			cairo_set_source_rgba(tmp_cr, r_t, g_t, b_t, a_t)
			cairo_mask(tmp_cr, tmp_pat)
			cairo_pattern_destroy(tmp_pat)
			cairo_destroy(tmp_cr)
			TINT_CACHE[tint_key] = { surface = surf }
			t_cached = TINT_CACHE[tint_key]
		end
		cairo_set_source_surface(cr, t_cached.surface, 0, 0)
		cairo_paint_with_alpha(cr, m.alpha or 1)
	else
		cairo_paint_with_alpha(cr, m.alpha or 1)
	end

	cairo_pattern_destroy(pat)
	cairo_restore(cr)
	return { x = m.x, y = m.y, w = w, h = h }
end
