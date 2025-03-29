from pymilvus import model
from pymilvus import MilvusClient
from dotenv import load_dotenv
import os

load_dotenv()

# collection_name = "concepts_with_desc_n_synonyms"
collection_name = "Symptoms_SNOMED"

class StdService:
    def __init__(self):
        self.openai_ef = model.dense.OpenAIEmbeddingFunction()
        # self.client = MilvusClient("/home/huangjia/Documents/06_EVYD/milvus_db/snomed_syn_openai-3-small.db")
        self.client = MilvusClient("/home/huangjia/Documents/06_EVYD/milvus_db/condition_syn.db")
        self.client.load_collection(collection_name)

    def process(self, query):
        query_embeddings = self.openai_ef([query])
        search_result = self.client.search(
            collection_name=collection_name,
            # filter=f"domain_id == 'Condition'",
            data=[query_embeddings[0].tolist()],
            limit=5,
            output_fields=["concept_name", "Synonyms", "concept_class_id", "concept_code"],
        )

        results = []
        for hit in search_result[0]:
            results.append({
                "concept_name": hit['entity'].get('concept_name'),
                "synonyms": hit['entity'].get('Synonyms'),
                "concept_class_id": hit['entity'].get('concept_class_id'),
                "concept_code": hit['entity'].get('concept_code'),
                "distance": float(hit['distance'])
            })

        return results

    def __del__(self):
        self.client.release_collection(collection_name)