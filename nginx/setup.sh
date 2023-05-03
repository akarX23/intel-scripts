#!/bin/bash

UPDATE_NGINX=
UPDATE_CONF=
INSTALL_NGINX=
OVERWRITE=
CONF_PATH="./nginx.conf"
SITES_AVAILABLE_DIR="/etc/nginx/sites-available"
SITES_ENABLED_DIR="/etc/nginx/sites-enabled"
LOCAL_CONF_DIR="./conf.d"

while [ "$1" != "" ]; do
    case $1 in
        --update-nginx )
            UPDATE_NGINX=true
            ;;
        --update-conf ) 
            COPY_CONF=true
            ;;
        --install-nginx )
            INSTALL_NGINX=true
            ;;
        --overwrite )
            OVERWRITE=true
            ;;
        --sa-dir )
            SITES_AVAILABLE_DIR="$2"
            shift 1
            ;;
        --se-dir )
            SITES_ENABLED_DIR="$2"
            shift 1
            ;;
        --conf-path )
            CONF_PATH="$2"
            shift 1
            ;;
        --local-conf-dir )
            LOCAL_CONF_DIR="$2"
            shift 1
            ;;
         * )
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

if command -v nginx >/dev/null 2>&1; then
    echo "Nginx exists"
else
    echo "Nginx is not installed"
    if [[ "$INSTALL_NGINX" = true ]]; then
        sudo apt update -y
        sudo apt install nginx -y

        if command -v ufw >/dev/null 2>&1; then
            sudo ufw allow 'Nginx Full'
        fi
    fi
fi

if [[ "$UPDATE_NGINX" = true ]]; then
    sudo rm $(nginx -V 2>&1 | grep --color=auto -oE 'conf-path=\S+' | cut -c 11-)
    sudo cp $CONF_PATH $(nginx -V 2>&1 | grep --color=auto -oE 'conf-path=\S+' | cut -c 11-)
fi

if $UPDATE_CONF; then
    for file in "$LOCAL_CONF_DIR"/*
    do
        if $OVERWRITE; then
            cp -f "$file" "$SITES_AVAILABLE_DIR"
        elif [ ! -e "$SITES_AVAILABLE_DIR/$(basename $file)" ]; then
            cp "$file" "$SITES_AVAILABLE_DIR"
        fi

        sudo ln -s $SITES_AVAILABLE_DIR/$(basename $file) $SITES_ENABLED_DIR
    done
fi

sudo nginx -s reload

