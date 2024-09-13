#!/bin/bash
APPROOT=$(dirname $(readlink -e $0))

log_with_timestamp() {
    echo "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 确保以 root 权限运行
if [[ "$UID" -ne '0' ]]; then
  echo "Error: You must run this script as root!"; exit 1
fi

uninstall_package() {
  # 直接杀掉 aleominer 进程
  pkill -f $APPROOT/aleominer
  rm -f $APPROOT/aleo.service
  rm -rf $APPROOT/start_aleo.sh
  rm -rf $APPROOT/stop_aleo.sh
  rm -rf $APPROOT/aleowrapper
  rm -rf $APPROOT/prover.log
  rm -rf $APPROOT/config.cfg
}

# 强制每次执行前卸载旧的 aleo 安装
uninstall_package

WORKER=
POOL=
while getopts "w:p:u" opt; do
  case "$opt" in
    w) echo "Worker: $OPTARG"
       WORKER=$OPTARG
       ;;
    p) echo "Pool  : $OPTARG"
       POOL=$OPTARG
       ;;
    u) echo "Uninstall aleo package..."
       uninstall_package
       echo "Done."
       exit 0
       ;;
    *) echo "Unknown option: $opt"
       exit 1
       ;;
  esac
done

# 创建配置文件
if [ ! -f $APPROOT/config.cfg ]; then
cat << EOF > $APPROOT/config.cfg
WORKER=$WORKER
POOL=$POOL
EOF
fi
source $APPROOT/config.cfg

# 检查池地址
if [[ "$POOL" == "xxx.xxx.xxx.xxx:xxxx" || "$POOL" == "" ]]; then
    echo -e "Please edit the '$APPROOT/config.cfg'\n"
    exit 1
fi

# 检查 aleominer 文件是否存在
if [[ ! -f $APPROOT/aleominer ]]; then
    echo -e "aleominer not found\n"
    exit 1
fi
chmod +x $APPROOT/aleominer

# 生成 aleowrapper 脚本
cat << SUPER-EOF > $APPROOT/aleowrapper
#!/bin/bash
set -o pipefail

source $APPROOT/config.cfg

if [[ "\$POOL" == "xxx.xxx.xxx.xxx:xxxx" || "\$POOL" == "" ]]; then
    echo -e "Please edit the '$APPROOT/config.cfg'\n"
    exit 1
fi

LOG_PATH="$APPROOT/prover.log"
APP_PATH="$APPROOT/aleominer"

cat << EOF >> \$LOG_PATH
=============================================================================
Account name    : \$WORKER
Pool            : \$POOL
=============================================================================
EOF
\$APP_PATH -w "\$WORKER" -u "\$POOL" >> \$LOG_PATH 2>&1
SUPER-EOF
chmod +x $APPROOT/aleowrapper

# 启动 aleominer 进程
log_with_timestamp "Starting aleominer with worker: $WORKER and pool: $POOL"
nohup $APPROOT/aleowrapper > /dev/null 2>&1 &