#!/usr/bin/env sh
set -e

# ===============================
# 1. 基础变量检查（防止空值导致脚本异常）
# ===============================
# 检查 SSH_USER/SSH_PASSWORD 非空（创建普通用户必需）
if [ -z "$SSH_USER" ] || [ -z "$SSH_PASSWORD" ]; then
    echo "[ERROR] SSH_USER or SSH_PASSWORD environment variable is not set!"
    exit 1
fi

# ===============================
# 2. 修改 root 密码（仅更新密码，不涉及服务）
# ===============================
if [ -n "$ROOT_PASSWORD" ]; then
    echo "[INFO] ROOT_PASSWORD detected, updating root password..."
    echo "root:${ROOT_PASSWORD}" | chpasswd
    unset ROOT_PASSWORD  # 清理环境变量，防止密码泄露
else
    echo "[INFO] ROOT_PASSWORD not set, skip root password update"
fi

# ===============================
# 3. 启用 root SSH 登录（仅修改配置，由 Supervisor 启动 SSH）
# ===============================
if [ -f /etc/ssh/sshd_config ]; then
    echo "[INFO] Updating SSH config to allow root login..."
    # 覆盖 PermitRootLogin 配置（无论是否注释）
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
    # 确保密码认证开启（SSH 登录必需）
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    # 清理可能覆盖主配置的子配置（避免配置失效）
    if [ -d /etc/ssh/sshd_config.d ]; then
        rm -f /etc/ssh/sshd_config.d/*root* /etc/ssh/sshd_config.d/*permit*
    fi
else
    echo "[WARN] /etc/ssh/sshd_config not found, skip SSH config update"
fi

# ===============================
# 4. 创建普通 SSH 用户（保留原有逻辑，增加容错）
# ===============================
echo "[INFO] Creating SSH user: $SSH_USER"
# 先检查用户是否已存在，避免重复创建报错
if ! id -u "$SSH_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$SSH_USER"
else
    echo "[INFO] User $SSH_USER already exists, skip creation"
fi
# 设置普通用户密码
echo "$SSH_USER:$SSH_PASSWORD" | chpasswd
# 添加 sudo 权限
usermod -aG sudo "$SSH_USER"
# 配置免密 sudo（修复文件权限，避免 sudo 报错）
echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/init-users
chmod 0440 /etc/sudoers.d/init-users  # sudoers 必需的权限

# ===============================
# 5. 启动原有服务（交由 Supervisor 接管后续进程）
# ===============================
echo "[INFO] Entrypoint script completed, starting main process..."
exec "$@"
