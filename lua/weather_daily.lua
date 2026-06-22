function conky_safe_day(tbl, i)
	return (tbl and tbl[i]) or 0
end
function conky_daily_data()
	return W.weather.daily or {}
end
function conky_weather_day_time(i)
	return conky_safe_day(conky_daily_data().time, i)
end
function conky_weather_day_code(i)
	return conky_safe_day(conky_daily_data().weather_code, i)
end
function conky_weather_day_temp_max(i)
	return conky_round(conky_safe_day(conky_daily_data().temperature_2m_max, i))
end
function conky_weather_day_temp_min(i)
	return conky_round(conky_safe_day(conky_daily_data().temperature_2m_min, i))
end
function conky_weather_day_sunrise(i)
	return fmt_unix(conky_safe_day(conky_daily_data().sunrise, i))
end
function conky_weather_day_sunset(i)
	return fmt_unix(conky_safe_day(conky_daily_data().sunset, i))
end
function conky_weather_day_daylight(i)
	return conky_safe_day(conky_daily_data().daylight_duration, i)
end
function conky_weather_day_sunshine(i)
	return conky_safe_day(conky_daily_data().sunshine_duration, i)
end
function conky_weather_day_uv(i)
	return conky_round(conky_safe_day(conky_daily_data().uv_index_max, i))
end
function conky_weather_day_precip_hours(i)
	return conky_safe_day(conky_daily_data().precipitation_hours, i)
end
