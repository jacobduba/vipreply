# So the tokenizer is pretty expensive
# If we recreate it everytime we need it, we run out of memory cuz ruby's garbage collector can't keep up
# VOYAGE_TOKENIZER = Tokenizers::Tokenizer.from_pretrained("voyageai/voyage-3-large")
# To find the tokenizer file for Cohere basically I had to go to https://docs.cohere.com/reference/list-models?explorer=true
# Yes thats the api. And run the list models. Search for the embedding model you want... it has a url with the tokenizer
COHERE_TOKENIZER = Tokenizers::Tokenizer.from_file(Rails.root.join("config/tokenizers/embed-v4.0.json"))
