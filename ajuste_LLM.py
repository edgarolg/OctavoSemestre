import ollama
import chromadb

chroma_client = chromadb.Client()
collection = chroma_client.get_or_create_collection("rag")

def upload_txt(file_path, chunk_size=500):
    with open(file_path, "r", encoding="utf-8") as f:
        text = f.read()

    chunks = [text[i:i+chunk_size] for i in range(0, len(text), chunk_size)]

    for idx, chunk in enumerate(chunks):
        collection.add(
            documents=[chunk],
            ids=[f"{file_path}_{idx}"]
        )
    print(f"✅ {len(chunks)} chunks indexados desde {file_path}")

upload_txt("percy_jackson.txt")

while True:
    query = input("\n>>> ").strip()
    if query.lower() in ("salir", "exit", "quit"):
        break

    closest = collection.query(
        query_texts=[query],
        n_results=3
    )

    context = "\n\n".join(closest["documents"][0])

    response = ollama.chat(
        model="llama3.2",
        messages=[
            {"role": "system", "content": context},
            {"role": "user",   "content": query}
        ]
    )

    print(f"\nPercy: {response['message']['content']}")