FROM koding/base
MAINTAINER Sonmez Kartal <sonmez@koding.com>

ADD pgdg.list /etc/apt/sources.list.d/pgdg.list

RUN curl --silent --location https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
    apt-key add - && \
    apt-get update && \
    apt-get install --yes \
            mongodb-server \
            postgresql-9.3 postgresql-contrib-9.3 \
            rabbitmq-server \
            redis-server

RUN rabbitmq-plugins enable rabbitmq_management

USER postgres
RUN sed -i "s/#listen_addresses =.*/listen_addresses = '*'/" /etc/postgresql/9.3/main/postgresql.conf
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.3/main/pg_hba.conf
USER root

ADD entrypoint.sh /opt/
ADD wait.sh /opt/wait.sh

RUN wget --quiet https://github.com/koding/koding/archive/master.zip && \
    unzip -q master.zip && mv koding-master /opt/koding && \
    rm -f master.zip

WORKDIR /opt/koding

RUN service postgresql start && \
    su postgres --command go/src/socialapi/db/sql/definition/create.sh go/src/socialapi/db/sql && \
    service postgresql stop

RUN npm install --unsafe-perm && \
    echo master > VERSION && \
    ./configure --host localhost --hostname localhost --publicPort 80 && \
    go/build.sh && \
    service postgresql start && ./run migrate up && service postgresql stop && \
    make -C client dist && \
    rm -rf generated

VOLUME ["/var/lib/mongodb", "/var/lib/postgresql"]

ENTRYPOINT ["/opt/entrypoint.sh"]
