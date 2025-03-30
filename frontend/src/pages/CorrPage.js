import React, { useState } from 'react';
import { AlertCircle } from 'lucide-react';

const CorrPage = () => {
  const [input, setInput] = useState('');
  const [result, setResult] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  
  // LLM options
  const [llmOptions, setLlmOptions] = useState({
    provider: 'ollama',
    model: 'qwen2.5:7b'
  });
  const llmProviders = {
    ollama: 'Ollama',
    openai: 'OpenAI'
  };

  const handleLlmOptionChange = (e) => {
    const { name, value } = e.target;
    setLlmOptions(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleSubmit = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('http://172.20.116.213:8000/api/corr', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          text: input,
          llmOptions
        }),
      });
      const data = await response.json();
      setResult(JSON.stringify(data, null, 2));
    } catch (error) {
      console.error('Error:', error);
      setResult('处理请求时发生错误。');
    }
    setIsLoading(false);
  };

  return (
    <div className="max-w-6xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">医疗记录纠错 🩺</h1>
      
      <div className="grid grid-cols-3 gap-6">
        {/* Left panel: Text inputs */}
        <div className="col-span-2 bg-white shadow-md rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">输入医疗记录</h2>
          <textarea
            className="w-full p-2 border rounded-md mb-4"
            rows="6"
            placeholder="请输入需要纠错的医疗记录..."
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />

          <button
            onClick={handleSubmit}
            className="bg-red-500 text-white px-4 py-2 rounded-md hover:bg-red-600 w-full"
            disabled={isLoading}
          >
            {isLoading ? '处理中...' : '纠正记录'}
          </button>
        </div>

        {/* Right panel: Options */}
        <div className="bg-white shadow-md rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">选项</h2>
          
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
      
      <div className="flex items-center text-yellow-700 bg-yellow-100 p-4 rounded-md mt-6">
        <AlertCircle className="mr-2" />
        <span>这是演示版本, 并非所有功能都可以正常工作。更多功能需要您来增强并实现。</span>
      </div>
    </div>
  );
};

export default CorrPage;