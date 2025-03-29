from transformers import pipeline
import torch
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class NERService:
    def __init__(self):
        self.pipe = pipeline("token-classification", 
                             model="Clinical-AI-Apollo/Medical-NER", 
                             aggregation_strategy='simple',
                             device=0 if torch.cuda.is_available() else -1)
  
    def process(self, text, options, term_types):
        result = self.pipe(text)
        
        # Ensure result is a list of entities
        if isinstance(result, dict):
            result = result.get('entities', [])
        
        combined_result = []
        
        # Step 1: Combine entities based on options
        i = 0
        while i < len(result):
            entity = result[i]
            entity['score'] = float(entity['score'])

            if options['combineBioStructure'] and entity['entity_group'] in ['SIGN_SYMPTOM', 'DISEASE_DISORDER']:
                if i > 0 and result[i-1]['entity_group'] == 'BIOLOGICAL_STRUCTURE':
                    start = result[i-1]['start']
                    end = entity['end']
                    word = text[start:end]
                    combined_entity = {
                        'entity_group': 'COMBINED_BIO_SYMPTOM',
                        'word': word,
                        'start': start,
                        'end': end,
                        'score': (entity['score'] + result[i-1]['score']) / 2,
                        'original_entities': [result[i-1], entity]
                    }
                    combined_result.append(combined_entity)
                    i += 1  # Skip the next entity as it's been combined
                elif i < len(result) - 1 and result[i+1]['entity_group'] == 'BIOLOGICAL_STRUCTURE':
                    start = entity['start']
                    end = result[i+1]['end']
                    word = text[start:end]
                    combined_entity = {
                        'entity_group': 'COMBINED_BIO_SYMPTOM',
                        'word': word,
                        'start': start,
                        'end': end,
                        'score': (entity['score'] + result[i+1]['score']) / 2,
                        'original_entities': [entity, result[i+1]]
                    }
                    combined_result.append(combined_entity)
                    i += 1  # Skip the next entity as it's been combined
                else:
                    combined_result.append(entity)
            else:
                combined_result.append(entity)
            i += 1

        # logger.info("Entities before removing overlaps:")
        # for entity in combined_result:
        #     logger.info(f"{entity['word']} - {entity['entity_group']} - Score: {entity['score']}")

        # New Step: Remove overlapping entities
        non_overlapping_result = self.remove_overlapping_entities(combined_result)

        # logger.info("Entities after removing overlaps:")
        # for entity in non_overlapping_result:
        #     logger.info(f"{entity['word']} - {entity['entity_group']} - Score: {entity['score']}")

        # Step 2: Filter entities based on term types
        filtered_result = []
        for entity in non_overlapping_result:
            if term_types.get('allMedicalTerms', False):
                filtered_result.append(entity)
            elif (term_types.get('symptom', False) and entity['entity_group'] in ['SIGN_SYMPTOM', 'COMBINED_BIO_SYMPTOM']) or \
                 (term_types.get('disease', False) and entity['entity_group'] == 'DISEASE_DISORDER') or \
                 (term_types.get('therapeuticProcedure', False) and entity['entity_group'] == 'THERAPEUTIC_PROCEDURE'):
                filtered_result.append(entity)

        # Step 3: Add original text to the response
        return {
            "text": text,
            "entities": filtered_result
        }

    def remove_overlapping_entities(self, entities):
        # 首先按开始位置排序，然后按结束位置（降序），最后按得分（降序）
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
                # 如果重叠，找出所有与当前实体起止位置相同的实体
                same_span = [current]
                j = i + 1
                while j < len(sorted_entities) and sorted_entities[j]['start'] == current['start'] and sorted_entities[j]['end'] == current['end']:
                    same_span.append(sorted_entities[j])
                    j += 1
                
                # 在相同范围的实体中选择得分最高的
                best_entity = max(same_span, key=lambda x: x['score'])
                
                # 如果最佳实体的结束位置更远，更新 last_end
                if best_entity['end'] > last_end:
                    non_overlapping.append(best_entity)
                    last_end = best_entity['end']
                
                i = j  # 跳过所有已处理的相同范围的实体

        return non_overlapping




