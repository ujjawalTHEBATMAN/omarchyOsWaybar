import json, subprocess, time

# Modify config
with open('/home/ujjawal/.config/waybar/config.jsonc', 'r') as f:
    conf = f.read()
conf = conf.replace('"empty": "{name}"', '"empty": "empty_{name}"')
with open('/home/ujjawal/.config/waybar/config.jsonc', 'w') as f:
    f.write(conf)

subprocess.Popen(["pkill", "waybar"])
time.sleep(1)
subprocess.Popen(["waybar"])
time.sleep(2)
