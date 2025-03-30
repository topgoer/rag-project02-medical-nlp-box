from transformers import pipeline
import torch
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class NERService:
    """
    医学术语命名实体识别服务
    使用 Clinical-AI-Apollo/Medical-NER 模型进行医疗文本的实体识别
    """
    def __init__(self):
        # 初始化 NER 模型，使用 GPU 如果可用
        self.pipe = pipeline("token-classification", 
                           model="Clinical-AI-Apollo/Medical-NER", 
                           aggregation_strategy='simple',
                           device=0 if torch.cuda.is_available() else -1)
  
    def process(self, text, options, term_types):
        """
        处理输入文本，识别医学术语实体
        
        Args:
            text: 输入文本
            options: 处理选项，如是否合并生物结构
            term_types: 需要识别的术语类型
            
        Returns:
            包含识别出的实体和原始文本的字典
        """
        # 使用模型进行实体识别
        result = self.pipe(text)
        
        # 确保结果是实体列表
        if isinstance(result, dict):
            result = result.get('entities', [])
        
        # 合并相关实体（如生物结构和症状）
        combined_result = self._combine_entities(result, text, options)
        
        # 移除重叠实体
        non_overlapping_result = self._remove_overlapping_entities(combined_result)
        
        # 根据术语类型过滤实体
        filtered_result = self._filter_entities(non_overlapping_result, term_types)
        
        return {
            "text": text,
            "entities": filtered_result
        }

    def _combine_entities(self, result, text, options):
        """
        合并相关的实体，如生物结构和症状
        """
        combined_result = []
        i = 0
        while i < len(result):
            entity = result[i]
            entity['score'] = float(entity['score'])

            if options['combineBioStructure'] and entity['entity_group'] in ['SIGN_SYMPTOM', 'DISEASE_DISORDER']:
                # 检查并合并生物结构
                combined_entity = self._try_combine_with_bio_structure(result, i, text)
                if combined_entity:
                    combined_result.append(combined_entity)
                    i += 1
                    continue
            combined_result.append(entity)
            i += 1
        return combined_result

    def _try_combine_with_bio_structure(self, result, i, text):
        """
        尝试将当前实体与生物结构实体合并
        """
        # 检查前一个实体
        if i > 0 and result[i-1]['entity_group'] == 'BIOLOGICAL_STRUCTURE':
            return self._create_combined_entity(result[i-1], result[i], text)
        # 检查后一个实体
        elif i < len(result) - 1 and result[i+1]['entity_group'] == 'BIOLOGICAL_STRUCTURE':
            return self._create_combined_entity(result[i], result[i+1], text)
        return None

    def _create_combined_entity(self, entity1, entity2, text):
        """
        创建合并后的实体
        """
        start = min(entity1['start'], entity2['start'])
        end = max(entity1['end'], entity2['end'])
        word = text[start:end]
        return {
            'entity_group': 'COMBINED_BIO_SYMPTOM',
            'word': word,
            'start': start,
            'end': end,
            'score': (entity1['score'] + entity2['score']) / 2,
            'original_entities': [entity1, entity2]
        }

    def _remove_overlapping_entities(self, entities):
        """
        移除重叠的实体，保留得分最高的实体
        """
        # 按开始位置、结束位置（降序）和得分（降序）排序
        sorted_entities = sorted(entities, key=lambda x: (x['start'], -x['end'], -x['score']))
        non_overlapping = []
        last_end = -1

        i = 0
        while i < len(sorted_entities):
            current = sorted_entities[i]
            
            # 如果当前实体与之前的实体不重叠，直接添加
            if current['start'] >= last_end:
                non_overlapping.append(current)
                last_end = current['end']
                i += 1
            else:
                # 处理重叠实体
                same_span = [current]
                j = i + 1
                while j < len(sorted_entities) and sorted_entities[j]['start'] == current['start'] and sorted_entities[j]['end'] == current['end']:
                    same_span.append(sorted_entities[j])
                    j += 1
                
                # 选择得分最高的实体
                best_entity = max(same_span, key=lambda x: x['score'])
                if best_entity['end'] > last_end:
                    non_overlapping.append(best_entity)
                    last_end = best_entity['end']
                
                i = j

        return non_overlapping

    def _filter_entities(self, entities, term_types):
        """
        根据术语类型过滤实体
        """
        filtered_result = []
        for entity in entities:
            if term_types.get('allMedicalTerms', False):
                filtered_result.append(entity)
            elif (term_types.get('symptom', False) and entity['entity_group'] in ['SIGN_SYMPTOM', 'COMBINED_BIO_SYMPTOM']) or \
                 (term_types.get('disease', False) and entity['entity_group'] == 'DISEASE_DISORDER') or \
                 (term_types.get('therapeuticProcedure', False) and entity['entity_group'] == 'THERAPEUTIC_PROCEDURE'):
                filtered_result.append(entity)
        return filtered_result




