# Ansible Collection: ansible.windows

[![Run Status](https://api.shippable.com/projects/5e4d952ef7b7100007bcf1a1/badge?branch=master)](https://app.shippable.com/github/ansible-collections/ansible.windows/dashboard/jobs)
[![codecov](https://codecov.io/gh/ansible-collections/ansible.windows/branch/master/graph/badge.svg)](https://codecov.io/gh/ansible-collections/ansible.windows)


The `ansible.windows` collection includes the core plugins supported by Ansible to help the management of Windows hosts.


## Included content

<!--start collection content-->
## Filter plugins
Name | Description
--- | ---
ansible.windows.quote|Quotes argument(s) for the various shells in Windows command processing.
## Modules
Name | Description
--- | ---
[ansible.windows.win_acl](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_acl.rst)|Set file/directory/registry permissions for a system user or group
[ansible.windows.win_acl_inheritance](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_acl_inheritance.rst)|Change ACL inheritance
[ansible.windows.win_certificate_store](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_certificate_store.rst)|Manages the certificate store
[ansible.windows.win_command](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_command.rst)|Executes a command on a remote Windows node
[ansible.windows.win_copy](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_copy.rst)|Copies files to remote locations on windows hosts
[ansible.windows.win_dns_client](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_dns_client.rst)|Configures DNS lookup on Windows hosts
[ansible.windows.win_domain](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_domain.rst)|Ensures the existence of a Windows domain
[ansible.windows.win_domain_controller](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_domain_controller.rst)|Manage domain controller/member server state for a Windows host
[ansible.windows.win_domain_membership](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_domain_membership.rst)|Manage domain/workgroup membership for a Windows host
[ansible.windows.win_dsc](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_dsc.rst)|Invokes a PowerShell DSC configuration
[ansible.windows.win_environment](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_environment.rst)|Modify environment variables on windows hosts
[ansible.windows.win_feature](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_feature.rst)|Installs and uninstalls Windows Features on Windows Server
[ansible.windows.win_file](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_file.rst)|Creates, touches or removes files or directories
[ansible.windows.win_find](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_find.rst)|Return a list of files based on specific criteria
[ansible.windows.win_get_url](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_get_url.rst)|Downloads file from HTTP, HTTPS, or FTP to node
[ansible.windows.win_group](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_group.rst)|Add and remove local groups
[ansible.windows.win_group_membership](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_group_membership.rst)|Manage Windows local group membership
[ansible.windows.win_hostname](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_hostname.rst)|Manages local Windows computer name
[ansible.windows.win_optional_feature](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_optional_feature.rst)|Manage optional Windows features
[ansible.windows.win_owner](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_owner.rst)|Set owner
[ansible.windows.win_package](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_package.rst)|Installs/uninstalls an installable package
[ansible.windows.win_path](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_path.rst)|Manage Windows path environment variables
[ansible.windows.win_ping](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_ping.rst)|A windows version of the classic ping module
[ansible.windows.win_reboot](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_reboot.rst)|Reboot a windows machine
[ansible.windows.win_reg_stat](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_reg_stat.rst)|Get information about Windows registry keys
[ansible.windows.win_regedit](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_regedit.rst)|Add, change, or remove registry keys and values
[ansible.windows.win_service](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_service.rst)|Manage and query Windows services
[ansible.windows.win_service_info](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_service_info.rst)|Gather information about Windows services
[ansible.windows.win_share](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_share.rst)|Manage Windows shares
[ansible.windows.win_shell](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_shell.rst)|Execute shell commands on target hosts
[ansible.windows.win_stat](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_stat.rst)|Get information about Windows files
[ansible.windows.win_tempfile](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_tempfile.rst)|Creates temporary files and directories
[ansible.windows.win_template](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_template.rst)|Template a file out to a remote server
[ansible.windows.win_updates](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_updates.rst)|Download and install Windows updates
[ansible.windows.win_uri](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_uri.rst)|Interacts with webservices
[ansible.windows.win_user](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_user.rst)|Manages local Windows user accounts
[ansible.windows.win_user_right](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_user_right.rst)|Manage Windows User Rights
[ansible.windows.win_wait_for](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_wait_for.rst)|Waits for a condition before continuing
[ansible.windows.win_whoami](https://github.com/ansible-collections/ansible.windows/blob/master/docs/ansible.windows.win_whoami.rst)|Get information about the current user and process
<!--end collection content-->


## Installation and Usage

### Installing the Collection from Ansible Galaxy

Before using the Windows collection, you need to install it with the `ansible-galaxy` CLI:

    ansible-galaxy collection install ansible.windows

You can also include it in a `requirements.yml` file and install it via `ansible-galaxy collection install -r requirements.yml` using the format:

```yaml
collections:
- name: ansible.windows
```

### Contributing to this collection

We welcome community contributions to this collection. If you find problems, please open an issue or create a PR against the [Ansible Windows collection repository](https://github.com/ansible-collections/ansible.windows). See [Contributing to Ansible-maintained collections](https://docs.ansible.com/ansible/devel/community/contributing_maintained_collections.html#contributing-maintained-collections) for details.

See [Developing modules for Windows](https://docs.ansible.com/ansible/latest/dev_guide/developing_modules_general_windows.html#developing-modules-general-windows) for specifics on Windows modules.

You can also join us on:

- Freenode IRC - ``#ansible-windows`` Freenode channel


See the [Ansible Community Guide](https://docs.ansible.com/ansible/latest/community/index.html) for details on contributing to Ansible.

### Code of Conduct
This collection follows the Ansible project's
[Code of Conduct](https://docs.ansible.com/ansible/devel/community/code_of_conduct.html).
Please read and familiarize yourself with this document.

### Generating plugin docs

Currently module documentation is generated manually using
[add_docs.py](https://github.com/ansible-network/collection_prep/blob/master/add_docs.py). This should be run whenever
there are any major doc changes or additional plugins have been added to ensure a docpage is viewable online in this
repo. The following commands will run the doc generator and create the updated doc pages under [docs](docs).

```bash
# This is the path to the ansible.windows checkout
COLLECTION_PATH=~/ansible_collections/ansible/windows

cd /tmp
git clone https://github.com/ansible-network/collection_prep.git
cd collection_prep
python add_docs.py -p "${COLLECTION_PATH}"
```


### Testing with `ansible-test`

The `tests` directory contains configuration for running sanity and integration tests using [`ansible-test`](https://docs.ansible.com/ansible/latest/dev_guide/testing_integration.html).

You can run the collection's test suites with the commands:

    ansible-test sanity --docker
    ansible-test windows-integration --docker


## Publishing New Version

The current process for publishing new versions of the Windows Core Collection is manual, and requires a user who has access to the `ansible` namespace on Ansible Galaxy and Automation Hub to publish the build artifact.

  1. Update the CHANGELOG:
    1. Make sure you have [`antsibull-changelog`](https://pypi.org/project/antsibull-changelog/) installed.  
    2. Make sure there are fragments for all known changes in `changelogs/fragments`.  
    3. Run `antsibull-changelog release`.    
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

- [Ansible Collection overview](https://github.com/ansible-collections/overview)
- [Ansible User guide](https://docs.ansible.com/ansible/latest/user_guide/index.html)
- [Ansible Developer guide](https://docs.ansible.com/ansible/latest/dev_guide/index.html)
- [Ansible Community code of conduct](https://docs.ansible.com/ansible/latest/community/code_of_conduct.html)


## License

GNU General Public License v3.0 or later

See [COPYING](COPYING) to see the full text.
