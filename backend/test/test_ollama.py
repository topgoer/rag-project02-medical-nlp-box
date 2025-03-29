from langchain_community.llms import Ollama

# Ensure Ollama is running and serving the model you want to use
ollama = Ollama(model="llama3.1:70b")

# Now you can use the model through Langchain
response = ollama("What is the capital of France?")
print(response)