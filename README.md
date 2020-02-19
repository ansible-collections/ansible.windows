# Ansible Collection: ansible.windows

[![Run Status](https://api.shippable.com/projects/5e4d952ef7b7100007bcf1a1/badge?branch=master)](https://app.shippable.com/github/ansible-collections/ansible.windows/dashboard/jobs)


This repo hosts the `ansible.windows` Ansible Collection.

The collection includes the core plugins supported by Ansible to help the management of Windows hosts.


## Installation and Usage

### Installaing the Collection from Ansible Galaxy

Before using the Windows collection, you need to install it with the `ansible-galaxy` CLI:

    ansible-galaxy collection install ansible.windows

You can also include it in a `requirements.yml` file and install it via `ansible-galaxy collection install -r requirements.yml` using the format:

```yaml
collections:
- name: ansible.windows
```


## Testing and Development

If you want to develop new content for this collection or improve what's already here, the easiest way to work on the collection is ot clone it into one of the configured [`COLLECTIONS_PATHS`](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#collections-paths), and work on it there.

### Testing with `ansible-test`

The `tests` directory contains configuration for running sanity and integration tests using [`ansible-test`](https://docs.ansible.com/ansible/latest/dev_guide/testing_integration.html).

You can run the collection's test suites with the commands:

    ansible-test sanity --docker
    ansible-test windows-integration --docker


## Publishing New Version

TBD

## More Information

TBD

## License


GNU General Public License v3.0 or later

See [LICENSE](LICENSE) to see the full text.
