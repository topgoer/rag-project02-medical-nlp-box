from pymilvus import MilvusClient
from dotenv import load_dotenv
from utils.embedding_factory import EmbeddingFactory
from utils.embedding_config import EmbeddingProvider, EmbeddingConfig
import os
from typing import List
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

class StdService:
    def __init__(self, 
                 provider="huggingface",
                 model="BAAI/bge-m3",
                 db_path="db/snomed_bge_m3.db",
                 collection_name="concepts_only_name"):

        # 根据 provider 字符串匹配正确的枚举值
        provider_mapping = {
            'openai': EmbeddingProvider.OPENAI,
            'bedrock': EmbeddingProvider.BEDROCK,
            'huggingface': EmbeddingProvider.HUGGINGFACE
        }
        
        # 创建 embedding 函数
        embedding_provider = provider_mapping.get(provider.lower())
        if embedding_provider is None:
            raise ValueError(f"Unsupported provider: {provider}")
            
        config = EmbeddingConfig(
            provider=embedding_provider,
            model_name=model
        )
        self.embedding_func = EmbeddingFactory.create_embedding_function(config)
        
        # 连接 Milvus
        self.client = MilvusClient(db_path)
        self.collection_name = collection_name
        self.client.load_collection(self.collection_name)
        
        # 存储数据库名称以便后续使用
        self.db_name = os.path.basename(db_path).replace('.db', '')

    def process(self, query):
        # 获取查询的向量表示
        query_embedding = self.embedding_func.embed_query(query)
        
        # 根据数据库类型设置输出字段
        search_params = {
            "collection_name": self.collection_name,
            "data": [query_embedding],
            "limit": 5,
        }
        
        if 'snomed' in self.db_name:
            search_params["output_fields"] = [
                "concept_id", "concept_name", "domain_id", 
                "vocabulary_id", "concept_class_id", "standard_concept",
                "concept_code", "synonyms"
            ]
            # 添加过滤条件
            search_params["filter"] = "domain_id == 'Condition'"
        else:  # icd10-terms-only
            search_params["output_fields"] = ["code", "title", "type", "depth"]
        
        # 搜索相似项
        search_result = self.client.search(**search_params)

        results = []
        for hit in search_result[0]:
            if 'snomed' in self.db_name:
                results.append({
                    "concept_id": hit['entity'].get('concept_id'),
                    "concept_name": hit['entity'].get('concept_name'),
                    "domain_id": hit['entity'].get('domain_id'),
                    "vocabulary_id": hit['entity'].get('vocabulary_id'),
                    "concept_class_id": hit['entity'].get('concept_class_id'),
                    "standard_concept": hit['entity'].get('standard_concept'),
                    "concept_code": hit['entity'].get('concept_code'),
                    "synonyms": hit['entity'].get('synonyms'),
                    "distance": float(hit['distance'])
                })
            else:  # icd10-terms-only
                results.append({
                    "code": hit['entity'].get('code'),
                    "title": hit['entity'].get('title'),
                    "type": hit['entity'].get('type'),
                    "depth": hit['entity'].get('depth'),
                    "distance": float(hit['distance'])
                })

        return results

    def search_similar_terms(self, query: str, limit: int = 10) -> List[str]:
        """
        Search for similar terms in the vector database
        Args:
            query: The query text to search for
            limit: Maximum number of results to return
        Returns:
            List of similar terms found in the database
        """
        try:
            # Get embeddings for the query
            query_embedding = self.embedding_func.embed_query(query)
            
            # Search the vector database
            search_params = {
                "collection_name": self.collection_name,
                "data": [query_embedding],
                "limit": limit,
                "output_fields": ["code", "title"] if 'icd10' in self.db_name else ["concept_name"]
            }
            
            search_result = self.client.search(**search_params)
            
            # Extract and return the terms
            results = []
            for hit in search_result[0]:
                if 'icd10' in self.db_name:
                    results.append(f"{hit['entity'].get('code')} - {hit['entity'].get('title')}")
                else:
                    results.append(hit['entity'].get('concept_name'))
                
            return results
            
        except Exception as e:
            logger.error(f"Error in semantic search: {str(e)}")
            return []

    def __del__(self):
        if hasattr(self, 'client') and hasattr(self, 'collection_name'):
            self.client.release_collection(self.collection_name)