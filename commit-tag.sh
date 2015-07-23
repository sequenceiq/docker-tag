#!/bin/bash

: ${KEY?'missing github private key do deploy docker run -e KEY=XXXX'}

[ -n "$DEBUG" ] && echo debug on ... && set -x

: ${COMMIT_NAME:=jenkins}
: ${COMMIT_EMAIL:=jenkins@sequenceiq.com}
: ${PROJECT:=cb-shell}
: ${BRANCH:=master}
: ${ORGANIZATION:=sequenceiq}
: ${PRE_RUN_COMMAND:=echo pre run command}
: ${POST_RUN_COMMAND:=echo post run command}

# private github key comes from env variable KEY
# docker run -e KEY=XXXX
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# switch off debug to hide private key
set +x
echo $KEY|base64 -d> /root/.ssh/id_rsa
[ -n "$DEBUG" ] && echo debug on ... && set -x

chmod 600 /root/.ssh/id_rsa

# saves githubs host to known_hosts
ssh -T -o StrictHostKeyChecking=no  git@github.com

git config --global user.name "$COMMIT_NAME"
git config --global user.email "$COMMIT_EMAIL"

rm -rf /tmp/$PROJECT
git clone git@github.com:$ORGANIZATION/$PROJECT.git /tmp/$PROJECT
cd /tmp/$PROJECT
git checkout $BRANCH
npm install
npm install semver -g
ACTUAL_VERSION=$(echo $(npm version)|sed 's/{//g' |sed 's/}//g'|sed 's/ //g'| cut -d \, -f 1|sed s/$PROJECT://g|sed "s/'//g")
echo $ACTUAL_VERSION
TEST=$(npm version $(semver $ACTUAL_VERSION -i minor)-rc.0)
echo $TEST
git checkout -b $TEST 
npm version $TEST -m "increase version [ci skip]" 
git push -f origin $TEST
git push -f --tags 
git checkout master 
npm version $(semver $ACTUAL_VERSION -i minor)-dev.0 -m "increase version [ci skip]"  
git push -f origin $BRANCH 
git push -f --tags
