#!/bin/bash

sudo apt update -yqq && apt install --no-install-recommends -yqq autoconf-archive unzip uuid-dev odbc-postgresql unixodbc unixodbc-dev \
	memcached libmemcached-dev libssl-dev \
	zlib1g-dev cmake make clang-format ninja-build libcurl4-openssl-dev git libpq-dev \
	wget build-essential pkg-config libpcre3-dev curl libgtk2.0-dev libgdk-pixbuf2.0-dev bison flex libreadline-dev
sudo apt-get install --reinstall ca-certificates

export IROOT=/tmp
cd $IROOT

sudo mkdir /usr/local/share/ca-certificates/cacert.org
sudo wget -P /usr/local/share/ca-certificates/cacert.org http://www.cacert.org/certs/root.crt http://www.cacert.org/certs/class3.crt
sudo update-ca-certificates
sudo git config --global http.sslCAinfo /etc/ssl/certs/ca-certificates.crt

#redis will not start correctly on bionic with this config
#sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis/redis.conf

#echo never > /sys/kernel/mm/transparent_hugepage/enabled
#echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local
#sysctl vm.overcommit_memory=1

#service apache2 stop
#service memcached stop
#service redis-server stop

cd $IROOT
git clone https://github.com/efficient/libcuckoo.git
cd libcuckoo
git checkout ea8c36c65bf9cf83aaf6b0db971248c6ae3686cf -b works
cmake -DCMAKE_INSTALL_PREFIX=/usr .
sudo make install
cd $IROOT
rm -rf libcuckoo

wget -q https://cdn.mysql.com/Downloads/Connector-ODBC/8.0/mysql-connector-odbc_8.0.29-1ubuntu21.10_amd64.deb
sudo dpkg -i mysql-connector-odbc_8.0.29-1ubuntu21.10_amd64.deb
wget -q https://cdn.mysql.com/Downloads/Connector-ODBC/8.0/mysql-connector-odbc-setup_8.0.29-1ubuntu21.10_amd64.deb
sudo dpkg -i mysql-connector-odbc-setup_8.0.29-1ubuntu21.10_amd64.deb
rm -f *.deb

wget -q https://github.com/mongodb/mongo-c-driver/releases/download/1.4.2/mongo-c-driver-1.4.2.tar.gz
tar xf mongo-c-driver-1.4.2.tar.gz
rm -f mongo-c-driver-1.4.2.tar.gz
cd mongo-c-driver-1.4.2/ && \
    ./configure --disable-automatic-init-and-cleanup && \
    make && sudo make install
cd $IROOT
rm -rf mongo-c-driver-1.4.2 

wget -q https://github.com/redis/hiredis/archive/v1.0.2.tar.gz
tar xf v1.0.2.tar.gz
rm -f v1.0.2.tar.gz
cd hiredis-1.0.2/
cmake . && sudo make install
cd $IROOT
rm -rf hiredis-1.0.2

wget -q https://github.com/sewenew/redis-plus-plus/archive/refs/tags/1.3.5.tar.gz
tar xf 1.3.5.tar.gz
rm -f 1.3.5.tar.gz
cd redis-plus-plus-1.3.5/
mkdir build
cd build
cmake -DREDIS_PLUS_PLUS_CXX_STANDARD=17 .. && sudo make && make install
cd $IROOT
rm -rf redis-plus-plus-1.3.5
