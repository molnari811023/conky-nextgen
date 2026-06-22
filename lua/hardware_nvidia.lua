--{{{ NVIDIA GPU
local gpu_mode_cache = nil

function conky_gpu_mode()
	if gpu_mode_cache then
		return gpu_mode_cache
	end
	local f = io.popen("envycontrol -q 2>/dev/null")
	if f then
		local out = f:read("*l")
		f:close()
		if out == "nvidia" then
			gpu_mode_cache = "nvidia"
		elseif out == "integrated" then
			gpu_mode_cache = "intel"
		elseif out == "hybrid" then
			gpu_mode_cache = "hybrid"
		else
			gpu_mode_cache = "unknown"
		end
	else
		gpu_mode_cache = "unknown"
	end
	return gpu_mode_cache
end

GPU_MODE = conky_gpu_mode()

function conky_nvidia_active()
	return (GPU_MODE == "nvidia" or GPU_MODE == "hybrid") and "1" or "0"
end

function conky_intel_active()
	return (GPU_MODE == "intel") and "1" or "0"
end

function conky_update_nvidia_xml()
	xml_update("nvidia-smi -x -q 2>/dev/null", 2)
	return ""
end
--}}}

--{{{ NVIDIA
function conky_nv_gputemp()
	return xml_num("gpu_temp")
end
function conky_nv_gputempthreshold()
	return xml_num("gpu_temp_slow_threshold")
end
function conky_nv_ambienttemp()
	return xml_num("gpu_temp_max_threshold")
end
function conky_nv_gpufreqcur()
	return xml_num("graphics_clock")
end
function conky_nv_gpufreqmin()
	return 0
end
function conky_nv_gpufreqmax()
	return xml_num("graphics_clock")
end
function conky_nv_memfreqcur()
	return xml_num("mem_clock")
end
function conky_nv_memfreqmin()
	return 0
end
function conky_nv_memfreqmax()
	return xml_num("mem_clock")
end
function conky_nv_mtrfreqcur()
	return 0
end
function conky_nv_mtrfreqmin()
	return 0
end
function conky_nv_mtrfreqmax()
	return 0
end
function conky_nv_perflevelcur()
	return xml_find("performance_state")
end
function conky_nv_perfmode()
	return xml_find("performance_state")
end
function conky_nv_gpuutil()
	return xml_num("gpu_util")
end
function conky_nv_membwutil()
	return xml_num("memory_util")
end
function conky_nv_videoutil()
	return xml_num("encoder_util")
end
function conky_nv_pcieutil()
	return xml_num("tx_util")
end
function conky_nv_memused()
	return xml_num("used")
end
function conky_nv_memfree()
	return xml_num("free")
end
function conky_nv_memmax()
	return xml_num("total")
end
function conky_nv_memutil()
	local u = conky_nv_memused()
	local t = conky_nv_memmax()
	return (t > 0) and math.floor((u / t) * 100) or 0
end
function conky_nv_fanspeed()
	return xml_num("fan_speed")
end
function conky_nv_fanlevel()
	return conky_nv_fanspeed()
end
function conky_nv_modelname()
	return xml_find("product_name")
end
function conky_nv_driverversion()
	return xml_find("driver_version")
end
--}}}
