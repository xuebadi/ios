# 🧠 学霸帝AI - 本地多模态AI助手

基于 **MNN** 推理引擎 + **Qwen2.5-VL-3B** 模型的中文 iOS 本地 AI 助手。

完全离线运行，保护隐私，无需网络连接。

![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![MNN](https://img.shields.io/badge/MNN-LLM%20Engine-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

---

## ✨ 功能特性

| 功能 | 说明 | 状态 |
|------|------|------|
| 📝 文本对话 | 本地 LLM 推理，支持 Qwen/DeepSeek 等 | ✅ |
| 📸 看图分析 | Qwen2.5-VL 多模态理解 | ✅ |
| 🎙️ 语音输入 | 语音识别转文字 (Speech.framework) | ✅ |
| 🧠 深度思考 | DeepSeek R1 风格推理链 | ✅ |
| 📱 模型市场 | 下载/管理本地模型 | ✅ |
| 🔧 硬件加速 | Metal GPU / CPU 推理 | ✅ |
| 💾 完全离线 | 无网络请求，数据不上传 | ✅ |
| 🌓 深色模式 | 自动跟随系统 | ✅ |

---

## 📱 支持的模型

| 模型 | 参数量 | 量化 | 推荐场景 |
|------|--------|------|----------|
| **Qwen2.5-VL-3B** | 3B | INT4 | 最佳平衡 (本项目默认) |
| **Qwen2.5-VL-7B** | 7B | INT4 | 高端设备，画质更佳 |
| **Qwen2.5-3B** | 3B | INT4 | 纯文本，轻量 |
| **DeepSeek-R1-1.5B** | 1.5B | INT4 | iPhone 友好，推理链强 |

> 📦 模型下载: [HuggingFace](https://huggingface.co/taobao-mnn) | [ModelScope](https://modelscope.cn/organization/MNN)

---

## 🏗️ 项目架构

```
XuebaAI/
├── Sources/
│   ├── App/
│   │   ├── AppDelegate.swift          # 应用入口
│   │   ├── SceneDelegate.swift        # 场景管理
│   │   ├── Info.plist                 # 应用配置
│   │   └── MNN-Bridging-Header.h     # C++ 桥接
│   ├── Models/
│   │   ├── Message.swift              # 消息模型
│   │   └── ChatModels.swift           # 对话/配置模型
│   ├── Views/
│   │   ├── HomeView.swift             # 首页 Tab 导航
│   │   ├── ChatView.swift             # 聊天界面
│   │   ├── SettingsView.swift         # 设置页面
│   │   └── ModelMarketView.swift      # 模型市场
│   ├── ViewModels/
│   │   └── ChatViewModel.swift        # 聊天逻辑 (MVVM)
│   └── Services/
│       └── MNNService.swift           # MNN 推理引擎封装
├── Resources/
│   └── Assets.xcassets/               # 资源目录
├── project.yml                         # XcodeGen 配置
├── build.sh                            # 构建脚本
└── README.md
```

**技术栈：**
- Swift 5.9 + SwiftUI
- MVVM 架构
- MNN LLM 推理引擎 (C++)
- Metal GPU 加速
- PhotosUI 相册访问
- Speech 语音识别
- XcodeGen 项目生成

---

## 🚀 快速开始

### 方式一：Demo 模式（无需 MNN）

```bash
git clone <your-repo>
cd xueba-ai/xueba-ai
./build.sh
```

> Demo 模式包含完整的 UI 和模拟推理，无需编译 MNN。

### 方式二：完整构建（MNN + Qwen 模型）

#### 步骤 1: 编译 MNN LLM 引擎

```bash
# 克隆 MNN
git clone https://github.com/alibaba/MNN.git
cd MNN

# iOS 编译 (启用 LLM + 视觉 + Metal)
sh package_scripts/ios/buildiOS.sh \
  -DMNN_ARM82=ON \
  -DMNN_LOW_MEMORY=ON \
  -DMNN_SUPPORT_TRANSFORMER_FUSE=ON \
  -DMNN_BUILD_LLM=ON \
  -DMNN_CPU_WEIGHT_DEQUANT_GEMM=ON \
  -DMNN_METAL=ON \
  -DMNN_BUILD_DIFFUSION=ON \
  -DMNN_BUILD_LLM_OMNI=ON \
  -DLLM_SUPPORT_AUDIO=ON \
  -DLLM_SUPPORT_VISION=ON \
  -DMNN_BUILD_OPENCV=ON
```

编译产物: `MNN-iOS-CPU-GPU/Static/MNN.framework`

#### 步骤 2: 导出 Qwen 模型

```bash
cd MNN/transformers/llm/export

pip install -r requirements.txt

# 导出 Qwen2.5-VL-3B (INT4 量化)
python llmexport.py \
  --path /path/to/Qwen2.5-VL-3B-Instruct \
  --export mnn \
  --quant_bit 4 \
  --hqq
```

#### 步骤 3: 构建 iOS App

```bash
# 复制 MNN.framework 到项目根目录
cp -r MNN-iOS-CPU-GPU/Static/MNN.framework /path/to/xueba-ai/

# 构建
cd /path/to/xueba-ai
./build.sh
```

#### 步骤 4: 运行

```bash
# 在 Xcode 中打开
open XuebaAI.xcodeproj

# 或命令行运行
xcrun simctl boot "iPhone 16 Pro"
xcrun simctl install "iPhone 16 Pro" ./DerivedData/Build/Products/Debug-iphonesimulator/XuebaAI.app
xcrun simctl launch "iPhone 16 Pro" com.xuebaai.app
```

---

## 🔧 Xcode 配置

首次打开项目需要：

1. **选择 Team**  
   `Signing & Capabilities → Team → Your Apple ID`

2. **添加 Bundle ID**  
   `Bundle Identifier: com.xuebaai.app`

3. **配置隐私权限**  
   Info.plist 中已配置，无需额外设置

4. **连接 MNN.framework**  
   确保 `Build Phases → Link Binary With Libraries` 包含 `MNN.framework`

---

## 📊 性能参考

| 设备 | 模型 | 后端 | 速度 |
|------|------|------|------|
| iPhone 15 Pro | Qwen2.5-VL-3B | Metal | ~25 tok/s |
| iPhone 14 Pro | Qwen2.5-VL-3B | Metal | ~18 tok/s |
| iPhone 15 | Qwen2.5-1.5B | CPU | ~15 tok/s |
| iPad Pro M2 | Qwen2.5-VL-7B | Metal | ~35 tok/s |

---

## ⚙️ 设置说明

| 选项 | 说明 |
|------|------|
| 后端 | CPU / Metal GPU |
| 线程数 | 建议设置为 CPU 核心数的一半 |
| 精度 | 低=FP16 / 标准=INT8 / 高=FP32 |
| Temperature | 控制回答随机性，0.7 适中 |
| Top-P | 控制词汇选择范围 |
| 深度思考 | 启用推理链 (DeepSeek 风格) |

---

## 📖 MNN LLM API 参考

MNN LLM 引擎提供以下核心接口（详见 `MNN-Bridging-Header.h`）：

```c
// 加载模型
void* session = MNNLLM_Load(model_dir, config_json);

// Tokenize
int* tokens = MNNLLM_Tokenize(session, text, &len);
char* text_out = MNNLLM_Detokenize(session, token);

// 流式推理
void* stream = MNNLLM_CreateStream(session, tokens, len, &params);
while (MNNLLM_Stream_HasNext(stream)) {
    int token = MNNLLM_Stream_Next(stream);
    char* text = MNNLLM_Detokenize(session, token);
    // 输出 text...
}

// 卸载
MNNLLM_Unload(session);
```

---

## ❓ 常见问题

**Q: 内存不足怎么办？**
A: 选择更小的模型（如 1.5B），或减少线程数

**Q: Metal 推理失败？**
A: 确认设备支持 Metal，且 `project.yml` 中 `DMNN_METAL=ON`

**Q: 模型文件放在哪里？**
A: App Documents/Models/ 目录下，或 App Bundle 的 LocalModel/ 目录

**Q: 如何添加自定义模型？**
A: 参考 `SettingsView.swift` 中的 `ModelInfo.defaultModels()` 添加模型信息

---

## 📄 License

MIT License - 详见 [LICENSE](LICENSE)

**鸣谢：**
- [Alibaba MNN](https://github.com/alibaba/MNN) - 高性能深度学习引擎
- [Qwen](https://github.com/QwenLM) - 通义千问大模型
- Apple SwiftUI & Metal

---

_🧠 学霸帝AI - 让 AI 在本地设备上为你服务_
