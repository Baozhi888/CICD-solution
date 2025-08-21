from flask import Flask, jsonify
import os
import logging
from datetime import datetime

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

@app.route('/')
def hello():
    """根路径 - 返回应用信息"""
    logger.info("访问根路径")
    return jsonify({
        'message': 'Hello, CI/CD World!',
        'version': '1.0.0',
        'environment': os.environ.get('ENVIRONMENT', 'development')
    })

@app.route('/health')
def health():
    """健康检查端点"""
    try:
        logger.debug("执行健康检查")
        return jsonify({
            'status': 'OK',
            'timestamp': datetime.now().isoformat(),
            'service': 'python-app',
            'version': '1.0.0'
        })
    except Exception as e:
        logger.error(f"健康检查失败: {str(e)}")
        return jsonify({
            'status': 'ERROR',
            'timestamp': datetime.now().isoformat(),
            'error': str(e)
        }), 500

@app.route('/env')
def env():
    """环境信息端点"""
    logger.info("访问环境信息")
    return jsonify({
        'environment': os.environ.get('ENVIRONMENT', 'development'),
        'port': os.environ.get('PORT', '5000'),
        'debug': os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    
    logger.info(f"启动应用 - 端口: {port}, 调试模式: {debug}")
    app.run(host='0.0.0.0', port=port, debug=debug)