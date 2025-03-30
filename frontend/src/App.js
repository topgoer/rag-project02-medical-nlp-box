import React, { useState } from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import NERPage from './pages/NERPage';
import StdPage from './pages/StdPage';
import CorrPage from './pages/CorrPage';
import AbbrPage from './pages/AbbrPage';
import GenPage from './pages/GenPage';

const WelcomePage = () => {
  return (
    <div className="flex flex-col items-center justify-center h-full">
      <img src="/images/medical-img.png" alt="医疗记录处理" className="w-96 h-auto mb-8" />
      <h1 className="text-3xl font-bold text-gray-800 mb-4">欢迎使用医疗记录处理工具箱</h1>
      <p className="text-xl text-gray-600">请从左侧菜单选择要使用的功能</p>
    </div>
  );
};

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
            <Route path="/" element={<WelcomePage />} />
            <Route path="/ner" element={<NERPage />} />
            <Route path="/stand" element={<StdPage />} />
            <Route path="/corr" element={<CorrPage />} />
            <Route path="/abbr" element={<AbbrPage />} />
            <Route path="/gen" element={<GenPage />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
};

export default App;