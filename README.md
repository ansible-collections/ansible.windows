# Ansible Collection: ansible.windows

[![Run Status](https://api.shippable.com/projects/5e4d952ef7b7100007bcf1a1/badge?branch=master)](https://app.shippable.com/github/ansible-collections/ansible.windows/dashboard/jobs)
[![codecov](https://codecov.io/gh/ansible-collections/ansible.windows/branch/master/graph/badge.svg)](https://codecov.io/gh/ansible-collections/ansible.windows)


This repo hosts the `ansible.windows` Ansible Collection.

The collection includes the core plugins supported by Ansible to help the management of Windows hosts.


## Installation and Usage

### Installing the Collection from Ansible Galaxy

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

The current process for publishing new versions of the Windows Core Collection is manual, and requires a user who has access to the `ansible` namespace on Ansible Galaxy and Automation Hub to publish the build artifact.

  1. Ensure `CHANGELOG.md` contains all the latest changes.
  2. Update `galaxy.yml` with the new `version` for the collection.
  3. Create a release in GitHub to tag the commit at the version to build.
  4. Run the following commands to build and release the new version on Galaxy:

     ```
     ansible-galaxy collection build
     ansible-galaxy collection publish ./ansible-windows-$VERSION_HERE.tar.gz
     ```

After the version is published, verify it exists on the [Windows Core Collection Galaxy page](https://galaxy.ansible.com/ansible/windows).


## More Information

For more information about Ansible's Windows integration, join the `#ansible-windows` channel on Freenode IRC, and browse the resources in the [Windows Working Group](https://github.com/ansible/community/wiki/Windows) Community wiki page.


## License

GNU General Public License v3.0 or later

See [COPYING](COPYING) to see the full text.
