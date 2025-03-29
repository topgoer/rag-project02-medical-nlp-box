from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from services.ner_service import NERService
from services.std_service import StdService
from services.abbr_service import AbbrService
from services.corr_service import CorrService
# from services.model_map_service import ModelMapService
from services.gen_service import GenService
from typing import List, Dict
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# 配置 CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],    
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

ner_service = NERService()
standardization_service = StdService()
# model_map_service = ModelMapService()
abbr_service = AbbrService()
gen_service = GenService()
corr_service = CorrService()

class TextInput(BaseModel):
    text: str
    options: dict = {}
    termTypes: dict = {}
    embeddingOptions: dict = {
        "provider": "openai",
        "model": "text-embedding-3-large",
        "dbName": "icd10-terms-only",
        "collectionName": "openai_3_large"
    }

class QueryInput(BaseModel):
    query: str

class SchemaInput(BaseModel):
    csv: str
    fileName: str = ""

class MappingInput(BaseModel):
    targetSchema: dict
    sourceSchemas: List[dict]

class MappingResult(BaseModel):
    mapping: dict

class AbbrInput(BaseModel):
    text: str
    context: str = ""
    method: str = "simple_ollama"
    llmOptions: dict = {
        "provider": "ollama",
        "model": "llama3.1:8b"
    }
    embeddingOptions: dict = {
        "provider": "openai",
        "model": "text-embedding-3-large",
        "dbName": "icd10-terms-only",
        "collectionName": "openai_3_large"
    }

class GenInput(BaseModel):
    patient_info: Dict
    symptoms: List[str]
    diagnosis: str = ""
    treatment: str = ""
    method: str = "generate_medical_note"
    llmOptions: dict = {
        "provider": "ollama",
        "model": "llama3.1:8b"
    }

class CorrInput(BaseModel):
    text: str
    method: str = "correct_spelling"
    llmOptions: dict = {
        "provider": "ollama",
        "model": "qwen2.5:7b"
    }
    errorOptions: dict = {
        "probability": 0.3,
        "maxErrors": 5,
        "keyboard": "querty"
    }

@app.post("/api/ner")
async def ner(input: TextInput):
    try:
        logger.info(f"Received NER request: text={input.text}, options={input.options}, termTypes={input.termTypes}")
        results = ner_service.process(input.text, input.options, input.termTypes)
        return results
    except Exception as e:
        logger.error(f"Error in NER processing: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/corr")
async def correct_notes(input: CorrInput):
    try:
        if input.method == "correct_spelling":
            return corr_service.correct_spelling(input.text, input.llmOptions)
        elif input.method == "add_mistakes":
            return corr_service.add_mistakes(input.text, input.errorOptions)
        else:
            raise HTTPException(status_code=400, detail="Invalid method")
    except Exception as e:
        logger.error(f"Error in correction processing: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/std")
async def standardization(input: TextInput):
    try:
        logger.info(f"Received request: text={input.text}, options={input.options}, embeddingOptions={input.embeddingOptions}")

        # Extract allMedicalTerms from options and create termTypes
        all_medical_terms = input.options.pop('allMedicalTerms', False)
        term_types = {'allMedicalTerms': all_medical_terms}

        ner_results = ner_service.process(input.text, input.options, term_types)

        # 创建标准化服务实例，使用传入的嵌入选项
        standardization_service = StdService(
            provider=input.embeddingOptions.get("provider", "openai"),
            model=input.embeddingOptions.get("model", "text-embedding-3-large"),
            db_path=f"db/{input.embeddingOptions.get('dbName', 'icd10-terms-only')}.db",
            collection_name=input.embeddingOptions.get("collectionName", "openai_3_large")
        )

        # Ensure ner_results is a list of entities
        entities = ner_results.get('entities', [])

        if not entities:
            return {"message": "No medical terms have been recognized", "standardized_terms": []}

        standardized_results = []
        for entity in entities:
            std_result = standardization_service.process(entity['word'])
            standardized_results.append({
                "original_term": entity['word'],
                "entity_group": entity['entity_group'],
                "standardized_results": std_result
            })

        return {
            "message": f"{len(entities)} medical terms have been recognized and standardized",
            "standardized_terms": standardized_results
        }

    except Exception as e:
        logger.error(f"Error in standardization processing: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/abbr")
async def expand_abbreviations(input: AbbrInput):
    try:
        if input.method == "simple_ollama":
            output = abbr_service.simple_ollama_expansion(input.text, input.llmOptions)
            return {"input": input.text, "output": output}
        elif input.method == "query_db_llm_rerank":
            return abbr_service.query_db_llm_rerank(
                input.text, 
                input.context, 
                input.llmOptions,
                input.embeddingOptions
            )
        elif input.method == "llm_rank_query_db":
            return abbr_service.llm_rank_query_db(
                input.text, 
                input.context, 
                input.llmOptions,
                input.embeddingOptions
            )
        else:
            raise HTTPException(status_code=400, detail="Invalid method")
    except Exception as e:
        logger.error(f"Error in abbreviation expansion: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# @app.post("/api/parse-schema")
# async def parse_schema(input: SchemaInput):
#     try:
#         schema = model_map_service.parse_schema(input.csv, input.fileName)
#         return schema
#     except Exception as e:
#         logger.error(f"Error parsing schema: {str(e)}")
#         raise HTTPException(status_code=500, detail=str(e))

# @app.post("/api/generate-mapping")
# async def generate_mapping(input: MappingInput):
#     try:
#         mapping = model_map_service.generate_mapping(
#             input.targetSchema,
#             input.sourceSchemas
#         )
#         return mapping
#     except Exception as e:
#         logger.error(f"Error generating mapping: {str(e)}")
#         raise HTTPException(status_code=500, detail=str(e))

# @app.post("/api/generate-sql")
# async def generate_sql(input: MappingResult):
#     try:
#         sql = model_map_service.generate_sql(input.mapping)
#         return {"sql": sql}
#     except Exception as e:
#         logger.error(f"Error generating SQL: {str(e)}")
#         raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/gen")
async def generate_medical_content(input: GenInput):
    try:
        if input.method == "generate_medical_note":
            return gen_service.generate_medical_note(
                input.patient_info,
                input.symptoms,
                input.diagnosis,
                input.treatment,
                input.llmOptions
            )
        elif input.method == "generate_differential_diagnosis":
            return gen_service.generate_differential_diagnosis(
                input.symptoms,
                input.llmOptions
            )
        elif input.method == "generate_treatment_plan":
            return gen_service.generate_treatment_plan(
                input.diagnosis,
                input.patient_info,
                input.llmOptions
            )
        else:
            raise HTTPException(status_code=400, detail="Invalid method")
    except Exception as e:
        logger.error(f"Error in medical content generation: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
