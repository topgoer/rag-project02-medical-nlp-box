import React from 'react';
import { Link } from 'react-router-dom';
import { Database, FileText, Book } from 'lucide-react';

const Sidebar = ({ width }) => {
  return (
    <div className="bg-white shadow-lg" style={{ width: `${width}px` }}>
      <div className="p-5">
        {/* <img src="https://www.a-star.edu.sg/images/librariesprovider1/default-album/00.-astar-hq-corporate-website.png?sfvrsn=470d170_9" alt="A*STAR Logo" className="w-full mb-4" /> */}
        <img src="https://brandmark.io/logo-rank/random/pepsi.png" alt="标志" className="w-full mb-4" />
        <h1 className="text-xl font-bold mb-2">医疗记录处理工具箱</h1>
        <p className="text-sm text-gray-600 mb-4">强大的医疗记录处理工具集</p>
      </div>
      <nav className="mt-5">
        <Link to="/ner" className="flex items-center p-3 text-gray-700 hover:bg-gray-100">
          <FileText className="mr-3" /> 医疗命名实体识别
        </Link>
        <Link to="/corr" className="flex items-center p-3 text-gray-700 hover:bg-gray-100">
          <FileText className="mr-3" /> 医疗记录纠错
        </Link>
        <Link to="/standardization" className="flex items-center p-3 text-gray-700 hover:bg-gray-100">
          <FileText className="mr-3" /> 医疗术语标准化
        </Link>
        <Link to="/abbr" className="flex items-center p-3 text-gray-700 hover:bg-gray-100">
          <Book className="mr-3" /> 医疗缩写展开
        </Link>
        <Link to="/model-map" className="flex items-center p-3 text-gray-700 hover:bg-gray-100">
          <FileText className="mr-3" /> 医疗模型映射
        </Link>
      </nav>
    </div>
  );
};

export default Sidebar;