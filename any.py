import re
import sys
import platform

def is_wheel_compatible(wheel_url):
    wheel_file = wheel_url.split('/')[-1]
    py_version = f"cp{sys.version_info.major}{sys.version_info.minor}"
    arch = platform.machine().lower()
    plat = sys.platform.lower()

    # 示例匹配，比如：
    # PyYAML-6.0.2-cp310-cp310-manylinux_2_17_aarch64.manylinux2014_aarch64.whl
    match = re.search(rf'{py_version}.*?({plat}|{arch})', wheel_file)
    return bool(match)

# 在每个 [[package]] 中做处理：
for pkg in data.get("package", []):
    name = pkg.get("name")
    wheels = pkg.get("wheels", [])
    matched_wheels = [w for w in wheels if is_wheel_compatible(w.get("url", ""))]
    if matched_wheels:
        print(f"✅ 适用于当前平台的 wheel: {name}")
        for w in matched_wheels:
            print(f"    {w['url']}")

