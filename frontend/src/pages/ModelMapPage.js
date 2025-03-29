import React, { useState } from 'react';

const ModelMapPage = () => {
  const [targetSchema, setTargetSchema] = useState(null);
  const [sourceSchemas, setSourceSchemas] = useState([]);
  const [mappingResult, setMappingResult] = useState(null);
  const [sqlResult, setSqlResult] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleTargetFileUpload = async (event) => {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = async (e) => {
        try {
          const response = await fetch('http://localhost:8000/api/parse-schema', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ 
              csv: e.target.result,
              fileName: file.name
            }),
          });
          const data = await response.json();
          setTargetSchema(data);
        } catch (error) {
          console.error('Error parsing target schema:', error);
        }
      };
      reader.readAsText(file);
    }
  };

  const handleSourceFileUpload = async (event) => {
    const files = Array.from(event.target.files);
    for (const file of files) {
      const reader = new FileReader();
      reader.onload = async (e) => {
        try {
          const response = await fetch('http://localhost:8000/api/parse-schema', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ 
              csv: e.target.result,
              fileName: file.name
            }),
          });
          const data = await response.json();
          setSourceSchemas(prev => [...prev, data]);
        } catch (error) {
          console.error('Error parsing source schema:', error);
        }
      };
      reader.readAsText(file);
    }
    event.target.value = '';
  };

  const handleRemoveSourceSchema = (index) => {
    setSourceSchemas(prev => prev.filter((_, i) => i !== index));
  };

  const handleGenerateMapping = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('http://localhost:8000/api/generate-mapping', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          targetSchema,
          sourceSchemas,
        }),
      });
      const data = await response.json();
      setMappingResult(data);
    } catch (error) {
      console.error('Error generating mapping:', error);
    }
    setIsLoading(false);
  };

  const handleGenerateSQL = async () => {
    if (!mappingResult) return;

    try {
      const response = await fetch('http://localhost:8000/api/generate-sql', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          mapping: mappingResult,
        }),
      });
      const data = await response.json();
      setSqlResult(data.sql);
    } catch (error) {
      console.error('Error generating SQL:', error);
    }
  };

  return (
    <div className="max-w-6xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">医疗模型映射 🔄</h1>
      
      {/* Target Schema Section */}
      <div className="bg-white shadow-md rounded-lg p-6 mb-6">
        <h2 className="text-xl font-semibold mb-4">目标表结构</h2>
        <input
          type="file"
          accept=".csv"
          onChange={handleTargetFileUpload}
          className="mb-4 block w-full text-sm text-gray-500
            file:mr-4 file:py-2 file:px-4
            file:rounded-md file:border-0
            file:text-sm file:font-semibold
            file:bg-blue-50 file:text-blue-700
            hover:file:bg-blue-100"
        />
        {targetSchema && (
          <div className="bg-gray-100 p-4 rounded-md">
            <pre className="whitespace-pre-wrap">
              {JSON.stringify(targetSchema, null, 2)}
            </pre>
          </div>
        )}
      </div>

      {/* Source Schemas Section */}
      <div className="bg-white shadow-md rounded-lg p-6 mb-6">
        <h2 className="text-xl font-semibold mb-4">源表结构</h2>
        <input
          type="file"
          accept=".csv"
          multiple
          onChange={handleSourceFileUpload}
          className="mb-4 block w-full text-sm text-gray-500
            file:mr-4 file:py-2 file:px-4
            file:rounded-md file:border-0
            file:text-sm file:font-semibold
            file:bg-green-50 file:text-green-700
            hover:file:bg-green-100"
        />
        {sourceSchemas.map((schema, index) => (
          <div key={index} className="bg-gray-100 p-4 rounded-md mb-4 relative">
            <button
              onClick={() => handleRemoveSourceSchema(index)}
              className="absolute top-2 right-2 text-red-500 hover:text-red-700"
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
              </svg>
            </button>
            <h3 className="font-semibold mb-2">源表结构：{schema.fileName}</h3>
            <pre className="whitespace-pre-wrap">
              {JSON.stringify(schema, null, 2)}
            </pre>
          </div>
        ))}
      </div>

      {/* Mapping Section */}
      <div className="flex gap-4 mb-6">
        <button
          onClick={handleGenerateMapping}
          className="bg-blue-500 text-white px-6 py-2 rounded-md hover:bg-blue-600 disabled:bg-gray-400 disabled:cursor-not-allowed"
          disabled={!targetSchema || sourceSchemas.length === 0 || isLoading}
        >
          {isLoading ? '生成映射中...' : '生成映射'}
        </button>
        <button
          onClick={handleGenerateSQL}
          className="bg-green-500 text-white px-6 py-2 rounded-md hover:bg-green-600 disabled:bg-gray-400 disabled:cursor-not-allowed"
          disabled={!mappingResult}
        >
          生成 SQL
        </button>
      </div>

      {/* Mapping Result */}
      {mappingResult && (
        <div className="bg-white shadow-md rounded-lg p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">映射结果</h2>
          <div className="bg-gray-100 p-4 rounded-md">
            <pre className="whitespace-pre-wrap">
              {JSON.stringify(mappingResult, null, 2)}
            </pre>
          </div>
        </div>
      )}

      {/* SQL Result */}
      {sqlResult && (
        <div className="bg-white shadow-md rounded-lg p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">生成的 SQL</h2>
          <div className="bg-gray-100 p-4 rounded-md">
            <pre className="whitespace-pre-wrap">{sqlResult}</pre>
          </div>
        </div>
      )}
    </div>
  );
};

export default ModelMapPage; 