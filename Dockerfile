FROM koding/base
MAINTAINER Sonmez Kartal <sonmez@koding.com>

RUN apt-get update && \
    apt-get install --yes \
            mongodb-server \
            postgresql postgresql-contrib \
            rabbitmq-server \
            redis-server

RUN rabbitmq-plugins enable rabbitmq_management

USER postgres
RUN sed -i "s/#listen_addresses =.*/listen_addresses = '*'/" /etc/postgresql/9.3/main/postgresql.conf
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.3/main/pg_hba.conf
USER root

ADD entrypoint.sh /opt/

RUN wget --quiet https://github.com/koding/koding/archive/master.zip && \
    unzip -q master.zip && mv koding-master /opt/koding && \
    rm -f master.zip

WORKDIR /opt/koding

RUN service postgresql start && \
    go/src/socialapi/db/sql/definition/create.sh go/src/socialapi/db/sql && \
    service postgresql stop

RUN npm install --unsafe-perm && \
    ./configure --host localhost:8090 --hostname localhost --version dist && \
    go/build.sh && \
    service postgresql start && \
    ./run migrate up && \
    service postgresql stop && \
    make -C client dist && \
    rm -rf generated

EXPOSE 8090:80

ENTRYPOINT ["/opt/entrypoint.sh"]
