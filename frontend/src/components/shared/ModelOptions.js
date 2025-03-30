import React from 'react';

// LLM选项组件
export const LLMOptions = ({ options, onChange }) => {
  const llmProviders = {
    ollama: 'Ollama',
    openai: 'OpenAI'
  };

  return (
    <div className="mb-4">
      <h3 className="text-lg font-medium mb-2">大语言模型设置</h3>
      <div className="grid grid-cols-1 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">提供商</label>
          <select
            name="provider"
            value={options.provider}
            onChange={onChange}
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
            value={options.model}
            onChange={onChange}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
          />
        </div>
      </div>
    </div>
  );
};

// 向量数据库选项组件
export const EmbeddingOptions = ({ options, onChange }) => {
  return (
    <div className="grid grid-cols-2 gap-4 mb-4">
      <div>
        <label className="block text-sm font-medium text-gray-700">嵌入提供商</label>
        <select
          name="provider"
          value={options.provider}
          onChange={onChange}
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
          value={options.model}
          onChange={onChange}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">向量数据库名称</label>
        <input
          type="text"
          name="dbName"
          value={options.dbName}
          onChange={onChange}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">集合名称</label>
        <input
          type="text"
          name="collectionName"
          value={options.collectionName}
          onChange={onChange}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
        />
      </div>
    </div>
  );
};

// 通用输入文本区域组件
export const TextInput = ({ value, onChange, rows = 6, placeholder }) => {
  return (
    <textarea
      className="w-full p-2 border rounded-md mb-4"
      rows={rows}
      placeholder={placeholder}
      value={value}
      onChange={onChange}
    />
  );
}; 