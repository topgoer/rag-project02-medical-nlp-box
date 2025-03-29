from langchain_community.llms import Ollama
from langchain.chat_models import ChatOpenAI
from langchain.prompts import ChatPromptTemplate
from typing import List, Dict
from std_service import StdService
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AbbrService:
    def __init__(self):
        self.std_service = None  # Initialize on demand with correct config
        
    def _get_std_service(self, embedding_options: dict) -> StdService:
        """Get or create StdService with specified options"""
        return StdService(
            provider=embedding_options.get("provider", "openai"),
            model=embedding_options.get("model", "text-embedding-3-large"),
            db_path=f"db/{embedding_options.get('dbName', 'icd10-terms-only')}.db",
            collection_name=embedding_options.get("collectionName", "openai_3_large")
        )

    def _get_llm(self, llm_options: dict):
        """Get LLM based on provider and model"""
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
        
    def simple_ollama_expansion(self, text: str, llm_options: dict) -> str:
        """Original simple expansion method"""
        llm = self._get_llm(llm_options)
        
        prompt = ChatPromptTemplate.from_messages([
            ("system", "You job is to simply return the input with ALL abbreviations in medical domain replaced with their expanded forms."),
            ("system", "Input consist of clinical notes. Keep all occurrences of ___ in the output."),
            ("system", "Do NOT include supplementary messages like -> Here are the expanded abbreviations: I only want the output as a string."),
            ("system", "Do NOT spell out numbers, leave them as digits."),
            ("human", "{input}"),
        ])
        
        chain = prompt | llm
        return chain.invoke({"input": text})

    def query_db_llm_rerank(self, text: str, context: str, llm_options: dict, embedding_options: dict) -> Dict:
        """Query DB first, then use LLM to rerank"""
        # Get or create StdService with specified options
        self.std_service = self._get_std_service(embedding_options)
        
        # First, use std_service to find similar terms
        candidates = self.std_service.search_similar_terms(text, limit=10)
        
        llm = self._get_llm(llm_options)
        rerank_prompt = ChatPromptTemplate.from_messages([
            ("system", "Given the medical abbreviation and its context, rank the candidate expansions by their likelihood and common usage."),
            ("human", f"Abbreviation: {text}\nContext: {context}\nCandidates: {candidates}")
        ])
        
        chain = rerank_prompt | llm
        ranked_results = chain.invoke({})
        
        return {
            "input": text,
            "context": context,
            "candidates": candidates,
            "ranked_results": ranked_results
        }

    def llm_rank_query_db(self, text: str, context: str, llm_options: dict, embedding_options: dict) -> Dict:
        """Use LLM first, then query DB for standardization"""
        # Get or create StdService with specified options
        self.std_service = self._get_std_service(embedding_options)
        
        llm = self._get_llm(llm_options)
        expand_prompt = ChatPromptTemplate.from_messages([
            ("system", "Given the medical abbreviation and its context, provide the most likely expansion based on common medical usage."),
            ("human", f"Abbreviation: {text}\nContext: {context}")
        ])
        
        chain = expand_prompt | llm
        expansion_result = chain.invoke({})
        
        # 修复：从 AIMessage 中提取实际的文本内容
        expansion_text = expansion_result.content if hasattr(expansion_result, 'content') else str(expansion_result)
        
        # Find similar standard terms for the expansion
        std_terms = self.std_service.search_similar_terms(expansion_text)
        
        return {
            "input": text,
            "context": context,
            "expansion": expansion_text,
            "standardized_terms": std_terms
        } 