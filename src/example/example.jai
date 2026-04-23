using #import,dir "../module"(DEBUG=true, ENFORCE_COMPUTE_CAPABILITIES = false);

WINDOW_WIDTH :: 1920;
WINDOW_HEIGHT :: 1080;
APP_NAME :: "jester-example";

main :: () {
    init(WINDOW_WIDTH, WINDOW_HEIGHT, APP_NAME);
    deinit();
}
