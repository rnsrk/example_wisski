#!/bin/bash

# Start services 
/etc/init.d/blazegraph start
/etc/init.d/solr start
/etc/init.d/mariadb start

# Import DB if necessary
if [[ -z "`mysql -qfsBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='wisski'" 2>&1`" ]]
then
	mysql -e "CREATE USER 'wisski'@'%' IDENTIFIED BY 'wisski';"
	mysql -e "CREATE DATABASE wisski;"
	mysql -e "GRANT ALL PRIVILEGES ON wisski.* TO 'wisski'@'%';"
	mysql -e "FLUSH PRIVILEGES;"
	mysql wisski < /opt/wisski.sql
fi

# Clear cache
/opt/drupal/vendor/drush/drush/drush cr

# log apache
/usr/sbin/apache2ctl -D FOREGROUND