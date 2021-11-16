# Ansible Role: SSHD Lockdown

Replaces SSHD config file with template on RHEL / CentOS 7.

This role replaces the sshd config using a template file and ansible variables. The defaults provide a locked down sshd config where password authentication is disabled for SSH users, and users must be a part of the `sshusers` group in order to be granted the ability to connect and authenticate over SSH. 

## TODO

Research https://www.ssh.com/ssh/sshd_config

## Requirements

None.

## Role Variables

See `defaults/main.yml` for details.

## Dependencies

None.

## Example Playbook

    - hosts: all
      vars:
        sshd_pass_auth_exception: true
        sshd_pass_auth_exception_user: rack
        
        sshd_access_users:
          - someotheruser
          - another_user
          - unprivileged_ssh_suer
      roles:
        - { role: classyllama.sshd-lockdown }

## License

This work is licensed under the MIT license. See LICENSE file for details.

## Author Information

This role was created in 2016 by [David Alger](https://davidalger.com/) with contributions from [Matt Johnson](https://github.com/mttjohnson/).