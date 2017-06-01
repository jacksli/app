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

#!/bin/bash
# https://github.com/jacksli/app

cd $(readlink -e $(dirname $0))
curdir=$(pwd)
workdir=${curdir%/*}
[ ! -f ${workdir}/scripts/function.sh ] && echo "${workdir}/scripts/function.sh does't exist" && exit 1 
source ${workdir}/scripts/function.sh
action=$1
env=$2
# 
# checksys get username & userid 
# checksys check something
#-----------------------------------------------
checksys $*
create_app_skeleton ${username}
install_app ${action} ${env}
