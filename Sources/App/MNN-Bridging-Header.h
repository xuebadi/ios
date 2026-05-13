//
//  MNN-Bridging-Header.h
//  学霸帝AI
//
//  MNN C++ 引擎桥接头文件
//  将 C++ MNN LLM API 暴露给 Swift 使用
//

#ifndef MNN_Bridging_Header_h
#define MNN_Bridging_Header_h

// ============================================================
// MNN 核心头文件 (来自 libMNN.dylib)
// ============================================================
#include <MNN/MNN.h>
#include <MNN/Tensor.hpp>
#include <MNN/ImageProcess.hpp>

// ============================================================
// MNN LLM 推理引擎头文件
// 完整路径: MNN/transformers/llm/include/MNNLLM.h
// ============================================================

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - 模型加载

/// 加载 MNN LLM 模型
/// @param model_dir 模型文件夹路径 (含 config.json, llm.mnn, tokenizer.mtok 等)
/// @param config_json MNN 运行时配置 JSON 字符串
/// @return Session 句柄，失败返回 NULL
void* MNNLLM_Load(const char* model_dir, const char* config_json);

/// 卸载模型并释放资源
/// @param session 之前 MNNLLM_Load 返回的句柄
void MNNLLM_Unload(void* session);

// MARK: - Tokenizer

/// 对文本进行 Tokenize
/// @param session 模型会话句柄
/// @param text 输入文本
/// @return token 数组 (需要调用 MNNLLM_FreeTokens 释放)
int* MNNLLM_Tokenize(void* session, const char* text, int* out_length);

/// 将 token 转换回文本
/// @param session 模型会话句柄
/// @param token 要解码的 token ID
/// @return 解码后的文本 (需要调用 MNNLLM_FreeString 释放)
char* MNNLLM_Detokenize(void* session, int token);

/// 释放 token 数组
void MNNLLM_FreeTokens(int* tokens);

/// 释放字符串
void MNNLLM_FreeString(char* str);

// MARK: - 推理

/// 推理参数结构体
typedef struct {
    int max_new_tokens;      // 最大生成长度
    float temperature;       // 温度
    float top_p;            // Top-P
    int top_k;              // Top-K
    float repeat_penalty;   // 重复惩罚
    int stream_interval;     // 流式输出间隔
    int* stop_tokens;       // 停止 token 数组
    int stop_token_count;   // 停止 token 数量
    void* vision_data;      // 视觉数据 (可选)
} MNNInferenceParams;

/// 创建推理流
/// @param session 模型会话句柄
/// @param input_tokens 输入 token 数组
/// @param input_length 输入长度
/// @param params 推理参数
/// @return 推理流句柄
void* MNNLLM_CreateStream(void* session, int* input_tokens, int input_length, MNNInferenceParams* params);

/// 获取下一个 token (流式推理)
/// @param stream 推理流句柄
/// @return 下一个 token ID，-1 表示结束
int MNNLLM_Stream_Next(void* stream);

/// 检查流是否还有更多 token
/// @param stream 推理流句柄
/// @return 1 还有，0 已结束
int MNNLLM_Stream_HasNext(void* stream);

/// 销毁推理流
/// @param stream 推理流句柄
void MNNLLM_DestroyStream(void* stream);

/// 单次推理 (非流式)
/// @param session 模型会话句柄
/// @param input_tokens 输入 token 数组
/// @param input_length 输入长度
/// @param params 推理参数
/// @param output 输出文本 (需要调用 MNNLLM_FreeString 释放)
void MNNLLM_Generate(void* session, int* input_tokens, int input_length,
                     MNNInferenceParams* params, char** output);

// MARK: - 视觉 (Qwen2.5-VL)

/// 预处理图像数据
/// @param session 模型会话句柄
/// @param image_path 图像文件路径
/// @param width 输出宽度
/// @param height 输出高度
/// @return 预处理后的张量数据
void* MNNLLM_PreprocessImage(void* session, const char* image_path, int width, int height);

/// 释放图像数据
void MNNLLM_FreeImageData(void* image_data);

/// 获取图像的视觉 token 数
/// @param session 模型会话句柄
/// @param image_data 预处理后的图像数据
/// @return 视觉 token 数量
int MNNLLM_GetVisionTokenCount(void* session, void* image_data);

// MARK: - 内存管理

/// 获取当前内存使用 (bytes)
uint64_t MNNLLM_GetMemoryUsage(void* session);

/// 获取当前 VRAM 使用 (bytes)
uint64_t MNNLLM_GetVRAMUsage(void* session);

/// 获取推理速度 (tokens/s)
float MNNLLM_GetTokenSpeed(void* session);

// MARK: - 配置

/// 更新推理参数
/// @param session 模型会话句柄
/// @param params 新的推理参数
void MNNLLM_UpdateParams(void* session, MNNInferenceParams* params);

/// 获取模型信息
/// @param session 模型会话句柄
/// @param key 信息键名 (如 "model_name", "vocab_size", "hidden_size")
/// @return 信息值字符串 (需要调用 MNNLLM_FreeString 释放)
char* MNNLLM_GetModelInfo(void* session, const char* key);

// MARK: - 错误处理

/// 获取最后一次错误信息
/// @return 错误信息字符串
const char* MNNLLM_GetLastError(void);

#ifdef __cplusplus
}
#endif

#endif /* MNN_Bridging_Header_h */
