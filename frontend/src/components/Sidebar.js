import React from 'react';
import { Link } from 'react-router-dom';
import { 
  Stethoscope, 
  FileCheck, 
  BookOpen, 
  FileEdit, 
  FileText
} from 'lucide-react';

const Sidebar = ({ width }) => {
  return (
    <div className="bg-white shadow-lg" style={{ width: `${width}px` }}>
      <div className="p-5">
        <img src="/images/medical-icon.png" alt="医疗图标" className="w-16 h-16 mx-auto mb-4" />
        <h1 className="text-xl font-bold mb-2">医疗记录处理工具箱</h1>
        <p className="text-sm text-gray-600 mb-4">强大的医疗记录处理工具集</p>
      </div>
      <nav className="mt-5">
        <Link to="/ner" className="flex items-center p-3 text-gray-700 hover:bg-gray-100">
          <Stethoscope className="mr-3" /> 医疗命名实体识别
        </Link>
        <Link to="/stand" className="flex items-center p-3 text-gray-700 hover:bg-gray-100">
          <FileCheck className="mr-3" /> 医疗术语标准化
        </Link>
        <Link to="/abbr" className="flex items-center p-3 text-gray-700 hover:bg-gray-100">
          <BookOpen className="mr-3" /> 医疗缩写展开
        </Link>
        <Link to="/corr" className="flex items-center p-3 text-gray-700 hover:bg-gray-100">
          <FileEdit className="mr-3" /> 医疗记录纠错
        </Link>        
        <Link to="/gen" className="flex items-center p-3 text-gray-700 hover:bg-gray-100">
          <FileText className="mr-3" /> 医疗内容生成
        </Link>
      </nav>
    </div>
  );
};

export default Sidebar;