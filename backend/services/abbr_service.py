from langchain_community.llms import Ollama
from langchain.chat_models import ChatOpenAI
from langchain.prompts import ChatPromptTemplate
from typing import Dict
from services.std_service import StdService
import os
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AbbrService:
    """
    医学术语缩写扩展服务
    提供两种方法来扩展医疗文本中的缩写：
    1. 简单 LLM 扩展：快速但不保证准确性
    2. LLM 生成 + 数据库查询：更准确但较慢
    """
    def __init__(self):
        self.std_service = None  # 按需初始化标准化服务
        
    def _get_std_service(self, embedding_options: dict) -> StdService:
        """
        获取或创建标准化服务实例
        
        Args:
            embedding_options: 嵌入模型配置选项，包含：
                - provider: 嵌入模型提供商
                - model: 模型名称
                - dbName: 数据库名称
                - collectionName: 集合名称
            
        Returns:
            配置好的标准化服务实例
            
        Raises:
            ValueError: 当标准化服务初始化失败时
        """
        try:
            return StdService(
                provider=embedding_options.get("provider", "huggingface"),
                model=embedding_options.get("model", "BAAI/bge-m3"),
                db_path=f"db/{embedding_options.get('dbName', 'snomed_bge_m3')}.db",
                collection_name=embedding_options.get("collectionName", "concepts_only_name")
            )
        except Exception as e:
            logger.error(f"Failed to initialize StdService: {str(e)}")
            raise ValueError(f"Failed to initialize standardization service: {str(e)}")

    def _get_llm(self, llm_options: dict):
        """
        根据配置获取语言模型实例
        
        Args:
            llm_options: 语言模型配置选项，包含：
                - provider: 模型提供商 (ollama/openai)
                - model: 模型名称
            
        Returns:
            配置好的语言模型实例
            
        Raises:
            ValueError: 当提供不支持的模型提供商时
        """
        provider = llm_options.get("provider", "ollama")
        model = llm_options.get("model", "llama3.1:8b")
        
        if provider == "ollama":
            return Ollama(model=model)
        elif provider == "openai":
            return ChatOpenAI(
                model=model,
                temperature=0,
                api_key=os.getenv("OPENAI_API_KEY")
            )
        else:
            raise ValueError(f"Unsupported LLM provider: {provider}")
        
    def simple_ollama_expansion(self, text: str, llm_options: dict) -> Dict:
        """
        使用简单的 LLM 方法扩展缩写（快速但不保证准确性）
        
        Args:
            text: 包含缩写的输入文本
            llm_options: 语言模型配置选项
            
        Returns:
            包含原始文本和扩展后文本的字典：
            {
                "input": 原始文本,
                "expanded_text": 扩展后的文本,
                "method": "simple_llm"
            }
        """
        llm = self._get_llm(llm_options)
        
        prompt = ChatPromptTemplate.from_messages([
            ("system", "You job is to simply return the input with ALL abbreviations in medical domain replaced with their expanded forms."),
            ("system", "Input consist of clinical notes. Keep all occurrences of ___ in the output."),
            ("system", "Do NOT include supplementary messages like -> Here are the expanded abbreviations: I only want the output as a string."),
            ("system", "Do NOT spell out numbers, leave them as digits."),
            ("human", "{input}"),
        ])
        
        chain = prompt | llm
        result = chain.invoke({"input": text})
        
        # 处理可能的AIMessage对象
        expanded_text = result.content if hasattr(result, 'content') else str(result)
        
        return {
            "input": text,
            "expanded_text": expanded_text,
            "method": "simple_llm"
        }

    def llm_rank_query_db(self, text: str, context: str, llm_options: dict, embedding_options: dict) -> Dict:
        """
        先使用 LLM 生成扩展，然后在数据库中查找标准化术语（更准确但较慢）
        
        Args:
            text: 需要扩展的缩写
            context: 缩写出现的上下文
            llm_options: 语言模型配置选项
            embedding_options: 嵌入模型配置选项
            
        Returns:
            包含扩展结果和标准化术语的字典：
            {
                "input": 原始缩写,
                "context": 上下文,
                "expansion": LLM生成的扩展,
                "standardized_terms": 标准化术语列表,
                "method": "llm_db"
            }
            
        Raises:
            ValueError: 当标准化服务初始化失败时
        """
        try:
            # 获取标准化服务实例
            self.std_service = self._get_std_service(embedding_options)
            
            # 使用 LLM 生成扩展
            llm = self._get_llm(llm_options)
            expand_prompt = ChatPromptTemplate.from_messages([
                ("system", "Given the medical abbreviation and its context, provide the most likely expansion based on common medical usage."),
                ("human", f"Abbreviation: {text}\nContext: {context}")
            ])
            
            chain = expand_prompt | llm
            expansion_result = chain.invoke({})
            
            # 从 AIMessage 中提取实际的文本内容
            expansion_text = expansion_result.content if hasattr(expansion_result, 'content') else str(expansion_result)
            
            # 在数据库中查找相似的标准术语
            std_terms = self.std_service.search_similar_terms(expansion_text)
            
            return {
                "input": text,
                "context": context,
                "expansion": expansion_text,
                "standardized_terms": std_terms,
                "method": "llm_db"
            }
        except Exception as e:
            logger.error(f"Error in llm_rank_query_db: {str(e)}")
            raise ValueError(f"Failed to process abbreviation expansion: {str(e)}") 