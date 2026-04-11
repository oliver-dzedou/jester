#import "Basic";
#import "Window_Creation";
#import "Input";
#import,dir "../dependencies/vulkan";
#if OS == .WINDOWS {
    #import "Windows"; 
} else #if OS == .LINUX {
    #import "POSIX";
    #import "Linux";
}

#module_parameters(DEBUG := false); // @TODO: figure out the idiomatic way of doing this kind of stuff in Jai

#scope_file

VK_API_VERSION :: #run VK_MAKE_API_VERSION(0, 1, 4, 341);
VK_VALIDATION_LAYER :: "VK_LAYER_KHRONOS_validation";
VK_DEBUG_EXTENSION :: "VK_EXT_debug_utils";
VK_KHR_SURFACE_EXTENSION :: "VK_KHR_surface";
VK_KHR_WIN32_SURFACE_EXTENSION :: "VK_KHR_win32_surface";
VK_CREATE_DEBUG_UTILS_MESSENGER :: "vkCreateDebugUtilsMessengerEXT";
VK_DESTROY_DEBUG_UTILS_MESSENGER :: "vkDestroyDebugUtilsMessengerEXT";
#if OS == .WINDOWS {
    VK_DLL :: "vulkan-1.dll";
} else #if OS == .WINDOWS {
    VK_DLL :: "libvulkan.so.1";
}
// @NOTE: all of these are arbitrary
VK_MAX_LAYER_COUNT :: 8;
VK_MAX_EXTENSION_COUNT :: 8;
VK_MAX_DEVICE_COUNT :: 8;
VK_MAX_QUEUE_FAMILY_COUNT :: 8;
//


instance: VkInstance;
physical_device: VkPhysicalDevice;
logical_device: VkDevice;
window: Window_Type;
surface: VkSurfaceKHR;
#if DEBUG {
    debug_messenger: VkDebugUtilsMessengerEXT;
}

vk_check :: (result: VkResult) {
    assert(result == .VK_SUCCESS, "VK_ERROR: %", result);
}

#scope_export

init :: (window_width: int, window_height: int, app_name: string) {
    #if OS == .WINDOWS {
        load_vulkan_loader_procedures(LoadLibraryA(VK_DLL) , GetProcAddress);
    } else #if OS == .LINUX {
        load_vulkan_loader_procedures(dlopen(VK_DLL, RTLD_NOW), dlsym);
    } else {
        #assert(false, tprint("% is not supported", OS));
    }

    window = create_window(window_width, window_height, app_name);
    app_info := VkApplicationInfo.{
        sType = .VK_STRUCTURE_TYPE_APPLICATION_INFO,
        apiVersion = VK_API_VERSION,
        pApplicationName = to_c_string(app_name),
        pEngineName = "jester",
    };

    layers: [VK_MAX_LAYER_COUNT]*u8;
    extensions: [VK_MAX_EXTENSION_COUNT]*u8;
    layer_count: u32;
    extension_count: u32;

    add_layer_or_extension :: (arr: []*u8, count: *u32, item: *u8) {
        arr[<<count] = item;
        <<count += 1;
    }

    debug_create_info: VkDebugUtilsMessengerCreateInfoEXT;
    #if DEBUG {
        debug_callback :: (
                messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT, 
                messageType: VkDebugUtilsMessageTypeFlagsEXT, 
                pCallbackData: *VkDebugUtilsMessengerCallbackDataEXT, 
                pUserData: *void
            ) -> VkBool32 #c_call {
                if messageSeverity > .VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT {
                    push_context {
                        log("VK_VALIDATION_LAYER: %", to_string(pCallbackData.pMessage));
                    }
                }
            
            return VK_FALSE;
        }
        add_layer_or_extension(layers, *layer_count, VK_VALIDATION_LAYER);
        add_layer_or_extension(extensions, *extension_count, VK_DEBUG_EXTENSION);
        debug_create_info = VkDebugUtilsMessengerCreateInfoEXT.{
            sType           =  .VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            messageSeverity =  .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            messageType = .VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            pfnUserCallback = debug_callback,
        };
    }

    #if OS == .WINDOWS {
        add_layer_or_extension(extensions, *extension_count, VK_KHR_SURFACE_EXTENSION);
        add_layer_or_extension(extensions, *extension_count, VK_KHR_WIN32_SURFACE_EXTENSION);
    }

    create_info: VkInstanceCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo = *app_info;
    create_info.enabledLayerCount = layer_count;
    create_info.enabledExtensionCount = extension_count;
    create_info.ppEnabledLayerNames = layers.data;
    create_info.ppEnabledExtensionNames = extensions.data;
    create_info.pNext = *debug_create_info;
    vk_check(vkCreateInstance(*create_info, null, *instance));
    load_vulkan_instance_procedures(instance);

    #if DEBUG {
        create_debug_messenger := cast(PFN_vkCreateDebugUtilsMessengerEXT) vkGetInstanceProcAddr(instance, VK_CREATE_DEBUG_UTILS_MESSENGER);
        assert(create_debug_messenger != null, "create_debug_messenger is null pointer");
        vk_check(create_debug_messenger(instance, *debug_create_info, null, *debug_messenger));
    }

    #if OS == .WINDOWS {
        surface_create_info: VkWin32SurfaceCreateInfoKHR; 
        surface_create_info.hinstance = GetModuleHandleW(null);
        surface_create_info.hwnd = window;
        vk_check(vkCreateWin32SurfaceKHR(instance, *surface_create_info, null, *surface));
    } else #if OS == .LINUX { 
        surface_create_info: VkXlibSurfaceCreateInfoKHR;
        surface_create_info.display = XOpenDisplay(null);
        surface_create_info.window = window;
        vk_check(vkCreateXlibSurfaceKHR(instance, *surface_create_info, null, *surface));
    } else {
        #assert(false, tprint("% is not supported", OS));
    }

    device_list: [VK_MAX_DEVICE_COUNT]VkPhysicalDevice;
    actual_device_count: u32;
    vk_check(vkEnumeratePhysicalDevices(instance, *actual_device_count, null));
    vk_check(vkEnumeratePhysicalDevices(instance, *actual_device_count, device_list.data));

    desired_device_types :: VkPhysicalDeviceType.[.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU, .VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU, .VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU];
    for desired_device_type: desired_device_types {
        for i: 0..actual_device_count - 1 {
            device_properties := VkPhysicalDeviceProperties2.{
                sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
            };
            vkGetPhysicalDeviceProperties2(device_list[i], *device_properties);
            if device_properties.properties.deviceType == desired_device_type {
                queue_family_list: [VK_MAX_QUEUE_FAMILY_COUNT]VkQueueFamilyProperties;
                actual_queue_family_count: u32;
                vkGetPhysicalDeviceQueueFamilyProperties(device_list[i], *actual_queue_family_count, null);
                vkGetPhysicalDeviceQueueFamilyProperties(device_list[i], *actual_queue_family_count, queue_family_list.data);
                for j: 0..actual_queue_family_count - 1 {
                    if queue_family_list[j].queueFlags & .VK_QUEUE_GRAPHICS_BIT { // @TODO: At some point there should be a system that allows opting into ensuring compute capabilities as well
                        #if DEBUG {
                            device_name := to_string(device_properties.properties.deviceName.data, device_properties.properties.deviceName.count);
                            device_type := device_properties.properties.deviceType;
                            log("INFO: using device \"%\" (%)", device_name, device_type);
                        }
                        physical_device = device_list[i];
                        break desired_device_type;
                    }
                }
            }
        }
    }

    assert(physical_device != null, "could not find a suitable device");

    load_vulkan_device_procedures(logical_device); // @TODO initializing logical device
}

deinit :: () {
    #if DEBUG {
        destroy_debug_messenger := cast(PFN_vkDestroyDebugUtilsMessengerEXT) vkGetInstanceProcAddr(instance, VK_DESTROY_DEBUG_UTILS_MESSENGER);
        assert(destroy_debug_messenger != null, "create_debug_messenger is null pointer");
        destroy_debug_messenger(instance, debug_messenger, null);
    }
    vkDestroySurfaceKHR(instance, surface, null);
    vkDestroyInstance(instance, null);
}