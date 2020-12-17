.. _ansible.windows.win_template_module:


****************************
ansible.windows.win_template
****************************

**Template a file out to a remote server**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Templates are processed by the `Jinja2 templating language <http://jinja.pocoo.org/docs/>`_.
- Documentation on the template formatting can be found in the `Template Designer Documentation <http://jinja.pocoo.org/docs/templates/>`_.
- Additional variables listed below can be used in templates.
- ``ansible_managed`` (configurable via the ``defaults`` section of ``ansible.cfg``) contains a string which can be used to describe the template name, host, modification time of the template file and the owner uid.
- ``template_host`` contains the node name of the template's machine.
- ``template_uid`` is the numeric user id of the owner.
- ``template_path`` is the path of the template.
- ``template_fullpath`` is the absolute path of the template.
- ``template_destpath`` is the path of the template on the remote system (added in 2.8).
- ``template_run_date`` is the date that the template was rendered.




Parameters
----------

.. raw:: html

    <table  border=0 cellpadding=0 class="documentation-table">
        <tr>
            <th colspan="1">Parameter</th>
            <th>Choices/<font color="blue">Defaults</font></th>
            <th width="100%">Comments</th>
        </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>backup</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li><div style="color: blue"><b>no</b>&nbsp;&larr;</div></li>
                                    <li>yes</li>
                        </ul>
                </td>
                <td>
                        <div>Determine whether a backup should be created.</div>
                        <div>When set to <code>yes</code>, create a backup file including the timestamp information so you can get the original file back if you somehow clobbered it incorrectly.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>block_end_string</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"%}"</div>
                </td>
                <td>
                        <div>The string marking the end of a block.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>block_start_string</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"{%"</div>
                </td>
                <td>
                        <div>The string marking the beginning of a block.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>dest</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Location to render the template to on the remote machine.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>force</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>no</li>
                                    <li><div style="color: blue"><b>yes</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div>Determine when the file is being transferred if the destination already exists.</div>
                        <div>When set to <code>yes</code>, replace the remote file when contents are different than the source.</div>
                        <div>When set to <code>no</code>, the file will only be transferred if the destination does not exist.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>lstrip_blocks</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li><div style="color: blue"><b>no</b>&nbsp;&larr;</div></li>
                                    <li>yes</li>
                        </ul>
                </td>
                <td>
                        <div>Determine when leading spaces and tabs should be stripped.</div>
                        <div>When set to <code>yes</code> leading spaces and tabs are stripped from the start of a line to a block.</div>
                        <div>This functionality requires Jinja 2.7 or newer.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>newline_sequence</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>\n</li>
                                    <li>\r</li>
                                    <li><div style="color: blue"><b>\r\n</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div>Specify the newline sequence to use for templating files.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>output_encoding</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"utf-8"</div>
                </td>
                <td>
                        <div>Overrides the encoding used to write the template file defined by <code>dest</code>.</div>
                        <div>It defaults to <code>utf-8</code>, but any encoding supported by python can be used.</div>
                        <div>The source template file must always be encoded using <code>utf-8</code>, for homogeneity.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>src</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Path of a Jinja2 formatted template on the Ansible controller.</div>
                        <div>This can be a relative or an absolute path.</div>
                        <div>The file must be encoded with <code>utf-8</code> but <em>output_encoding</em> can be used to control the encoding of the output template.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>trim_blocks</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>no</li>
                                    <li><div style="color: blue"><b>yes</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div>Determine when newlines should be removed from blocks.</div>
                        <div>When set to <code>yes</code> the first newline after a block is removed (block, not variable tag!).</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>variable_end_string</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"}}"</div>
                </td>
                <td>
                        <div>The string marking the end of a print statement.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>variable_start_string</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"{{"</div>
                </td>
                <td>
                        <div>The string marking the beginning of a print statement.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - Including a string that uses a date in the template will result in the template being marked 'changed' each time.
   - Also, you can override jinja2 settings by adding a special header to template file. i.e. ``#jinja2:variable_start_string:'[%', variable_end_string:'%]', trim_blocks: False`` which changes the variable interpolation markers to ``[% var %]`` instead of ``{{ var }}``. This is the best way to prevent evaluation of things that look like, but should not be Jinja2.

   - Using raw/endraw in Jinja2 will not work as you expect because templates in Ansible are recursively evaluated.
   - To find Byte Order Marks in files, use ``Format-Hex <file> -Count 16`` on Windows, and use ``od -a -t x1 -N 16 <file>`` on Linux.
   - Beware fetching files from windows machines when creating templates because certain tools, such as Powershell ISE, and regedit's export facility add a Byte Order Mark as the first character of the file, which can cause tracebacks.
   - You can use the :ref:`ansible.windows.win_copy <ansible.windows.win_copy_module>` module with the ``content:`` option if you prefer the template inline, as part of the playbook.
   - For Linux you can use :ref:`ansible.builtin.template <ansible.builtin.template_module>` which uses '\\n' as ``newline_sequence`` by default.


See Also
--------

.. seealso::

   :ref:`ansible.windows.win_copy_module`
      The official documentation on the **ansible.windows.win_copy** module.
   :ref:`ansible.builtin.copy_module`
      The official documentation on the **ansible.builtin.copy** module.
   :ref:`ansible.builtin.template_module`
      The official documentation on the **ansible.builtin.template** module.


Examples
--------

.. code-block:: yaml

    - name: Create a file from a Jinja2 template
      ansible.windows.win_template:
        src: /mytemplates/file.conf.j2
        dest: C:\Temp\file.conf

    - name: Create a Unix-style file from a Jinja2 template
      ansible.windows.win_template:
        src: unix/config.conf.j2
        dest: C:\share\unix\config.conf
        newline_sequence: '\n'
        backup: yes



Return Values
-------------
Common return values are documented `here <https://docs.ansible.com/ansible/latest/reference_appendices/common_return_values.html#common-return-values>`_, the following are the fields unique to this module:

.. raw:: html

    <table border=0 cellpadding=0 class="documentation-table">
        <tr>
            <th colspan="1">Key</th>
            <th>Returned</th>
            <th width="100%">Description</th>
        </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>backup_file</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>if backup=yes</td>
                <td>
                            <div>Name of the backup file that was created.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">C:\Path\To\File.txt.11540.20150212-220915.bak</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Jon Hawkesworth (@jhawkesworth)
