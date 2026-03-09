import ollama
import chromadb
import pypdf

chroma_client = chromadb.Client()
collection = chroma_client.get_or_create_collection("rag")

def upload_pdf(file_path):
    with open(file_path, "rb") as file:
        pdf_reader = pypdf.PdfReader(file)
        id = 0
        for page in pdf_reader.pages:
            collection.add(
                documents = [page.extract_text()],
                ids = [f"{file_path}{id}"]
        )
        id += 1

upload_pdf("The-Wizard-of-Oz-1.pdf")
#upload_pdf("b.pdf")
#upload_pdf("c.pdf")

query = input(">>>")
closestPages = collection.query(
    query_texts = [query],
    n_results = 3
)

response = ollama.chat(
    model = "llama3.1",
    messages = [
        {
            "role": "system",
            "content": closestPages["documents"][0][0]
        },
        #{
        #    "role": "system",
        #    "content": closestPages["documents"][0][1]
        #},
        #{
        #    "role": "system",
        #    "content": closestPages["documents"][0][2]
        #},
        {
            "role": "user",
            "content": query
        }
    ]
)

print (response["message"]["content"])
