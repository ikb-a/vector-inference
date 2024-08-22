from openai import OpenAI


#URL="http://gpu017:8080/v1"

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('url')
args = parser.parse_args()
URL=args.url

# The url is located in the .vLLM_model-variant_url file in the corresponding model directory.
client = OpenAI(base_url=URL, api_key="EMPTY")

# Update the model path accordingly
completion = client.chat.completions.create(
  model="/model-weights/Llama-2-7b-chat-hf",
  #timeout=2,
  messages=[
    {"role": "system", "content": "You are yourself."},
    {"role": "user", "content": "Who are you?"},
  ]
)

print(completion)
