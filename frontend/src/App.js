import React, { useState } from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import NERPage from './pages/NERPage';
import StandardizationPage from './pages/StandardizationPage';
import CorrPage from './pages/CorrPage';
import AbbrPage from './pages/AbbrPage';
import ModelMapPage from './pages/ModelMapPage';

const App = () => {
  const [sidebarWidth, setSidebarWidth] = useState(250);

  const handleResize = (e) => {
    setSidebarWidth(e.clientX);
  };

  return (
    <Router>
      <div className="flex h-screen bg-gray-100">
        <Sidebar width={sidebarWidth} />
        <div
          className="w-1 cursor-col-resize bg-gray-300 hover:bg-blue-500"
          onMouseDown={() => {
            document.addEventListener('mousemove', handleResize);
            document.addEventListener('mouseup', () => {
              document.removeEventListener('mousemove', handleResize);
            });
          }}
        />
        <main className="flex-1 overflow-y-auto p-5">
          <Routes>
            <Route path="/ner" element={<NERPage />} />
            <Route path="/standardization" element={<StandardizationPage />} />
            <Route path="/corr" element={<CorrPage />} />
            <Route path="/abbr" element={<AbbrPage />} />
            <Route path="/model-map" element={<ModelMapPage />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
};

export default App;