# Change Log

All notable changes to this project will be documented in this file.

The ManageIQ organization is continuously adding new smaller repositories.  The repositories listed below maintain their own changelogs on GitHub:
- [manageiq-content CHANGELOG](https://github.com/ManageIQ/manageiq-content/blob/master/CHANGELOG.md)
- [manageiq-providers-amazon CHANGELOG](https://github.com/ManageIQ/manageiq-providers-amazon/blob/master/CHANGELOG.md)
- [manageiq-providers-azure CHANGELOG](https://github.com/ManageIQ/manageiq-providers-azure/blob/master/CHANGELOG.md)
- [manageiq-providers-vmware CHANGELOG](https://github.com/ManageIQ/manageiq-providers-vmware/blob/master/CHANGELOG.md)
- [manageiq-ui-classic CHANGELOG](https://github.com/ManageIQ/manageiq-ui-classic/blob/master/CHANGELOG.md)

## Sprint 67 ending 2017-08-21

### [Enhancement](https://github.com/ManageIQ/manageiq/issues?utf8=%E2%9C%93&q=milestone%3A%22Sprint%2067%20Ending%20Aug%2021%2C%202017%22%20label%3Aenhancement%20)
- Don't use secure sessions in containers [(#15819)](https://github.com/ManageIQ/manageiq/pull/15819)
- Add metrics default limit to API settings [(#15797)](https://github.com/ManageIQ/manageiq/pull/15797)
- Missing settings for a cloud batch saving and adding shared_options [(#15792)](https://github.com/ManageIQ/manageiq/pull/15792)
- Get tag details for no specific model [(#15788)](https://github.com/ManageIQ/manageiq/pull/15788)
- Add group in manageiq payload for ansible automation. [(#15787)](https://github.com/ManageIQ/manageiq/pull/15787)
- Validate that an entitlement has one kind of managed filter [(#15786)](https://github.com/ManageIQ/manageiq/pull/15786)
- Batch saving timestamps enhancement [(#15774)](https://github.com/ManageIQ/manageiq/pull/15774)
- Adds dialog field association info to importer [(#15740)](https://github.com/ManageIQ/manageiq/pull/15740)
- Limit Generic Object associations to the same list of objects available to reporting. [(#15735)](https://github.com/ManageIQ/manageiq/pull/15735)
- Removes importer association data for backwards compatibility [(#15724)](https://github.com/ManageIQ/manageiq/pull/15724)
- Needed config for Cloud batch saver_strategy [(#15708)](https://github.com/ManageIQ/manageiq/pull/15708)
- Add MiqExpression support for managed filters [(#15623)](https://github.com/ManageIQ/manageiq/pull/15623)
- Exports new DialogFieldAssociations data [(#15608)](https://github.com/ManageIQ/manageiq/pull/15608)
- Use memcached for sending messages to workers [(#15471)](https://github.com/ManageIQ/manageiq/pull/15471)
- Remove the Eventcatcher from CinderManager [(#14962)](https://github.com/ManageIQ/manageiq/pull/14962)

### [Performance](https://github.com/ManageIQ/manageiq/issues?utf8=%E2%9C%93&q=milestone%3A%22Sprint%2067%20Ending%20Aug%2021%2C%202017%22%20label%3Aperformance)
- Ultimate batch saving speedup [(#15761)](https://github.com/ManageIQ/manageiq/pull/15761)
- Memoize Metric::Capture.capture_cols [(#15791)](https://github.com/ManageIQ/manageiq/pull/15791)

### Fixed
- Remove rails-controller-testing from Gemfile [(#15852)](https://github.com/ManageIQ/manageiq/pull/15852)
- Use ruby not runner for run single worker [(#15825)](https://github.com/ManageIQ/manageiq/pull/15825)
- Handle pid in run_single_worker.rb properly [(#15820)](https://github.com/ManageIQ/manageiq/pull/15820)
- Handle SIGTERM in run_single_worker.rb [(#15818)](https://github.com/ManageIQ/manageiq/pull/15818)
- Fix for custom button not passing target object to dynamic dialog fields [(#15810)](https://github.com/ManageIQ/manageiq/pull/15810)
- Adding currencies is not that exciting [(#15809)](https://github.com/ManageIQ/manageiq/pull/15809)
- Fail with descriptive message when no EMS [(#15807)](https://github.com/ManageIQ/manageiq/pull/15807)
- Bump to non-broken network discovery [(#15798)](https://github.com/ManageIQ/manageiq/pull/15798)
- Get tag details for no specific model [(#15788)](https://github.com/ManageIQ/manageiq/pull/15788)
- Make networks vms relations distinct [(#15783)](https://github.com/ManageIQ/manageiq/pull/15783)
- Add custom reconnect logic also to the batch saver [(#15777)](https://github.com/ManageIQ/manageiq/pull/15777)
- Fix saving of refresh stats [(#15775)](https://github.com/ManageIQ/manageiq/pull/15775)
- Adding require_nested for new azure_classic_credential [(#15770)](https://github.com/ManageIQ/manageiq/pull/15770)
- web service worker needs to load MiqAeDomain etc. [(#15769)](https://github.com/ManageIQ/manageiq/pull/15769)
- miq_group_id is required by automate. [(#15760)](https://github.com/ManageIQ/manageiq/pull/15760)
- manageiq-api should be a plugin [(#15755)](https://github.com/ManageIQ/manageiq/pull/15755)
- Cleanup Postgres adapter extension redirection [(#15737)](https://github.com/ManageIQ/manageiq/pull/15737)
- Support logins when "Get User Groups from LDAP" is not checked [(#15661)](https://github.com/ManageIQ/manageiq/pull/15661)
- Give active queue worker time to complete message [(#15529)](https://github.com/ManageIQ/manageiq/pull/15529)


## Unreleased - as of Sprint 66 end 2017-08-07

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+66+Ending+Aug+7%2C+2017%22+label%3Aenhancement)

- Automate
  - Added support for expression methods [(#15537)](https://github.com/ManageIQ/manageiq/pull/15537)
  - Provisioning: Support memory limit for RHV [(#15591)](https://github.com/ManageIQ/manageiq/pull/15591)
  - Services
    - Add a relationship between generic objects and services. [(#15490)](https://github.com/ManageIQ/manageiq/pull/15490)
    - Display the text "Generic Object Class" in the UI (instead of Generic Object Definition) [(#15672)](https://github.com/ManageIQ/manageiq/pull/15672)
    - Set up dialog_field relationships through DialogFieldAssociations [(#15566)](https://github.com/ManageIQ/manageiq/pull/15566)
    - Metric rollups at the Service level [(#15695)](https://github.com/ManageIQ/manageiq/pull/15695)
    - Remove methods for Azure sample orchestration [(#15752)](https://github.com/ManageIQ/manageiq/pull/15752)

- Platform
  - Evaluate enablement expressions for custom buttons [(#15729)](https://github.com/ManageIQ/manageiq/pull/15729)
  - Evaluate visibility expressions for CustomButtons [(#15725)](https://github.com/ManageIQ/manageiq/pull/15725)
  - RBAC
    - Include EvmRole-reader as read-only role in the fixtures [(#15647)](https://github.com/ManageIQ/manageiq/pull/15647)
    - Add HostAggregates to RBAC [(#15417)](https://github.com/ManageIQ/manageiq/pull/15417)
  - Adding options field to ext_management_system [(#15398)](https://github.com/ManageIQ/manageiq/pull/15398)
  - Change the target of tag expressions [(#15715)](https://github.com/ManageIQ/manageiq/pull/15715)
  - MiqExpression::Target#to_s [(#15713)](https://github.com/ManageIQ/manageiq/pull/15713)
  - Rename applies_to_exp to visibility_expression for serializing [(#15501)](https://github.com/ManageIQ/manageiq/pull/15501)
- Workers
  - [Rearch] Combine worker messages 'sync_config' and sync_active_role' into a single 'sync_config' message. [(#15597)](https://github.com/ManageIQ/manageiq/pull/15597)
  - Add server MB usage to rake evm:status and status_full. [(#15457)](https://github.com/ManageIQ/manageiq/pull/15457)

- Providers
  - Add a virtual column for `supports_block_storage?` and `supports_cloud_object_store_container_create?` [(#15600)](https://github.com/ManageIQ/manageiq/pull/15600)
  - Containers
    - Add product features for provider disable UI [(#15592)](https://github.com/ManageIQ/manageiq/pull/15592)
    - Raise creation event batched job [(#15679)](https://github.com/ManageIQ/manageiq/pull/15679)
  - Inventory
    - Allow to run post processing job for ManagerRefresh (Graph Refresh) [(#15678)](https://github.com/ManageIQ/manageiq/pull/15678)
    - Batch saving strategy that does not require unique indexes [(#15627)](https://github.com/ManageIQ/manageiq/pull/15627)
    - Make sure passed ids for habtm relation are unique [(#15651)](https://github.com/ManageIQ/manageiq/pull/15651)
    - Sort nodes for a proper disconnect_inv/destroy order [(#15636)](https://github.com/ManageIQ/manageiq/pull/15636)
  - Middleware: Register product feature for stopping domains [(#15680)](https://github.com/ManageIQ/manageiq/pull/15680)
  - Physical Infrastructure
    - Add physical infra discovery to product features [(#15607)](https://github.com/ManageIQ/manageiq/pull/15607)
    - Adds virtual totals for servers vms and hosts to Physical Infrastructure Providers [(#15613)](https://github.com/ManageIQ/manageiq/pull/15613)
    - Change name of physical infra type in discovery [(#15681)](https://github.com/ManageIQ/manageiq/pull/15681)

- REST API
  - Add paging links to the API [(#15148)](https://github.com/ManageIQ/manageiq/pull/15148)
  - Render links with compressed ids [(#15659)](https://github.com/ManageIQ/manageiq/pull/15659)

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+66+Ending+Aug+7%2C+2017%22+label%3Aenhancement)

- Performance
  - Don't run the broker for ems_inventory if update_driven_refresh is set [(#15579)](https://github.com/ManageIQ/manageiq/pull/15579)
  - Merge retirement checks [(#15645)](https://github.com/ManageIQ/manageiq/pull/15645)
  - Batch disconnect method for ContainerImage [(#15698)](https://github.com/ManageIQ/manageiq/pull/15698)
  - Allow batch disconnect for the batch strategy [(#15699)](https://github.com/ManageIQ/manageiq/pull/15699)
  - Optimize the query of a service's orchestration_stacks. [(#15727)](https://github.com/ManageIQ/manageiq/pull/15727)
  - [Performance] MiqGroup.seed [(#15586)](https://github.com/ManageIQ/manageiq/pull/15586)

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+66+Ending+Aug+7%2C+2017%22+label%3Abug)

- Automate
  - Provisioning: Force status removal and default value [(#15685)](https://github.com/ManageIQ/manageiq/pull/15685)
  - Services
    - Fix service dialog edit [(#15658)](https://github.com/ManageIQ/manageiq/pull/15658)
    - Set user's group to the requester group. [(#15696)](https://github.com/ManageIQ/manageiq/pull/15696)

- Platform
  - Seeding timeout [(#15595)](https://github.com/ManageIQ/manageiq/pull/15595)
  - RBAC: Add Storage feature to container administrator role [(#15689)](https://github.com/ManageIQ/manageiq/pull/15689)
  - Reporting: Do not limit width of table when downloading report in text format [(#15750)](https://github.com/ManageIQ/manageiq/pull/15750)
  - Authenticatin: Normalize the username entered at login to lowercase [(#15716)](https://github.com/ManageIQ/manageiq/pull/15716)

- Providers
  - Containers
    - Re-adding "Create Service Dialog from Container Template" feature [(#15653)](https://github.com/ManageIQ/manageiq/pull/15653)
    - JobProxyDispatcher should use all container image classes [(#15519)](https://github.com/ManageIQ/manageiq/pull/15519)
    - Remove remains of container definition [(#15721)](https://github.com/ManageIQ/manageiq/pull/15721)
    - Use archived? instead of ems_id.nil? [(#15633)](https://github.com/ManageIQ/manageiq/pull/15633)
  - Inventory
    - Return VMs and Templates for EMS prev_relats [(#15671)](https://github.com/ManageIQ/manageiq/pull/15671)
    - Fix bug in InventoryCollection#find_by with non-default ref [(#15648)](https://github.com/ManageIQ/manageiq/pull/15648)
  - Remove methods for Azure sample orchestration [(#15752)](https://github.com/ManageIQ/manageiq/pull/15752)
  - VMware Infrastructure: Fix Core Refresher if there is no ems_vmware setting [(#15690)](https://github.com/ManageIQ/manageiq/pull/15690)

- REST API
  - Allow operator characters on the RHS of filter [(#15534)](https://github.com/ManageIQ/manageiq/pull/15534)


## Unreleased - as of Sprint 65 end 2017-07-24

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+65+Ending+Jul+24%2C+2017%22+label%3Aenhancement)

- Platform
  - Chargeback: Add average calculation for allocated costs and metrics optionally in chargeback [(#15565)](https://github.com/ManageIQ/manageiq/pull/15565)
  - Workers: Add heartbeat_check script for file-based worker process heartbeating [(#15494)](https://github.com/ManageIQ/manageiq/pull/15494)

- Providers
  - Adapt manageiq to new managers [(#15506)](https://github.com/ManageIQ/manageiq/pull/15506)
  - Ansible Tower: Azure Classic Credential added for embedded Ansible [(#15626)](https://github.com/ManageIQ/manageiq/pull/15626)
  - Containers: Add new class ServiceContainerTemplate. [(#15429)](https://github.com/ManageIQ/manageiq/pull/15429)
  - Inventory
    - Custom reconnect block [(#15605)](https://github.com/ManageIQ/manageiq/pull/15605)
    - Deal with special AR setters [(#15439)](https://github.com/ManageIQ/manageiq/pull/15439)
    - Store created updated and deleted records [(#15603)](https://github.com/ManageIQ/manageiq/pull/15603)
    - Use proper multi select condition [(#15436)](https://github.com/ManageIQ/manageiq/pull/15436)
- Network: Generic CRUD for network routers [(#15451)](https://github.com/ManageIQ/manageiq/pull/15451)
- Physical Infrastructure: Add physical infra types for discovery [(#15621)](https://github.com/ManageIQ/manageiq/pull/15621)

- REST API
  - Query by multiple tags [(#15557)](https://github.com/ManageIQ/manageiq/pull/15557)
  - Floating IPs: Initial API [(#15524)](https://github.com/ManageIQ/manageiq/pull/15524)
  - Network Routers REST API [(#15450)](https://github.com/ManageIQ/manageiq/pull/15450)

- User Interface
  - Features for Generic Object Classes and Instances [(#15611)](https://github.com/ManageIQ/manageiq/pull/15611)

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+65+Ending+Jul+24%2C+2017%22+label%3Aenhancement)

- Performance: Use concat for better performance [(#15635)](https://github.com/ManageIQ/manageiq/pull/15635)
- Platform: Move MiqApache from manageiq-gems-pending [(#15548)](https://github.com/ManageIQ/manageiq/pull/15548)
- User Interface: Use update:ui rake task instead of update:bower [(#15578)](https://github.com/ManageIQ/manageiq/pull/15578)


### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+65+Ending+Jul+24%2C+2017%22+label%3Abug)

- Automate
  - Fixed path for including miq-syntax-checker [(#15551)](https://github.com/ManageIQ/manageiq/pull/15551)
  - Provisioning: Validate if we have an array of integers [(#15572)](https://github.com/ManageIQ/manageiq/pull/15572)
  - Services: Add my_zone to Service Orchestration. [(#15533)](https://github.com/ManageIQ/manageiq/pull/15533)

- Platform
  - Add a marker file for determining when the ansible setup has been run [(#15642)](https://github.com/ManageIQ/manageiq/pull/15642)
  - Fix CI after adding new columns to custom_buttons table [(#15581)](https://github.com/ManageIQ/manageiq/pull/15581)
  - Check for messages key in prefetch_below_threshold? [(#15620)](https://github.com/ManageIQ/manageiq/pull/15620)
  - Track and kill embedded ansible monitoring thread [(#15612)](https://github.com/ManageIQ/manageiq/pull/15612)
  - Reporting
    - Fix chargeback report with unassigned rates [(#15580)](https://github.com/ManageIQ/manageiq/pull/15580)
    - Cast virtual attribute 'Hardware#ram_size_in_bytes' to bigint [(#15554)](https://github.com/ManageIQ/manageiq/pull/15554)

- Providers
  - Ansible Tower: Let ansible worker gracefully stop [(#15643)](https://github.com/ManageIQ/manageiq/pull/15643)
  - Containers: Save inventory container: remove target option [(#15182)](https://github.com/ManageIQ/manageiq/pull/15182)
  - Pluggability: change ManageIQ::Environment to run bundle install on plugin_setup [(#15589)](https://github.com/ManageIQ/manageiq/pull/15589)

- REST API
  - Force ascending order [(#15559)](https://github.com/ManageIQ/manageiq/pull/15559)
  - Allow compressed ids when updating a service dialog [(#15619)](https://github.com/ManageIQ/manageiq/pull/15619)



## Unreleased - as of Sprint 64 end 2017-07-10

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+64+Ending+Jul+10%2C+2017%22+label%3Aenhancement)

- Automate
  - Provisioning: Add validate_blacklist method for VM pre-provisioning [(#15513)](https://github.com/ManageIQ/manageiq/pull/15513)

- Platform
  - Make namespace into a virtual attribute [(#15532)](https://github.com/ManageIQ/manageiq/pull/15532)
  - Use OpenShift API to control the Ansible container [(#15492)](https://github.com/ManageIQ/manageiq/pull/15492)
  - Allow MiqWorker.required_roles to be a lambda [(#15522)](https://github.com/ManageIQ/manageiq/pull/15522)
  - MulticastLogger#reopen shouldn't be used because it's backed by other loggers [(#15512)](https://github.com/ManageIQ/manageiq/pull/15512)
  - Add the evm:deployment_status rake task [(#15402)](https://github.com/ManageIQ/manageiq/pull/15402)
  - Set default server roles from env [(#15470)](https://github.com/ManageIQ/manageiq/pull/15470)
  - Logging to STDOUT in JSON format for containers [(#15392)](https://github.com/ManageIQ/manageiq/pull/15392)
  - Allow overriding memcache server setting by environment variable [(#15326)](https://github.com/ManageIQ/manageiq/pull/15326)
- Reporting: Add Amazon report to standard set of reports [(#15445)](https://github.com/ManageIQ/manageiq/pull/15445)
- Queue
  - Changed task_id to tracking_label [(#15443)](https://github.com/ManageIQ/manageiq/pull/15443)
  - Add MiqQueue#tracking_label [(#15224)](https://github.com/ManageIQ/manageiq/pull/15224)
- Workers
  - Support  worker heartbeat to a local file instead of Drb. [(#15377)](https://github.com/ManageIQ/manageiq/pull/15377)
  - Use the Ansible service in containers rather than starting it locally [(#15423)](https://github.com/ManageIQ/manageiq/pull/15423)
  - Default to spawn automatically if fork isn't supported [(#15425)](https://github.com/ManageIQ/manageiq/pull/15425)

- Providers
  - Add monitoring manager [(#15354)](https://github.com/ManageIQ/manageiq/pull/15354)
  - Containers
    - Adding sti mixin to container_image base class [(#15505)](https://github.com/ManageIQ/manageiq/pull/15505)
    - Container Template: Add :miq_class for each object [(#15475)](https://github.com/ManageIQ/manageiq/pull/15475)
    - Adding ContainerImage subclasses [(#15386)](https://github.com/ManageIQ/manageiq/pull/15386)
    - Change the criteria for a required field of ContainerTemplateServiceDialog. [(#15469)](https://github.com/ManageIQ/manageiq/pull/15469)
  - Inventory
    - Support find and lazy_find by other fields than manager_ref [(#15447)](https://github.com/ManageIQ/manageiq/pull/15447)
    - Add MiqTemplate to InfraManager InventoryCollection [(#15400)](https://github.com/ManageIQ/manageiq/pull/15400)
    - Optimize insert query loading [(#15404)](https://github.com/ManageIQ/manageiq/pull/15404)

- REST API
  - Render ids in compressed form in API responses [(#15430)](https://github.com/ManageIQ/manageiq/pull/15430)

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+64+Ending+Jul+10%2C+2017%22+label%3Abug)

- Automate
  - Provisioning
    - Checks PXE customization templates for unique names [(#15495)](https://github.com/ManageIQ/manageiq/pull/15495)
    - Rebuild Provision Requests with arrays [(#15410)](https://github.com/ManageIQ/manageiq/pull/15410)

- Platform
  - Refactor MiqTask.delete_older to queue condition instead of array of IDs [(#15415)](https://github.com/ManageIQ/manageiq/pull/15415)
  - Run the setup playbook if we see that an upgrade has happened [(#15482)](https://github.com/ManageIQ/manageiq/pull/15482)
  - Alerts: Fail explicitly for MAS validation failure [(#15473)](https://github.com/ManageIQ/manageiq/pull/15473)
  - Authentication: Check the current region when creating a new user [(#15516)](https://github.com/ManageIQ/manageiq/pull/15516)
  - Reporting: Fix key for regexp in miq_expression.yaml [(#15452)](https://github.com/ManageIQ/manageiq/pull/15452)
  - Workers
    - Fix pseudo heartbeating when HB file missing [(#15483)](https://github.com/ManageIQ/manageiq/pull/15483)
    - Only remove my process' pidfile. [(#15491)](https://github.com/ManageIQ/manageiq/pull/15491)
    - Add UiConstants back to the web server worker mixin [(#15518)](https://github.com/ManageIQ/manageiq/pull/15518)

- Providers
  - Add explicit capture threshold for container [(#15311)](https://github.com/ManageIQ/manageiq/pull/15311)
  - Save key pairs in Authentication table [(#15485)](https://github.com/ManageIQ/manageiq/pull/15485)
  - Lower the report level of routine http errors in the Fog log [(#15363)](https://github.com/ManageIQ/manageiq/pull/15363)

- REST API
  - Fix virtual attribute selection [(#15387)](https://github.com/ManageIQ/manageiq/pull/15387)
  - Make request APIs consistent by restricting access to automation/provision requests to admin/requester [(#15186)](https://github.com/ManageIQ/manageiq/pull/15186)
  - Render ids in compressed form in API responses [(#15430)](https://github.com/ManageIQ/manageiq/pull/15430)
  - Use correct identifier for VM Retirement [(#15509)](https://github.com/ManageIQ/manageiq/pull/15509)
  - Return only requested attributes [(#14734)](https://github.com/ManageIQ/manageiq/pull/14734)
  - Return Not Found on Snapshots Delete actions  [(#15489)](https://github.com/ManageIQ/manageiq/pull/15489)

- UI (Classic)
  - Fix URL to Compute/Containers/Containers in miq_shortcuts [(#15497)](https://github.com/ManageIQ/manageiq/pull/15497)

## Unreleased - as of Sprint 63 end 2017-06-19

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+63+Ending+Jun+19%2C+2017%22+label%3Aenhancement)

- Automate
  - Support array of objects for custom button support [(#14930)](https://github.com/ManageIQ/manageiq/pull/14930)
  - Services
    - Log zone(q_options) when raising retirement event. [(#15317)](https://github.com/ManageIQ/manageiq/pull/15317)
    - Add configuration_script reference to service [(#14232)](https://github.com/ManageIQ/manageiq/pull/14232)
    - Add ServiceTemplateContainerTemplate. [(#15356)](https://github.com/ManageIQ/manageiq/pull/15356)
    - Add project option to container template service dialog. [(#15340)](https://github.com/ManageIQ/manageiq/pull/15340)

- Platform
  - Rails scripts for setting a server's zone and configuration settings from a command line [(#11204)](https://github.com/ManageIQ/manageiq/pull/11204)

- Providers
  - Batch saving strategy should populate the right timestamps [(#15394)](https://github.com/ManageIQ/manageiq/pull/15394)
  - Add power off/on events to automate control and the foreign key to events physical server [(#15138)](https://github.com/ManageIQ/manageiq/pull/15138)
  - Search for "product/views" in all plugins [(#15353)](https://github.com/ManageIQ/manageiq/pull/15353)
  - Save resource group information [(#15187)](https://github.com/ManageIQ/manageiq/pull/15187)
  - Add new class Dialog::ContainerTemplateServiceDialog. [(#15216)](https://github.com/ManageIQ/manageiq/pull/15216)
  - Concurent safe batch saver [(#15247)](https://github.com/ManageIQ/manageiq/pull/15247)
  - Removed SCVMM Data as moved to manageiq-providers-scvmm [(#15314)](https://github.com/ManageIQ/manageiq/pull/15314)
  - Middleware: Validate presence of feed on middleware servers [(#15390)](https://github.com/ManageIQ/manageiq/pull/15390)

- REST API
  - Return BadRequestError when invalid attributes are specified [(#15040)](https://github.com/ManageIQ/manageiq/pull/15040)
  - Return href on create [(#15005)](https://github.com/ManageIQ/manageiq/pull/15005)
  - Remove miq_server [(#15284)](https://github.com/ManageIQ/manageiq/pull/15284)

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+63+Ending+Jun+19%2C+2017%22+label%3Aenhancement)

- Performance
  - Do not queue C&U for things that aren't supported [(#15195)](https://github.com/ManageIQ/manageiq/pull/15195)
  - Add memory usage to worker status in rake evm:status and status_full [(#15375)](https://github.com/ManageIQ/manageiq/pull/15375)
  - Inventory collection default for infra manager [(#15082)](https://github.com/ManageIQ/manageiq/pull/15082)
  - Cache node_types instead of calling on every request [(#14922)](https://github.com/ManageIQ/manageiq/pull/14922)
  - Introduce: supports :capture [(#15194)](https://github.com/ManageIQ/manageiq/pull/15194)

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+63+Ending+Jun+19%2C+2017%22+label%3Abug)

- Automate
  - Provisioning: Select datastore by its association with the provider [(#15245)](https://github.com/ManageIQ/manageiq/pull/15245)
  - Services: Add orchestration stack my_zone. [(#15334)](https://github.com/ManageIQ/manageiq/pull/15334)

- Platform
  - Add vm_migrate_task factory. [(#15332)](https://github.com/ManageIQ/manageiq/pull/15332)
  - FileDepotFtp: FTP.nlst cannot distinguish empty from non-existent dir [(#9127)](https://github.com/ManageIQ/manageiq/pull/9127)
  - Put back region_description method that was accidentally extracted [(#15372)](https://github.com/ManageIQ/manageiq/pull/15372)
  - Format time interval for log message [(#15370)](https://github.com/ManageIQ/manageiq/pull/15370)
  - Increase timeout for metric purging [(#15312)](https://github.com/ManageIQ/manageiq/pull/15312)
  - Handle setup playbook failure better [(#15313)](https://github.com/ManageIQ/manageiq/pull/15313)
  - RBAC
    - Make user filter as restriction in RBAC [(#15367)](https://github.com/ManageIQ/manageiq/pull/15367)
    - Add AuthKeyPair to RBAC [(#15359)](https://github.com/ManageIQ/manageiq/pull/15359)
  - Reporting: Include cloud instances in Powered On/Off Report [(#15333)](https://github.com/ManageIQ/manageiq/pull/15333)

- Providers
  - Limit CloudTenants' related VMs to the non-archived ones [(#15329)](https://github.com/ManageIQ/manageiq/pull/15329)
  - Fix orchestrated destroy [(#15339)](https://github.com/ManageIQ/manageiq/pull/15339)
  - Wait for ems workers to finish before destroying the ems [(#14848)](https://github.com/ManageIQ/manageiq/pull/14848)
  - Return an empty relation instead of an array from db_relation() [(#15325)](https://github.com/ManageIQ/manageiq/pull/15325)

- REST API
  - Redirect tasks subcollection to request_tasks  [(#15357)](https://github.com/ManageIQ/manageiq/pull/15357)
  - Add RBAC for virtual attributes in API [(#15145)](https://github.com/ManageIQ/manageiq/pull/15145)

## Unreleased - as of Sprint 62 end 2017-06-05

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+62+Ending+Jun+5%2C+2017%22+label%3Aenhancement)

- Automate
  -  Ansible Tower Services: Add Enhanced Debug level support [(#15288)](https://github.com/ManageIQ/manageiq/pull/15288)
  - Provisioning: Ovirt-networking: using profiles [(#14991)](https://github.com/ManageIQ/manageiq/pull/14991)

- Platform
  - Allow deletion of groups with users belonging to other groups [(#15041)](https://github.com/ManageIQ/manageiq/pull/15041)
  - Add rake script to export/import miq alerts and alert profiles [(#14126)](https://github.com/ManageIQ/manageiq/pull/14126)
  - Adds MiqHelper [(#15020)](https://github.com/ManageIQ/manageiq/pull/15020)
  - Move ResourceGroup relationship into VmOrTemplate model [(#14948)](https://github.com/ManageIQ/manageiq/pull/14948)

- Providers
  - Add important asserts to the default save inventory [(#15197)](https://github.com/ManageIQ/manageiq/pull/15197)
  Delete complement strategy for deleting top level entities using batches [(#15229)](https://github.com/ManageIQ/manageiq/pull/15229)
  First version of targeted concurrent safe Persistor strategy [(#15227)](https://github.com/ManageIQ/manageiq/pull/15227)
  Generalize targeted inventory collection saving [(#15198)](https://github.com/ManageIQ/manageiq/pull/15198)
  - Containers: Add Report: Images by Failed Openscap Rule Results [(#15210)](https://github.com/ManageIQ/manageiq/pull/15210)
  - Physical Infrastructure: Add constraint to vendor in Physical Server [(#15128)](https://github.com/ManageIQ/manageiq/pull/15128)

- REST API
  - Add SQL store option to token store [(#14947)](https://github.com/ManageIQ/manageiq/pull/14947)
  - Add cloud subnet REST API [(#15248)](https://github.com/ManageIQ/manageiq/pull/15248)
  - Set_miq_server Action [(#15262)](https://github.com/ManageIQ/manageiq/pull/15262)

- User Interface
  - Add entries for Physical Server [(#15275)](https://github.com/ManageIQ/manageiq/pull/15275)
  - Add pretty model name for physical server [(#15283)](https://github.com/ManageIQ/manageiq/pull/15283)

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+62+Ending+Jun+5%2C+2017%22+label%3Aenhancement)

- Performance
  - Performance: evmserver start-up: Improve ChargeableField.seed [(#15236)](https://github.com/ManageIQ/manageiq/pull/15236)
  - Memoize root tenant [(#15191)](https://github.com/ManageIQ/manageiq/pull/15191)

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+62+Ending+Jun+5%2C+2017%22+label%3Abug)

- Automate
  - Add my_zone to ansible tower service template. [(#15233)](https://github.com/ManageIQ/manageiq/pull/15233)
  - Control: Remove the policy checking for request_host_vmotion_enabled. [(#14429)](https://github.com/ManageIQ/manageiq/pull/14429)

- Platform
  - Workaround Rails.configuration.database_configuration being {} [(#15269)](https://github.com/ManageIQ/manageiq/pull/15269)
  - Check for timed out active tasks [(#15231)](https://github.com/ManageIQ/manageiq/pull/15231)
  - Do not delete report if task associated with this report deleted [(#15134)](https://github.com/ManageIQ/manageiq/pull/15134)
  - Move signal handling into the MiqServer object [(#15206)](https://github.com/ManageIQ/manageiq/pull/15206)
  - Chargeback
    - Do not calculate useless group metrics [(#15260)](https://github.com/ManageIQ/manageiq/pull/15260)
    - Do not offer report columns that are useless [(#15261)](https://github.com/ManageIQ/manageiq/pull/15261)
  - RBAC
    - Allow matching via descendants for CloudNetworks (via network manager) [(#15271)](https://github.com/ManageIQ/manageiq/pull/15271)
    - Add vm_transform product feature [(#15214)](https://github.com/ManageIQ/manageiq/pull/15214)
  - Reporting
    - Ensure report columns serialized as hashes have symbolized keys before importing [(#15273)](https://github.com/ManageIQ/manageiq/pull/15273)
    - Changed report name to be consistent with actual produced report. [(#14646)](https://github.com/ManageIQ/manageiq/pull/14646)
    - Correct field names for reports [(#14905)](https://github.com/ManageIQ/manageiq/pull/14905)
    - Format trend max cpu usage rate with percent [(#15272)](https://github.com/ManageIQ/manageiq/pull/15272)

- Providers
  - Ansible Tower: Only run the setup playbook the first time we start embedded ansible [(#15225)](https://github.com/ManageIQ/manageiq/pull/15225)
  - Containers
    - Delete archived entities when a container manager is deleted [(#14359)](https://github.com/ManageIQ/manageiq/pull/14359)
    - Fix Containers dashboard heatmaps [(#14857)](https://github.com/ManageIQ/manageiq/pull/14857)
  - Microsoft Infrastructure: Set maintenance column for SCVMM hosts. [(#15202)](https://github.com/ManageIQ/manageiq/pull/15202)
  - Physical Infrastructure: Fix the hosts key in method which save physical server [(#15199)](https://github.com/ManageIQ/manageiq/pull/15199)

- SmartState: Queue the VM scan command after vm_scan_start event is handled by automate. [(#15228)](https://github.com/ManageIQ/manageiq/pull/15228)

## Unreleased - as of Sprint 61 end 2017-05-22

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+61+Ending+May+22%2C+2017%22+label%3Aenhancement)

- Automate: Add delete method for Cloud Subnet [(#15087)](https://github.com/ManageIQ/manageiq/pull/15087)

- Providers
  - Adding helper for unique index columns to inventory collection [(#15141)](https://github.com/ManageIQ/manageiq/pull/15141)
  - Minor inventory collection enhancements [(#15108)](https://github.com/ManageIQ/manageiq/pull/15108)
  - Physical Infrastructure: Method to save asset details  [(#14827)](https://github.com/ManageIQ/manageiq/pull/14827)
  - Pluggability
    - Blacklisted event names in settings.yml [(#14647)](https://github.com/ManageIQ/manageiq/pull/14647)
    - Allow Vmdb::Plugins to work through code reloads in development. [(#15057)](https://github.com/ManageIQ/manageiq/pull/15057)
  - Red Hat Virtualization: Reduce the default oVirt open timeout to 1 minute [(#15099)](https://github.com/ManageIQ/manageiq/pull/15099)

- REST API
  - Add support for Cloud Volume Delete action [(#15097)](https://github.com/ManageIQ/manageiq/pull/15097)
  - Configuration_script_sources subcollection [(#15070)](https://github.com/ManageIQ/manageiq/pull/15070)

- SmartState: Fix sometimes host analysis cannot get the linux packages info [(#15140)](https://github.com/ManageIQ/manageiq/pull/15140)

###  [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+61+Ending+May+22%2C+2017%22+label%3Aenhancement)

- Performance
  - Do not schedule Session.purge if this Session is not used [(#15064)](https://github.com/ManageIQ/manageiq/pull/15064)
  - Do not queue no-op destroy action [(#15080)](https://github.com/ManageIQ/manageiq/pull/15080)
  - Do not schedule smartstate dispatch unless it is needed [(#15067)](https://github.com/ManageIQ/manageiq/pull/15067)

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+61+Ending+May+22%2C+2017%22+label%3Abug)

- Automate
  - Retirement: Change retire_now to pass zone_name to raise_retirement_event. [(#15026)](https://github.com/ManageIQ/manageiq/pull/15026)
  - Services: Use extra_vars to create a new dialog when editing Ansible playbook service template. [(#15120)](https://github.com/ManageIQ/manageiq/pull/15120)

- Platform
  - Ensure order is qualified by table name for rss feeds [(#15112)](https://github.com/ManageIQ/manageiq/pull/15112)
  - Do not queue e-mails unless there is a notifier in the region [(#14801)](https://github.com/ManageIQ/manageiq/pull/14801)
  - Fixed logging for proxy when storage not defined  [(#15028)](https://github.com/ManageIQ/manageiq/pull/15028)
  - Fix broken stylesheet path for PDFs [(#14793)](https://github.com/ManageIQ/manageiq/pull/14793)
  - Start Apache if roles were changed and it is needed by the current roles [(#15078)](https://github.com/ManageIQ/manageiq/pull/15078)
  - RBAC
    - Fix tag filtering for indirect RBAC [(#15088)](https://github.com/ManageIQ/manageiq/pull/15088)
    - Add middleware models to direct RBAC [(#15011)](https://github.com/ManageIQ/manageiq/pull/15011)

- Providers
  - Ansible Tower
    - Check that the Embedded Ansible role is on [(#15045)](https://github.com/ManageIQ/manageiq/pull/15045)
    - Encrypt secrets before enqueue Tower CU operations [(#15084)](https://github.com/ManageIQ/manageiq/pull/15084)
    - Hint to UI that scm_credential private_key field should have multiple-line [(#15109)](https://github.com/ManageIQ/manageiq/pull/15109)
  - Containers: Add default filters for the container page [(#14893)](https://github.com/ManageIQ/manageiq/pull/14893)
  - Foreman: Added a check that URL is a type of HTTPS uri. [(#14965)](https://github.com/ManageIQ/manageiq/pull/14965)
  - Microsoft Infrastructure
    - [SCVMM] Remove -All from Get-SCVMTemplate call [(#15106)](https://github.com/ManageIQ/manageiq/pull/15106)
    - Refactor start_clone method and break up powershell functions [(#14842)](https://github.com/ManageIQ/manageiq/pull/14842)

- REST API
  - Request members should allow access to users with admin role [(#15163)](https://github.com/ManageIQ/manageiq/pull/15163)
  - Make TokenManager#token_ttl callable (evaluated at call time) [(#15124)](https://github.com/ManageIQ/manageiq/pull/15124)
  - Requests should allow access to users with admin role [(#15151)](https://github.com/ManageIQ/manageiq/pull/15151)

- User Interface
  - Removed grouping from all Middleware* views [(#15042)](https://github.com/ManageIQ/manageiq/pull/15042)

## Unreleased - as of Sprint 60 end 2017-05-08

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+60+Ending+May+8%2C+2017%22+label%3Aenhancement)

- Automate
  - Extract automation engine to separate repository [(#13783)](https://github.com/ManageIQ/manageiq/pull/13783)

- Platform
  - Allow reports to be generated based on GuestApplication [(#14939)](https://github.com/ManageIQ/manageiq/pull/14939)

- Providers
  - Provider native operations state machine [(#14405)](https://github.com/ManageIQ/manageiq/pull/14405)
  - Ansible Tower
    - Escalate privilege [(#14929)](https://github.com/ManageIQ/manageiq/pull/14929)
    - Add status column to Repositories list [(#14855)](https://github.com/ManageIQ/manageiq/pull/14855)
    - Use $log.log_hashes to filter out sensitive data. [(#14878)](https://github.com/ManageIQ/manageiq/pull/14878)
  - Physical Infrastructure: Create asset details object [(#14749)](https://github.com/ManageIQ/manageiq/pull/14749)

- REST API
 - Add Alert Definition Profiles (MiqAlertSet) REST API support [(#14438)](https://github.com/ManageIQ/manageiq/pull/14438)
 - API support for adding/removing Policies to/from Policy Profiles [(#14575)](https://github.com/ManageIQ/manageiq/pull/14575)
 - Enable custom actions for Vms API [(#14817)](https://github.com/ManageIQ/manageiq/pull/14817)

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+60+Ending+May+8%2C+2017%22+label%3Abug)

- Automate
  - Retirement
    - Add orchestration_stack_retired notification type. [(#14957)](https://github.com/ManageIQ/manageiq/pull/14957)
    - Revert previous changes adding notification to finish retirement. [(#14955)](https://github.com/ManageIQ/manageiq/pull/14955)
  - Provisioning
    - Add :sort_by: :none to GCE Boot Disk Size dialog field. [(#14981)](https://github.com/ManageIQ/manageiq/pull/14981)
    - Filter out the hosts with the selected network. [(#14946)](https://github.com/ManageIQ/manageiq/pull/14946)

- Platform
  - RBAC for User model regard to allowed role [(#14898)](https://github.com/ManageIQ/manageiq/pull/14898)
  - Fallback to ActiveRecord config for DB host lookup [(#15018)](https://github.com/ManageIQ/manageiq/pull/15018)
  - Use ActiveRecord::Base for connection info [(#15019)](https://github.com/ManageIQ/manageiq/pull/15019)
  - Miq shortcut seeding [(#14915)](https://github.com/ManageIQ/manageiq/pull/14915)
  - Fix constant reference in ManagerRefresh::Inventory::AutomationManager [(#14984)](https://github.com/ManageIQ/manageiq/pull/14984)
  - Set the db application_name after the server row is created [(#14904)](https://github.com/ManageIQ/manageiq/pull/14904)

- Providers
  - Microsoft Infrastructure: [SCVMM] Always assume a string for run_powershell_script [(#14859)](https://github.com/ManageIQ/manageiq/pull/14859)
  - Ansible Tower
    - Sleep some more time in ansible targeted refresh [(#14899)](https://github.com/ManageIQ/manageiq/pull/14899)
    - Tower CUD to invoke targeted refresh [(#14954)](https://github.com/ManageIQ/manageiq/pull/14954)
    - Create or delete a catalog item on update [(#14830)](https://github.com/ManageIQ/manageiq/pull/14830)
    - Prefer :dialog_id to :new_dialog_name in config_info [(#14958)](https://github.com/ManageIQ/manageiq/pull/14958)
    - Service Playbook updates fqname and configuration_template [(#15007)](https://github.com/ManageIQ/manageiq/pull/15007)
    - Use human friendly names in task names and notifications for Tower CUD operations [(#14977)](https://github.com/ManageIQ/manageiq/pull/14977)
    - Tower CUD check and run refresh_in_provider followed by refreshing manager [(#15025)](https://github.com/ManageIQ/manageiq/pull/15025)
  - Containers: Update miq-shortcuts [(#14951)](https://github.com/ManageIQ/manageiq/pull/14951)
  - Hawkular: Fix defaults for immutability of MiddlewareServers [(#14822)](https://github.com/ManageIQ/manageiq/pull/14822)
  - Network
    - Move public/external network method into base class [(#14920)](https://github.com/ManageIQ/manageiq/pull/14920)
    - Fix network_ports relation of a LB [(#14969)](https://github.com/ManageIQ/manageiq/pull/14969)
  - Virtual Infrastructure: Add a method to InfraManager to retrieve Hosts without EmsCluster [(#14884)](https://github.com/ManageIQ/manageiq/pull/14884)

- SmartState: Fixed bug: one call to Job#set_status from \`VmScan#call_snapshot_delete' has one extra parameter [(#14964)](https://github.com/ManageIQ/manageiq/pull/14964)

- User Interface (Classic)
  - Sync up dropdown list in My Settings => Visual Tab => Start Up [(#14914)](https://github.com/ManageIQ/manageiq/pull/14914)
  - Show Network Port name in Floating IP list [(#14970)](https://github.com/ManageIQ/manageiq/pull/14970)
  - Add missing units on VMDB Utilization page for disk size [(#14921)](https://github.com/ManageIQ/manageiq/pull/14921)
  - Add Memory chart for Availability Zones [(#14938)](https://github.com/ManageIQ/manageiq/pull/14938)
  - Added jobs.target_class and jobs.target_id to returned dataset in MiqTask.yaml view [(#14932)](https://github.com/ManageIQ/manageiq/pull/14932)

## Unreleased - as of Sprint 59 end 2017-04-24

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+59+Ending+Apr+24%2C+2017%22+label%3Aenhancement)

- Automate
  - Automate - added vmware reconfigure model to quota helper. [(#14756)](https://github.com/ManageIQ/manageiq/pull/14756)

- Platform
  - Generate virtual custom attributes with sections [(#14837)](https://github.com/ManageIQ/manageiq/pull/14837)
  - Set database application name in workers and server [(#13856)](https://github.com/ManageIQ/manageiq/pull/13856)
  - Report attributes for SUI [(#14829)](https://github.com/ManageIQ/manageiq/pull/14829)

- Providers
  - Containers: Add purge timer for archived entities [(#14322)](https://github.com/ManageIQ/manageiq/pull/14322)
  - Pluggable Providers: allow seeding of dialogs from plugins [(#14668)](https://github.com/ManageIQ/manageiq/pull/14668)
  - Physical Infrastructure
    - Add features to physical servers pages [(#14709)](https://github.com/ManageIQ/manageiq/pull/14709)
    - Adds physical_server methods to be used by miq-ui [(#14552)](https://github.com/ManageIQ/manageiq/pull/14552)
  - Link MiqTemplates to their parent VM when one is present [(#14755)](https://github.com/ManageIQ/manageiq/pull/14755)

- REST API
  - Refresh Configuration Script Sources action [(#14714)](https://github.com/ManageIQ/manageiq/pull/14714)
  - Authentications refresh action [(#14717)](https://github.com/ManageIQ/manageiq/pull/14717)
  - Add cloud tenants to API [(#14731)](https://github.com/ManageIQ/manageiq/pull/14731)
  - Updated providers refresh to return all tasks for multi-manager providers [(#14747)](https://github.com/ManageIQ/manageiq/pull/14747)
  - Added new firmware collection api [(#14476)](https://github.com/ManageIQ/manageiq/pull/14476)

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+59+Ending+Apr+24%2C+2017%22+label%3Aenhancement)

- Performance
  - Avoid dozens of extra selects in seed_default_events [(#14722)](https://github.com/ManageIQ/manageiq/pull/14722)
  - Do not store whole container env. in the reporting worker forever [(#14807)](https://github.com/ManageIQ/manageiq/pull/14807)

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+59+Ending+Apr+24%2C+2017%22+label%3Abug)

- Automate: Adjust power states on a service to handle children [(#14550)](https://github.com/ManageIQ/manageiq/pull/14550)

- Platform
  - Remove default server.cer [(#14858)](https://github.com/ManageIQ/manageiq/pull/14858)
  - Fix startup shortcut YAML setting for Configuration Management [(#14506)](https://github.com/ManageIQ/manageiq/pull/14506)
  - Add a notification for when the embedded ansible role is activated [(#14867)](https://github.com/ManageIQ/manageiq/pull/14867)
  - Fixed bug: timeout was not triggered for Image Scanning Job after removing Job#agent_class [(#14791)](https://github.com/ManageIQ/manageiq/pull/14791)

- Providers
  - Ensure that genealogy_parent exists in the vm data before using it [(#14753)](https://github.com/ManageIQ/manageiq/pull/14753)
  - All_ems_in_zone is not a scope yet so we can't chain 'where' [(#14792)](https://github.com/ManageIQ/manageiq/pull/14792)
  - Ansible Tower: Reformat Ansible Tower error messages [(#14777)](https://github.com/ManageIQ/manageiq/pull/14777)
  - Containers: Removed duplicate report [(#14515)](https://github.com/ManageIQ/manageiq/pull/14515)
  - Google: Fix typo on "retirement" string in google provisioning dialog. [(#14800)](https://github.com/ManageIQ/manageiq/pull/14800)
  - Physical Infrastructure: Fix vendor key in physical server [(#14828)](https://github.com/ManageIQ/manageiq/pull/14828)
  - Storage: Fix StorageManagers Cross Linkers [(#14795)](https://github.com/ManageIQ/manageiq/pull/14795)
  - VMware: Create a notification when a snapshot operation fails [(#13991)](https://github.com/ManageIQ/manageiq/pull/13991)

- REST API
  - Correctly configure custom attributes for DELETEs [(#14751)](https://github.com/ManageIQ/manageiq/pull/14751)
  - Return correct custom_attributes href  [(#14752)](https://github.com/ManageIQ/manageiq/pull/14752)
  - Render DELETE action for notifications [(#14775)](https://github.com/ManageIQ/manageiq/pull/14775)

## Unreleased - as of Sprint 58 end 2017-04-10

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+58+Ending+Apr+10%2C+2017%22+label%3Aenhancement)

- Automate
  - Services
    - Modified destroying an Ansible Service Template [(#14586)](https://github.com/ManageIQ/manageiq/pull/14586)
    - Ansible Playbook Service add on_error method. [(#14583)](https://github.com/ManageIQ/manageiq/pull/14583)

- Providers
  - Ansible: Refresh job_template -> playbook connection [(#14432)](https://github.com/ManageIQ/manageiq/pull/14432)
  - Middleware: Cross-linking Middleware server model with containers. [(#14043)](https://github.com/ManageIQ/manageiq/pull/14043)
  - Openstack: Notify when an Openstack VM has been relocated [(#14604)](https://github.com/ManageIQ/manageiq/pull/14604)

  - Physical Infra: Add Topology feature [(#14589)](https://github.com/ManageIQ/manageiq/pull/14589)

- REST API
  - Edit VMs API [(#14623)](https://github.com/ManageIQ/manageiq/pull/14623)
  - Remove all service resources [(#14584)](https://github.com/ManageIQ/manageiq/pull/14584)
  - Remove resources from service [(#14581)](https://github.com/ManageIQ/manageiq/pull/14581)
  - Bumping up version to 2.4.0 for the Fine Release [(#14541)](https://github.com/ManageIQ/manageiq/pull/14541)
  - Bumping up API Versioning to 2.5.0-pre for the G-Release [(#14544)](https://github.com/ManageIQ/manageiq/pull/14544)
  - Exposing prototype as part of /api/settings [(#14690)](https://github.com/ManageIQ/manageiq/pull/14690)


### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+58+Ending+Apr+10%2C+2017%22+label%3Aenhancement)

- Automate
  - Provisioning: First and Last name are no longer required. [(#14694)](https://github.com/ManageIQ/manageiq/pull/14694)
  - Control
    - Add policy checking for request_host_scan. [(#14427)](https://github.com/ManageIQ/manageiq/pull/14427)
    - Enforce policies type to be either "compliance" or "control" [(#14519)](https://github.com/ManageIQ/manageiq/pull/14519)
    - Add policy checking for retirement request. [(#14641)](https://github.com/ManageIQ/manageiq/pull/14641)

- Performance
  - BlacklistedEvent.seed was so slow [(#14712)](https://github.com/ManageIQ/manageiq/pull/14712)
  - Remove count(\*) from MiqQueue.get [(#14621)](https://github.com/ManageIQ/manageiq/pull/14621)
  - MiqQueue - remove MiqWorker lookup [(#14620)](https://github.com/ManageIQ/manageiq/pull/14620)
  - Optimize number of transactions sent in refresh [(#14670)](https://github.com/ManageIQ/manageiq/pull/14670)
  - Optimize store_ids_for_new_records by getting rid of the O(n^2) lookups [(#14542)](https://github.com/ManageIQ/manageiq/pull/14542)

- Providers
  - Drop support for oVirt /api always use /ovirt-engine/api [(#14469)](https://github.com/ManageIQ/manageiq/pull/14469)
  - Red Hat Virtualization Manager: New provider event parsing [(#14399)](https://github.com/ManageIQ/manageiq/pull/14399)
  - Middleware: Stop using deprecated names of hawkular-client gem [(#14543)](https://github.com/ManageIQ/manageiq/pull/14543)
  - Containers
    - Add config option to skip container_images [(#14606)](https://github.com/ManageIQ/manageiq/pull/14606)
    - Pass additional metadata from alert to event [(#14301)](https://github.com/ManageIQ/manageiq/pull/14301)

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+58+Ending+Apr+10%2C+2017%22+label%3Abug)

- Automate
  - Display Name and Description not updated during import [(#14689)](https://github.com/ManageIQ/manageiq/pull/14689)
  - Service#my_zone should only reference a VM associated to a provider. [(#14696)](https://github.com/ManageIQ/manageiq/pull/14696)

- Platform
  - Make worker_monitor_drb act like a reader again! [(#14638)](https://github.com/ManageIQ/manageiq/pull/14638)
  - Do not pass nil to the assignment mixin [(#14713)](https://github.com/ManageIQ/manageiq/pull/14713)
  - Use base class only when it is supported by direct rbac [(#14665)](https://github.com/ManageIQ/manageiq/pull/14665)
  - Alter embedded ansible for rpm builds [(#14637)](https://github.com/ManageIQ/manageiq/pull/14637)

- Providers
  - Metrics: Handle exception when a metrics target doesn't have an ext_management_system [(#14718)](https://github.com/ManageIQ/manageiq/pull/14718)
  - Ensure remote shells generated by SCVMM are closed when finished [(#14591)](https://github.com/ManageIQ/manageiq/pull/14591)
  - Containters
    - Fix queueing of historical metrics collection [(#14695)](https://github.com/ManageIQ/manageiq/pull/14695)
    - Always evaluate datawarehouse_alerts [(#14318)](https://github.com/ManageIQ/manageiq/pull/14318)
  - Ansible Tower
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

- REST API
  - Allow policies to be deleted via DELETE [(#14659)](https://github.com/ManageIQ/manageiq/pull/14659)
  - Allow partial POST edits on miq policy REST [(#14518)](https://github.com/ManageIQ/manageiq/pull/14518)
  - Return provider_class on provider requests [(#14657)](https://github.com/ManageIQ/manageiq/pull/14657)
  - Return correct resource hrefs [(#14549)](https://github.com/ManageIQ/manageiq/pull/14549)
  - Removing ems_events from config/api.yml [(#14699)](https://github.com/ManageIQ/manageiq/pull/14699)

# Fine-1

## Added

- Automate
  - Control: Enforce policies type to be either "compliance" or "control" [(#14519)](https://github.com/ManageIQ/manageiq/pull/14519)
  - Services
    - Modified destroying an Ansible Service Template [(#14586)](https://github.com/ManageIQ/manageiq/pull/14586)
    - Ansible Playbook Service add on_error method. [(#14583)](https://github.com/ManageIQ/manageiq/pull/14583)

- Platform
  - Include embedded ansible logs in log collection [(#14770)](https://github.com/ManageIQ/manageiq/pull/14770)

- Providers
  - New folder targeted refresh [Depends on vmware/32] [(#14460)](https://github.com/ManageIQ/manageiq/pull/14460)
  - Ansible Tower: Refresh job_template -> playbook connection [(#14432)](https://github.com/ManageIQ/manageiq/pull/14432)
  - Middleware: Cross-linking Middleware server model with containers. [(#14043)](https://github.com/ManageIQ/manageiq/pull/14043)
  - Physical Infrastructure: Add Physical Infra Topology feature [(#14589)](https://github.com/ManageIQ/manageiq/pull/14589)
  - Red Hat Virtualization: New provider event parsing [(#14399)](https://github.com/ManageIQ/manageiq/pull/14399)

- REST API
  - Remove all service resources [(#14584)](https://github.com/ManageIQ/manageiq/pull/14584)
  - Remove resources from service [(#14581)](https://github.com/ManageIQ/manageiq/pull/14581)
  - Bumping up version to 2.4.0 for the Fine Release [(#14541)](https://github.com/ManageIQ/manageiq/pull/14541)
  - Exposing prototype as part of /api/settings [(#14690)](https://github.com/ManageIQ/manageiq/pull/14690)

## Changed

- Performance
  - Optimize number of transactions sent in refresh [(#14670)](https://github.com/ManageIQ/manageiq/pull/14670)
  - Optimize store_ids_for_new_records by getting rid of the O(n^2) lookups [(#14542)](https://github.com/ManageIQ/manageiq/pull/14542)
  - Do not run MiqEventDefinitionSet.seed twice on every start-up [(#14725)](https://github.com/ManageIQ/manageiq/pull/14725)
  - Do not run these seeds twice [(#14726)](https://github.com/ManageIQ/manageiq/pull/14726)
  - Speed up MiqEventDefinitionSet.seed [(#14721)](https://github.com/ManageIQ/manageiq/pull/14721)
  - Do not store whole container env. in the reporting worker forever [(#14807)](https://github.com/ManageIQ/manageiq/pull/14807)

- Platform
  - RBAC
    - Allow descendants of Host model to use belongsto filters in RBAC [(#14852)](https://github.com/ManageIQ/manageiq/pull/14852)
    - Add chargeback to shortcuts to allow access to chargeback only. [(#14809)](https://github.com/ManageIQ/manageiq/pull/14809)
    - Define new product features for specific types of Storage Managers [(#14745)](https://github.com/ManageIQ/manageiq/pull/14745)

- Providers
  - Red Hat Virtualization: Drop support for oVirt /api always use /ovirt-engine/api [(#14469)](https://github.com/ManageIQ/manageiq/pull/14469)

## Fixed

- Automate
  - Automate - Added finish retirement notification. [(#14780)](https://github.com/ManageIQ/manageiq/pull/14780)
  - Add policy checking for retirement request. [(#14641)](https://github.com/ManageIQ/manageiq/pull/14641)
  - Ansible Tower
    - Ensure job is refreshed in the condition of state machine exits on error [(#14684)](https://github.com/ManageIQ/manageiq/pull/14684)
    - Parse password field from dialog and decrypt before job launch [(#14636)](https://github.com/ManageIQ/manageiq/pull/14636)
    - Ansible Service: skip dialog options for retirement [(#14602)](https://github.com/ManageIQ/manageiq/pull/14602)
    - Modified to use Embedded Ansible instance [(#14568)](https://github.com/ManageIQ/manageiq/pull/14568)
  - Control: Add policy checking for request_host_scan. [(#14427)](https://github.com/ManageIQ/manageiq/pull/14427)
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

- Providers
  - Google: Ensure google managers change zone and provider region with cloud manager [(#14742)](https://github.com/ManageIQ/manageiq/pull/14742)
  - Metrics: Handle exception when a metrics target doesn't have an ext_management_system [(#14718)](https://github.com/ManageIQ/manageiq/pull/14718)
  - Microsoft Infrastructure: Ensure remote shells generated by SCVMM are closed when finished [(#14591)](https://github.com/ManageIQ/manageiq/pull/14591)
  - Containers
    - Container Volumes should honor tag visibility [(#14517)](https://github.com/ManageIQ/manageiq/pull/14517)
    - Fix queueing of historical metrics collection [(#14695)](https://github.com/ManageIQ/manageiq/pull/14695)
  - Ansible Tower
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

- REST API
  - Allow partial POST edits on miq policy REST [(#14518)](https://github.com/ManageIQ/manageiq/pull/14518)
  - Return provider_class on provider requests [(#14657)](https://github.com/ManageIQ/manageiq/pull/14657)
  - Return correct resource hrefs [(#14549)](https://github.com/ManageIQ/manageiq/pull/14549)
  - Removing ems_events from config/api.yml [(#14699)](https://github.com/ManageIQ/manageiq/pull/14699)

- SmartState
  - Timeout was not triggered for Image Scanning Job after removing Job#agent_class [(#14791)](https://github.com/ManageIQ/manageiq/pull/14791)

# Fine Beta

## Added

- Automate
  - Alerts
    - Pass metadata from an EmsEvent to an alert [(#14136)](https://github.com/ManageIQ/manageiq/pull/14136)
    - Add hide & show alert status actions (backend) [(#13650)](https://github.com/ManageIQ/manageiq/pull/13650)
  - Ansible Tower
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

  - See also [Manageiq/manageiq-content](https://github.com/ManageIQ/manageiq-content)

- Platform
  - Add remote servers to rake evm:status_full [(#14107)](https://github.com/ManageIQ/manageiq/pull/14107)
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

  - See also [Manageiq/manageiq-appliance](https://github.com/ManageIQ/manageiq-appliance)

- Providers
  - Enhanced inventory collector target and parser classes [(#13907)](https://github.com/ManageIQ/manageiq/pull/13907)
  - Force unique endpoint hostname only for same type ([#12912](https://github.com/ManageIQ/manageiq/pull/12912))
  - Amazon
    - Namespace the mappable object types add Amazon VM and Image types. [(#14288)](https://github.com/ManageIQ/manageiq/pull/14288)
    - Map Amazon labels to tags [(#14436)](https://github.com/ManageIQ/manageiq/pull/14436)
    - Import AWS Tags as CustomAttributes for Instances and Images [(#14202)](https://github.com/ManageIQ/manageiq/pull/14202)
    - Move amazon settings to ManageIQ/manageiq-providers-amazon ([#13192](https://github.com/ManageIQ/manageiq/pull/13192))
  - Ansible Tower
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
    - Be able to use tls when connecting to Hawkular [(#14054)](https://github.com/ManageIQ/manageiq/pull/14054)
    - Send data source properties when adding data source operation is performed [(#13937)](https://github.com/ManageIQ/manageiq/pull/13937)
    - Middleware server group power ops [(#13741)](https://github.com/ManageIQ/manageiq/pull/13741)
  - OpenStack
    - Use task queue for set/unset node maintenance [(#13657)](https://github.com/ManageIQ/manageiq/pull/13657)
    - Use task queue for CRUD operations on auth key pair  [(#13464)](https://github.com/ManageIQ/manageiq/pull/13464)
    - Add OpenStack excon settings [(#14172)](https://github.com/ManageIQ/manageiq/pull/14172)
    - Add OpenStack infra provider event blacklist [(#14369)](https://github.com/ManageIQ/manageiq/pull/14369)
  - Physical Infrastructure
    - Add physical infra refresh monitor [(#14424)](https://github.com/ManageIQ/manageiq/pull/14424)
    - Add physical server views to the product [(#14031)](https://github.com/ManageIQ/manageiq/pull/14031)
  - Pluggable
    - Ems event groups - allow provider settings (deeper_merge edition) [(#14177)](https://github.com/ManageIQ/manageiq/pull/14177)
    - Add registered_provider_plugins to Vmdb::Plugins [(#13983)](https://github.com/ManageIQ/manageiq/pull/13983)
  - Red Hat Virtualization
    - Use the new OvirtSDK for refresh [(#14398)](https://github.com/ManageIQ/manageiq/pull/14398)
    - Don't pass empty lists of certificates to the oVirt SDK [(#14160)](https://github.com/ManageIQ/manageiq/pull/14160)
    - Always pass the URL path to the oVirt SDK [(#14159)](https://github.com/ManageIQ/manageiq/pull/14159)
    - Set 'https' as the default protocol when using oVirt SDK [(#14157)](https://github.com/ManageIQ/manageiq/pull/14157)
  - VMware Infrastructure: Validate CPU and Memory Hot-Plug settings in reconfigure ([#12275](https://github.com/ManageIQ/manageiq/pull/12275))

  - See also [Manageiq/manageiq-providers-amazon](https://github.com/ManageIQ/manageiq-providers-amazon)
  - See also [Manageiq/manageiq-providers-azure](https://github.com/ManageIQ/manageiq-providers-azure)

- REST API
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

- Service UI
  - See [Manageiq/manageiq-ui-service](https://github.com/ManageIQ/manageiq-ui-service)

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

  - See also [Manageiq/manageiq-ui-classic changelog] (https://github.com/ManageIQ/manageiq-ui-classic/pull/461)

## Changed

- Automate
  - Switched to the latest version of `ansible_tower_client` gem [(#14117)](https://github.com/ManageIQ/manageiq/pull/14117)
  - Update the service dialog to use the correct automate entry point [(#13955)](https://github.com/ManageIQ/manageiq/pull/13955)
  - Change default provisioning entry point for AutomationManagement. [(#13762)](https://github.com/ManageIQ/manageiq/pull/13762)
  - Look for resources in the same region as the selected template during provisioning. ([#13045](https://github.com/ManageIQ/manageiq/pull/13045))

- Performance
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
  - Use the new setup script argument types [(#14313)](https://github.com/ManageIQ/manageiq/pull/14313)
  - Exclude chargeback lookup tables in replication [(#14466)](https://github.com/ManageIQ/manageiq/pull/14466)
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
  - Kill workers that don't stop after a configurable time [(#13805)](https://github.com/ManageIQ/manageiq/pull/13805)

- Providers
  - Move azure settings to azure provider [(#14345)](https://github.com/ManageIQ/manageiq/pull/14345)
  - Ansible event catcher - mark event_monitor_runnning when there are no events at startup [(#13903)](https://github.com/ManageIQ/manageiq/pull/13903)
  - Virtual Infrastructure: Deprecate callers to Address in Host [(#14138)](https://github.com/ManageIQ/manageiq/pull/14138)
  - Set timeout for inventory refresh calls [(#14245)](https://github.com/ManageIQ/manageiq/pull/14245)
  - OpenStack
    - Add openstack cloud tenant events [(#14052)](https://github.com/ManageIQ/manageiq/pull/14052)
    - Set the raw power state when starting Openstack instance [(#14122)](https://github.com/ManageIQ/manageiq/pull/14122)
  - Red Hat Virtualization
    - Resolve oVirt IP addresses [(#13767)](https://github.com/ManageIQ/manageiq/pull/13767)
    - Save host for a VM after migration ([#13511](https://github.com/ManageIQ/manageiq/pull/13511))
  - Use task queue for VM actions [(#13782)](https://github.com/ManageIQ/manageiq/pull/13782)

- Storage
  - Rename Amazon EBS storage manager ([#13569](https://github.com/ManageIQ/manageiq/pull/13569))

- User Interface (Classic): Updated patternfly to v3.23 [(#13940)](https://github.com/ManageIQ/manageiq/pull/13940)

## Fixed

- Automate
  - Fix services always invisible [(#14403)](https://github.com/ManageIQ/manageiq/pull/14403)
  - Fixes tag control multi-value [(#14382)](https://github.com/ManageIQ/manageiq/pull/14382)
  - Control
    - Add the logic to allow a policy to prevent request_vm_scan. [(#14370)](https://github.com/ManageIQ/manageiq/pull/14370)
    - During control action host was not being passed in  [(#14500)](https://github.com/ManageIQ/manageiq/pull/14500)
  - Don't allow selecting resources from another region when creating a catalog item [(#14468)](https://github.com/ManageIQ/manageiq/pull/14468)
  - Merge service template options on update [(#14314)](https://github.com/ManageIQ/manageiq/pull/14314)
  - Fix for Service Dialog not saving default value <None> for drop down or radio button [(#14240)](https://github.com/ManageIQ/manageiq/pull/14240)
  - Avoid calling $evm.backtrace over DRb to prevent DRb-level mutex locks [(#14239)](https://github.com/ManageIQ/manageiq/pull/14239)
  - Fix Automate domain reset for legacy directory. [(#13933)](https://github.com/ManageIQ/manageiq/pull/13933)
  - Services: Power state for services that do not have an associated service_template [(#13785)](https://github.com/ManageIQ/manageiq/pull/13785)
  - Provisioning: Update validation regex to prohibit only numbers for Azure VM provisioning [(#13730)](https://github.com/ManageIQ/manageiq/pull/13730)
  - Allow a service power state to correctly handle nil actions ([#13232](https://github.com/ManageIQ/manageiq/pull/13232))
  - Increment the ae_state_retries when on_exit sets retry ([#13339](https://github.com/ManageIQ/manageiq/pull/13339))

- Platform
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
  - Ansible
    - Fix saving hosts in ansible playbook job [(#14522)](https://github.com/ManageIQ/manageiq/pull/14522)
    - Add missing authentication require_nested [(#14018)](https://github.com/ManageIQ/manageiq/pull/14018)
    - Disable SSL verification for embedded Ansible. [(#14078)](https://github.com/ManageIQ/manageiq/pull/14078)
    - Allow create_in_provider to fail [(#14049)](https://github.com/ManageIQ/manageiq/pull/14049)
  - Console: Added missing parameter when requesting OpenStack remote console ([#13558](https://github.com/ManageIQ/manageiq/pull/13558))
  - Containers
    - Identifying container images by digest only [(#14185)](https://github.com/ManageIQ/manageiq/pull/14185)
    - Create a hawkular client for partial endpoints [(#13814)](https://github.com/ManageIQ/manageiq/pull/13814)
    - Container managers #connect: don't mutate argument [(#13719)](https://github.com/ManageIQ/manageiq/pull/13719)
    - Fix creating Kubernetes or OSE with `credentials.auth_key` [(#13317)](https://github.com/ManageIQ/manageiq/pull/13317)
  - Microsoft Sesrvice Control Virtualization Manager: - Enable VM reset functionality [(#14123)](https://github.com/ManageIQ/manageiq/pull/14123)
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
  - Ensure actions are returned correctly in the API [(#14033)](https://github.com/ManageIQ/manageiq/pull/14033)
  - Return result of destroy action to user not nil [(#14097)](https://github.com/ManageIQ/manageiq/pull/14097)
  - Convey a useful message to queue_object_action [(#13710)](https://github.com/ManageIQ/manageiq/pull/13710)
  - Fix load balancers access in API [(#13866)](https://github.com/ManageIQ/manageiq/pull/13866)
  - Fix cloud networks access in API [(#13865)](https://github.com/ManageIQ/manageiq/pull/13865)
  - Fix schedule access in API [(#13864)](https://github.com/ManageIQ/manageiq/pull/13864)

- User Interface
  - Fix mixed values in Low and High operating ranges for CU charts [(#14324)](https://github.com/ManageIQ/manageiq/pull/14324)
  - Revert "Remove unneeded include from reports" [(#14439)](https://github.com/ManageIQ/manageiq/pull/14439)
  - Added missing second level menu keys for Storage menu [(#14145)](https://github.com/ManageIQ/manageiq/pull/14145)
  - Update spice-html5-bower to 1.6.3 fixing an extra GET .../null request [(#13889)](https://github.com/ManageIQ/manageiq/pull/13889)
  - Add the Automation Manager submenu key to the permission yaml file [(#13931)](https://github.com/ManageIQ/manageiq/pull/13931)
  - Added missing Automate sub menu key to permissions yml. [(#13819)](https://github.com/ManageIQ/manageiq/pull/13819)

  - See also [Manageiq/manageiq-ui-classic changelog](https://github.com/ManageIQ/manageiq-ui-classic/pull/461)

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
  - I18n support added to the Self Service UI
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
- I18n
  - Marked translated strings directly in UI
  - Gettext support
  - I18n for toolbars
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
  - Updated to newer [ansible`_tower`_client gem](https://github.com/ManageIQ/ansible_tower_client)
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
  - Fixes for Japanese I18n support
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
- I18N
  - HAML and I18n strings 100% completed in views
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

### I18n
  - All strings in the views have been converted to use gettext (I18n) calls
  - Can add/update I18n files with translations

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
