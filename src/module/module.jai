#import "Basic";
using #import "Vulkan";

#module_parameters(DEBUG := false);

#scope_file

VK_MAJOR_VERSION :: 1;
VK_MINOR_VERSION :: 4;
VK_PATCH_VERSION :: 341;
VK_VALIDATION_LAYER :: "VK_LAYER_KHRONOS_validation";
VK_DEBUG_EXTENSION :: "VK_EXT_debug_utils";
VK_DEBUG_UTILS_MESSENGER :: "vkCreateDebugUtilsMessengerEXT";

vk_check :: (result: VkResult) {
    assert(result == .SUCCESS, "VK_ERROR: %", result);
}

debug_callback :: (
        messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT, 
        messageType: VkDebugUtilsMessageTypeFlagsEXT, 
        pCallbackData: *VkDebugUtilsMessengerCallbackDataEXT, 
        pUserData: *void
    ) -> VkBool32 #c_call {
        if messageSeverity > .INFO_BIT_EXT {
            push_context {
                log("VK_VALIDATION_LAYER: %", to_string(pCallbackData.pMessage));
            }
        }
    
    return VK_FALSE;
}

#scope_export

init :: () {
    assert(vkCreateInstance != null, "vkCreateInstance is null pointer");
    
    app_info := VkApplicationInfo.{
        sType = .APPLICATION_INFO,
        apiVersion = VK_MAKE_API_VERSION(0, VK_MAJOR_VERSION, VK_MINOR_VERSION, VK_PATCH_VERSION),
        pApplicationName = "jester-example",
        pEngineName = "jester",
    };

    layers: []*u8;
    extensions: []*u8;
    debug_create_info: VkDebugUtilsMessengerCreateInfoEXT;
    #if DEBUG {
        layers = .[VK_VALIDATION_LAYER];
        extensions = .[VK_DEBUG_EXTENSION];
        debug_create_info = VkDebugUtilsMessengerCreateInfoEXT.{
            sType           =  .VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            messageSeverity =  .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            messageType = .VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            pfnUserCallback = debug_callback,
        };
    }
    create_info: VkInstanceCreateInfo;
    create_info.sType = .INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo = *app_info;
    create_info.enabledLayerCount = cast(u32)layers.count;
    create_info.enabledExtensionCount = cast(u32)extensions.count;
    create_info.ppEnabledLayerNames = layers.data;
    create_info.ppEnabledExtensionNames = extensions.data;
    create_info.pNext = *debug_create_info;
    instance: VkInstance;
    vk_check(vkCreateInstance(*create_info, null, *instance));

    #if DEBUG {
        debug_messenger: VkDebugUtilsMessengerEXT;
        create_debug_messenger := cast(PFN_vkCreateDebugUtilsMessengerEXT) vkGetInstanceProcAddr(instance, VK_DEBUG_UTILS_MESSENGER);
        assert(create_debug_messenger != null, "create_debug_messenger is null pointer");
        vk_check(create_debug_messenger(instance, *debug_create_info, null, *debug_messenger));
    }

    device_count: u32 = 0;
    vk_check(vkEnumeratePhysicalDevices(instance, *device_count, null));
    device_list: [..] VkPhysicalDevice;
    array_resize(*device_list, device_count);
    defer array_free(device_list);
    vk_check(vkEnumeratePhysicalDevices(instance, *device_count, device_list.data));
    device: VkPhysicalDevice;
    desired_device_types :: VkPhysicalDeviceType.[.DISCRETE_GPU, .INTEGRATED_GPU, .VIRTUAL_GPU];
    for desired_device_type: desired_device_types {
        for device_list {
            device_properties := VkPhysicalDeviceProperties2.{
                sType = .PHYSICAL_DEVICE_PROPERTIES_2,
            };
            vkGetPhysicalDeviceProperties2(it, *device_properties);
            if device_properties.properties.deviceType == desired_device_type {
                #if DEBUG {
                    log(
                        "INFO: using device \"%\" (%)", 
                        to_string(device_properties.properties.deviceName.data, device_properties.properties.deviceName.count), device_properties.properties.deviceType
                    );
                }
                device = it;
                break desired_device_type;
            }
        }
    }
    assert(device != null, "could not find a suitable device");
}

deinit :: () {
    
}