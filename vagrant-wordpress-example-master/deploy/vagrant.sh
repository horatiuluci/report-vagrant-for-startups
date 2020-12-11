#! /bin/bash

domain_name='example.com';
site_title='example';
user_name='user';
password='password';

function print_footer()
{
    echo "###############################################################################";
} # print_footer

function print_heading()
{
    local title=$1;
    echo "########## $title ##########";
} # print_heading

print_heading "Defining System Variables";
APACHE_USER="www-data";
DOMAINS_HOME="/var/domains";
PROJECT_HOME="/vagrant";
VAGRANT_HOME="/home/vagrant";
INSTALL_HOME="$VAGRANT_HOME/install";
print_footer;

print_heading "Defining Domain Variables";

DOMAIN_NAME="example.site";
if [[ -n "$domain_name" ]]; then DOMAIN_NAME=${domain_name}; fi;

DOMAIN_TLD=`echo ${DOMAIN_NAME} | sed 's/\./_/g'`;

SITE_TITLE="Example Site";
if [[ -n "$site_title" ]]; then SITE_TITLE=${site_title}; fi;

print_footer;

print_heading "Defining Database Variables";
DB_NAME=${DOMAIN_TLD};
DB_USER="vagrant";
DB_PASS="V46R4NT";
print_footer;

print_heading "Defining WordPress Variables";
WP_PATH="$DOMAINS_HOME/$DOMAIN_TLD/wordpress";

WP_USER="webmaster";
if [[ -n "$user_name" ]]; then WP_USER=${user_name}; fi;

WP_PASS="vagrant";
if [[ -n "$password" ]]; then WP_USER=${password}; fi;

WP_EMAIL="$WP_USER@$DOMAIN_NAME";

print_footer;

print_heading "Entering Non-Interactive Mode";
export DEBIAN_FRONTEND=noninteractive;
print_footer;

print_heading "Set Up Directories";
if [[ ! -d ${DOMAINS_HOME} ]]; then mkdir ${DOMAINS_HOME}; fi;
if [[ ! -L /domains ]]; then ln -s ${DOMAINS_HOME} /domains; fi;
if [[ ! -d ${DOMAINS_HOME}/${DOMAIN_TLD} ]]; then mkdir ${DOMAINS_HOME}/${DOMAIN_TLD}; fi;
if [[ ! -d ${INSTALL_HOME} ]]; then mkdir ${INSTALL_HOME}; fi;
print_footer;

if [[ ! -f ${INSTALL_HOME}/os.lock ]]; then
    print_heading "Set Up Operating System";
    apt-get update -y;
    apt-get install -y vim;
    apt-get install -y curl;
    apt-get install -y lftp;
    apt-get install -y sqlite3;
    apt-get install -y traceroute;
    apt-get install -y tree;
    print_footer;
fi;
touch ${INSTALL_HOME}/os.lock;

if [[ ! -f ${INSTALL_HOME}/apache.lock ]]; then
    print_heading "Install Apache";
    apt-get install -yf apache2;
    a2enmod rewrite;
    print_footer;
fi;
touch ${INSTALL_HOME}/apache.lock;

if [[ ! -f ${INSTALL_HOME}/mysql.lock ]]; then
    print_heading "Install MySQL";
    apt-get install -yf mysql-server-5.5;
    apt-get install -yf mysql-server;
    apt-get install -yf libmysqlclient-dev;
    print_footer;
fi;
touch ${INSTALL_HOME}/mysql.lock;

if [[ ! -f ${INSTALL_HOME}/php.lock ]]; then
    print_heading "Install PHP";
    apt-get install -yf php;
    apt-get install -yf libapache2-mod-php;
    apt-get install -yf php-cli;
    apt-get install -yf php-gd;
    apt-get install -yf php-json;
    apt-get install -yf php-ldap;
    apt-get install -yf php-mysql;
    #apt-get install -y php-pgsql;
    apt-get install -yf php-curl;
    print_footer;
fi;
touch ${INSTALL_HOME}/php.lock;

print_heading "Clean Up Packages";
apt-get -y autoremove;
print_footer;

print_heading "Restart Services";
systemctl reload apache2;
systemctl reload mysql;
print_footer;

if [[ ! -f ${INSTALL_HOME}/db.lock ]]; then
    print_heading "Set Up the Database";
    set -xv;
    mysqladmin create ${DB_NAME};
    mysql --user=root --execute="GRANT ALL ON $DB_NAME.* to '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'" ${DB_NAME};
    mysql --user=root --execute="FLUSH PRIVILEGES" ${DB_NAME};
    set +xv;
    print_footer;
fi;
touch ${INSTALL_HOME}/db.lock;

if [[ ! -f /usr/local/bin/wp ]]; then
    print_heading "Install WordPress CLI";
    curl -sS -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar;
    php wp-cli.phar --allow-root --info;
    chmod +x wp-cli.phar;
    sudo mv wp-cli.phar /usr/local/bin/wp;
    print_footer;
fi;

if [[ ! -f /home/vagrant/wp-completion.bash ]]; then
    print_heading "Enable Bash Completion for WordPress CLI";
    wget --no-verbose --quiet https://github.com/wp-cli/wp-cli/raw/master/utils/wp-completion.bash;
    echo "source ~/wp-completion.bash;" >> .bashrc;
    print_footer;
fi;

#print_heading "Set Up Users";
#useradd -c "Replaces the default of wwww-data." -d $DOMAINS_HOME $APACHE_USER;

if [[ ! -d ${WP_PATH} ]]; then
    print_heading "Download WordPress";
    (cd `dirname ${WP_PATH}` && wget --no-verbose --quiet https://wordpress.org/latest.tar.gz);
    (cd `dirname ${WP_PATH}` && tar -xzf latest.tar.gz);
    (cd `dirname ${WP_PATH}` && rm latest.tar.gz);
    print_footer;
fi;

if [[ ! -d ${WP_PATH}/wp-config.php ]]; then
    print_heading "Generate WordPress Configuration";
    set -xv;
    wp core config \
        --allow-root \
        --path=${WP_PATH} \
        --dbname=${DB_NAME} \
        --dbuser=${DB_USER} \
        --dbpass=${DB_PASS};
    set +xv;
    print_footer;
fi;

result=`mysql --user=root --execute="SELECT * FROM wp_users WHERE id = 1;" ${DB_NAME}`;
if [[ -z "$result" ]]; then
    print_heading "Install WordPress";

    # The real domain name doesn't work in development and we also need the
    # port. See deploy/config.csv for the override.

    set -xv;
    wp core install \
        --allow-root \
        --path=${WP_PATH} \
        --url=http://${DOMAIN_NAME} \
        --title="$SITE_TITLE" \
        --admin_user=${WP_USER} \
        --admin_email=${WP_EMAIL} \
        --admin_password=${WP_PASS};
    set +xv;
    print_footer;
fi;

echo "Copy .htaccess file to document root.";
cp ${PROJECT_HOME}/deploy/htaccess ${WP_PATH}/.htaccess;

if [[ ! -d ${WP_PATH}/wp-content/themes/simple-bootstrap ]]; then
    print_heading "Install Simple Bootstrap Theme";
    wp theme install /vagrant/themes/simple-bootstrap.zip --allow-root --path=${WP_PATH};
    wp theme install simple-boostrap --allow-root --path=${WP_PATH};
fi;

print_heading "Remove Unwanted Plugins";
for plugin in akismet hello-dolly
do
    if [[ -d ${WP_PATH}/wp-content/plugins/${plugin} ]]; then
        wp plugin uninstall ${plugin} \
	   --allow-root \
	   --deactivate \
	   --path=${WP_PATH};
    fi;
done

print_heading "Install Plugins";
old_ifs=$IFS;
IFS="
";
plugins=`cat ${PROJECT_HOME}/deploy/plugins.csv`;
for line in ${plugins}
do

    first_character=`echo "$line" | cut -c 1`;
    if [[ ${first_character} == "#" ]]; then continue; fi;

    title=`echo "$line" | awk -F "," '{print $1}'`;
    installer=`echo "$line" | awk -F "," '{print $2}'`;
    name=`echo "$line" | awk -F "," '{print $3}'`;

    if [[ ! -d ${WP_PATH}/wp-content/plugins/${name} ]]; then
        echo ">>> $title <<<";
        set -xv;

        wp plugin install ${installer} \
           --allow-root \
           --path=${WP_PATH};

        wp plugin activate ${name} \
           --allow-root \
           --path=${WP_PATH};
            set +xv;
    fi;
done
print_footer;

print_heading "Set WP Options";
settings=`cat ${PROJECT_HOME}/deploy/config.csv`;
for line in ${settings}
do

    first_character=`echo "$line" | cut -c 1`;
    if [[ ${first_character} == "#" ]]; then continue; fi;

    name=`echo "$line" | awk -F "," '{print $1}'`;
    value=`echo "$line" | awk -F "," '{print $2}'`;

    echo ">>> $name <<<";
    set -xv;
    mysql --user=root --execute="UPDATE wp_options SET option_value = '$value' WHERE option_name = '$name';" ${DB_NAME};
    set +xv;

done
print_footer;

IFS=${old_ifs};

print_heading "Reset Permissions";
chown -R ${APACHE_USER} ${DOMAINS_HOME};
chgrp -R ${APACHE_USER} ${DOMAINS_HOME};

print_heading "Create Apache Configuration";
cat > /etc/apache2/sites-available/${DOMAIN_NAME}.conf << EOF
<VirtualHost *:80>
    #ServerName ${DOMAIN_NAME}
    #ServerAlias www.${DOMAIN_NAME}
    DocumentRoot ${WP_PATH}
    <Directory ${WP_PATH}>
        Order allow,deny
        Allow from all
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

print_heading "Enable WordPress Site";
a2ensite ${DOMAIN_NAME}.conf
a2dissite 000-default.conf
systemctl reload apache2

print_footer;
