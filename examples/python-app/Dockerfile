FROM python:3.9-alpine

# 设置工作目录
WORKDIR /app

# 复制依赖文件
COPY requirements.txt .

# 安装依赖
RUN pip install -r requirements.txt

# 复制源代码
COPY app/ app/

# 暴露端口
EXPOSE 5000

# 启动应用
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app.main:app"]