#
# Licensed to app under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. app licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

#!/bin/bash
# https://github.com/jacksli/app

function errmsg()
{
    echo "                    "
    echo "          $1        "
    exit 1
}

function usage() {
    echo -e "\nUsage:"
    echo -e "\t`basename $0` [action  env [-q]]\n"
    echo -e "Parameters:"
    echo -e "\taction:  { install | update | uninstall | restore }"
    echo -e "\tenv:  { developing | product | staging }"
    echo -e "\t-q:      quiet mode, no interation.\n"
    exit 1
}

#
#$1: username
#$2: userid
#--------------------------------------------------------------------------------
function adduser()
{
    id -u $1 >/dev/null && [ X$(id -u $1) == X$2 ] && [ X$(id -g $1) == X1001 ] && return 0   
    id -u $1 >/dev/null && [ X$(id -u $1) != X$2 ] && errmsg "username $1 userid not $2"
    id -u $1 >/dev/null && [ X$(id -g $1) != X1001 ] && errmsg "username $1 groupid not 1001"
    sudo useradd -u $2 -g 1001 -s /sbin/nologin  $1 || errmsg "add user $1 failed"
}

#
# check 
#------------------------------------------------------------------------------
function checksys()
{
    [ $# -lt 2 ] && usage
    [ ! -f ${workdir}/ReadMe ] &&  errmsg "ReadMe does't exist"
    [ ! -f /etc/redhat-release ] && errmsg "/etc/redhat-release does't exist"
    grep -E 7.[0-9] /etc/redhat-release || errmsg "os should be centos 7.x"
    [ X$(id -u) == X0 ] || errmsg "you should have root privileges"
    sudo yum install -y dos2unix >/dev/null || errmsg "install dos2unix failed"
    dos2unix ${workdir}/ReadMe
    username=$(awk -F'=' '/Project/{print $2}' ${workdir}/ReadMe  | tr -d ' ')
    [ X${username} == X ] && errmsg "username can't be null"
    userid=$(awk -F'=' '/User_ID/{print $2}' ${workdir}/ReadMe  | tr -d ' ')  
    [ X${userid} == X ] && errmsg "userid can't be null"     
    echo ${workdir} | grep "/home/${username}/src" || errmsg "scripts should be in /home/${username}/src"
    env_type=$(find ${workdir}/config -maxdepth 1 -mindepth 1 -type d | awk -F'/' '{print $NF}' | xargs )
    echo ${env_type} | grep -w ${env} >/dev/null || errmsg "${env} does't support"    
    [ X$(id -u ${username}) != X${userid} ] && errmsg "${username} userid is not ${userid}"  
    grep -w ${username} /etc/passwd | grep -w '/bin/bash' && errmsg "${username} should use /sbin/nologin as shell"
}

#
# $1: user name
#---------------------------------------------------------------------------------------------------------
function create_app_skeleton() {
    chown -R $1:program /home/$1 
    chmod 770 /home/$1
    [ -d /home/$1/conf ] && sudo -u $1 rm -fr /home/$1/conf
    sudo -u $1 mkdir -p /home/$1/{bin,conf,data/cache,log,src,tmp,www}
    sudo -u $1 chmod -R g+rw,o-rwx /home/$1/{data,log}
    sudo -u $1 ln -fsn ${workdir} /home/$1/src/CURRENT
    sudo -u $1 find /home/$1/src/CURRENT/config/${env} -maxdepth 1 -mindepth 1 -exec ln -fsn {} /home/$1/conf \;
    sudo -u $1 find /home/$1/src/CURRENT/config/ -maxdepth 1 -mindepth 1 -type f -exec ln -fsn {} /home/$1/conf \;
    sudo -u $1 ln -fsn /home/$1/src/CURRENT/web /home/$1/www/htdocs
    sudo -u $1 find /home/$1/src/CURRENT/scripts -type f -exec ln -fsn {} /home/$1/bin \;
}

# do_crontab
# $1: action: { install | update | uninstall }
# $2: env: {developing | staging | product }
#---------------------------------------------------------------------------------------------------------
function do_crontab()
{
    [ ! -f /home/${username}/conf/crontab.conf ] && return 0
    case $1 in
        install | update )
        sudo crontab -u ${username} /home/${username}/conf/crontab.conf || errmsg "crontab -u ${username} failed"
        ;;
        uninstall )
        sudo crontab -u ${username} -r
        ;;
        * )
        errmsg "crontab does't support"
        ;;
esac
}

# do_logrotate
# $1: action: { install | update | uninstall }
# $2: env: {developing | staging | product }
#---------------------------------------------------------------------------------------------------------
function do_logrotate()
{
    [ ! -f /home/$1/conf/logrotate.conf ] && return 0
    case $1 in
        install | update )
        sudo ln -fsn /home/$1/conf/logrotate.conf /etc/logrotate.d/${username}
        ;;
        uninstall )
        [ -f /etc/logrotate.d/${username} ] && sudo unlink /etc/logrotate.d/${username}
        ;;
        * )
        errmsg "do_logrotate does't support"
        ;;
esac
}

function install_php()
{
    sudo yum install -y php70 php70-php-bcmath php70-php-devel php70-php-gd php70-php-json php70-php-mbstring php70-php-mcrypt php70-php-mysqlnd php70-php-pear php70-php-pecl-mongodb php70-php-phalcon3 php70-php-xml php70-php-pecl-couchbase2   >/dev/null || errmsg "install php70 packages failed"
    sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/opt/remi/php70/php.ini
    sudo sed -i "s/expose_php.*/expose_php = Off/"  /etc/opt/remi/php70/php.ini 
    sudo ln -fsn /opt/remi/php70/enable /etc/profile.d/enable.sh
    source /etc/profile >/dev/null 
}

# do_httpd
# $1: action: { install | update | uninstall }
# $2: env: {developing | staging | product }
# install php 7.x
#---------------------------------------------------------------------------------------------------------
function do_httpd()
{
    [ ! -f /home/${username}/conf/httpd.conf ] && [ ! -f /home/${username}/conf/httpd.${username}.conf ] && return 0  
    [ -f /home/${username}/conf/httpd.conf ] && sudo -u ${username} mv /home/${username}/conf/httpd.conf /home/${username}/conf/httpd.${username}.conf
    install_php
    sudo yum install -y httpd >/dev/null || errmsg "install httpd failed"
    sudo yum install -y php70-php >/dev/null || errmsg "install httpd php modules failed"
    sudo usermod -G 1001 apache
    port=$(awk '/Listen/{print $2}' /home/${username}/conf/httpd.${username}.conf | tr -d ' ' )
    ss -ltnp | awk '{print $4}' | grep -w ${port} >/dev/null || flag="unused"
    [ X${flag} == Xunused ] ||  ss -tlnp | awk '/httpd/{print $4}' | grep -w ${port} || errmsg "${port} not used by httpd"  
    echo "ServerTokens Prod" >/etc/httpd/conf.d/security.conf
    echo "ServerName localhost:80" >>/etc/httpd/conf.d/security.conf
    echo "FileETag None" >>/etc/httpd/conf.d/security.conf
    sudo systemctl enable httpd.service
    case $1 in
        install | update )
        sudo ln -fsn /home/${username}/conf/httpd.${username}.conf /etc/httpd/conf.d/httpd.${username}.conf
        sudo httpd -t || errmsg "httpd syntax problem"          
        pgrep -f "/usr/sbin/httpd -k graceful"  && sleep 5
        pgrep -f "/usr/sbin/httpd -k graceful"  && errmsg "/usr/sbin/httpd -k graceful still exist"
        pgrep -f "/usr/sbin/httpd" && sudo systemctl reload httpd.service || sudo systemctl restart httpd.service || errmsg "start httpd failed"
        ;;
        uninstall )
        [ ! -f /etc/httpd/conf.d/httpd.${username}.conf ] && return 0
        sudo unlink /etc/httpd/conf.d/httpd.${username}.conf
        pgrep -f "/usr/sbin/httpd" || return 0
        sudo httpd -t || errmsg "httpd syntax problem"
        pgrep -f "/usr/sbin/httpd -k graceful"  && sleep 5
        pgrep -f "/usr/sbin/httpd -k graceful"  && errmsg "/usr/sbin/httpd -k graceful still exist"
        sudo systemctl reload httpd.service || errmsg "start httpd failed"
        ;;
        * )
        errmsg "httpd does't support $1"    
        ;;
esac   
}

# install app
# $1: action: { install | update | uninstall }
# $2: env: {developing | staging | product }
#----------------------------------------------------------------------------------------------------------
function install_app()
{
    action=$1   
    env=$2
    do_crontab ${action} ${env}
    do_logrotate ${action} ${env}
    do_httpd ${action} ${env}
    sudo find /home/${username}/src/CURRENT -type f -exec chmod 440 {} \;
    sudo find /home/${username}/src/CURRENT -type d -exec chmod 550 {} \;
    [ ! -f /home/${username}/bin/customer.sh ] && return 0
    sudo -u ${username} /bin/sh /home/${username}/bin/customer.sh  || errmsg "execute customer.sh failed"
}
