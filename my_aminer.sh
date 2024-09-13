#!/bin/bash

# 读取系统环境变量，如果没有定义，则使用默认值
name="${ALNAME:-mtdou.default}"  # 如果未设置环境变量 ALNAME，则使用默认值
log_file="./prover.log"
timeout=120  # 每次日志检查的间隔时间：2 分钟
initial_delay=120  # 2 分钟，aleominer 启动后的延迟时间

# 获取带时间戳的输出函数（UTC+8）
log_with_timestamp() {
    echo "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 删除现有的 aleo.zip 文件（如果存在）
if [ -f "aleo.zip" ]; then
    log_with_timestamp "Found existing aleo.zip. Deleting it..."
    rm aleo.zip
fi

# 检查并终止正在运行的 aleominer 进程（如果存在）
if pgrep -f "./aleominer" > /dev/null; then
    log_with_timestamp "Found running aleominer process. Stopping it..."
    pkill -f "./aleominer"
    sleep 5  # 给系统时间清理进程
    log_with_timestamp "Aleominer process stopped."
else
    log_with_timestamp "No running aleominer process found."
fi

# 下载 Aleo Miner
log_with_timestamp "Downloading Aleo Miner..."
curl -L "https://github.com/GreenLim/my_aleo_miner/releases/download/v1.1.3/aleominer+2.11.49.zip" --output aleo.zip

# 安装 unzip 工具
log_with_timestamp "Installing unzip..."
sudo apt update
sudo apt install -y unzip

# 解压缩并进入目录
log_with_timestamp "Extracting files..."
unzip aleo.zip

# 设置可执行权限
log_with_timestamp "Setting permissions..."
chmod +x aleo_setup.sh
chmod +x my_aleo_setup.sh
chmod +x aleominer

# 显示 GPU 信息
log_with_timestamp "Checking NVIDIA GPU status..."
nvidia-smi

# 定义一个标志位，用于判断是否需要重启
restart_flag=0

# 定义一个函数来检查日志文件中的 "Pool response" 或日志的更新时间
check_log_file() {
    log_with_timestamp "Waiting for $initial_delay seconds (2 minutes) before starting log checks..."
    sleep $initial_delay  # 等待2分钟才开始日志检查

    while true; do
        if [[ ! -f "$log_file" ]]; then
            log_with_timestamp "Log file $log_file not found. Skipping log checks."
            break
        fi

        # 检查日志文件是否在过去2分钟内有更新
        last_modified=$(stat -c %Y "$log_file")
        current_time=$(date +%s)
        diff_time=$((current_time - last_modified))

        if [ $diff_time -gt $timeout ]; then
            log_with_timestamp "Log file has not been updated in the last 2 minutes. Restarting aleominer..."
            restart_flag=1
            break
        fi

        # 检查日志文件中是否在过去 2 分钟内有 "Pool response"
        if tail -n 50 "$log_file" | grep -q "Pool response"; then
            log_with_timestamp "Pool response found. Continuing..."
        else
            log_with_timestamp "No 'Pool response' found in the last 3 minutes. Restarting aleominer..."
            restart_flag=1
            break
        fi

        # 每 2 分钟检查一次
        sleep $timeout
    done
}

while true; do
    # 启动 aleominer 进程
    log_with_timestamp "Starting aleominer with worker name: $name"
    sudo ./my_aleo_setup.sh -p stratum+tcp://aleo-asia.f2pool.com:4400 -w $name

    # 等待 aleominer 完全启动
    sleep 5

    # 获取 aleominer 的 PID
    miner_pid=$(pgrep -f aleominer)

    if [[ -z "$miner_pid" ]]; then
        log_with_timestamp "Failed to start aleominer or couldn't find aleominer process."
    else
        log_with_timestamp "Aleominer started with PID: $miner_pid"
        ps -p $miner_pid -o pid,cmd,%cpu,%mem,etime
    fi

    # 将日志检查函数放在前台执行，避免后台进程过多
    check_log_file

    # 检查是否需要重启
    if [ $restart_flag -eq 1 ]; then
        log_with_timestamp "Restarting aleominer..."
        restart_flag=0  # 重置重启标志
        sleep 10  # 等待 10 秒再重新启动
    else
        log_with_timestamp "Aleominer stopped normally."
        break  # 如果正常退出，跳出循环
    fi
done
