import pandas as pd
from typing import List
import json
from openai import OpenAI
from io import StringIO
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ModelMapService:
    def __init__(self):
        self.client = OpenAI()

    def parse_schema(self, csv_content: str, file_name: str = "") -> dict:
        """将CSV内容解析为schema JSON"""
        try:
            # 读取CSV内容
            df = pd.read_csv(StringIO(csv_content))
            
            # 处理文件名，移除.csv后缀
            table_name = file_name.replace('.csv', '') if file_name else "table"
            
            # 获取列信息
            columns_info = []
            for column in df.columns:
                # 获取所有唯一值并转换为字符串
                unique_values = [str(val) for val in df[column].dropna().unique().tolist()]
                column_info = {
                    'column_name': column,
                    'unique_values': unique_values[:10],  # 最多展示10个不同的值
                    'total_unique_values': str(len(unique_values)),
                    'null_count': str(df[column].isna().sum()),
                    'dtype': str(df[column].dtype)
                }
                columns_info.append(column_info)
            
            prompt = f"""As a database expert, analyze this table structure and convert it to a standardized database schema JSON.

Table Analysis:
- Total rows: {len(df)}
- Total columns: {len(df.columns)}

Column Information:
{json.dumps(columns_info, indent=2)}

Return a JSON object that strictly follows this format:
{{
    "tables": [
        {{
            "table_name": "{table_name}",
            "columns": [
                {{
                    "name": "column_name",
                    "type": "SQL_TYPE(with size if applicable)",
                    "primary_key": boolean,
                    "required": boolean
                }}
            ]
        }}
    ]
}}"""

            response = self.client.chat.completions.create(
                model="gpt-4-turbo-preview",
                messages=[
                    {"role": "system", "content": "You are a database schema expert. Always return valid JSON format."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.1,
                response_format={"type": "json_object"}
            )
            
            schema_json = json.loads(response.choices[0].message.content)
            return schema_json

        except Exception as e:
            logger.error(f"Error in parse_schema: {str(e)}")
            raise Exception(f"Error parsing schema: {str(e)}")

    def generate_mapping(self, target_schema: dict, source_schemas: List[dict]) -> dict:
        """生成schema mapping"""
        try:
            prompt = f"""As a database expert, create a detailed mapping between the target schema and source schemas.

Target Schema:
{json.dumps(target_schema, indent=2)}

Source Schemas:
{json.dumps(source_schemas, indent=2)}

Analyze the schemas and create a mapping JSON that adds source table and column information to each target column.
The output should follow this exact format:
{{
    "tables": [
        {{
            "table_name": "{target_schema['tables'][0]['table_name']}",
            "columns": [
                {{
                    "name": "target_column_name",
                    "type": "SQL_TYPE",
                    "primary_key": boolean,
                    "required": boolean,
                    "mapping": {{
                        "source_table": "source_table_name",
                        "source_column": "source_column_name"
                    }}
                }}
            ]
        }}
    ]
}}

Rules:
1. Match columns based on name similarity and data type compatibility
2. Keep all original target schema information
3. Add mapping information for each column
4. If no match is found, set mapping to null
5. Return ONLY the JSON, no explanations"""

            response = self.client.chat.completions.create(
                model="gpt-4-turbo-preview",
                messages=[
                    {"role": "system", "content": "You are a database schema expert. Always return valid JSON format."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.1,
                response_format={"type": "json_object"}
            )
            
            mapping_json = json.loads(response.choices[0].message.content)
            return mapping_json

        except Exception as e:
            raise Exception(f"Error generating mapping: {str(e)}")

    def generate_sql(self, mapping: dict) -> str:
        """根据mapping生成SQL"""
        try:
            prompt = f"""As a database expert, generate a SQL migration script based on this mapping:
            {json.dumps(mapping, indent=2)}
            
            Requirements:
            1. Create proper INSERT INTO or MERGE statements
            2. Include all necessary JOIN operations
            3. Apply all specified transformations
            4. Handle NULL values and mandatory fields appropriately
            5. Use standard SQL syntax
            6. Include comments explaining complex transformations
            7. Format the SQL for readability
            
            Return only the SQL script without any additional explanation.
            """

            response = self.client.chat.completions.create(
                model="gpt-4o",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1
            )
            
            return response.choices[0].message.content

        except Exception as e:
            raise Exception(f"Error generating SQL: {str(e)}") 