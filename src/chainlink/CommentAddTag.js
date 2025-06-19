const promptText = args[0]; // 把用户输入当作 prompt
const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=AIzaSyDAxxv2iq4miqPHqXxLqwyOYTXubQWdLKQ`;

// 构建 HTTP 请求 payload
const body = {
  system_instruction: {
    parts: [
      {
        text: "You are a crypto market sentiment analysis expert. Your task is to classify the sentiment of a given crypto-related statement into one of three categories: POS (Positive): The statement clearly expresses bullish or optimistic sentiment, especially in the context of current or target price. NEG (Negative): The statement clearly expresses bearish or pessimistic sentiment, especially if it expects a drop or criticizes a coin. NEU (Neutral or Mixed): The statement contains mixed, unclear, or ambiguous opinions, or lacks strong sentiment. Always consider current or referenced market price if applicable. For example, saying 'BTC will reach $30,000' can be pessimistic if BTC is already at $60,000. Output strictly one of: POS / NEG / NEU"
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
const resultText = response.data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "EMPTY";

return Functions.encodeString(resultText);
