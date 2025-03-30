from pymilvus import MilvusClient
from dotenv import load_dotenv
from utils.embedding_factory import EmbeddingFactory
from utils.embedding_config import EmbeddingProvider, EmbeddingConfig
import os
from typing import List, Dict
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

class StdService:
    """
    医学术语标准化服务
    使用向量数据库进行医学术语的标准化和相似度搜索
    """
    def __init__(self, 
                 provider="huggingface",
                 model="BAAI/bge-m3",
                 db_path="db/snomed_bge_m3.db",
                 collection_name="concepts_only_name"):
        """
        初始化标准化服务
        
        Args:
            provider: 嵌入模型提供商 (openai/bedrock/huggingface)
            model: 使用的模型名称
            db_path: Milvus 数据库路径
            collection_name: 集合名称
        """
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

    def search_similar_terms(self, query: str, limit: int = 5) -> List[Dict]:
        """
        搜索与查询文本相似的医学术语
        
        Args:
            query: 查询文本
            limit: 返回结果的最大数量
            
        Returns:
            包含相似术语信息的列表，每个术语包含：
            - concept_id: 概念ID
            - concept_name: 概念名称
            - domain_id: 领域ID
            - vocabulary_id: 词汇表ID
            - concept_class_id: 概念类别ID
            - standard_concept: 是否标准概念
            - concept_code: 概念代码
            - synonyms: 同义词
            - distance: 相似度距离
        """
        # 获取查询的向量表示
        query_embedding = self.embedding_func.embed_query(query)
        
        # 设置搜索参数
        search_params = {
            "collection_name": self.collection_name,
            "data": [query_embedding],
            "limit": limit,
            "output_fields": [
                "concept_id", "concept_name", "domain_id", 
                "vocabulary_id", "concept_class_id", "standard_concept",
                "concept_code", "synonyms"
            ],
            # "filter": "domain_id == 'Condition'"
        }
        
        # 搜索相似项
        search_result = self.client.search(**search_params)

        results = []
        for hit in search_result[0]:
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

        return results

    def __del__(self):
        """清理资源，释放集合"""
        if hasattr(self, 'client') and hasattr(self, 'collection_name'):
            self.client.release_collection(self.collection_name)