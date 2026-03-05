# 基础镜像
FROM ubuntu:22.04

# 核心环境变量（解决交互式安装、时区等问题）
ENV DEBIAN_FRONTEND=noninteractive
ENV NVM_DIR="/root/.nvm"
ENV TZ=Asia/Shanghai \
    SSH_USER=ubuntu
# ENV ROOT_PASSWORD=your_secure_password  # 1. 新增：定义root密码环境变量（建议后续用secret管理）
# 注意：这个敏感信息建议用secret管理，仅保留适配你的原有配置

COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY reboot.sh /usr/local/sbin/reboot
COPY index.js /index.js
COPY app.js /app.js
COPY package.json /package.json
COPY app.py /app.py
COPY app.sh /app.sh
COPY requirements.txt /requirements.txt
COPY agent /agent
COPY start.sh /start.sh

# 安装所有基础依赖（整合你日志里的所有依赖）
RUN apt-get update; \
    apt-get install -y tzdata openssh-server sudo curl ca-certificates wget vim net-tools supervisor cron unzip iputils-ping telnet git iproute2 nano python3.10 pip --no-install-recommends; \
    apt-get clean; \
    npm install; \
    pip install -r requirements.txt; \    
    rm -rf /var/lib/apt/lists/*; \
    mkdir /var/run/sshd; \
    chmod +x /entrypoint.sh; \
    chmod +x /usr/local/sbin/reboot; \
    chmod +x index.js; \
    chmod +x app.py; \
    chmod +x app.js; \
    chmod +x app.sh; \
    chmod +x agent; \
    chmod +x start.sh; \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo $TZ > /etc/timezone; 
    
# 安装nvm + Node.js 24.13.0（核心：无任何嵌套shell，全程在同一个shell执行）
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash;  \
    . "$NVM_DIR/nvm.sh" ;  \
    nvm install 24.13.0 ;  \
    nvm alias default 24.13.0 ;  \
    node -v && npm -v ;  \
    nvm cache clear
# 全局配置PATH（关键：确保容器内所有进程都能找到node/npm）
ENV PATH="$NVM_DIR/versions/node/v24.13.0/bin:$PATH"
# 二次验证：确保全局PATH生效（非必需，但能提前发现问题）
RUN node -v && npm -v

EXPOSE 22/tcp
ENTRYPOINT ["/entrypoint.sh"]

# 容器启动命令
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
