--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- weather/air.lua — Air quality accessors (current + hourly)
-- Reads from W.air. Covers PM, gases, pollen, and AQI indices.

function conky_safe_air(v)
	return v or 0
end
function conky_cur_air_data()
	return W.air.current or {}
end
function conky_air_current_pm10()
	return conky_safe_air(conky_cur_air_data().pm10)
end
function conky_air_current_pm25()
	return conky_safe_air(conky_cur_air_data().pm2_5)
end
function conky_air_current_co()
	return conky_safe_air(conky_cur_air_data().carbon_monoxide)
end
function conky_air_current_o3()
	return conky_safe_air(conky_cur_air_data().ozone)
end
function conky_air_current_no2()
	return conky_safe_air(conky_cur_air_data().nitrogen_dioxide)
end
function conky_air_current_so2()
	return conky_safe_air(conky_cur_air_data().sulphur_dioxide)
end
function conky_air_current_dust()
	return conky_safe_air(conky_cur_air_data().dust)
end
function conky_air_current_eaqi()
	return conky_safe_air(conky_cur_air_data().european_aqi)
end
function conky_air_current_usaqi()
	return conky_safe_air(conky_cur_air_data().us_aqi)
end
function conky_air_current_alder()
	return conky_safe_air(conky_cur_air_data().alder_pollen)
end
function conky_air_current_birch()
	return conky_safe_air(conky_cur_air_data().birch_pollen)
end
function conky_air_current_grass()
	return conky_safe_air(conky_cur_air_data().grass_pollen)
end
function conky_air_current_mugwort()
	return conky_safe_air(conky_cur_air_data().mugwort_pollen)
end
function conky_air_current_olive()
	return conky_safe_air(conky_cur_air_data().olive_pollen)
end
function conky_air_current_ragweed()
	return conky_safe_air(conky_cur_air_data().ragweed_pollen)
end
function conky_air_hourly_data()
	return W.air.hourly or {}
end
function conky_air_hour_pm10(i)
	return conky_safe_hour(conky_air_hourly_data().pm10, get_idx(i))
end
function conky_air_hour_pm25(i)
	return conky_safe_hour(conky_air_hourly_data().pm2_5, get_idx(i))
end
function conky_air_hour_co(i)
	return conky_safe_hour(conky_air_hourly_data().carbon_monoxide, get_idx(i))
end
function conky_air_hour_o3(i)
	return conky_safe_hour(conky_air_hourly_data().ozone, get_idx(i))
end
function conky_air_hour_no2(i)
	return conky_safe_hour(conky_air_hourly_data().nitrogen_dioxide, get_idx(i))
end
function conky_air_hour_so2(i)
	return conky_safe_hour(conky_air_hourly_data().sulphur_dioxide, get_idx(i))
end
function conky_air_hour_dust(i)
	return conky_safe_hour(conky_air_hourly_data().dust, get_idx(i))
end
function conky_air_hour_eaqi(i)
	return conky_safe_hour(conky_air_hourly_data().european_aqi, get_idx(i))
end
function conky_air_hour_usaqi(i)
	return conky_safe_hour(conky_air_hourly_data().us_aqi, get_idx(i))
end
