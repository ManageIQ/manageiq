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
## miqssh
```

DESCRIPTION: ssh and run command with args

USAGE: miqssh [-g group] [-s] command args

DETAILS:

  -s to run serially

AVAILABLE GROUPS (default is all):

  all
  all_no_db
  db
  ui
  workers
  zone1
  zone2

To see matching hosts for a given group, use:

miqssh [-q] -g <group> list
  -q to suppress header

```
## miqscp
```

DESCRIPTION: push files out using scp

USAGE: miqscp [-g group] [-s] local_file remote_dest_dir

DETAILS:
 
  Only one file is supported at a time

  -s to run serially

AVAILABLE GROUPS (default is all):

  all
  all_no_db
  db
  ui
  workers
  zone1
  zone2

To see matching hosts for a given group, use:

miqscp [-q] -g <group> list
  -q to suppress header

```
## miqcollect
```

DESCRIPTION: pull files in using scp

USAGE: miqcollect [-g group] [-s] remote_file local_dest_dir

DETAILS:
 
  Wildcards are accepted for remote_file but should only match one file
 
  local_files are appended with remote hostname

  -s to run serially

AVAILABLE GROUPS (default is all):

  all
  all_no_db
  db
  ui
  workers
  zone1
  zone2

To see matching hosts for a given group, use:

miqcollect [-q] -g <group> list
  -q to suppress header

```
## miqgrep
```

DESCRIPTION: grep log_file for pattern or request_id and associated task_ids and collate all results and display using less

USAGE: miqgrep [-g group] [-s] [-a] [-i] [-o outputfile] [-Q] (pattern | -r request_id) [log_file]

DETAILS:

  -i is optional to ignore case with grep

  pattern may be specified as a regex suitable for egrep taking care to prevent the shell from interpretation
  pattern may be specified as 'nogrep' to have no grep or use cat instead of grep
  -r request_id maybe used to search for a request_id and associated task_ids
    request_id can be provided with or without commas

  -o outputfile can be used to save output to outputfile
  -Q can be used to not less the output file automatically

  log_file is optional and defaults to automation.log
    For ManageIQ logs, log_file can be in the format of evm or evm.log
    For any other files, use /the/full/path/to/file

  -a can be used to also grep archived logs

  -s to run serially

AVAILABLE GROUPS (default is all):

  all
  all_no_db
  db
  ui
  workers
  zone1
  zone2

To see matching hosts for a given group, use:

miqgrep [-q] -g <group> list
  -q to suppress header

```
## miqtail
```

DESCRIPTION: multitail and grep pattern or request_id and associated task_ids

USAGE: miqtail [-g group] [-s] [-i] [-l] (pattern | -r request_id) [log_file]

DETAILS:

  -i is optional to ignore case with grep

  pattern may be specified as a regex suitable for egrep taking care to prevent the shell from interpretation
  pattern may be specified as 'nogrep' to have no grep or use cat instead of grep
  -r request_id maybe used to search for a request_id and associated task_ids
    request_id can be provided with or without commas

  log_file is optional and defaults to automation.log
    For ManageIQ logs, log_file can be in the format of evm or evm.log
    For any other files, use /the/full/path/to/file

  -l can be used to place output in separate window panes, by default output is merged

  In multitail:
    Move around the buffer similar to less by pressing 'b'
    Exit whatever context you are in by pressing 'q'

  -s to run serially

AVAILABLE GROUPS (default is all):

  all
  all_no_db
  db
  ui
  workers
  zone1
  zone2

To see matching hosts for a given group, use:

miqtail [-q] -g <group> list
  -q to suppress header

```


# Examples:
## miqssh
```
$ miqssh uptime

*** miq01 ***
 16:19:34 up  5:43,  0 users,  load average: 3.10, 3.06, 3.09

*** miq02 ***
 16:19:47 up  1:15,  0 users,  load average: 0.16, 0.07, 0.01

*** miq03 ***
 16:19:53 up  1:15,  0 users,  load average: 0.07, 0.15, 0.14
```
## miqscp
```
$ miqscp README.md /tmp/

*** miq01 ***
README.md                                               100% 1020     1.0KB/s   00:00    

*** miq02 ***
README.md                                               100% 1020     1.0KB/s   00:00    
```
## miqcollect
```
$ miqcollect /etc/hostname /tmp/

*** miq1 ***
hostname                                                100%   22    39.2KB/s   00:00    

*** miq2 ***
hostname                                                100%    6     9.0KB/s   00:00    

*** miq3 ***
hostname                                                100%    6     9.5KB/s   00:00    

$ ls /tmp/*hostname*
/tmp/hostname-miq1  /tmp/hostname-miq2  /tmp/hostname-miq3
```
## miqgrep pattern
```
$ miqgrep "MiqEventHandler#log_status" evm

*** miq1 ***

*** miq2 ***

*** miq3 ***

*** collating results ***

[miq1] [----] I, [2017-08-11T19:06:20.698103 #2949:b81140]  INFO -- : Q-task_id([log_status]) MIQ(MiqEventHandler#log_status) [Event Handler] Worker ID [1000000001071], PID [2922], GUID [c0f9c28a-7ed6-11e7-8b18-525400431635], Last Heartbeat [2017-08-11 23:06:19 UTC], Process Info: Memory Usage [310091776], Memory Size [652206080], Proportional Set Size: [203949000], Memory % [3.01], CPU Time [735.0], CPU % [0.09], Priority [27]
[miq2] [----] I, [2017-08-11T19:06:25.187956 #2765:623130]  INFO -- : Q-task_id([log_status]) MIQ(MiqEventHandler#log_status) [Event Handler] Worker ID [1000000002270], PID [2756], GUID [f99103f2-7eda-11e7-a70f-5254003dad57], Last Heartbeat [2017-08-11 23:06:14 UTC], Process Info: Memory Usage [338751488], Memory Size [672755712], Proportional Set Size: [235704000], Memory % [3.28], CPU Time [726.0], CPU % [0.11], Priority [27]
[miq1] [----] I, [2017-08-11T19:11:22.361405 #2949:b81140]  INFO -- : Q-task_id([log_status]) MIQ(MiqEventHandler#log_status) [Event Handler] Worker ID [1000000001071], PID [2922], GUID [c0f9c28a-7ed6-11e7-8b18-525400431635], Last Heartbeat [2017-08-11 23:11:14 UTC], Process Info: Memory Usage [310091776], Memory Size [652206080], Proportional Set Size: [203977000], Memory % [3.01], CPU Time [785.0], CPU % [0.09], Priority [27]
[miq2] [----] I, [2017-08-11T19:11:24.019597 #2765:623130]  INFO -- : Q-task_id([log_status]) MIQ(MiqEventHandler#log_status) [Event Handler] Worker ID [1000000002270], PID [2756], GUID [f99103f2-7eda-11e7-a70f-5254003dad57], Last Heartbeat [2017-08-11 23:11:21 UTC], Process Info: Memory Usage [338751488], Memory Size [672755712], Proportional Set Size: [235704000], Memory % [3.28], CPU Time [774.0], CPU % [0.12], Priority [27]
```
## miqgrep -r request_id
```
$ miqgrep -r 1,000,000,000,088

*** looking for tasks associated with request_id: 1000000000088 ***

*** looking for request_id: 1000000000088 and task_ids: 1000000000088 ***

*** miq1 ***

*** miq2 ***

*** miq3 ***

*** collating results ***

[miq2] [----] I, [2017-08-11T19:30:25.616820 #2773:3e3f758]  INFO -- : Q-task_id([service_template_provision_task_1000000000087]) Instantiating [/System/Process/REQUEST?MiqProvisionRequest%3A%3Amiq_provision_request=1000000000088&MiqRequest%3A%3Amiq_request=1000000000088&MiqServer%3A%3Amiq_server=1000000000001&User%3A%3Auser=1000000000001&message=get_vmname&object_name=REQUEST&request=UI_PROVISION_INFO&vmdb_object_type=miq_provision_request]
[miq2] [----] I, [2017-08-11T19:30:25.664169 #2773:3e3f758]  INFO -- : Q-task_id([service_template_provision_task_1000000000087]) Updated namespace [/System/Process/REQUEST?MiqProvisionRequest%3A%3Amiq_provision_request=1000000000088&MiqRequest%3A%3Amiq_request=1000000000088&MiqServer%3A%3Amiq_server=1000000000001&User%3A%3Auser=1000000000001&message=get_vmname&object_name=REQUEST&request=UI_PROVISION_INFO&vmdb_object_type=miq_provision_request  ManageIQ/System]
...
```
## miqtail pattern
```
$ miqtail "ERROR|WARN" evm

Running: multitail -L "ssh miq1 tail -f /var/www/miq/vmdb/log/evm.log \| egrep \"ERROR\|WARN\" | sed -e 's/^/[miq1] /'" -L "ssh miq2 tail -f /var/www/miq/vmdb/log/evm.log \| egrep \"ERROR\|WARN\" | sed -e 's/^/[miq2] /'" -L "ssh miq3 tail -f /var/www/miq/vmdb/log/evm.log \| egrep \"ERROR\|WARN\" | sed -e 's/^/[miq3] /'"

[miq1] [----] E, [2017-08-11T18:22:56.974519 #2939:b81140] ERROR -- : <RHEVM> Ovirt::Service#resource_get: class = Errno::EHOSTUNREACH, message=Failed to open TCP connection to rhvm1.hemlockhill.org:443 (No route to host - connect(2) for "rhvm1.hemlockhill.org" port 443), URI=https://rhvm1.hemlockhill.org/ovirt-engine/api
[miq1] [----] W, [2017-08-11T18:22:56.975316 #2939:b81140]  WARN -- : MIQ(ManageIQ::Providers::Redhat::InfraManager#verify_credentials_for_rhevm) Failed to open TCP connection to rhvm1.hemlockhill.org:443 (No route to host - connect(2) for "rhvm1.hemlockhill.org" port 443)
[miq1] [----] W, [2017-08-11T18:22:56.975570 #2939:b81140]  WARN -- : MIQ(ManageIQ::Providers::Redhat::InfraManager#authentication_check_no_validation) type: [:default] for [1000000000002] [rhvm1] Validation failed: unreachable, Failed to open TCP connection to rhvm1.hemlockhill.org:443 (No route to host - connect(2) for "rhvm1.hemlockhill.org" port 443)
[miq1] [----] W, [2017-08-11T18:22:56.976243 #2939:b81140]  WARN -- : MIQ(AuthUseridPassword#validation_failed) [ExtManagementSystem] [1000000000002], previously valid on: 2017-04-19 04:48:07 UTC, previous status: [Unreachable]
[miq1] [----] W, [2017-08-11T18:22:56.981000 #2931:b81140]  WARN -- : MIQ(ManageIQ::Providers::Vmware::InfraManager#verify_credentials) #<Errno::EHOSTUNREACH: No route to host - connect(2) for "vcenter1.hemlockhill.org" port 443 (vcenter1.hemlockhill.org:443)>
[miq1] [----] W, [2017-08-11T18:22:56.981450 #2931:b81140]  WARN -- : MIQ(ManageIQ::Providers::Vmware::InfraManager#authentication_check_no_validation) type: ["default"] for [1000000000001] [vcenter1] Validation failed: unreachable, No route to host - connect(2) for "vcenter1.hemlockhill.org" port 443 (vcenter1.hemlockhill.org:443)
[miq1] [----] W, [2017-08-11T18:22:56.982164 #2931:b81140]  WARN -- : MIQ(AuthUseridPassword#validation_failed) [ExtManagementSystem] [1000000000001], previously valid on: 2017-04-19 04:59:44 UTC, previous status: [Unreachable]
[miq2] [----] W, [2017-08-11T18:36:44.479934 #2738:623130]  WARN -- : MIQ(ManageIQ::Providers::Foreman::ConfigurationManager::RefreshParser#configuration_profile_inv_to_hashes) hostgroup openstack missing: location

```
## miqtail -r request_id
```
$ miqtail -r 1,000,000,000,088

*** looking for tasks associated with request_id: 1000000000088 ***

*** looking for request_id: 1000000000088 and task_ids: 1000000000088 ***

Running: multitail -L "ssh miq1 tail -f /var/www/miq/vmdb/log/automation.log \| egrep \"1000000000088\|1000000000088\" | sed -e 's/^/[miq1] /'" -L "ssh miq2 tail -f /var/www/miq/vmdb/log/automation.log \| egrep \"1000000000088\|1000000000088\" | sed -e 's/^/[miq2] /'" -L "ssh miq3 tail -f /var/www/miq/vmdb/log/automation.log \| egrep \"1000000000088\|1000000000088\" | sed -e 's/^/[miq3] /'"

[miq2] [----] I, [2017-08-11T19:31:06.042900 #2765:623130]  INFO -- : Q-task_id([miq_provision_request_1000000000088]) Followed  Relationship [miqaedb:/infrastructure/VM/Provisioning/Profile/EvmGroup-super_administrator#get_vmname]
[miq2] [----] I, [2017-08-11T19:31:06.043258 #2765:623130]  INFO -- : Q-task_id([miq_provision_request_1000000000088]) Followed  Relationship [miqaedb:/System/Request/UI_PROVISION_INFO#create]
[miq2] [----] I, [2017-08-11T19:31:09.194610 #2773:623130]  INFO -- : Q-task_id([miq_provision_1000000000088]) Instantiating [/System/Process/AUTOMATION?MiqProvision%3A%3Amiq_provision=1000000000088&MiqServer%3A%3Amiq_server=1000000000001&User%3A%3Auser=1000000000001&object_name=AUTOMATION&request=vm_provision&vmdb_object_type=miq_provision]

```
# Sample miqhosts file:

```
# This file is a sample.  See miqhosts-gen script to generate this file by querying the VMDB.
#
# hostname_or_ip  <white space>	groups to assign host to separated by commas.
#
# Lines starting with a # are ignored.
#
miqdb01.example.com		db
miqui01.example.com		ui
miqwrk01.example.com		workers,zone1
miqwrk02.example.com		workers,zone1
miqwrk03.example.com		workers,zone2
miqwrk04.example.com		workers,zone2
```
