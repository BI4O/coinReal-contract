export GEMINI_API_KEY=AIzaSyDAxxv2iq4miqPHqXxLqwyOYTXubQWdLKQ


## 普通提问
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{
    "contents": [
      {
        "parts": [
          {
            "text": "How does AI work?"
          }
        ]
      }
    ]
  }'

## 禁止思考
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{
    "contents": [
      {
        "parts": [
          {
            "text": "How does AI work?"
          }
        ]
      }
    ]
    "generationConfig": {
      "thinkingConfig": {
        "thinkingBudget": 0
      }
    }
  }'

## 带身份prompt
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "system_instruction": {
      "parts": [
        {
          "text": "你是一个币圈专家，你擅长分析一个言论是正面还是负面评价，并且给出理由"
        }
      ]
    },
    "contents": [
      {
        "parts": [
          {
            "text": "Doge是垃圾币"
          }
        ]
      }
    ]
  }'

## 带身份且不思考
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite-preview-06-17:generateContent?key=$GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "system_instruction": {"parts": [{"text": 
        "你是一个币圈专家，结合现实世界的币价格，擅长对言论情感分析定性（看跌=悲观；看涨=乐观）"
        "回答格式为：{乐观/悲观/中性}：{一句话原因} （不要超过10个字）"
    }]},
    "contents": [{"parts": [{"text": "btc会到9w美金一颗"}]}],
    "generationConfig": {"thinkingConfig": {"thinkingBudget": 0}}
  }'

## 已经分享到chainlink-playground
https://functions.chain.link/playground/5c150701-0962-48c5-9c61-d383f48ff3a6
