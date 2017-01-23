load common

@test 'create tarball directory if needed' {
    mkdir -p $TARDIR
}

@test 'executables --help' {
    # Assume that everything in $CH_BIN is ours if it starts with "ch-" and
    # either (1) is executable or (2) ends in ".c". Demand satisfaction from
    # each. The latter is to catch cases when we haven't compiled everything;
    # if we have, the test makes duplicate demands, but that's low cost.
    for i in $(find $CH_BIN -name 'ch-*' -a \( -executable -o -name '*.c' \));
    do
        i=$(echo $i | sed s/.c$//)
        echo $i
        $i --help
    done
}

@test 'proxy variables' {
    # Proxy variables are a mess on UNIX. There are a lot them, and different
    # programs use them inconsistently. This test is based on the assumption
    # that if one of the proxy variables are set, then they all should be, in
    # order to prepare for diverse internet access at build time.
    #
    # Coordinate this test with bin/docker-build.
    #
    # Note: ALL_PROXY and all_proxy aren't currently included, because they
    # cause image builds to fail until Docker 1.13
    # (https://github.com/docker/docker/pull/27412).
    V=' no_proxy http_proxy https_proxy'
    V+=$(echo "$V" | tr '[:lower:]' '[:upper:]')
    empty_ct=0
    for i in $V; do
        if [[ -n ${!i} ]]; then
            echo "$i is non-empty"
            for j in $V; do
                echo "  $j=${!j}"
                if [[ -z ${!j} ]]; then
                    (( ++empty_ct ))
                fi
            done
            break
        fi
    done
    [[ $empty_ct -eq 0 ]]
}

@test 'docker run hello-world' {
    # Does Docker basically work before we start in on the Charliecloud stuff?
    # First, clear the cache so we pull from the internet and start from a
    # known (empty) state.
    containers=$(sudo docker ps -qaf ancestor=hello-world)
    if [[ -n $containers ]]; then
        sudo docker rm $containers
    fi
    images=$(sudo docker images -qa hello-world)
    if [[ -n $images ]]; then
        sudo docker rmi $images
    fi
    sudo docker run hello-world
    # This one should use the cache (though we don't verify that).
    sudo docker run hello-world
}

@test 'docker-build' {
    cd chtest
    docker-build -t chtest ../..
    docker_ok chtest
}

@test 'docker-build --pull' {
    # this may get a new image, if edge has been updated
    docker-build --pull -t alpineedge --file=./Dockerfile.alpineedge ..
    # this very probably will not
    docker-build --pull -t alpineedge --file=./Dockerfile.alpineedge ..
}

@test 'ch-dockerfile2dir' {
    # This test unpacks into $TARDIR so we don't put anything in $IMGDIR at
    # build time. It removes the image on completion.
    TAR=$CHTEST_TARBALL
    IMG=$TARDIR/chtest
    [[ ! -e $IMG ]]
    cd chtest
    # Dockerfile expected in $CWD
    ch-dockerfile2dir ../.. $TARDIR
    docker_ok chtest
    image_ok $IMG
    # Same, overwrite
    ch-dockerfile2dir ../.. $TARDIR
    docker_ok chtest
    image_ok $IMG
    # Remove since we don't want it hanging around later
    rm -Rf $TAR $IMG
}