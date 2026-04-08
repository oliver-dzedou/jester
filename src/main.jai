#import "Basic";
using #import "Vulkan";

vk_check :: (result: VkResult) {
    assert(result == .SUCCESS, "A vulkan error occured: %", result);
}

main :: () {
    assert(vkCreateInstance != null, "vkCreateInstance is null pointer");
    
    app_info := VkApplicationInfo.{
        sType = .APPLICATION_INFO,
        apiVersion = VK_MAKE_API_VERSION(0, 1, 3, 0),
        pApplicationName = "jester",
    };
    instance_create_info := VkInstanceCreateInfo.{
        sType = .INSTANCE_CREATE_INFO,
        pApplicationInfo = *app_info,
        enabledExtensionCount = 0,
        ppEnabledExtensionNames = null,
    };
    instance: VkInstance;
    vk_check(vkCreateInstance(*instance_create_info, null, *instance));

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
                log("using % :: %", device_properties.properties.deviceType, to_string(*device_properties.properties.deviceName[0], device_properties.properties.deviceName.count));
                device = it;
                break desired_device_type;
            }
        }
    }
    assert(device != null, "could not find a suitable device, exiting");
}