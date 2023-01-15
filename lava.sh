Crontab_file="/usr/bin/crontab"
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Info="[${Green_font_prefix}信息${Font_color_suffix}]"
Error="[${Red_font_prefix}错误${Font_color_suffix}]"
Tip="[${Green_font_prefix}注意${Font_color_suffix}]"
check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}

install_evn(){
    check_root
    sudo apt install -y unzip logrotate git jq sed wget curl coreutils systemd
    echo "正在安装GO环境.............."
    go_package_url="https://go.dev/dl/go1.18.linux-amd64.tar.gz"
    go_package_file_name=${go_package_url##*\/}
    wget -q $go_package_url
    sudo tar -C /usr/local -xzf $go_package_file_name
    echo "export PATH=\$PATH:/usr/local/go/bin" >>~/.profile
    echo "export PATH=\$PATH:\$(go env GOPATH)/bin" >>~/.profile
    source ~/.profile
    rm go1.18.linux-amd64.tar.gz
    go version
    echo "环境安装完成"
}

install_lavad(){
    git clone https://github.com/K433QLtr6RA9ExEq/GHFkqmTzpdNLDd6T.git
    cd GHFkqmTzpdNLDd6T/testnet-1
    source setup_config/setup_config.sh
    echo "Lava config file path: $lava_config_folder"
    mkdir -p $lavad_home_folder
    mkdir -p $lava_config_folder
    cp default_lavad_config_files/* $lava_config_folder
    cp genesis_json/genesis.json $lava_config_folder/genesis.json
    lavad_binary_path="$HOME/go/bin/"
    mkdir -p $lavad_binary_path
    echo "正在把Lavad加入境变量.............."
    wget https://lava-binary-upgrades.s3.amazonaws.com/testnet/v0.4.3/lavad
    chmod +x lavad
    sudo cp ./lavad /usr/local/bin/lavad
    echo "[Unit]
    Description=Lava Node
    After=network-online.target
    [Service]
    User=$USER
    ExecStart=$(which lavad) start --home=$lavad_home_folder --p2p.seeds $seed_node
    Restart=always
    RestartSec=180
    LimitNOFILE=infinity
    LimitNPROC=infinity
    [Install]
    WantedBy=multi-user.target" >lavad.service
    sudo mv lavad.service /lib/systemd/system/lavad.service
    sudo systemctl daemon-reload
    sudo systemctl enable lavad.service
    sudo systemctl restart systemd-journald
    sudo systemctl start lavad
    echo "正在更新区块高度升级..........."
    temp_folder=$(mktemp -d) && cd $temp_folder
    required_upgrade_name="v0.4.3" 
    upgrade_binary_url="https://lava-binary-upgrades.s3.amazonaws.com/testnet/$required_upgrade_name/lavad"
    source ~/.profile
    sudo systemctl stop lavad
    wget "$upgrade_binary_url" -q -O $temp_folder/lavad
    chmod +x $temp_folder/lavad
    sudo cp $temp_folder/lavad $(which lavad)
    sudo systemctl start lavad
    echo "启动成功！"
}

run_lavad(){
    sudo systemctl start lavad
    sleep 5
    echo "启动成功！"
}

stop_lavad(){
    sudo systemctl start stop
    sleep 10
    echo "停止成功！"
}

log_lavad(){
    echo "正在查询，如需退出 LOG 查询请使用 CTRL+C"
    sudo journalctl -u lavad -f
}

status_lavad(){
    echo "正在查询，如需退出状态查询请使用 CTRL+C"
    sudo systemctl status lavad
}

sync_lavad(){
    echo "正在查询同步状态，false是已经同步到最新区块，true则反之"
    lavad status | jq .SyncInfo.catching_up
}

create_lavad(){
    read -p " 请输入钱包名字:" name
    lavad keys add ${name} --keyring-backend "${name}"
    lavad tendermint show-validator
    echo "请保存好如上信息，包括钱包助记词，可以导入Keplr钱包"
}

list_lavad(){
    echo "正在查询....."
    lavad keys list
}

export_lavad(){
    read -p " 请输入你要导出的钱包名字:" name
    echo "正在导出，请输入导出文件的加密秘钥...."
    lavad keys export ${name}
}

import_lavad(){
    read -p " 请输入你要导入的钱包名字:" name
    read -p " 请输入你要导入的钱包文件位置(Finalshell右键文件复制路径即可):" locate
    echo "正在导出，请输入导出文件的加密秘钥...."
    lavad keys import ${name} ${locate}
}

validator_lavad(){
    echo "此功能请同步完节点后使用，同步是否完成请使用 7.查询 Lavad 同步状态 ！"
    echo "同时请确保你的地址有足够的测试代币，请到官方Discord进行领水"
    echo "Lava官方：https://discord.gg/5VcqgwMmkA"
    echo "领水教程将在后续更新，现在官方暂时关闭了通道"
    read -p " 请输入你的钱包名字:" name
    lavad tx staking create-validator \
    --amount="50000ulava" \
    --pubkey=$(lavad tendermint show-validator --home "$HOME/.lava/") \
    --moniker="${name}" \
    --chain-id=lava-testnet-1 \
    --commission-rate="0.10" \
    --commission-max-rate="0.20" \
    --commission-max-change-rate="0.01" \
    --min-self-delegation="10000" \
    --gas="auto" \
    --gas-adjustment "1.5" \
    --gas-prices="0.05ulava" \
    --home="$HOME/.lava/" \
    --from=${name}
    echo "如果返回 code: 0 则验证者质押成功，否则失败同时忽视后面的操作或报错，CTRL+C退出即可"
    sleep 10
    block_time=60
    validator_pubkey=$(lavad tendermint show-validator | jq .key | tr -d '"')
    lavad q staking validators | grep $validator_pubkey
    echo "等待1分钟后返回结果....."
    sleep $block_time
    lavad status | jq .ValidatorInfo.VotingPower | tr -d '"'
    echo "如果返回的数字大于0,则节点验证者验证成功，否则反之"
}

update_lavad(){
    echo "请访问网页 https://github.com/lavanet/lava/releases 查看最新版本"
    echo "比如最新版本是 V0.4.3 就在下方输入V0.4.3"
    read -p "请输入最新版本(比如V0.4.3):" release
    echo "你输入的最新版本是 $release"
    read -r -p "请确认输入的最新版本正确，正确请输入Y，否则将退出 [Y/n] " input
    case $input in
        [yY][eE][sS]|[yY])
            echo "继续更新"
            ;;

        *)
            echo "退出更新..."
            exit 1
            ;;
    esac
    temp_folder=$(mktemp -d) && cd $temp_folder
    upgrade_binary_url="https://lava-binary-upgrades.s3.amazonaws.com/testnet/${release}/lavad"
    source ~/.profile
    sudo systemctl stop lavad
    wget "$upgrade_binary_url" -q -O $temp_folder/lavad
    chmod +x $temp_folder/lavad
    sudo cp $temp_folder/lavad $(which lavad)
    sudo systemctl start lavad
    echo "更新成功！"
}




echo && echo -e " ${Red_font_prefix}Lava Network 一键脚本${Font_color_suffix} by \033[1;35mLattice\033[0m
此脚本完全免费开源，由推特用户 ${Green_font_prefix}@L4ttIc3${Font_color_suffix} 开发
推特链接：${Green_font_prefix}https://twitter.com/L4ttIc3${Font_color_suffix}
欢迎关注，如有收费请勿上当受骗
 ———————————————————————
 ${Green_font_prefix} 1.安装运行环境 ${Font_color_suffix}
 ${Green_font_prefix} 2.安装并运行 Lavad ${Font_color_suffix}
  -----节点功能------
 ${Green_font_prefix} 3.运行 Lavad 节点 ${Font_color_suffix}
 ${Green_font_prefix} 4.停止 Lavad 节点 ${Font_color_suffix}
  -----查询功能------
 ${Green_font_prefix} 5.查询 Lavad 日志 ${Font_color_suffix}
 ${Green_font_prefix} 6.查询 Lavad 运行状态 ${Font_color_suffix}
 ${Green_font_prefix} 7.查询 Lavad 同步状态 ${Font_color_suffix}
  -----钱包功能------
 ${Green_font_prefix} 8.新建 Lavad 钱包 ${Font_color_suffix}
 ${Green_font_prefix} 9.查看 Lavad 钱包 ${Font_color_suffix}
 ${Green_font_prefix} 10.导出 Lavad 钱包 ${Font_color_suffix}
 ${Green_font_prefix} 11.导入 Lavad 钱包 ${Font_color_suffix}
  -----其他功能------
 ${Green_font_prefix} 12.验证 Lavad 节点 ${Font_color_suffix}
 ${Green_font_prefix} 13.更新 Lavad 节点程序 ${Font_color_suffix}

 ———————————————————————" && echo
read -e -p " 请输入数字 [1-6]:" num
case "$num" in
1)
    install_evn
    ;;
2)
    install_lavad
    ;;
3)
    run_lavad
    ;;
4)
    stop_lavad
    ;;
5)
    log_lavad
    ;;
6)
    status_lavad
    ;;
7)
    sync_lavad
    ;;
8)
    create_lavad
    ;;
9)
    list_lavad
    ;;
10)
    export_lavad
    ;;
11)
    import_lavad
    ;;
12)
    validator_lavad
    ;;
13)
    update_lavad
    ;;


*)
    echo
    echo -e " ${Error} 请输入正确的数字"
    ;;
esac