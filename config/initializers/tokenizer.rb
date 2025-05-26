# So the tokenizer is pretty expensive
# If we recreate it everytime we need it, we run out of memory cuz ruby's garbage collector can't keep up
TOKENIZER = Tokenizers::Tokenizer.from_pretrained("voyageai/voyage-3-large")
