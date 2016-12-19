/*
* Licensed to app under one or more contributor
* license agreements. See the NOTICE file distributed with
* this work for additional information regarding copyright
* ownership. app licenses this file to you under
* the Apache License, Version 2.0 (the "License"); you may
* not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*    http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing,
* software distributed under the License is distributed on an
* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
* KIND, either express or implied.  See the License for the
* specific language governing permissions and limitations
* under the License.
*/



#!/bin/bash
# https://github.com/jacksli/app

function help()
{
    type=$(find ${workdir}/config/developing  -mindepth 1 -maxdepth 1 -type d -exec basename '{}' \;)
    echo "usage: <username> <userid> <type>"
    echo "username: user name of application"
    echo "userid: user id of application"
    echo "type: $(echo ${type} | xargs)                        "
    exit 1
}

function checking()
{
    [ $# -lt 3 ] && help
    grep -E 7.[0-9] /etc/redhat-release || errmsg "os should be centos 7.x"
    [ X$(id -u) == X0 ] || errmsg "you should have root privileges"
    inrpm tree
}

function createapp()
{
    sudo mkdir -p /home/${username}/src/release 
    sudo /bin/cp -fr ${workdir}/scripts /home/${username}/src/release
    sudo find ${workdir} -maxdepth 1 -mindepth 1 -type f -exec /bin/cp -fr {} /home/${username}/src/release \;
    [ -f /home/${username}/src/release/build.sh ] && sudo rm -fr /home/${username}/src/release/build.sh
    sudo mkdir -p /home/${username}/src/release/config/{developing,staging,product}
    sudo mkdir -p /home/${username}/src/release/web
    sudo /bin/cp -fr ${workdir}/config/developing/${type}/* /home/${username}/src/release/config/developing
    sudo /bin/cp -fr ${workdir}/config/staging/${type}/* /home/${username}/src/release/config/staging
    sudo /bin/cp -fr ${workdir}/config/product/${type}/* /home/${username}/src/release/config/product
    sudo find ${workdir}/config -maxdepth 1 -mindepth 1 -type f -exec /bin/cp -fr {} /home/${username}/src/release/config \;
    sudo /bin/cp -fr ${workdir}/web/${type}/* /home/${username}/src/release/web
    port=$((userid*10))
    for file in $(sudo find /home/${username}/src/release -type f)
    do
        sudo sed -i -e "s/%APP_PORT%/${port}/g" ${file} /home/${username}/src/release/ReadMe
        sudo sed -i -e "s/%APP_NAME%/${username}/g" ${file} /home/${username}/src/release/ReadMe
        sudo sed -i -e "s/%APP_ID%/${userid}/g" ${file} /home/${username}/src/release/ReadMe
        sudo sed -i -e "s/%APP_TYPE%/${type}/g" ${file} /home/${username}/src/release/ReadMe
        sudo sed -i -e "s/%APP_PATH%/\/home\/${username}/g" ${file} /home/${username}/src/release/ReadMe
    done 
    tree /home/${username}/src/release
    sleep 15
    echo "you april is place in /home/${username}/src/release"   
    echo "usage example                                      "
    echo "sudo sh /home/${username}/src/release/scripts/install.sh install developing -q "
}

cd $(readlink -e $(dirname $0))
workdir=$(pwd)
[ ! -f ${workdir}/scripts/function.sh ] && echo "${workdir}/scripts/function.sh does't exist" && exit 1 
source ${workdir}/scripts/function.sh
username=$1
userid=$2
type=$3
checking $*
adduser ${username} ${userid}
createapp
