FROM cloudfoundry/cnb:cflinuxfs3
USER root
RUN apt update -qqy && apt install re2c
