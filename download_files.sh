#!/bin/bash

# 定义 URL 列表
urls=(
    "http://pkg.loongnix.cn/loongnix/20/pool/main/o/openssl/libssl1.1_1.1.1d-0%2Blnd.12_loongarch64.deb"
    "https://repo1.maven.org/maven2/org/apache/tika/tika-server-standard/3.0.0/tika-server-standard-3.0.0.jar"
    "https://repo1.maven.org/maven2/org/apache/tika/tika-server-standard/3.0.0/tika-server-standard-3.0.0.jar.md5"
    "https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken"
    "http://ftp.loongnix.cn/browser/lbrowser/3.3.2091.6/la64/lbrowser_3.3.2091.6-1.stable.loongarch64.deb"
    "http://ftp.loongnix.cn/nodejs/npm-registry/LoongArch/abi-v1.0/chromedriver/89.0.4389.23/chromedriver_linux64.zip"
)

# 遍历并下载每个文件
for url in "${urls[@]}"; do
    # 提取文件名（假设文件名是 URL 中的最后一部分）
    filename=$(basename "$url")

    echo "Downloading $filename from $url..."
    
    # 使用 curl 或 wget 下载文件
    # 如果你没有 curl，可以使用 wget 代替
    curl -O "$url"
    # 或者
    # wget "$url"
    
    echo "$filename downloaded successfully!"
done

