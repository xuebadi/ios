#!/bin/bash
# ============================================================
# 学霸帝AI - iOS 构建脚本
# Build: ./build.sh
# Clean: ./build.sh --clean
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
XCODEPROJ="$PROJECT_DIR/XuebaAI.xcodeproj"
SCHEME="XuebaAI"
TEAM_ID="${DEVELOPMENT_TEAM:-}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# 清理函数
do_clean() {
    info "清理构建产物..."
    rm -rf "$PROJECT_DIR/XuebaAI.xcodeproj"
    rm -rf ~/Library/Developer/Xcode/DerivedData/XuebaAI-*
    rm -rf "$PROJECT_DIR/build"
    success "清理完成"
}

# ============================================================
# 步骤 0: 检查参数
# ============================================================
if [[ "$1" == "--clean" ]]; then
    do_clean
    exit 0
fi

# ============================================================
# 步骤 1: 检查 XcodeGen
# ============================================================
if ! command -v xcodegen &> /dev/null; then
    error "XcodeGen 未安装"
    echo ""
    echo "安装方法:"
    echo "  brew install xcodegen"
    echo ""
    echo "或使用 Mint:"
    echo "  mint install XcodeGen/XcodeGen"
    exit 1
fi

info "XcodeGen version: $(xcodegen version)"

# ============================================================
# 步骤 2: 检查 Xcode
# ============================================================
if ! command -v xcodebuild &> /dev/null; then
    error "Xcode Command Line Tools 未安装"
    echo ""
    echo "请从 App Store 安装 Xcode"
    exit 1
fi

info "Xcode: $(xcodebuild -version 2>/dev/null | head -1)"

# ============================================================
# 步骤 3: 检查 MNN.framework
# ============================================================
MNN_FRAMEWORK="$PROJECT_DIR/MNN.framework"
if [[ ! -d "$MNN_FRAMEWORK" ]]; then
    warn "MNN.framework 未找到"
    echo ""
    echo "请先编译 MNN 引擎:"
    echo ""
    echo "  git clone https://github.com/alibaba/MNN.git"
    echo "  cd MNN"
    echo "  sh package_scripts/ios/buildiOS.sh \\"
    echo "    -DMNN_ARM82=ON \\"
    echo "    -DMNN_LOW_MEMORY=ON \\"
    echo "    -DMNN_SUPPORT_TRANSFORMER_FUSE=ON \\"
    echo "    -DMNN_BUILD_LLM=ON \\"
    echo "    -DMNN_CPU_WEIGHT_DEQUANT_GEMM=ON \\"
    echo "    -DMNN_METAL=ON \\"
    echo "    -DMNN_BUILD_DIFFUSION=ON \\"
    echo "    -DMNN_BUILD_LLM_OMNI=ON \\"
    echo "    -DLLM_SUPPORT_AUDIO=ON \\"
    echo "    -DLLM_SUPPORT_VISION=ON \\"
    echo "    -DMNN_BUILD_OPENCV=ON"
    echo ""
    echo "  然后将生成的 MNN-iOS-CPU-GPU/Static/MNN.framework 复制到项目根目录"
    echo ""
    read -p "继续以 Demo 模式构建? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    warn "将以 Demo 模式构建（无真实 MNN 推理）"
    # 创建占位 framework 避免编译错误
    mkdir -p "$MNN_FRAMEWORK"
fi

# ============================================================
# 步骤 4: 生成 Xcode 项目
# ============================================================
info "生成 Xcode 项目..."
cd "$PROJECT_DIR"
xcodegen generate

if [[ ! -d "$XCODEPROJ" ]]; then
    error "Xcode 项目生成失败"
    exit 1
fi
success "Xcode 项目生成成功"

# ============================================================
# 步骤 5: 设置 Team ID (如果提供了)
# ============================================================
if [[ -n "$TEAM_ID" ]]; then
    info "设置 Team ID: $TEAM_ID"
fi

# ============================================================
# 步骤 6: 检查可用模拟器
# ============================================================
info "检查可用模拟器..."
SIMULATORS=$(xcrun simctl list devices available | grep -E "iPhone|iPad" | head -10)
if [[ -z "$SIMULATORS" ]]; then
    warn "未找到模拟器"
    SIMULATOR="iPhone 16 Pro"
else
    SIMULATOR=$(echo "$SIMULATORS" | head -1 | sed 's/.*(\([^)]*\)).*/\1/' | xargs)
    [[ -z "$SIMULATOR" ]] && SIMULATOR="iPhone 16 Pro"
fi
info "将使用模拟器: $SIMULATOR"

# ============================================================
# 步骤 7: 构建
# ============================================================
BUILD_CMD="xcodebuild -project XuebaAI.xcodeproj -scheme XuebaAI"
BUILD_CMD+=" -configuration Debug"
BUILD_CMD+=" -destination 'platform=iOS Simulator,name=$SIMULATOR'"
BUILD_CMD+=" -derivedDataPath ./DerivedData"
BUILD_CMD+=" build"

if [[ -n "$TEAM_ID" ]]; then
    BUILD_CMD+=" DEVELOPMENT_TEAM=$TEAM_ID CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
fi

info "开始构建..."
echo ""

eval "$BUILD_CMD" 2>&1 | tail -50

BUILD_STATUS=${PIPESTATUS[0]}

echo ""

if [[ $BUILD_STATUS -eq 0 ]]; then
    success "✅ 构建成功!"
    echo ""
    echo "============================================"
    echo "  运行应用:"
    echo ""
    echo "  1. 打开 Xcode:"
    echo "     open XuebaAI.xcodeproj"
    echo ""
    echo "  2. 选择模拟器并点击 Run (⌘R)"
    echo ""
    echo "  3. 首次运行会自动打开模拟器"
    echo ""
    echo "  注意: Demo 模式下无需真实模型"
    echo "        可正常使用 UI 和模拟推理"
    echo "============================================"
    echo ""
else
    error "❌ 构建失败 (Exit code: $BUILD_STATUS)"
    echo ""
    echo "调试建议:"
    echo "  1. 检查 XcodeGen 版本: xcodegen version"
    echo "  2. 检查 MNN.framework: ls -la MNN.framework"
    echo "  3. 查看完整错误: xcodebuild ... 2>&1 | grep -A 5 error:"
    echo ""
    exit $BUILD_STATUS
fi
