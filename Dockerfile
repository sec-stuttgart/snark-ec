# Stage 1: Builder (Circom & Ligero)
# ==========================================
FROM sagemath/sagemath:latest
USER root
SHELL ["/bin/bash", "-c"]

WORKDIR /home/app
COPY src /home/app/src
COPY libs /home/app/libs

# Avoid tzdata prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools and dependencies
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    curl \
    npm \
    nano \
    ca-certificates \
    libgmp3-dev \
    libboost-all-dev \
    libssl-dev \
    libsodium-dev \
    libsimdjson-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/app

# Install Rust (required for Circom v2 and Icicle)
ENV HOME=/root
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Circom v2
RUN git clone https://github.com/iden3/circom.git && \
    cd circom && \
    cargo build --release

RUN echo 'export PATH="/home/app/circom/target/release"' >> /root/.bashrc
ENV PATH="/home/app/circom/target/release:${PATH}"

# Copy Ligero source into builder
# (Ensure libiop is in your docker build context)
COPY snark-ec/libiop_circom/libiop /home/app/libiop

# Build ligero for BN254
WORKDIR /home/app/libiop
RUN mkdir build_BN254 && cd build_BN254 && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DBENCHMARK_ENABLE_TESTING=OFF -DUSE_BN254=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5 && \
    make -j$(nproc)

# Install modern Node.js (v18) and SnarkJS
# The default Ubuntu nodejs is often too old for modern ZK tooling
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g snarkjs

# Add ptau file 
WORKDIR /home/app/src/scripts/ptau
RUN wget -O powersOfTau28_hez_final_21.ptau \
    https://circom.info/powersOfTau28_hez_final_21.ptau

# Setting Working directory
WORKDIR /home/app
ENTRYPOINT ["sage"]
CMD ["-sh"]
