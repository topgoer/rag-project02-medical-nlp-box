import React, { useState } from 'react';

const AbbrPage = () => {
  const [input, setInput] = useState('');
  const [context, setContext] = useState('');
  const [result, setResult] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  
  // Method selection
  const [method, setMethod] = useState('simple_ollama');
  const methods = {
    simple_ollama: '简单大语言模型展开',
    query_db_llm_rerank: '查询数据库 + 大语言模型重排',
    llm_rank_query_db: '大语言模型展开 + 数据库标准化'
  };

  // LLM options
  const [llmOptions, setLlmOptions] = useState({
    provider: 'ollama',
    model: 'llama3.1:8b'
  });
  const llmProviders = {
    ollama: 'Ollama',
    openai: 'OpenAI'
  };

  // Vector DB options (reusing from StandardizationPage)
  const [embeddingOptions, setEmbeddingOptions] = useState({
    provider: 'openai',
    model: 'text-embedding-3-large',
    dbName: 'icd10-terms-only',
    collectionName: 'openai_3_large'
    // model: 'text-embedding-3-small',  // 改为 3-small
    // dbName: 'snomed_syn',             // 改为 snomed_syn
    // collectionName: 'concepts_with_desc_n_synonyms'  // 改为实际的集合名称    
  });

  const handleLlmOptionChange = (e) => {
    const { name, value } = e.target;
    setLlmOptions(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleEmbeddingOptionChange = (e) => {
    setEmbeddingOptions(prev => ({
      ...prev,
      [e.target.name]: e.target.value
    }));
  };

  const handleSubmit = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('http://localhost:8000/api/abbr', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          text: input,
          context,
          method,
          llmOptions,
          embeddingOptions
        }),
      });
      const data = await response.json();
      setResult(JSON.stringify(data, null, 2));
    } catch (error) {
      console.error('Error:', error);
      setResult('An error occurred while processing the request.');
    }
    setIsLoading(false);
  };

  return (
    <div className="max-w-6xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">医疗缩写展开 📝</h1>
      
      <div className="grid grid-cols-3 gap-6">
        {/* Left panel: Text inputs */}
        <div className="col-span-2 bg-white shadow-md rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">输入医疗记录</h2>
          <textarea
            className="w-full p-2 border rounded-md mb-4"
            rows="4"
            placeholder="请输入包含缩写的医疗记录..."
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />

          {method !== 'simple_ollama' && (
            <textarea
              className="w-full p-2 border rounded-md mb-4"
              rows="2"
              placeholder="输入上下文以获得更好的缩写展开效果..."
              value={context}
              onChange={(e) => setContext(e.target.value)}
            />
          )}

          <button
            onClick={handleSubmit}
            className="bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-600 w-full"
            disabled={isLoading}
          >
            {isLoading ? '处理中...' : '展开缩写'}
          </button>
        </div>

        {/* Right panel: Options */}
        <div className="bg-white shadow-md rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">选项</h2>
          
          {/* Method Selection */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700">展开方法</label>
            <select
              value={method}
              onChange={(e) => setMethod(e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
            >
              {Object.entries(methods).map(([key, label]) => (
                <option key={key} value={key}>{label}</option>
              ))}
            </select>
          </div>

          {/* LLM Options */}
          <div className="mb-4">
            <h3 className="text-lg font-medium mb-2">大语言模型设置</h3>
            <div className="grid grid-cols-1 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">提供商</label>
                <select
                  name="provider"
                  value={llmOptions.provider}
                  onChange={handleLlmOptionChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                >
                  {Object.entries(llmProviders).map(([key, label]) => (
                    <option key={key} value={key}>{label}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">模型</label>
                <input
                  type="text"
                  name="model"
                  value={llmOptions.model}
                  onChange={handleLlmOptionChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                />
              </div>
            </div>
          </div>

          {/* Vector DB Options (only show when method needs it) */}
          {method !== 'simple_ollama' && (
            <div className="mb-4">
              <h3 className="text-lg font-medium mb-2">向量数据库设置</h3>
              <div className="grid grid-cols-1 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">嵌入提供商</label>
                  <select
                    name="provider"
                    value={embeddingOptions.provider}
                    onChange={handleEmbeddingOptionChange}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                  >
                    <option value="openai">OpenAI</option>
                    <option value="bedrock">Bedrock</option>
                    <option value="huggingface">HuggingFace</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">嵌入模型</label>
                  <input
                    type="text"
                    name="model"
                    value={embeddingOptions.model}
                    onChange={handleEmbeddingOptionChange}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">向量数据库名称</label>
                  <input
                    type="text"
                    name="dbName"
                    value={embeddingOptions.dbName}
                    onChange={handleEmbeddingOptionChange}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">集合名称</label>
                  <input
                    type="text"
                    name="collectionName"
                    value={embeddingOptions.collectionName}
                    onChange={handleEmbeddingOptionChange}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                  />
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Results */}
      {result && (
        <div className="mt-6">
          <div className="bg-blue-100 border-l-4 border-blue-500 text-blue-700 p-4 mb-6" role="alert">
            <p className="font-bold">结果：</p>
            <pre className="whitespace-pre-wrap">{result}</pre>
          </div>
        </div>
      )}
    </div>
  );
};

export default AbbrPage; 