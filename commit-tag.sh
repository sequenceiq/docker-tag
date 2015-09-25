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
  ACTUAL_VERSION=$(echo $(git describe --abbrev=0 --tags))
  echo $ACTUAL_VERSION
  RC_VERSION=$(semver $ACTUAL_VERSION -i minor)-rc.0
  RC_BRANCH_MAJOR=$(semver $ACTUAL_VERSION -i minor|cut -d \. -f 1)
  RC_BRANCH_MINOR=$(semver $ACTUAL_VERSION -i minor|cut -d \. -f 2)
  RC_BRANCH=rc-$RC_BRANCH_MAJOR.$RC_BRANCH_MINOR
  echo $RC_VERSION
  git checkout -b $RC_BRANCH
  git tag $RC_VERSION
  git push -f --tags
  git checkout master
  NEW_VERSION=$RC_BRANCH_MAJOR.$RC_BRANCH_MINOR.0
  NEW_DEV_VERSION=$(semver $NEW_VERSION -i minor)-dev.0
  git tag $NEW_DEV_VERSION
  git push -f --tags
}

dev_to_dev() {
  ACTUAL_VERSION=$(echo $(git describe --abbrev=0 --tags))
  DEV_VERSION=$(echo $ACTUAL_VERSION | tr '.' '\n'|tail -1)
  DEV_VERSION=$((DEV_VERSION+1))
  NEW_VERSION=$(semver $ACTUAL_VERSION -i patch)-dev.$DEV_VERSION
  echo $NEW_VERSION
  git tag $NEW_VERSION
  git push -f --tags
}

rc_to_rc() {
  ACTUAL_BRANCH=$(echo $GIT_BRANCH|cut -d \/ -f 2)
  git checkout $ACTUAL_BRANCH
  LAST_TAG=$(echo $(git describe --abbrev=0 --tags))
  RC_VERSION=$(echo $LAST_TAG | tr '.' '\n'|tail -1)
  RC_VERSION=$((RC_VERSION+1))
  NEW_RC=$(semver $LAST_TAG -i patch)-rc.$RC_VERSION
  git tag $NEW_RC
  git push -f --tags
}

rc_to_release() {
  git checkout $BRANCH
  ACTUAL_VERSION=$(echo $(git describe --abbrev=0 --tags))
  echo $ACTUAL_VERSION
  RELEASE_VERSION=$(semver $ACTUAL_VERSION -i)
  git checkout -b release-$ACTUAL_VERSION
  git tag $RELEASE_VERSION
  git push -f --tags
  git push origin release-$RELEASE_VERSION

  git checkout $BRANCH
  RC_BRANCH_MAJOR=$(echo $ACTUAL_VERSION|cut -d \. -f 1)
  RC_BRANCH_MAJOR=$(echo $RC_BRANCH_MAJOR| sed "s/v//g")
  RC_BRANCH_MINOR=$(echo $ACTUAL_VERSION|cut -d \. -f 2)
  RC_BRANCH_PATCH=$(echo $ACTUAL_VERSION|cut -d \. -f 3)
  RC_BRANCH_PATCH=$(echo $RC_BRANCH_PATCH| sed "s/-rc//g")
  NEW_VERSION=$RC_BRANCH_MAJOR.$RC_BRANCH_MINOR.$RC_BRANCH_PATCH
  PATCHED_VERSION=$(semver $NEW_VERSION -i patch)-rc.0
  git tag $PATCHED_VERSION
  git push -f --tags
}

$COMMAND
