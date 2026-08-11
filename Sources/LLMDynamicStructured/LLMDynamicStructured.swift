// Compatibility module: structured output now lives in LLMClient, and this re-export keeps
// existing `import LLMDynamicStructured` lines compiling. Import LLMClient in new code.

@_exported import LLMClient
