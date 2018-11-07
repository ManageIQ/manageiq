# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Unreleased as of Sprint 98 ending 2018-11-05

### Added
- Include resource_action type and ID in linked components error message [(#18152)](https://github.com/ManageIQ/manageiq/pull/18152)
- ADD rbac_tenant_manage_quotas to tenant product features [(#18151)](https://github.com/ManageIQ/manageiq/pull/18151)
- Add support for using run_role_async [(#18108)](https://github.com/ManageIQ/manageiq/pull/18108)
- Add product features to ansible endpoint in the API [(#18059)](https://github.com/ManageIQ/manageiq/pull/18059)
- Adding ansible tags option through cmdline [(#18030)](https://github.com/ManageIQ/manageiq/pull/18030)
- Backend-initiated notifications in v2v for Successful and Failed Requests [(#18012)](https://github.com/ManageIQ/manageiq/pull/18012)
- Add template methods needed for provision report [(#17884)](https://github.com/ManageIQ/manageiq/pull/17884)

### Fixed
- Add aggregate_memory to container project [(#18159)](https://github.com/ManageIQ/manageiq/pull/18159)
- Credential.manager_ref need to be an integer for Tower 3.3 [(#18155)](https://github.com/ManageIQ/manageiq/pull/18155)
- Use images to get registry pods using the registry instead of running it. [(#18148)](https://github.com/ManageIQ/manageiq/pull/18148)
- Fix flavor and security group collection [(#18147)](https://github.com/ManageIQ/manageiq/pull/18147)
- system_context_requester User needs to be scoped by region [(#18145)](https://github.com/ManageIQ/manageiq/pull/18145)
- Fix send_args for EvmDatabaseOps.restore [(#18144)](https://github.com/ManageIQ/manageiq/pull/18144)
- Allow to set retirement date for service via Centralized Administration [(#18137)](https://github.com/ManageIQ/manageiq/pull/18137)
- Fix typo in get_conversion_log method [(#18136)](https://github.com/ManageIQ/manageiq/pull/18136)
- Add a validation for conversion hosts [(#18135)](https://github.com/ManageIQ/manageiq/pull/18135)
- Fix Exception due to missing #merged_uri parameters in FileDepot parent class [(#18131)](https://github.com/ManageIQ/manageiq/pull/18131)
- Use Settings.active_task_timeout for db backup task  instead of hardcoded value [(#18124)](https://github.com/ManageIQ/manageiq/pull/18124)
- Force a run of the setup playbook after a db failover [(#18120)](https://github.com/ManageIQ/manageiq/pull/18120)
- Retire Task deliver_to_automate now uses tenant_identity [(#18104)](https://github.com/ManageIQ/manageiq/pull/18104)
- Adjust VM validity correctly while editing a ServiceTemplate record [(#18065)](https://github.com/ManageIQ/manageiq/pull/18065)

## Gaprindashvili-6 - Released 2018-11-02

### Added
- Add possibility to group by date only in chargeback [(#17893)](https://github.com/ManageIQ/manageiq/pull/17893)
- Service retirement values from dialog [(#16799)](https://github.com/ManageIQ/manageiq/pull/16799)
- Added 64 and 128gb to provision dialogs [(#17622)](https://github.com/ManageIQ/manageiq/pull/17622)
- Add log messages to Chargeback [(#17874)](https://github.com/ManageIQ/manageiq/pull/17874)
- Add tenant filtering for templates in provisioning and summary pages [(#17851)](https://github.com/ManageIQ/manageiq/pull/17851)

### Fixed
- Always return 0 for missing num_cpu [(#17937)](https://github.com/ManageIQ/manageiq/pull/17937)
- Maintenance must run VACUUM to avoid long held locks [(#17713)](https://github.com/ManageIQ/manageiq/pull/17713)
- Allow for empty strings in the execution_ttl field [(#17715)](https://github.com/ManageIQ/manageiq/pull/17715)
- New and improved Field.is_field?() [(#17801)](https://github.com/ManageIQ/manageiq/pull/17801)
- Don't queue metrics capture if metrics unsupported [(#17820)](https://github.com/ManageIQ/manageiq/pull/17820)
- Add support for load_values_on_init to text boxes. [(#17814)](https://github.com/ManageIQ/manageiq/pull/17814)
- Fix metering report for resources without rollups [(#17836)](https://github.com/ManageIQ/manageiq/pull/17836)
- Fix counts in log message in ConsumptionHistory [(#17868)](https://github.com/ManageIQ/manageiq/pull/17868)
- Creating miq_request for CustomButton request call with open_url. [(#17802)](https://github.com/ManageIQ/manageiq/pull/17802)
- Ensure Zone data is Valid [(#17892)](https://github.com/ManageIQ/manageiq/pull/17892)
- Ensure options is always a hash [(#17917)](https://github.com/ManageIQ/manageiq/pull/17917)
- L10N - Add the missing pb and eb types for storage_units [(#17800)](https://github.com/ManageIQ/manageiq/pull/17800)
- Added access to MyTasks to self_service roles [(#18006)](https://github.com/ManageIQ/manageiq/pull/18006)
- Scope ui and api server searches to recently active servers [(#17670)](https://github.com/ManageIQ/manageiq/pull/17670)
- Add regex for dialog password fields. [(#17986)](https://github.com/ManageIQ/manageiq/pull/17986)
- Hide the password values in the log messages. [(#18028)](https://github.com/ManageIQ/manageiq/pull/18028)
- Scope ui and api server searches to recently active servers [(#17670)](https://github.com/ManageIQ/manageiq/pull/17670)
- Prevent queueing things for a zone that doesn't exist in the region [(#17987)](https://github.com/ManageIQ/manageiq/pull/17987)
- Currently on a successful ActionResult (start / stop) we return nil [(#18036)](https://github.com/ManageIQ/manageiq/pull/18036)
- Skip tags without classification in assigments [(#17883)](https://github.com/ManageIQ/manageiq/pull/17883)
- Add flag for init of defaults in fields [(#18061)](https://github.com/ManageIQ/manageiq/pull/18061)
- Check if class is taggable before attempting to process tag expression [(#18114)](https://github.com/ManageIQ/manageiq/pull/18114)

## Hammer Beta-2 - Released 2018-10-29

### Added
- Conversion script for mapped tags/classification from remote regions to global [(#17971)](https://github.com/ManageIQ/manageiq/pull/17971)
- Add tenant filtering for templates in provisioning and summary pages [(#17851)](https://github.com/ManageIQ/manageiq/pull/17851)
- Order custom buttons by array of ids [(#18060)](https://github.com/ManageIQ/manageiq/pull/18060)
- Openstack Swift DB Backups [(#17967)](https://github.com/ManageIQ/manageiq/pull/17967)
- Script to copy reports access from group to role [(#18066)](https://github.com/ManageIQ/manageiq/pull/18066)
- For database dumps don't modify the directory name [(#18058)](https://github.com/ManageIQ/manageiq/pull/18058)
- Add ext_management_system method to conversion host [(#18097)](https://github.com/ManageIQ/manageiq/pull/18097)
- Clean up mapped tenants after a CloudManager is destroyed [(#17866)](https://github.com/ManageIQ/manageiq/pull/17866)
- Conversion Host - Try hostname for SSH and fix MiqSshUtil args [(#18103)](https://github.com/ManageIQ/manageiq/pull/18103)
- Add resource ems_ref and ip addresses to virt-v2v options hash [(#18101)](https://github.com/ManageIQ/manageiq/pull/18101)

### Fixed
- Parse automation attrs correctly [(#18084)](https://github.com/ManageIQ/manageiq/pull/18084)
- Don't use special characters in ansible passwords [(#18092)](https://github.com/ManageIQ/manageiq/pull/18092)
- Add flag for init of defaults in fields [(#18061)](https://github.com/ManageIQ/manageiq/pull/18061)
- Handle a blank value for the http_proxy host [(#18073)](https://github.com/ManageIQ/manageiq/pull/18073)
- Add retirement initiator context [(#17951)](https://github.com/ManageIQ/manageiq/pull/17951)
- RestClient: Support percent encoded proxy user/pass [(#18105)](https://github.com/ManageIQ/manageiq/pull/18105)
- Add product setting default for allowing API service ordering [(#18029)](https://github.com/ManageIQ/manageiq/pull/18029)
- Check if class is taggable before attempting to process tag expression [(#18114)](https://github.com/ManageIQ/manageiq/pull/18114)
- Add object retirement_requester [(#18113)](https://github.com/ManageIQ/manageiq/pull/18113)
- Don't need the name, since it's mixed in... [(#18117)](https://github.com/ManageIQ/manageiq/pull/18117)

## Unreleased as of Sprint 97 ending 2018-10-22

### Added
- Fix travis failure in manageiq-content repo. [(#18115)](https://github.com/ManageIQ/manageiq/pull/18115)
- show VmClonedEvent in timelines [(#18075)](https://github.com/ManageIQ/manageiq/pull/18075)
- InventoryCollection definitions for Lenovo [(#18063)](https://github.com/ManageIQ/manageiq/pull/18063)
- Normalize extra_vars support for Ansible Tower playbooks. [(#18057)](https://github.com/ManageIQ/manageiq/pull/18057)
- Add delete notification types for Network Router [(#17514)](https://github.com/ManageIQ/manageiq/pull/17514)

### Fixed
Disable transactions in locking examples [(#18089)](https://github.com/ManageIQ/manageiq/pull/18089)
Rails 5.0/5.1 compatibility: Define through association before has many through [(#18080)](https://github.com/ManageIQ/manageiq/pull/18080)
Rails 5.0/5.1 Use o.reload.assoc assoc(true) is gone [(#18079)](https://github.com/ManageIQ/manageiq/pull/18079)
Rails 5.0/5.1 prepare_binds_for_database is gone [(#18078)](https://github.com/ManageIQ/manageiq/pull/18078)
Rails 5.1/5.0 compatibility: Use constant since string/symbol was removed [(#18077)](https://github.com/ManageIQ/manageiq/pull/18077)

## Hammer Beta-1 - Released 2018-10-12

### Added
- Add an alias for InventoryRefresh -> ManagerRefresh [(#17965)](https://github.com/ManageIQ/manageiq/pull/17965)
- Add physical chassis details builder [(#17941)](https://github.com/ManageIQ/manageiq/pull/17941)
- Add accessors for physical chassis tree [(#17940)](https://github.com/ManageIQ/manageiq/pull/17940)
- Add product feature for displaying custom button events [(#17939)](https://github.com/ManageIQ/manageiq/pull/17939)
- Add CustomButtonEvent association to GenericObject. [(#17924)](https://github.com/ManageIQ/manageiq/pull/17924)
- Product features for servicey things [(#17920)](https://github.com/ManageIQ/manageiq/pull/17920)
- Send link with the text_bindings in notifications when link_to is set [(#17913)](https://github.com/ManageIQ/manageiq/pull/17913)
- InventoryCollection's Builder exception message [(#17904)](https://github.com/ManageIQ/manageiq/pull/17904)
- Add best fit logic for transformations moving vms to openstack [(#17880)](https://github.com/ManageIQ/manageiq/pull/17880)
- Core fixes for infra graph refresh [(#17870)](https://github.com/ManageIQ/manageiq/pull/17870)
- Add Cloud Volume Type features [(#17828)](https://github.com/ManageIQ/manageiq/pull/17828)
- Save Canister Model [(#17706)](https://github.com/ManageIQ/manageiq/pull/17706)
- Service retirement values from dialog [(#16799)](https://github.com/ManageIQ/manageiq/pull/16799)
- Inform Rails that SecurityGroup now belongs to Router/Subnet [(#17900)](https://github.com/ManageIQ/manageiq/pull/17900)
- Populate timestamp of CustomButtonEvent. [(#17899)](https://github.com/ManageIQ/manageiq/pull/17899)
- Add requester to raise_retirement_event log message [(#17898)](https://github.com/ManageIQ/manageiq/pull/17898)
- Refresh containers service catalog entities [(#17895)](https://github.com/ManageIQ/manageiq/pull/17895)
- Add possibility to group by date only in chargeback [(#17893)](https://github.com/ManageIQ/manageiq/pull/17893)
- Add search filter to ESX 6.7 [(#17891)](https://github.com/ManageIQ/manageiq/pull/17891)
- Advanced_settings assoc for google refresh [(#17890)](https://github.com/ManageIQ/manageiq/pull/17890)
- Logging to Inventory collector/parser [(#17889)](https://github.com/ManageIQ/manageiq/pull/17889)
- Added key pairs cloud networks and networks to reporting and expresions [(#17888)](https://github.com/ManageIQ/manageiq/pull/17888)
- Changes to CustomButtonEvent. [(#17885)](https://github.com/ManageIQ/manageiq/pull/17885)
- Add support for exporting and importing customization templates [(#17877)](https://github.com/ManageIQ/manageiq/pull/17877)
- Expose ems_cluster_id on VMs for use in V2V OpenStack support [(#17876)](https://github.com/ManageIQ/manageiq/pull/17876)
- Add log messages to Chargeback [(#17874)](https://github.com/ManageIQ/manageiq/pull/17874)
- Updating example oVirt cloud-init template [(#17869)](https://github.com/ManageIQ/manageiq/pull/17869)
- Add a relationship between Tenant and VolumeTypes [(#17864)](https://github.com/ManageIQ/manageiq/pull/17864)
- Partial row updates in parallel [(#17861)](https://github.com/ManageIQ/manageiq/pull/17861)
- Added Audit logging to new user creation [(#17852)](https://github.com/ManageIQ/manageiq/pull/17852)
- Adding summary for number of resources racks and health states to Provider [(#17841)](https://github.com/ManageIQ/manageiq/pull/17841)
- Create a physical infrastructure user group [(#17840)](https://github.com/ManageIQ/manageiq/pull/17840)
- Create generic task notifications [(#17835)](https://github.com/ManageIQ/manageiq/pull/17835)
- Add a model for ConversionHosts [(#17813)](https://github.com/ManageIQ/manageiq/pull/17813)
- Add Openstack to list of valid prefixes for tag mapping [(#17790)](https://github.com/ManageIQ/manageiq/pull/17790)
- Add CustomButton event emiter [(#17764)](https://github.com/ManageIQ/manageiq/pull/17764)
- remote log/.gitkeep [(#17663)](https://github.com/ManageIQ/manageiq/pull/17663)
- Add delete notifications for Networks Subnets [(#17556)](https://github.com/ManageIQ/manageiq/pull/17556)
- Don't queue EmsRefresh if using streaming refresh [(#17531)](https://github.com/ManageIQ/manageiq/pull/17531)
- Add new rename_queue method to VM operations [(#17853)](https://github.com/ManageIQ/manageiq/pull/17853)
- Missing definitions for targeted refresh for containers [(#17846)](https://github.com/ManageIQ/manageiq/pull/17846)
- rake evm:db:restore:remote mods for S3 [(#17827)](https://github.com/ManageIQ/manageiq/pull/17827)
- Add an association for Datacenters [(#17821)](https://github.com/ManageIQ/manageiq/pull/17821)
- Vmdb::Plugins::AssetPath - add node_modules development_gem? [(#17818)](https://github.com/ManageIQ/manageiq/pull/17818)
- Move the roles dir to content/ansible_runner [(#17811)](https://github.com/ManageIQ/manageiq/pull/17811)
- Cleanup Ansible::Runner [(#17808)](https://github.com/ManageIQ/manageiq/pull/17808)
- Add Danish krone (DKK) currency to chargeback rates [(#17807)](https://github.com/ManageIQ/manageiq/pull/17807)
- ServiceAnsibleTower to provision both job and workflow [(#17804)](https://github.com/ManageIQ/manageiq/pull/17804)
- Support for DB Restore from Object Stores [(#17791)](https://github.com/ManageIQ/manageiq/pull/17791)
- Added ability to create default dashboard for group [(#17778)](https://github.com/ManageIQ/manageiq/pull/17778)
- Seed Ansible Roles for Vmdb Plugins [(#17777)](https://github.com/ManageIQ/manageiq/pull/17777)
- [RFE] Allow customizing product title and brand image through settings [(#17773)](https://github.com/ManageIQ/manageiq/pull/17773)
- Allow mapping event types to groups using regexes [(#17772)](https://github.com/ManageIQ/manageiq/pull/17772)
- Add codename in log file and stdout [(#17769)](https://github.com/ManageIQ/manageiq/pull/17769)
- Add Vmdb::Plugins#versions [(#17755)](https://github.com/ManageIQ/manageiq/pull/17755)
- Prefix the method name with the class name for validation errors [(#17754)](https://github.com/ManageIQ/manageiq/pull/17754)
- Do not fallback-compile missing assets [(#17741)](https://github.com/ManageIQ/manageiq/pull/17741)
- Add support for exporting and importing provision dialogs [(#17739)](https://github.com/ManageIQ/manageiq/pull/17739)
- Add rake task to import custom buttons [(#17726)](https://github.com/ManageIQ/manageiq/pull/17726)
- Add permission to groups of users access the event_streams_view [(#17723)](https://github.com/ManageIQ/manageiq/pull/17723)
- ConfigurationWorkflow to exist only in AutomationManager space [(#17720)](https://github.com/ManageIQ/manageiq/pull/17720)
- put S3 refresh in a separate worker [(#17704)](https://github.com/ManageIQ/manageiq/pull/17704)
- Save Physical Disks Model [(#17700)](https://github.com/ManageIQ/manageiq/pull/17700)
- DB Backups to AWS S3 [(#17689)](https://github.com/ManageIQ/manageiq/pull/17689)
- Notify users of killing workers when exceed memory [(#17673)](https://github.com/ManageIQ/manageiq/pull/17673)
- Remove hacked relations [(#17545)](https://github.com/ManageIQ/manageiq/pull/17545)
- Ansible runner async method [(#17763)](https://github.com/ManageIQ/manageiq/pull/17763)
- Ansible runner add missing yard docs [(#17761)](https://github.com/ManageIQ/manageiq/pull/17761)
- Add a state machine for long ansible operations [(#17759)](https://github.com/ManageIQ/manageiq/pull/17759)
- Ansible runner allow to run roles without playbook [(#17757)](https://github.com/ManageIQ/manageiq/pull/17757)
- Add validations for the ansible-runner params [(#17749)](https://github.com/ManageIQ/manageiq/pull/17749)
- Connecting physical switch to computer systems [(#17735)](https://github.com/ManageIQ/manageiq/pull/17735)
- Replace custom_attributes by ems_custom_attributes [(#17734)](https://github.com/ManageIQ/manageiq/pull/17734)
- InventoryCollection definitions for vmware infra [(#17729)](https://github.com/ManageIQ/manageiq/pull/17729)
- locale:po_to_json: add support for including catalogs from javascript plugins [(#17725)](https://github.com/ManageIQ/manageiq/pull/17725)
- Service AnsibleTower and EmbeddedAnsible UI parity [(#17712)](https://github.com/ManageIQ/manageiq/pull/17712)
- Add support to show Group Level of an event in the timeline page. [(#17702)](https://github.com/ManageIQ/manageiq/pull/17702)
- Add rake task to export custom buttons [(#17699)](https://github.com/ManageIQ/manageiq/pull/17699)
- Use ansible-runner instead of ansible-playbook [(#17688)](https://github.com/ManageIQ/manageiq/pull/17688)
- Add relationship between [physical switch and physical chassis] and event stream [(#17661)](https://github.com/ManageIQ/manageiq/pull/17661)
- Adding PhysicalStorage into PhysicalChassis [(#17616)](https://github.com/ManageIQ/manageiq/pull/17616)
- Add Cloud Volume Type model [(#17610)](https://github.com/ManageIQ/manageiq/pull/17610)
- Add host_guest_devices association and inv_collection [(#17505)](https://github.com/ManageIQ/manageiq/pull/17505)
- Add a method to queue an Ansible::Runner.run [(#17705)](https://github.com/ManageIQ/manageiq/pull/17705)
- Adding miq_feature to chassis LED operation [(#17668)](https://github.com/ManageIQ/manageiq/pull/17668)
- Provider generator: Persister update [(#17666)](https://github.com/ManageIQ/manageiq/pull/17666)
- InventoryCollection Builder improvements [(#17621)](https://github.com/ManageIQ/manageiq/pull/17621)
- Add a new event group level [(#17611)](https://github.com/ManageIQ/manageiq/pull/17611)
- Add the ability to rename a VM [(#17658)](https://github.com/ManageIQ/manageiq/pull/17658)
- Add display name for PhysicalSwitch model [(#17655)](https://github.com/ManageIQ/manageiq/pull/17655)
- Add factory :ansible_tower_workflow_job. [(#17654)](https://github.com/ManageIQ/manageiq/pull/17654)
- Adding title and cve's to openscap_rule_result creation [(#17651)](https://github.com/ManageIQ/manageiq/pull/17651)
- Add an ansible_tower_log to vmdb loggers [(#17634)](https://github.com/ManageIQ/manageiq/pull/17634)
- Add a method to remove a disk from a VM [(#17633)](https://github.com/ManageIQ/manageiq/pull/17633)
- Return with HTML table instead of PDF in the saved report async task [(#17632)](https://github.com/ManageIQ/manageiq/pull/17632)
- Add a precanned physical server policy [(#17624)](https://github.com/ManageIQ/manageiq/pull/17624)
- [RFE]Added 64 and 128gb to provision dialogs [(#17622)](https://github.com/ManageIQ/manageiq/pull/17622)
- Add Polish to chargeback currencies [(#17609)](https://github.com/ManageIQ/manageiq/pull/17609)
- Scheduling catalog items [(#17594)](https://github.com/ManageIQ/manageiq/pull/17594)
- Extracting physical ports of a switch to a new page [(#17593)](https://github.com/ManageIQ/manageiq/pull/17593)
- Adjusting ManageIQ core to enable PhysicalStorage API endpoint [(#17586)](https://github.com/ManageIQ/manageiq/pull/17586)
- Support moving a VM to another folder during VM Migrate. [(#17519)](https://github.com/ManageIQ/manageiq/pull/17519)
- Keep track of the server ids where the automate task has been processed. [(#17451)](https://github.com/ManageIQ/manageiq/pull/17451)
- Adding connection b/w physical servers and physical switches [(#17311)](https://github.com/ManageIQ/manageiq/pull/17311)
- Add configuration_script_sources.last_update_error [(#17290)](https://github.com/ManageIQ/manageiq/pull/17290)
- Cashe cloud volumes in ChargebackVm [(#17585)](https://github.com/ManageIQ/manageiq/pull/17585)
- Add policy event host_failure. [(#17578)](https://github.com/ManageIQ/manageiq/pull/17578)
- Add display name for guest device [(#17573)](https://github.com/ManageIQ/manageiq/pull/17573)
- Add display name for Credential (RHV) [(#17572)](https://github.com/ManageIQ/manageiq/pull/17572)
- Added IC Builder definition for Tower Workflow [(#17571)](https://github.com/ManageIQ/manageiq/pull/17571)
- Add simple wrapping code for running ansible-playbook [(#17564)](https://github.com/ManageIQ/manageiq/pull/17564)
- Add physical infra related default collections [(#17557)](https://github.com/ManageIQ/manageiq/pull/17557)
- Adding miq_feature to Physical Switch restart [(#17548)](https://github.com/ManageIQ/manageiq/pull/17548)
- Add display name for Physical Server (Redfish) [(#17532)](https://github.com/ManageIQ/manageiq/pull/17532)
- Add tests for rbac on ansible playbooks and authentications [(#17528)](https://github.com/ManageIQ/manageiq/pull/17528)
- Added separate features for Requests subtabs [(#17524)](https://github.com/ManageIQ/manageiq/pull/17524)
- Adds support for Physical Chassis in the UI [(#17523)](https://github.com/ManageIQ/manageiq/pull/17523)
- Fix to show vm/image related info in audit log when deleting vm/image [(#17504)](https://github.com/ManageIQ/manageiq/pull/17504)
- Added actions for suspend a provider [(#17500)](https://github.com/ManageIQ/manageiq/pull/17500)
- Ability to reset settings to default value and delete newly added keys [(#17482)](https://github.com/ManageIQ/manageiq/pull/17482)
- Add has_one scope support to virtual_delegate [(#17473)](https://github.com/ManageIQ/manageiq/pull/17473)
- Integrate with external Tower Workflow [(#17440)](https://github.com/ManageIQ/manageiq/pull/17440)
- Warn when we're running fix_auth in dry run mode [(#17410)](https://github.com/ManageIQ/manageiq/pull/17410)
- Fix call for future retirement [(#17382)](https://github.com/ManageIQ/manageiq/pull/17382)
- Create a virtual column for `archived` for using in the API [(#17509)](https://github.com/ManageIQ/manageiq/pull/17509)
- Raise an event on failed login attempt [(#17508)](https://github.com/ManageIQ/manageiq/pull/17508)
- Move get_file and save_file to ConfigurationManagementMixin [(#17494)](https://github.com/ManageIQ/manageiq/pull/17494)
- Remove changes to enable workers to be started in containers [(#17493)](https://github.com/ManageIQ/manageiq/pull/17493)
- Add physical server asset details collection [(#17486)](https://github.com/ManageIQ/manageiq/pull/17486)
- Add Redfish provider logger [(#17485)](https://github.com/ManageIQ/manageiq/pull/17485)
- Add evm:db:dump:local and evm:db:dump:remote tasks [(#17483)](https://github.com/ManageIQ/manageiq/pull/17483)
- Add include_automate_models_and_dialogs to ::Settings [(#17467)](https://github.com/ManageIQ/manageiq/pull/17467)
- Upload automate models dialogs during log collection [(#17445)](https://github.com/ManageIQ/manageiq/pull/17445)
- Use feature for admin [(#17444)](https://github.com/ManageIQ/manageiq/pull/17444)
- Add feature to allow downloading private keys [(#17439)](https://github.com/ManageIQ/manageiq/pull/17439)
- Add Redfish server default collection [(#17426)](https://github.com/ManageIQ/manageiq/pull/17426)
- Wire up Redfish inventory collector [(#17393)](https://github.com/ManageIQ/manageiq/pull/17393)
- Save Physical Storage Model [(#17380)](https://github.com/ManageIQ/manageiq/pull/17380)
- Add support for sysprep customization templates [(#17293)](https://github.com/ManageIQ/manageiq/pull/17293)
- PhysicalRack refresh action [(#17162)](https://github.com/ManageIQ/manageiq/pull/17162)
- Add more currencies to chargeback [(#17456)](https://github.com/ManageIQ/manageiq/pull/17456)
- Report chargeback from all regions [(#17453)](https://github.com/ManageIQ/manageiq/pull/17453)
- Read ui url from settings file for dev environment [(#17435)](https://github.com/ManageIQ/manageiq/pull/17435)
- Added export/import of SmartState Analysis Profiles [(#17427)](https://github.com/ManageIQ/manageiq/pull/17427)
- Nested lazy find with secondary ref [(#17425)](https://github.com/ManageIQ/manageiq/pull/17425)
- Add methods to process the refesh action for a PhysicalSwitch [(#17409)](https://github.com/ManageIQ/manageiq/pull/17409)
- Targeted scope serialization [(#17408)](https://github.com/ManageIQ/manageiq/pull/17408)
- Expose plugin ansible content consolidation as a rake task [(#17407)](https://github.com/ManageIQ/manageiq/pull/17407)
- Changed get_file method to receive a resource as parameter. [(#17406)](https://github.com/ManageIQ/manageiq/pull/17406)
- Adjusting ManageIQ core to enable PhysicalChassis API endpoint [(#17320)](https://github.com/ManageIQ/manageiq/pull/17320)
- Config file to represent Rack in the UI [(#17078)](https://github.com/ManageIQ/manageiq/pull/17078)
- Add support for reconfigure cdroms [(#17365)](https://github.com/ManageIQ/manageiq/pull/17365)
- Enhance persister serialization [(#17361)](https://github.com/ManageIQ/manageiq/pull/17361)
- Removing confirm_password field from change_password routine [(#17345)](https://github.com/ManageIQ/manageiq/pull/17345)
- Add logging and update upgrade_message for successful registration [(#17340)](https://github.com/ManageIQ/manageiq/pull/17340)
- Add reporting session threshold options in settings [(#17334)](https://github.com/ManageIQ/manageiq/pull/17334)
- GuestDevice model updates for support of storage devices [(#17332)](https://github.com/ManageIQ/manageiq/pull/17332)
- Add call for bundled service children retirement [(#17317)](https://github.com/ManageIQ/manageiq/pull/17317)
- Add support for exporting an importing service dialogs [(#17241)](https://github.com/ManageIQ/manageiq/pull/17241)
- Adding roles filters and configurations for Physical Switches support [(#17216)](https://github.com/ManageIQ/manageiq/pull/17216)
- Initialize MiqQueue.miq_task_id column when queuing metric capture task [(#17301)](https://github.com/ManageIQ/manageiq/pull/17301)
- Add .yamllint config to provider generators [(#17281)](https://github.com/ManageIQ/manageiq/pull/17281)
- Add `:transformation` under product and set it to `true` by default [(#17270)](https://github.com/ManageIQ/manageiq/pull/17270)
- Save Physical Chassis [(#17236)](https://github.com/ManageIQ/manageiq/pull/17236)
- Add child retirement task methods [(#17234)](https://github.com/ManageIQ/manageiq/pull/17234)
- Add delete notification types for Tenant [(#17011)](https://github.com/ManageIQ/manageiq/pull/17011)
- Add InventoryObject interface automatically [(#17010)](https://github.com/ManageIQ/manageiq/pull/17010)
- Add support for exporting and importing tags [(#16983)](https://github.com/ManageIQ/manageiq/pull/16983)
- Add crud for Template [(#17217)](https://github.com/ManageIQ/manageiq/pull/17217)
- Add remote console feature for physical servers [(#17213)](https://github.com/ManageIQ/manageiq/pull/17213)
- Add image_create to product features [(#17089)](https://github.com/ManageIQ/manageiq/pull/17089)
- Adding request id to evm log [(#17013)](https://github.com/ManageIQ/manageiq/pull/17013)
- Adding switches support for physical infra [(#16948)](https://github.com/ManageIQ/manageiq/pull/16948)
- Add a Physical Rack model [(#16853)](https://github.com/ManageIQ/manageiq/pull/16853)
- Expose get_assigned_tos as virtual attribute to allow access via the API [(#17182)](https://github.com/ManageIQ/manageiq/pull/17182)
- Make resource groups taggable [(#17148)](https://github.com/ManageIQ/manageiq/pull/17148)
- Add rates to chargeback report [(#17142)](https://github.com/ManageIQ/manageiq/pull/17142)
- Tower Rhv credential type [(#17044)](https://github.com/ManageIQ/manageiq/pull/17044)
- Activate miq_task when deliver from miq_queue [(#17015)](https://github.com/ManageIQ/manageiq/pull/17015)
- Add tasks and models for retire as a request [(#16933)](https://github.com/ManageIQ/manageiq/pull/16933)
- Return a task when queueing chargeback report generation for services [(#17135)](https://github.com/ManageIQ/manageiq/pull/17135)
- Moved creating task instances message. [(#17093)](https://github.com/ManageIQ/manageiq/pull/17093)
- Automatically fetch the right unique index [(#17029)](https://github.com/ManageIQ/manageiq/pull/17029)
- ConfigurationScriptSource to have last_updated_on column [(#17026)](https://github.com/ManageIQ/manageiq/pull/17026)
- Stop container workers cleanly [(#17042)](https://github.com/ManageIQ/manageiq/pull/17042)
- Differentiate being in a container vs running in OpenShift/k8s [(#17028)](https://github.com/ManageIQ/manageiq/pull/17028)
- Add the artemis auth info as env variables in worker containers [(#17025)](https://github.com/ManageIQ/manageiq/pull/17025)
- Use arel to build local_db multiselect condition [(#17012)](https://github.com/ManageIQ/manageiq/pull/17012)
- Add sui_product_features method to miq_group [(#17007)](https://github.com/ManageIQ/manageiq/pull/17007)
- Add miq_product_features to miq_group [(#17003)](https://github.com/ManageIQ/manageiq/pull/17003)
- Rename new guest device pages [(#16996)](https://github.com/ManageIQ/manageiq/pull/16996)
- Two small fixes to tools/miqssh [(#16986)](https://github.com/ManageIQ/manageiq/pull/16986)
- Get targeted arel query automatically [(#16981)](https://github.com/ManageIQ/manageiq/pull/16981)
- Inventory task [(#16980)](https://github.com/ManageIQ/manageiq/pull/16980)
- Fix reason scope for MiqRequest [(#16950)](https://github.com/ManageIQ/manageiq/pull/16950)
- Graph refresh skeletal precreate [(#16882)](https://github.com/ManageIQ/manageiq/pull/16882)
- [REARCH] Container workers [(#15884)](https://github.com/ManageIQ/manageiq/pull/15884)
- Don't return in a rake task [(#16920)](https://github.com/ManageIQ/manageiq/pull/16920)
- Declare Kubevirt's template as eligible for provision [(#16873)](https://github.com/ManageIQ/manageiq/pull/16873)
- Add scopes for MiqRequest [(#16843)](https://github.com/ManageIQ/manageiq/pull/16843)
- Add api_allowed_attributes to ExtManagementSystem and Provider [(#16802)](https://github.com/ManageIQ/manageiq/pull/16802)
- Graph refresh enhance local db finders [(#16741)](https://github.com/ManageIQ/manageiq/pull/16741)
- Graph refresh use advanced references [(#16659)](https://github.com/ManageIQ/manageiq/pull/16659)
- Adds unique within region check to pxe image type names [(#16745)](https://github.com/ManageIQ/manageiq/pull/16745)
- Picture content is moving to the pictures table. [(#16810)](https://github.com/ManageIQ/manageiq/pull/16810)
- Adding apply config pattern feature [(#16796)](https://github.com/ManageIQ/manageiq/pull/16796)
- Add orphan purging for vim_performance_states [(#16754)](https://github.com/ManageIQ/manageiq/pull/16754)
- Introduce virtualization manager [(#16721)](https://github.com/ManageIQ/manageiq/pull/16721)
- Graph refresh refactoring internal indexes [(#16597)](https://github.com/ManageIQ/manageiq/pull/16597)
- Add ems_cluster_id to vms returned by validator [(#18011)](https://github.com/ManageIQ/manageiq/pull/18011)
- Add :cinder_volume_types to SupportsFeatureMixin [(#18000)](https://github.com/ManageIQ/manageiq/pull/18000)
- virtual column for parent blue folder path with excluded non-display folders [(#17976)](https://github.com/ManageIQ/manageiq/pull/17976)
- virtual column for `default_security_group` to make it accessible via the API [(#17975)](https://github.com/ManageIQ/manageiq/pull/17975)
- Allow ems to terminate connection after use [(#17959)](https://github.com/ManageIQ/manageiq/pull/17959)
- Add CPU cores and MEMORY metering allocation to Metering reports [(#17938)](https://github.com/ManageIQ/manageiq/pull/17938)
- Shared persistor definitions plus adding ServiceInstance [(#17933)](https://github.com/ManageIQ/manageiq/pull/17933)
- Add file splitting to evm:db tasks (V2) [(#17894)](https://github.com/ManageIQ/manageiq/pull/17894)
- Adding product features for PhysicalInfra Overview page [(#17770)](https://github.com/ManageIQ/manageiq/pull/17770)
- Add sysprep support for oVirt provider [(#17636)](https://github.com/ManageIQ/manageiq/pull/17636)
- Add VmMigrationValidator. [(#17364)](https://github.com/ManageIQ/manageiq/pull/17364)
- Detect and log long running http(s) requests [(#17842)](https://github.com/ManageIQ/manageiq/pull/17842)
- Add OSP attributes to VM ServiceResource options [(#18045)](https://github.com/ManageIQ/manageiq/pull/18045)
- Add methods to conversion_host to build virt-v2v wrapper options [(#18033)](https://github.com/ManageIQ/manageiq/pull/18033)
- Move from apache module mod_auth_kerb to mod_auth_gssapi [(#18014)](https://github.com/ManageIQ/manageiq/pull/18014)

### Fixed
- update attribute_builder for rails change [(#17996)](https://github.com/ManageIQ/manageiq/pull/17996)
- Rescue NoMethodError to prevent requeueing something that won't work [(#18017)](https://github.com/ManageIQ/manageiq/pull/18017)
- Fixing Computer System relationship on Physical Storage [(#17945)](https://github.com/ManageIQ/manageiq/pull/17945)
- Fix of inventory building and refactoring [(#17942)](https://github.com/ManageIQ/manageiq/pull/17942)
- Always return 0 for missing num_cpu [(#17937)](https://github.com/ManageIQ/manageiq/pull/17937)
- fix: with_role_excluding has bad subquery [(#17930)](https://github.com/ManageIQ/manageiq/pull/17930)
- Add method to allow access for tenant quotas [(#17926)](https://github.com/ManageIQ/manageiq/pull/17926)
- Do not duplicate same notification if user belongs to several groups [(#17918)](https://github.com/ManageIQ/manageiq/pull/17918)
- Ensure options is always a hash [(#17917)](https://github.com/ManageIQ/manageiq/pull/17917)
- Association default can't be array [(#17915)](https://github.com/ManageIQ/manageiq/pull/17915)
- Fix Refresh Relationships and Power States button for VMs Instances Images [(#17863)](https://github.com/ManageIQ/manageiq/pull/17863)
- rake locale:plugin:find fixes [(#17847)](https://github.com/ManageIQ/manageiq/pull/17847)
- Get rid of the condition modifier. [(#16213)](https://github.com/ManageIQ/manageiq/pull/16213)
- Add possibility to group by date only in chargeback [(#17893)](https://github.com/ManageIQ/manageiq/pull/17893)
- Ensure Zone data is Valid [(#17892)](https://github.com/ManageIQ/manageiq/pull/17892)
- Skip tags without classification in assigments [(#17883)](https://github.com/ManageIQ/manageiq/pull/17883)
- Send the notification ID when propagating a notification through WS [(#17875)](https://github.com/ManageIQ/manageiq/pull/17875)
- Backup subject's name in case subject is removed [(#17871)](https://github.com/ManageIQ/manageiq/pull/17871)
- Fix counts in log message in ConsumptionHistory [(#17868)](https://github.com/ManageIQ/manageiq/pull/17868)
- Load dialog fields with updated values on workflow submit [(#17855)](https://github.com/ManageIQ/manageiq/pull/17855)
- Fix Physical Storage to Physical Disks inverse association [(#17854)](https://github.com/ManageIQ/manageiq/pull/17854)
- Converge request user roles to match API and UI [(#17849)](https://github.com/ManageIQ/manageiq/pull/17849)
- Fix metering report for resources without rollups [(#17836)](https://github.com/ManageIQ/manageiq/pull/17836)
- Filter out orphaned hosts and cloud instances from list of running [(#17815)](https://github.com/ManageIQ/manageiq/pull/17815)
- Creating miq_request for CustomButton request call with open_url. [(#17802)](https://github.com/ManageIQ/manageiq/pull/17802)
- switch back to require_nested due to linux load error [(#17848)](https://github.com/ManageIQ/manageiq/pull/17848)
- human_attribute_name():  add ui option to be able to call original (super) method [(#17834)](https://github.com/ManageIQ/manageiq/pull/17834)
- Fix bug with EvmDatabaseOps.dump [(#17830)](https://github.com/ManageIQ/manageiq/pull/17830)
- Fix for physical server alert bug [(#17829)](https://github.com/ManageIQ/manageiq/pull/17829)
- Don't log the deprecation debug messages in production [(#17824)](https://github.com/ManageIQ/manageiq/pull/17824)
- Mark Cloud Tenant as required for Openstack provisioning [(#17822)](https://github.com/ManageIQ/manageiq/pull/17822)
- Don't queue metrics capture if metrics unsupported [(#17820)](https://github.com/ManageIQ/manageiq/pull/17820)
- Add support for load_values_on_init to text boxes. [(#17814)](https://github.com/ManageIQ/manageiq/pull/17814)
- Save Aws Region in File Depot for DB Backup [(#17803)](https://github.com/ManageIQ/manageiq/pull/17803)
- New and improved Field.is_field?() [(#17801)](https://github.com/ManageIQ/manageiq/pull/17801)
- L10N - Add the missing pb and eb types for storage_units  [(#17800)](https://github.com/ManageIQ/manageiq/pull/17800)
- Distinguish between no password provided and bad password in error message [(#17792)](https://github.com/ManageIQ/manageiq/pull/17792)
- Apply gettext to initial & error service dialog values [(#17789)](https://github.com/ManageIQ/manageiq/pull/17789)
- Include task_id in result of ResourceActionWorkflow#process_request [(#17788)](https://github.com/ManageIQ/manageiq/pull/17788)
- Graph refresh of configuration_scripts and configuration_workflows in one InventoryCollection [(#17785)](https://github.com/ManageIQ/manageiq/pull/17785)
- Add internal attribute to service template [(#17781)](https://github.com/ManageIQ/manageiq/pull/17781)
- Fix Remove Selected Items from Inventory button for Images Instances [(#17780)](https://github.com/ManageIQ/manageiq/pull/17780)
- Include the request_type when creating a retirement request [(#17779)](https://github.com/ManageIQ/manageiq/pull/17779)
- Use standard method for filesystem cleanup [(#17774)](https://github.com/ManageIQ/manageiq/pull/17774)
- Allow tenant admins to see all groups within the scope of their tenant [(#17768)](https://github.com/ManageIQ/manageiq/pull/17768)
- Logging archived targets during C&U collection [(#17762)](https://github.com/ManageIQ/manageiq/pull/17762)
- Avoid raising and re-queueing when the remote resource is not found [(#17745)](https://github.com/ManageIQ/manageiq/pull/17745)
- Added Physical Server view to OOTB Security role. [(#17753)](https://github.com/ManageIQ/manageiq/pull/17753)
- Fix refresh time and memory issues [(#17724)](https://github.com/ManageIQ/manageiq/pull/17724)
- Fix detection of an EMS to use for Storage#scan [(#17718)](https://github.com/ManageIQ/manageiq/pull/17718)
- Allow for empty strings in the execution_ttl field [(#17715)](https://github.com/ManageIQ/manageiq/pull/17715)
- Missing embedded ansible persisters dependencies [(#17574)](https://github.com/ManageIQ/manageiq/pull/17574)
- Maintenance must run VACUUM to avoid long held locks [(#17713)](https://github.com/ManageIQ/manageiq/pull/17713)
- Fix import export smartstate analysis [(#17697)](https://github.com/ManageIQ/manageiq/pull/17697)
- automation_manager should use :manager(_id) instead of :ems_id [(#17694)](https://github.com/ManageIQ/manageiq/pull/17694)
- fix MiqGroup#miq_user_role_name [(#17686)](https://github.com/ManageIQ/manageiq/pull/17686)
- Network Subnet total_vms work correctly [(#17683)](https://github.com/ManageIQ/manageiq/pull/17683)
- Remove generic object from all related services before destroy [(#17679)](https://github.com/ManageIQ/manageiq/pull/17679)
- Scope ui and api server searches to recently active servers [(#17670)](https://github.com/ManageIQ/manageiq/pull/17670)
- Miq server zone description [(#17662)](https://github.com/ManageIQ/manageiq/pull/17662)
- Normal Operating Range cpu/mem usage rate to use avg (instead of max) values  [(#17614)](https://github.com/ManageIQ/manageiq/pull/17614)
- Give embedded ansible enough time to start in containers [(#17603)](https://github.com/ManageIQ/manageiq/pull/17603)
- Add Automate Generic Objects shortcut menu [(#17630)](https://github.com/ManageIQ/manageiq/pull/17630)
- Fix ordering of metric rollups in consumption history [(#17620)](https://github.com/ManageIQ/manageiq/pull/17620)
- Reject empty button groups from the result of #custom_actions [(#17607)](https://github.com/ManageIQ/manageiq/pull/17607)
- Fixed InventoryCollection Vm and Template [(#17602)](https://github.com/ManageIQ/manageiq/pull/17602)
- Skip Vm reconnect if already reconnected [(#17570)](https://github.com/ManageIQ/manageiq/pull/17570)
- Explicitly shortcut "everything" for privileges [(#17526)](https://github.com/ManageIQ/manageiq/pull/17526)
- Fix multiple parents error moving vm to new folder [(#17525)](https://github.com/ManageIQ/manageiq/pull/17525)
- Join object and block storage under ems_storage in the features tree [(#17512)](https://github.com/ManageIQ/manageiq/pull/17512)
- Fixing the refresh to remove all physical switches. [(#17390)](https://github.com/ManageIQ/manageiq/pull/17390)
- Add display name for RHV Embedded Ansible Credential [(#17330)](https://github.com/ManageIQ/manageiq/pull/17330)
- Migrate model display names from locale/en.yml to models [(#16836)](https://github.com/ManageIQ/manageiq/pull/16836)
- Define model_name with route keys for the StorageManager model [(#17513)](https://github.com/ManageIQ/manageiq/pull/17513)
- Extend support from memberof to other multi-value attribute for group membership [(#17497)](https://github.com/ManageIQ/manageiq/pull/17497)
- Allow MiqReport.paged_view_search to take advantage of Rbac :extra_cols [(#17474)](https://github.com/ManageIQ/manageiq/pull/17474)
- Remove :match_via_decendants for ConfiguredSystem::ConfiguredSystem [(#17430)](https://github.com/ManageIQ/manageiq/pull/17430)
- Fix current/active server deletability validation [(#17391)](https://github.com/ManageIQ/manageiq/pull/17391)
- NOR covers 30 days [(#17376)](https://github.com/ManageIQ/manageiq/pull/17376)
- Remove 'Storage Total' field from Chargeback Preview reports [(#17199)](https://github.com/ManageIQ/manageiq/pull/17199)
- PhysicalRack refresh action [(#17162)](https://github.com/ManageIQ/manageiq/pull/17162)
- Fixes to Rbac::Filterer#skip_references [(#17429)](https://github.com/ManageIQ/manageiq/pull/17429)
- Always reconnect the oldest entity [(#17421)](https://github.com/ManageIQ/manageiq/pull/17421)
- Skip Vm reconnect if already reconnected [(#17417)](https://github.com/ManageIQ/manageiq/pull/17417)
- Renamed method to delete container object store for consistency reasons [(#17399)](https://github.com/ManageIQ/manageiq/pull/17399)
- Deduplicate embedded ansible notifications [(#17394)](https://github.com/ManageIQ/manageiq/pull/17394)
- Delete dequeued shutdown_and_exit messages from MiqQueue on server start [(#17370)](https://github.com/ManageIQ/manageiq/pull/17370)
- Add an entry for guest device to en.yml [(#17350)](https://github.com/ManageIQ/manageiq/pull/17350)
- Renamed method to delete cloud object store for consistency reasons [(#17143)](https://github.com/ManageIQ/manageiq/pull/17143)
- Fix infra inventory collections for targeted refresh [(#17324)](https://github.com/ManageIQ/manageiq/pull/17324)
- Fixes for create action in Template model [(#17308)](https://github.com/ManageIQ/manageiq/pull/17308)
- Change the role for Service provisioning create_request_tasks MiqQueue.put. [(#17297)](https://github.com/ManageIQ/manageiq/pull/17297)
- Fix call to process_tasks to run the right thing [(#17255)](https://github.com/ManageIQ/manageiq/pull/17255)
- Removed redundant entries from start up drop down. [(#17260)](https://github.com/ManageIQ/manageiq/pull/17260)
- Give more information on a failed configuration validation. [(#17247)](https://github.com/ManageIQ/manageiq/pull/17247)
- Log Vm or Template for Create/Update [(#17240)](https://github.com/ManageIQ/manageiq/pull/17240)
- Fix update_attributes to take right number of args [(#17235)](https://github.com/ManageIQ/manageiq/pull/17235)
- Providers discovery without unspecified discovery types (FIX) [(#17229)](https://github.com/ManageIQ/manageiq/pull/17229)
- Add custom Azure logger [(#17228)](https://github.com/ManageIQ/manageiq/pull/17228)
- Add 'breakable' optional argument to report_build_html_table method [(#17204)](https://github.com/ManageIQ/manageiq/pull/17204)
- Cache MiqExpression.get_col_type in MiqReport::Formatting [(#17195)](https://github.com/ManageIQ/manageiq/pull/17195)
- Refactor ensure_nondefault method for chargeback rate [(#17188)](https://github.com/ManageIQ/manageiq/pull/17188)
- Add product files for physical server dashboard widgets [(#17172)](https://github.com/ManageIQ/manageiq/pull/17172)
- Fix provider proxy settings fallback [(#17205)](https://github.com/ManageIQ/manageiq/pull/17205)
- Bad skipping of assert in production env [(#17173)](https://github.com/ManageIQ/manageiq/pull/17173)
- Add encryption key validation rake task [(#17149)](https://github.com/ManageIQ/manageiq/pull/17149)
- Use vm_ems_ref to reconnect events [(#17145)](https://github.com/ManageIQ/manageiq/pull/17145)
- Stop unbounded growth of targets [(#17144)](https://github.com/ManageIQ/manageiq/pull/17144)
- Don't define DISALLOWED_SUFFIXES if already defined [(#17125)](https://github.com/ManageIQ/manageiq/pull/17125)
- Alphabets are hard... [(#17136)](https://github.com/ManageIQ/manageiq/pull/17136)
- Bump manageiq-smartstate to 0.2.10 version [(#17121)](https://github.com/ManageIQ/manageiq/pull/17121)
- Fix ambiguous created_recently scope [(#17102)](https://github.com/ManageIQ/manageiq/pull/17102)
- Fix single security group in provisioning [(#17094)](https://github.com/ManageIQ/manageiq/pull/17094)
- Remove new fields from export if empty [(#17080)](https://github.com/ManageIQ/manageiq/pull/17080)
- Calculate totals for hours of exitstence in metering reports [(#17077)](https://github.com/ManageIQ/manageiq/pull/17077)
- Configure server settings cleanup [(#17059)](https://github.com/ManageIQ/manageiq/pull/17059)
- Fix rake `evm:status` and `evm:status_full` [(#17054)](https://github.com/ManageIQ/manageiq/pull/17054)
- Removal of nil's before relationship remove_children [(#17038)](https://github.com/ManageIQ/manageiq/pull/17038)
- Fix build methods [(#17032)](https://github.com/ManageIQ/manageiq/pull/17032)
- Fix alerts based on hourly timer for container entities [(#16902)](https://github.com/ManageIQ/manageiq/pull/16902)
- Singularize plural model [(#16833)](https://github.com/ManageIQ/manageiq/pull/16833)
- Close open connections from parent after fork [(#16953)](https://github.com/ManageIQ/manageiq/pull/16953)
- Add a 'Container Project Discovered' event [(#16903)](https://github.com/ManageIQ/manageiq/pull/16903)
- Don't dependent => destroy child managers [(#16871)](https://github.com/ManageIQ/manageiq/pull/16871)
- Change DescendantLoader to handle non-AR classes in the models directory [(#16867)](https://github.com/ManageIQ/manageiq/pull/16867)
- Added before_save to MiqTask to initialize MiqTask#started_on when task become active [(#16863)](https://github.com/ManageIQ/manageiq/pull/16863)
- Add missing role for container user groups [(#16861)](https://github.com/ManageIQ/manageiq/pull/16861)
- When using http only set env variable to allow insecure sessions [(#16854)](https://github.com/ManageIQ/manageiq/pull/16854)
- Allow users already in UPN format [(#16849)](https://github.com/ManageIQ/manageiq/pull/16849)
- Fix memory leak with ruby/require/autoload_paths [(#16837)](https://github.com/ManageIQ/manageiq/pull/16837)
- Change the way active_provisions are calculated. [(#16831)](https://github.com/ManageIQ/manageiq/pull/16831)
- Add acts_as_miq_taggable to AuthPrivateKey [(#16828)](https://github.com/ManageIQ/manageiq/pull/16828)
- Update users' current_group on group  deletion [(#16809)](https://github.com/ManageIQ/manageiq/pull/16809)
- Fixed expression evaluation for custom button in CustomActionMixin [(#16770)](https://github.com/ManageIQ/manageiq/pull/16770)
- Provider to orchestrate_destroy managers first - Alt [(#16755)](https://github.com/ManageIQ/manageiq/pull/16755)
- EmsRefresh task name to use demodularize classname [(#16594)](https://github.com/ManageIQ/manageiq/pull/16594)
- ContainerServicePortConfigs using :container_service :name [(#16454)](https://github.com/ManageIQ/manageiq/pull/16454)
- Establish a new connection instead of reconnect! [(#18010)](https://github.com/ManageIQ/manageiq/pull/18010)
- Added access to MyTasks to self_service roles [(#18006)](https://github.com/ManageIQ/manageiq/pull/18006)
- Delegate verify_ssl & verify_ssl= to default endpoint [(#18001)](https://github.com/ManageIQ/manageiq/pull/18001)
- Fixed error with replication setup when default exclude list used [(#17999)](https://github.com/ManageIQ/manageiq/pull/17999)
- Fix to handle the case when default value of internal is nil [(#17995)](https://github.com/ManageIQ/manageiq/pull/17995)
- Only reload settings for servers in current region [(#17992)](https://github.com/ManageIQ/manageiq/pull/17992)
- Prevent queueing things for a zone that doesn't exist in the region [(#17987)](https://github.com/ManageIQ/manageiq/pull/17987)
- Add regex for dialog password fields. [(#17986)](https://github.com/ManageIQ/manageiq/pull/17986)
- Move `virtual` definition for `default_security_group` to OpenStack [(#17979)](https://github.com/ManageIQ/manageiq/pull/17979)
- Remove line from metering_container_image_spec and FIX CI failure [(#17974)](https://github.com/ManageIQ/manageiq/pull/17974)
- Load all the values along with their key names into the field update method [(#17973)](https://github.com/ManageIQ/manageiq/pull/17973)
- Fix Physical Disks save inventory [(#17972)](https://github.com/ManageIQ/manageiq/pull/17972)
- Fix Canisters save inventory [(#17966)](https://github.com/ManageIQ/manageiq/pull/17966)
- Add Switch model to RBAC [(#17964)](https://github.com/ManageIQ/manageiq/pull/17964)
- Consolidate production env checks [(#17957)](https://github.com/ManageIQ/manageiq/pull/17957)
- Add replication set-up methods to be queued on UI side [(#17956)](https://github.com/ManageIQ/manageiq/pull/17956)
- Adds task to subservices for correct retirement completion [(#17912)](https://github.com/ManageIQ/manageiq/pull/17912)
- Enable cancel operation for service template transformation plan request [(#17825)](https://github.com/ManageIQ/manageiq/pull/17825)
- Add Ownership and Tenancy Mixins to Authentication [(#17731)](https://github.com/ManageIQ/manageiq/pull/17731)
- Add a patch to ActiveRecord::Migration for tracking replicated migrations [(#17919)](https://github.com/ManageIQ/manageiq/pull/17919)
- Properly create tenant default group for population [(#18025)](https://github.com/ManageIQ/manageiq/pull/18025)
- Hide the password values in the log messages. [(#18028)](https://github.com/ManageIQ/manageiq/pull/18028)
- Do not double encrypt a protected password dialog text field [(#18031)](https://github.com/ManageIQ/manageiq/pull/18031)
- Validate towhat policy field [(#18032)](https://github.com/ManageIQ/manageiq/pull/18032)
- Fix Notifications None [(#18035)](https://github.com/ManageIQ/manageiq/pull/18035)
- Fixed MiqExpression evaluation on tagged Services [(#18020)](https://github.com/ManageIQ/manageiq/pull/18020)
- Fix ServiceTemplateTransformationPlan edit action [(#17989)](https://github.com/ManageIQ/manageiq/pull/17989)
- Queue reporting work for any zone [(#18041)](https://github.com/ManageIQ/manageiq/pull/18041)
- Create custom button events for each object in target list [(#18042)](https://github.com/ManageIQ/manageiq/pull/18042)
- Currently on a successful ActionResult (start / stop) we return nil [(#18036)](https://github.com/ManageIQ/manageiq/pull/18036)
- Fix typo in message if VM has no provider [(#18047)](https://github.com/ManageIQ/manageiq/pull/18047)
- Don't start memcached in any container runtime [(#18051)](https://github.com/ManageIQ/manageiq/pull/18051)
- Fix ordering in list of custom buttons [(#18049)](https://github.com/ManageIQ/manageiq/pull/18049)
- Properly serialize OrchestrationStack class name for MiqRetireTask.request_type [(#18023)](https://github.com/ManageIQ/manageiq/pull/18023)
- Force targets to be an array so we can each them in cb run on multiple objects [(#18056)](https://github.com/ManageIQ/manageiq/pull/18056)
- Don't use interpolation in gettext strings [(#18067)](https://github.com/ManageIQ/manageiq/pull/18067)
- Don't translate FileDepot types [(#18069)](https://github.com/ManageIQ/manageiq/pull/18069)

### Removed
- Remove todo with virtual attr inclusion in attr list [(#18019)](https://github.com/ManageIQ/manageiq/pull/18019)
- Remove Debug Message [(#17796)](https://github.com/ManageIQ/manageiq/pull/17796)
- remove 'require_nested :ConfigurationWorkflow' from parent space [(#17782)](https://github.com/ManageIQ/manageiq/pull/17782)
- Remove ui_lookup_for_title() [(#17691)](https://github.com/ManageIQ/manageiq/pull/17691)

## Unreleased as of Sprint 96 ending 2018-10-08

### Added
- Get container statuses during refresh [(#18016)](https://github.com/ManageIQ/manageiq/pull/18016)
- Add Redfish event catcher [(#18013)](https://github.com/ManageIQ/manageiq/pull/18013)

## Gaprindashvili-5 - Released 2018-09-07

### Added
- Scheduling catalog items [(#17765)](https://github.com/ManageIQ/manageiq/pull/17765)
- locale:po_to_json: add support for including catalogs from js plugins [(#17740)](https://github.com/ManageIQ/manageiq/pull/17740)
- Support cancellation for miq_request and miq_request_task [(#17687)](https://github.com/ManageIQ/manageiq/pull/17687)
- Add Cumulative Chargeback rates [(#17795)](https://github.com/ManageIQ/manageiq/pull/17795)
- Add RBAC feature for Migration (v2v). [(#17596)](https://github.com/ManageIQ/manageiq/pull/17596)
- Add ServiceTemplate#miq_schedules relation [(#17672)](https://github.com/ManageIQ/manageiq/pull/17672)
- Support for v2v pre/post Ansible playbook service. [(#17627)](https://github.com/ManageIQ/manageiq/pull/17627)
- The vm_id coming in from API is a string. [(#17674)](https://github.com/ManageIQ/manageiq/pull/17674)
- MiqSchedule call method directly if available [(#17588)](https://github.com/ManageIQ/manageiq/pull/17588)
- Validate name uniqueness for Transformation Plans [(#17677)](https://github.com/ManageIQ/manageiq/pull/17677)

### Fixed
- Add option to prov workflow to not rerun methods [(#17641)](https://github.com/ManageIQ/manageiq/pull/17641)
- Set Settings.product.transformation to true [(#17733)](https://github.com/ManageIQ/manageiq/pull/17733)
- Set checkbox on load, sans default, to be false, not nil [(#17810)](https://github.com/ManageIQ/manageiq/pull/17810)
- Allow tenant admins to see all groups within the scope of their tenant [(#17817)](https://github.com/ManageIQ/manageiq/pull/17817)
- Ensure MiqSchedule#name is unique for ServiceTemplate orders [(#17696)](https://github.com/ManageIQ/manageiq/pull/17696)
- Fix class name for queueing [(#17717)](https://github.com/ManageIQ/manageiq/pull/17717)
- Start the drb server with a unix socket [(#17744)](https://github.com/ManageIQ/manageiq/pull/17744)
- Add internal column to service template for transformation plan [(#17748)](https://github.com/ManageIQ/manageiq/pull/17748)
- Add pt_BR.yml for Brazilian Portuguese [(#17775)](https://github.com/ManageIQ/manageiq/pull/17775)
- Fix for $evm.execute not honoring dialog options [(#17844)](https://github.com/ManageIQ/manageiq/pull/17844)
- Move VIRTUAL_COL_USES translation to col_index method in ChargeableField [(#17747)](https://github.com/ManageIQ/manageiq/pull/17747)
- Only update zone if found [(#17139)](https://github.com/ManageIQ/manageiq/pull/17139)
- Add option to clear classifications for tag_details [(#17465)](https://github.com/ManageIQ/manageiq/pull/17465)
- Add Flavor model to :tag_classes: section in miq_expression.yml. [(#17537)](https://github.com/ManageIQ/manageiq/pull/17537)
- Restrict Vm Operating System detection for XP [(#17405)](https://github.com/ManageIQ/manageiq/pull/17405)
- Delete #retire_now since it has been moved to shared code [(#17095)](https://github.com/ManageIQ/manageiq/pull/17095)
- Return custom buttons for service having nil service template [(#17703)](https://github.com/ManageIQ/manageiq/pull/17703)
- Force user_type to UPN when username is a UPN [(#17690)](https://github.com/ManageIQ/manageiq/pull/17690)
- Adding flavor as a has one on VM [(#17692)](https://github.com/ManageIQ/manageiq/pull/17692)
- Clean up queued items on Zone#destroy [(#17374)](https://github.com/ManageIQ/manageiq/pull/17374)

## Gaprindashvili-4

### Added
- Introduce model changes for v2v [(#16787)](https://github.com/ManageIQ/manageiq/pull/16787)
- Transformation Plan, Request, and Task for V2V [(#16960)](https://github.com/ManageIQ/manageiq/pull/16960)
- Add lans as a virtual relationship to ems_cluster [(#17019)](https://github.com/ManageIQ/manageiq/pull/17019)
- Support for hidden columns in reports and views [(#17133)](https://github.com/ManageIQ/manageiq/pull/17133)
- Add has_many :miq_requests in ServiceTemplate [(#17242)](https://github.com/ManageIQ/manageiq/pull/17242)
- Add association of service_templates to TransformationMapping. [(#17266)](https://github.com/ManageIQ/manageiq/pull/17266)
- Add TransformationMapping#validate_vms method [(#17177)](https://github.com/ManageIQ/manageiq/pull/17177)
- Introduce support for multi-tab orchestration dialogs [(#17342)](https://github.com/ManageIQ/manageiq/pull/17342)
- Update vm transformation status in a plan [(#17027)](https://github.com/ManageIQ/manageiq/pull/17027)
- Use constant to store ServiceResource status. [(#17256)](https://github.com/ManageIQ/manageiq/pull/17256)
- Adding classifications for V2V [(#17000)](https://github.com/ManageIQ/manageiq/pull/17000)
- Backend enhancements for transformation plan request to better support UI [(#17071)](https://github.com/ManageIQ/manageiq/pull/17071)
- Add methods to extract v2v log from conversion host. [(#17333)](https://github.com/ManageIQ/manageiq/pull/17333)
- Provide base graph refresh attributes for ::Snapshot [(#17335)](https://github.com/ManageIQ/manageiq/pull/17335)
- Resize disk reconfigure screen [(#16711)](https://github.com/ManageIQ/manageiq/pull/16711)
- Reconfigure VM: Add / Remove Network Adapters [(#16700)](https://github.com/ManageIQ/manageiq/pull/16700)
- Add built in policy to prevent transformed VM from starting. [(#17389)](https://github.com/ManageIQ/manageiq/pull/17389)
- Add ArchivedMixin to ServiceTemplate [(#17480)](https://github.com/ManageIQ/manageiq/pull/17480)
- Add Archive/Unarchive for Service Templates to features [(#17518)](https://github.com/ManageIQ/manageiq/pull/17518)
- Add faster MiqReportResult helper methods for viewing saved report results [(#17590)](https://github.com/ManageIQ/manageiq/pull/17590)
- Add tool to remove grouping from report results [(#17589)](https://github.com/ManageIQ/manageiq/pull/17589)
- Add save hooks on MiqReportResult to remove groupings [(#17598)](https://github.com/ManageIQ/manageiq/pull/17598)
- Changes custom_attribute virtual_attributes to support AREL/SQL [(#17615)](https://github.com/ManageIQ/manageiq/pull/17615)
- Make all public images be visible for provisioning. [(#17058)](https://github.com/ManageIQ/manageiq/pull/17058)
- Add `:transformation` under product and set to `false` [(#17285)](https://github.com/ManageIQ/manageiq/pull/17285)
- v2v plugin [(#17529)](https://github.com/ManageIQ/manageiq/pull/17529)
- Add ArchivedMixin to ServiceTemplate [(#17481)](https://github.com/ManageIQ/manageiq/pull/17481)
- Use AREL for custom_attributes virtual_attributes in MiqReport ONLY [(#17629)](https://github.com/ManageIQ/manageiq/pull/17629)

### Fixed
- Fix the issue of defined analyisis profile missed in vm scanning. [(#17331)](https://github.com/ManageIQ/manageiq/pull/17331)
- Get allocated values of sub metrics for cloud volumes in chargeback without rollups [(#17277)](https://github.com/ManageIQ/manageiq/pull/17277)
- Require dalli before using it [(#17269)](https://github.com/ManageIQ/manageiq/pull/17269) 
- Changing the description of the 'vlan' field in provision/network [(#17306)](https://github.com/ManageIQ/manageiq/pull/17306)
- Add cloud volumes for selecting assigned tagged resources [(#17271)](https://github.com/ManageIQ/manageiq/pull/17271)
- Add method retire_now to container OrchestrationStack. [(#17298)](https://github.com/ManageIQ/manageiq/pull/17298)
- Check all costs fields for relevancy for the report [(#17387)](https://github.com/ManageIQ/manageiq/pull/17387)
- Do not delete children snapshots as part of parent [(#17462)](https://github.com/ManageIQ/manageiq/pull/17462)
- Adjust how default_value is calculated for multi-select drop downs [(#17449)](https://github.com/ManageIQ/manageiq/pull/17449)
- Added ActAsTaggable concern to MiqRequest model [(#17466)](https://github.com/ManageIQ/manageiq/pull/17466)
- Use current tags for filtering resources in chargeback for VMs [(#17470)](https://github.com/ManageIQ/manageiq/pull/17470)
- Add product features needed for v2v Transformation Mappings API [(#16947)](https://github.com/ManageIQ/manageiq/pull/16947)
- Add #orderable? as alias method [(#17045)](https://github.com/ManageIQ/manageiq/pull/17045)
- Honor user provided execution_ttl option [(#17476)](https://github.com/ManageIQ/manageiq/pull/17476)
- Adding the profile description option to the provision error message [(#17495)](https://github.com/ManageIQ/manageiq/pull/17495)
- Removes last call to automate from dialog_field serializer [(#17436)](https://github.com/ManageIQ/manageiq/pull/17436)
- No event will be shown when a compliance policy is created for a Physical Infra [(#17516)](https://github.com/ManageIQ/manageiq/pull/17516)
- Allow models to include methods for MiqExpression sql evaluation [(#17562)](https://github.com/ManageIQ/manageiq/pull/17562)
- Fix for STI scoping across leaves [(#16775)](https://github.com/ManageIQ/manageiq/pull/16775)
- Allow duplicate nil pxe_image_types during seed (for the current region) [(#17544)](https://github.com/ManageIQ/manageiq/pull/17544)
- Replace remove duplicate timestamp by sql version for chargeback [(#17538)](https://github.com/ManageIQ/manageiq/pull/17538)
- Use pluck on metric rollup query in chargeback [(#17560)](https://github.com/ManageIQ/manageiq/pull/17560)
- Remove conversion to UTC in Chargeback [(#17606)](https://github.com/ManageIQ/manageiq/pull/17606)
- Memoize log.prefix calls [(#17355)](https://github.com/ManageIQ/manageiq/pull/17355)
- Prevents N+1 SQL queries in miq_request_workflow.rb [(#17354)](https://github.com/ManageIQ/manageiq/pull/17354)
- Add uniq on datacenters in #host_to_folder [(#17422)](https://github.com/ManageIQ/manageiq/pull/17422)
- Use nested hashes instead of string keys [(#17357)](https://github.com/ManageIQ/manageiq/pull/17357)
- Avoid duplicate host load in allowed_hosts_obj [(#17402)](https://github.com/ManageIQ/manageiq/pull/17402)
- Refactor get_ems_folders to create less strings [(#17358)](https://github.com/ManageIQ/manageiq/pull/17358)
- Ancestry Patch updates/fixes [(#17511)](https://github.com/ManageIQ/manageiq/pull/17511)
- Fixed the virtual columns to be able to use in the API with `filter[]` [(#17553)](https://github.com/ManageIQ/manageiq/pull/17553)
- Ensure sorting does not happen when sort_by is set to "none" [(#17625)](https://github.com/ManageIQ/manageiq/pull/17625)
- Add `nil` check for report.extras on save hooks [(#17605)](https://github.com/ManageIQ/manageiq/pull/17605)
- Set value of static text box to default when default exists [(#17631)](https://github.com/ManageIQ/manageiq/pull/17631)
- Filter relevant fields also according to chargeback class in Chargeback [(#17414)](https://github.com/ManageIQ/manageiq/pull/17414)
- include shared external networks in list on router create [(#17305)](https://github.com/ManageIQ/manageiq/pull/17305)
- move #my_zone from ArchivedMixin to OldEmsMixin [(#17539)](https://github.com/ManageIQ/manageiq/pull/17539)
- Change reconfigure setup to include values configured with originally [(#17647)](https://github.com/ManageIQ/manageiq/pull/17647)
- Fixes undefined method `name` error during CSV validation required for v2v migration [(#17650)](https://github.com/ManageIQ/manageiq/pull/17650)
- Remove Request taggable and prevent tag filtering [(#17656)](https://github.com/ManageIQ/manageiq/pull/17656)
- Filter relevant fields also according to chargeback class in Chargeback [(#17639)](https://github.com/ManageIQ/manageiq/pull/17639)

### Removed
- Get rid off query "All in One" in Chargeback [(#17552)](https://github.com/ManageIQ/manageiq/pull/17552)
- Remove N+1 obj creation in flatten_arranged_rels [(#17325)](https://github.com/ManageIQ/manageiq/pull/17325)

## Gaprindashvili-3 released 2018-05-15

### Added
- Introduce $nuage_log that logs into log/nuage.log [(#16455)](https://github.com/ManageIQ/manageiq/pull/16455)
- Group chargeback report for VMs by tenant [(#17002)](https://github.com/ManageIQ/manageiq/pull/17002)
- EMS infra: adds Openstack undercloud discovery [(#16318)](https://github.com/ManageIQ/manageiq/pull/16318)
- Make Taggable of AutomationManager's authentications/playbooks/repos [(#17049)](https://github.com/ManageIQ/manageiq/pull/17049)
- Add tagging feature for Ansible Credentials [(#17079)](https://github.com/ManageIQ/manageiq/pull/17079)
- Add ConfigurationScriptSource to RBAC [(#17091)](https://github.com/ManageIQ/manageiq/pull/17091)
- Add tagging feature for Ansible Repositories [(#17083)](https://github.com/ManageIQ/manageiq/pull/17083)
- Adds purging for notifications [(#17046)](https://github.com/ManageIQ/manageiq/pull/17046)
- Add reindex to job scheduler [(#16929)](https://github.com/ManageIQ/manageiq/pull/16929)
- Add Vacuum to Job Scheduler [(#16940)](https://github.com/ManageIQ/manageiq/pull/16940)
- Allow individual tables to be specified for metrics [(#17051)](https://github.com/ManageIQ/manageiq/pull/17051)
- Create an empty CSS file that is outside the asset pipeline [(#17127)](https://github.com/ManageIQ/manageiq/pull/17127)
- Add tagging feature for Ansible Playbooks [(#17099)](https://github.com/ManageIQ/manageiq/pull/17099)
- Tower 3.2.2 vault credential types [(#16825)](https://github.com/ManageIQ/manageiq/pull/16825)
- Add circular reference association check to import for ui update [(#16918)](https://github.com/ManageIQ/manageiq/pull/16918)
- Tower Rhv credential type [(#17044)](https://github.com/ManageIQ/manageiq/pull/17044)
- Report datetime columns(begining and end of resource's existence) in metering report of VMs [(#17100)](https://github.com/ManageIQ/manageiq/pull/17100)
- Compare decimal columns correctly in batch saver [(#17020)](https://github.com/ManageIQ/manageiq/pull/17020)
- Enhance logging around remove snapshot operations [(#17057)](https://github.com/ManageIQ/manageiq/pull/17057)
- Keep container quota history by archiving [(#16722)](https://github.com/ManageIQ/manageiq/pull/16722)
- Allow OrchestrationTemplate subclass to customize md5 calculation [(#17126)](https://github.com/ManageIQ/manageiq/pull/17126)
- Add vault credential support to Ansible playbook service template. [(#17184)](https://github.com/ManageIQ/manageiq/pull/17184)
- Purging of ContainerQuota & ContainerQuotaItem [(#17167)](https://github.com/ManageIQ/manageiq/pull/17167)
- Add vault credential support to automat playbook method. [(#17192)](https://github.com/ManageIQ/manageiq/pull/17192)
- Add title display message and factory for Vault Credentials [(#17048)](https://github.com/ManageIQ/manageiq/pull/17048)
- Add vault credential to factory and provision_job_options. [(#17207)](https://github.com/ManageIQ/manageiq/pull/17207)
- Add support for non-binary WebMKS websocket [(#17200)](https://github.com/ManageIQ/manageiq/pull/17200)
- Added Embedded Ansible Content plugin [(#17096)](https://github.com/ManageIQ/manageiq/pull/17096)
- Seed plugin ansible playbooks [(#17185)](https://github.com/ManageIQ/manageiq/pull/17185)
- Add timeout knob for monitoring server roles [(#17265)](https://github.com/ManageIQ/manageiq/pull/17265)
- Azure labeling and tagging support [(#17212)](https://github.com/ManageIQ/manageiq/pull/17212)
- Add lock to retire_now start [(#17280)](https://github.com/ManageIQ/manageiq/pull/17280)
- Add Openstack Cinder EventCatcher worker [(#17351)](https://github.com/ManageIQ/manageiq/pull/17351)
- Add a memcached bind address for tower [(#17366)](https://github.com/ManageIQ/manageiq/pull/17366)

### Fixed
- Many things rely on authentications, check it first [(#16864)](https://github.com/ManageIQ/manageiq/pull/16864)
- Add condition to fix deletion of Default Container Image Rate [(#16792)](https://github.com/ManageIQ/manageiq/pull/16792)
- Event state machine is added to replace the synchronous refresh. [(#16868)](https://github.com/ManageIQ/manageiq/pull/16868)
- Change aliases for container entities [(#16765)](https://github.com/ManageIQ/manageiq/pull/16765)
- Rescue attempt to get backlog for remote db in PglogicalSubscription#backlog [(#16889)](https://github.com/ManageIQ/manageiq/pull/16889)
- Add display name for Amazon Network Router [(#16912)](https://github.com/ManageIQ/manageiq/pull/16912)
- Only store the hostname if the hostname is valid [(#16913)](https://github.com/ManageIQ/manageiq/pull/16913)
- Implement #configuration_script because of virtual_has_one relationship [(#16923)](https://github.com/ManageIQ/manageiq/pull/16923)
- Remove chargeback rate from metering reports [(#16928)](https://github.com/ManageIQ/manageiq/pull/16928)
- Support mixed case basedn. [(#16925)](https://github.com/ManageIQ/manageiq/pull/16925)
- Fix physical server and topology access rights for EvmRole-operator [(#16958)](https://github.com/ManageIQ/manageiq/pull/16958)
- Fix event linking to a disconnected VM [(#16907)](https://github.com/ManageIQ/manageiq/pull/16907)
- Configure yum proxy if given for updates [(#16972)](https://github.com/ManageIQ/manageiq/pull/16972)
- Re-check the provider authentication if the API is responding [(#16989)](https://github.com/ManageIQ/manageiq/pull/16989)
- Add support for bind dn and bind pwd on the command line. [(#16979)](https://github.com/ManageIQ/manageiq/pull/16979)
- Fix replication validation for not saved subscriptions [(#16997)](https://github.com/ManageIQ/manageiq/pull/16997)
- Fix errors in help message [(#17009)](https://github.com/ManageIQ/manageiq/pull/17009)
- Handle group names with encoded special characters [(#16998)](https://github.com/ManageIQ/manageiq/pull/16998)
- Update the human description for "cpu_used_delta_summation" [(#16878)](https://github.com/ManageIQ/manageiq/pull/16878)
- query also archived objects for a new ems [(#16886)](https://github.com/ManageIQ/manageiq/pull/16886)
- Changes to catch the retirement requester in automate. [(#17033)](https://github.com/ManageIQ/manageiq/pull/17033)
- For all roles that have sui product features adds sui_notifications [(#16817)](https://github.com/ManageIQ/manageiq/pull/16817)
- Support Automate Git repos without master branch [(#16690)](https://github.com/ManageIQ/manageiq/pull/16690)
- Raise a notification when registration fails [(#17037)](https://github.com/ManageIQ/manageiq/pull/17037)
- Adding missing Product Feature for viewing a single container [(#17074)](https://github.com/ManageIQ/manageiq/pull/17074)
- Add uniqueness of service for generation chargeback report for SSUI [(#17082)](https://github.com/ManageIQ/manageiq/pull/17082)
- Rename network module to not overrun network class [(#16994)](https://github.com/ManageIQ/manageiq/pull/16994)
- Fix the pre-defined Auditor role's permissions. [(#16394)](https://github.com/ManageIQ/manageiq/pull/16394)
- Move SchemaMigration from ManageIQ to ManageIQ::Schema plugin [(#17072)](https://github.com/ManageIQ/manageiq/pull/17072)
- Remove options[:user_message] during miq_request_task creation. [(#17084)](https://github.com/ManageIQ/manageiq/pull/17084)
- Fix RBAC for User and enable tagging for Tenants [(#17061)](https://github.com/ManageIQ/manageiq/pull/17061)
- Pass target object when evaluating expression for Generic Object [(#16858)](https://github.com/ManageIQ/manageiq/pull/16858)
- Make db restore more reliable [(#16942)](https://github.com/ManageIQ/manageiq/pull/16942)
- Fix Default log level for automation log [(#17130)](https://github.com/ManageIQ/manageiq/pull/17130)
- Do not divide recipients to subgroup when sending attached report [(#17132)](https://github.com/ManageIQ/manageiq/pull/17132)
- Fix policy_events relationship on VmOrTemplate [(#17036)](https://github.com/ManageIQ/manageiq/pull/17036)
- Consolidate Azure refresh workers [(#17076)](https://github.com/ManageIQ/manageiq/pull/17076)
- Core changes for azure targeted refresh [(#17070)](https://github.com/ManageIQ/manageiq/pull/17070)
- Add detail and name to the new update event group [(#17164)](https://github.com/ManageIQ/manageiq/pull/17164)
- Remove empty array associations created via UI from association list [(#16919)](https://github.com/ManageIQ/manageiq/pull/16919)
- Fix active_provision quota check for infra VM request with invalid vm_template. [(#17158)](https://github.com/ManageIQ/manageiq/pull/17158)
- Fail Cinder/Swift Ensures if Service not Present [(#17067)](https://github.com/ManageIQ/manageiq/pull/17067)
- Fix RefreshWorker dequeue race condition [(#17187)](https://github.com/ManageIQ/manageiq/pull/17187)
- Add case insensitivity when validating uniqueness of name of new group/role [(#17197)](https://github.com/ManageIQ/manageiq/pull/17197)
- Fixed case of expression in OOTB report. [(#17191)](https://github.com/ManageIQ/manageiq/pull/17191)
- Fix establishing relations of tenants and cloud tenants between different cloud tenant -> tenant sync [(#17190)](https://github.com/ManageIQ/manageiq/pull/17190)
- Add ownership for MiqRequest in RBAC [(#17208)](https://github.com/ManageIQ/manageiq/pull/17208)
- Change the method signatures for ServiceTemplateContainerTemplate. [(#17221)](https://github.com/ManageIQ/manageiq/pull/17221)
- Don't ignore errors in Vm#running_processes [(#17220)](https://github.com/ManageIQ/manageiq/pull/17220)
- Fix editing Ansible Credential/Repository for restricted user [(#17244)](https://github.com/ManageIQ/manageiq/pull/17244)
- Makes http_proxy_uri class method [(#17218)](https://github.com/ManageIQ/manageiq/pull/17218)
- Fixed error with dialog expression when virtual column involved [(#17215)](https://github.com/ManageIQ/manageiq/pull/17215)
- Skip query references in Rbac when not needed [(#17141)](https://github.com/ManageIQ/manageiq/pull/17141)
- convert Vm#miq_provision_template to has_one [(#17246)](https://github.com/ManageIQ/manageiq/pull/17246)
- Set DRb conn pool to [] after closing connections [(#17267)](https://github.com/ManageIQ/manageiq/pull/17267)
- Adding scan action with userid to container_image [(#17264)](https://github.com/ManageIQ/manageiq/pull/17264)
- Don't format PersistentVolume-capacity as bytes [(#17278)](https://github.com/ManageIQ/manageiq/pull/17278)
- Resolve string handling for "https://" or "http://" in update_rhsm_conf [(#17222)](https://github.com/ManageIQ/manageiq/pull/17222)
- Use handled_list to get Cinder backups for all accessible tenants [(#17157)](https://github.com/ManageIQ/manageiq/pull/17157)
- Scope the default zone to the current region [(#17103)](https://github.com/ManageIQ/manageiq/pull/17103)
- Force UTF-8 encoding on task results [(#17252)](https://github.com/ManageIQ/manageiq/pull/17252)
- Handle non-existant tag category id when importing a service dialog [(#17237)](https://github.com/ManageIQ/manageiq/pull/17237)
- Forcing default_value to an array, if the dynamic dropdown is multiselect [(#17272)](https://github.com/ManageIQ/manageiq/pull/17272)
- Use credential callback to set credentials [(#14889)](https://github.com/ManageIQ/manageiq/pull/14889)
- Filter out archived and orphaned VMs in 'Running VMs' filter [(#17183)](https://github.com/ManageIQ/manageiq/pull/17183)
- Do not show archived and orphaned VMs on report 'Online VMs (Powered On)' [(#17178)](https://github.com/ManageIQ/manageiq/pull/17178)
- Fix filename when downloading pdf from Flavor summary [(#16944)](https://github.com/ManageIQ/manageiq/pull/16944)
- Check for the existence of credentials. [(#17313)](https://github.com/ManageIQ/manageiq/pull/17313)
- Dialog field loading/refresh refactor to fix automate delays [(#17329)](https://github.com/ManageIQ/manageiq/pull/17329)
- Change dialog import to only use auto_refresh if new triggers are blank [(#17363)](https://github.com/ManageIQ/manageiq/pull/17363)
- Do not change current_group for super admin user when executing Rbac#lookup_user_group [(#17347)](https://github.com/ManageIQ/manageiq/pull/17347)

## Gaprindashvili-2 released 2018-03-06

### Added
- Refactor VM naming method in provisioning task to support call from automate [(#16897)](https://github.com/ManageIQ/manageiq/pull/16897)

### Fixed
- Add back the missing IP address range in Virtual Private Cloud name. [(#16898)](https://github.com/ManageIQ/manageiq/pull/16898)
- Fix Deleting Snapshot on Smartstate Cancel [(#16885)](https://github.com/ManageIQ/manageiq/pull/16885)
- Fix supports_launch_vnc_console? for VMWare VMs [(#16905)](https://github.com/ManageIQ/manageiq/pull/16905)
- Add << method to MulticastLogger [(#16904)](https://github.com/ManageIQ/manageiq/pull/16904)
- Exclude Service::AGGREGATE_ALL_VM_ATTRS from MiqExp.to_sql [(#16915)](https://github.com/ManageIQ/manageiq/pull/16915)
- No longer assume that a value is an array [(#16924)](https://github.com/ManageIQ/manageiq/pull/16924)
- Follow up to update_vm_name for Service template provisioning [(#16949)](https://github.com/ManageIQ/manageiq/pull/16949)
- Add nil check to serializer for invalid categories [(#16951)](https://github.com/ManageIQ/manageiq/pull/16951)
- Make sure Containers Exist Before Processing [(#16922)](https://github.com/ManageIQ/manageiq/pull/16922)
- Fix for differing behavior in DialogFieldTagControl multi/single drop downs [(#16955)](https://github.com/ManageIQ/manageiq/pull/16955)
- Dropping azure classic and rackspace credential types [(#16936)](https://github.com/ManageIQ/manageiq/pull/16936)
- Only set encryption option to net-ldap when needed. [(#16954)](https://github.com/ManageIQ/manageiq/pull/16954)
- Use correct comparison for multi-value default value inclusion rules [(#16978)](https://github.com/ManageIQ/manageiq/pull/16978)
- Checking killed worker with is_alive? [(#16908)](https://github.com/ManageIQ/manageiq/pull/16908)
- Lookup a category_id if a tag control passes it in [(#16965)](https://github.com/ManageIQ/manageiq/pull/16965)
- Fix MulticastLogger DEBUG mode [(#16990)](https://github.com/ManageIQ/manageiq/pull/16990)

## Unreleased as of Sprint 80 ending 2018-02-26

### Added
- Stop container workers cleanly [(#17042)](https://github.com/ManageIQ/manageiq/pull/17042)
- Differentiate being in a container vs running in OpenShift/k8s [(#17028)](https://github.com/ManageIQ/manageiq/pull/17028)
- Add the artemis auth info as env variables in worker containers [(#17025)](https://github.com/ManageIQ/manageiq/pull/17025)
- Use arel to build local_db multiselect condition [(#17012)](https://github.com/ManageIQ/manageiq/pull/17012)
- Add sui_product_features method to miq_group [(#17007)](https://github.com/ManageIQ/manageiq/pull/17007)
- Add miq_product_features to miq_group [(#17003)](https://github.com/ManageIQ/manageiq/pull/17003)
- Rename new guest device pages [(#16996)](https://github.com/ManageIQ/manageiq/pull/16996)
- Two small fixes to tools/miqssh [(#16986)](https://github.com/ManageIQ/manageiq/pull/16986)
- Get targeted arel query automatically [(#16981)](https://github.com/ManageIQ/manageiq/pull/16981)
- Inventory task [(#16980)](https://github.com/ManageIQ/manageiq/pull/16980)
- Fix reason scope for MiqRequest [(#16950)](https://github.com/ManageIQ/manageiq/pull/16950)
- Graph refresh skeletal precreate [(#16882)](https://github.com/ManageIQ/manageiq/pull/16882)
- [REARCH] Container workers [(#15884)](https://github.com/ManageIQ/manageiq/pull/15884)

### Fixed
- Fix build methods [(#17032)](https://github.com/ManageIQ/manageiq/pull/17032)
- Fix alerts based on hourly timer for container entities [(#16902)](https://github.com/ManageIQ/manageiq/pull/16902)
- Singularize plural model [(#16833)](https://github.com/ManageIQ/manageiq/pull/16833)

## Gaprindashvili-1 - Released 2018-01-31

### Added
- Alerts
  - Seed MiqAlerts used for Prometheus Alerts [(#16479)](https://github.com/ManageIQ/manageiq/pull/16479)
  - Add severity to alert definitions [(#16040)](https://github.com/ManageIQ/manageiq/pull/16040)
  - Add hash_expression to MiqAlert [(#15315)](https://github.com/ManageIQ/manageiq/pull/15315)
- Ansible
  - Procfile.example - add workers needed for embedded ansible [(#16679)](https://github.com/ManageIQ/manageiq/pull/16679)
  - Add log_output option for embedded ansible service [(#16414)](https://github.com/ManageIQ/manageiq/pull/16414)
- Authentication
  - Added support for httpd auth-api service for containers. [(#15881)](https://github.com/ManageIQ/manageiq/pull/15881)
- Automate
  - Add quota mixin for vm_reconfigure_request and vm_migrate_request [(#16626)](https://github.com/ManageIQ/manageiq/pull/16626)
  - Add #raw_stdout_via_worker method [(#16441)](https://github.com/ManageIQ/manageiq/pull/16441)
  - Imports old associations [(#16471)](https://github.com/ManageIQ/manageiq/pull/16471)
  - Add the `picture` association to Generic Objects via `generic_object_definition` [(#16006)](https://github.com/ManageIQ/manageiq/pull/16006)
  - Generic object add to service. [(#16000)](https://github.com/ManageIQ/manageiq/pull/16000)
  - Rename the key from workspace to objects [(#15977)](https://github.com/ManageIQ/manageiq/pull/15977)
  - Added 'playbook' as location type for Automate Methods [(#15939)](https://github.com/ManageIQ/manageiq/pull/15939)
  - Added AutomateWorkspace model [(#15817)](https://github.com/ManageIQ/manageiq/pull/15817)
  - Add new classes to have custom buttons [(#15845)](https://github.com/ManageIQ/manageiq/pull/15845)
  - Added support for expression methods [(#15537)](https://github.com/ManageIQ/manageiq/pull/15537)
  - Provisioning: Support memory limit for RHV [(#15591)](https://github.com/ManageIQ/manageiq/pull/15591)
  - Add a relationship between generic objects and services. [(#15490)](https://github.com/ManageIQ/manageiq/pull/15490)
  - Display the text "Generic Object Class" in the UI (instead of Generic Object Definition) [(#15672)](https://github.com/ManageIQ/manageiq/pull/15672)
  - Set up dialog_field relationships through DialogFieldAssociations [(#15566)](https://github.com/ManageIQ/manageiq/pull/15566)
  - Metric rollups at the Service level [(#15695)](https://github.com/ManageIQ/manageiq/pull/15695)
  - Remove methods for Azure sample orchestration [(#15752)](https://github.com/ManageIQ/manageiq/pull/15752)
  - Provisioning: Add validate_blacklist method for VM pre-provisioning [(#15513)](https://github.com/ManageIQ/manageiq/pull/15513)
  - Support array of objects for custom button support [(#14930)](https://github.com/ManageIQ/manageiq/pull/14930)
  - Add configuration_script reference to service [(#14232)](https://github.com/ManageIQ/manageiq/pull/14232)
  - Add ServiceTemplateContainerTemplate. [(#15356)](https://github.com/ManageIQ/manageiq/pull/15356)
  - Add project option to container template service dialog. [(#15340)](https://github.com/ManageIQ/manageiq/pull/15340)
  - Provisioning: Ovirt-networking: using profiles [(#14991)](https://github.com/ManageIQ/manageiq/pull/14991)
  - Add delete method for Cloud Subnet [(#15087)](https://github.com/ManageIQ/manageiq/pull/15087)
  - Extract automation engine to separate repository [(#13783)](https://github.com/ManageIQ/manageiq/pull/13783)
  - Modified destroying an Ansible Service Template [(#14586)](https://github.com/ManageIQ/manageiq/pull/14586)
  - Ansible Playbook Service add on_error method. [(#14583)](https://github.com/ManageIQ/manageiq/pull/14583)
- Chargeback
  - Add Metering Used Hours to chargeback report [(#15908)](https://github.com/ManageIQ/manageiq/pull/15908)
- Core
  - Add method for Vm to get 'My Company' tags [(#16607)](https://github.com/ManageIQ/manageiq/pull/16607)
  - Remove the column reordering tool and the schema structure validations [(#16488)](https://github.com/ManageIQ/manageiq/pull/16488)
  - Added Product name to VMDB::Appliance [(#16409)](https://github.com/ManageIQ/manageiq/pull/16409)
  - Added User Agent to VMDB::Appliance [(#16410)](https://github.com/ManageIQ/manageiq/pull/16410)
  - Add PostgreSQL version restriction [(#16171)](https://github.com/ManageIQ/manageiq/pull/16171)
  - Print file name on any error from RipperRubyParser not just SyntaxError [(#16112)](https://github.com/ManageIQ/manageiq/pull/16112)
  - Added user_id group_id tenant_id [(#16089)](https://github.com/ManageIQ/manageiq/pull/16089)
  - Enhance the the orchestrator to deal with more objects [(#15962)](https://github.com/ManageIQ/manageiq/pull/15962)
  - Add event streams product features [(#16021)](https://github.com/ManageIQ/manageiq/pull/16021)
  - Use the built-in OpenShift service environment variables [(#16001)](https://github.com/ManageIQ/manageiq/pull/16001)
  - Adding Child Managers to EMS [(#15889)](https://github.com/ManageIQ/manageiq/pull/15889)
  - Add status and state scopes, fix time for MiqTask list [(#16365)](https://github.com/ManageIQ/manageiq/pull/16365)
- Events
  - Add target to event existence check [(#15719)](https://github.com/ManageIQ/manageiq/pull/15719)
- i18n
  - Add product/compare/.yaml to string extraction [(#16691)](https://github.com/ManageIQ/manageiq/pull/16691)
  - Add Data Types to dictionary [(#15922)](https://github.com/ManageIQ/manageiq/pull/15922)
  - Add missing Cloud Volume model names [(#16689)](https://github.com/ManageIQ/manageiq/pull/16689)
- Middleware
  - Enable compliance check for MW server [(#16375)](https://github.com/ManageIQ/manageiq/pull/16375)
  - Middleware compliance assignment [(#16376)](https://github.com/ManageIQ/manageiq/pull/16376)
- Performance
  - Optimize speed and stabilize the batch graph refresh memory usage [(#15897)](https://github.com/ManageIQ/manageiq/pull/15897)
- Platform
  - Don't use secure sessions in containers [(#15819)](https://github.com/ManageIQ/manageiq/pull/15819)
  - Add MiqExpression support for managed filters [(#15623)](https://github.com/ManageIQ/manageiq/pull/15623)
  - Use memcached for sending messages to workers [(#15471)](https://github.com/ManageIQ/manageiq/pull/15471)
  - Evaluate enablement expressions for custom buttons [(#15729)](https://github.com/ManageIQ/manageiq/pull/15729)
  - Evaluate visibility expressions for CustomButtons [(#15725)](https://github.com/ManageIQ/manageiq/pull/15725)
  - Include EvmRole-reader as read-only role in the fixtures [(#15647)](https://github.com/ManageIQ/manageiq/pull/15647)
  - Add HostAggregates to RBAC [(#15417)](https://github.com/ManageIQ/manageiq/pull/15417)
  - Adding options field to ext_management_system [(#15398)](https://github.com/ManageIQ/manageiq/pull/15398)
  - Change the target of tag expressions [(#15715)](https://github.com/ManageIQ/manageiq/pull/15715)
  - MiqExpression::Target#to_s [(#15713)](https://github.com/ManageIQ/manageiq/pull/15713)
  - Rename applies_to_exp to visibility_expression for serializing [(#15501)](https://github.com/ManageIQ/manageiq/pull/15501)
  - Add server MB usage to rake evm:status and status_full. [(#15457)](https://github.com/ManageIQ/manageiq/pull/15457)
  - Chargeback: Add average calculation for allocated costs and metrics optionally in chargeback [(#15565)](https://github.com/ManageIQ/manageiq/pull/15565)
  - Workers: Add heartbeat_check script for file-based worker process heartbeating [(#15494)](https://github.com/ManageIQ/manageiq/pull/15494)
  - Make namespace into a virtual attribute [(#15532)](https://github.com/ManageIQ/manageiq/pull/15532)
  - Use OpenShift API to control the Ansible container [(#15492)](https://github.com/ManageIQ/manageiq/pull/15492)
  - Allow MiqWorker.required_roles to be a lambda [(#15522)](https://github.com/ManageIQ/manageiq/pull/15522)
  - MulticastLogger#reopen shouldn't be used because it's backed by other loggers [(#15512)](https://github.com/ManageIQ/manageiq/pull/15512)
  - Add the evm:deployment_status rake task [(#15402)](https://github.com/ManageIQ/manageiq/pull/15402)
  - Set default server roles from env [(#15470)](https://github.com/ManageIQ/manageiq/pull/15470)
  - Logging to STDOUT in JSON format for containers [(#15392)](https://github.com/ManageIQ/manageiq/pull/15392)
  - Allow overriding memcache server setting by environment variable [(#15326)](https://github.com/ManageIQ/manageiq/pull/15326)
  - Reporting: Add Amazon report to standard set of reports [(#15445)](https://github.com/ManageIQ/manageiq/pull/15445)
  - Changed task_id to tracking_label [(#15443)](https://github.com/ManageIQ/manageiq/pull/15443)
  - Add MiqQueue#tracking_label [(#15224)](https://github.com/ManageIQ/manageiq/pull/15224)
  - Support  worker heartbeat to a local file instead of Drb. [(#15377)](https://github.com/ManageIQ/manageiq/pull/15377)
  - Use the Ansible service in containers rather than starting it locally [(#15423)](https://github.com/ManageIQ/manageiq/pull/15423)
  - Default to spawn automatically if fork isn't supported [(#15425)](https://github.com/ManageIQ/manageiq/pull/15425)
  - Rails scripts for setting a server's zone and configuration settings from a command line [(#11204)](https://github.com/ManageIQ/manageiq/pull/11204)
  - Add rake script to export/import miq alerts and alert profiles [(#14126)](https://github.com/ManageIQ/manageiq/pull/14126)
  - Adds MiqHelper [(#15020)](https://github.com/ManageIQ/manageiq/pull/15020)
  - Move ResourceGroup relationship into VmOrTemplate model [(#14948)](https://github.com/ManageIQ/manageiq/pull/14948)
  - Report attributes for SUI [(#14829)](https://github.com/ManageIQ/manageiq/pull/14829)
- Providers
  - Introduce $vcloud_log that logs into log/vcloud.log [(#16641)](https://github.com/ManageIQ/manageiq/pull/16641)
  - Changing the key of network device to be both ipv4 + ipv6 [(#16619)](https://github.com/ManageIQ/manageiq/pull/16619)
  - Added "Mass Transform" feature [(#16686)](https://github.com/ManageIQ/manageiq/pull/16686)
  - Add ContainerQuotaScope model, save them in save_inventory [(#16555)](https://github.com/ManageIQ/manageiq/pull/16655)
  - Add tag categories for VM migration [(#16402)](https://github.com/ManageIQ/manageiq/pull/16402)
  - Add requests and limits to Persistent Volume Claim [(#16026)](https://github.com/ManageIQ/manageiq/pull/16026)
  - Add ems_infra_admin_ui feature [(#16403)](https://github.com/ManageIQ/manageiq/pull/16403)
  - Update ems_infra_admin_ui feature to role assignment [(#16484)](https://github.com/ManageIQ/manageiq/pull/16484)
  - Move graph refresh internals logging to debug [(#16442)](https://github.com/ManageIQ/manageiq/pull/16442)
  - Save the Lan parent_id for SCVMM [(#16165)](https://github.com/ManageIQ/manageiq/pull/16165)
  - Directly run a playbook [(#16161)](https://github.com/ManageIQ/manageiq/pull/16161)
  - Adding default filters configuration to physical servers [(#16158)](https://github.com/ManageIQ/manageiq/pull/16158)
  - Add a Subnet model for SCVMM [(#16153)](https://github.com/ManageIQ/manageiq/pull/16153)
  - Extend InventoryCollectionDefault::NetworkManager with network_groups [(#16136)](https://github.com/ManageIQ/manageiq/pull/16136)
  - Enable alerts definitions for transactions and messaging for Middleware Server [(#16133)](https://github.com/ManageIQ/manageiq/pull/16133)
  - Allow a 'type' setter on MiddlewareServer [(#16126)](https://github.com/ManageIQ/manageiq/pull/16126)
  - Enable alerts definitions with datasource for Middleware Server [(#16125)](https://github.com/ManageIQ/manageiq/pull/16125)
  - Enable alerts definitions using web sessions [(#16113)](https://github.com/ManageIQ/manageiq/pull/16113)
  - Add policy buttons to physical server page [(#16110)](https://github.com/ManageIQ/manageiq/pull/16110) 
  - Add ems_ref to filter duplicate events [(#16104)](https://github.com/ManageIQ/manageiq/pull/16104)
  - Group by docker label in chargeback for container images [(#16097)](https://github.com/ManageIQ/manageiq/pull/16097)
  - Add physical server to constant support policy [(#16085)](https://github.com/ManageIQ/manageiq/pull/16085)
  - Adds support for physical server timeline [(#16084)](https://github.com/ManageIQ/manageiq/pull/16084)
  - Add Service resource linking. [(#16082)](https://github.com/ManageIQ/manageiq/pull/16082)
  - Always check for userid as UPN [(#16069)](https://github.com/ManageIQ/manageiq/pull/16069)
  - Fixing middleware servers alert handling [(#16048)](https://github.com/ManageIQ/manageiq/pull/16048)
  - Update model to use the customization_scripts table for LXCA config patterns [(#16036)](https://github.com/ManageIQ/manageiq/pull/16036)
  - Parse the serial number during refresh [(#15992)](https://github.com/ManageIQ/manageiq/pull/15992)
  - ovn: introducing ovn as ovirt's network provider [(#15929)](https://github.com/ManageIQ/manageiq/pull/15929)
  - Add Report: Projects by Quota Items [(#15776)](https://github.com/ManageIQ/manageiq/pull/15776)
  - Use more descriptive name for seal template [(#16045)](https://github.com/ManageIQ/manageiq/pull/16045)
  - Enhance NetworkRouter model for Amazon [(#16030)](https://github.com/ManageIQ/manageiq/pull/16030)
  - Metrics Worker capture_timer more ems centric [(#16004)](https://github.com/ManageIQ/manageiq/pull/16004)
  - Support publish Vm by RHV [(#15981)](https://github.com/ManageIQ/manageiq/pull/15981)
  - Improve metrics saving [(#15976)](https://github.com/ManageIQ/manageiq/pull/15976)
  - Add OpenSCAP scan to supported features mixin [(#15944)](https://github.com/ManageIQ/manageiq/pull/15944)
  - Queue targeted refresh in a provisioning workflow [(#15933)](https://github.com/ManageIQ/manageiq/pull/15933)
  - Convert Container quotas to numeric values [(#15639)](https://github.com/ManageIQ/manageiq/pull/15639)
  - Update model to support LXCA config patterns [(#15956)](https://github.com/ManageIQ/manageiq/pull/15956)
  - Add orchestration stack targeted refresh method [(#15936)](https://github.com/ManageIQ/manageiq/pull/15936)
  - Add relation between container projects and persistent volume claims [(#15932)](https://github.com/ManageIQ/manageiq/pull/15932)
  - Apply distinct on lans and switches [(#15930)](https://github.com/ManageIQ/manageiq/pull/15930)
  - Add instance security group management to product features [(#15915)](https://github.com/ManageIQ/manageiq/pull/15915)
  - raw_connect method for infra provider  [(#15914)](https://github.com/ManageIQ/manageiq/pull/15914)
  - Add Ansible Playbook custom button type [(#15874)](https://github.com/ManageIQ/manageiq/pull/15874)
  - Add Openscap Result to VM model [(#15862)](https://github.com/ManageIQ/manageiq/pull/15862)
  - Flavors create and add methods [(#15552)](https://github.com/ManageIQ/manageiq/pull/15552)
  - Container Template: Add object_labels [(#15406)](https://github.com/ManageIQ/manageiq/pull/15406)
  - Add cloud volume backup delete and restore actions. [(#15891)](https://github.com/ManageIQ/manageiq/pull/15891)
  - Add instantiation_attributes to Container Template Parameter [(#15863)](https://github.com/ManageIQ/manageiq/pull/15863)
  - Add vm security group operations [(#15826)](https://github.com/ManageIQ/manageiq/pull/15826)
  - Add metadata function that should return the description of the data that is stored in the options field [(#15799)](https://github.com/ManageIQ/manageiq/pull/15799)
  - Register product features for JDR reports [(#15768)](https://github.com/ManageIQ/manageiq/pull/15768)
  - Add number of container using image [(#15741)](https://github.com/ManageIQ/manageiq/pull/15741)
  - Add support for additional power operations [(#15683)](https://github.com/ManageIQ/manageiq/pull/15683)
  - Update model to support network adapters [(#15371)](https://github.com/ManageIQ/manageiq/pull/15371)
  - Archive Container Nodes [(#15351)](https://github.com/ManageIQ/manageiq/pull/15351)
  - Add Pod to PersistentVolume relationship [(#15023)](https://github.com/ManageIQ/manageiq/pull/15023)
  - Missing settings for a cloud batch saving and adding shared_options [(#15792)](https://github.com/ManageIQ/manageiq/pull/15792)
  - Needed config for Cloud batch saver_strategy [(#15708)](https://github.com/ManageIQ/manageiq/pull/15708)
  - Remove the Eventcatcher from CinderManager [(#14962)](https://github.com/ManageIQ/manageiq/pull/14962)
  - Add a virtual column for `supports_block_storage?` and `supports_cloud_object_store_container_create?` [(#15600)](https://github.com/ManageIQ/manageiq/pull/15600)
  - Add product features for provider disable UI [(#15592)](https://github.com/ManageIQ/manageiq/pull/15592)
  - Raise creation event batched job [(#15679)](https://github.com/ManageIQ/manageiq/pull/15679)
  - Allow to run post processing job for ManagerRefresh (Graph Refresh) [(#15678)](https://github.com/ManageIQ/manageiq/pull/15678)
  - Batch saving strategy that does not require unique indexes [(#15627)](https://github.com/ManageIQ/manageiq/pull/15627)
  - Make sure passed ids for habtm relation are unique [(#15651)](https://github.com/ManageIQ/manageiq/pull/15651)
  - Sort nodes for a proper disconnect_inv/destroy order [(#15636)](https://github.com/ManageIQ/manageiq/pull/15636)
  - Middleware: Register product feature for stopping domains [(#15680)](https://github.com/ManageIQ/manageiq/pull/15680)
  - Add physical infra discovery to product features [(#15607)](https://github.com/ManageIQ/manageiq/pull/15607)
  - Adds virtual totals for servers vms and hosts to Physical Infrastructure Providers [(#15613)](https://github.com/ManageIQ/manageiq/pull/15613)
  - Change name of physical infra type in discovery [(#15681)](https://github.com/ManageIQ/manageiq/pull/15681)
  - Adapt manageiq to new managers [(#15506)](https://github.com/ManageIQ/manageiq/pull/15506)
  - Ansible Tower: Azure Classic Credential added for embedded Ansible [(#15626)](https://github.com/ManageIQ/manageiq/pull/15626)
  - Containers: Add new class ServiceContainerTemplate. [(#15429)](https://github.com/ManageIQ/manageiq/pull/15429)
  - Custom reconnect block [(#15605)](https://github.com/ManageIQ/manageiq/pull/15605)
  - Deal with special AR setters [(#15439)](https://github.com/ManageIQ/manageiq/pull/15439)
  - Store created updated and deleted records [(#15603)](https://github.com/ManageIQ/manageiq/pull/15603)
  - Use proper multi select condition [(#15436)](https://github.com/ManageIQ/manageiq/pull/15436)
  - Network: Generic CRUD for network routers [(#15451)](https://github.com/ManageIQ/manageiq/pull/15451)
  - Physical Infrastructure: Add physical infra types for discovery [(#15621)](https://github.com/ManageIQ/manageiq/pull/15621)
  - Add monitoring manager [(#15354)](https://github.com/ManageIQ/manageiq/pull/15354)
  - Adding sti mixin to container_image base class [(#15505)](https://github.com/ManageIQ/manageiq/pull/15505)
  - Container Template: Add :miq_class for each object [(#15475)](https://github.com/ManageIQ/manageiq/pull/15475)
  - Adding ContainerImage subclasses [(#15386)](https://github.com/ManageIQ/manageiq/pull/15386)
  - Change the criteria for a required field of ContainerTemplateServiceDialog. [(#15469)](https://github.com/ManageIQ/manageiq/pull/15469)
  - Support find and lazy_find by other fields than manager_ref [(#15447)](https://github.com/ManageIQ/manageiq/pull/15447)
  - Add MiqTemplate to InfraManager InventoryCollection [(#15400)](https://github.com/ManageIQ/manageiq/pull/15400)
  - Optimize insert query loading [(#15404)](https://github.com/ManageIQ/manageiq/pull/15404)
  - Batch saving strategy should populate the right timestamps [(#15394)](https://github.com/ManageIQ/manageiq/pull/15394)
  - Add power off/on events to automate control and the foreign key to events physical server [(#15138)](https://github.com/ManageIQ/manageiq/pull/15138)
  - Search for "product/views" in all plugins [(#15353)](https://github.com/ManageIQ/manageiq/pull/15353)
  - Save resource group information [(#15187)](https://github.com/ManageIQ/manageiq/pull/15187)
  - Add new class Dialog::ContainerTemplateServiceDialog. [(#15216)](https://github.com/ManageIQ/manageiq/pull/15216)
  - Concurent safe batch saver [(#15247)](https://github.com/ManageIQ/manageiq/pull/15247)
  - Removed SCVMM Data as moved to manageiq-providers-scvmm [(#15314)](https://github.com/ManageIQ/manageiq/pull/15314)
  - Middleware: Validate presence of feed on middleware servers [(#15390)](https://github.com/ManageIQ/manageiq/pull/15390)
  - Add important asserts to the default save inventory [(#15197)](https://github.com/ManageIQ/manageiq/pull/15197)
  - Delete complement strategy for deleting top level entities using batches [(#15229)](https://github.com/ManageIQ/manageiq/pull/15229)
  - First version of targeted concurrent safe Persistor strategy [(#15227)](https://github.com/ManageIQ/manageiq/pull/15227)
  - Generalize targeted inventory collection saving [(#15198)](https://github.com/ManageIQ/manageiq/pull/15198)
  - Containers: Add Report: Images by Failed Openscap Rule Results [(#15210)](https://github.com/ManageIQ/manageiq/pull/15210)
  - Physical Infrastructure: Add constraint to vendor in Physical Server [(#15128)](https://github.com/ManageIQ/manageiq/pull/15128)
  - Adding helper for unique index columns to inventory collection [(#15141)](https://github.com/ManageIQ/manageiq/pull/15141)
  - Minor inventory collection enhancements [(#15108)](https://github.com/ManageIQ/manageiq/pull/15108)
  - Physical Infrastructure: Method to save asset details  [(#14827)](https://github.com/ManageIQ/manageiq/pull/14827)
  - Blacklisted event names in settings.yml [(#14647)](https://github.com/ManageIQ/manageiq/pull/14647)
  - Allow Vmdb::Plugins to work through code reloads in development. [(#15057)](https://github.com/ManageIQ/manageiq/pull/15057)
  - Provider native operations state machine [(#14405)](https://github.com/ManageIQ/manageiq/pull/14405)
  - Escalate privilege [(#14929)](https://github.com/ManageIQ/manageiq/pull/14929)
  - Physical Infrastructure: Create asset details object [(#14749)](https://github.com/ManageIQ/manageiq/pull/14749)
  - Pluggable Providers: allow seeding of dialogs from plugins [(#14668)](https://github.com/ManageIQ/manageiq/pull/14668)
  - Add features to physical servers pages [(#14709)](https://github.com/ManageIQ/manageiq/pull/14709)
  - Adds physical_server methods to be used by miq-ui [(#14552)](https://github.com/ManageIQ/manageiq/pull/14552)
  - Link MiqTemplates to their parent VM when one is present [(#14755)](https://github.com/ManageIQ/manageiq/pull/14755)
  - Ansible: Refresh job_template -> playbook connection [(#14432)](https://github.com/ManageIQ/manageiq/pull/14432)
  - Middleware: Cross-linking Middleware server model with containers. [(#14043)](https://github.com/ManageIQ/manageiq/pull/14043)
  - Openstack: Notify when an Openstack VM has been relocated [(#14604)](https://github.com/ManageIQ/manageiq/pull/14604)
  - Physical Infra: Add Topology feature [(#14589)](https://github.com/ManageIQ/manageiq/pull/14589)
  - Refresh Physical Servers [(#16344)](https://github.com/ManageIQ/manageiq/pull/16344)
  - Additions for Amazon tag mapping in graph refresh [(#16734)](https://github.com/ManageIQ/manageiq/pull/16734)
  - Reconnect host on provider add [(#16767)](https://github.com/ManageIQ/manageiq/pull/16767)
- Provisioning
  - Change get_targets_for_source to use correct params [(#16811)](https://github.com/ManageIQ/manageiq/pull/16811)
  - VMware placement to support only Clusters or only Folders. [(#15951)](https://github.com/ManageIQ/manageiq/pull/15951)
- RBAC
  - Added SUI notifications product feature [(#16107)](https://github.com/ManageIQ/manageiq/pull/16107)
- Reporting
  - Add scope :without_configuration_profile_id needed by Foreman explorer UI [(#16439)](https://github.com/ManageIQ/manageiq/pull/16439)
  - Limit Generic Object associations to the same list of objects available to reporting. [(#15735)](https://github.com/ManageIQ/manageiq/pull/15735)
- REST API
  - Set current user for generic object methods [(#16120)](https://github.com/ManageIQ/manageiq/pull/16120)
  - Add metrics default limit to API settings [(#15797)](https://github.com/ManageIQ/manageiq/pull/15797)
  - Add paging links to the API [(#15148)](https://github.com/ManageIQ/manageiq/pull/15148)
  - Render links with compressed ids [(#15659)](https://github.com/ManageIQ/manageiq/pull/15659)
  - Query by multiple tags [(#15557)](https://github.com/ManageIQ/manageiq/pull/15557)
  - Floating IPs: Initial API [(#15524)](https://github.com/ManageIQ/manageiq/pull/15524)
  - Network Routers REST API [(#15450)](https://github.com/ManageIQ/manageiq/pull/15450)
  - Render ids in compressed form in API responses [(#15430)](https://github.com/ManageIQ/manageiq/pull/15430)
  - Return BadRequestError when invalid attributes are specified [(#15040)](https://github.com/ManageIQ/manageiq/pull/15040)
  - Return href on create [(#15005)](https://github.com/ManageIQ/manageiq/pull/15005)
  - Remove miq_server [(#15284)](https://github.com/ManageIQ/manageiq/pull/15284)
  - Add cloud subnet REST API [(#15248)](https://github.com/ManageIQ/manageiq/pull/15248)
  - Set_miq_server Action [(#15262)](https://github.com/ManageIQ/manageiq/pull/15262)
  - Add support for Cloud Volume Delete action [(#15097)](https://github.com/ManageIQ/manageiq/pull/15097)
  - Add Alert Definition Profiles (MiqAlertSet) REST API support [(#14438)](https://github.com/ManageIQ/manageiq/pull/14438)
  - API support for adding/removing Policies to/from Policy Profiles [(#14575)](https://github.com/ManageIQ/manageiq/pull/14575)
  - Refresh Configuration Script Sources action [(#14714)](https://github.com/ManageIQ/manageiq/pull/14714)
  - Authentications refresh action [(#14717)](https://github.com/ManageIQ/manageiq/pull/14717)
  - Updated providers refresh to return all tasks for multi-manager providers [(#14747)](https://github.com/ManageIQ/manageiq/pull/14747)
  - Added new firmware collection api [(#14476)](https://github.com/ManageIQ/manageiq/pull/14476)
  - Edit VMs API [(#14623)](https://github.com/ManageIQ/manageiq/pull/14623)
  - Remove all service resources [(#14584)](https://github.com/ManageIQ/manageiq/pull/14584)
  - Remove resources from service [(#14581)](https://github.com/ManageIQ/manageiq/pull/14581)
  - Bumping up version to 2.4.0 for the Fine Release [(#14541)](https://github.com/ManageIQ/manageiq/pull/14541)
  - Bumping up API Versioning to 2.5.0-pre for the G-Release [(#14544)](https://github.com/ManageIQ/manageiq/pull/14544)
  - Exposing prototype as part of /api/settings [(#14690)](https://github.com/ManageIQ/manageiq/pull/14690)
- Service UI
  - Add SUI product features [(#16068)](https://github.com/ManageIQ/manageiq/pull/16068)
  - Service dialog generation rely only on OrchestrationParameterConstraint [(#16047)](https://github.com/ManageIQ/manageiq/pull/16047)
- Services
  - Add manageiq_connection as an extra_var key sent through services [(#16668)](https://github.com/ManageIQ/manageiq/pull/16668)
  - Name service during provisioning from dialog input [(#16338)](https://github.com/ManageIQ/manageiq/pull/16338)
  - Adds dialog field association info to importer [(#15740)](https://github.com/ManageIQ/manageiq/pull/15740)
  - Removes importer association data for backwards compatibility [(#15724)](https://github.com/ManageIQ/manageiq/pull/15724)
  - Exports new DialogFieldAssociations data [(#15608)](https://github.com/ManageIQ/manageiq/pull/15608)
- Smart State
  - Snapshot Support for Non-Managed Disks SSA [(#15960)](https://github.com/ManageIQ/manageiq/pull/15960)
  - Create Snapshot for Azure if a snapshot is required for SSA and if so call the snapshot code.[(#15865)](https://github.com/ManageIQ/manageiq/pull/15865)
  - Fix sometimes host analysis cannot get the linux packages info [(#15140)](https://github.com/ManageIQ/manageiq/pull/15140)
- Storage
  - Add missing features for Block Storage and Object Storage [(#15812)](https://github.com/ManageIQ/manageiq/pull/15812)
- Tools
  - Make tools easier to run [(#15957)](https://github.com/ManageIQ/manageiq/pull/15957)
- User Interface
  - Allow the target attribute to be read on ResourceActionWorkflow objects [(#15916)](https://github.com/ManageIQ/manageiq/pull/15916)
  - Add new classes to BUTTON_CLASSES [(#16181)](https://github.com/ManageIQ/manageiq/pull/16181)
  - Override the href_slug method to use GUID instead of id [(#16129)](https://github.com/ManageIQ/manageiq/pull/16129)
  - Add dialog field description to list of values updatable by automate [(#16011)](https://github.com/ManageIQ/manageiq/pull/16011)
  - Add virtual columns for GenericObject and GenericObjectDefinition [(#16007)](https://github.com/ManageIQ/manageiq/pull/16007)
  - Expose Custom Button visability/enablement [(#15911)](https://github.com/ManageIQ/manageiq/pull/15911)
  - Add custom buttons to generic object. [(#15980)](https://github.com/ManageIQ/manageiq/pull/15980)
  - Show monitoring screen by default [(#14976)](https://github.com/ManageIQ/manageiq/pull/14976)
  - Features for Generic Object Classes and Instances [(#15611)](https://github.com/ManageIQ/manageiq/pull/15611)
  - Add entries for Physical Server [(#15275)](https://github.com/ManageIQ/manageiq/pull/15275)
  - Add pretty model name for physical server [(#15283)](https://github.com/ManageIQ/manageiq/pull/15283)

### Changed
- Automate
  - Provisioning: First and Last name are no longer required. [(#14694)](https://github.com/ManageIQ/manageiq/pull/14694)
  - Add policy checking for request_host_scan. [(#14427)](https://github.com/ManageIQ/manageiq/pull/14427)
  - Enforce policies type to be either "compliance" or "control" [(#14519)](https://github.com/ManageIQ/manageiq/pull/14519)
  - Add policy checking for retirement request. [(#14641)](https://github.com/ManageIQ/manageiq/pull/14641)
- Performance
  - Ultimate batch saving speedup [(#15761)](https://github.com/ManageIQ/manageiq/pull/15761)
  - Memoize Metric::Capture.capture_cols [(#15791)](https://github.com/ManageIQ/manageiq/pull/15791)
  - Don't run the broker for ems_inventory if update_driven_refresh is set [(#15579)](https://github.com/ManageIQ/manageiq/pull/15579)
  - Merge retirement checks [(#15645)](https://github.com/ManageIQ/manageiq/pull/15645)
  - Batch disconnect method for ContainerImage [(#15698)](https://github.com/ManageIQ/manageiq/pull/15698)
  - Allow batch disconnect for the batch strategy [(#15699)](https://github.com/ManageIQ/manageiq/pull/15699)
  - Optimize the query of a service's orchestration_stacks. [(#15727)](https://github.com/ManageIQ/manageiq/pull/15727)
  - MiqGroup.seed [(#15586)](https://github.com/ManageIQ/manageiq/pull/15586)
  - Use concat for better performance [(#15635)](https://github.com/ManageIQ/manageiq/pull/15635)
  - Do not queue C&U for things that aren't supported [(#15195)](https://github.com/ManageIQ/manageiq/pull/15195)
  - Add memory usage to worker status in rake evm:status and status_full [(#15375)](https://github.com/ManageIQ/manageiq/pull/15375)
  - Inventory collection default for infra manager [(#15082)](https://github.com/ManageIQ/manageiq/pull/15082)
  - Cache node_types instead of calling on every request [(#14922)](https://github.com/ManageIQ/manageiq/pull/14922)
  - Introduce: supports :capture [(#15194)](https://github.com/ManageIQ/manageiq/pull/15194)
  - Evmserver start-up: Improve ChargeableField.seed [(#15236)](https://github.com/ManageIQ/manageiq/pull/15236)
  - Do not schedule Session.purge if this Session is not used [(#15064)](https://github.com/ManageIQ/manageiq/pull/15064)
  - Do not queue no-op destroy action [(#15080)](https://github.com/ManageIQ/manageiq/pull/15080)
  - Do not schedule smartstate dispatch unless it is needed [(#15067)](https://github.com/ManageIQ/manageiq/pull/15067)
  - Avoid dozens of extra selects in seed_default_events [(#14722)](https://github.com/ManageIQ/manageiq/pull/14722)
  - Do not store whole container env. in the reporting worker forever [(#14807)](https://github.com/ManageIQ/manageiq/pull/14807)
  - BlacklistedEvent.seed was so slow [(#14712)](https://github.com/ManageIQ/manageiq/pull/14712)
  - Remove count(\*) from MiqQueue.get [(#14621)](https://github.com/ManageIQ/manageiq/pull/14621)
  - MiqQueue - remove MiqWorker lookup [(#14620)](https://github.com/ManageIQ/manageiq/pull/14620)
- Platform
  - Move MiqApache from manageiq-gems-pending [(#15548)](https://github.com/ManageIQ/manageiq/pull/15548)
- Providers
  - Drop support for oVirt /api always use /ovirt-engine/api [(#14469)](https://github.com/ManageIQ/manageiq/pull/14469)
  - Red Hat Virtualization Manager: New provider event parsing [(#14399)](https://github.com/ManageIQ/manageiq/pull/14399)
  - Middleware: Stop using deprecated names of hawkular-client gem [(#14543)](https://github.com/ManageIQ/manageiq/pull/14543)
  - Add config option to skip container_images [(#14606)](https://github.com/ManageIQ/manageiq/pull/14606)
  - Pass additional metadata from alert to event [(#14301)](https://github.com/ManageIQ/manageiq/pull/14301)
- User Interface
  - Split up miq_capacity into three separate controllers [(#15869)](https://github.com/ManageIQ/manageiq/pull/15869)
  - Use update:ui rake task instead of update:bower [(#15578)](https://github.com/ManageIQ/manageiq/pull/15578)

### Depricated
- Provisioning
  - Label has been deprecated and I need PR for day [(#16671)](https://github.com/ManageIQ/manageiq/pull/16671)

### Fixed
- Authentication
  - Add raw_connect? method to ExtManagementSystem [(#16636)](https://github.com/ManageIQ/manageiq/pull/16636)
  - Fixes a stack trace issue (500) during API authentication. [(#16520)](https://github.com/ManageIQ/manageiq/pull/16520)
  - If the userid is not found in the DB do a case insensitive search [(#15904)](https://github.com/ManageIQ/manageiq/pull/15904)
  - A tool for converting miqldap auth to external auth with sssd [(#15640)](https://github.com/ManageIQ/manageiq/pull/15640)
  - Converting userids to UPN format to avoid duplicate user records [(#15535)](https://github.com/ManageIQ/manageiq/pull/15535)
  - External auth lookup_by_identity should handle missing request parameter [(#16386)](https://github.com/ManageIQ/manageiq/pull/16386)
- Automate
  - Use UUID to ensure the uniqueness of job template name [(#16672)](https://github.com/ManageIQ/manageiq/pull/16672)
  - Rescue migration error and update status [(#16705)](https://github.com/ManageIQ/manageiq/pull/16705)
  - Adds field unique validator check to dialog [(#16487)](https://github.com/ManageIQ/manageiq/pull/16487)
  - Fix for custom button not passing target object to dynamic dialog fields [(#15810)](https://github.com/ManageIQ/manageiq/pull/15810)
  - miq_group_id is required by automate. [(#15760)](https://github.com/ManageIQ/manageiq/pull/15760)
  - Fix service dialog edit [(#15658)](https://github.com/ManageIQ/manageiq/pull/15658)
  - Set user's group to the requester group. [(#15696)](https://github.com/ManageIQ/manageiq/pull/15696)
  - Fixed path for including miq-syntax-checker [(#15551)](https://github.com/ManageIQ/manageiq/pull/15551)
  - Provisioning: Validate if we have an array of integers [(#15572)](https://github.com/ManageIQ/manageiq/pull/15572)
  - Services: Add my_zone to Service Orchestration. [(#15533)](https://github.com/ManageIQ/manageiq/pull/15533)
  - Checks PXE customization templates for unique names [(#15495)](https://github.com/ManageIQ/manageiq/pull/15495)
  - Rebuild Provision Requests with arrays [(#15410)](https://github.com/ManageIQ/manageiq/pull/15410)
  - Services: Add orchestration stack my_zone. [(#15334)](https://github.com/ManageIQ/manageiq/pull/15334)
  - Add orchestration_stack_retired notification type. [(#14957)](https://github.com/ManageIQ/manageiq/pull/14957)
  - Revert previous changes adding notification to finish retirement. [(#14955)](https://github.com/ManageIQ/manageiq/pull/14955)
  - Adjust power states on a service to handle children [(#14550)](https://github.com/ManageIQ/manageiq/pull/14550)
  - Display Name and Description not updated during import [(#14689)](https://github.com/ManageIQ/manageiq/pull/14689)
  - Service#my_zone should only reference a VM associated to a provider. [(#14696)](https://github.com/ManageIQ/manageiq/pull/14696)
  - Fixes custom button method for things with subclasses [(#16378)](https://github.com/ManageIQ/manageiq/pull/16378)
  - Scope User and MiqGroup searches within the current region [(#16756)](https://github.com/ManageIQ/manageiq/pull/16756)
- Chargeback
  - Consider cloud volumes as data storages in chargeback [(#16638)](https://github.com/ManageIQ/manageiq/pull/16638)
  - Add back listing of custom attributes in chargeback [(#16350)](https://github.com/ManageIQ/manageiq/pull/16350)
  - Stop cashing fields for ChargebackVm report [(#16683)](https://github.com/ManageIQ/manageiq/pull/16683)
  - Fix max method on empty array in chargeback storage report [(#16575)](https://github.com/ManageIQ/manageiq/pull/16575)
  - Fix chargeback report when VM is destroyed [(#16598)](https://github.com/ManageIQ/manageiq/pull/16598)
  - Delete tag assignments when deleting a tag that is referenced in an assignment [(#16039)](https://github.com/ManageIQ/manageiq/pull/16039)
  - Rate selection using union of all tags in reporting(consumption) period [(#15888)](https://github.com/ManageIQ/manageiq/pull/15888)
- Core
  - Fix for failure to update service dialog - Couldn't find DialogField without an ID [(#16753)](https://github.com/ManageIQ/manageiq/pull/16753)
  - Add missing gettext into MiqUserRole [(#16752)](https://github.com/ManageIQ/manageiq/pull/16752)
  - Use USS (unique set size) instead of PSS for all the things [(#16570)](https://github.com/ManageIQ/manageiq/pull/16570)
  - Make ContainerLogger respond to #instrument [(#16694)](https://github.com/ManageIQ/manageiq/pull/16694)
  - Allow full error log [(#16550)](https://github.com/ManageIQ/manageiq/pull/16550)
  - Parse models of > 3 namespaces [(#16704)](https://github.com/ManageIQ/manageiq/pull/16704)
  - Fixes wrong number of arguments in purge_queue [(#16706)](https://github.com/ManageIQ/manageiq/pull/16706)
  - Send IDs through exec_api_call as a regular param not a block [(#16708)](https://github.com/ManageIQ/manageiq/pull/16708)
  - Dont queue email sending when notifier is off [(#16528)](https://github.com/ManageIQ/manageiq/pull/16528)
  - Ensure that the zone name is unique only within the current region [(#16731)](https://github.com/ManageIQ/manageiq/pull/16731)
  - Fix cached query for total unregistered vms [(#16577)](https://github.com/ManageIQ/manageiq/pull/16577)
  - No need to call normalized_status [(#16578)](https://github.com/ManageIQ/manageiq/pull/16578)
  - Skip seeding of categories if their creation is invalid [(#16568)](https://github.com/ManageIQ/manageiq/pull/16568)
  - Don't return a duplicate object from MiqGroup#settings [(#16572)](https://github.com/ManageIQ/manageiq/pull/16572)
  - Handle deprecated classes in arel [(#16560)](https://github.com/ManageIQ/manageiq/pull/16560)
  - Fix error in timeout checking for job without target [(#16627)](https://github.com/ManageIQ/manageiq/pull/16627)
  - Use the server IP for the AWX database host when the rails config is no good [(#16621)](https://github.com/ManageIQ/manageiq/pull/16621)
  - Handle autoload error not caught by safe_constantize [(#16608)](https://github.com/ManageIQ/manageiq/pull/16608)
  - Cache invalidation... [(#16601)](https://github.com/ManageIQ/manageiq/pull/16601)
  - Add purging for vim_performance_tag_values with disabled tags [(#16425)](https://github.com/ManageIQ/manageiq/pull/16425)
  - Add a connection to the pool if there is only one for embedded ansible [(#16477)](https://github.com/ManageIQ/manageiq/pull/16477)
  - Fix Expression builder argument error by reverting #5506 [(#16255)](https://github.com/ManageIQ/manageiq/pull/16255)
  - Move the notifications to include more of the setup [(#16508)](https://github.com/ManageIQ/manageiq/pull/16508)
  - Finish simplifying NTP configuration using Settings [(#16393)](https://github.com/ManageIQ/manageiq/pull/16393)
  - Fix issue where plugin settings had higher precedence than manageiq [(#16535)](https://github.com/ManageIQ/manageiq/pull/16535)
  - When importing report symbolize keys only in 'db_options:' section [(#16143)](https://github.com/ManageIQ/manageiq/pull/16143)
  - Allow group settings with string keys [(#16142)](https://github.com/ManageIQ/manageiq/pull/16142)
  - Add the help menu to the permissions template yaml file [(#16096)](https://github.com/ManageIQ/manageiq/pull/16096)
  - Fix error importing Widget on Custom Report page [(#16034)](https://github.com/ManageIQ/manageiq/pull/16034)
  - Queue destroying of linked events when instance of MiqServer destroyed [(#15995)](https://github.com/ManageIQ/manageiq/pull/15995)
  - Tool to replicate server settings to other servers [(#15990)](https://github.com/ManageIQ/manageiq/pull/15990)
  - Ruby 2.4 - Replace all Fixnum|Bignum [(#15987)](https://github.com/ManageIQ/manageiq/pull/15987)
  - Cancel before_destroy  callback chain for MiqServer by throwing 'abort' [(#15986)](https://github.com/ManageIQ/manageiq/pull/15986)
  - Fix event_catcher blacklisted events logging [(#15945)](https://github.com/ManageIQ/manageiq/pull/15945)
  - This allows access to the worker object and also allows the web service workers to start the rails server which was broken [(#15880)](https://github.com/ManageIQ/manageiq/pull/15880)
  - Allows seeding a database with groups from other regions. [(#15876)](https://github.com/ManageIQ/manageiq/pull/15876)
  - Find_by_queue_name expects a string as queue_name [(#16359)](https://github.com/ManageIQ/manageiq/pull/16359)
  - Fix Zone creation [(#16391)](https://github.com/ManageIQ/manageiq/pull/16391)
  - Sort array of queue names [(#16400)](https://github.com/ManageIQ/manageiq/pull/16400)
- Events
  - Fix the ems_event add_queue method [(#16187)](https://github.com/ManageIQ/manageiq/pull/16187)
- i18n
  - Add missing gettext into MiqAction [(#16766)](https://github.com/ManageIQ/manageiq/pull/16766)
  - Add missing model names into locale/en.yml [(#16604)](https://github.com/ManageIQ/manageiq/pull/16604)
  - Fix string interpolations [(#16468)](https://github.com/ManageIQ/manageiq/pull/16468)
  - Add Middleware Server EAP/Wildfly translation [(#16492)](https://github.com/ManageIQ/manageiq/pull/16492)
- Inventory
  - Log less details about the targets [(#16405)](https://github.com/ManageIQ/manageiq/pull/16405)
  - Print name instead of manager ref [(#16411)](Print name instead of manager ref #16411)
- Metrics
  - Calculate Metering Used Hours only from used metrics in metering reports [(#16677)](https://github.com/ManageIQ/manageiq/pull/16677)
- Platform
  - Use ruby not runner for run single worker [(#15825)](https://github.com/ManageIQ/manageiq/pull/15825)
  - Handle pid in run_single_worker.rb properly [(#15820)](https://github.com/ManageIQ/manageiq/pull/15820)
  - Handle SIGTERM in run_single_worker.rb [(#15818)](https://github.com/ManageIQ/manageiq/pull/15818)
  - Bump to non-broken network discovery [(#15798)](https://github.com/ManageIQ/manageiq/pull/15798)
  - Get tag details for no specific model [(#15788)](https://github.com/ManageIQ/manageiq/pull/15788)
  - Support logins when "Get User Groups from LDAP" is not checked [(#15661)](https://github.com/ManageIQ/manageiq/pull/15661)
  - Give active queue worker time to complete message [(#15529)](https://github.com/ManageIQ/manageiq/pull/15529)
  - Seeding timeout [(#15595)](https://github.com/ManageIQ/manageiq/pull/15595)
  - RBAC: Add Storage feature to container administrator role [(#15689)](https://github.com/ManageIQ/manageiq/pull/15689)
  - Reporting: Do not limit width of table when downloading report in text format [(#15750)](https://github.com/ManageIQ/manageiq/pull/15750)
  - Authenticatin: Normalize the username entered at login to lowercase [(#15716)](https://github.com/ManageIQ/manageiq/pull/15716)
  - Fix CI after adding new columns to custom_buttons table [(#15581)](https://github.com/ManageIQ/manageiq/pull/15581)
  - Check for messages key in prefetch_below_threshold? [(#15620)](https://github.com/ManageIQ/manageiq/pull/15620)
  - Cast virtual attribute 'Hardware#ram_size_in_bytes' to bigint [(#15554)](https://github.com/ManageIQ/manageiq/pull/15554)
  - Refactor MiqTask.delete_older to queue condition instead of array of IDs [(#15415)](https://github.com/ManageIQ/manageiq/pull/15415)
  - Run the setup playbook if we see that an upgrade has happened [(#15482)](https://github.com/ManageIQ/manageiq/pull/15482)
  - Alerts: Fail explicitly for MAS validation failure [(#15473)](https://github.com/ManageIQ/manageiq/pull/15473)
  - Fix pseudo heartbeating when HB file missing [(#15483)](https://github.com/ManageIQ/manageiq/pull/15483)
  - Only remove my process' pidfile. [(#15491)](https://github.com/ManageIQ/manageiq/pull/15491)
  - Add UiConstants back to the web server worker mixin [(#15518)](https://github.com/ManageIQ/manageiq/pull/15518)
  - Add vm_migrate_task factory. [(#15332)](https://github.com/ManageIQ/manageiq/pull/15332)
  - FileDepotFtp: FTP.nlst cannot distinguish empty from non-existent dir [(#9127)](https://github.com/ManageIQ/manageiq/pull/9127)
  - Put back region_description method that was accidentally extracted [(#15372)](https://github.com/ManageIQ/manageiq/pull/15372)
  - Make user filter as restriction in RBAC [(#15367)](https://github.com/ManageIQ/manageiq/pull/15367)
  - Add AuthKeyPair to RBAC [(#15359)](https://github.com/ManageIQ/manageiq/pull/15359)
  - Workaround Rails.configuration.database_configuration being {} [(#15269)](https://github.com/ManageIQ/manageiq/pull/15269)
  - Move signal handling into the MiqServer object [(#15206)](https://github.com/ManageIQ/manageiq/pull/15206)
  - Format trend max cpu usage rate with percent [(#15272)](https://github.com/ManageIQ/manageiq/pull/15272)
  - Do not queue e-mails unless there is a notifier in the region [(#14801)](https://github.com/ManageIQ/manageiq/pull/14801)
  - Fixed logging for proxy when storage not defined  [(#15028)](https://github.com/ManageIQ/manageiq/pull/15028)
  - Fix broken stylesheet path for PDFs [(#14793)](https://github.com/ManageIQ/manageiq/pull/14793)
  - RBAC: Add middleware models to direct RBAC [(#15011)](https://github.com/ManageIQ/manageiq/pull/15011)
  - RBAC for User model regard to allowed role [(#14898)](https://github.com/ManageIQ/manageiq/pull/14898)
  - Fallback to ActiveRecord config for DB host lookup [(#15018)](https://github.com/ManageIQ/manageiq/pull/15018)
  - Use ActiveRecord::Base for connection info [(#15019)](https://github.com/ManageIQ/manageiq/pull/15019)
  - Miq shortcut seeding [(#14915)](https://github.com/ManageIQ/manageiq/pull/14915)
  - Fix constant reference in ManagerRefresh::Inventory::AutomationManager [(#14984)](https://github.com/ManageIQ/manageiq/pull/14984)
  - Set the db application_name after the server row is created [(#14904)](https://github.com/ManageIQ/manageiq/pull/14904)
  - Remove default server.cer [(#14858)](https://github.com/ManageIQ/manageiq/pull/14858)
  - Fixed bug: timeout was not triggered for Image Scanning Job after removing Job#agent_class [(#14791)](https://github.com/ManageIQ/manageiq/pull/14791)
  - Use base class only when it is supported by direct rbac [(#14665)](https://github.com/ManageIQ/manageiq/pull/14665)
  - Alter embedded ansible for rpm builds [(#14637)](https://github.com/ManageIQ/manageiq/pull/14637)
- Providers
  - disconnect flag not respected in link_ems_inventory [(#16618)](https://github.com/ManageIQ/manageiq/pull/16618)
  - Fix missing operations for MW datasource [(#16611)](https://github.com/ManageIQ/manageiq/pull/16611)
  - remove satellite6 credential type from embedded ansible space [(#16663)](https://github.com/ManageIQ/manageiq/pull/16663)
  - Create a task when destroying an ems [(#16669)](https://github.com/ManageIQ/manageiq/pull/16669)
  - Add container events to pod [(#16583)](https://github.com/ManageIQ/manageiq/pull/16583)
  - Hide by default the Middleware tab in UI [(#16698)](https://github.com/ManageIQ/manageiq/pull/16698)
  - Disconnect inventory on targeted refresh [(#16718)](https://github.com/ManageIQ/manageiq/pull/16718)
  - Stop generating `vim_performance_tag_values` rows [(#16692)](https://github.com/ManageIQ/manageiq/pull/16692)
  - Add vm_destroy event to MiqEventDefinition [(#16257)](https://github.com/ManageIQ/manageiq/pull/16557)
  - Fix missing do_disconnect check in link_inventory [(#16726)](https://github.com/ManageIQ/manageiq/pull/16726)
  - Allow proxying WebMKS consoles using the WebsocketWorker [(#16490)](https://github.com/ManageIQ/manageiq/pull/16490)
  - Add the missing container template openshift to the en.yml [(#16595)](https://github.com/ManageIQ/manageiq/pull/16595)
  - Catalog Item type list is dependent on installed providers [(#16559)](https://github.com/ManageIQ/manageiq/pull/16559)
  - Allowing OperatingSystem for CloudManager graph refresh [(#16605)](https://github.com/ManageIQ/manageiq/pull/16605)
  - Fix has_required_role? for InventoryCollectorWorker [(#16415)](https://github.com/ManageIQ/manageiq/pull/16415)
  - Missing cascade delete for host_storages [(#16440)](https://github.com/ManageIQ/manageiq/pull/16440)
  - Truncate name of refresh task to 255 [(#16444)](https://github.com/ManageIQ/manageiq/pull/16444)
  - Datastores duplicated after a refresh [(#16408)](https://github.com/ManageIQ/manageiq/pull/16408)
  - Added a Maintenance key to the hash struct [(#16464)](https://github.com/ManageIQ/manageiq/pull/16464)
  - Refresh new target do not run post_refresh [(#16436)](https://github.com/ManageIQ/manageiq/pull/16436)
  - Add two new types to MW server factories [(#16478)](https://github.com/ManageIQ/manageiq/pull/16478)
  - Container ssa annotate success [(#15031)](https://github.com/ManageIQ/manageiq/pull/15031)
  - Require handsoap in VimConnectMixin [(#16450)](https://github.com/ManageIQ/manageiq/pull/16450)
  - Require miq_fault_tolerant_vim in raw_connect [(#16500)](https://github.com/ManageIQ/manageiq/pull/16500)
  - Unique EmsRefresh.refresh targets if there are over 1,000 targets [(#16432)](https://github.com/ManageIQ/manageiq/pull/16432)
  - Add MiqException prefix to vm snapshot exceptions [(#16186)](https://github.com/ManageIQ/manageiq/pull/16186)
  - Changed Friendly_name to accept Arrays of queue_names [(#16172)](https://github.com/ManageIQ/manageiq/pull/16172)
  - Remove duplicate metric_rollups not dealing with active relation [(#16166)](https://github.com/ManageIQ/manageiq/pull/16166)
  - Fix Product Features [(#16164)](https://github.com/ManageIQ/manageiq/pull/16164)
  - Fix attach/detach disks automate methods [(#16160)](https://github.com/ManageIQ/manageiq/pull/16160)
  - Change Failure label by Rollback [(#16148)](https://github.com/ManageIQ/manageiq/pull/16148)
  - Delegate name attribute to parent_manager [(#16067)](https://github.com/ManageIQ/manageiq/pull/16067)
  - Fix for when target new refresh fails [(#16043)](https://github.com/ManageIQ/manageiq/pull/16043)
  - Disabling batch saving for VmOrTemplate because of needed hooks [(#16031)](https://github.com/ManageIQ/manageiq/pull/16031)
  - Fix the lenovo's event_catcher time [(#16012)](https://github.com/ManageIQ/manageiq/pull/16012)
  - Change error notification level from success to error [(#15998)](https://github.com/ManageIQ/manageiq/pull/15998)
  - Add nil checks for manager_uuids and references [(#15934)](https://github.com/ManageIQ/manageiq/pull/15934)
  - Proxy support for cloning ansible repo and add provider [(#15762)](https://github.com/ManageIQ/manageiq/pull/15762)
  - Have parent inventory collections as dependencies [(#15903)](https://github.com/ManageIQ/manageiq/pull/15903)
  - Orchestrate destroy of dependent managers [(#15590)](https://github.com/ManageIQ/manageiq/pull/15590)
  - save_vms_inventory needs to respect disconnect flag [(#15924)](https://github.com/ManageIQ/manageiq/pull/15924)
  - When trying to find char layout for middleware messaging return correct file path [(#15872)](https://github.com/ManageIQ/manageiq/pull/15872)
  - Add the missing openstack Cloud Tenant translation to en.yml [(#15744)](https://github.com/ManageIQ/manageiq/pull/15744)
  - Fix non existent container showing in report [(#15405)](https://github.com/ManageIQ/manageiq/pull/15405)
  - Make networks vms relations distinct [(#15783)](https://github.com/ManageIQ/manageiq/pull/15783)
  - Add custom reconnect logic also to the batch saver [(#15777)](https://github.com/ManageIQ/manageiq/pull/15777)
  - Fix saving of refresh stats [(#15775)](https://github.com/ManageIQ/manageiq/pull/15775)
  - Adding require_nested for new azure_classic_credential [(#15770)](https://github.com/ManageIQ/manageiq/pull/15770)
  - Re-adding "Create Service Dialog from Container Template" feature [(#15653)](https://github.com/ManageIQ/manageiq/pull/15653)
  - JobProxyDispatcher should use all container image classes [(#15519)](https://github.com/ManageIQ/manageiq/pull/15519)
  - Remove remains of container definition [(#15721)](https://github.com/ManageIQ/manageiq/pull/15721)
  - Use archived? instead of ems_id.nil? [(#15633)](https://github.com/ManageIQ/manageiq/pull/15633)
  - Return VMs and Templates for EMS prev_relats [(#15671)](https://github.com/ManageIQ/manageiq/pull/15671)
  - Fix bug in InventoryCollection#find_by with non-default ref [(#15648)](https://github.com/ManageIQ/manageiq/pull/15648)
  - Remove methods for Azure sample orchestration [(#15752)](https://github.com/ManageIQ/manageiq/pull/15752)
  - VMware Infrastructure: Fix Core Refresher if there is no ems_vmware setting [(#15690)](https://github.com/ManageIQ/manageiq/pull/15690)
  - Pluggability: change ManageIQ::Environment to run bundle install on plugin_setup [(#15589)](https://github.com/ManageIQ/manageiq/pull/15589)
  - Fix orchestrated destroy [(#15339)](https://github.com/ManageIQ/manageiq/pull/15339)
  - Wait for ems workers to finish before destroying the ems [(#14848)](https://github.com/ManageIQ/manageiq/pull/14848)
  - Return an empty relation instead of an array from db_relation() [(#15325)](https://github.com/ManageIQ/manageiq/pull/15325)
  - Physical Infrastructure: Fix the hosts key in method which save physical server [(#15199)](https://github.com/ManageIQ/manageiq/pull/15199)
  - Foreman: Added a check that URL is a type of HTTPS uri. [(#14965)](https://github.com/ManageIQ/manageiq/pull/14965)
  - Refactor start_clone method and break up powershell functions [(#14842)](https://github.com/ManageIQ/manageiq/pull/14842)
  - Microsoft Infrastructure: [SCVMM] Always assume a string for run_powershell_script [(#14859)](https://github.com/ManageIQ/manageiq/pull/14859)
  - Sleep some more time in ansible targeted refresh [(#14899)](https://github.com/ManageIQ/manageiq/pull/14899)
  - Create or delete a catalog item on update [(#14830)](https://github.com/ManageIQ/manageiq/pull/14830)
  - Prefer :dialog_id to :new_dialog_name in config_info [(#14958)](https://github.com/ManageIQ/manageiq/pull/14958)
  - Containers: Update miq-shortcuts [(#14951)](https://github.com/ManageIQ/manageiq/pull/14951)
  - Hawkular: Fix defaults for immutability of MiddlewareServers [(#14822)](https://github.com/ManageIQ/manageiq/pull/14822)
  - Move public/external network method into base class [(#14920)](https://github.com/ManageIQ/manageiq/pull/14920)
  - Ensure that genealogy_parent exists in the vm data before using it [(#14753)](https://github.com/ManageIQ/manageiq/pull/14753)
  - All_ems_in_zone is not a scope yet so we can't chain 'where' [(#14792)](https://github.com/ManageIQ/manageiq/pull/14792)
  - Ansible Tower: Reformat Ansible Tower error messages [(#14777)](https://github.com/ManageIQ/manageiq/pull/14777)
  - Containers: Removed duplicate report [(#14515)](https://github.com/ManageIQ/manageiq/pull/14515)
  - Google: Fix typo on "retirement" string in google provisioning dialog. [(#14800)](https://github.com/ManageIQ/manageiq/pull/14800)
  - Physical Infrastructure: Fix vendor key in physical server [(#14828)](https://github.com/ManageIQ/manageiq/pull/14828)
  - Storage: Fix StorageManagers Cross Linkers [(#14795)](https://github.com/ManageIQ/manageiq/pull/14795)
  - VMware: Create a notification when a snapshot operation fails [(#13991)](https://github.com/ManageIQ/manageiq/pull/13991)
  - Ensure remote shells generated by SCVMM are closed when finished [(#14591)](https://github.com/ManageIQ/manageiq/pull/14591)
  - Always evaluate datawarehouse_alerts [(#14318)](https://github.com/ManageIQ/manageiq/pull/14318)
  - Use human friendly names in task names and notifications for Tower CUD operations [(#14977)](https://github.com/ManageIQ/manageiq/pull/14977)
  - Nullify dependents when destroying configuration_script_sources/configuration_scripts [(#14567)](https://github.com/ManageIQ/manageiq/pull/14567)
  - Use organization instead of organization_id when talking to Tower [(#14538)](https://github.com/ManageIQ/manageiq/pull/14538)
  - Fix task name for task that create Tower project [(#14656)](https://github.com/ManageIQ/manageiq/pull/14656)
  - Ensure job is refreshed in the condition of state machine exits on error [(#14684)](https://github.com/ManageIQ/manageiq/pull/14684)
  - Parse password field from dialog and decrypt before job launch [(#14636)](https://github.com/ManageIQ/manageiq/pull/14636)
  - Ansible Service: skip dialog options for retirement [(#14602)](https://github.com/ManageIQ/manageiq/pull/14602)
  - Modified to use Embedded Ansible instance [(#14568)](https://github.com/ManageIQ/manageiq/pull/14568)
  - An Ansible Tower "Inventory" is a ManageIQ "InventoryRootGroup" [(#14716)](https://github.com/ManageIQ/manageiq/pull/14716)
  - Fix for  External Automation Manager Inventory Group [(#14691)](https://github.com/ManageIQ/manageiq/pull/14691)
  - Notification after Tower credential CUD operations [(#14625)](https://github.com/ManageIQ/manageiq/pull/14625)
  - Product features for embedded ansible refresh [(#14664)](https://github.com/ManageIQ/manageiq/pull/14664)
  - Notification after Tower credential CUD operations [(#14625)](https://github.com/ManageIQ/manageiq/pull/14625)
  - Product features for embedded ansible refresh [(#14664)](https://github.com/ManageIQ/manageiq/pull/14664)
  - Do unassign tags when mapped tags list becomes empty [(#16370)](https://github.com/ManageIQ/manageiq/pull/16370)
  - C&U fix bug in Targets#capture_vm_targets [(#16373)](https://github.com/ManageIQ/manageiq/pull/16373)
  - Fixed: ESxi host does not exit maintenance mode [(#16710)](https://github.com/ManageIQ/manageiq/pull/16710)
  - ensure monitoring manager deletion and creation on endpoint update [(#16635)](https://github.com/ManageIQ/manageiq/pull/16635)
  - Set limits for VM and Template names and descriptions [(#16736)](https://github.com/ManageIQ/manageiq/pull/16736)
  - Reconnect host on provider add [(#16750)](https://github.com/ManageIQ/manageiq/pull/16750)
  - Adding hostname format validation [(#16714)](https://github.com/ManageIQ/manageiq/pull/16714)
  - Added get_targets_for_base class methods [(#16707)](https://github.com/ManageIQ/manageiq/pull/16707)
- Provisioning
  - Changes cloud network list to follow availability zone rules [(#16688)](https://github.com/ManageIQ/manageiq/pull/16688)
  - Adding the option to set default vlan [(#16504)](https://github.com/ManageIQ/manageiq/pull/16504)
  - Fix email issue in miq_provision_quota_mixin active_provision by_owner method [(#16693)](https://github.com/ManageIQ/manageiq/pull/16693)
  - Fix allowed_vlans to call preload correctly [(#16702)](https://github.com/ManageIQ/manageiq/pull/16702)
- RBAC
  - Removed redundant "Monitor" main tab node. #16648 [(#16648)](https://github.com/ManageIQ/manageiq/pull/16648)
  - Standalone ServiceUI product features require, updating affected roles [(#16329)](https://github.com/ManageIQ/manageiq/pull/16329)
  - Fix nil cases of allocated disk types in chargeback reporting [(#16434)](https://github.com/ManageIQ/manageiq/pull/16434)
  - Add Missing button features to miq_features.yaml [(#16027)](https://github.com/ManageIQ/manageiq/pull/16027)
  - Ensure that `base_class` of first target is used for RBAC scope [(#16178)](https://github.com/ManageIQ/manageiq/pull/16178)
  - Add belongsto filter for other network models [(#16151)](https://github.com/ManageIQ/manageiq/pull/16151)
  - Move rule for network manager to belonsto filter [(#16063)](https://github.com/ManageIQ/manageiq/pull/16063)
  - Add Tasks start page URL to shortcuts yaml file [(#16061)](https://github.com/ManageIQ/manageiq/pull/16061)
  - Save key pairs in Authentication table [(#15485)](https://github.com/ManageIQ/manageiq/pull/15485)
  - Lower the report level of routine http errors in the Fog log [(#15363)](https://github.com/ManageIQ/manageiq/pull/15363)
- Replication
  - Prevent replication subscription to the same region as the current region [(#16446)](https://github.com/ManageIQ/manageiq/pull/16446)
  - Scope Tenant#name validation to the current region [(#16506)](https://github.com/ManageIQ/manageiq/pull/16506)
- Reporting
  - Add proper translation for manageiq_providers_cloud_manager_vms [(#16666)](https://github.com/ManageIQ/manageiq/pull/16666)
  - Update translation to resolve ambiguous Provider:Type field [(#16673)](https://github.com/ManageIQ/manageiq/pull/16673)
  - Fixed syntax with `orderby` in RSS Feed YAML files [(#16493)](https://github.com/ManageIQ/manageiq/pull/16493)
  - Unconditionally seed all standard reports and widgets [(#16062)](https://github.com/ManageIQ/manageiq/pull/16062)
  - Do not show container and cloud providers  on 'Monthly Hosts per Provider' report [(#15822)](https://github.com/ManageIQ/manageiq/pull/15822)
  - Expand scope of report definitions that visible to a user [(#16716)](https://github.com/ManageIQ/manageiq/pull/16716)
  - Add more translations for cloud resources and templates [(#16744)](https://github.com/ManageIQ/manageiq/pull/16744)
- REST API
  - web service worker needs to load MiqAeDomain etc. [(#15769)](https://github.com/ManageIQ/manageiq/pull/15769)
  - manageiq-api should be a plugin [(#15755)](https://github.com/ManageIQ/manageiq/pull/15755)
  - Allow operator characters on the RHS of filter [(#15534)](https://github.com/ManageIQ/manageiq/pull/15534)
  - Force ascending order [(#15559)](https://github.com/ManageIQ/manageiq/pull/15559)
  - Allow compressed ids when updating a service dialog [(#15619)](https://github.com/ManageIQ/manageiq/pull/15619)
  - Make request APIs consistent by restricting access to automation/provision requests to admin/requester [(#15186)](https://github.com/ManageIQ/manageiq/pull/15186)
  - Render ids in compressed form in API responses [(#15430)](https://github.com/ManageIQ/manageiq/pull/15430)
  - Use correct identifier for VM Retirement [(#15509)](https://github.com/ManageIQ/manageiq/pull/15509)
  - Return only requested attributes [(#14734)](https://github.com/ManageIQ/manageiq/pull/14734)
  - Return Not Found on Snapshots Delete actions  [(#15489)](https://github.com/ManageIQ/manageiq/pull/15489)
  - Redirect tasks subcollection to request_tasks  [(#15357)](https://github.com/ManageIQ/manageiq/pull/15357)
  - Request members should allow access to users with admin role [(#15163)](https://github.com/ManageIQ/manageiq/pull/15163)
  - Requests should allow access to users with admin role [(#15151)](https://github.com/ManageIQ/manageiq/pull/15151)
  - Correctly configure custom attributes for DELETEs [(#14751)](https://github.com/ManageIQ/manageiq/pull/14751)
  - Return correct custom_attributes href  [(#14752)](https://github.com/ManageIQ/manageiq/pull/14752)
  - Render DELETE action for notifications [(#14775)](https://github.com/ManageIQ/manageiq/pull/14775)
  - Allow policies to be deleted via DELETE [(#14659)](https://github.com/ManageIQ/manageiq/pull/14659)
  - Allow partial POST edits on miq policy REST [(#14518)](https://github.com/ManageIQ/manageiq/pull/14518)
  - Return provider_class on provider requests [(#14657)](https://github.com/ManageIQ/manageiq/pull/14657)
  - Return correct resource hrefs [(#14549)](https://github.com/ManageIQ/manageiq/pull/14549)
  - Removing ems_events from config/api.yml [(#14699)](https://github.com/ManageIQ/manageiq/pull/14699)
- Services
  - Fix check_quota(:active_provisions) for Service MiqRequest invalid service_template [(#16769)](https://github.com/ManageIQ/manageiq/pull/16769)
  - Change the type name for the catalog Item from 'Container Template' to 'Openshift Template' [(#16639)](https://github.com/ManageIQ/manageiq/pull/16639)
  - ServiceTemplate: add scope for unassigned items. [(#16445)](https://github.com/ManageIQ/manageiq/pull/16445)
- Smartstate
  - Increase Timeouts and Worker Memory for Azure SSA [(#16016)](https://github.com/ManageIQ/manageiq/pull/16016)
  - Add Heartbeat Thread to SmartProxy Worker [(#16685)](https://github.com/ManageIQ/manageiq/pull/16685)
- User Interface
  - Added factories that are need to run spec tests in the BZ fix [(#16794)](https://github.com/ManageIQ/manageiq/pull/16794)
  - Add MiqWdigetSet to Dashboard dictionary translation [(#16784)](https://github.com/ManageIQ/manageiq/pull/16784)
  - Update group/role EvmGroup-desktop product features [(#16788)](https://github.com/ManageIQ/manageiq/pull/16788)
  - Fixed control explorer feature id [(#16780)](https://github.com/ManageIQ/manageiq/pull/16780)
  - Update user roles to proper access physical infrastructure views [(#16637)](https://github.com/ManageIQ/manageiq/pull/16637)
  - Add Compute Infrastructure Hosts filter for ESX 6.5 [(#16703)](https://github.com/ManageIQ/manageiq/pull/16703)
  - Set default values for help menu link target types in settings.yml [(#16549)](https://github.com/ManageIQ/manageiq/pull/16549)
  - Update Catalog tab of Publish VM dialog [(#16599)](https://github.com/ManageIQ/manageiq/pull/16599)
  - Fix resize approval to work for editing requests [(#16381)](https://github.com/ManageIQ/manageiq/pull/16381)
  - Add monitoring menus [(#15866)](https://github.com/ManageIQ/manageiq/pull/15866)
  - This fixes Cockpit console from attempting to connect to AWS and GCE on private instead of public ip addresses and enables Cockpit console for RHOS. [(#15901)](https://github.com/ManageIQ/manageiq/pull/15901)
  - Remove rails-controller-testing from Gemfile [(#15852)](https://github.com/ManageIQ/manageiq/pull/15852)
  - Fail with descriptive message when no EMS [(#15807)](https://github.com/ManageIQ/manageiq/pull/15807)
  - Sync up dropdown list in My Settings => Visual Tab => Start Up [(#14914)](https://github.com/ManageIQ/manageiq/pull/14914)
  - Added jobs.target_class and jobs.target_id to returned dataset in MiqTask.yaml view [(#14932)](https://github.com/ManageIQ/manageiq/pull/14932)
  - Renamed action to copy Service Dialog [(#16623)](https://github.com/ManageIQ/manageiq/pull/16623)

### Removed
- Core
  - Passing a class as a value in an Active Record query is deprecated [(#16008)](https://github.com/ManageIQ/manageiq/pull/16008)
- Middleware
  - Remove middleware reports [(#16712)](https://github.com/ManageIQ/manageiq/pull/16712)
  - Removing all middleware performance charts [(#16713)](https://github.com/ManageIQ/manageiq/pull/16713)
  - Revert "Enable mwPolicies" [(#16701)](https://github.com/ManageIQ/manageiq/pull/16701)

# Fine-4

## Added
- Automate
  - Add ae_state_max_retries to root object. [(#46)](https://github.com/ManageIQ/manageiq-automation_engine/pull/46)
  - Add missing service model change for calculating active quota counts for Service requests. [(#69)](https://github.com/ManageIQ/manageiq-automation_engine/pull/69)
- Platform
  - Only remove my process' pidfile. [(#15491)](https://github.com/ManageIQ/manageiq/pull/15491)
- Providers
  - Implement :reboot_guest for VM [(#52)](https://github.com/ManageIQ/manageiq-providers-ovirt/pull/52)
  - Add additional logging into the websocket proxy for easier debugging [(#15428)](https://github.com/ManageIQ/manageiq/pull/15428)
  - Add validate_blacklist method for VM pre-provisioning [(#15513)](https://github.com/ManageIQ/manageiq/pull/15513)
  - Add blacklists for VM username and password when provisioning [(#88)](https://github.com/ManageIQ/manageiq-providers-azure/pull/88)
  - ovirt-networking: using profiles [(#14991)](https://github.com/ManageIQ/manageiq/pull/14991)
  - Disable delete button for the active snapshot on oVirt [(#54)](https://github.com/ManageIQ/manageiq-providers-ovirt/pull/54)
  - Update provision requirements check to allow exact matches [(#72)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/72)
  - Add config option to skip container_images [(#14606)](https://github.com/ManageIQ/manageiq/pull/14606)
  - Create Snapshot for Azure [(#15865)](https://github.com/ManageIQ/manageiq/pull/15865)
  - Option needed for new ems_refresh.openshift.store_unused_images setting [(#11)](https://github.com/ManageIQ/manageiq-providers-kubernetes/pull/11)
- RBAC
  - Include EvmRole-reader as read-only role in the fixtures [(#15647)](https://github.com/ManageIQ/manageiq/pull/15647)
- Services
  - Add group in manageiq payload for ansible automation. [(#15787)](https://github.com/ManageIQ/manageiq/pull/15787)
- Smart State
  - Snapshot Support for Non-Managed Disks SSA [(#15960)](https://github.com/ManageIQ/manageiq/pull/15960)
  - Increase Timeouts and Worker Memory for Azure SSA [(#16016)](https://github.com/ManageIQ/manageiq/pull/16016)

## Fixed
- Authentication
  - Normalize the username entered at login to lowercase [(#15716)](https://github.com/ManageIQ/manageiq/pull/15716)
  - Converting userids to UPN format to avoid duplicate user records [(#15535)](https://github.com/ManageIQ/manageiq/pull/15535)
- Automate
  - Add validate_blacklist method for VM pre-provisioning [(#15513)](https://github.com/ManageIQ/manageiq/pull/15513)
  - Fix vm_migrate_task statemachine_task_status value. [(#38)](https://github.com/ManageIQ/manageiq-automation_engine/pull/38)
  - Need to pass the user's group in to automate when the provision starts. [(#61)](https://github.com/ManageIQ/manageiq-automation_engine/pull/61)
  - miq_group_id is required by automate. [(#15760)](https://github.com/ManageIQ/manageiq/pull/15760)
- Chargeback
  - Delete tag assignments when deleting a tag that is referenced in an assignment [(#16039)](https://github.com/ManageIQ/manageiq/pull/16039)
- Core
  - Do not limit width of table when downloading report in text format [(#15750)](https://github.com/ManageIQ/manageiq/pull/15750)
  - Check for messages key in prefetch_below_threshold? [(#15620)](https://github.com/ManageIQ/manageiq/pull/15620)
  - Give active queue worker time to complete message [(#15529)](https://github.com/ManageIQ/manageiq/pull/15529)
  - Fix constant reference in ManagerRefresh::Inventory::AutomationManager [(#14984)](https://github.com/ManageIQ/manageiq/pull/14984)
- Platform
  - Add vm_migrate_task factory. [(#15332)](https://github.com/ManageIQ/manageiq/pull/15332)
  - Check for messages key in prefetch_below_threshold? [(#15620)](https://github.com/ManageIQ/manageiq/pull/15620)
  - Normalize the username entered at login to lowercase [(#15716)](https://github.com/ManageIQ/manageiq/pull/15716)
  - Collect log follows symlink recursively to the origin file [(#15420)](https://github.com/ManageIQ/manageiq/pull/15420)
- Providers
  - Return VMs and Templates for EMS prev_relats [(#15671)](https://github.com/ManageIQ/manageiq/pull/15671)
  - Fix VM password restrictions [(#87)](https://github.com/ManageIQ/manageiq-providers-azure/pull/87)
  - Fix unhandled exception in metrics collection when missing credentials [(#53)](https://github.com/ManageIQ/manageiq-providers-ovirt/pull/53)
  - Add explicit capture threshold for container [(#15311)](https://github.com/ManageIQ/manageiq/pull/15311)
  - Avoid Tower in notifications for embedded ansible [(#15478)](https://github.com/ManageIQ/manageiq/pull/15478)
  - Pass userid before going to automation [(#54)](https://github.com/ManageIQ/manageiq-providers-kubernetes/pull/54)
  - Manager name not updated on foreman provider edit [(#5)](https://github.com/ManageIQ/manageiq-providers-foreman/pull/5)
  - Remove the expose of manager to Embedded Ansible Job in service model. [(#47)](https://github.com/ManageIQ/manageiq-automation_engine/pull/47)
  - Avoid Tower in notifications for embedded ansible [(#10)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/10)
  - Choose build pod by name AND namespace [(#15575)](https://github.com/ManageIQ/manageiq/pull/15575)
  - disconnect_storage should be called once [(#62)](https://github.com/ManageIQ/manageiq-providers-ovirt/pull/62)
  - Matching on array order is failing sporadically [(#15692)](https://github.com/ManageIQ/manageiq/pull/15692)
  - Revamp create_vm_script to use configuration [(#9)](https://github.com/ManageIQ/manageiq-providers-scvmm/pull/9)
  - Force array context for VMs, hosts, vnets and images [(#13)](https://github.com/ManageIQ/manageiq-providers-scvmm/pull/13)
  - Don't break refresh if a flavor couldn't be found [(#69)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/69)
  - Fixed cases causing waiting on timeout in vm_import [(#73)](https://github.com/ManageIQ/manageiq-providers-ovirt/pull/73)
  - fix builds namespace matching [(#33)](https://github.com/ManageIQ/manageiq-providers-openshift/pull/33)
  - Handle case where do_volume_creation_check gets a nil from Fog [(#73)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/73)
  - Fix non existent container showing in report [(#15405)](https://github.com/ManageIQ/manageiq/pull/15405)
  - 'try' in case its a v2 tower which doesn't have v3 attr [(#17)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/17)
  - Quota - Calculate quota values for active provisions. [(#15466)](https://github.com/ManageIQ/manageiq/pull/15466)
  - Do not downcase the amazon IAM username [(#296)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/296)
  - Skip invalid container_images [(#94)](https://github.com/ManageIQ/manageiq-providers-kubernetes/pull/94)
  - Proxy support for cloning ansible repo and add provider [(#15762)](https://github.com/ManageIQ/manageiq/pull/15762)
  - Check if project_id is accessible [(#23)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/23)
- RBAC
  - Move rule for network manager to belongsto filter [(#16063)](https://github.com/ManageIQ/manageiq/pull/16063)
- Reporting
  - Cast virtual attribute 'Hardware#ram_size_in_bytes' to bigint [(#15554)](https://github.com/ManageIQ/manageiq/pull/15554)
  - Unconditionally seed all standard reports and widgets [(#16062)](https://github.com/ManageIQ/manageiq/pull/16062)
- REST API
  - Return Not Found on Snapshots Delete actions  [(#15489)](https://github.com/ManageIQ/manageiq/pull/15489)
  - Use correct identifier for VM Retirement [(#15509)](https://github.com/ManageIQ/manageiq/pull/15509)
  - Allow operator characters on the RHS of filter [(#15534)](https://github.com/ManageIQ/manageiq/pull/15534)
  - Set the current userid when running a report [(#30)](https://github.com/ManageIQ/manageiq-api/pull/30)
- Security
  - Use nil ca_certs to trust system CAs [(#63)](https://github.com/ManageIQ/manageiq-providers-ovirt/pull/63)
- Services
  - Set user's group to the requester group. [(#15696)](https://github.com/ManageIQ/manageiq/pull/15696)
- User Interface
  - Fix for <Choose> found as option in drop down service dialogs [(#15456)](https://github.com/ManageIQ/manageiq/pull/15456)
  - Don't unconditionally update verify_ssl [(#52)](https://github.com/ManageIQ/manageiq-automation_engine/pull/52)]
  - Login Start Pages dropdown list - Clouds menus [(#15017)](https://github.com/ManageIQ/manageiq/pull/15017)
  - Fix for custom button not passing target object to dynamic dialog fields [(#15810)](https://github.com/ManageIQ/manageiq/pull/15810)

# Fine-3

## Added

- Automate
  - Automate - added vmware reconfigure model to quota helper. [(#14756)](https://github.com/ManageIQ/manageiq/pull/14756)
  - Provisioning: Ovirt-networking: using profiles [(#14991)](https://github.com/ManageIQ/manageiq/pull/14991)
  - Services
    - Log zone(q_options) when raising retirement event. [(#15317)](https://github.com/ManageIQ/manageiq/pull/15317)

- Platform
  - Set database application name in workers and server [(#13856)](https://github.com/ManageIQ/manageiq/pull/13856)
  - Fix startup shortcut YAML setting for Configuration Management [(#14506)](https://github.com/ManageIQ/manageiq/pull/14506)
  - Generate virtual custom attributes with sections [(#14837)](https://github.com/ManageIQ/manageiq/pull/14837)
  - Allow reports to be generated based on GuestApplication [(#14939)](https://github.com/ManageIQ/manageiq/pull/14939)
  - Allow deletion of groups with users belonging to other groups [(#15041)](https://github.com/ManageIQ/manageiq/pull/15041)
  - Track and kill embedded ansible monitoring thread [(#15612)](https://github.com/ManageIQ/manageiq/pull/15612)
  - RBAC
    - Include EvmRole-reader as read-only role in the fixtures [(#15647)](https://github.com/ManageIQ/manageiq/pull/15647)

- Providers
  - Ansible Tower
    - Add status column to Repositories list [(#14855)](https://github.com/ManageIQ/manageiq/pull/14855)
    - Use $log.log_hashes to filter out sensitive data. [(#14878)](https://github.com/ManageIQ/manageiq/pull/14878)
  - Containers
    - Add purge timer for archived entities [(#14322)](https://github.com/ManageIQ/manageiq/pull/14322)
    - Delete archived entities when a container manager is deleted [(#14359)](https://github.com/ManageIQ/manageiq/pull/14359)
- Red Hat Virtualization: Reduce the default oVirt open timeout to 1 minute [(#15099)](https://github.com/ManageIQ/manageiq/pull/15099)
  - Add a virtual column for `supports_block_storage?` and `supports_cloud_object_store_container_create?` [(#15600)](https://github.com/ManageIQ/manageiq/pull/15600)

- REST API
  - Add cloud tenants to API [(#14731)](https://github.com/ManageIQ/manageiq/pull/14731)
  - Add SQL store option to token store [(#14947)](https://github.com/ManageIQ/manageiq/pull/14947)
  - Configuration_script_sources subcollection [(#15070)](https://github.com/ManageIQ/manageiq/pull/15070)

## Changed

- Providers
  - Add config option to skip container_images [(#14606)](https://github.com/ManageIQ/manageiq/pull/14606)

## Fixed

- Automate
  - Fix for custom button not passing target object to dynamic dialog fields [(#15810)](https://github.com/ManageIQ/manageiq/pull/15810)
  - miq_group_id is required by automate. [(#15760)](https://github.com/ManageIQ/manageiq/pull/15760)
  - Control: Remove the policy checking for request_host_vmotion_enabled. [(#14429)](https://github.com/ManageIQ/manageiq/pull/14429)
  - Provisioning
    - Add validate_blacklist method for VM pre-provisioning [(#15513)](https://github.com/ManageIQ/manageiq/pull/15513)
    - Filter out the hosts with the selected network. [(#14946)](https://github.com/ManageIQ/manageiq/pull/14946)
    - Add :sort_by: :none to GCE Boot Disk Size dialog field. [(#14981)](https://github.com/ManageIQ/manageiq/pull/14981)
    - Force status removal and default value [(#15685)](https://github.com/ManageIQ/manageiq/pull/15685)
  - Services
    - Set user's group to the requester group. [(#15696)](https://github.com/ManageIQ/manageiq/pull/15696)
    - Use extra_vars to create a new dialog when editing Ansible playbook service template. [(#15120)](https://github.com/ManageIQ/manageiq/pull/15120)

- Platform
  - Add a marker file for determining when the ansible setup has been run [(#15642)](https://github.com/ManageIQ/manageiq/pull/15642)
  - Give active queue worker time to complete message [(#15529)](https://github.com/ManageIQ/manageiq/pull/15529)
  - Authentication
    - Check the current region when creating a new user [(#15516)](https://github.com/ManageIQ/manageiq/pull/15516)
    - Normalize the username entered at login to lowercase [(#15716)](https://github.com/ManageIQ/manageiq/pull/15716)
  - Format time interval for log message [(#15370)](https://github.com/ManageIQ/manageiq/pull/15370)
  - Add vm_migrate_task factory. [(#15332)](https://github.com/ManageIQ/manageiq/pull/15332)
  - Start Apache if roles were changed and it is needed by the current roles [(#15078)](https://github.com/ManageIQ/manageiq/pull/15078)
  - Add a notification for when the embedded ansible role is activated [(#14867)](https://github.com/ManageIQ/manageiq/pull/14867)
  - Reporting
    - Do not limit width of table when downloading report in text format [(#15750)](https://github.com/ManageIQ/manageiq/pull/15750)
    - Fix chargeback report with unassigned rates [(#15580)](https://github.com/ManageIQ/manageiq/pull/15580)
    - Cast virtual attribute 'Hardware#ram_size_in_bytes' to bigint [(#15554)](https://github.com/ManageIQ/manageiq/pull/15554)
    - Fix key for regexp in miq_expression.yaml [(#15452)](https://github.com/ManageIQ/manageiq/pull/15452)
    - Include cloud instances in Powered On/Off Report [(#15333)](https://github.com/ManageIQ/manageiq/pull/15333)
    - Correct field names for reports [(#14905)](https://github.com/ManageIQ/manageiq/pull/14905)
    - Changed report name to be consistent with actual produced report. [(#14646)](https://github.com/ManageIQ/manageiq/pull/14646)
  - Fix constant reference in ManagerRefresh::Inventory::AutomationManager [(#14984)](https://github.com/ManageIQ/manageiq/pull/14984)
  - Do not delete report if task associated with this report deleted [(#15134)](https://github.com/ManageIQ/manageiq/pull/15134)
  - Workers
    - Only remove my process' pidfile. [(#15491)](https://github.com/ManageIQ/manageiq/pull/15491)
  - Check for messages key in prefetch_below_threshold? [(#15620)](https://github.com/ManageIQ/manageiq/pull/15620)

- Providers
  - Inventory
    - Return VMs and Templates for EMS prev_relats [(#15671)](https://github.com/ManageIQ/manageiq/pull/15671)
  - Ansible Tower: Let ansible worker gracefully stop [(#15643)](https://github.com/ManageIQ/manageiq/pull/15643)
  - Limit CloudTenants' related VMs to the non-archived ones [(#15329)](https://github.com/ManageIQ/manageiq/pull/15329)
  - Containers
    - Add default filters for the container page [(#14893)](https://github.com/ManageIQ/manageiq/pull/14893)
    - Fix Containers dashboard heatmaps [(#14857)](https://github.com/ManageIQ/manageiq/pull/14857)
  - Microsoft Infrastructure
    - [SCVMM] Remove -All from Get-SCVMTemplate call [(#15106)](https://github.com/ManageIQ/manageiq/pull/15106)
  - Network
    - Fix network_ports relation of a LB [(#14969)](https://github.com/ManageIQ/manageiq/pull/14969)
  - Virtual Infrastructure: Add a method to InfraManager to retrieve Hosts without EmsCluster [(#14884)](https://github.com/ManageIQ/manageiq/pull/14884)

- REST API
  - Allow operator characters on the RHS of filter [(#15534)](https://github.com/ManageIQ/manageiq/pull/15534)
  - Fix virtual attribute selection [(#15387)](https://github.com/ManageIQ/manageiq/pull/15387)
  - Make TokenManager#token_ttl callable (evaluated at call time) [(#15124)](https://github.com/ManageIQ/manageiq/pull/15124)
  - Return Not Found on Snapshots Delete actions  [(#15489)](https://github.com/ManageIQ/manageiq/pull/15489)
  - Use correct identifier for VM Retirement [(#15509)](https://github.com/ManageIQ/manageiq/pull/15509)

- SmartState: Fixed bug: one call to Job#set_status from \`VmScan#call_snapshot_delete' has one extra parameter [(#14964)](https://github.com/ManageIQ/manageiq/pull/14964)

- User Interface (Classic)
  - Show Network Port name in Floating IP list [(#14970)](https://github.com/ManageIQ/manageiq/pull/14970)
  - Add missing units on VMDB Utilization page for disk size [(#14921)](https://github.com/ManageIQ/manageiq/pull/14921)
  - Add Memory chart for Availability Zones [(#14938)](https://github.com/ManageIQ/manageiq/pull/14938)
  - Removed grouping from all Middleware views [(#15042)](https://github.com/ManageIQ/manageiq/pull/15042)
  - Fix URL to Compute/Containers/Containers in miq_shortcuts [(#15497)](https://github.com/ManageIQ/manageiq/pull/15497)
  - Fail with descriptive message when no EMS [(#15807)](https://github.com/ManageIQ/manageiq/pull/15807)

# Fine-2

## Added

- REST API
 - Enable custom actions for Vms API [(#14817)](https://github.com/ManageIQ/manageiq/pull/14817)

## Fixed

- Platform
  - Ensure order is qualified by table name for rss feeds [(#15112)](https://github.com/ManageIQ/manageiq/pull/15112)

  - RBAC
    - Fix tag filtering for indirect RBAC [(#15088)](https://github.com/ManageIQ/manageiq/pull/15088)

- Providers
  - Ansible Tower
    - Check that the Embedded Ansible role is on [(#15045)](https://github.com/ManageIQ/manageiq/pull/15045)
    - Encrypt secrets before enqueue Tower CU operations [(#15084)](https://github.com/ManageIQ/manageiq/pull/15084)
    - Hint to UI that scm_credential private_key field should have multiple-line [(#15109)](https://github.com/ManageIQ/manageiq/pull/15109)
    - Only run the setup playbook the first time we start embedded ansible [(#15225)](https://github.com/ManageIQ/manageiq/pull/15225)

# Fine-1

## Added

- Automate
  - Alerts
    - Pass metadata from an EmsEvent to an alert [(#14136)](https://github.com/ManageIQ/manageiq/pull/14136)
    - Add hide & show alert status actions (backend) [(#13650)](https://github.com/ManageIQ/manageiq/pull/13650)
  - Ansible Tower
    - Service Playbook updates fqname and configuration_template [(#15007)](https://github.com/ManageIQ/manageiq/pull/15007)
    - Require EmbeddedAnsible playbook to create playbook service [(#14226)](https://github.com/ManageIQ/manageiq/pull/14226)
    - Add relationships between Ansible job and its playbook [(#14144)](https://github.com/ManageIQ/manageiq/pull/14144)
    - Associate job with credentials [(#14113)](https://github.com/ManageIQ/manageiq/pull/14113)
    - Save newly created dialog_id in options [(#14254)](https://github.com/ManageIQ/manageiq/pull/14254)
    - Collect more attributes for Ansible Tower job [(#14076)](https://github.com/ManageIQ/manageiq/pull/14076)
    - Add Run Ansible Playbook control action type [(#13943)](https://github.com/ManageIQ/manageiq/pull/13943)
    - Create service template with Ansible Tower after first creating a new job template [(#13896)](https://github.com/ManageIQ/manageiq/pull/13896)
    - Added "Ansible Playbook" to the list of catalog item types [(#13936)](https://github.com/ManageIQ/manageiq/pull/13936)
    - Expose job_template from a service template [(#13895)](https://github.com/ManageIQ/manageiq/pull/13895)
    - Create catalog item after job templates are created [(#13893)](https://github.com/ManageIQ/manageiq/pull/13893)
    - Create temporary inventory when execute a playbook [(#14008)](https://github.com/ManageIQ/manageiq/pull/14008)
    - Run a control action to order Ansible Playbook Service [(#13874)](https://github.com/ManageIQ/manageiq/pull/13874)
  - Control: Enforce policies type to be either "compliance" or "control" [(#14519)](https://github.com/ManageIQ/manageiq/pull/14519)
  - Orchestration
    - Add Picture to Orchestration Template [(#14201)](https://github.com/ManageIQ/manageiq/pull/14201)
    - Use task queue for update stack operation [(#13897)](https://github.com/ManageIQ/manageiq/pull/13897)
  - Provisioning
    - Change vLan name to Virtual Network  [(#13747)](https://github.com/ManageIQ/manageiq/pull/13747)
    - Advanced networking placement features and automate exposure for OpenStack  [(#13608)](https://github.com/ManageIQ/manageiq/pull/13608)
    - Add multiple_value option to expose_eligible_resources [(#13853)](https://github.com/ManageIQ/manageiq/pull/13853)
  - Service Model
    - Add ae service model for S3 CloudObjectStoreContainer [(#14164)](https://github.com/ManageIQ/manageiq/pull/14164)
    - Add ae service model for S3 CloudObjectStoreObject [(#14189)](https://github.com/ManageIQ/manageiq/pull/14189)
  - Services
    - Add a add_to_service method to Vm [(#14416)](https://github.com/ManageIQ/manageiq/pull/14416)
    - Add orchestration_stacks to ServiceAnsiblePlaybook [(#14248)](https://github.com/ManageIQ/manageiq/pull/14248)
    - Update catalog item without config_options [(#14147)](https://github.com/ManageIQ/manageiq/pull/14147)
    - Set the initiator from the workflow/request [(#14070)](https://github.com/ManageIQ/manageiq/pull/14070)
    - Add service object to deliver to automate. [(#13956)](https://github.com/ManageIQ/manageiq/pull/13956)
    - Create a provision request for a service template [(#13972)](https://github.com/ManageIQ/manageiq/pull/13972)
    - ServiceTemplate update_catalog_item [(#13811)](https://github.com/ManageIQ/manageiq/pull/13811)
    - Add create_catalog_item to ServiceTemplateAnsibleTower  [(#13646)](https://github.com/ManageIQ/manageiq/pull/13646)
    - Tool to create a service dialog for an Ansible playbook [(#13494)](https://github.com/ManageIQ/manageiq/pull/13494)
    - Resource action - Add service_action. [(#13751)](https://github.com/ManageIQ/manageiq/pull/13751)
    - Initial commit for ansible playbook methods and service model. [(#13717)](https://github.com/ManageIQ/manageiq/pull/13717)
    - Add automate engine support for array elements containing text values ([#11667](https://github.com/ManageIQ/manageiq/pull/11667))
    - Modified destroying an Ansible Service Template [(#14586)](https://github.com/ManageIQ/manageiq/pull/14586)
    - Ansible Playbook Service add on_error method. [(#14583)](https://github.com/ManageIQ/manageiq/pull/14583)
    - Add 'delete' to generic object configuration dropdown ([#13541](https://github.com/ManageIQ/manageiq/pull/13541))
  - Automate Model: Add Amazon block storage automation models ([#13458](https://github.com/ManageIQ/manageiq/pull/13458))
  - Orchestration Services: create_catalog_item to ServiceTemplateOrchestration ([#13628](https://github.com/ManageIQ/manageiq/pull/13628))
  - Add create_catalog_item class method to ServiceTemplate ([#13589](https://github.com/ManageIQ/manageiq/pull/13589))
  - Save playbook service template ([#13600](https://github.com/ManageIQ/manageiq/pull/13600))
  - Allow adding disks to vm provision via api and automation ([#13318](https://github.com/ManageIQ/manageiq/pull/13318))
  - Move MiqAeEngine components into the appropriate directory in preparation for extracting the Automate engine into its own repository ([#13406](https://github.com/ManageIQ/manageiq/pull/13406))
  - Automate Retry with Server Affinity ([#13363](https://github.com/ManageIQ/manageiq/pull/13363))
  - Service Model: Added container components for service model ([#12863](https://github.com/ManageIQ/manageiq/pull/12863))
  - Expose attach/detach method for volume [(#14289)](https://github.com/ManageIQ/manageiq/pull/14289)
  - Allow passing options when adding a disk in automate. [(#14350)](https://github.com/ManageIQ/manageiq/pull/14350)


- Platform
  - Add remote servers to rake evm:status_full [(#14107)](https://github.com/ManageIQ/manageiq/pull/14107)
  - Include embedded ansible logs in log collection [(#14770)](https://github.com/ManageIQ/manageiq/pull/14770)
  - Ansible Tower
    - Create initial tower objects when we start the worker [(#14283)](https://github.com/ManageIQ/manageiq/pull/14283)
    - Add embedded_ansible to the list of roles that need apache [(#14353)](https://github.com/ManageIQ/manageiq/pull/14353)
    - Raise a notification when the embedded ansible server starts [(#14529)](https://github.com/ManageIQ/manageiq/pull/14529)
    - Move embedded ansible worker thread up to start_runner [(#14256)](https://github.com/ManageIQ/manageiq/pull/14256)
    - Run #authentication_check after the embedded ansible service starts [(#14235)](https://github.com/ManageIQ/manageiq/pull/14235)
    - Rely on 10 minute starting_timeout instead of a heartbeating thread [(#14053)](https://github.com/ManageIQ/manageiq/pull/14053)
    - Add methods for configuring and starting Ansible inside ([#13584](https://github.com/ManageIQ/manageiq/pull/13584))
    - New class for determining the availability of embedded ansible ([#13435](https://github.com/ManageIQ/manageiq/pull/13435)).
  - Authentication: Ensure user name is set even when common LDAP attributes are missing. [(#14142)](https://github.com/ManageIQ/manageiq/pull/14142)
  - RBAC
    - Introduce CloudTenancyMixin to fix RBAC for cloud_tenant based models [(#13535)](https://github.com/ManageIQ/manageiq/pull/13535)
    - Add RBAC for rss feeds [(#14041)](https://github.com/ManageIQ/manageiq/pull/14041)
    - Add View and Modify/Add RBAC features for the Embedded Automation Provider [(#13716)](https://github.com/ManageIQ/manageiq/pull/13716)
    - Add list of providers to RBAC on catalog items ([#13395](https://github.com/ManageIQ/manageiq/pull/13395))
  - Reporting
    - Add archived Container Groups [(#13810)](https://github.com/ManageIQ/manageiq/pull/13810)
    - Adding new report and widgets for Containers [(#13055)](https://github.com/ManageIQ/manageiq/pull/13055)
    - Add option for container performance reports ([#11904](https://github.com/ManageIQ/manageiq/pull/11904))
  - Chargeback
    - Chargeback without C & U [(#13884)](https://github.com/ManageIQ/manageiq/pull/13884)
    - Containers: Enterprise rate parent for chargeback [(#14079)](https://github.com/ManageIQ/manageiq/pull/14079)
    - Add tenant scoping for resources of performance reports in RBAC [(#14095)](https://github.com/ManageIQ/manageiq/pull/14095)
    - Introduce Vm/Chargeback tab backend ([#13687](https://github.com/ManageIQ/manageiq/pull/13687))
    - Charge SCVMM's vm only until it is retired. ([#13451](https://github.com/ManageIQ/manageiq/pull/13451))
  - Add a #backlog method to PglogicalSubscription objects [(#14010)](https://github.com/ManageIQ/manageiq/pull/14010)
  - Metrics: Collect metrics for archived containers [(#13686)](https://github.com/ManageIQ/manageiq/pull/13686)

- Providers
  - Enhanced inventory collector target and parser classes [(#13907)](https://github.com/ManageIQ/manageiq/pull/13907)
  - Force unique endpoint hostname only for same type ([#12912](https://github.com/ManageIQ/manageiq/pull/12912))
  - New folder targeted refresh [Depends on vmware/32] [(#14460)](https://github.com/ManageIQ/manageiq/pull/14460)
  - Amazon
    - Namespace the mappable object types add Amazon VM and Image types. [(#14288)](https://github.com/ManageIQ/manageiq/pull/14288)
    - Map Amazon labels to tags [(#14436)](https://github.com/ManageIQ/manageiq/pull/14436)
    - Import AWS Tags as CustomAttributes for Instances and Images [(#14202)](https://github.com/ManageIQ/manageiq/pull/14202)
    - Move amazon settings to ManageIQ/manageiq-providers-amazon ([#13192](https://github.com/ManageIQ/manageiq/pull/13192))
  - Ansible Tower
    - Tower CUD check and run refresh_in_provider followed by refreshing manager [(#15025)](https://github.com/ManageIQ/manageiq/pull/15025)
    - Tower CUD to invoke targeted refresh [(#14954)](https://github.com/ManageIQ/manageiq/pull/14954)
    - Refresh job_template -> playbook connection [(#14432)](https://github.com/ManageIQ/manageiq/pull/14432)
    - Prepare parameter hash before passing to Tower API credential CU [(#14483)](https://github.com/ManageIQ/manageiq/pull/14483)
    - Add manageiq to the extra_var before launching a job [(#14354)](https://github.com/ManageIQ/manageiq/pull/14354)
    - Use embedded tower default objects for ManageIQ [(#14467)](https://github.com/ManageIQ/manageiq/pull/14467)
    - Catalog item accepts remove_resources option [(#14328)](https://github.com/ManageIQ/manageiq/pull/14328)
    - Enable scm_credential type in refresh [(#14471)](https://github.com/ManageIQ/manageiq/pull/14471)
    - Add a concern for storing and accessing embedded ansible object ids [(#14377)](https://github.com/ManageIQ/manageiq/pull/14377)
    - Added Inventory to EmbeddedAnsible namespace [(#14282)](https://github.com/ManageIQ/manageiq/pull/14282)
    - Create/Update/Delete Ansible Tower Projects and Credentials via queue [(#14305)](https://github.com/ManageIQ/manageiq/pull/14305)
    - Add retire_now to Embedded Ansible job. [(#14479)](https://github.com/ManageIQ/manageiq/pull/14479)
    - Destroy Ansible Playbook job templates [(#14461)](https://github.com/ManageIQ/manageiq/pull/14461)
    - Add job_plays to job [(#14331)](https://github.com/ManageIQ/manageiq/pull/14331)
    - Add EmbeddedAnsible workers to WorkerManagement [(#14234)](https://github.com/ManageIQ/manageiq/pull/14234)
    - Refresh to pick up scm options for Tower Project [(#14220)](https://github.com/ManageIQ/manageiq/pull/14220)
    - Refresh to pick up extra attributes of Ansible Credentials [(#14106)](https://github.com/ManageIQ/manageiq/pull/14106)
    - Enhanced dependency and references scanning [(#13995)](https://github.com/ManageIQ/manageiq/pull/13995)
    - Introducing find by and find or build by methods [(#13926)](https://github.com/ManageIQ/manageiq/pull/13926)
    - Model change for Ansible Tower Credential [(#13773)](https://github.com/ManageIQ/manageiq/pull/13773)
    - Add missing `ConfigurationScriptSource` hierarchy and Automate models [(#14069)](https://github.com/ManageIQ/manageiq/pull/14069)
    - Models for EmbeddedAnsible provider [(#13879)](https://github.com/ManageIQ/manageiq/pull/13879)
    - Refresh inventory [(#13807)](https://github.com/ManageIQ/manageiq/pull/13807)
    - Event Catcher ([#13423](https://github.com/ManageIQ/manageiq/pull/13423))
    - Migrate AnsibleTower ConfigurationManager to AutomationManager ([#13630](https://github.com/ManageIQ/manageiq/pull/13630))
  - Cloud Providers
    - Enable cloud_tenant based RBAC for additional models  [(#14036)](https://github.com/ManageIQ/manageiq/pull/14036)
    - Update Cloud Image View to Differentiate Between Snapshots and Non-Snapshots [(#12970)](https://github.com/ManageIQ/manageiq/pull/12970)
    - Allow cloud volume to provide a list of volumes for attach [(#14058)](https://github.com/ManageIQ/manageiq/pull/14058)
    - Add relationship between VM and ResourceGroup. [(#14000)](https://github.com/ManageIQ/manageiq/pull/14000)
    - Support operation `create` on CloudObjectStoreContainer [(#14269)](https://github.com/ManageIQ/manageiq/pull/14269)
  - Console: Add product feature for VMware WebMKS HTML consoles [(#13945)](https://github.com/ManageIQ/manageiq/pull/13945)
  - Containers
    - Support alerts on container nodes [(#13812)](https://github.com/ManageIQ/manageiq/pull/13812)
    - Add External Logging Support SupportFeature [(#13319)](https://github.com/ManageIQ/manageiq/pull/13319)
    - Add datawarehouse logger [(#13813)](https://github.com/ManageIQ/manageiq/pull/13813)
    - Instantiate Container Template ([#10737](https://github.com/ManageIQ/manageiq/pull/10737))
    - Collect node custom attributes from hawkular during refresh ([#12924](https://github.com/ManageIQ/manageiq/pull/12924))
    - Add alerts on container nodes ([#13323](https://github.com/ManageIQ/manageiq/pull/13323))
  - Middleware
    - Cross-linking Middleware server model with containers. [(#14043)](https://github.com/ManageIQ/manageiq/pull/14043)
    - Be able to use tls when connecting to Hawkular [(#14054)](https://github.com/ManageIQ/manageiq/pull/14054)
    - Send data source properties when adding data source operation is performed [(#13937)](https://github.com/ManageIQ/manageiq/pull/13937)
    - Middleware server group power ops [(#13741)](https://github.com/ManageIQ/manageiq/pull/13741)
  - OpenStack
    - Use task queue for set/unset node maintenance [(#13657)](https://github.com/ManageIQ/manageiq/pull/13657)
    - Use task queue for CRUD operations on auth key pair  [(#13464)](https://github.com/ManageIQ/manageiq/pull/13464)
    - Add OpenStack excon settings [(#14172)](https://github.com/ManageIQ/manageiq/pull/14172)
    - Add OpenStack infra provider event blacklist [(#14369)](https://github.com/ManageIQ/manageiq/pull/14369)
  - Physical Infrastructure
    - Add Physical Infra Topology feature [(#14589)](https://github.com/ManageIQ/manageiq/pull/14589)
    - Add physical infra refresh monitor [(#14424)](https://github.com/ManageIQ/manageiq/pull/14424)
    - Add physical server views to the product [(#14031)](https://github.com/ManageIQ/manageiq/pull/14031)
  - Pluggable
    - Ems event groups - allow provider settings (deeper_merge edition) [(#14177)](https://github.com/ManageIQ/manageiq/pull/14177)
    - Add registered_provider_plugins to Vmdb::Plugins [(#13983)](https://github.com/ManageIQ/manageiq/pull/13983)
  - Red Hat Virtualization
    - New provider event parsing [(#14399)](https://github.com/ManageIQ/manageiq/pull/14399)
    - Use the new OvirtSDK for refresh [(#14398)](https://github.com/ManageIQ/manageiq/pull/14398)
    - Don't pass empty lists of certificates to the oVirt SDK [(#14160)](https://github.com/ManageIQ/manageiq/pull/14160)
    - Always pass the URL path to the oVirt SDK [(#14159)](https://github.com/ManageIQ/manageiq/pull/14159)
    - Set 'https' as the default protocol when using oVirt SDK [(#14157)](https://github.com/ManageIQ/manageiq/pull/14157)
  - VMware Infrastructure: Validate CPU and Memory Hot-Plug settings in reconfigure ([#12275](https://github.com/ManageIQ/manageiq/pull/12275))

- REST API
  - Remove all service resources [(#14584)](https://github.com/ManageIQ/manageiq/pull/14584)
  - Remove resources from service [(#14581)](https://github.com/ManageIQ/manageiq/pull/14581)
  - Bumping up version to 2.4.0 for the Fine Release [(#14541)](https://github.com/ManageIQ/manageiq/pull/14541)
  - Exposing prototype as part of /api/settings [(#14690)](https://github.com/ManageIQ/manageiq/pull/14690)
  - Add Alert Definitions (MiqAlert) bulk edits support [(#14397)](https://github.com/ManageIQ/manageiq/pull/14397)
  - Add_resource to Service api [(#14409)](https://github.com/ManageIQ/manageiq/pull/14409)
  - API Authentication create [(#14217)](https://github.com/ManageIQ/manageiq/pull/14217)
  - Added support for API slugs [(#14344)](https://github.com/ManageIQ/manageiq/pull/14344)
  - Enable put/patch on configuration script sources and authentications [(#14381)](https://github.com/ManageIQ/manageiq/pull/14381)
  - API Enhancement to support fine-grained settings whitelisting [(#13948)](https://github.com/ManageIQ/manageiq/pull/13948)
  - Create configuration script sources [(#14006)](https://github.com/ManageIQ/manageiq/pull/14006)
  - Edit Authentications API [(#14319)](https://github.com/ManageIQ/manageiq/pull/14319)
  - Delete and update configuration script sources [(#14323)](https://github.com/ManageIQ/manageiq/pull/14323)
  - Delete authentication in provider [(#14307)](https://github.com/ManageIQ/manageiq/pull/14307)
  - Collections API for Cloud Volumes [(#14260)](https://github.com/ManageIQ/manageiq/pull/14260)
  - Orchestration stack subcollection [(#14273)](https://github.com/ManageIQ/manageiq/pull/14273)
  - Add cloud types to authentication options [(#13951)](https://github.com/ManageIQ/manageiq/pull/13951)
  - Adds host to physical server relationship [(#14026)](https://github.com/ManageIQ/manageiq/pull/14026)
  - Adding support for a format_attributes parameter [(#14449)](https://github.com/ManageIQ/manageiq/pull/14449)
  - Added Api::Utils.resource_search_by_href_slug helper method [(#14443)](https://github.com/ManageIQ/manageiq/pull/14443)
  - Enhanced API to have a task created for provider refreshes [(#14387)](https://github.com/ManageIQ/manageiq/pull/14387)
  - Add Alert Definitions (MiqAlert) REST API support [(#13967)](https://github.com/ManageIQ/manageiq/pull/13967)
  - Enhance service edit to accept attribute references  [(#14124)](https://github.com/ManageIQ/manageiq/pull/14124)
  - Delete service templates via POST [(#14112)](https://github.com/ManageIQ/manageiq/pull/14112)
  - Delete services via POST [(#14111)](https://github.com/ManageIQ/manageiq/pull/14111)
  - Delete templates via POST [(#14110)](https://github.com/ManageIQ/manageiq/pull/14110)
  - Exposing regions as a primary collection /api/regions [(#14109)](https://github.com/ManageIQ/manageiq/pull/14109)
  - Add authentications sub collection to ConfigurationScriptPayload  [(#14002)](https://github.com/ManageIQ/manageiq/pull/14002)
  - Improve error handling on destroy action [(#14098)](https://github.com/ManageIQ/manageiq/pull/14098)
  - Differentiate Vms/Instances in messages [(#13971)](https://github.com/ManageIQ/manageiq/pull/13971)
  - Authentications Read and Delete api [(#13780)](https://github.com/ManageIQ/manageiq/pull/13780)
  - Create service template REST api [(#12594)](https://github.com/ManageIQ/manageiq/pull/12594)
  - Snapshots revert API [(#13829)](https://github.com/ManageIQ/manageiq/pull/13829)
  - Add snapshotting for instances in the API [(#13729)](https://github.com/ManageIQ/manageiq/pull/13729)
  - Bulk unassign tags on services and vms  [(#13712)](https://github.com/ManageIQ/manageiq/pull/13712)
  - Add bulk delete for snapshots API [(#13711)](https://github.com/ManageIQ/manageiq/pull/13711)
  - Improve create picture validation [(#13697)](https://github.com/ManageIQ/manageiq/pull/13697)
  - Configuration Script Sources API [(#13626)](https://github.com/ManageIQ/manageiq/pull/13626)
  - Api enhancement to support optional collection_class parameter [(#13845)](https://github.com/ManageIQ/manageiq/pull/13845)
  - Allows specification for optional multiple identifiers [(#13827)](https://github.com/ManageIQ/manageiq/pull/13827)
  - Add config_info as additional attribute to Service Templates API [(#13842)](https://github.com/ManageIQ/manageiq/pull/13842)
  - API collection OPTIONS Enhancement to expose list of supported subcollections ([#13681](https://github.com/ManageIQ/manageiq/pull/13681))
  - API Enhancement to support filtering on id attributes by compressed id's ([#13645](https://github.com/ManageIQ/manageiq/pull/13645))
  - Adds remove_approver_resource to ServiceRequestController. ([#13596](https://github.com/ManageIQ/manageiq/pull/13596))
  - Add OPTIONS method to Clusters and Hosts ([#13574](https://github.com/ManageIQ/manageiq/pull/13574))
  - VMs/Snapshots API CRD ([#13552](https://github.com/ManageIQ/manageiq/pull/13552))
  - Add alert actions api ([#13325](https://github.com/ManageIQ/manageiq/pull/13325))
  - Copy orchestration template ([#13053](https://github.com/ManageIQ/manageiq/pull/13053))
  - Expose Request Workflow class name ([#13441](https://github.com/ManageIQ/manageiq/pull/13441))
  - Sort on sql friendly virtual attributes ([#13409](https://github.com/ManageIQ/manageiq/pull/13409))
  - Expose allowed tags for a request workflow ([#13379](https://github.com/ManageIQ/manageiq/pull/13379))

- SmartState
  - Make docker registry & repo configurable for 'image-inspector' [(#8439)](https://github.com/ManageIQ/manageiq/pull/8439)
  - Warn if OpenSCAP binary not available [(#13878)](https://github.com/ManageIQ/manageiq/pull/13878)

- Storage
  - Add Amazon EC2 block storage manager EMS ([#13539](https://github.com/ManageIQ/manageiq/pull/13539))

- User Interface (Classic)
  - Add missing ui_lookup for Repository [(#14485)](https://github.com/ManageIQ/manageiq/pull/14485)
  - Remove 'retired' column from the services list [(#14378)](https://github.com/ManageIQ/manageiq/pull/14378)
  - Changes for Embedded Ansible models [(#14199)](https://github.com/ManageIQ/manageiq/pull/14199)
  - Add missing fields to Middleware views [(#14115)](https://github.com/ManageIQ/manageiq/pull/14115)
  - Add multiselect option to dropdowns [(#10270)](https://github.com/ManageIQ/manageiq/pull/10270)
  - Core changes for Ansible Tower Playbooks & Repositories UI [(#13731)](https://github.com/ManageIQ/manageiq/pull/13731)
  - Core changes for Ansible Credentials UI [(#14020)](https://github.com/ManageIQ/manageiq/pull/14020)
  - Added changes to show Catalog Item type in UI [(#13516)](https://github.com/ManageIQ/manageiq/pull/13516)
  - Physical Infrastructure provider (lenovo) changes required for the UI [(#13735)](https://github.com/ManageIQ/manageiq/pull/13735)
  - Adding Physical Infra Providers Menu Item [(#13587)](https://github.com/ManageIQ/manageiq/pull/13587)
  - Added new features for the Ansible UI move to the Automation tab [(#13526)](https://github.com/ManageIQ/manageiq/pull/13526)
  - Added new features for the Ansible UI move to the Automation tab [(#13526)](https://github.com/ManageIQ/manageiq/pull/13526)
  - Add edit functionality for generic object UI ([#11815](https://github.com/ManageIQ/manageiq/pull/11815))

## Changed

- Automate
  - Switched to the latest version of `ansible_tower_client` gem [(#14117)](https://github.com/ManageIQ/manageiq/pull/14117)
  - Update the service dialog to use the correct automate entry point [(#13955)](https://github.com/ManageIQ/manageiq/pull/13955)
  - Change default provisioning entry point for AutomationManagement. [(#13762)](https://github.com/ManageIQ/manageiq/pull/13762)
  - Look for resources in the same region as the selected template during provisioning. ([#13045](https://github.com/ManageIQ/manageiq/pull/13045))

- Performance
  - Optimize number of transactions sent in refresh [(#14670)](https://github.com/ManageIQ/manageiq/pull/14670)
  - Optimize store_ids_for_new_records by getting rid of the O(n^2) lookups [(#14542)](https://github.com/ManageIQ/manageiq/pull/14542)
  - Do not run MiqEventDefinitionSet.seed twice on every start-up [(#14725)](https://github.com/ManageIQ/manageiq/pull/14725)
  - Do not run these seeds twice [(#14726)](https://github.com/ManageIQ/manageiq/pull/14726)
  - Speed up MiqEventDefinitionSet.seed [(#14721)](https://github.com/ManageIQ/manageiq/pull/14721)
  - Do not store whole container env. in the reporting worker forever [(#14807)](https://github.com/ManageIQ/manageiq/pull/14807)
  - Make Widget run without timezones [(#14386)](https://github.com/ManageIQ/manageiq/pull/14386)
  - boot skips all seeding with env variable [(#14207)](https://github.com/ManageIQ/manageiq/pull/14207)
  - Add a cache for full Feature objects [(#14037)](https://github.com/ManageIQ/manageiq/pull/14037)
  - Report Widget [(#14285)](https://github.com/ManageIQ/manageiq/pull/14285)
  - Skip relationship query when we know there are none [(#14480)](https://github.com/ManageIQ/manageiq/pull/14480)
  - Report Widget [(#14285)](https://github.com/ManageIQ/manageiq/pull/14285)
  - Speed up widget generation [(#14224)](https://github.com/ManageIQ/manageiq/pull/14224)
  - Fix ordering by VMs in NetworkManagers list [(#14092)](https://github.com/ManageIQ/manageiq/pull/14092)
  - Use eager_load for extra_resources [(#13904)](https://github.com/ManageIQ/manageiq/pull/13904)
  - Perfomance fix for Object Storage Manager deletion [(#14009)](https://github.com/ManageIQ/manageiq/pull/14009)
  - Avoid N+1 queries by including snapshots [(#13833)](https://github.com/ManageIQ/manageiq/pull/13833)
  - Load created Vms in batches so they don't load all in memory [(#14067)](https://github.com/ManageIQ/manageiq/pull/14067)
  - Do not keep all association records in the memory [(#14066)](https://github.com/ManageIQ/manageiq/pull/14066)
  - Scanning for used attributes for query optimizations [(#14023)](https://github.com/ManageIQ/manageiq/pull/14023)

- Platform
  - RBAC
    - Allow descendants of Host model to use belongsto filters in RBAC [(#14852)](https://github.com/ManageIQ/manageiq/pull/14852)
    - Add chargeback to shortcuts to allow access to chargeback only. [(#14809)](https://github.com/ManageIQ/manageiq/pull/14809)
    - Define new product features for specific types of Storage Managers [(#14745)](https://github.com/ManageIQ/manageiq/pull/14745)
  - Reporting
    - Support dots and slashes in virtual custom attributes [(#14329)](https://github.com/ManageIQ/manageiq/pull/14329)
    - Link recently_discovered_pods widget to rpt [(#14493)](https://github.com/ManageIQ/manageiq/pull/14493)
  - Allow regex for MiqExpression::Field which contains numbers in associations [(#14229)](https://github.com/ManageIQ/manageiq/pull/14229)
  - Move the call to reload ntp settings to the server only [(#14208)](https://github.com/ManageIQ/manageiq/pull/14208)
  - Ansible Tower: Use http_port extra variables instead of nginx ones [(#14204)](https://github.com/ManageIQ/manageiq/pull/14204)
  - Fix ordering by VMs in NetworkManagers list [(#14092)](https://github.com/ManageIQ/manageiq/pull/14092)
  - Configure apache balancer with up to 10 members at startup [(#14007)](https://github.com/ManageIQ/manageiq/pull/14007)
  - Remove admin role for tenant admin [(#14081)](https://github.com/ManageIQ/manageiq/pull/14081)
  - Ansible: Properly monitor the embedded ansible service [(#13978)](https://github.com/ManageIQ/manageiq/pull/13978)
  - Remove the mechanisms around "configuring" central admin [(#13966)](https://github.com/ManageIQ/manageiq/pull/13966)
  - Allow users to input ipv6 where it makes sense [(#70)](https://github.com/ManageIQ/manageiq-gems-pending/pull/70)
  - Rename events "ExtManagementSystem Compliance\*" -> "Provider Compliance\*" [(#13388)](https://github.com/ManageIQ/manageiq/pull/13388)
  - Use the new setup script argument types [(#14313)](https://github.com/ManageIQ/manageiq/pull/14313)
  - Exclude chargeback lookup tables in replication [(#14466)](https://github.com/ManageIQ/manageiq/pull/14466)

- Providers
  - Move azure settings to azure provider [(#14345)](https://github.com/ManageIQ/manageiq/pull/14345)
  - Ansible event catcher - mark event_monitor_runnning when there are no events at startup [(#13903)](https://github.com/ManageIQ/manageiq/pull/13903)
  - Virtual Infrastructure: Deprecate callers to Address in Host [(#14138)](https://github.com/ManageIQ/manageiq/pull/14138)
  - OpenStack
    - Add openstack cloud tenant events [(#14052)](https://github.com/ManageIQ/manageiq/pull/14052)
    - Set the raw power state when starting Openstack instance [(#14122)](https://github.com/ManageIQ/manageiq/pull/14122)
  - Use task queue for VM actions [(#13782)](https://github.com/ManageIQ/manageiq/pull/13782)
  - Red Hat Virtualization
    - Drop support for oVirt /api always use /ovirt-engine/api [(#14469)](https://github.com/ManageIQ/manageiq/pull/14469)
    - Resolve oVirt IP addresses [(#13767)](https://github.com/ManageIQ/manageiq/pull/13767)
    - Save host for a VM after migration ([#13511](https://github.com/ManageIQ/manageiq/pull/13511))

- Storage
  - Rename Amazon EBS storage manager ([#13569](https://github.com/ManageIQ/manageiq/pull/13569))

- User Interface (Classic)
  - Updated patternfly to v3.23 [(#13940)](https://github.com/ManageIQ/manageiq/pull/13940)

## Fixed

- Automate
  - Retirement: Change retire_now to pass zone_name to raise_retirement_event. [(#15026)](https://github.com/ManageIQ/manageiq/pull/15026)
  - Added finish retirement notification. [(#14780)](https://github.com/ManageIQ/manageiq/pull/14780)
  - Add policy checking for retirement request. [(#14641)](https://github.com/ManageIQ/manageiq/pull/14641)
  - Fix services always invisible [(#14403)](https://github.com/ManageIQ/manageiq/pull/14403)
  - Fixes tag control multi-value [(#14382)](https://github.com/ManageIQ/manageiq/pull/14382)
  - Don't allow selecting resources from another region when creating a catalog item [(#14468)](https://github.com/ManageIQ/manageiq/pull/14468)
  - Merge service template options on update [(#14314)](https://github.com/ManageIQ/manageiq/pull/14314)
  - Fix for Service Dialog not saving default value <None> for drop down or radio button [(#14240)](https://github.com/ManageIQ/manageiq/pull/14240)
  - Avoid calling $evm.backtrace over DRb to prevent DRb-level mutex locks [(#14239)](https://github.com/ManageIQ/manageiq/pull/14239)
  - Fix Automate domain reset for legacy directory. [(#13933)](https://github.com/ManageIQ/manageiq/pull/13933)
  - Services: Power state for services that do not have an associated service_template [(#13785)](https://github.com/ManageIQ/manageiq/pull/13785)
  - Provisioning: Update validation regex to prohibit only numbers for Azure VM provisioning [(#13730)](https://github.com/ManageIQ/manageiq/pull/13730)
  - Allow a service power state to correctly handle nil actions ([#13232](https://github.com/ManageIQ/manageiq/pull/13232))
  - Increment the ae_state_retries when on_exit sets retry ([#13339](https://github.com/ManageIQ/manageiq/pull/13339))
  - Ansible Tower
    - Ensure job is refreshed in the condition of state machine exits on error [(#14684)](https://github.com/ManageIQ/manageiq/pull/14684)
    - Parse password field from dialog and decrypt before job launch [(#14636)](https://github.com/ManageIQ/manageiq/pull/14636)
    - Ansible Service: skip dialog options for retirement [(#14602)](https://github.com/ManageIQ/manageiq/pull/14602)
    - Modified to use Embedded Ansible instance [(#14568)](https://github.com/ManageIQ/manageiq/pull/14568)
  - Control
    - Add policy checking for request_host_scan. [(#14427)](https://github.com/ManageIQ/manageiq/pull/14427)
    - Add the logic to allow a policy to prevent request_vm_scan. [(#14370)](https://github.com/ManageIQ/manageiq/pull/14370)
    - During control action host was not being passed in  [(#14500)](https://github.com/ManageIQ/manageiq/pull/14500)
  - Provisioning
   - Remove reverse! call for timezone after converting structure to hash [(#14772)](https://github.com/ManageIQ/manageiq/pull/14772)
   - First and Last name are no longer required. [(#14694)](https://github.com/ManageIQ/manageiq/pull/14694)
   - Use fetch_path to handle the case where :ws_values is nil. [(#14797)](https://github.com/ManageIQ/manageiq/pull/14797)
  - Services: Service#my_zone should only reference a VM associated to a provider. [(#14696)](https://github.com/ManageIQ/manageiq/pull/14696)

- Platform
  - Chargeback
    - Group chargeback with unknown image under 'unknown image' [(#14816)](https://github.com/ManageIQ/manageiq/pull/14816)
    - Charge since the first MetricRollup [(#14666)](https://github.com/ManageIQ/manageiq/pull/14666)
    - Group results with unknown project under 'unknown project' [(#14811)](https://github.com/ManageIQ/manageiq/pull/14811)
  - Reports: Add Container entities to TAG_CLASSES [(#14535)](https://github.com/ManageIQ/manageiq/pull/14535)
  - Make worker_monitor_drb act like a reader [(#14638)](https://github.com/ManageIQ/manageiq/pull/14638)
  - Do not pass nil to the assignment mixin [(#14713)](https://github.com/ManageIQ/manageiq/pull/14713)
  - Use base class only when it is supported by direct rbac [(#14665)](https://github.com/ManageIQ/manageiq/pull/14665)
    - Metrics: Split metric collections into smaller intervals [(#14332)](https://github.com/ManageIQ/manageiq/pull/14332)
  - Add balancer members after configs have been written [(#14311)](https://github.com/ManageIQ/manageiq/pull/14311)
  - MiqApache::Conf.create_balancer_config expects a :lbmethod key [(#14306)](https://github.com/ManageIQ/manageiq/pull/14306)
  - If we can't update_attributes on a queue row, set state to error [(#14365)](https://github.com/ManageIQ/manageiq/pull/14365)
  - Do not truncate(255) message attribute in miq_tasks table [(#14105)](https://github.com/ManageIQ/manageiq/pull/14105)
  - Fix "Multiple Parents Found" issue when moving a relationship. [(#14060)](https://github.com/ManageIQ/manageiq/pull/14060)
  - Core
    - Fix missing reason constants [(#13919)](https://github.com/ManageIQ/manageiq/pull/13919)
    - Rescue worker class sync_workers exceptions and move on [(#13976)](https://github.com/ManageIQ/manageiq/pull/13976)
  - Reporting: Ignore custom attributes that have a nil name [(#14055)](https://github.com/ManageIQ/manageiq/pull/14055)
  - Chargeback
    - Skip calculation when there is zero consumed hours [(#13723)](https://github.com/ManageIQ/manageiq/pull/13723)
    - Bring currency symbols back to chargeback reports [(#13861)](https://github.com/ManageIQ/manageiq/pull/13861)
    - Fix tier selection when using different units. [(#13593)](https://github.com/ManageIQ/manageiq/pull/13593)
    - Fix rate adjustment rounding bug ([#13331](https://github.com/ManageIQ/manageiq/pull/13331))
    - Charge only for past hours ([#13134](https://github.com/ManageIQ/manageiq/pull/13134))
    - Delegate custom attributes to images in ChargebackContainerImage [(#14395)](https://github.com/ManageIQ/manageiq/pull/14395)
  - Add MiqUserRole to RBAC [(#13689)](https://github.com/ManageIQ/manageiq/pull/13689)
  - Fix broken C&U collection [(#13843)](https://github.com/ManageIQ/manageiq/pull/13843)
  - Instead of default(system) assign current user to generating report task [(#13823)](https://github.com/ManageIQ/manageiq/pull/13823)
  - Tenant admin should not be able to create groups in other tenants. ([#13483](https://github.com/ManageIQ/manageiq/pull/13483))
  - Replication: Expose a method for encrypting using a remote v2_key ([#13083](https://github.com/ManageIQ/manageiq/pull/13083))

- Providers
  - Fixing full_name not returning docker_id when it should [(#14412)](https://github.com/ManageIQ/manageiq/pull/14412)
  - Remove queue serialization [(#13722)](https://github.com/ManageIQ/manageiq/pull/13722)
  - Fix general CloudNetwork class_by_ems method [(#14392)](https://github.com/ManageIQ/manageiq/pull/14392)
  - Prevent a DVPortGroup from overwriting a LAN with the same name in provisioning [(#14292)](https://github.com/ManageIQ/manageiq/pull/14292)
  - Fix EmsRefresh miq_callback when merging queue items [(#14441)](https://github.com/ManageIQ/manageiq/pull/14441)
  - Pass hosts as a parameter to create the service dialog [(#14507)](https://github.com/ManageIQ/manageiq/pull/14507)
  - Provide better error message when migrating to the same host [(#14155)](https://github.com/ManageIQ/manageiq/pull/14155)
  - Fixed refresh & save for Physical Infra. [(#14351)](https://github.com/ManageIQ/manageiq/pull/14351)
  - Always pass valid date format [(#14296)](https://github.com/ManageIQ/manageiq/pull/14296)
  - Check if project has credential before try to use it [(#14297)](https://github.com/ManageIQ/manageiq/pull/14297)
  - Ansible Tower
    - Fix saving hosts in ansible playbook job [(#14522)](https://github.com/ManageIQ/manageiq/pull/14522)
    - Add missing authentication require_nested [(#14018)](https://github.com/ManageIQ/manageiq/pull/14018)
    - Disable SSL verification for embedded Ansible. [(#14078)](https://github.com/ManageIQ/manageiq/pull/14078)
    - Allow create_in_provider to fail [(#14049)](https://github.com/ManageIQ/manageiq/pull/14049)
    - It's \_log not log and we don't need the undefined variable prefix [(#14846)](https://github.com/ManageIQ/manageiq/pull/14846)
    - Reload the ems object in the event catcher if we fail to start [(#14736)](https://github.com/ManageIQ/manageiq/pull/14736)
    - Add multiline to ssh attribute [(#14707)](https://github.com/ManageIQ/manageiq/pull/14707)
    - Create/update Tower project with scm_credential [(#14618)](https://github.com/ManageIQ/manageiq/pull/14618)
    - Nullify dependents when destroying configuration_script_sources/configuration_scripts [(#14567)](https://github.com/ManageIQ/manageiq/pull/14567)
    - Use organization instead of organization_id when talking to Tower [(#14538)](https://github.com/ManageIQ/manageiq/pull/14538)
    - Fix task name for task that create Tower project [(#14656)](https://github.com/ManageIQ/manageiq/pull/14656)
    - An Ansible Tower "Inventory" is a ManageIQ "InventoryRootGroup" [(#14716)](https://github.com/ManageIQ/manageiq/pull/14716)
    - Fix for  External Automation Manager Inventory Group [(#14691)](https://github.com/ManageIQ/manageiq/pull/14691)
    - Notification after Tower credential CUD operations [(#14625)](https://github.com/ManageIQ/manageiq/pull/14625)
    - Product features for embedded ansible refresh [(#14664)](https://github.com/ManageIQ/manageiq/pull/14664)
  - Console: Added missing parameter when requesting OpenStack remote console ([#13558](https://github.com/ManageIQ/manageiq/pull/13558))
  - Containers
    - Container Volumes should honor tag visibility [(#14517)](https://github.com/ManageIQ/manageiq/pull/14517)
    - Fix queueing of historical metrics collection [(#14695)](https://github.com/ManageIQ/manageiq/pull/14695)
    - Identifying container images by digest only [(#14185)](https://github.com/ManageIQ/manageiq/pull/14185)
    - Create a hawkular client for partial endpoints [(#13814)](https://github.com/ManageIQ/manageiq/pull/13814)
    - Container managers #connect: don't mutate argument [(#13719)](https://github.com/ManageIQ/manageiq/pull/13719)
    - Fix creating Kubernetes or OSE with `credentials.auth_key` [(#13317)](https://github.com/ManageIQ/manageiq/pull/13317)
  - Google: Ensure google managers change zone and provider region with cloud manager [(#14742)](https://github.com/ManageIQ/manageiq/pull/14742)
  - Metrics: Handle exception when a metrics target doesn't have an ext_management_system [(#14718)](https://github.com/ManageIQ/manageiq/pull/14718)
  - Microsoft Infrastructure
    - Enable VM reset functionality [(#14123)](https://github.com/ManageIQ/manageiq/pull/14123)
    - Ensure remote shells generated by SCVMM are closed when finished [(#14591)](https://github.com/ManageIQ/manageiq/pull/14591)
  - Middleware: Hawkular Allow adding datawarehouse provider with a port other than 80 [(#13840)](https://github.com/ManageIQ/manageiq/pull/13840)
  - OpenStack Cloud Network Router:  Raw commands are wrapped in raw prefixed methods ([#13072](https://github.com/ManageIQ/manageiq/pull/13072))
  - OpenStack Infra: Ssh keypair validation fixes ([#13445](https://github.com/ManageIQ/manageiq/pull/13445))
  - Pluggable: Changing ordering of checks to see if snapshot operations are supported [(#14014)](https://github.com/ManageIQ/manageiq/pull/14014)
  - Red Hat Virtualization
    - Add oVirt cloud-init customization template [(#14139)](https://github.com/ManageIQ/manageiq/pull/14139)
    - Disks should be added as 'active' in RHV [(#13913)](https://github.com/ManageIQ/manageiq/pull/13913)
    - Use the provided database name during metric collection [(#13909)](https://github.com/ManageIQ/manageiq/pull/13909)
    - Fix authentication of metrics credentials in RHV [(#13981)](https://github.com/ManageIQ/manageiq/pull/13981)
    - Set timeout for inventory refresh calls [(#14245)](https://github.com/ManageIQ/manageiq/pull/14245)
    - Fix Host getting disconnected from Cluster when migrating a VM in  [(#13815)](https://github.com/ManageIQ/manageiq/pull/13815)

- REST API
  - Allow partial POST edits on miq policy REST [(#14518)](https://github.com/ManageIQ/manageiq/pull/14518)
  - Return provider_class on provider requests [(#14657)](https://github.com/ManageIQ/manageiq/pull/14657)
  - Return correct resource hrefs [(#14549)](https://github.com/ManageIQ/manageiq/pull/14549)
  - Removing ems_events from config/api.yml [(#14699)](https://github.com/ManageIQ/manageiq/pull/14699)
  - Ensure actions are returned correctly in the API [(#14033)](https://github.com/ManageIQ/manageiq/pull/14033)
  - Return result of destroy action to user not nil [(#14097)](https://github.com/ManageIQ/manageiq/pull/14097)
  - Convey a useful message to queue_object_action [(#13710)](https://github.com/ManageIQ/manageiq/pull/13710)
  - Fix load balancers access in API [(#13866)](https://github.com/ManageIQ/manageiq/pull/13866)
  - Fix cloud networks access in API [(#13865)](https://github.com/ManageIQ/manageiq/pull/13865)
  - Fix schedule access in API [(#13864)](https://github.com/ManageIQ/manageiq/pull/13864)

- SmartState
  - Timeout was not triggered for Image Scanning Job after removing Job#agent_class [(#14791)](https://github.com/ManageIQ/manageiq/pull/14791)

- User Interface
  - Fix mixed values in Low and High operating ranges for CU charts [(#14324)](https://github.com/ManageIQ/manageiq/pull/14324)
  - Revert "Remove unneeded include from reports" [(#14439)](https://github.com/ManageIQ/manageiq/pull/14439)
  - Added missing second level menu keys for Storage menu [(#14145)](https://github.com/ManageIQ/manageiq/pull/14145)
  - Update spice-html5-bower to 1.6.3 fixing an extra GET .../null request [(#13889)](https://github.com/ManageIQ/manageiq/pull/13889)
  - Add the Automation Manager submenu key to the permission yaml file [(#13931)](https://github.com/ManageIQ/manageiq/pull/13931)
  - Added missing Automate sub menu key to permissions yml. [(#13819)](https://github.com/ManageIQ/manageiq/pull/13819)

# Euwe-3

## Added

### Automate
- Allow passing options when adding a disk in automate. [(#14350)](https://github.com/ManageIQ/manageiq/pull/14350)
- Added container components for service model. ([#12863](https://github.com/ManageIQ/manageiq/pull/12863))
- Services
  - Add automate engine support for array elements containing text values. ([#11667](https://github.com/ManageIQ/manageiq/pull/11667))
  - Add multiselect option to dropdowns [(#10270)](https://github.com/ManageIQ/manageiq/pull/10270)

### Platform
- Authentication: Ensure user name is set even when common LDAP attributes are missing. [(#14142)](https://github.com/ManageIQ/manageiq/pull/14142)
- Chargeback
  - Add tenant scoping for resources of performance reports in RBAC [(#14095)](https://github.com/ManageIQ/manageiq/pull/14095)
  - Enterprise rate parent for containers chargeback [(#14079)](https://github.com/ManageIQ/manageiq/pull/14079)
- RBAC: Add RBAC for rss feeds [(#14041)](https://github.com/ManageIQ/manageiq/pull/14041)

### Providers
- Openstack
  - Add openstack excon settings [(#14172)](https://github.com/ManageIQ/manageiq/pull/14172)
  - Add :event_catcher_openstack_service setting [(#13985)](https://github.com/ManageIQ/manageiq/pull/13985)
- Red Hat Virtualization Manager: Resolve oVirt IP addresses [(#13767)](https://github.com/ManageIQ/manageiq/pull/13767)

## Changed

### Performance
- Optimize number of transactions sent in refresh [(#14670)](https://github.com/ManageIQ/manageiq/pull/14670)
- Make Widget run without timezones [(#14386)](https://github.com/ManageIQ/manageiq/pull/14386)
- Speed up widget generation [(#14224)](https://github.com/ManageIQ/manageiq/pull/14224)

### Platform
- RBAC: Remove admin role for tenant admin [(#14081)](https://github.com/ManageIQ/manageiq/pull/14081)
- Reporting: Support dots and slashes in virtual custom attributes [(#14329)](https://github.com/ManageIQ/manageiq/pull/14329)

## Fixed

### Automate
- Provisioning: Add multiple_value option to expose_eligible_resources. [(#13853)](https://github.com/ManageIQ/manageiq/pull/13853)
- Services
  - Fixes tag control multi-value [(#14382)](https://github.com/ManageIQ/manageiq/pull/14382)
  - Power state for services that do not have an associated service_template [(#13785)](https://github.com/ManageIQ/manageiq/pull/13785)

### Platform
- Appliance: Move the call to reload ntp settings to the server only [(#14208)](https://github.com/ManageIQ/manageiq/pull/14208)
- Chargeback: Do not pass nil to the assignment mixin [(#14713)](https://github.com/ManageIQ/manageiq/pull/14713)
- Fix "Multiple Parents Found" issue when moving a relationship. [(#14060)](https://github.com/ManageIQ/manageiq/pull/14060)
- Workers
  - Make worker_monitor_drb act like a reader again! [(#14638)](https://github.com/ManageIQ/manageiq/pull/14638)
  - Fix missing reason constants [(#13919)](https://github.com/ManageIQ/manageiq/pull/13919)
  - Add balancer members after configs have been written [(#14311)](https://github.com/ManageIQ/manageiq/pull/14311)
  - Rescue worker class sync_workers exceptions and move on [(#13976)](https://github.com/ManageIQ/manageiq/pull/13976)
  - Configure apache balancer with up to 10 members at startup [(#14007)](https://github.com/ManageIQ/manageiq/pull/14007)
  - If we can't update_attributes on a queue row set state to error [(#14365)](https://github.com/ManageIQ/manageiq/pull/14365)

### Performance
- Optimize store_ids_for_new_records by getting rid of the O(n^2) lookups [(#14542)](https://github.com/ManageIQ/manageiq/pull/14542)

### Providers
- Containers
  - Delegate custom attributes to images in ChargebackContainerImage [(#14395)](https://github.com/ManageIQ/manageiq/pull/14395)
  - Fix queueing of historical metrics collection [(#14695)](https://github.com/ManageIQ/manageiq/pull/14695)
  - Identifying container images by digest only [(#14185)](https://github.com/ManageIQ/manageiq/pull/14185)
  - Container Project reports: add archived Container Groups [(#13810)](https://github.com/ManageIQ/manageiq/pull/13810)
- Metrics
  - Split metric collections into smaller intervals [(#14332)](https://github.com/ManageIQ/manageiq/pull/14332)
  - Handle exception when a metrics target doesn't have an ext_management_system [(#14718)](https://github.com/ManageIQ/manageiq/pull/14718)
- Microsoft: SCVMM - Enable VM reset functionality [(#14123)](https://github.com/ManageIQ/manageiq/pull/14123)
- Openstack: Set the raw power state when starting Openstack instance [(#14122)](https://github.com/ManageIQ/manageiq/pull/14122)
- Red Hat Virtualization Manager
  - Set timeout for inventory refresh calls [(#14245)](https://github.com/ManageIQ/manageiq/pull/14245)
  - Add oVirt cloud-init customization template [(#14139)](https://github.com/ManageIQ/manageiq/pull/14139)
  - Fix authentication of metrics credentials in RHV [(#13981)](https://github.com/ManageIQ/manageiq/pull/13981)

### SmartState
- Add the logic to allow a policy to prevent request_vm_scan. [(#14370)](https://github.com/ManageIQ/manageiq/pull/14370)

### User Interface (Classic)
- Update spice-html5-bower to 1.6.3 fixing an extra GET .../null request [(#13889)](https://github.com/ManageIQ/manageiq/pull/13889)
- Fix mixed values in Low and High operating ranges for CU charts [(#14324)](https://github.com/ManageIQ/manageiq/pull/14324)

# Euwe-2

## Added

### Automate
- Automate Retry with Server Affinity ([#13543](https://github.com/ManageIQ/manageiq/pull/13543))

### Platform
- Chargeback
  - Chargebacks for SCVMM (rollup-less) ([#13419](https://github.com/ManageIQ/manageiq/pull/13419))
  - Chargebacks for SCVMM (rollup-less) [2/2] ([#13554](https://github.com/ManageIQ/manageiq/pull/13554))
  - Prioritize rate with tag of VM when selecting from more rates ([#13556](https://github.com/ManageIQ/manageiq/pull/13556))
- Reporting: Add option for container performance reports ([#11904](https://github.com/ManageIQ/manageiq/pull/11904))

### Providers
- Ansible Tower: Advanced search for Ansible Tower Jobs not visible on switch from a different tab ([#12717](https://github.com/ManageIQ/manageiq/pull/12717))
- Containers: Common mixin: ui_lookup should get a string ([#13389](https://github.com/ManageIQ/manageiq/pull/13389))
- Microsoft Azure: Delete all resources when deleting an Azure stack ([#24](https://github.com/ManageIQ/manageiq-providers-azure/pull/24))

### User Interface (Classic)
- Ops_rbac - group detail - don't render trees that are not visible ([#13399](https://github.com/ManageIQ/manageiq/pull/13399))
- Launch a URL returned by an automate button ([#13449](https://github.com/ManageIQ/manageiq/pull/13449))
- Remove confirmation when opening the HTML5 vnc/spice console. ([#13465](https://github.com/ManageIQ/manageiq/pull/13465))
- Cloud Network UI: Task queue ([#13416](https://github.com/ManageIQ/manageiq/pull/13416))

## Changed

### Automate
  - Look for resources in the same region as the selected template during provisioning. ([#13045](https://github.com/ManageIQ/manageiq/pull/13045))

### Performance
- Don't lookup category names if tag tree view all ([#13308](https://github.com/ManageIQ/manageiq/pull/13308))

### Platform
- Add list of providers to RBAC on catalog items ([#13395](https://github.com/ManageIQ/manageiq/pull/13395))
- Gem changes
  - Upgrade azure-armrest gem to 0.5.2. [(#13670)](https://github.com/ManageIQ/manageiq/pull/13670)
  - Use version 0.14.0 of the 'ovirt' gem ([#13425](https://github.com/ManageIQ/manageiq/pull/13425))
  - Updated PatternFly to v3.15.0 ([#13404](https://github.com/ManageIQ/manageiq/pull/13404))

### Providers
- Network: Added exception clases for router add/remove interfaces ([#13005](https://github.com/ManageIQ/manageiq/pull/13005))

### User Interface
- UX improvements for attaching Openstack cloud volumes to instances ([#13437](https://github.com/ManageIQ/manageiq/pull/13437))
- Add latest VMRC API version ([#184](https://github.com/ManageIQ/manageiq-ui-classic/pull/184))


## Fixed

Notable fixes include:

### Automate
- Inconsistent attribute names inside Automate Engine ([#13545](https://github.com/ManageIQ/manageiq/pull/13545))
- Allow a service power state to correctly handle nil actions ([#13232](https://github.com/ManageIQ/manageiq/pull/13232))
- Increment the ae_state_retries when on_exit sets retry ([#13339](https://github.com/ManageIQ/manageiq/pull/13339))

### Platform
- Chargeback
  - BigDecimal not working properly on ruby 2.3.1 ([#13634](https://github.com/ManageIQ/manageiq/pull/13634))
  - Skip calculation when there is zero consumed hours ([#13723](https://github.com/ManageIQ/manageiq/pull/13723))
- Tenant admin should not be able to create groups in other tenants. ([#13483](https://github.com/ManageIQ/manageiq/pull/13483))
- Add MiqUserRole to RBAC ([#13689](https://github.com/ManageIQ/manageiq/pull/13689))
- Reporting: Introduce report result purging timer ([#13429](https://github.com/ManageIQ/manageiq/pull/13429))

### Providers
- Hawkular: Adding alt and title attributes for buttons ([#13468](https://github.com/ManageIQ/manageiq/pull/13468))
- RHEV
  - Save host for a Vm after migration ([#13618](https://github.com/ManageIQ/manageiq/pull/13618))
  - Fix Host getting disconnected from Cluster when migrating a VM in RHEV [(#13836)](https://github.com/ManageIQ/manageiq/pull/13836)
  - Disks should be added as 'active' in RHV ([#13913)](https://github.com/ManageIQ/manageiq/pull/13913)
- OpenStack
  - Add Openstack metric service to Settings ([#13918](https://github.com/ManageIQ/manageiq/pull/13918))
  - OpenStack Infra: ssh keypair validation fixes ([#13445](https://github.com/ManageIQ/manageiq/pull/13445))
  - Console: Added missing parameter when requesting OpenStack remote console ([#13558](https://github.com/ManageIQ/manageiq/pull/13558))

### User Interface (Classic)
- Pulled out simulation parameters ([#13472](https://github.com/ManageIQ/manageiq/pull/13472))
- Advanced search not working for the ansible job ([#12719](https://github.com/ManageIQ/manageiq/pull/12719))
- Fix missing Smart State Analysis button on Cloud Instances list view ([#13422](https://github.com/ManageIQ/manageiq/pull/13422))
- Remove disabling of 'instance_retire' button ([#14016)](https://github.com/ManageIQ/manageiq/pull/14016)
- Fix Snapshot revert ([#13986)](https://github.com/ManageIQ/manageiq/pull/13986)
- Make created filters in Datastores visible and fix commiting filters ([#13621](https://github.com/ManageIQ/manageiq/pull/13621))
- Add missing icons for provider policies & compliance events ([#13502](https://github.com/ManageIQ/manageiq/pull/13502))
- Allow configuration managers providers and configuration scripts trees to display the advanced search box ([#13763](https://github.com/ManageIQ/manageiq/pull/13763))
- Cloud Subnet UI: Task queue validation buttons ([#13490](https://github.com/ManageIQ/manageiq/pull/13490))
- Tenant admin should not be able to create groups in other tenants. ([#151](https://github.com/ManageIQ/manageiq-ui-classic/pull/151))
- Floating IPs: Adds missing route for wait_for_task ([#192](https://github.com/ManageIQ/manageiq-ui-classic/pull/192))
- Fix valid_tenant check in ops ([#203](https://github.com/ManageIQ/manageiq-ui-classic/pull/203))
- Red Hat Enterprise Virtualization: Removed the option to migrate the VMs outside of the cluster. ([#207](https://github.com/ManageIQ/manageiq-ui-classic/pull/207))
- Fix check_box_tag parameters for snap_memory ([#217](https://github.com/ManageIQ/manageiq-ui-classic/pull/217))
- Add list of roles to rbac ([#271)](https://github.com/ManageIQ/manageiq-ui-classic/pull/271)
- Fix assigning roles in group form ([#296)](https://github.com/ManageIQ/manageiq-ui-classic/pull/296)
- Fix repeating values on Y-axis of C&U charts ([#40](https://github.com/ManageIQ/manageiq-ui-classic/pull/40))

# Euwe-1

## Added

### Automate

- Automate Model
  - Added top_level_namespace to miq_ae_namespace model to support filtering for pluggable providers
  - Added /System/Process/MiqEvent instance
  - Class Schema allows for EMS, Host, Policy, Provision, Request, Server, Storage, and VM(or Template) datatypes
    - Value is id of the objects
    - If object is not found, the attribute is not defined.
  - Import Rake task `OVERWRITE` argument: Setting  `OVERWRITE=true` removes the target domain prior to import
  - Null Coalescing Operator
    - Multiple String values separated by “||”
    - Evaluated on new attribute data type “Null Coalescing”
    - Order dependent, left to right evaluation
    - First non-blank value is used
    - Skip and warn about missing objects
- Generic Objects
  - Model updates
    - Associations
    - Tagging
  - Service Methods: `add_to_service / remove_from_service`
  - Service models created for GenericObject and GenericObjectDefinition
  - Process Generic Object method call via automate
  - Methods content stored in Automate
    - Generic Object Definition model contains the method name only (Parameters defined in automate)
    - Methods can return data to caller
    - Methods can be overridden by domain ordering
- Git Automate support
  - Branch/Tag support
  - Contents are locked and can be copied to other domains for editing
  - Editable properties
    - Enabled/Disabled
    - Priority
    - Removal of Domain
    - Dedicated Server Role to store the repository
- Methods
  - `extend_retires_on` method: Used by Automate methods to set a retirement date to specified number of days from today, or from a future date.
  - `taggable?` to programmatically determine if a Service Model class or instance is taggable.
  - Added $evm.create_notification
- Provisioning
  - Service Provisioning: Exposed number_of_vms when building the provision request for a service
  - Filter networks and floating_ips for OpenStack provisioning
  - Added Google pre and post provisioning methods
  - Enabled support for vApp provisioning service
  - Backend support to enable VMware provisioning through selection of a DRS-enabled cluster instead of a host
  - Set VM storage profile in provisioning
  - Show shared networks in the OpenStack provisioning dialog
  - Enhanced messaging for provisioning: Displayed elements
    - ManageIQ Server name
    - Name of VM/Service being provisioned
    - Current Automate state machine step
    - Status message
    - Provision Task Message
    - Retry count (when applicable)
  - Set zone when deliver a service template provision task
- Reconfigure: Route VM reconfigure request to appropriate region
- Retirement
  - Restored retirement logic to verify that VM was provisioned or contains Lifecycle tag before processing
  - Built-in policy to prevent retired VM from starting on a resume power
  - Added lifecycle tag as a default tag
  - Schema change for Cloud Orchestration Retirement class
  - Added Provider refresh call to Amazon retire state machine in Pre-Retirement state
- Service Dialogs
  - Added ‘Visible’ flag to all dialog fields
  - Support for “visible” flag for dynamic fields
- Service Models - New
  - Compliance: `expose :compliance_details`
  - ComplianceDetail: `expose :compliance`, `expose :miq_policy`
  - MiqAeServicePartition
  - MiqAeServiceVolume
  - GenericObject
  - GenericObjectDefinition
- Service Models - Updates
    - MiqAeServiceServiceTemplateProvisionTask updated to expose provision_priority value
    - MiqAeServiceHardware updated to expose a relationship to partitions.
    - Added cinder backup/restore actions
    - New associations on VmOrTemplate and Host models
      - `expose :compliances`
      - `expose :last_compliance`
    - Expose ems_events to Vm service model
    - Expose a group's filters.

- Services
  - Set default entry points for non-generic catalog items
  - Service resolution based on Provision Order
  - Log properly dynamic dialog field script error
  - Back-end support for Power Operations on Services
    - Service Items: Pass start/stop commands to associated resources.
    - Service Bundles: Honor bundle resource configuration for start/stop actions
    - Created service_connections table to support connecting services together along with metadata

### Platform

- Centralized Administration
  - Server to server authentication
  - Invoke tasks on remote regions
  - Leverage new API client (WIP)
  - VM power operations
  - VM retirement
- Chargeback
  - Support for generating chargeback for services
  - Will be used in Service UI for showing the cost of a service
  - Generate monthly report for a Service
  - Daily schedule generates report for each Service
  - Enables SUI display of Service costs over last 30 days
  - Containers
    - Added a 'fixed_compute_metric' column to chargeback
    - Added rate assigning by tags to container images
    - Chargeback vm group by tag
- Database Maintenance
  - Hourly reindex: High Churn Tables
  - Periodic full vacuum
  - Configure in appliance console
  - Database maintenance scripts added to appliance
- Notifications
  - Dynamic substitution in notification messages
  - Generate for Lifecycle events
  - Model for asynchronous notifications
  - Authentication token generation for web sockets
  - API for notification drawer
- PostgreSQL High Availability
  - Added [repmgr](http://repmgr.org/)  to support automatic failover
    - Maintain list of active standby database servers
    - Added [pg-dsn_parser](https://github.com/ManageIQ/pg-dsn_parser) for converting DSN to a hash
  - DB Cluster - Primary, Standbys
  - Uses [repmgr](http://www.repmgr.org/) (replication)
  - Failover
    - Primary to Standby
    - Appliance connects to new primary DB
    - Primary/Standby DB config in Appliance Console
    - Database-only appliance config in Appliance Console
    - Failover Monitor
    - Raise event when failover successful
- Replication: Add logging when the replication set is altered
- Reporting
  - Watermark reports updated to be based on max of daily max value instead of max of average value
  - Custom attributes support in reporting and expressions
    - Selectable as a column
    - Usable in report filters and charts
- Tenancy
  - Groundwork in preparation for supporting multiple entitlements
  - ApplicationHelper#role_allows and User#role_allows? combined and moved to RBAC
  - Added parent_id to CloudTenant as prerequisite for mapping OpenStack tenants to ManageIQ tenants
  - Mapping Cloud Tenants to ManageIQ Tenants
    - Prevent deleting mapped tenants from cloud provider
    - Added checkbox "Tenant Mapping Enabled" to Openstack Manager
    - Post refresh hook to queue mapping of Cloud Tenants
- Appliance Console: Removed menu items that are not applicable when running inside a container
- Nice values added to worker processes

### Providers

- Core
  - Override default http proxy
  - Known features are discoverable
  - Every known feature is unsupported by default
  - Allow Vm to show floating and fixed ip addresses
  - Generate a csv of features supported across all models
- Amazon: Public Images Filter
- Ansible Tower
  - Collect Job parameters during Provider Refresh
  - Log Ansible Tower Job output when deployment fails
- Containers
  - Persist Container Templates
  - Reports: Pods for images per project, Pods per node
  - Deployment wizard
  - Models for container deployments
  - Limit number of concurrent SmartState Analyses
  - Allow policies to prevent Container image scans
  - Chargeback rates based on container image tags
  - Keep pod-container relationship after disconnection
  - Label based Auto-Tagging UI
- Google Compute Engine
  - Use standard health states
  - Provision Preemptible VMs
  - Preemptible Instances
  - Retirement support
  - Metrics
  - Load Balancer refresh
- Middleware (Hawkular)  
  - JMS support (entities, topology)
  - Reports for Transactions (in App servers)
  - Support micro-lifecycle for Middleware-deployments
  - Alerts
    - Link miq alerts and hawkular events on the provider
    - Convert ManageIQ alerts/profiles to hawkular group triggers/members of group triggers
    - Sync the provider when ManageIQ alerts and alert profiles are created/updated
    - Support for alert profiles and alert automated expressions
  - Added entities: Domains and Server Groups including their visualization in topology
  - Datasource entity now has deletion operation
  - Cross linking to VMs added to topology
  - Operations: Add Deployment, Start/stop deployment
  - Performance reports for datasources
  - Collect more metrics for datasources
  - Deployment entity operations: Undeploy, redeploy
  - Server operations: Reload, suspend, resume
  - Live metrics for datasources and transactions
  - Performance reports for middleware servers
  - Crosslink middleware servers with RHEV VMs
  - Collect and display deployment status
  - Datasources topology view
  - Added missing fields in UI to improve user experience
  - Middleware as top level menu item
  - Default view for Middleware is datasource
  - Change labels in middleware topology
  - Added "Server State" into Middleware Server Details
  - Enabled search for Middleware entities
  - Users can add Middleware Datasources and JDBC Drivers
  - Metrics for JMS Topics and Queues
  - Add support to overwrite an existing deployment
- Kubernetes: Cross-linking with OpenStack instances
- Microsoft Cloud (Azure)
  - Handle new events: Create Security Group, VM Capture
  - Provider-specific logging
  - Added memory and disk utilization metrics
  - Support floating IPs during provisioning
  - Load Balancer inventory collection for Azure
  - Pagination support in armrest gem
- Microsoft Infrastructure (SCVMM): Set CPU sockets and cores per socket
- Networking
  - Allow port ranges for Load Balancers
  - Load Balancer user interface
  - Separate Google Network Manager
  - NFV: VNFD Templates and VNF Stacks
  - Nuage: Inventory of Managed Cloud Subnets
  - Nuage policy groups added
    - Load balancer service type actions for reconfigure, retirement, provisioning
  - UI for creating subnets
  - UI for Network elements
- OpenStack
  - Cloud
    - Collect inventory for cloud volume backups
    - UI: Cloud volume backup
    - UI: CRUD for Host Aggregates
    - UI: CRUD for OpenStack Cloud tenants
    - Enable image snapshot
    - Map Flavors to Cloud Tenants during Openstack Cloud refresh
    - Associate/Disassociate Floating IPs
    - Region Support
    - Create provider base tenant under a root tenant
    - Topology
  - Infrastructure
    - Set boot image for registered hosts
    - Node destroy deletes node from Ironic
    - Enable node start and stop
    - Ironic Controls
    - UI to register Ironic nodes through Mistral
    - Topology
- Red Hat Enterprise Virtualization
  - Get Host OS version and type
  - Disk Management in VM Reconfigure
  - Snapshot support
  - Report manufacturer and product info for RHEVM hosts
  - Make C&U Metrics Database a mandatory field for Validation
  - Migrate support
  - Enable VM reconfigure disks for supported version
- Storage
  - New Swift Storage Manager
  - New Cinder Storage Manager
  - Initial User Interface support for Storage Managers
- VMware vSphere
  - Storage Profiles modeling and inventory
  - Datastores are filtered by Storage Profiles in provisioning
- vCloud
  - Collect status of vCloud Orchestration Stacks
  - Add Network Manager
  - Collect networking inventory
  - Cloud orchestration stack operation: Create and delete stack
  - Collect virtual datacenters as availability zones
  - Event Catcher
  - Event monitoring

### REST API

- Support for /api/requests creation and edits
- Token manager supports for web sockets
- Added ability to query virtual machines for cockpit support
- Support for Bulk queries
- Support for UI notification drawer
- API entrypoint returns details about the appliance via server_info
- Support for compressed ids in inbound requests
- CRUD support for Arbitration Rules
- Added GET role identifiers
- Support for arbitrary resource paths
- Support for Arbitration Profiles
- Support for Cloud Networks queries
- Support for Arbitration Settings
- Updated /api/users to support edits of user settings
- Support for report schedules
- Support for approving or denying service requests
- Support for OpenShift Container Deployments
- Support for Virtual Templates
- Added /api/automate primary collection
  - Enhanced to return additional product information for the About modal
  - Bulk queries now support referencing resources by attributes
  - Added ability to delete one’s own notifications
  - Publish Blueprint API
  - Update Blueprint API to store bundle info in ui_properties
  - CRUD for Service create and orchestration template
  - Api for refreshing automate domain from git
  - Allow compressed IDs in resource references

###  Service UI

- Renamed from Self-Service UI due to expanding number of use cases
- Language selections separated from Operations UI
- Order History with detail
- Added Arbitration Rules UI
- Service Designer: Blueprint API
  - Arbitration Profiles
    - Collection of pre-defined settings
    - Work in conjunction with the Arbitration Engine
  - Rules Engine: API
- Added datastore for the default settings for resourceless servers
- Create picture
- Generic requests OPTION method
- API for Delete dialogs
- Cockpit integration: Added About modal
- Set default visibility to true for all dialog fields

### SmartState

- Add /etc/redhat-access-insights/machine-id to the sample VM analysis
- Deployed new MiqDiskCache module for use with Microsoft Azure
  - Scan time reduced from >20 minutes to <5 minutes
  - Microsoft Azure backed read requests reduced from >7000 requests to <1000
- Generalized disk LRU caching module
  - Caching module can be used by any disk module, eliminating duplication.
  - Can be inserted “higher” in the IO path.
  - Configurable caching parameters (memory vs performance)
  - Will be employed to address Azure performance and throttling issues.
  - Other disk modules converted over time.
- Containers: Settings for proxy environment variables
- Support analysis of VMs residing on NFS41 datastores

### User Interface

- Added mandatory Subscription field to Microsoft Azure Discovery screen
- Added Notifications Drawer and Toast Notifications List
- Added support for vSphere Distributed Switches
- Added support to show child/parent relations of Orchestration Stacks
- Added Middleware Messaging entities to topology chart
- Arbitration Profiles management for Service Broker
- Re-check Authentication button added to Provider list views
- Provisioning button added to the Templates & Images list and summary screens
- Subtype option added to Generic Catalog Items
- About modal added to OPS UI
- Both UIs updated to latest PatternFly and Angular PatternFly
- Internationalization
  - Virtual Columns
  - Toolbars
  - Changed to use gettext’s pluralization
  - i18n support in pdf reports
  - i18n support for UI plugins
- Ansible Tower Jobs moved to the Configuration tab (from Clouds/Stacks)
- Interactivity added to C3 charts on C&U screens  
- Settings moved to top right navigation header
- Tagging for Ansible Tower job templates
- Live Search added to bootstrap selects
- Add GUID validation for certain Azure fields in Cloud Provider screen
- OpenStack: Register new Ironic nodes through Mistral
- Timeline resdesign
- vSphere Distributed Switches tagging
- Patternfly Labels for OpenSCAP Results
- Notifications
- Conversion of Middleware Provider form to Angular
- Add UI for generating authorization keys for remote regions
- Topology for Cloud Managers
- Topology for Infrastructure Providers
- Show replication excluded tables to the replication tab in Settings
- Fix angular controller for Network Router and Cloud Subnet

## Changed

### Automate

- Description for Datastore Reset action now includes list of target domains
- Simulation: Updated defaults
  - Entry-point: `/System/Process/Request` (Previous value of “Automation”)
  - Execute Method: Enabled
- Infrastructure Provision: Updated memory values for VM provisioning dialogs to 1, 2, 4, 8, 12, 16, 32 GB
- Generic Object: Model refactoring/cleanup, use PostgreSQL jsonb column
- Changed Automate import to enable system domains
- Google schema changes in Cloud Provision Method class

### Performance

- Page rendering
  - Compute -> Infrastructure -> Virtual Machines: 9% faster, 32% fewer rows tested on 3k active vms and 3k archived vms
  - Services -> My Services: 60% faster, 98% fewer queries, 32% fewer db rows returned
  - Services -> Workloads -> All VMs page load time reduced from 93,770ms to 524ms (99%) with a test of 20,000 VMs
- `OwnershipMixin`
  - Filtering now done in SQL
  - 99.5% faster (93.8s -> 0.5s) testing
    - VMs / All VMs / VMs I Own
    - VMs / All VMs / VMs in My LDAP Group
- Reduced the time and memory required to schedule Capacity and Utilization data collection.
- Capacity and Utlization improvements included reduced number of SQL queries and number of objects
- Improved tag processing for Alert Profiles
- Do not reload miq server in tree builder
- Prune VM Tree folders first, so nodes can be properly prune and tree nodes can then be collapsed
- For resource_pools only bring back usable Resource Pools

### Platform

- Upgrade ruby 2.2.5 to 2.3.1
- Configure Rails web server - Puma or Thin
  - Puma is still the default
  - Planning on adding additional servers
- Expression refactoring and cleanup with relative dates and times
- Set appliance "system" memory/swap information
- PostgreSQL upgraded to 9.5 needed for HA feature
- Performance: Lazy load message catalogs for faster startup and reduced memory
- Replication: Added "deprecated" in replication worker screen (Rubyrep replication removed in Euwe release)
- Tenancy: Splitting MiqGroup
  - Filters moved to to Entitlement model
  - Enabler for sharing entitlements   
- MiqExpression Refactoring
- LDAP: Allow apostrophes in email addresses

### Providers

- Core
  - Remove provider specific constants
  - Ask whether provider supports VM architecture instead of assuming support by provider type
- Ansible: Automate method updated to pass JobTemplate “Extra Variables” defined in the Provision Task
- Hawkular
  - Upgrade of Hawkular gem to 2.3.0
  - Skip unreachable middleware providers when reporting
  - Add re-checking authentication status functionality/button
  - Refactor infrastructure for easier configuration
  - Optimization and enhancement of event fetching
- Microsoft SCVMM: Set default security protocol to ssl
- vSphere Host storage device inventory collection improvements

### REST API

- Updated /api entrypoint so collection list is sorted
- API CLI moved to tools/rest_api.rb
- Update API CLI to support the HTTP OPTIONS method

### User Interface

- Dynatree replaced with bootstrap-treeview
- Converted to TreeBuilder - Snapshot, Policy, Policy RSOP, C&U Build Datastores and Clusters/Hosts, Automate Results
- CodeMirror version updated (used for text/yaml editors)
- Default Filters tree converted to TreeBuilder - more on the way
- Cloud Key Pair form converted to AngularJS
- Toolbars:Cleaned up partials, YAML -> classes
- Provider Forms: Credentials Validation improvements
- Updated PatternFly to v3.11.0
- Summary Screen styling updates

## Removed

- Platform
  - Removed rubyrep
  - Removed hourly checking of log growth and rotation if > 1gb
- User Interface: Explorer Presenter RJS removal

## Fixed

Notable fixes include:

### Automate

- Fixed case where user can't add alerts
- Fixed issue where alerts don't send SNMP v1 traps
- Fixed problem with request_pending email method
- Set User.current_user in Automation Engine to fix issue where provisioning resources were not being assigned to the correct tenant
- Provisioning
  - VMware Infrastructure: sysprep_product_id field is no longer required
  - Provisioned Notifications - Use Automate notifications instead of event notifications.
- Fixed ordering ae_domains for a root tenant
- Set default value of param visible to true for all field types
- Git Domains
  - When a domain is deleted, also delete git based bare repository on the appliance with the git owner server role
  - Only enable git import submit button when a branch or tag is selected

### Platform

-  Authentication
  - Support a separate auth URL for external authentication
  - Remove the FQDN from group names for external authentication
- Use correct adjustment in chargeback reports
- Replication
  - Add repmgr tables to replication excludes
  - Don't consider tables that are always excluded during the schema check
  - Fix typo prevention full error message
- Tenancy: User friendly tenant names
- Perform RBAC user filter check on requested ids before allowing request
- Increase worker memory thresholds to avoid frequent restarts
- Send notifications only when user is authorized to see referenced object
- Increase  web socket worker's pool size

### Providers

- Fix targeted refresh of a VM without its host clearing all folder relationships
- Containers: Ability to add a container provider with a port other than 8443
- Microsoft Azure: Fix proxy for template lookups
- VMware vSphere: Block duplicate events
- VMware: Fix for adding multiple disks
- Openstack
  - Catch unauthorized exception in refresh
  - Add logs for network and subnet CRUD
  - Remove port_security_enabled from attributes passed to network create
- Middleware: Fix operation timeout parameter fetch
- Red Hat Enterprise Virtualization
  - Access VM Cluster relationship correctly
  - Pass storage domains collection in disks RHV api request
  - Require a description when creating Snapshot

### REST API

- Hide internal Tenant Groups from /api/groups
- Raise 403 Forbidden for deleting read-only groups
- API Request logging
- Fix creation of Foreman provider
- Ensure api config references only valid miq_product_features

### SmartState

- Update logging and job error message when getting the service account for Containers

### User Interface

- Add missing Searchbar and Advanced Search button
- Containers: Download to PDF/CSV/Text - don't download deleted containers
- Ability to bring VM out of retirement from detail page
- Inconsistent menus in Middleware Views
- Save Authentication status on a Save
- RBAC:List only those VMs that the user has access to in planning
- Enable Provision VMs button via relationships
- Missing reset button for Job Template Service Dialog
- Fix for custom logo in header
- Fall back to VMRC desktop client if no NPAPI plugin is available
- Default Filters can be saved or reset
- Prevent service dialog refreshing every time a dropdown item is selected
- RBAC: Add Storage Product Features for Roles
- Set categories correctly for policy timelines

# Darga

## Added

### Automate
- Ansible Tower added as Configuration Management Provider
  - Modeling for AnsibleTowerJob
  - Support for launching JobTemplates with a limit. (Target specific system)
  - Modeling for Provider, Configuration Manager, and Configured Systems
  - Provider connection logic
  - Support refresh of Configured Systems
  - `wait_for_ip` method added to state-machine
  - [ansible_tower_client](https://github.com/ManageIQ/ansible_tower_client) gem
     - Credential validation
     - Supported resources: Hosts, JobTemplates, Adhoc commands
  - Support for generating Service Dialogs from Ansible Tower JobTemplate
  - Support for setting Ansible Tower JobTemplate variables through dialog options and automate methods
- Switchboard events for OpenStack
    - New Events: compute.instance.reboot.end, compute.instance.reset.end, compute.instance.snapshot.start
    - Policy Event updates: compute.instance.snapshot.end, compute.instance.suspend
- Service Model
  - Added “networks” relationship to Hardware model
  - Support where method, find_by, and find_by!
  - Azure VM retirement modeling added
  - Storage: Added storage_clusters association
  - Openstack::NetworkManager::Network
       - cloud_subnets
       - network_routers
       - public_networks
  - Openstack Event compute.instance.power_on.end: added Policy event for vm_start

- Services
  - Added instances/methods to generate emails for consolidated quota (Denied, Pending, Warning)
  - Enhanced Dialogs validation at build time to check tabs, and boxes in addition to fields.
- Modeling changes
  - quota_source_type moved into instance
  - Added Auto-Approval/Email to VM Reconfigure
  - Default Retirement state-machine behavior changed to retain record (historical data)
  - Enhance state-machine fields to support methods
- New model for Generic Object
- New service model Account
- SSUI: Support dialogs with dynamic fields
- Simulate UI support for state machine retries
- New script to rebuild provision requests
     -  Reconstructs the parameters of an existing provision request so that request can be resubmitted through a REST API or Automate call.


### Platform (Appliance)
- Chargeback
  - Able to assign rates to tenants
  - Can generate reports by tenant
  - Currencies added to rates
  - Rate tiers
- Authentication
  - Appliance Console External Auth updated to also work with 6.x IPA Servers
  - SAML Authentication (verified with KeyCloak 1.8)
  - External Authentication with IPA: Added support for top level domains needed in test environments
- Configuration Revamp
  - Relies heavily on the config gem
  - New classes Settings and Vmdb::Settings
  - `VMDB::Config` is deprecated
  - `config/*.tmpl.yml` -> `config/settings.yml`
  - Locally override with `config/settings.local.yml` or `config/settings/development.local.yml`
- Replication (pglogical)
    - Replacement of rubyrep with pglogical
    - New MiqPglogical class: provides generic functionality for remote and global regions
  - New PglogicalSubscription model: Provides global region functionality as an ActiveRecord model
  - Global and Remote regions instead of Master and subordinate
  - Replication enabled on remote regions
  - Remote regions subscribed to on Global Region
  - Replication Database Schema
    - Column order is important for pglogical
    - Regional and Global DBs MUST have identical schemas
     - Migrations must have timestamp later than the last migration of previous version for correct column order
     - Specs added to validate schema
     - See [New Schema Specs for New Replication](http://talk.manageiq.org/t/new-schema-specs-for-new-replication/1404)
  - Schema consistency checking - during configuration
and before subscription is enabled
  - Tool to fix column order mismatches
- Appliance Console
  - Ability to reset database
  - Ability to create region in external database
  - Added alias 'ap' as shortcut for appliance_console
  - Updates for external authentication settings
- Shopping cart model for ordering services
- Consumption_administrator role with chargeback/reporting duties
- Expresions: refactor SQL for all operators now build with Arel

### Providers
- New provider types
  - Middleware
  - Networking
- Amazon as a pluggable provider: almost completed
- Containers
    - Reports
    - Linking registries with services
    - Bug fixes and UI updates
    - Network Trends, Heat Maps, Donuts
    - Chargeback
    - SmartState extended with OpenSCAP support
    - Policies
    - Cloud Cross Linking
    - Pod Network Metrics
    - Persistent Volume Claims
    - Seed for policies, policy sets, policy contents and conditions
    - Auto-tagging from kubernetes labels (backend only)
    - MiqAction to annotate container images as non-secure at
    - Multiple endpoint support OpenShift
- Google Compute Engine
  - Inventory
  - Power Operations
  - Provisioning
  - Events
  - Better OS identification for VMs
  - Allow custom flavors
- Hawkular
  - First Middleware provider
  - Inventory and topology
  - Event Catcher and power operations to reload and stop Middleware servers
  - Capacity and Utilization collected live on demand without need for Cap and U workers
  - Links to provider and entity in event popups on Timelines
     - Ability to configure default views
     - New Datasource entity (UI and Backend only)
- Microsoft Azure
  - Http proxy support
  - Provisioning
  - Subscriptions and Events
  - Rely on resource location, metrics
- Microsoft SCVMM
  - Inventory Performance improvements
  - Ability to delete VMs
- VMware
  - Read-only datastores
  - Clustered datastores
  - Add/remove disk methods for reconfigure
- Red Hat Enterprise Virtualization: Targeted refresh process
- Red Hat OpenStack
  - Instance Evacuation
  - Better neutron modeling
  - Ceilometer events
  - cleanup SSL support
  - VM operations
  - Memory metrics
  - Image details
  - API over SSL
  - Integration feaures
     - Backend support for Live VM Migration
     - Backend support for VM resize
     - Support for Cinder and Glance v2
  - Enable / Disable cloud services
  - Make Keystone V3 Domain ID Configurable
  - File upload for SSH keypair
  - Add volumes during provisioning
  - Evacuating instances
- Continued work on Multi-endpoint modeling
- Generic Targeted refresh process

### Provisioning
- New providers able to be provisioned
  - Google Compute Engine
  - Microsoft Azure
- Services Back End
  - Service Order (Cart) created for each Service Request based on current user and tenant.
- VMware
  - Clustered Datastores in Provisioning
  - Distributed Switches referenced from database during provisioning workflow
- Google Compute Engine: Added Google Auto-Placement methods

### REST API
- Enhanced filtering to use MiqExpression
- Enhanced API to include Role identifiers for collections and augmented the authorization hash in the entrypoint to include that correlation
- Added support for Service Reconfigure action
- Added new service orders collection and CRUD operations
- Actions for instances: stop, start, pause, suspend, shelve, reset, reboot guest
- Actions provided to approve or deny provision requests
- Ability to delete one’s own authenticated token
- Added primary collection for Instances.
- Added terminate action for instances.
- Ability to filter string equality/inequality on virtual attributes.
- For SSUI, ability to retrieve user’s default language
 and support for Dynamic Dialogs.
- Support for Case insensitive sorting
- Adding new VM actions
- Authentication: Option to not extend a token’s TTL
- CRUD for Tenant quotas
- Support for /api/settings
- Added support for Shopping Carts
- Automation Requests approve and deny actions

### SmartState
- Microsoft SCVMM: new
  - Virtual hard disks residing on Hyper-V servers
  - VHD, and newer VHDX disk formats
  - Snapshotted disks
  - Same filesystems as other providers
  - Support for network-mounted HyperV virtual disks and performance improvements (HyperDisk caching)
- Microsoft Azure: new
  - Azure-armrest: added offset/length blob read support.
  - Added AzureBlobDisk module for MiqDisk.
  - Implemented MiqAzureVm subclass of MiqVm.
- Testing: Added TestEnvHelper class for gems/pending.  
- LVM thin volume support

### Tenancy
- Splitting MiqGroup
- New model created for entitlements
- Sharing entitlements across tenants will provide more flexibility for defining groups in LDAP
- Added scoping strategy for provision request
- Added ability to report on tenants and tenant quotas

### User Interface
- VM: Devices and Network Adapters
- Cloud: Key Pairs, Object Stores, Objects, Object Summary
- Bootstrap switches
- C3 Charts (jqPlot replacement)
- SSUI
  - RBAC Control of Menus and Features
  - Reconfiguring a Service
  - Set Ownership of a Service
  - i18n support added to the Self Service UI
  - Self Service UI group switcher
  - Support for Custom Buttons that use Dialogs
  - Navigation bar restyled to match Operations UI
  - HTML5 Console support for Service VMs (using new console-proxy implementation)
  - Shopping Cart
- Add Ansible Tower providers
- Containers
  - Persistent volumes, topology context menus
  - Dashboard network trends
  - Container environment variables table
  - Search functionality for Container topology
  - Dashboard no data cards
  - Refresh option in Configuration dropdown
  - Container Builds tab, Chargeback  
- i18n
  - Marked translated strings directly in UI
  - Gettext support
  - i18n for toolbars
- Topology Status Colors
- Vertical navigation menus
- VM Reconfigure - add/remove disks
- Orderable Orchestration Templates - create and copy
- Explorer for Datastore Clusters for VMware vSphere 5+
- Template/Image compliance policy checking (previously only allowed for VMs/Instances)
- New UI for replication configuration
- OpenStack - Cloud Volumes Add/Delete/Update/Attach/Detach
- Ansible Inventories/Configured Systems
- Support for Ansible Tower Jobs
- Support to add Service Dialog for a Job Template & display Surveys on summary screen
- Support added for Evacuate Openstack VMs

## Removed

- Providers: Removed Amazon SDK v1

## Notable Fixes and Changes

- Tag management cleanup
  - Tags are removed from managed filters for all groups after deletion
  - Update of managed filters after tag rename (in progress)
- SmartState Analysis
  - LVM thin volume - fatal error: No longer fatal, but not supported. Thin volume support planned.
  - LVM logical volume names containing “-”: LV name to device file mapping now properly accounts for “-”
  - EXT4 - 64bit group descriptor: Variable group descriptor size correctly determined.
  - Collect services that are symlinked
- Automate
  - Retirement state-machine updates for SCVMM
  - Enhanced .missing method support
     - Save original method name in `_missing`_instance property
     - Accessible during instance resolution and within methods
- [Self Service UI](https://github.com/ManageIQ/manageiq-ui-self_service) extracted into its own repository setting up pattern for other independent UIs
  -  Initializers can now load ApplicationController w/o querying DB
  -  10-20% performance improvement in vm explorer
- User Interface
  - Converted toolbar images to font icons
  - Enabled font icon support in list views
  - Implemented Bootstrap switch to replace checkboxes
  - SVG replacement of PNGs
  - SlickGrid replaced with Patternfly TreeGrid
  - Patternfly style updates to the Dashboard and other areas
  - Updates to support multiple provider endpoints
  - Moved Services to top level Menus
- Logo image on top left links to user's start page
- VM Provisoning: Disabled Auto-Placement logic for create_provision_request and Rest API calls
- Performance
  - Support for sorting Virtual Columns in the database
  - Service Tree improvement
  - RBAC: Ongoing effort to reduce the number SQL queries and quantity of data being transferred
  - Metrics Rollups bug fix
  - Performance capture failure on cloud platforms caused by orphan VMs
  - Reduction in base size of workers
  - Reduction in memory used by EmsRefresh
- Platform
  - Updated to Rails 5 (using Rails master branch until stable branch is cut)
  - Appliance OS updated to CentOS 7.2 build 1511
  - oVirt-metrics gem fixed for Rails 5
  - Log Collection behavior updated
     - Zone depot used if requested on zone and defined. Else, collection disabled
     - Appliance depot used if requested on appliance and defined. Else, collection disabled
  - DB seeding no longer silently catches exceptions
  - Workers forked from main server process instead of spawned
  - Updated to newer [ansible`tower`client gem](https://github.com/ManageIQ/ansible_tower_client)
     - Accessors for Host#groups and #inventory_id
     - Allow passing extra_vars to Job Template launch
     - Added JSON validation for extra_vars
- Providers
  - Memory issues during inventory collection
  - Validating endpoints should not save data


# Capablanca Release

## Added Features

### Providers
- Kubernetes
  - RHEV Integration
  - Events
  - Topology Widget
  - VMware integration
  - Inventory: Replicators, Routes, Projects
  - SmartState Analysis
- Containers
  - Resource Quotas
  - Component Status
  - Introduction of Atomic
-  Namespacing
  - Preparation for pluggable providers
  - OpenStack, Containers
- Amazon: Added M4 and t2.large instance types
- OpenStack
  - Improved naming for AMQP binding queues
  - Shelve VMs
  - Neutron Networking
- Foreman: Exposed additional properties to reporting
- Azure
  - Initial work for Inventory Collection, OAuth2, [azure-armrest gem](https://github.com/ManageIQ/azure-armrest)
  - Azure Provider models
  - Power Operations
- RHEVM: Reconfigure of Memory and CPU
- Orchestration: Reconfiguration
- Reporting on Providers
  - Ability to report on Performance
  - Host Socket and Total VMs metrics
  - Watermark reports available out-of-the-box
- Google Compute Engine
  - New Provider
  - Ability to validate authentication


### Provisioning
- Filter Service Catalog Items during deployment
- OpenStack Shared Networks
  - Identified during inventory refresh
  - Available in the Cloud Network drop-down in Provisioning across all OpenStack Tenants
- Enabled SCVMM Auto placement
- Provision Dialogs: field validation for non-required fields
- Service Dialogs: Auto-refresh for dynamic dialog fields
- Foreman: Filtering of available Configuration Profiles based on selected Configured Systems in provisioning dialog

### User Interface
- Charting by field values
- Cloud Provider editor
  - Converted to Angular
  - Uses RESTful routes
- Orchestration: Stacks Retirement added
- Retirement screens converted to Angular
- DHTMLX menus replaced with Bootstrap/Patternfly menus
- Host editor converted to Angular
- Added donut charts
- Tenancy Roles for RBAC
- Self Service UI is enabled and included in build
- Updated file upload screens

### Event Switchboard
- Initiate event processing through Automate
- Users can add automate handlers to customize event processing
- Centralized event mappings
- Moves provider event mappings from appliance file (config/event_handling.tmpl.yml) into the automate model
- Organization of Events through automate namespaces
- Event handling changes without appliance restarts
- Notes:
  - New events must be added to automate model
  - Built-in event handlers added for performance
  - Requires update of the ManageIQ automate domain

### Tenancy
- Model
  - new Tenant model associations
  - Automate domains
  - Service Catalogs
  - Catalog Items
  - Assign default groups to tenants
  - Assign groups to all VMs and Services
  - Assign existing records to root tenant Provider, Automate Domain, Group, TenantQuota, Vm
  - Expose VM/Templates association on Tenant model
- New Automate Service Models
  - Tenant
  - TenantQuota
- UI
  - RBAC and Roles - Access Roles features exposed
  - New roles created for RBAC
  - Quota Management
- Associate Tenant to Requests and Services
- Update of VM tenant when owning group changes
- Tagging support
- Automate Tenant Quotas
  - Customizable Automate State Machine for validating quotas for Service, Infrastructure, and Cloud
  - Default Setting based on Tenant Quota Model
  - Can be enforced per tenant and subtenants in the UI
  - Selection of multiple constraints (cpu, memory, storage)
  - Limits are enforced during provisioning

### Control
- New Events available for use with Policy
  - Host Start Request
  - Host Stop Request
  - Host Shutdown Request
  - Host Reset Request
  - Host Reboot Request
  - Host Standby Request
  - Host Maintenance Enter Request
  - Host Maintenance Exit Request
  - Host Vmotion Enable Request
  - Host Vmotion Disable Request

### REST API
- Querying Service Template images
- Querying Resource Actions as a formal sub-collection of service_templates
- Querying Service Dialogs
- Querying Provision Dialogs
- Ability to import reports
- Roles CRUD
- Product features collection
- Chargeback Rates CRUD
- Reports run action
- Report results collection
- Access to image_hrefs for Services and Service Templates
- Support for custom action buttons and dialogs
- Categories and tags CRUD
- Support password updates
- Enhancements for Self-Service UI
- Enhancements for Tenancy

### Automate

- Automate Server Role enabled by default
- Configurable Automate Worker added
- State Machine
  - Multiple state machine support
  - Allow for a state to be skipped (on_entry)
  - Allow for continuation of a state machine in case of errors (on_error)
  - Allow methods to set the next state to execute
  - Added support for state machine restart
- Identify Visible/Editable/Enabled Automate domains for tenants
- Set automate domain priority (scoped per tenant)
- Service model updates
- Import/export updates to honor tenant domains

### SmartState
- Support for VMware VDDK version 6
- Storage: Added FCP, iSCSI, GlusterFS

### Security
- Authentication
  - External Auth to AD web ui login & SSO - Manual configuration
  - External Auth to LDAP - Manual configuration
- Supporting Additional External Authentications
  - Appliance tested with 2-Factor Authentication with FreeIPA >= 4.1.0

### Appliance
- PostgreSQL 9.4.1
- CentOS 7.1
- Apache 2.4
- jQuery 1.9.1
- STIG compliant file systems
- Changed file system from ext4 to xfs  
- Added support for systemctl
- Support for running on Puma, but default is Thin
- Reworked report serialization for Rails 4.2
- Replication: Added Diagnostics
- Appliance Console
 - Standard login: type root (not admin)
 - Standard bash: type appliance_console   
- GitHub Repository
 - vmdb rerooted to look like a Rails app
 - lib moved into gems/pending
 - Build and system directories extracted to new repositories
- Extracted C code to external gems
 - MiqLargeFileLinux => [large\_file\_linux]( https://github.com/ManageIQ/large_file_linux) gem
 - MiqBlockDevOps => [linux\_block\_device](https://github.com/ManageIQ/linux_block_device) and [memory\_buffer](https://github.com/ManageIQ/memory_buffer) gems
 - MiqMemory => [memory\_buffer](https://github.com/ManageIQ/memory_buffer) gem
 - SlpLib => [slp](https://github.com/ManageIQ/slp) gem  
- Gem updates
  - Upgraded rufus scheduler to version 3
  - Upgraded to latest net-sftp
  - Upgraded to latest net-ssh  
  - Upgraded to latest ruby-progressbar
  - Upgraded to latest snmp
  - LinuxAdmin updated to 0.11.1    

### Removed

- Core: SOAP server side has been removed

### Notable Fixes and Changes
- RHEVM SmartState Analysis issues.
  - Fix for RHEV 3.5 - ovf file no longer on NFS share.
  - Fix for NFS permission problem - uid changed when opening files on share.
  - Fix for environments with both, NFS and LUN based storage.
  - Timeout honored.
- SmartState Refactoring
   - Refactored the middle layer of the SmartState Analysis stack.
   - Common code no longer based on VmOrTemplate models.
   - Facilitate the implementation of SmartState for things that are not like VMs.
   - Enabler for Container SmartState
- Appliance: Cloud-init reported issues have been addressed.
- Automate: VMware snapshot from automate fixed - memory parameter added
- REST API Source refactoring: app/helpers/api\_helper/ → app/controllers/api_controller
- Replication: Added heartbeating to child worker process for resiliency
- Providers
 - Moved provider event filters into the database (blacklisted events)
 - SCVMM Inventory Performance Improvement
 - Fixed caching for OpenStack Event Monitors
 - OpenStack
    - Generic Pagination
    - Better Neutron support
    - Deleting unused RabbitMIQ queues
- Provisioning: Fixed unique names for provisioned VMs when ordered through a service  
- UI
  - Technical Debt Progress
    - Remaining TreePresenter/ExplorerPresenter conversions in progress
    - Switched from Patternfly LESS to SASS  
    - Replaced DHTMLXCombo controls
    - Replaced DHTMLXCalendar controls
  - Patternfly styling
  - Schedule Editor updated to use Angular and RESTful routes
  - Increased chart responsiveness
  - Fixes for Japanese i18n support
  - Fixed alignment of Foreman explorer RBAC features with the UI
- Chargeback: selectable units for Chargeback Rates

# Botvinnik Release

## Added Features

### Providers
- General
  - Added refresh status and errors, viewable on Provider Summary Page.
  - Added collection of raw power state and exposed to reporting.
  - Orchestration: Support for Retirement
  - Update authentication status when clicking validate for existing Providers.
  - Hosts and Providers now default to use the hostname column for communication instead of IP address.    
- SCVMM
  - Provisioning from template, Kerberos Authentication
  - Virtual DVD drives for templates
- Kubernetes
  - UI updates including Refresh button
  - Inventory Collection
  - EMS Refresh scheduling
- Foreman
  - Provider refresh
  - Enabled Reporting / Tagging
  - Exposed Foreman models as Automate service models
  - Zone enablement
  - EMS Refresh scheduling
  - Added tag processing during provisioning.
  - Added inventory collection of direct and inherited host/host-group settings.
  - Organization and location inventory
- Cloud Providers
 - Cloud Images and Instances: Added root device type to summary screens.
 - Cloud Flavors: Added block storage restriction to summary screens.
 - Enabled Reporting.
- OpenStack
  - Inventory for Heat Stacks (Cloud and Infrastructure)
  - Connect Cloud provider to Infrastructure provider
  - OpenStack Infrastructure Host Events
  - Autoscale compute nodes via Automate
  - Support for non-admin users to EMS Refresh
  - Tenant relationships added to summary screens
  - OpenStack Infrastructure Event processing
  - Handling of power states: paused, rebooting, waiting to launch
  - UI OpenStack Terminology: Clusters vs Deployment Roles, Hosts vs Nodes
- Amazon
  - AWS Region EU Frankfurt
  - Inventory collection for AWS CloudFormation
  - Parsing of parameters from orchestration templates
  - Amazon Events via AWS Config service
  - Event-based policies for AWS
  - Added a backend attribute to identify public images.
  - Added C4, D2, and G2 instance types.
  - Virtualization type collected during EMS refresh for better
    filtering of available types during provisioning.
  - Handling of power states
- Orchestration
 - Orchestration Stacks include tagging
 - Cloud Stacks: Summary and list views.
 - Orchestration templates
     - Create, edit, delete, tagging, 'draft' support
     - Create Service Dialog from template contents
 - Enabled Reporting / Tagging.
 - Improved rollback error message in UI.
 - Collect Stack Resource name and status reason message.

### Provisioning
- Heat Orchestration provisioning through services
- Foreman
  - Provisioning of bare metal systems
  - Uses latest Foreman Apipie gem
- Allow removing keys from :clone_options by setting value to nil
- OpenStack: Added tenant filtering on security groups, floating IPs, and
    networks.
- Amazon: Filter of flavors based on root device type and block
    storage restrictions.

### User Interface
- Bootstrap/Patternfly
  - Updates to form buttons with Patternfly
  - Login screen converted to Bootstrap / Patternfly
  - Header, navigation, and outer layouts converted to Bootstrap / Patternfly
  - Advanced search converted to Bootstrap / Patternfly
- AngularJS
  - Repository Editor using AngularJS
  - Schedule editor converted to AngularJS
- i18n
  - HAML and i18n strings 100% completed in views
  - Multi-character set language support
  - Can now set the locale for both server and user
- HTML5 Console for RHEVM, VMware, and OpenStack
- Menu plugins for external sites
- Charting updates: jqPlot, default charts, chart styling, donut chart support
- UI Customizations with Less
- Dashboard tabs updated
- Replaced many legacy Prototype calls with jQuery equivalents
- Tagging support and toolbars on list views

### REST API
- Total parity with SOAP API. SOAP API is now deprecated and will be removed in an upcoming release.
- Foundational
  - Virtual attribute support  
  - Id/Href separation- Enhancement to /api/providers to support new provider class
- Providers CRUD
- Refresh via /api/providers
- Tag Collection /api/tags
- Tag Management (assign and unassign to/from resources)
- Policy Management: Query policy and policy profiles conditions
- VM Management
  - Custom Attributes
  - Add LifeCycle Events
  - Start, stop, suspend, delete.
- Accounts sub-collection /api/vms/#/accounts
- Software sub-collection /api/vms/#/software
- Support for external authentication (httpd) against an IPA server.  

### Automate
- Enhanced UI import to allow granularity down to the namespace.
- Cloud Objects exposed to Automate.
- Allow Automate methods to override or extend parameters passed to provider by updating the clone_options during provisioning.  
- New service model for CloudResourceQuota.
- Exposed relationships through EmsCloud and CloudTenant models.
- Exposed cloud relationships in automate service models.
- Persist state data through automate state machine retries.
- Moved auto-placement into an Automate state-machine step for Cloud and Infrastructure provisioning.
- Added common "Finished" step to all Automate state machine classes.
- Added eligible\_* and set\_* methods for cloud resources to provision task service model.
- Ability to specify zone for web service automation request
- Ability to override request message
- Updated provisioning/retirement entry point in a catalog item or bundle.
- Disabled domains now clearly marked in UI.
- Automate entry point selection reduced to state machine classes.
- Retirement
  - New workflow
  - Detection of User vs. System initiated retirement

### Fleecing
- Qcow3
- VSAN (VMware)
- OpenStack instances
- Systemd fleecing support
- XFS filesystem support

### i18n
  - All strings in the views have been converted to use gettext (i18n) calls
  - Can add/update i18n files with translations

### Service Dialogs
- Dynamic field support: text boxes, text area boxes, checkboxes, radio buttons, date/time control
- Dynamic list field refactored into standard drop-down field
- Read only field support
- Dialog seeding for imports
- Service provisioning request overrides

### IPv6
- Allow IPv6 literals in VMware communication by upgrading httpclient
- Allow IPv6 literals in RHEVM/ovirt communication by fixing and upgrading rest-client and ruby 2.0  
- Fixed URI building within ManageIQ to wrap/unwrap IPv6 literals as needed

### Security
- Lock down [POODLE](http://en.wikipedia.org/wiki/POODLE) attacks.
- Support SSL for OpenStack
  - Deals with different ways to configure SSL for OpenStack
    - SSL termination at OpenStack services
    - SSL termination at proxy
    - Doesn't always change the service ports
  - Attempts non-SSL first, then fails over to SSL
- Kerberos ticket based SSO to web UI login.
- Fix_auth command tool can now update passwords in database.yml
- Better messaging around overwriting database encryption keys
- Make memcached listen on loopback address, not all addresses
- Migrate empty memcache_server_opts to bind on localhost by default

### Appliance
- Rake task to allow a user to replicate all pending backlog before upgrading.
- Appliance Console: Added ability to copy keys across appliances.
- Ruby 2.0
  - Appliance now built using Ruby 2.0
  - New commits and pull requests - tested with Ruby 2.0
- Ability to configure a temp disk for OpenStack fleecing added to the
    appliance console.
- Generation of encryption keys added to the appliance console and CLI.
- Generation of PostgreSQL certificates, leveraging IPA, added to the
    appliance console CLI.
- Support for Certmonger/IPA to the appliance certificate authority.
- Iptables configured via kickstart
- Replaced authentication_(valid|invalid)? with (has|missing)_credentials?
- Stop/start apache if user_interface and web_services are inactive/active
- Rails
  - Moved to Rails 4 finders.
  - Removed patches against the logger classes.
  - Removed assumptions that associations are eagerly loaded.
  - Updated  preloader patches against Rails
  - Updated virtual column / reflection code to integrate with Rails
  - Started moving ActiveRecord 2.3 hash based finders to Relation based finders
  - Backports and refactorings on master for Rails 4 support
  - Rails server listen on loopback when running appliance in production mode
  - Bigint id columns
  - Memoist gem replaced deprecated ActiveSupport::Memoizable
- Upgraded AWS SDK gem
- Upgraded Fog gem
- LDAP
  - Allow undefined users to log in when “Get User Groups from LDAP” is disabled
  - Ability to set default group for LDAP Authentication
- Allow Default Zone description to be changed
- Lazy require the less-rails gem  


## Removed

- SmartProxy:
  - Removed from UI
  - Directory removed
- IP Address Form Field: Removed from UI (use Hostname)
- Prototype from UI
- Support for repository refreshes, since they are not used.
- Support for Host-only refreshes.  Instead, an ESX/ESXi server should be added as a Provider.
- Rails Fork removal
  - Backport disable\_ddl_transaction! from Rails master to our fork
  - Update the main app to use disable\_ddl_transaction!
  - Add bigserial support for primary keys to Rails (including table creation and FK column creation)
  - Backport bigserial API to our fork
  - Update application to use new API
- Old C-Language VixDiskLib binding code
- Reduced need for Rails fork.
- Testing: Removed have\_same\_elements custom matcher in favor of built-in match_array
- Graphical summary screens
- VDI support
- Various monkey patches to prepare for Ruby 2 and Rails 4 upgrades  

## Notable Fixes and Changes

- Provisioning
  - Fixed duplicate VM name generation issue during provisioning.
  - Provisioning fix for non-admin OpenStack tenants.
  - Provisioning fix to deal with multiple security groups with the same name.
- Automate
  - Prevent deletion of locked domains.
  - Corrected ManageIQ/Infrastructure/vm/retirement method retry criteria.
  - Fixed timeout issue with remove_from_disk method on a VM in Automate.
- Providers
 - server_monitor_poll default setting changed to 5 seconds, resulting in shorter queue times.
 - Fixed issue where deleting an EMS and adding it back would cause refresh failure.
 - EventEx is now disabled by default to help prevent event storms
 - Fixed "High CPU usage" due to continually restarting workers when a provider is unreachable or password is invalid.
 - RHEVM/oVirt:
    - Ignore user login failed events to prevent event flooding.
    - Discovery fixed to eliminate false positives
 - SCVMM: Fixed refresh when Virtual DVD drives are not present.
 - OpenStack
       -  Image pagination issue where all of the images would not be collected.
       -  OpenStack provider will gracefully handle 404 errors.
       - Fixed issue where a stopped or paused OpenStack instance could not be
    restarted.
- Database
  - Fixed seeding of VmdbDatabase timing out with millions of vmdb_metrics rows
  - Database.yml is no longer created  after database is configured.
  - Fixed virtual column inheritance creating duplicate entries.
-  Appliance
   - Fixed ftp log collection regression
   - Ruby 2.0
     - Ruby2 trap logging and worker row status
   - Fixed appliance logrotate not actually rotating the logs.
   - Gem upgrades for bugs/enhancements
      - haml
      - net-ldap
      - net-ping
- Other
 - Workaround for broker hang: Reported as VMware events and capacity and utilization works for a while, then stops.
  - Chargeback
  - Storage C&U collected every 60 minutes.
  - Don't collect cpus/memory available unless you have usage.
  - Clean up of CPU details in UI
 - SMTP domain length updated to match SMTP host length
 - Fleecing: Fixed handling of nil directory entries and empty files
 - Fixed issue where deleting a cluster or host tries to delete all policy_events, thus never completing when there are millions of events.
 - Fixed inheriting tags from resource pool.
 - UI: Fixed RBAC / Feature bugs
