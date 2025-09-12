# So the tokenizer is pretty expensive
# If we recreate it everytime we need it, we run out of memory cuz ruby's garbage collector can't keep up
QWEN_TOKENIZER = Tokenizers::Tokenizer.from_file(Rails.root.join("config/tokenizers/qwen-8b.json"))
