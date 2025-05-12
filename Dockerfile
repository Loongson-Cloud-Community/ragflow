# base stage
FROM cr.loongnix.cn/library/python:3.10.16-slim-buster AS base
USER root
SHELL ["/bin/bash", "-c"]

ARG NEED_MIRROR=0
ARG LIGHTEN=0
ENV LIGHTEN=${LIGHTEN}

WORKDIR /ragflow

# Copy models downloaded via download_deps.py
RUN mkdir -p /ragflow/rag/res/deepdoc /root/.ragflow
RUN --mount=type=bind,from=loongarch64/ragflow_deps_abi1,source=/huggingface.co,target=/huggingface.co \
    cp /huggingface.co/InfiniFlow/huqie/huqie.txt.trie /ragflow/rag/res/ && \
    tar --exclude='.*' -cf - \
        /huggingface.co/InfiniFlow/text_concat_xgb_v1.0 \
        /huggingface.co/InfiniFlow/deepdoc \
        | tar -xf - --strip-components=3 -C /ragflow/rag/res/deepdoc 
RUN --mount=type=bind,from=loongarch64/ragflow_deps_abi1,source=/huggingface.co,target=/huggingface.co \
    if [ "$LIGHTEN" != "1" ]; then \
        (tar -cf - \
            /huggingface.co/BAAI/bge-large-zh-v1.5 \
            /huggingface.co/BAAI/bge-reranker-v2-m3 \
            /huggingface.co/maidalun1020/bce-embedding-base_v1 \
            /huggingface.co/maidalun1020/bce-reranker-base_v1 \
            | tar -xf - --strip-components=2 -C /root/.ragflow) \
    fi

# https://github.com/chrismattmann/tika-python
# This is the only way to run python-tika without internet access. Without this set, the default is to check the tika version and pull latest every time from Apache.
RUN --mount=type=bind,from=loongarch64/ragflow_deps_abi1,source=/,target=/deps \
    cp -r /deps/nltk_data /root/ && \
    cp /deps/tika-server-standard-3.0.0.jar /deps/tika-server-standard-3.0.0.jar.md5 /ragflow/ && \
    cp /deps/cl100k_base.tiktoken /ragflow/9b5ad71b2ce5302211f9c61530b329a4922fc6a4

ENV TIKA_SERVER_JAR="file:///ragflow/tika-server-standard-3.0.0.jar"
ENV DEBIAN_FRONTEND=noninteractive

# Setup apt
# Python package and implicit dependencies:
# opencv-python: libglib2.0-0 libglx-mesa0 libgl1
# aspose-slides: pkg-config libicu-dev libgdiplus         libssl1.1_1.1.1f-1ubuntu2_amd64.deb
# python-pptx:   default-jdk                              tika-server-standard-3.0.0.jar
# selenium:      libatk-bridge2.0-0                       chrome-linux64-121-0-6167-85
# Building C extensions: libpython3-dev libgtk-4-1 libnss3 xdg-utils libgbm-dev
RUN --mount=type=cache,id=ragflow_apt,target=/var/cache/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    chmod 1777 /tmp && \
    apt update && \
    apt --no-install-recommends install -y ca-certificates && \
    apt update && \
    apt install -y libglib2.0-0 libglx-mesa0 libgl1 && \
    apt install -y pkg-config libicu-dev libgdiplus && \
    apt install -y default-jdk && \
    apt install -y libatk-bridge2.0-0 && \
    apt install -y libpython3-dev libgtk-3-0 libnss3 xdg-utils libgbm-dev && \
    apt install -y libjemalloc-dev libomp-dev libopenblas-base libpq-dev libgeos-c1v5 && \
    apt install -y  nginx unzip curl wget git vim less

RUN if [ "$NEED_MIRROR" == "1" ]; then \
        pip3 config set global.extra-index-url https://mirrors.aliyun.com/pypi/simple && \
        pip3 config set global.trusted-host mirrors.aliyun.com; \
	pip3 config set global.index-url https://pypi.loongnix.cn/loongson/pypi/+simple && \
	pip3 config set global.trusted-host pypi.loongnix.cn; \
	pip install pipx;\
	mkdir -p /etc/uv && \
        echo "[[index]]" > /etc/uv/uv.toml && \
        echo 'url = "https://pypi.loongnix.cn/loongson/pypi/+simple"' >> /etc/uv/uv.toml && \
        echo "default = true" >> /etc/uv/uv.toml; \
    fi; 

ENV PYTHONDONTWRITEBYTECODE=1 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
ENV PATH=/root/.local/bin:$PATH

# 安装 Node.js from tar.gz for LoongArch or custom env
RUN --mount=type=cache,id=ragflow_apt,target=/var/cache/apt,sharing=locked \
    apt purge -y nodejs npm cargo && \
    apt autoremove -y && \
    apt update && apt install -y curl xz-utils ca-certificates && \
    mkdir -p /opt/node && \
    curl -fsSL https://ftp.loongnix.cn/nodejs/LoongArch/dist/v21.7.3/node-v21.7.3-linux-loong64.tar.gz \
      | tar -xz -C /opt/node --strip-components=1 && \
    ln -sf /opt/node/bin/node /usr/local/bin/node && \
    ln -sf /opt/node/bin/npm /usr/local/bin/npm && \
    ln -sf /opt/node/bin/npx /usr/local/bin/npx && \
    node -v && npm -v


# A modern version of cargo is needed for the latest version of the Rust compiler.
RUN apt update && apt install -y curl build-essential  && \
    curl --proto '=https' --tlsv1.2 -sSf https://rust-lang.loongnix.cn/rustup-init.sh | bash -s -- -y --profile minimal \
    && echo 'export PATH="/root/.cargo/bin:${PATH}"' >> /root/.bashrc

ENV PATH="/root/.cargo/bin:${PATH}"

RUN cargo --version && rustc --version && pip install --upgrade pip && pip install uv==0.6.17

# msssql ODBC闭源，RAGflow loongarch不支持msssql数据库
# Add msssql ODBC driver
# macOS ARM64 environment, install msodbcsql18.
# general x86_64 environment, install msodbcsql17.
#RUN --mount=type=cache,id=ragflow_apt,target=/var/cache/apt,sharing=locked \
#    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
#    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
#    apt update && \
#    arch="$(uname -m)"; \
#    if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then \
        # ARM64 (macOS/Apple Silicon or Linux aarch64)
#        ACCEPT_EULA=Y apt install -y unixodbc-dev msodbcsql18; \
#    else \
#        # x86_64 or others
#        ACCEPT_EULA=Y apt install -y unixodbc-dev msodbcsql17; \
#    fi || \
#    { echo "Failed to install ODBC driver"; exit 1; }
#RUN --mount=type=cache,id=ragflow_apt,target=/var/cache/apt,sharing=locked \
#    apt update && \
#    apt install -y unixodbc-dev freetds-dev tdsodbc


# Add dependencies of selenium
RUN --mount=type=bind,from=loongarch64/ragflow_deps_abi1,source=/lbrowser_3.3.2091.6-1.stable.loongarch64.deb,target=/lbrowser_3.3.2091.6-1.stable.loongarch64.deb \
#    dpkg -i /lbrowser_3.3.2091.6-1.stable.loongarch64.deb && \
    apt-get update && \
    apt-get install -f -y lbrowser man
RUN --mount=type=bind,from=loongarch64/ragflow_deps_abi1,source=/chromedriver_linux64.zip,target=/chromedriver_linux64.zip \
    unzip -j /chromedriver_linux64.zip chromedriver && \
    mv chromedriver /usr/local/bin/ && \
    rm -f /usr/bin/google-chrome

# https://forum.aspose.com/t/aspose-slides-for-net-no-usable-version-of-libssl-found-with-linux-server/271344/13
# aspose-slides on linux/arm64 is unavailable
RUN --mount=type=bind,from=loongarch64/ragflow_deps_abi1,source=/,target=/deps \
	dpkg -i /deps/libssl1.1_1.1.1d-0%2Blnd.12_loongarch64.deb


# builder stage
FROM base AS builder
USER root

WORKDIR /ragflow

# install dependencies from uv.lock file
# add pyarrow-libs so
# 解决torch lib库找不到2.4.26符号的问题
RUN python3 -m venv /ragflow/.venv \ 
	&& wget https://github.com/yzewei/arrow/releases/download/17.0.0/arrow-17.0.0.tar.gz -O /tmp/arrow-17.0.0.tar.gz \
	&& mkdir -p /opt/arrow-17.0.0 \
	&& tar -xzf /tmp/arrow-17.0.0.tar.gz -C /opt/arrow-17.0.0 --strip-components=1 \
	&& wget https://github.com/yzewei/gcc/releases/download/10.3.0/libstdc++-6.0.28.tar.gz -O /tmp/libstdc++-6.0.28.tar.gz \
	&& mkdir -p /opt/libc_2_36 \
	&& tar -xzf /tmp/libstdc++-6.0.28.tar.gz -C /opt/libc_2_36 \
	&& rm /tmp/arrow-17.0.0.tar.gz /tmp/libstdc++-6.0.28.tar.gz

ENV LD_LIBRARY_PATH="/opt/libc_2_36:/usr/lib/llvm-8/lib:/opt/arrow-17:$PATH"
ENV PATH="/ragflow/.venv/bin:$PATH"
COPY pyproject.toml ./
COPY requirements.txt requirements-full.txt ./
# https://github.com/astral-sh/uv/issues/10462
# uv records index url into uv.lock but doesn't failover among multiple indexes
RUN --mount=type=cache,id=ragflow_uv,target=/root/.cache/uv,sharing=locked \
    if [ "$NEED_MIRROR" == "1" ]; then \
        sed -i 's|pypi.org|mirrors.aliyun.com/pypi|g' uv.lock; \
    else \
        sed -i 's|mirrors.aliyun.com/pypi|pypi.org|g' uv.lock; \
    fi; \
     pip install --upgrade pip && pip install cmake==3.31.6; \
    if [ "$LIGHTEN" == "1" ]; then \
        pip install -r requirements.txt --no-cache-dir; \
    else \
        pip install -r requirements-full.txt --no-cache-dir; \
    fi


COPY web web
COPY docs docs
#RUN --mount=type=cache,id=ragflow_npm,target=/root/.npm,sharing=locked \
RUN cd web && npm install && npm run build

COPY .git /ragflow/.git

RUN version_info=$(git describe --tags --match=v* --first-parent --always); \
    if [ "$LIGHTEN" == "1" ]; then \
        version_info="$version_info slim"; \
    else \
        version_info="$version_info full"; \
    fi; \
    echo "RAGFlow version: $version_info"; \
    echo $version_info > /ragflow/VERSION

# production stage
FROM base AS production
USER root

WORKDIR /ragflow

# Copy Python environment and packages
ENV VIRTUAL_ENV=/ragflow/.venv
COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}
COPY --from=builder /opt /opt
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/libc_2_36:/usr/lib/llvm-8/lib:/opt/arrow-17:$LD_LIBRARY_PATH"
ENV PYTHONPATH=/ragflow/

COPY web web
COPY api api
COPY conf conf
COPY deepdoc deepdoc
COPY rag rag
COPY agent agent
COPY graphrag graphrag
COPY agentic_reasoning agentic_reasoning
COPY pyproject.toml ./

COPY docker/service_conf.yaml.template ./conf/service_conf.yaml.template
COPY docker/entrypoint.sh docker/entrypoint-parser.sh ./
RUN chmod +x ./entrypoint*.sh

# Copy compiled web pages
COPY --from=builder /ragflow/web/dist /ragflow/web/dist

COPY --from=builder /ragflow/VERSION /ragflow/VERSION
RUN mv /usr/lib/loongarch64-linux-gnu/libstdc++.so.6 /usr/lib/loongarch64-linux-gnu/libstdc++.so.6.bak && \
    ln -s /opt/libc_2_36/libstdc++.so.6 /usr/lib/loongarch64-linux-gnu/libstdc++.so.6
ENTRYPOINT ["./entrypoint.sh"]
