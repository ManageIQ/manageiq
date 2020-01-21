# miqssh miqscp miqcollect miqgrep and miqtail utilities

These tools allow for running commands and copying files and searching log files against multiple ManageIQ workers in an environment based on groups defined in hosts files.

Also, even if you do have pssh or other tools for running commands on multiple systems, the new miqgrep, miqgrep -r, miqtail, and miqtail -r are worth a look.

Different transport mechanisms are now supported and can be selected by updating the .config file.  By default, Ansible is used since it can work in parallel and is included by default with ManageIQ.  Alternatively, if installed and selected, Parallel SSH can be used and is faster opening connections than Ansible.

**Note that this program can enable you to do things faster, including mistakes, use at your own risk.**

# Command Descriptions:

miqssh (connect to each host in group and run provided commands)

miqscp (copy file TO each host in group)

miqcollect (copy file FROM each host in group)

miqgrep (connect to each host in group and grep log_file for pattern or request_id and associated task_ids and collate all results and display using less)

miqtail (Use multitail to tail log_file and optionally grep for pattern or request_id and associated task_ids)

miqstatus (run rake evm:status on each host in group)

miqworkermemcheck (search for memory exceeded messages in automation.log)

# Installation:

See INSTALL.txt in this directory.

# Usages:
