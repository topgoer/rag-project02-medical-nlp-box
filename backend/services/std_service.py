from pymilvus import connections, Collection, FieldSchema, CollectionSchema, DataType, utility
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
        try:
            # Connect to Milvus server
            connections.connect(
                alias="default",
                host="localhost",
                port="19530"
            )
            
            # Define collection schema
            fields = [
                FieldSchema(name="id", dtype=DataType.INT64, is_primary=True, auto_id=True),
                FieldSchema(name="vector", dtype=DataType.FLOAT_VECTOR, dim=1024),  # BGE-m3 dimension
                FieldSchema(name="concept_id", dtype=DataType.VARCHAR, max_length=50),
                FieldSchema(name="concept_name", dtype=DataType.VARCHAR, max_length=200),
                FieldSchema(name="domain_id", dtype=DataType.VARCHAR, max_length=20),
                FieldSchema(name="vocabulary_id", dtype=DataType.VARCHAR, max_length=20),
                FieldSchema(name="concept_class_id", dtype=DataType.VARCHAR, max_length=20),
                FieldSchema(name="standard_concept", dtype=DataType.VARCHAR, max_length=1),
                FieldSchema(name="concept_code", dtype=DataType.VARCHAR, max_length=50),
                FieldSchema(name="valid_start_date", dtype=DataType.VARCHAR, max_length=10),
                FieldSchema(name="valid_end_date", dtype=DataType.VARCHAR, max_length=10),
                FieldSchema(name="input_file", dtype=DataType.VARCHAR, max_length=500),
            ]
            schema = CollectionSchema(fields, "SNOMED-CT Concepts")
            
            # Create collection if it doesn't exist
            if not utility.has_collection(collection_name):
                logger.info(f"Creating collection: {collection_name}")
                self.collection = Collection(collection_name, schema)
                # Create index
                index_params = {
                    "metric_type": "COSINE"
                }
                self.collection.create_index("vector", index_params)
                logger.info("Index created successfully")
            else:
                logger.info(f"Using existing collection: {collection_name}")
                self.collection = Collection(collection_name)
                # Check if index exists
                if not self.collection.has_index():
                    logger.info("Creating index for existing collection")
                    index_params = {
                        "metric_type": "COSINE"
                    }
                    self.collection.create_index("vector", index_params)
                    logger.info("Index created successfully")
            
            # Load collection after ensuring index exists
            self.collection.load()
            logger.info(f"Successfully connected to Milvus and loaded collection: {collection_name}")
        except Exception as e:
            logger.error(f"Failed to connect to Milvus: {e}")
            raise

    def search_similar_terms(self, query: str, limit: int = 5) -> List[Dict]:
        """
        搜索与查询文本相似的医学术语
        
        Args:
            query: 查询文本
            limit: 返回结果的最大数量
            
        Returns:
            包含相似术语信息的列表
        """
        # 获取查询的向量表示
        query_embedding = self.embedding_func.embed_query(query)
        
        # 搜索参数
        search_params = {
            "metric_type": "COSINE",
            "params": {"nprobe": 10}
        }
        
        # 执行搜索
        results = self.collection.search(
            data=[query_embedding],
            anns_field="vector",
            param=search_params,
            limit=limit,
            output_fields=[
                "concept_id", "concept_name", "domain_id", 
                "vocabulary_id", "concept_class_id", "standard_concept",
                "concept_code"
            ]
        )

        # 处理结果
        processed_results = []
        for hits in results:
            for hit in hits:
                processed_results.append({
                    "concept_id": hit.entity.get('concept_id'),
                    "concept_name": hit.entity.get('concept_name'),
                    "domain_id": hit.entity.get('domain_id'),
                    "vocabulary_id": hit.entity.get('vocabulary_id'),
                    "concept_class_id": hit.entity.get('concept_class_id'),
                    "standard_concept": hit.entity.get('standard_concept'),
                    "concept_code": hit.entity.get('concept_code'),
                    "distance": float(hit.distance)
            })

        return processed_results

    def __del__(self):
        """清理资源"""
        try:
            if hasattr(self, 'collection'):
                self.collection.release()
            connections.disconnect("default")
        except Exception as e:
            logger.error(f"Error during cleanup: {e}")