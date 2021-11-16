# Ansible Role: Timezone

Sets the system timezone via community.general.timezone and restarts crond

## Requirements

None

## Role Configuration

* Adjust the default variable to change the clock default timezone

        timezone_name: America/Chicago

* List possible timezone names the system knows about:

        timedatectl list-timezones

## Dependencies

* collection community.general.timezone
  https://galaxy.ansible.com/community/general

## Example Usage

    vars:
        timezone_name: America/Chicago
    roles:
        - { role: classyllama.timezone }

## License

This work is licensed under the MIT license. See LICENSE file for details.

## Author Information

This role was created in 2021 by [Matt Johnson](https://github.com/mttjohnson/).