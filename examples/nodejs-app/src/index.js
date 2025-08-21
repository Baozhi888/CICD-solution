const express = require('express');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// 健康检查端点
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', timestamp: new Date().toISOString() });
});

// 主页端点
app.get('/', (req, res) => {
  res.status(200).json({ message: 'Hello, CI/CD World!', version: '1.0.0' });
});

// API端点示例
app.get('/api/users', (req, res) => {
  res.status(200).json([
    { id: 1, name: 'Alice' },
    { id: 2, name: 'Bob' },
    { id: 3, name: 'Charlie' }
  ]);
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

module.exports = app;