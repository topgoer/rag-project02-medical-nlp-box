import React, { useState } from 'react';

const GenPage = () => {
  // 基础状态
  const [isLoading, setIsLoading] = useState(false);
  const [result, setResult] = useState('');
  
  // 方法选择
  const [method, setMethod] = useState('generate_medical_note');
  const methods = {
    generate_medical_note: '生成完整医疗记录',
    generate_differential_diagnosis: '生成鉴别诊断',
    generate_treatment_plan: '生成治疗计划'
  };

  // 患者信息
  const [patientInfo, setPatientInfo] = useState({
    name: '',
    age: '',
    gender: '',
    medicalHistory: ''
  });

  // 症状列表
  const [symptoms, setSymptoms] = useState('');
  const [diagnosis, setDiagnosis] = useState('');
  const [treatment, setTreatment] = useState('');

  // LLM 选项
  const [llmOptions, setLlmOptions] = useState({
    provider: 'ollama',
    model: 'qwen2.5:7b'
  });
  const llmProviders = {
    ollama: 'Ollama',
    openai: 'OpenAI'
  };

  const handlePatientInfoChange = (e) => {
    const { name, value } = e.target;
    setPatientInfo(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleLlmOptionChange = (e) => {
    const { name, value } = e.target;
    setLlmOptions(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleSymptomsChange = (e) => {
    setSymptoms(e.target.value);
  };

  const handleSubmit = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('http://localhost:8000/api/gen', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          patient_info: patientInfo,
          symptoms: symptoms.split('\n').filter(s => s.trim()),
          diagnosis,
          treatment,
          method,
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
      <h1 className="text-3xl font-bold mb-6">医疗内容生成 🏥</h1>
      
      <div className="grid grid-cols-3 gap-6">
        {/* 左侧面板：输入表单 */}
        <div className="col-span-2 bg-white shadow-md rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">患者信息</h2>
          
          {/* 患者基本信息 */}
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">姓名</label>
              <input
                type="text"
                name="name"
                value={patientInfo.name}
                onChange={handlePatientInfoChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">年龄</label>
              <input
                type="number"
                name="age"
                value={patientInfo.age}
                onChange={handlePatientInfoChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">性别</label>
              <select
                name="gender"
                value={patientInfo.gender}
                onChange={handlePatientInfoChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
              >
                <option value="">选择性别</option>
                <option value="M">男</option>
                <option value="F">女</option>
                <option value="O">其他</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">病史</label>
              <input
                type="text"
                name="medicalHistory"
                value={patientInfo.medicalHistory}
                onChange={handlePatientInfoChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                placeholder="既往病史..."
              />
            </div>
          </div>

          {/* 症状输入 */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700">症状（每行一个）</label>
            <textarea
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
              rows="3"
              value={symptoms}
              onChange={handleSymptomsChange}
              placeholder="输入症状，每行一个..."
            />
          </div>

          {/* 诊断和治疗（仅在生成医疗记录时显示） */}
          {method === 'generate_medical_note' && (
            <>
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700">诊断</label>
                <input
                  type="text"
                  value={diagnosis}
                  onChange={(e) => setDiagnosis(e.target.value)}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                  placeholder="输入诊断..."
                />
              </div>
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700">治疗</label>
                <input
                  type="text"
                  value={treatment}
                  onChange={(e) => setTreatment(e.target.value)}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                  placeholder="输入治疗方案..."
                />
              </div>
            </>
          )}

          <button
            onClick={handleSubmit}
            className="bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-600 w-full"
            disabled={isLoading}
          >
            {isLoading ? '生成中...' : '生成内容'}
          </button>
        </div>

        {/* 右侧面板：选项 */}
        <div className="bg-white shadow-md rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">选项</h2>
          
          {/* 方法选择 */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700">生成方法</label>
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

          {/* LLM 选项 */}
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

      {/* 结果显示 */}
      {result && (
        <div className="mt-6">
          <div className="bg-blue-100 border-l-4 border-blue-500 text-blue-700 p-4 mb-6" role="alert">
            <p className="font-bold">生成结果：</p>
            <pre className="whitespace-pre-wrap">{result}</pre>
          </div>
        </div>
      )}
    </div>
  );
};

export default GenPage; 