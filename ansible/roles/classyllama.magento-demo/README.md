# Ansible Role: Magento Demo

Installs a shell script on RHEL / CentOS for installing Magento with demo data.

The role sets up a config file for a specific domain/directory/user and saves the config files and scripts in the user's home directory ~/username/magento-demo/.

## Requirements

None.

## Role Variables

See `defaults/main.yml` for details.

## Dependencies

None.

## Example Playbook

    - hosts: all
      vars:
        magento_demo_config_overrides:
        magento_demo_hostname: example.lan
        magento_demo_env_root: /var/www/data
        magento_demo_magento_root: /var/www/data/magento
        magento_demo_user: www-data
        magento_demo_group: www-data

        magento_demo_config_overrides:
          SHOULD_USE_CUSTOM_ADMIN_DOMAIN: "true"
          SITE_ADMIN_DOMAIN: "admin-{{ magento_demo_hostname }}"
          MAGENTO_COMPOSER_PROJECT: magento/project-community-edition
          SHOULD_SETUP_SAMPLE_DATA: "true"
          SHOULD_SETUP_TFA: "true"
          MAGENTO_REL_VER: 2.4.3-p1
          REDIS_OBJ_HOST: "localhost"
          REDIS_OBJ_PORT: "6379"
          REDIS_OBJ_DB: "0"
          REDIS_SES_HOST: "localhost"
          REDIS_SES_PORT: "6379"
          REDIS_SES_DB: "1"
          REDIS_FPC_HOST: "localhost"
          REDIS_FPC_PORT: "6379"
          REDIS_FPC_DB: "2"
          VARNISH_HOST: "localhost"
          VARNISH_PORT: "6081"
          SEARCH_ENGINE: "elasticsearch7"
          ELASTIC_HOST: "localhost"
          ELASTIC_PORT: "9200"
          ELASTIC_ENABLE_AUTH: "1"
          ELASTIC_USERNAME: "elastic"
          ELASTIC_PASSWORD: "changeme"
      roles:
        - { role: classyllama.magento-demo }

  For optional PWA installation it is possible to include [Venia Sample Data](https://magento.github.io/pwa-studio/venia-pwa-concept/install-sample-data/) installation using the following variables:

    - hosts: all
      vars:
        magento_demo_config_overrides:
        magento_demo_hostname: example.lan
        magento_demo_env_root: /var/www/data
        magento_demo_magento_root: /var/www/data/magento
        magento_demo_user: www-data
        magento_demo_group: www-data

        magento_demo_config_overrides:
          MAGENTO_COMPOSER_PROJECT: magento/project-community-edition
          SHOULD_SETUP_TFA: "true"
          ...
          SHOULD_SETUP_SAMPLE_DATA: "false"
          SHOULD_SETUP_VENIA_SAMPLE_DATA: "true"
          VENIA_SAMPLE_DATA_VERSION: "12.1.0"
          REDIS_SES_MAX_CONCURRENCY: "30"
          REDIS_SES_BREAK_AFTER_FRONT: "15"
          REDIS_SES_BREAK_AFTER_ADMIN: "30"
          REDIS_SES_DISABLE_LOCKING: "1"
          ...
      roles:
        - { role: classyllama.magento-demo }

  Please note, Magento Sample data should be disabled during Venia Sample data installation.


## Script Usage

    # Once the scripts are on the server
    ~/magento-demo/install-magento.sh config_site.json
    ~/magento-demo/uninstall-magento.sh config_site.json

## TFA OTP Secret

For dealing with Magento 2.4 Two Factor Auth (TFA) the demo install can generate a TFA secret and saves it with the other credentials in a `magento_admin_credentials.json` file, to make it simpler to validate an environment is working with the specific version of Magento installed. 

    cd /var/www/data/

Generate OTP code from CLI using TFA Secret from json file

    oathtool --time-step-size=30 --window=0 --totp=sha1 --base32 "$(cat magento_admin_credentials.json | jq -r .admin_tfa_secret)"

Use the script `magento_tfa_otp_code.sh` created during the install to easily run the command that generates the OTP code

    cat magento_admin_credentials.json
    ./magento_tfa_otp_code.sh

## Additional TFA Details

Storing TFA secrets in a file like `magento_admin_credentials.json` is a VEYR BAD idea, and is only used here for quick throwaway temporary demo environments. For an environment that isn't temporary you should re-generate the TFA secret for the user and store the secret in an app designed to encrypt and protect it. If the TFA secret is compromized or exposed, anyone can use it to generate the TFA 6 digit codes making the Two Factor Auth useless.

To manually initialize TFA from the command line and utilize a QR code and TFA app

    MAGENTO_DOMAIN="example.lan"
    INSTALL_PATH=$(cat magento_admin_credentials.json | jq -r .install_path)           # or replace this with a static string "/var/www/data/magento"
    BASE_URL=$(cat magento_admin_credentials.json | jq -r .base_url)                   # or replace this with a static string "https://example.lan"
    ADMIN_USER=$(cat magento_admin_credentials.json | jq -r .admin_user)               # or replace this with a static string "admin_wi8ao5"
    TFA_SECRET=""

    # Generate random secret for OTP use
    SECRET=$(pwgen -1 -s -n 32)
    # Detect Python version available - base32 encode and strip padding
    if command -v python3 >/dev/null 2>&1; then
      TFA_SECRET=$(python3 -c "import base64; print(base64.b32encode(bytearray('${SECRET}', 'ascii')).decode('utf-8'))" | sed 's/=*$//')
    else
      TFA_SECRET=$(python -c "import base64; print base64.b32encode('${SECRET}')" | sed 's/=*$//')
    fi
    # Build otpauth URI
    OTPAUTH_URL="otpauth://totp/${MAGENTO_DOMAIN}:${ADMIN_USER}?secret=${TFA_SECRET}&issuer=${MAGENTO_DOMAIN}&algorithm=SHA1&digits=6&period=30"
  
    # Set Google TFA as the forced provider
    bin/magento config:set --lock-env twofactorauth/general/force_providers google

    # Set the TFA secret for admin user
    bin/magento security:tfa:google:set-secret "${ADMIN_USER}" "${TFA_SECRET}"

    # Generate OTP code from CLI using TFA Secret from json file
    oathtool --time-step-size=30 --window=0 --totp=sha1 --base32 "${TFA_SECRET}"

If you want to build a QR code image to setup an app you can build an image from the TFA details and then remove the image afterwards

    # Generating a QR code image that can be used with Google Authenticator, Authy, 1Password, etc...
    segno "${OTPAUTH_URL}" -s 4 -o "${INSTALL_PATH}/pub/media/${ADMIN_USER}-totp-qr.png"
    printf "%s\n\n" "${BASE_URL}/media/${ADMIN_USER}-totp-qr.png?t=$(date +%s)"

    # Deleted generated sensetive OTP QR Code image after use
    rm ${INSTALL_PATH}/pub/media/${ADMIN_USER}-totp-qr.png

## License

This work is licensed under the MIT license. See LICENSE file for details.

## Author Information

This role was created in 2020 by [Matt Johnson](https://github.com/mttjohnson/).
