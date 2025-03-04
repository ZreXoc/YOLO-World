# Base image with CUDA support
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS base

# Set environment variables
ENV FORCE_CUDA="1" \
    MMCV_WITH_OPS=1 \
    DEBIAN_FRONTEND=noninteractive \
    DOCKER_BUILDKIT=1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    TORCH_CUDA_ARCH_LIST="8.0;8.0+PTX"
RUN cat <<'EOF' > /etc/apt/sources.list
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.osa.moe/ubuntu/ jammy main restricted universe multiverse
# deb-src https://mirrors.osa.moe/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.osa.moe/ubuntu/ jammy-updates main restricted universe multiverse
# deb-src https://mirrors.osa.moe/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.osa.moe/ubuntu/ jammy-backports main restricted universe multiverse
# deb-src https://mirrors.osa.moe/ubuntu/ jammy-backports main restricted universe multiverse

# deb https://mirrors.osa.moe/ubuntu/ jammy-security main restricted universe multiverse
# # deb-src https://mirrors.osa.moe/ubuntu/ jammy-security main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
# deb-src http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

# 预发布软件源，不建议启用
# deb https://mirrors.osa.moe/ubuntu/ jammy-proposed main restricted universe multiverse
# # deb-src https://mirrors.osa.moe/ubuntu/ jammy-proposed main restricted universe multiverse
EOF

# Install system dependencies
RUN apt-get --allow-unauthenticated update && apt-get --allow-unauthenticated install -y --no-install-recommends \
    build-essential \
    python3-pip \
    libgl1-mesa-glx \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libglib2.0-0 \
    git \
    python3-dev \
    python3-wheel \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python dependencies
FROM base AS python_deps

RUN pip3 install --upgrade pip wheel \
    && pip config set global.index-url https://mirrors.osa.moe/pypi/web/simple \
    && pip3 install torch==2.1.2 torchvision==0.16.2 torchaudio==2.1.2 -f https://mirror.sjtu.edu.cn/pytorch-wheels/cu124 \
    && pip3 install --no-cache-dir \
        gradio==5.6.0 \
        opencv-python==4.9.0.80 \
        supervision \
        mmengine==0.10.4 \
        setuptools \
        openmim \
        onnx \
        onnxsim
RUN mim install mmcv==2.1.0 \
    && mim install mmdet==3.3.0 \
    && mim install mmengine==0.10.6\
    && mim install mmyolo==0.6.0 \
    && pip3 install git+https://github.com/lvis-dataset/lvis-api \
    && pip3 install numpy==1.23.5 \
    && pip3 cache purge

# Clone and install YOLO-World

FROM python_deps AS yolo_world
#RUN git clone --recursive https://github.com/AILab-CVC/YOLO-World /yolo/

COPY . /yolo

FROM yolo_world AS final

WORKDIR /yolo
RUN pip3 install ./third_party/mmyolo \
    && pip3 install -e .[demo] \
    && pip3 cache purge \
    && mkdir /weights/ \
    && chmod 775 /yolo/configs/*/*

# Final stage
# FROM yolo_world AS final

ARG MODEL="yolo_world_v2_l_vlpan_bn_2e-3_100e_4x8gpus_obj365v1_goldg_train_lvis_minival.py"
ARG WEIGHT="yolo_world_v2_l_obj365v1_goldg_cc3mv2_pretrain-2f3a4a22.pth"

# Create weights directory and set permissions

# Optionally download weights (commented out by default)
#RUN curl -o /weights/$WEIGHT -L https://huggingface.co/wondervictor/YOLO-World/resolve/main/$WEIGHT

EXPOSE 8080

# Set the default command
CMD ["bash"]
