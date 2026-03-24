package main

import "core:bytes"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"
import vk "vendor:vulkan"

vk_check :: proc(result: vk.Result, loc := #caller_location) {
	assert(result == .SUCCESS, fmt.tprintf("%v\na Vulkan error occurred: %v", loc, result))
}

sdl_check :: proc(result: bool, loc := #caller_location) {
	assert(result, fmt.tprintf("%v\nan SDL error occurred: %v", sdl.GetError()))
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		logger := log.create_console_logger()
		context.logger = logger

		defer {
			log.destroy_console_logger(context.logger)
			if len(track.allocation_map) > 0 {
				fmt.println("\n-----== Tracking allocator: Detected memory leaks ==-----\n")
				for _, entry in track.allocation_map {
					fmt.printfln("%v leaked %v bytes", entry.location, entry.size)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	sdl_check(sdl.Init({.VIDEO}))
	sdl_check(sdl.Vulkan_LoadLibrary(nil))
	proc_addr := sdl.Vulkan_GetVkGetInstanceProcAddr()
	vk.load_proc_addresses_global(cast(rawptr)proc_addr)
	assert(proc_addr != nil, "proc_addr is nulptr")
	assert(vk.CreateInstance != nil, "vk.CreateInstance is nulptr")

	vk_extension_count := u32(0)
	vk_extensions := sdl.Vulkan_GetInstanceExtensions(&vk_extension_count)

	app_info := vk.ApplicationInfo {
		sType            = .APPLICATION_INFO,
		apiVersion       = vk.API_VERSION_1_3,
		pApplicationName = "jester",
	}
	instance_create_info := vk.InstanceCreateInfo {
		sType                   = .INSTANCE_CREATE_INFO,
		pApplicationInfo        = &app_info,
		enabledExtensionCount   = vk_extension_count,
		ppEnabledExtensionNames = vk_extensions,
	}

	instance: vk.Instance
	vk_check(vk.CreateInstance(&instance_create_info, nil, &instance))
	vk.load_proc_addresses_instance(instance)
	device_count := u32(0)
	vk_check(vk.EnumeratePhysicalDevices(instance, &device_count, nil))
	// @allocation
	device_list := make([dynamic]vk.PhysicalDevice, device_count, device_count)
	defer delete(device_list)
	vk_check(vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(device_list)))

	device: vk.PhysicalDevice
	desired_device_types :: [3]vk.PhysicalDeviceType{.DISCRETE_GPU, .INTEGRATED_GPU, .VIRTUAL_GPU}
	outer: for desired_device_type in desired_device_types {
		for it in device_list {
			device_properties := vk.PhysicalDeviceProperties2 {
				sType = .PHYSICAL_DEVICE_PROPERTIES_2,
			}
			vk.GetPhysicalDeviceProperties2(it, &device_properties)
			if device_properties.properties.deviceType == desired_device_type {
				log.infof(
					"Using %v :: %v",
					device_properties.properties.deviceType,
					cstring(&device_properties.properties.deviceName[0]),
				)
				device = it
				break outer
			}
		}
	}
	assert(device != nil, "could not find a suitable device, exiting")
}
