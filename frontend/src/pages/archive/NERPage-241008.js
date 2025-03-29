import React, { useState } from 'react';
import { AlertCircle } from 'lucide-react';

const NERPage = () => {
  const [input, setInput] = useState('');
  const [result, setResult] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [termTypes, setTermTypes] = useState({
    symptom: false,
    disease: false,
    therapeuticProcedure: false,
    allMedicalTerms: false,
  });
  const [options, setOptions] = useState({
    combineBioStructure: false,
  });

  const handleTermTypeChange = (e) => {
    const { name, checked } = e.target;
    if (name === 'allMedicalTerms') {
      setTermTypes({
        symptom: false,
        disease: false,
        therapeuticProcedure: false,
        allMedicalTerms: checked,
      });
    } else {
      setTermTypes({ ...termTypes, [name]: checked });
    }
  };

  const handleOptionChange = (e) => {
    setOptions({ ...options, [e.target.name]: e.target.checked });
  };

  const handleSubmit = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('http://localhost:8000/api/ner', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text: input, options, termTypes }), // Send options and termTypes with the request
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
    <div className="max-w-2xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">Medical Named Entity Recognition 🏥</h1>
      <div className="bg-white shadow-md rounded-lg p-6 mb-6">
        <h2 className="text-xl font-semibold mb-4">Enter Medical Text</h2>
        <textarea
          className="w-full p-2 border rounded-md mb-4"
          rows="4"
          placeholder="Enter medical text for NER..."
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        
        <h3 className="text-lg font-semibold mb-2">Medical Terms Type</h3>
        <div className="mb-4">
          <label>
            <input
              type="checkbox"
              name="symptom"
              checked={termTypes.symptom}
              onChange={handleTermTypeChange}
            />
            Symptom
          </label>
          <label className="ml-4">
            <input
              type="checkbox"
              name="disease"
              checked={termTypes.disease}
              onChange={handleTermTypeChange}
            />
            Disease
          </label>
          <label className="ml-4">
            <input
              type="checkbox"
              name="therapeuticProcedure"
              checked={termTypes.therapeuticProcedure}
              onChange={handleTermTypeChange}
            />
            Therapeutic Procedure
          </label>
          <label className="ml-4">
            <input
              type="checkbox"
              name="allMedicalTerms"
              checked={termTypes.allMedicalTerms}
              onChange={handleTermTypeChange}
            />
            All Medical Terms
          </label>
        </div>

        <h3 className="text-lg font-semibold mb-2">Options</h3>
        <div className="mb-4">
          <label>
            <input
              type="checkbox"
              name="combineBioStructure"
              checked={options.combineBioStructure}
              onChange={handleOptionChange}
            />
            Combine Bio Structure and Symptom
          </label>
        </div>

        <button
          onClick={handleSubmit}
          className="bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-600"
        >
          Identify Entities
        </button>
      </div>
      {result && (
        <div className="bg-green-100 border-l-4 border-green-500 text-green-700 p-4 mb-6" role="alert">
          <p className="font-bold">Result:</p>
          <p>{result}</p>
        </div>
      )}
      <div className="flex items-center text-yellow-700 bg-yellow-100 p-4 rounded-md">
        <AlertCircle className="mr-2" />
        <span>This is a demo version. Actual NER process will be implemented in the future.</span>
      </div>
    </div>
  );
};

export default NERPage;