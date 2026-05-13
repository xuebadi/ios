# Qwen2.5-VL 模型导出指南

本文档说明如何将 Qwen2.5-VL 系列模型导出为 MNN 格式，供 iOS App 使用。

## 环境准备

### 1. 克隆 MNN 仓库

```bash
git clone https://github.com/alibaba/MNN.git
cd MNN
```

### 2. 安装 Python 依赖

```bash
cd transformers/llm/export
pip install -r requirements.txt
```

**关键依赖：**
- `torch >= 2.0`
- `transformers`
- `optimum` (用于量化)
- `hqq` (推荐量化后端)
- `accelerate`

### 3. 安装 git-lfs

```bash
brew install git-lfs   # macOS
git lfs install
```

## 导出命令

### Qwen2.5-VL-3B-Instruct (推荐)

```bash
cd MNN/transformers/llm/export

python llmexport.py \
  --path /path/to/Qwen2.5-VL-3B-Instruct \
  --export mnn \
  --quant_bit 4 \
  --quant_block 64 \
  --hqq \
  --dst_path ./output/Qwen2.5-VL-3B-Instruct-MNN
```

### Qwen2.5-VL-7B-Instruct (高端设备)

```bash
python llmexport.py \
  --path /path/to/Qwen2.5-VL-7B-Instruct \
  --export mnn \
  --quant_bit 4 \
  --quant_block 128 \
  --hqq \
  --dst_path ./output/Qwen2.5-VL-7B-Instruct-MNN
```

### 纯文本模型 (更小更快)

```bash
# Qwen2.5-1.5B
python llmexport.py \
  --path /path/to/Qwen2.5-1.5B-Instruct \
  --export mnn \
  --quant_bit 4 \
  --hqq \
  --dst_path ./output/Qwen2.5-1.5B-Instruct-MNN
```

## 参数说明

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `--quant_bit` | 量化位数 | 4 (INT4) |
| `--quant_block` | 量化块大小 | 64-128 |
| `--hqq` | 启用 HQQ 量化算法 (精度更高) | 推荐加 |
| `--awq` | 启用 AWQ 量化算法 | 可选 |
| `--seperate_embed` | 分离 embedding 权重 | 可选 |
| `--lora_path` | 合并 LoRA 权重 | 可选 |

## 输出文件

导出完成后，`--dst_path` 目录下会生成以下文件：

```
Qwen2.5-VL-3B-Instruct-MNN/
├── config.json          # MNN 运行时配置
├── llm.mnn             # MNN 模型图定义
├── llm.mnn.weight      # MNN 模型权重 (INT4)
├── llm.mnn.json        # 模型结构 JSON
├── tokenizer.mtok      # Tokenizer 文件
├── embeddings_bf16.bin  # Embedding 权重 (部分模型)
└── llm_config.json     # 模型元信息
```

## iOS 集成

### 1. 复制到 App Bundle

```bash
# 复制到项目
cp -r ./output/Qwen2.5-VL-3B-Instruct-MNN \
  /path/to/XuebaAI/Sources/Resources/LocalModel/

# 或复制到 Documents (用户下载的模型)
```

### 2. 更新模型配置

在 `SettingsView.swift` 中更新 `ModelInfo`:

```swift
ModelInfo(
    id: "Qwen2.5-VL-3B-Instruct",
    name: "Qwen2.5-VL-3B-Instruct",
    size: "~3.6 GB",
    parameters: "3B",
    quantization: "INT4",
    downloadURL: "local://bundle",
    category: .omni,
    tags: ["Qwen", "多模态", "视觉", "中文"],
    isDownloaded: true  // Bundle 内置
)
```

### 3. 运行时加载

```swift
// 本地 Bundle 模型
let bundlePath = Bundle.main.resourcePath!
let modelPath = "\(bundlePath)/LocalModel/Qwen2.5-VL-3B-Instruct-MNN"

await mnnService.initialize(modelPath: modelPath)
```

## 从 ModelScope 下载原始模型

```bash
# 安装 modelscope
pip install modelscope

# 下载 Qwen2.5-VL-3B
python -c "
from modelscope import snapshot_download
snapshot_download('Qwen/Qwen2.5-VL-3B-Instruct', 
                  cache_dir='./models')
"
```

## 从 HuggingFace 下载

```bash
# 安装 huggingface-hub
pip install huggingface-hub

# 下载
huggingface-cli download Qwen/Qwen2.5-VL-3B-Instruct \
  --local-dir ./models/Qwen2.5-VL-3B-Instruct \
  --local-dir-use-symlinks False
```

## 验证导出结果

```bash
# 在 Mac/Linux 上运行测试
cd MNN
./build/llm_demo ./output/Qwen2.5-VL-3B-Instruct-MNN/config.json "你好"
```

如果输出正常，模型即可用于 iOS App。

## 模型下载链接

| 模型 | HuggingFace | ModelScope |
|------|-------------|------------|
| Qwen2.5-VL-3B-Instruct | [HF Link](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct) | [MS Link](https://modelscope.cn/Qwen/Qwen2.5-VL-3B-Instruct) |
| Qwen2.5-VL-7B-Instruct | [HF Link](https://huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct) | [MS Link](https://modelscope.cn/Qwen/Qwen2.5-VL-7B-Instruct) |
| Qwen2.5-1.5B-Instruct | [HF Link](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct) | [MS Link](https://modelscope.cn/Qwen/Qwen2.5-1.5B-Instruct) |

---

**提示：** 首次运行建议先用小模型（0.5B 或 1.5B）验证流程，确认无误后再导出 3B/7B 大模型。
