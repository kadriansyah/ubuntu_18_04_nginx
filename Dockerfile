# image name: kadriansyah/ubuntu_18_04_nginx
FROM  ubuntu:18.04
LABEL version="1.0"
LABEL maintainer="Kiagus Arief Adriansyah <kadriansyah@gmail.com>"

ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

# install nginx (https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-open-source/#prebuilt_ubuntu)
RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends wget gnupg2 ca-certificates apt-utils; \
	wget https://nginx.org/keys/nginx_signing.key --no-check-certificate; \
	apt-key add nginx_signing.key; \
	echo "deb https://nginx.org/packages/mainline/ubuntu/ bionic nginx" >> /etc/apt/sources.list.d/nginx.list; \
	echo "deb-src https://nginx.org/packages/mainline/ubuntu/ bionic nginx" >> /etc/apt/sources.list.d/nginx.list; \
	apt-get update; \
	apt-get install nginx; \
	apt-get purge -y --auto-remove wget gnupg2 ca-certificates apt-utils && rm -rf /etc/apt/sources.list.d/nginx.list;

# install nodejs
ENV NODE_VERSION 10.16.3
RUN set -x && apt-get install -yqq curl gnupg
RUN groupadd --gid 1000 node && useradd --uid 1000 --gid node --shell /bin/bash --create-home node
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
	&& case "${dpkgArch##*-}" in \
		amd64) ARCH='x64';; \
		ppc64el) ARCH='ppc64le';; \
		s390x) ARCH='s390x';; \
		arm64) ARCH='arm64';; \
		armhf) ARCH='armv7l';; \
		i386) ARCH='x86';; \
		*) echo "unsupported architecture"; exit 1 ;; \
  	esac \
  	# gpg keys listed at https://github.com/nodejs/node#release-keys
  	&& set -ex \
  	&& for key in \
		94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
		FD3A5288F042B6850C66B31F09FE44734EB7990E \
		71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
		DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
		C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
		B9AE9905FFD7803F25714661B63B535A4C206CA9 \
		77984A986EBC2AA786BC0F66B01FBB92821C587A \
		8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
		4ED778F539E3634C779C87C6D7062848A1AB005C \
		A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
		B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  	; do \
    	gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "$key"; \
  	done \
	&& curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.gz" \
	&& curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
	&& gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
	&& grep " node-v$NODE_VERSION-linux-$ARCH.tar.gz\$" SHASUMS256.txt | sha256sum -c - \
	&& tar -xvf "node-v$NODE_VERSION-linux-$ARCH.tar.gz" -C /usr/local --strip-components=1 --no-same-owner \
	&& rm "node-v$NODE_VERSION-linux-$ARCH.tar.gz" SHASUMS256.txt.asc SHASUMS256.txt \
	&& ln -s /usr/local/bin/node /usr/local/bin/nodejs

# install ruby-2.6.0 & skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 2.6
ENV RUBY_VERSION 2.6.2
ENV RUBY_DOWNLOAD_SHA256 91fcde77eea8e6206d775a48ac58450afe4883af1a42e5b358320beb33a445fa

# some of ruby's build scripts are written in ruby we purge system ruby later to make sure our final image uses what we just built
RUN set -ex \
	\
	&& buildDeps=' \
		bison \
		wget \
		build-essential \
		autoconf \
		dpkg-dev \
		libgdbm-dev \
		zlib1g-dev \
		libssl-dev \
		ruby \
	' \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends $buildDeps \
	&& rm -rf /var/lib/apt/lists/* \
	\
	&& wget -O ruby.tar.gz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR}/ruby-${RUBY_VERSION}.tar.gz" \
	&& mkdir -p /usr/src/ruby \
	&& tar -xvf ruby.tar.gz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.gz \
	\
	&& cd /usr/src/ruby \
	\
	# hack in "ENABLE_PATH_CHECK" disabling to suppress: warning: Insecure world writable dir
	&& { \
		echo '#define ENABLE_PATH_CHECK 0'; \
		echo; \
		cat file.c; \
	} > file.c.new \
	&& mv file.c.new file.c \
	\
	&& autoconf \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--disable-install-doc \
		--enable-shared \
		--with-zlib-dir=/usr \
		--with-openssl-dir=/usr \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& apt-get purge -yqq --auto-remove $buildDeps \
	&& cd / \
	&& rm -r /usr/src/ruby \
	&& ruby --version && gem --version && bundle --version

# install passenger
RUN set -x \
    && apt-get update \
    && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7 \
    && apt-get install -yqq apt-transport-https ca-certificates \
    && sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger bionic main > /etc/apt/sources.list.d/passenger.list' \
    && apt-get update && apt-get install -yqq nginx-extras passenger

# install yarn
ENV YARN_VERSION 1.19.1
RUN set -ex; \
  apt-get update; \
  apt-get install -yqq curl gnupg; \
  for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "$key"; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

# mongodb client
ENV GPG_KEYS 9DA31620334BD75D9DCB49F368818C72E52529D4
RUN set -ex; \
	apt-get update; \
  	apt-get install -yqq wget gnupg; \
	export GNUPGHOME="$(mktemp -d)"; \
	for key in $GPG_KEYS; do \
		gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	done; \
	gpg --batch --export $GPG_KEYS > /etc/apt/trusted.gpg.d/mongodb.gpg; \
	command -v gpgconf && gpgconf --kill all || :; \
	rm -r "$GNUPGHOME"; \
	apt-key list;

ARG MONGO_PACKAGE=mongodb-org
ARG MONGO_REPO=repo.mongodb.org
ENV MONGO_PACKAGE=${MONGO_PACKAGE} MONGO_REPO=${MONGO_REPO}

ENV MONGO_MAJOR 4.2
ENV MONGO_VERSION 4.2.1

RUN wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | apt-key add -
RUN apt-get install gnupg
RUN echo "deb [ arch=amd64,arm64 ] http://$MONGO_REPO/apt/ubuntu bionic/${MONGO_PACKAGE%}/$MONGO_MAJOR multiverse" | tee "/etc/apt/sources.list.d/${MONGO_PACKAGE%}-${MONGO_MAJOR%}.list"

RUN set -x \
	&& apt-get update \
	&& apt-get install -y \
		${MONGO_PACKAGE}-shell=$MONGO_VERSION \
		${MONGO_PACKAGE}-tools=$MONGO_VERSION \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mongodb

RUN set -ex \
        \
        && buildDeps=' \
                gcc \
                make \
                libxml2 \
                libxml2-dev \
                libxslt1-dev \
                zlib1g-dev \
                wget \
                rsync \
        ' \
        && apt-get update \
		&& apt-get install -yqq --no-install-recommends $buildDeps

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80
STOPSIGNAL SIGTERM
CMD ["nginx", "-g", "daemon off;"]
