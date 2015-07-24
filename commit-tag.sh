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

dev_to_rc() {
  ACTUAL_VERSION=$(echo $(npm version))
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/{//g")
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/}//g")
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/ //g")
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|cut -d \, -f 1)
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/$PROJECT://g")
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/'//g")

  echo $ACTUAL_VERSION
  RC_VERSION=$(semver $ACTUAL_VERSION -i minor)-rc.0
  RC_BRANCH_MAJOR=$(semver $ACTUAL_VERSION -i minor|cut -d \. -f 1)
  RC_BRANCH_MINOR=$(semver $ACTUAL_VERSION -i minor|cut -d \. -f 2)
  RC_BRANCH=rc-$RC_BRANCH_MAJOR.$RC_BRANCH_MINOR
  echo $RC_VERSION
  git checkout -b $RC_BRANCH
  npm version $RC_VERSION -m "increase version [ci skip]" 
  git push -f origin $RC_BRANCH
  git push -f --tags 
  git checkout master 
  NEW_VERSION=$RC_BRANCH_MAJOR.$RC_BRANCH_MINOR.0
  npm version $(semver $NEW_VERSION -i minor)-dev.0 -m "increase version [ci skip]"  
  git push -f origin $BRANCH 
  git push -f --tags
}

dev_to_dev() {
  npm version prerelease -m "increase version [ci skip]" && git push -f origin $BRANCH && git push -f --tags
}

rc_to_rc() {
  ACTUAL_BRANCH=$(echo $GIT_BRANCH|cut -d \/ -f 2)       
  git checkout $ACTUAL_BRANCH && npm version prerelease -m "increase version [ci skip]" && git push -f origin $ACTUAL_BRANCH && git push -f --tags
}

rc_to_release() {
  git checkout $BRANCH
  ACTUAL_VERSION=$(echo $(npm version))
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/{//g")
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/}//g")
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/ //g")
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|cut -d \, -f 1)
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/$PROJECT://g")
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/'//g")
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|sed "s/'//g")
  ACTUAL_VERSION=$(echo $ACTUAL_VERSION|cut -d \- -f 1)
  echo $ACTUAL_VERSION

  git checkout -b release-$ACTUAL_VERSION
  npm version $ACTUAL_VERSION -m "increase version [ci skip]" && git push -f origin release-$ACTUAL_VERSION && git push -f --tags
  
  git checkout $BRANCH
  RC_BRANCH_MAJOR=$(echo $ACTUAL_VERSION|cut -d \. -f 1)
  RC_BRANCH_MINOR=$(echo $ACTUAL_VERSION|cut -d \. -f 2)
  RC_BRANCH_PATCH=$(echo $ACTUAL_VERSION|cut -d \. -f 3)
  NEW_VERSION=$RC_BRANCH_MAJOR.$RC_BRANCH_MINOR.$RC_BRANCH_PATCH
  PATCHED_VERSION=$(semver $NEW_VERSION -i patch)-rc.0
  npm version $PATCHED_VERSION -m "increase version [ci skip]" && git push -f origin $BRANCH && git push -f --tags
}

$COMMAND
