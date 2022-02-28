#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# from https://www.drupal.org/docs/system-requirements/php-requirements
FROM php:8.0-apache-bullseye

# Install all the stuff we need
# Enable rewrite
RUN set -eux; \
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi

# Install packages 
RUN	apt-get update; \
	apt-get install -y --no-install-recommends \
		apt-utils \
		autoconf \
		automake \
		openjdk-11-jdk \
		git \
		iipimage-server \
		iipimage-doc \
		libapache2-mod-fcgid \
		libfreetype6-dev \
		libjpeg-dev \
		libjpeg62-turbo \
		libpng-dev \
		libpng16-16 \
		libpq-dev \
		libtiff-dev \
		libtiff5 \
		libtool \
		libvips-dev \
		libvips-tools \
		libzip-dev \
		imagemagick \
		unzip \
		vim \
		wget

# Add php extensions
RUN	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr \
		--with-webp; \
	docker-php-ext-install -j "$(nproc)" \
		gd \
		opcache \
		pdo_mysql \
		pdo_pgsql \
		zip

# Upload progress
RUN	set -eux; \
	git clone https://github.com/php/pecl-php-uploadprogress/ /usr/src/php/ext/uploadprogress/; \
	docker-php-ext-configure uploadprogress; \
	docker-php-ext-install uploadprogress; \
	rm -rf /usr/src/php/ext/uploadprogress;

# Install apcu
RUN set -eux; \
	pecl install apcu;

# Add php configs
RUN { \
		echo 'extension=apcu.so'; \
		echo "apc.enable_cli=1"; \
		echo "apc.enable=1"; \
	} >> /usr/local/etc/php/php.ini;

# Install iipsrv
RUN set -eux; \
	git clone https://github.com/ruven/iipsrv.git; \
	cd iipsrv; \
	./autogen.sh; \
	./configure; \
	make; \
	mkdir /fcgi-bin; \
	cp src/iipsrv.fcgi /fcgi-bin/iipsrv.fcgi

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini;

# set memory settings for WissKi
RUN { \
		echo 'max_execution_time = 1200'; \
		echo 'max_input_time = 600'; \
		echo 'max_input_nesting_level = 640'; \
		echo 'max_input_vars = 10000'; \
		echo 'memory_limit = 512M'; \
		echo 'upload_max_filesize = 512M'; \
		echo 'max_file_uploads = 50'; \
		echo 'post_max_size = 512M'; \
	} > /usr/local/etc/php/conf.d/wisski-settings.ini;

# Solr
ENV SOLR_VERSION 8.11.1
WORKDIR /opt/
RUN set -eux; \
	wget https://www.apache.org/dyn/closer.lua/lucene/solr/8.11.1/solr-${SOLR_VERSION}.tgz?action=download -O solr-${SOLR_VERSION}.tgz; \
	tar xzf solr-${SOLR_VERSION}.tgz solr-${SOLR_VERSION}/bin/install_solr_service.sh --strip-components=2; \
	./install_solr_service.sh solr-${SOLR_VERSION}.tgz; \
	rm -r solr-${SOLR_VERSION}.tgz install_solr_service.sh

# reset apt
#	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
#	rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

# https://www.drupal.org/node/3060/release
ENV DRUPAL_VERSION 9.3.6

# Installed Drupal modules, please check and update versions if necessary
# List Requirements
ENV REQUIREMENTS="drupal/colorbox \
	drupal/devel \
	drupal/facets \
	drupal/field_permissions \
	drupal/geofield \
	drupal/geofield_map \
	drupal/image_effects \
	drupal/imagemagick \
	drupal/imce \
	drupal/inline_entity_form:1.x-dev@dev \
	kint-php/kint \
	drupal/leaflet \
	drupal/search_api \
	drupal/search_api_solr \
	drupal/viewfield:3.x-dev@dev \
	drupal/wisski:3.x-dev@dev"

# Install Drupal, WissKI and dependencies
WORKDIR /opt/drupal
RUN set -eux; \
	export COMPOSER_HOME="$(mktemp -d)"; \
	composer create-project --no-interaction "drupal/recommended-project:$DRUPAL_VERSION" ./; \
	composer require ${REQUIREMENTS}; \
	composer require --dev drush/drush --with-all-dependencies; \
	cd web/modules/contrib/wisski && composer update && cd /opt/drupal
# Copy example site
COPY sites.tar.gz /opt/sites.tar.gz
RUN	rm -r /opt/drupal/web/sites; \
	tar xfz /opt/sites.tar.gz --directory web/
# Copy necessary themes
COPY themes.tar.gz /opt/themes.tar.gz 
RUN rm -r /opt/drupal/web/themes; \
	tar xfz /opt/themes.tar.gz --directory web/
# Adjust permissions and links 
RUN	chown -R www-data:www-data web/sites web/modules web/themes; \
	rm -r /var/www/html; \
	ln -sf /opt/drupal/web /var/www/html; \
	# delete composer cache
	rm -rf "$COMPOSER_HOME"

# install libraries
RUN set -eux; \
	mkdir -p web/libraries; \
	wget https://github.com/jackmoore/colorbox/archive/refs/heads/master.zip -P web/libraries/; \
	unzip web/libraries/master.zip -d web/libraries/; \
	rm -r web/libraries/master.zip;\
	mv web/libraries/colorbox-master web/libraries/colorbox

# Add IIPServer config
COPY iipsrv.conf /etc/apache2/mods-available/iipsrv.conf 

# IIPMooViewer
RUN wget https://github.com/ruven/iipmooviewer/archive/refs/heads/master.zip -P web/libraries/; \
	unzip web/libraries/master.zip -d web/libraries/; \
	rm -r web/libraries/master.zip;\
	mv web/libraries/iipmooviewer-master web/libraries/iipmooviewer

# Mirador
RUN	wget https://github.com/rnsrk/wisski-mirador-integration/archive/refs/heads/main.zip -P web/libraries/; \
	unzip web/libraries/main.zip -d web/libraries/; \
	mv web/libraries/wisski-mirador-integration-main web/libraries/wisski-mirador-integration

# Add private files directory
RUN mkdir /var/www/private_files && chown -R www-data /var/www/private_files

# Add path
ENV PATH=${PATH}:/opt/drupal/vendor/bin

# Install mariadb
RUN apt install mariadb-server -y

# Copy example Database
COPY wisski.sql /opt/wisski.sql

# Install Blazegraph
ENV BLAZEGRAPH_VERSION 2_1_6
RUN mkdir -p /opt/blazegraph
WORKDIR /opt/blazegraph
RUN set -eux; \
	wget https://github.com/blazegraph/database/releases/download/BLAZEGRAPH_${BLAZEGRAPH_VERSION}_RC/blazegraph.jar
COPY blazegraph /etc/init.d/
COPY blazegraph.tar.gz /opt/blazegraph/blazegraph.tar.gz
RUN update-rc.d blazegraph defaults

# Copy example data
RUN	tar xfz blazegraph.tar.gz --directory /usr/lib/jvm/java-11-openjdk-amd64/bin/

WORKDIR /opt/drupal

# Startscripts
COPY start.sh /
RUN chmod +x /start.sh
CMD ["/start.sh"]

# vim:set ft=dockerfile: