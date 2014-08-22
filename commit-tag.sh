#!/bin/bash

: ${KEY?'missing github private key do deploy docker run -e KEY=XXXX'}

[ -n "$DEBUG" ] && echo debug on ... && set -x

: ${COMMIT_NAME:=jenkins}
: ${COMMIT_EMAIL:=jenkins@sequenceiq.com}
: ${PROJECT:=cloudbreak}

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

MAVEN_URL=http://maven.sequenceiq.com/releases
PACKAGE=com/sequenceiq
FULLNAME=$PACKAGE/$PROJECT

VERSION=$(curl -Ls $MAVEN_URL/$FULLNAME/maven-metadata.xml|sed -n "s/.*<version>\([^<]*\).*/\1/p" |tail -1)

echo latest jar version is $VERSION ...


rm -rf /tmp/$PROJECT
git clone git@github.com:sequenceiq/$PROJECT.git /tmp/$PROJECT
cd /tmp/$PROJECT
git tag -a $VERSION -m 'jenkins tag commit'
git push -f --tags
