import ollama
import chromadb

chroma_client = chromadb.Client()
collection = chroma_client.get_or_create_collection("rag")

# ── Cargar el texto (es .txt, no PDF) ─────────────────────────────
def upload_txt(file_path, chunk_size=500):
    with open(file_path, "r", encoding="utf-8") as f:
        text = f.read()

    # Dividir en chunks por caracteres
    chunks = [text[i:i+chunk_size] for i in range(0, len(text), chunk_size)]

    for idx, chunk in enumerate(chunks):
        collection.add(
            documents=[chunk],
            ids=[f"{file_path}_{idx}"]
        )
    print(f"✅ {len(chunks)} chunks indexados desde {file_path}")

upload_txt("percy_jackson.txt")

# ── Loop de preguntas ──────────────────────────────────────────────
while True:
    query = input("\n>>> ").strip()
    if query.lower() in ("salir", "exit", "quit"):
        break

    closest = collection.query(
        query_texts=[query],
        n_results=3
    )

    # Juntar los 3 fragmentos más relevantes como contexto
    context = "\n\n".join(closest["documents"][0])

    response = ollama.chat(
        model="llama3.1",
        messages=[
            {"role": "system", "content": context},
            {"role": "user",   "content": query}
        ]
    )

    print(f"\nPercy: {response['message']['content']}")