# CHANGELOG

### 0.1.0
* Added device selection

### 0.1.1
* Added window creation
* Added surface creation
* Added deinit function

### 0.1.2
* Initial window dimensions and app name are now configurable
* Switched from Jai's default Vulkan bindings to Mr. Osor's bindings (https://codeberg.org/osor_io/osor_vulkan)
* Now loading VK function pointers manually
* Add Linux support
* The README no longer states who is this library intended for; everyone should feel encouraged to try it out :)

### 0.1.3
Turns out, the Linux support didn't work (surprise, surprise)

After a few fixes, it now successfully compiles and runs on Linux, but no window shows up.
This is most likely because Wayland actually doesn't show a window until something is drawn into it
so that should fix itself once we start drawing something.

As a sidenote, the built-in Jai "Window_Creation" module only supports X11, but XWayland handles stuff just fine.

Tested with this minimal example, which does indeed show a window:

```
#import "Window_Creation";
#import "Input";
#import "Simp";
#import "Math";
#import "Basic";
main :: () {
    window := create_window(1920, 1080, "TEST");
    set_render_target(window);
    while true {
            background_color :: Vector4.{x=.1, y=.1, z=.1, w=1};
            using background_color;
            clear_render_target(x, y, z, w);
            swap_buffers(window);
      }
  }
```
