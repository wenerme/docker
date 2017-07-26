#!/bin/bash
set -e
[ -z "$VERBOSE" ] || set -o xtrace

echo Load build init script

command -v git > /dev/null || {
echo "NOTE: Git not found"
alias git="echo Git Not Found:"
}
BRANCH=${BRANCH:-`git rev-parse --abbrev-ref HEAD`}
COMMIT=${COMMIT:-`git log --pretty=format:'%h' -n 1`}
COMMENT=${COMMENT:-`git log -1 --pretty=%B | tr '\n' ' '`}

# registry.cn-hangzhou.aliyuncs.com
# registry.wener.me
DOCKER_REGISTRY=${DOCKER_REGISTRY:-docker.io}
GROUP=${GROUP:-wener}

buildreport(){
    echo "Building `date +"%Y%m%d%H%M"` ${BRANCH}@${COMMIT} : ${COMMENT}"
}

# Build container in current dir
builddocker(){
local name=$(basename $PWD)
local repo=${REPO:-$GROUP/$name}
echo "Building container: $repo in '$PWD'"

[ -f 'Dockerfile' ] || { echo No Dockerfile in "'$PWD'";exit 1; }
[ -f "before.sh" ] && echo Call before hook && ./before.sh || true

if [ -z "${BUILD_IN_PARENT}" ]; then
    docker build -t ${repo} .
else
    echo "Build in parent dir $(realpath $PWD/..)"
    ( cd ..; docker build -t ${repo} . -f ${name}/Dockerfile )
fi

[ -f "after.sh" ] && echo Call after hook && ./after.sh || true

}

builddocker_dirs(){
local names="$@"
echo "Building docker dir: $names"
for name in ${names};
do

    [ -f "$name/before.sh" ] && echo Call before hook && ${name}/before.sh
    if [ -f "$name/build.sh" ];
    then
        echo Call custom build
        ${name}/build.sh
    else
        ( cd ${name} && builddocker )
    fi
    [ -f "$name/after.sh" ] && echo Call after hook && ${name}/after.sh

done

if [ -z "$SKIP_PUSH" ]; then

for name in $names;
do
    REPO=$GROUP/$name
    echo Pushing $REPO
    # 只有在没有 build.sh 且镜像内容发生了改变时才推送
    [ -f "$name/build.sh" ] || [ "`docker images $REPO --format '{{.ID}}' | head -n1`" != "`docker images $DOCKER_REGISTRY/$REPO --format '{{.ID}}' | head -n1`" ] && {
#        docker tag $REPO $DOCKER_REGISTRY/$REPO:$BUILD_VERSION
#        docker push $DOCKER_REGISTRY/$REPO:$BUILD_VERSION
        docker tag $REPO $DOCKER_REGISTRY/$REPO
        docker push $DOCKER_REGISTRY/$REPO
    } || {
        echo $REPO unchanged
    }
done

fi
}

builddocker_vers(){
local name="`basename $PWD`"
local names="$@"
echo "Building docker versions: $names"
for ver in ${names}; do
    # Use latest
    if [ "$ver" = "$name" ]; then
        REPO="$GROUP/$name"
    else
        REPO="$GROUP/$name:$ver"
    fi
    echo "Build version $REPO"
    ( cd ${ver} && builddocker )
done

if [ -z "$SKIP_PUSH" ]; then

for ver in $names; do
    if [ "$ver" = "$name" ]; then
    REPO=$GROUP/$name
    else
    REPO=$GROUP/$name:$ver
    fi

    [ "`docker images $REPO --format '{{.ID}}' | head -n1`" != "`docker images $DOCKER_REGISTRY/$REPO --format '{{.ID}}' | head -n1`" ] && {
        docker tag $REPO $DOCKER_REGISTRY/$REPO
        docker push $DOCKER_REGISTRY/$REPO
    } || {
        echo $REPO unchanged
    }
done

fi
}

builddocker_init_ver(){
NAME=$1
[ "`basename $PWD`" == "$NAME" ] || cd $NAME

# Reset configs
# 在上级目录构建
unset BUILD_IN_PARENT
}
