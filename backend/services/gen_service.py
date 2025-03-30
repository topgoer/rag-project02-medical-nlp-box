from langchain_community.llms import Ollama
from langchain.chat_models import ChatOpenAI
from langchain.prompts import ChatPromptTemplate
from typing import Dict, List
import os
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GenService:
    """
    医疗文本生成服务
    提供医疗笔记、鉴别诊断和治疗计划等医疗文本的生成功能
    """
    def __init__(self):
        pass
        
    def _get_llm(self, llm_options: dict):
        """
        根据配置获取语言模型实例
        
        Args:
            llm_options: 语言模型配置选项
            
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
                temperature=0.7,  # 稍微提高温度以获得更有创意的输出
                api_key=os.getenv("OPENAI_API_KEY")
            )
        else:
            raise ValueError(f"Unsupported LLM provider: {provider}")

    def generate_medical_note(self, 
                            patient_info: Dict,
                            symptoms: List[str],
                            diagnosis: str,
                            treatment: str,
                            llm_options: dict) -> Dict:
        """
        生成结构化的医疗笔记
        
        Args:
            patient_info: 患者信息
            symptoms: 症状列表
            diagnosis: 诊断结果
            treatment: 治疗方案
            llm_options: 语言模型配置选项
            
        Returns:
            包含输入信息和生成的医疗笔记的字典
        """
        llm = self._get_llm(llm_options)
        
        prompt = ChatPromptTemplate.from_messages([
            ("system", """You are a professional medical note writer. 
            Generate a detailed medical note in a structured format including:
            1. Patient Information
            2. Chief Complaint
            3. History of Present Illness
            4. Physical Examination
            5. Assessment and Plan
            
            Use medical terminology appropriately and maintain a professional tone."""),
            ("human", """
            Patient Information:
            {patient_info}
            
            Symptoms:
            {symptoms}
            
            Diagnosis:
            {diagnosis}
            
            Treatment:
            {treatment}
            """)
        ])
        
        chain = prompt | llm
        result = chain.invoke({
            "patient_info": str(patient_info),
            "symptoms": "\n".join(symptoms),
            "diagnosis": diagnosis,
            "treatment": treatment
        })
        
        return {
            "input": {
                "patient_info": patient_info,
                "symptoms": symptoms,
                "diagnosis": diagnosis,
                "treatment": treatment
            },
            "output": result.content if hasattr(result, 'content') else str(result)
        }

    def generate_differential_diagnosis(self,
                                      symptoms: List[str],
                                      llm_options: dict) -> Dict:
        """
        根据症状生成鉴别诊断
        
        Args:
            symptoms: 症状列表
            llm_options: 语言模型配置选项
            
        Returns:
            包含输入症状和生成的鉴别诊断的字典
        """
        llm = self._get_llm(llm_options)
        
        prompt = ChatPromptTemplate.from_messages([
            ("system", """You are a medical expert. 
            Generate a list of possible differential diagnoses based on the provided symptoms.
            For each diagnosis, provide:
            1. The condition name
            2. Brief explanation why it's a possibility
            3. Key distinguishing features
            
            Order the diagnoses from most likely to least likely."""),
            ("human", "Symptoms:\n{symptoms}")
        ])
        
        chain = prompt | llm
        result = chain.invoke({
            "symptoms": "\n".join(symptoms)
        })
        
        return {
            "input": {
                "symptoms": symptoms
            },
            "output": result.content if hasattr(result, 'content') else str(result)
        }

    def generate_treatment_plan(self,
                              diagnosis: str,
                              patient_info: Dict,
                              llm_options: dict) -> Dict:
        """
        生成详细的治疗计划
        
        Args:
            diagnosis: 诊断结果
            patient_info: 患者信息
            llm_options: 语言模型配置选项
            
        Returns:
            包含输入信息和生成的治疗计划的字典
        """
        llm = self._get_llm(llm_options)
        
        prompt = ChatPromptTemplate.from_messages([
            ("system", """You are a medical expert.
            Generate a comprehensive treatment plan that includes:
            1. Immediate interventions
            2. Medications (if applicable)
            3. Follow-up recommendations
            4. Lifestyle modifications
            5. Monitoring plan
            
            Consider the patient's information and medical history in your recommendations."""),
            ("human", """
            Diagnosis: {diagnosis}
            Patient Information: {patient_info}
            """)
        ])
        
        chain = prompt | llm
        result = chain.invoke({
            "diagnosis": diagnosis,
            "patient_info": str(patient_info)
        })
        
        return {
            "input": {
                "diagnosis": diagnosis,
                "patient_info": patient_info
            },
            "output": result.content if hasattr(result, 'content') else str(result)
        } 