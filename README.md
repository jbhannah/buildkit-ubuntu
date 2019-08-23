# buildkit-ubuntu

[BuildKit][] packaged in an Ubuntu image for portable use.

## Usage

An Ouroborosian example:

    git clone https://github.com/jbhannah/buildkit-ubuntu
    cd buildkit-ubuntu
    docker run --rm -it -v `pwd`:`pwd` -w `pwd` --privileged \
        jbhannah/buildkit-ubuntu buildctl build --frontend dockerfile.v0 \
        --local context=. --local dockerfile=. \
        --export-cache type=local,dest=./cache \
        --output type=docker,name=jbhannah/buildkit-ubuntu,dest=./out.tar

## Copyright

Copyright © 2019 Jesse B. Hannah. This image and BuildKit itself are both
licensed under the Apache License version 2.0 (see [LICENSE](LICENSE)).

[buildkit]: https://github.com/moby/buildkit
