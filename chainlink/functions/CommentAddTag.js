const promptText = args[0]; // 把用户输入当作 prompt
const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=AIzaSyDAxxv2iq4miqPHqXxLqwyOYTXubQWdLKQ`;

// 构建 HTTP 请求 payload
const body = {
  system_instruction: {
    parts: [
      {
        text: 'Classify crypto sentiment: POS for positive/bullish, NEG for negative/bearish, NEU for neutral. Output only: POS, NEG, or NEU'
      }
    ]
  },
  contents: [
    {
      parts: [
        {
          text: promptText
        }
      ]
    }
  ],
  generationConfig: {
    thinkingConfig: {
      thinkingBudget: 0
    }
  }
};

const response = await Functions.makeHttpRequest({
  url: url,
  method: "POST",
  headers: {
    "Content-Type": "application/json"
  },
  data: body
});

// 错误处理
if (response.error) {
  throw Error(`Request failed: ${response.error}`);
}

// 提取模型返回的 text 内容（结构依赖 Gemini 的返回）
const resultText = response.data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "NEU";

return Functions.encodeString(resultText);
