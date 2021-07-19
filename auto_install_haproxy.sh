#! /bin/bash

#first input the server's ip and host in which you want to install the service into follow variables.
HAproxyIP=(ip1 ip2 ip3)
HostName=(host1 host2 host3)

# define some global variables, like the base directory, and the install directory
BaseDir=/home/service/app/
InstallDir=/usr/local/haproxy

# choose the haproxy version that you want to install
Version=2.0.5

# get the local ip that you do run this script on to check if has wrong with the $HAproxyIP $HostName
local_ip=$(ifconfig |awk 'NR==2{print $2}')


## now start to define some function for auto deploy.

function confirm_install(){
        for i in ${HAproxyIP[@]}; do [ "$i" == "$local_ip"  ] && commands="yes"; done
        if [[ $commands == "yes" ]];then
            echo "start install haproxy."
        else
            exit 1
        fi
}

function adduser(){
        groupadd haproxy
        useradd -g haproxy haproxy -s /bin/false

}

function get_pkg(){

        cd $BaseDir
        wget -N -q  http://10.12.29.98:8090/tools/haproxy-2.0.5.tar.gz
        tar zxvf haproxy-$Version.tar.gz -C $BaseDir
        cd haproxy-$Version

}

function patch_install(){
        yum install -y gcc >>error.log
        yum install -y openssl openssl-devel systemd-devel.x86_64 -y >> error.log
        
        #需要判断系统的版本号是否符合haproxy编译条件
        uname -r

        cd $BaseDir/haproxy-$Version
        make TARGET=linux3100 CPU=x86_64 PREFIX=$InstallDir USE_OPENSSL=1 USE_SYSTEMD=1 USE_PCRE=1  USE_ZLIB=1
        make install PREFIX=$InstallDir

}

function set_dir(){

        mkdir -p $InstallDir/conf
        mkdir -p /etc/haproxy
        cd /var/tmp
        wget http://10.12.29.98:8090/tidb/haproxy.cfg
        cp /var/tmp/haproxy.cfg $InstallDir/conf/haproxy.cfg
        ln -s $InstallDir/conf/haproxy.cfg /etc/haproxy/haproxy.cfg

        cp -r $BaseDir/haproxy-$Version/examples/errorfiles $InstallDir/errorfiles
        ln -s $InstallDir/errorfiles /etc/haproxy/errorfiles

        mkdir -p $InstallDir/log/
        touch $InstallDir/log/haproxy.log
        ln -s $InstallDir/log/haproxy.log /var/log/haproxy.log

        ln -s $InstallDir/sbin/haproxy /usr/sbin/haproxy
        chown -R haproxy.haproxy $InstallDir
        chown -R haproxy.haproxy /etc/haproxy

}

function modify_cfg(){

        /bin/sed -i "s#ip1#${HAproxyIP[0]}#g" /etc/haproxy/haproxy.cfg
        /bin/sed -i "s#ip2#${HAproxyIP[1]}#g" /etc/haproxy/haproxy.cfg
        /bin/sed -i "s#ip3#${HAproxyIP[2]}#g" /etc/haproxy/haproxy.cfg

        /bin/sed -i "s#name1#${HostName[0]}#g" /etc/haproxy/haproxy.cfg
        /bin/sed -i "s#name2#${HostName[1]}#g" /etc/haproxy/haproxy.cfg
        /bin/sed -i "s#name3#${HostName[2]}#g" /etc/haproxy/haproxy.cfg
}

function service_init(){

        #cp -r /var/tmp/haproxy.service /usr/lib/systemd/system/
        cd /var/tmp
        wget http://10.12.29.98:8090/tidb/haproxy.service
        cp -r /var/tmp/haproxy.service /usr/lib/systemd/system/
        cd /usr/lib/systemd/system/
        if [  -e haproxy.service  ]
        then
                systemctl daemon-reload
                systemctl enable haproxy
                systemctl start haproxy
        else
                echo "Please create file :/usr/lib/systemd/system/haproxy.service !"
        fi

}

confirm_install
adduser
get_pkg
patch_install
set_dir
modify_cfg
service_init
