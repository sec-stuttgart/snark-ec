# Quickstart Guide: Ballot Validity & Tally Hiding Benchmarks

This guide covers how to execute the zero-knowledge proof benchmarking suite using either a Docker container or a local native environment. 

### Prerequisites
Before starting with either method, ensure your local repository has pulled down all necessary submodules (specifically the Ligero implementation). Run this at the root of your project:
```bash
git submodule update --init --recursive
```

---

## 1. Running Benchmarks via Docker

The Dockerfile is configured to build a self-contained SageMath environment with Circom, SnarkJS, and the compiled Ligero backend. 

### Step 1: Build the Image
From the root of your repository (where the `Dockerfile` is located), build the image. This will take some time on the first run as it compiles Rust and C++ dependencies.
```bash
docker build -t zkp-benchmarks .
```

### Step 2: Run the Container with Volume Mapping
To ensure the benchmark results are saved back to your host machine, map a local `results` folder to the container’s `results` folder. 
```bash
# Creates a local results directory if it doesn't exist
mkdir -p results 

# Runs the container interactively and removes it upon exit
docker run -it --rm -v $(pwd)/results:/home/app/results zkp-benchmarks
```

### Step 3: Execute the Benchmark
The container's entrypoint automatically drops you into a `sage -sh` shell. From the `/home/app` directory, run the benchmark script against your target test suite configuration:
```bash
cd src
python benchmark.py test_suites/min_test_all.json
```
*(Note: Because you are inside the `sage -sh` environment, calling `python` automatically uses the SageMath Python interpreter).*

---

## 2. Local Native Setup (Ubuntu Environment)

If you prefer to run the pipeline directly on your host machine, you will need to replicate the container's build steps. The following instructions are optimized for an Ubuntu Linux environment.

### Step 1: Install System Dependencies & SageMath
Update your package manager and install the required C++ libraries, build tools, and SageMath:
```bash
sudo apt update && sudo apt install -y \
    build-essential cmake git curl npm nano ca-certificates \
    libgmp3-dev libboost-all-dev libssl-dev libsodium-dev libsimdjson-dev \
    wget sagemath
```

### Step 2: Install Rust & Circom v2
Circom is written in Rust. Install the Rust toolchain, compile Circom from source, and add it to your PATH:
```bash
# Install Rust
curl [https://sh.rustup.rs](https://sh.rustup.rs) -sSf | bash -s -- -y --profile minimal
source $HOME/.cargo/env

# Clone and build Circom
git clone [https://github.com/iden3/circom.git](https://github.com/iden3/circom.git)
cd circom
cargo build --release

# Add circom to your current PATH
export PATH="$(pwd)/target/release:$PATH"
cd ..
```

### Step 3: Install Modern Node.js & SnarkJS
The default Ubuntu repository often carries older Node versions. Install Node v18+ and SnarkJS globally:
```bash
curl -fsSL [https://deb.nodesource.com/setup_18.x](https://deb.nodesource.com/setup_18.x) | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g snarkjs
```

### Step 4: Compile the Ligero Backend
Navigate into your submodule and compile the C++ Ligero implementation specifically for the BN254 curve:
```bash
cd snark-ec/libiop_circom/libiop
mkdir -p build_BN254 && cd build_BN254
cmake .. -DCMAKE_BUILD_TYPE=Release -DBENCHMARK_ENABLE_TESTING=OFF -DUSE_BN254=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5
make -j$(nproc)
cd ../../../..
```

### Step 5: Download the Phase 2 Powers of Tau File
The pipeline requires a precomputed structured reference string (PTAU). Download it into the designated scripts folder:
```bash
mkdir -p src/scripts/ptau
wget -O src/scripts/ptau/powersOfTau28_hez_final_21.ptau \
    [https://circom.info/powersOfTau28_hez_final_21.ptau](https://circom.info/powersOfTau28_hez_final_21.ptau)
```

### Step 6: Execute the Benchmark
With all dependencies installed, you must invoke the benchmark script using SageMath's Python runtime so that the underlying `fullprove.py` script can access the `sage.all` libraries.

```bash
sage -python src/benchmark.py bv_pointlist_borda_sw_config.json
```