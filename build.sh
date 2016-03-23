#!/bin/bash

#COULEURS
RED='\e[0;31m'
GREEN='\e[0;32m'
NC='\e[0m'
ARROW="${GREEN}==>${NC}"

#VÉRIFICATION ET STOCKAGE DES ARGUMENTS
if [[ $EUID -eq 0 ]]; then
   printf "Ce script ne doit pas être lancé en tant que root.\n"
   exit 1
fi

if [[ $# -eq 0 ]]; then
	printf "Usage : build nomDuSite [nomAdmin] [emailAdmin]\n"
	exit 1
elif [[ ${#1} -gt 12 ]]; then
	printf "Le nom du site doit faire moins de 12 caractères.\n"
	exit 1
else
	SITE_NAME=${1}
	USR_NAME=${2}
	USR_MAIL=${3}
fi

#ENVIRONMENT
UNIX_USER="cua"
HTTPD_GROUP="www-data"
DEV_DIR=/home/cua/public_html
SITE_URL="http://dev/${SITE_NAME}"
TARGET_DIR="${DEV_DIR}/${SITE_NAME}"
MAKEFILES="/home/cua/makefiles"
WP_HTACCESS="${MAKEFILES}/htaccess-wp"

#EXÉCUTABLES
WP="/usr/local/bin/wp"
DRUSH="/usr/bin/drush"

#SGBD
DBUSER="build-user"
DBPWD="xxxxxxxxxxxxxx"
DATABASE="`echo ${SITE_NAME} | sed 's/\.//g'`_dev"
BDD_USER="${DATABASE}"
BDD_PASSWORD=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10`

printf "\n${ARROW} Bienvenue dans le script de déploiement !\n"

printf "\nVous allez installer un CMS à l'emplacement suivant : ${TARGET_DIR}\n"

if [[ -z "${USR_NAME}" ]]; then
	echo -e "\nEntrez le nom de l'administrateur du site à déployer :"
	read USR_NAME
fi
if [[ -z "${USR_MAIL}" ]]; then
	echo -e "\nEntrez l'adresse email de l'administrateur :"
	read USR_MAIL
fi

USR_PASSWORD=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10`

printf "\nQuel CMS voulez-vous installer ?\n"
select dw in "Drupal" "Wordpress" "Anuuler"; do
	case $dw in
		Drupal ) CMS="Drupal"; break;;
		Wordpress ) CMS="Wordpress"; break;;
		Anuuler ) exit;;
	esac
done

if [ "${CMS}" = "Drupal" ]; then

	printf "\nSélectionnez le profil qui sera utilisé par le script de déploiement :\n"
	select profile in "Normal" "Commerce Base" "Commerce KickStart" "Multilingue" "Annuler"; do
		case $profile in
			"Normal" ) MAKEFILE="${MAKEFILES}/d7Base.makefile"; PROFILE="standard"; break;;
			"Commerce Base" ) MAKEFILE="${MAKEFILES}/d7Commerce.makefile"; PROFILE="standard"; break;;
			"Commerce KickStart" ) MAKEFILE="${MAKEFILES}/d7Kickstart.makefile"; PROFILE="commerce_kickstart"; break;;
			"Multilingue" ) MAKEFILE="${MAKEFILES}/d7Multilingual.makefile"; PROFILE="standard"; break;;
			"Annuler" ) echo "Annulation..."; exit;;
		esac
	done
	printf "\n${ARROW} Téléchargement de Drupal 7 et des modules...\n"
	#${DRUSH} make --concurrency=8 --prepare-install --translations=fr "${MAKEFILE}" "${TARGET_DIR}" #translations=fr peut casser
	${DRUSH} make --concurrency=1 --prepare-install --translations=fr "${MAKEFILE}" "${TARGET_DIR}"

elif [ "${CMS}" = "Wordpress" ]; then

	printf "\n${ARROW} Téléchargement de Wordpress et des modules...\n"
	${WP} core download --path="${TARGET_DIR}" --locale="fr_FR"

else

	printf "\nErreur fatale\n"
	exit 1

fi

printf "\n${ARROW} Création et configuration de la base de données...\n"

Q1="CREATE DATABASE IF NOT EXISTS ${DATABASE};"
Q2="GRANT ALL ON ${DATABASE}.* TO '${BDD_USER}'@'localhost' IDENTIFIED BY '${BDD_PASSWORD}';"
Q3="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}"

mysql -u${DBUSER} -p${DBPWD} -e "${SQL}" || exit;

printf "\n${ARROW} Peuplement de la base de données, configuration du CMS et installation des modules...\n"

if [ "${CMS}" = "Drupal" ]; then

	${DRUSH} site-install ${PROFILE} --locale=fr --account-mail="${USR_MAIL}" --account-name="${USR_NAME}" --account-pass="${USR_PASSWORD}" --site-name="${SITE_NAME}" --site-mail="tech@commeunarbre.fr" --db-url=mysql://${BDD_USER}:${BDD_PASSWORD}@localhost/${DATABASE} --db-prefix="cua_" -r "${TARGET_DIR}" || exit 1
	MODULES=`grep --color=never "projects" "${MAKEFILE}" "${BASE_MAKEFILE}" | grep -v "theme" | cut -d [ -f 2 | cut -d ] -f 1 | grep -Ev "(^drupal$|memcache|varnish|commerce_kickstart)" | sed ':a;N;$!ba;s/\n/ /g'`
	${DRUSH} pm-disable toolbar dashboard color shortcut -r "${TARGET_DIR}" -y
	${DRUSH} pm-enable ${MODULES} admin_menu_toolbar -r "${TARGET_DIR}" -y

elif [ "${CMS}" = "Wordpress" ]; then

    ${WP} core config --path="${TARGET_DIR}" --dbname="${DATABASE}" --dbuser="${BDD_USER}" --dbpass="${BDD_PASSWORD}" --dbprefix="cua_" || exit 1
    ${WP} core install --path="${TARGET_DIR}" --url="${SITE_URL}" --title="${SITE_NAME}" --admin_user="${USR_NAME}" --admin_password="${USR_PASSWORD}" --admin_email="${USR_MAIL}"
    ${WP} plugin install --path="${TARGET_DIR}" google-analytics-dashboard-for-wp wp-sitemap-page ninja-forms w3-total-cache wp-smushit wp-jquery-plus --activate
    ${WP} theme install --path="${TARGET_DIR}" https://github.com/Bertrand31/WP_Kickstart/archive/master.zip --activate

else
	printf "\nErreur fatale\n"
	exit 1
fi

printf "\n${ARROW} Sécurisation de l'installation\n"

if [ "${CMS}" = "Drupal" ]; then

    printf "Changement des propriétaires du dossier "${TARGET_DIR}":\n user => "${UNIX_USER}" \t group => "${HTTPD_GROUP}"\n"
    chown -R ${UNIX_USER}:${HTTPD_GROUP} ${TARGET_DIR}

    printf "Changement des permissions des répertoires à l'intérieur de "${TARGET_DIR}" en "rwxr-x---"...\n"
    find ${TARGET_DIR} -type d -exec chmod 750 '{}' \;

    printf "Changement des permissions des fichiers à l'intérieur de "${TARGET_DIR}" en "rw-r-----"...\n"
    find ${TARGET_DIR} -type f -exec chmod 640 '{}' \;

    printf "Changement des permissions des répertoires "files" dans "${TARGET_DIR}/sites" en "rwxrwx---"...\n"
    find ${TARGET_DIR}/sites -type d -name files -exec chmod 770 '{}' \;

    printf "Changement des permissions des fichiers dans les répertoires "files" de "${TARGET_DIR}/sites" en "rw-rw----"...\n"
    printf "Changement des permissions des répertoires dans les répértoires "files" de "${TARGET_DIR}/sites" en "rwxrwx---"...\n"
    for x in ${TARGET_DIR}/sites/*/files; do
        find ${x} -type d -exec chmod 770 '{}' \;
        find ${x} -type f -exec chmod 660 '{}' \;
    done

elif [ "${CMS}" = "Wordpress" ]; then

    printf "Sécurisation du .htaccess\n"
    cat ${WP_HTACCESS}>>${TARGET_DIR}/.htaccess

    printf "Sécurisation du wp-config.php\n"
    echo -e "\ndefine('DISALLOW_FILE_EDIT', true);">>${TARGET_DIR}/wp-config.php
    chmod 440 ${TARGET_DIR}/wp-config.php

    printf "Sécurisation de wp-content/\n"
    find ${TARGET_DIR}/wp-content/ -type f -exec chmod 660 {} \;
    find ${TARGET_DIR}/wp-content/ -type d -exec chmod 770 {} \;
    chown -R ${UNIX_USER}:${HTTPD_GROUP} ${TARGET_DIR}/wp-content/
    chown -R ${UNIX_USER} ${TARGET_DIR}/wp-content/themes/

else

	printf "\nErreur fatale"
	exit 1

fi

printf "\n${ARROW} Bilan de l'installation\n"
printf "\nAccès :\nChemin : ${TARGET_DIR}\nURL : ${SITE_URL}\n"
printf "\nBase de données :\nNom : ${DATABASE}\nUtilisateur : ${BDD_USER}\nMot de passe : ${BDD_PASSWORD}\n"
printf "\nIdentifiants de l'arrière-boutique :\nNom : ${USR_NAME}\nMot de passe : ${USR_PASSWORD}\nCourriel : ${USR_MAIL}\n"
