-- Extra autostart processes.
-- o.launch_on_start("my-service")
o.launch_on_start("hyprsunset")
o.launch_on_start("omarchy-backup")
o.launch_on_start("bash " .. (os.getenv("HOME") or "/home/nikhil") .. "/.config/hypr/scripts/monitor-watcher.sh")
