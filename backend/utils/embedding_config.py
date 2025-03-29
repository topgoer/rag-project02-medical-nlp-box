from dataclasses import dataclass
from enum import Enum
from typing import Optional

class EmbeddingProvider(Enum):
    BEDROCK = "bedrock"
    OPENAI = "openai"
    HUGGINGFACE = "huggingface"

@dataclass
class EmbeddingConfig:
    provider: EmbeddingProvider
    model_name: str  # 直接使用字符串，而不是枚举
    aws_region: Optional[str] = None
