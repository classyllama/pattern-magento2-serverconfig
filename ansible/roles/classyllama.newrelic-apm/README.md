# Ansible Role: NewRelic APM

Installs NewRelic yum repo and PHP APM package.

## Requirements

None.

## Role Variables

See `defaults/main.yml` for details.

## Dependencies

None.

## Example Playbook

    - hosts: web-server
      vars:
        newrelic_apm_key: xxxxxxxxxxxxxxxxxxxxx
      roles:
        # NewRelic APM support; appname set in nginx configs
        - { role: alpacaglue.newrelic-apm, tags: newrelic }

## License

This work is licensed under the MIT license. See LICENSE file for details.

## Author Information

This role was created in 2017 by [Matt Johnson](https://github.com/mttjohnson/) with contributions from [David Alger](https://davidalger.com/).