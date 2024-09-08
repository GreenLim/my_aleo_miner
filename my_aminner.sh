#!/bin/bash

# 定义变量
name="mtdou.s1hk12333207"
device="0"
log_file="./aleominer.log"
timeout=180  # 3 分钟

# 删除现有的 aleo.zip 文件（如果存在）
if [ -f "aleo.zip" ]; then
    echo "Found existing aleo.zip. Deleting it..."
    rm aleo.zip
fi

# 检查并终止正在运行的 aleominer 进程（如果存在）
if pgrep -f "./aleominer" > /dev/null; then
    echo "Found running aleominer process. Stopping it..."
    pkill -f "./aleominer"
    sleep 5  # 给系统时间清理进程
    echo "Aleominer process stopped."
else
    echo "No running aleominer process found."
fi

# 下载 Aleo Miner
echo "Downloading Aleo Miner..."
curl -L "https://public-download-ase1.s3.ap-southeast-1.amazonaws.com/aleo-miner/Aleo+miner+2.11.44.zip" --output aleo.zip

# 安装 unzip 工具
echo "Installing unzip..."
sudo apt update
sudo apt install -y unzip

# 解压缩并进入目录
echo "Extracting files..."
unzip aleo.zip


# 设置可执行权限
echo "Setting permissions..."
chmod +x aleo.sh
chmod +x aleominer

# 显示 GPU 信息
echo "Checking NVIDIA GPU status..."
nvidia-smi

# 定义一个函数来检查日志文件中的 "Pool response"
check_pool_response() {
    while true; do
        # 检查日志文件中是否在过去 5 分钟内有 "Pool response"
        if tail -n 1000 "$log_file" | grep -q "Pool response"; then
            echo "Pool response found. Continuing..."
        else
            echo "No 'Pool response' found in the last $timeout seconds. Restarting aleominer..."
            
            # 杀掉 aleominer 进程
            pkill -f ./aleominer
            
            # 等待 5 秒后重新启动
            sleep 5
            break
        fi

        # 每 5 分钟检查一次
        sleep $timeout
    done
}

# 启动 aleominer 进程，并自动重新启动
echo "Starting aleominer with name: $name and device: $device"

while true; do
    # 启动挖矿进程
    nohup ./aleominer -u stratum+tcp://aleo-asia.f2pool.com:4400 -d $device -w $name >> $log_file 2>&1 &
    
    # 获取进程 ID
    miner_pid=$!

    # 启动日志检查功能（在后台运行）
    check_pool_response &

    # 等待挖矿进程结束
    wait $miner_pid

    # 检查退出代码，如果非 0 则说明进程异常终止，重新启动
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Aleominer crashed with exit code $exit_code. Restarting..."
        sleep 10  # 等待 10 秒再重新启动
    else
        echo "Aleominer stopped normally."
        break
    fi
done