from langchain_community.llms import Ollama
from langchain.chat_models import ChatOpenAI
from langchain.prompts import ChatPromptTemplate
from typing import Dict
from utils.processing import extract_sentences, save_model_output
from datetime import datetime
import random
import re
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CorrService:
    def __init__(self):
        self.keyboard_layouts = {
            'querty': {
                'q': "wasedzx",
                'w': "qesadrfcx",
                'e': "wrsfdqazxcvgt",
                'r': "etdgfwsxcvgt",
                't': "ryfhgedcvbnju",
                'y': "tugjhrfvbnji",
                'u': "yihkjtgbnmlo",
                'i': "uojlkyhnmlp",
                'o': "ipklujm",
                'p': "lo['ik",
                'a': "qszwxwdce",
                's': "wxadrfv",
                'd': "ecsfaqgbv",
                'f': "dgrvwsxyhn",
                'g': "tbfhedcyjn",
                'h': "yngjfrvkim",
                'j': "hknugtblom",
                'k': "jlinyhn",
                'l': "okmpujn",
                'z': "axsvde",
                'x': "zcsdbvfrewq",
                'c': "xvdfzswergb",
                'v': "cfbgxdertyn",
                'b': "vnghcftyun",
                'n': "bmhjvgtuik",
                'm': "nkjloik",
                ' ': " "
            }
        }
        
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
    
    def _has_slash_or_uppercase(self, word: str) -> bool:
        """检测单词是否包含斜杠或多个大写字母（可能是缩写）"""
        pattern = re.compile(r'\b\w{5,}/\w{5,}\b|\b(?:\w*[A-Z]){2,}\w*\b')
        return bool(pattern.match(word))
    
    def _butterfinger(self, text: str, prob: float = 0.2, keyboard: str = 'querty') -> str:
        """为单词引入打字错误"""
        if keyboard not in self.keyboard_layouts:
            logger.warning(f"Keyboard layout {keyboard} not supported, using querty")
            keyboard = 'querty'
            
        key_approx = self.keyboard_layouts[keyboard]
        prob_of_typo = int(prob * 100)
        
        buttertext = ""
        errors = 0
        
        for letter in text:
            lcletter = letter.lower()
            if lcletter not in key_approx:
                newletter = lcletter
            else:
                # 确保不超过1个错误
                if random.choice(range(0, 100)) <= prob_of_typo and errors < 1:
                    errors += 1
                    if random.choice(range(0, 100)) <= 80:
                        newletter = random.choice(key_approx[lcletter])
                    else:
                        # 有20%概率跳过字符
                        continue
                else:
                    newletter = lcletter
                    
            # 保持原始大小写
            if lcletter != letter:
                newletter = newletter.upper()
                
            buttertext += newletter
            
        return buttertext
        
    def correct_spelling(self, text: str, llm_options: dict) -> Dict:
        """纠正拼写错误方法"""
        llm = self._get_llm(llm_options)
        
        prompt = ChatPromptTemplate.from_messages([
            ("system", "Your job is to return the input with ALL spelling errors corrected. DO NOT expand any abbreviations."),
            ("system", "Input consist of clinical notes. Keep all occurrences of ___ in the output."),
            ("system", "Do NOT include supplementary messages like -> Here is the corrected input. Return the corrected input only."),
            ("human", "{input}"),
        ])
        
        chain = prompt | llm
        result = chain.invoke({"input": text})
        
        # 处理可能的AIMessage对象
        corrected_text = result.content if hasattr(result, 'content') else str(result)
        
        return {
            "input": text,
            "corrected_text": corrected_text
        }
        
    def add_mistakes(self, text: str, error_options: dict) -> Dict:
        """故意添加拼写错误（用于测试）"""
        probability = error_options.get("probability", 0.3)
        max_errors = error_options.get("maxErrors", 5)
        keyboard = error_options.get("keyboard", "querty")
        
        words = text.split()
        mistake_text = ""
        
        errors = 0
        for word in words:
            # 如果不是缩写，长度>=4，并且错误数小于最大值，则添加错误
            prob_of_typo = int(probability * 100)
            if (errors < max_errors and 
                random.choice(range(0, 100)) <= prob_of_typo and 
                len(word) >= 4 and 
                not self._has_slash_or_uppercase(word) and 
                word != "___"):
                
                mistake_text += self._butterfinger(word, probability, keyboard) + " "
                errors += 1
            else:
                mistake_text += word + " "
                
        mistake_text = mistake_text.strip()
        
        return {
            "input": text,
            "text_with_errors": mistake_text,
            "errors_added": errors
        }

# 以下函数保留为向后兼容，但不在新UI中使用
def butterfinger(text, prob=0.2, keyboard='querty'):
    service = CorrService()
    return service._butterfinger(text, prob, keyboard)

def has_slash_or_two_or_more_uppercase(word):
    service = CorrService()
    return service._has_slash_or_uppercase(word)

def add_mistakes(text):
    service = CorrService()
    result = service.add_mistakes(text, {"probability": 0.3, "maxErrors": 5})
    return result["text_with_errors"]

def correct_spelling(text, model_name):
    service = CorrService()
    result = service.correct_spelling(text, {"provider": "ollama", "model": model_name})
    return result["corrected_text"]

def generate_spellCorr_samples(dataset_path, headers, samples, model_name, save_path):
    """保留以前的函数用于兼容性"""
    from utils.processing import extract_sentences, save_model_output
    from datetime import datetime
    
    # get list of sentences from notes
    sentences = extract_sentences(dataset_path, headers, samples)

    # specify unique output file names
    mod_name = ""
    if model_name == "llama3":
        mod_name = "llama3_7b"
    elif model_name == "meta.llama3-70b-instruct-v1:0":
        mod_name = "llama3_70b"
    save_file = "spell_cor_" + mod_name + "_" + str(samples) + "_" + str(datetime.now()) + ".json"

    # for each sentence extracted
    for st in sentences:
        sent = st['input']

        # introduce spelling errors
        sent_with_errors = add_mistakes(sent)

        # correct spelling using model
        output = correct_spelling(sent_with_errors, model_name)

        json = {
            "input": sent,
            "with_errors": sent_with_errors,
            "output": output
        }

        print(json)

        save_model_output(json, save_path, save_file)