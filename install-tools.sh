#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERILATOR_VER="v5.026"
COCOTB_VER="2.0.1"
PYUVM_VER="4.0.1"
FIND_LIBPYTHON_VER="0.5.0"
SV2V_VER="v0.0.13"

# FIX: Since this script resides directly in the repository root, REPO_ROOT should point 
# to the current directory of the script, not the parent directory. Going up one level (..) 
# would install the tools outside the repository, causing paths like 'venv/bin/activate' to fail.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
TOOLS_DIR="$REPO_ROOT/tools"
VENV_DIR="$REPO_ROOT/venv"
VERILATOR_SRC_DIR="$TOOLS_DIR/verilator"
VERILATOR_INSTALL_DIR="$TOOLS_DIR/verilator-install"
SV2V_INSTALL_DIR="$TOOLS_DIR/sv2v-install"
ACTIVATE="$VENV_DIR/bin/activate"
BASHRC="$HOME/.bashrc"

mkdir -p "$TOOLS_DIR" "$SV2V_INSTALL_DIR/bin"

echo -e "${GREEN}=== TinyGPU Setup Script (Ubuntu/Debian) ===${NC}"
echo "This script installs:"
echo " • Verilator from source ($VERILATOR_VER)"
echo " • sv2v from pre-built binary ($SV2V_VER)"
echo " • Python venv with cocotb + helpers"
echo " • Repo-local PATH activation for repeatable runs"
echo " • Persistent ~/.bashrc PATH for always-available tools"
echo ""
echo "Install root: $TOOLS_DIR"
echo "Venv root:    $VENV_DIR"
echo ""

if ! command -v apt >/dev/null 2>&1; then
  echo -e "${RED}This installer currently supports Ubuntu/Debian systems with apt.${NC}"
  exit 1
fi

echo -e "${YELLOW}[1/6] Installing system dependencies...${NC}"
sudo apt update -y
sudo apt install -y \
  ca-certificates git curl wget unzip python3 python3-pip python3-venv \
  autoconf automake libtool make g++ flex bison libfl-dev \
  zlib1g-dev libgoogle-perftools-dev pkg-config help2man

echo -e "${YELLOW}[2/6] Building Verilator from source...${NC}"
if [ ! -x "$VERILATOR_INSTALL_DIR/bin/verilator" ]; then
  if [ ! -d "$VERILATOR_SRC_DIR/.git" ]; then
    git clone https://github.com/verilator/verilator.git "$VERILATOR_SRC_DIR"
  fi
  cd "$VERILATOR_SRC_DIR"
  git fetch --tags
  git checkout "$VERILATOR_VER"
  autoconf
  ./configure --prefix="$VERILATOR_INSTALL_DIR"
  make -j"$(nproc)"
  make install
  cd "$REPO_ROOT"
  echo -e "${GREEN}✓ Verilator installed at $VERILATOR_INSTALL_DIR${NC}"
else
  echo -e "${GREEN}✓ Verilator already installed, skipping build${NC}"
fi

# FIX: Building sv2v from source requires Haskell Stack, which takes a long time (10-20 mins) 
# and can easily fail due to compiler dependencies or network timeouts. We now download the 
# pre-compiled Linux binary from GitHub releases, which is fast and robust.
echo -e "${YELLOW}[3/6] Downloading sv2v binary...${NC}"
if [ ! -x "$SV2V_INSTALL_DIR/bin/sv2v" ]; then
  ZIP_FILE="$TOOLS_DIR/sv2v-Linux.zip"
  TEMP_DIR="$TOOLS_DIR/sv2v-temp"
  
  echo "Downloading pre-built sv2v $SV2V_VER from GitHub..."
  curl -sSL -o "$ZIP_FILE" "https://github.com/zachjs/sv2v/releases/download/$SV2V_VER/sv2v-Linux.zip"
  
  mkdir -p "$TEMP_DIR"
  unzip -q -o "$ZIP_FILE" -d "$TEMP_DIR"
  
  cp "$TEMP_DIR/sv2v-Linux/sv2v" "$SV2V_INSTALL_DIR/bin/sv2v"
  chmod +x "$SV2V_INSTALL_DIR/bin/sv2v"
  
  rm -rf "$TEMP_DIR" "$ZIP_FILE"
  echo -e "${GREEN}✓ sv2v installed at $SV2V_INSTALL_DIR/bin/sv2v${NC}"
else
  echo -e "${GREEN}✓ sv2v already installed, skipping download${NC}"
fi

echo -e "${YELLOW}[4/6] Creating Python virtual environment...${NC}"
if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi
source "$ACTIVATE"
pip install --upgrade pip setuptools wheel
pip install \
  "cocotb==$COCOTB_VER" \
  "pyuvm==$PYUVM_VER" \
  "find_libpython==$FIND_LIBPYTHON_VER"
deactivate

echo -e "${YELLOW}[5/6] Updating venv activation script...${NC}"
if [ -f "$ACTIVATE" ]; then
  sed -i '/# TINYGPU TOOLCHAIN PATHS/,/echo "\[TinyGPU\]/d' "$ACTIVATE" 2>/dev/null || true
  cat <<EOF2 >> "$ACTIVATE"
# TINYGPU TOOLCHAIN PATHS (added by tools/install.sh)
export VERILATOR_ROOT="$VERILATOR_INSTALL_DIR"
export SV2V_ROOT="$SV2V_INSTALL_DIR"
export PATH="$VERILATOR_INSTALL_DIR/bin:$SV2V_INSTALL_DIR/bin:\$PATH"
echo "[TinyGPU] Environment activated: Verilator + sv2v + cocotb ready"
EOF2
  echo -e "${GREEN}✓ venv activation updated${NC}"
fi

echo -e "${YELLOW}[6/6] Updating ~/.bashrc for persistent tool PATH...${NC}"
if [ -f "$BASHRC" ]; then
  sed -i '/# TINYGPU TOOL PATHS/,/# End TINYGPU TOOL PATHS/d' "$BASHRC" 2>/dev/null || true
  cat <<EOF3 >> "$BASHRC"
# TINYGPU TOOL PATHS
export VERILATOR_ROOT="$VERILATOR_INSTALL_DIR"
export SV2V_ROOT="$SV2V_INSTALL_DIR"
export PATH="$VERILATOR_INSTALL_DIR/bin:$SV2V_INSTALL_DIR/bin:$PATH"
# End TINYGPU TOOL PATHS
EOF3
  echo -e "${GREEN}✓ ~/.bashrc updated${NC}"
  echo -e "${YELLOW}NOTE: To use the tools in your current shell session, run:${NC}"
  echo -e "      source ~/.bashrc  -OR-  source venv/bin/activate"
else
  echo -e "${YELLOW}~/.bashrc not found, skipping persistent PATH update${NC}"
fi

echo ""
echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}TinyGPU setup complete${NC}"
echo ""
echo "Next steps:"
echo "  source venv/bin/activate"
echo "  verilator --version"
echo "  sv2v --version"
echo "  cocotb-config --version"
echo ""
echo -e "${GREEN}===========================================================${NC}"