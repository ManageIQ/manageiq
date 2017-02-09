# Change Log

All notable changes to this project will be documented in this file.

## Unreleased - as of Sprint 54 end 2017-02-13

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+54+Ending+Feb+13%2C+2017%22+label%3Aenhancement)

- Automate
  - Alerts: Add hide & show alert status actions (backend) [(#13650)](https://github.com/ManageIQ/manageiq/pull/13650)
  - Provisioning
    - Change vLan name to Virtual Network  [(#13747)](https://github.com/ManageIQ/manageiq/pull/13747)
    - Advanced networking placement features and automate exposure for OpenStack  [(#13608)](https://github.com/ManageIQ/manageiq/pull/13608)
    - Add multiple_value option to expose_eligible_resources [(#13853)](https://github.com/ManageIQ/manageiq/pull/13853)
  - Services
    - Add create_catalog_item to ServiceTemplateAnsibleTower  [(#13646)](https://github.com/ManageIQ/manageiq/pull/13646)
    - Tool to create a service dialog for an Ansible playbook [(#13494)](https://github.com/ManageIQ/manageiq/pull/13494)
    - Resource action - Add service_action. [(#13751)](https://github.com/ManageIQ/manageiq/pull/13751)
    - Initial commit for ansible playbook methods and service model. [(#13717)](https://github.com/ManageIQ/manageiq/pull/13717)
  - See also [Manageiq/manageiq-content](https://github.com/ManageIQ/manageiq-content)

- Platform
  - Add View and Modify/Add RBAC features for the Embedded Automation Provider [(#13716)](https://github.com/ManageIQ/manageiq/pull/13716)
  - Reporting: Adding new report and widgets for Containers [(#13055)](https://github.com/ManageIQ/manageiq/pull/13055)
  - See also [Manageiq/manageiq-appliance](https://github.com/ManageIQ/manageiq-appliance)

- Providers
  - Ansible: Refresh inventory [(#13807)](https://github.com/ManageIQ/manageiq/pull/13807)
  - Containers: Add datawarehouse logger [(#13813)](https://github.com/ManageIQ/manageiq/pull/13813)
  - See also [Manageiq/manageiq-providers-amazon](https://github.com/ManageIQ/manageiq-providers-amazon)
  - See also [Manageiq/manageiq-providers-azure](https://github.com/ManageIQ/manageiq-providers-azure)

- REST API
  - Add snapshotting for instances in the API [(#13729)](https://github.com/ManageIQ/manageiq/pull/13729)
  - Bulk unassign tags on services and vms  [(#13712)](https://github.com/ManageIQ/manageiq/pull/13712)
  - Add bulk delete for snapshots API [(#13711)](https://github.com/ManageIQ/manageiq/pull/13711)
  - Improve create picture validation [(#13697)](https://github.com/ManageIQ/manageiq/pull/13697)
  - Configuration Script Sources API [(#13626)](https://github.com/ManageIQ/manageiq/pull/13626)
  - Api enhancement to support optional collection_class parameter [(#13845)](https://github.com/ManageIQ/manageiq/pull/13845)
  - Allows specification for optional multiple identifiers [(#13827)](https://github.com/ManageIQ/manageiq/pull/13827)
  - Add config_info as additional attribute to Service Templates API [(#13842)](https://github.com/ManageIQ/manageiq/pull/13842)

- User Interface (Classic)
  - Added changes to show Catalog Item type in UI [(#13516)](https://github.com/ManageIQ/manageiq/pull/13516)
  - Physical Infrastructure provider (lenovo) changes required for the UI [(#13735)](https://github.com/ManageIQ/manageiq/pull/13735)
  - Adding Physical Infra Providers Menu Item [(#13587)](https://github.com/ManageIQ/manageiq/pull/13587)
  - Added new features for the Ansible UI move to the Automation tab [(#13526)](https://github.com/ManageIQ/manageiq/pull/13526)
  - Added new features for the Ansible UI move to the Automation tab [(#13526)](https://github.com/ManageIQ/manageiq/pull/13526)
  - See also [Manageiq/manageiq-ui-classic changelog](https://github.com/ManageIQ/manageiq-ui-classic/pull/352)

- Service UI
 - See [Manageiq/manageiq-ui-service](https://github.com/ManageIQ/manageiq-ui-service)

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+54+Ending+Feb+13%2C+2017%22+label%3Aenhancement)

- Platform
  - Rename events "ExtManagementSystem Compliance\*" -> "Provider Compliance\*" [(#13388)](https://github.com/ManageIQ/manageiq/pull/13388)
  - Kill workers that don't stop after a configurable time [(#13805)](https://github.com/ManageIQ/manageiq/pull/13805)


### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+54+Ending+Feb+13%2C+2017%22+label%3Abug)

- Providers
  - RHEV Fix Host getting disconnected from Cluster when migrating a VM in  [(#13815)](https://github.com/ManageIQ/manageiq/pull/13815)

- Automate
  - Services
    - Power state for services that do not have an associated service_template [(#13785)](https://github.com/ManageIQ/manageiq/pull/13785)
  - Provisioning
    - Update validation regex to prohibit only numbers for Azure VM provisioning [(#13730)](https://github.com/ManageIQ/manageiq/pull/13730)

- User Interface (Classic)
  - Added missing Automate sub menu key to permissions yml. [(#13819)](https://github.com/ManageIQ/manageiq/pull/13819)

- Platform
  - Chargeback
    - Skip calculation when there is zero consumed hours [(#13723)](https://github.com/ManageIQ/manageiq/pull/13723)
    - Bring currency symbols back to chargeback reports [(#13861)](https://github.com/ManageIQ/manageiq/pull/13861)
  - Add MiqUserRole to RBAC [(#13689)](https://github.com/ManageIQ/manageiq/pull/13689)
  - Fix broken C&U collection [(#13843)](https://github.com/ManageIQ/manageiq/pull/13843)
  - Instead of default(system) assign current user to generating report task [(#13823)](https://github.com/ManageIQ/manageiq/pull/13823)

- Providers
  - Hawkular: Allow adding datawarehouse provider with a port other than 80 [(#13840)](https://github.com/ManageIQ/manageiq/pull/13840)

- REST API
  - Convey a useful message to queue_object_action [(#13710)](https://github.com/ManageIQ/manageiq/pull/13710)
  - Fix load balancers access in API [(#13866)](https://github.com/ManageIQ/manageiq/pull/13866)
  - Fix cloud networks access in API [(#13865)](https://github.com/ManageIQ/manageiq/pull/13865)
  - Fix schedule access in API [(#13864)](https://github.com/ManageIQ/manageiq/pull/13864)

## Unreleased - as of Sprint 53 end 2017-01-30

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+53+Ending+Jan+30%2C+2017%22+label%3Aenhancement)

- Automate
  - Add 'delete' to generic object configuration dropdown ([#13541](https://github.com/ManageIQ/manageiq/pull/13541))
  - Automate Model: Add Amazon block storage automation models ([#13458](https://github.com/ManageIQ/manageiq/pull/13458))
  - Orchestration Services: create_catalog_item to ServiceTemplateOrchestration ([#13628](https://github.com/ManageIQ/manageiq/pull/13628))
  - Add create_catalog_item class method to ServiceTemplate ([#13589](https://github.com/ManageIQ/manageiq/pull/13589))
  - Save playbook service template ([#13600](https://github.com/ManageIQ/manageiq/pull/13600))
  - Allow adding disks to vm provision via api and automation ([#13318](https://github.com/ManageIQ/manageiq/pull/13318))
  - See also [manageiq-content repository](https://github.com/ManageIQ/manageiq-content).

- Platform
  - Chargeback: Introduce Vm/Chargeback tab backend ([#13687](https://github.com/ManageIQ/manageiq/pull/13687))
  - Add methods for configuring and starting Ansible inside ([#13584](https://github.com/ManageIQ/manageiq/pull/13584))
  - See also [manageiq-appliance repository](https://github.com/ManageIQ/manageiq-appliance).

- Providers
  - Ansible Tower
    - Event Catcher ([#13423](https://github.com/ManageIQ/manageiq/pull/13423))
    - Migrate AnsibleTower ConfigurationManager to AutomationManager ([#13630](https://github.com/ManageIQ/manageiq/pull/13630))
  - Containers
    - Instantiate Container Template ([#10737](https://github.com/ManageIQ/manageiq/pull/10737))
    - Collect node custom attributes from hawkular during refresh ([#12924](https://github.com/ManageIQ/manageiq/pull/12924))
  - See also [manageiq-providers-azure changelog](https://github.com/ManageIQ/manageiq-providers-azure/pull/29).
  - See also [manageiq-providers-amazon changelog](https://github.com/ManageIQ/manageiq-providers-amazon/pull/124).

- REST API
  - API collection OPTIONS Enhancement to expose list of supported subcollections ([#13681](https://github.com/ManageIQ/manageiq/pull/13681))
  - API Enhancement to support filtering on id attributes by compressed id's ([#13645](https://github.com/ManageIQ/manageiq/pull/13645))
  - Adds remove_approver_resource to ServiceRequestController. ([#13596](https://github.com/ManageIQ/manageiq/pull/13596))
  - Add OPTIONS method to Clusters and Hosts ([#13574](https://github.com/ManageIQ/manageiq/pull/13574))
  - VMs/Snapshots API CRD ([#13552](https://github.com/ManageIQ/manageiq/pull/13552))
  - Add alert actions api ([#13325](https://github.com/ManageIQ/manageiq/pull/13325))

- Storage
  - Add Amazon EC2 block storage manager EMS ([#13539](https://github.com/ManageIQ/manageiq/pull/13539))

- Services UI
  - See [manageiq-ui-service repository](https://github.com/ManageIQ/manageiq-ui-service).

- User Interface (Classic)
  - See [manageiq-ui-classic changelog](https://github.com/ManageIQ/manageiq-ui-classic/pull/276).

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+53+Ending+Jan+30%2C+2017%22+label%3Aenhancement)

- Automate
  - Look for resources in the same region as the selected template during provisioning. ([#13045](https://github.com/ManageIQ/manageiq/pull/13045))

- Providers
  - Red Hat Virtualization Manager: Save host for a VM after migration ([#13511](https://github.com/ManageIQ/manageiq/pull/13511))

- Storage
  - Rename Amazon EBS storage manager ([#13569](https://github.com/ManageIQ/manageiq/pull/13569))

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+53+Ending+Jan+30%2C+2017%22+label%3Abug)

Notable fixes include:

- Automate
  - Allow a service power state to correctly handle nil actions ([#13232](https://github.com/ManageIQ/manageiq/pull/13232))

- Platform
  - Tenant admin should not be able to create groups in other tenants. ([#13483](https://github.com/ManageIQ/manageiq/pull/13483))
  - Chargeback: Fix rate adjustment rounding bug ([#13331](https://github.com/ManageIQ/manageiq/pull/13331))

- Providers
  - Console: Added missing parameter when requesting OpenStack remote console ([#13558](https://github.com/ManageIQ/manageiq/pull/13558))

## Unreleased - as of Sprint 52 end 2017-01-16

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+52+Ending+Jan+16%2C+2017%22+label%3Aenhancement)

- Automate
  - Move MiqAeEngine components into the appropriate directory in preparation for extracting the Automate engine into its own repository ([#13406](https://github.com/ManageIQ/manageiq/pull/13406))
  - Automate Retry with Server Affinity ([#13363](https://github.com/ManageIQ/manageiq/pull/13363))
  - Service Model: Added container components for service model ([#12863](https://github.com/ManageIQ/manageiq/pull/12863))
  - Services: Add automate engine support for array elements containing text values ([#11667](https://github.com/ManageIQ/manageiq/pull/11667))
  - See also [manageiq-content repository](https://github.com/ManageIQ/manageiq-content).

- Platform
  - Reporting: Add option for container performance reports ([#11904](https://github.com/ManageIQ/manageiq/pull/11904))
  - Chargeback: Charge SCVMM's vm only until it is retired. ([#13451](https://github.com/ManageIQ/manageiq/pull/13451))
  - New class for determining the availability of embedded ansible ([#13435](https://github.com/ManageIQ/manageiq/pull/13435)).
  - See also [manageiq-appliance repository](https://github.com/ManageIQ/manageiq-appliance).

- Providers
  - Force unique endpoint hostname only for same type ([#12912](https://github.com/ManageIQ/manageiq/pull/12912))
  - Containers: Add alerts on container nodes ([#13323](https://github.com/ManageIQ/manageiq/pull/13323))
  - VMware Infrastructure: Validate CPU and Memory Hot-Plug settings in reconfigure ([#12275](https://github.com/ManageIQ/manageiq/pull/12275))
  - See also [manageiq-providers-azure repository](https://github.com/ManageIQ/manageiq-providers-azure).
  - See also [manageiq-providers-amazon repository](https://github.com/ManageIQ/manageiq-providers-amazon).

- REST API
  - Copy orchestration template ([#13053](https://github.com/ManageIQ/manageiq/pull/13053))
  - Expose Request Workflow class name ([#13441](https://github.com/ManageIQ/manageiq/pull/13441))
  - Sort on sql friendly virtual attributes ([#13409](https://github.com/ManageIQ/manageiq/pull/13409))
  - Expose allowed tags for a request workflow ([#13379](https://github.com/ManageIQ/manageiq/pull/13379))

- Services UI
  - See [manageiq-ui-service repository](https://github.com/ManageIQ/manageiq-ui-service).

- User Interface (Classic)
  - Add edit functionality for generic object UI ([#11815](https://github.com/ManageIQ/manageiq/pull/11815))
  - See also [manageiq-ui-classic repository](https://github.com/ManageIQ/manageiq-ui-classic).

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+52+Ending+Jan+16%2C+2017%22+label%3Aenhancement)

- Platform
  - Add list of providers to RBAC on catalog items ([#13395](https://github.com/ManageIQ/manageiq/pull/13395))

- Providers
  - Amazon: Move amazon settings to ManageIQ/manageiq-providers-amazon ([#13192](https://github.com/ManageIQ/manageiq/pull/13192))


### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+52+Ending+Jan+16%2C+2017%22+label%3Abug)

Notable fixes include:

- Automate
  - Increment the ae_state_retries when on_exit sets retry ([#13339](https://github.com/ManageIQ/manageiq/pull/13339))

- Platform
  - Chargeback: Charge only for past hours ([#13134](https://github.com/ManageIQ/manageiq/pull/13134))
  - Replication: Expose a method for encrypting using a remote v2_key ([#13083](https://github.com/ManageIQ/manageiq/pull/13083))

- Providers
  - OpenStack Cloud Network Router:  Raw commands are wrapped in raw prefixed methods ([#13072](https://github.com/ManageIQ/manageiq/pull/13072))
  - OpenStack Infra: Ssh keypair validation fixes ([#13445](https://github.com/ManageIQ/manageiq/pull/13445))


## Unreleased - as of Sprint 51 end 2017-01-02

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+51+Ending+Jan+2%2C+2017%22+label%3Aenhancement)

- Automate
  - Events: Add openstack floatingip/security group events ([#12941](https://github.com/ManageIQ/manageiq/pull/12941))
  - Pluggable automate domains ([#11083](https://github.com/ManageIQ/manageiq/pull/11083))
  - When importing domains from the UI, pass in the tenant_id ([#13031](https://github.com/ManageIQ/manageiq/pull/13031))

- Platform
 - Notifications: Use initiator's tenant when subject lacks tenant relationship ([#13081](https://github.com/ManageIQ/manageiq/pull/13081))
 - Replication: Add a default value for the replication subscription database name ([#12994](https://github.com/ManageIQ/manageiq/pull/12994))
 - Chargeback: Prioritize rate with tag of VM when selecting from more rates ([#12534](https://github.com/ManageIQ/manageiq/pull/12534))

- Providers
  - Amazon: Add an additional_regions key for amazon EC2 ([#12965](https://github.com/ManageIQ/manageiq/pull/12965))
  - Hawkular: Enable deployment actions in server deployments list view ([#12991](https://github.com/ManageIQ/manageiq/pull/12991))
  - Network: Model for add/remove interface on network router ([#13032](https://github.com/ManageIQ/manageiq/pull/13032))
  - VMware: Add VM specific customisations to vApp orchestration ([#12273](https://github.com/ManageIQ/manageiq/pull/12273))

- REST API
  - Missing DELETE /api/actions/:id ([#13160](https://github.com/ManageIQ/manageiq/pull/13160))
  - Missing DELETE /api/conditions/:id ([#13161](https://github.com/ManageIQ/manageiq/pull/13161))
  - Expose workflow on request resources ([#13254](https://github.com/ManageIQ/manageiq/pull/13254))

- Services UI
  - Load Balancers API ([#13067](https://github.com/ManageIQ/manageiq/pull/13067))
  - Add Service Request Approver ([#12997](https://github.com/ManageIQ/manageiq/pull/12997))
  - Service order copy API ([#12951](https://github.com/ManageIQ/manageiq/pull/12951))
  - Service Request edit API ([#12929](https://github.com/ManageIQ/manageiq/pull/12929))
  - ServiceOrder deep copy ([#12945](https://github.com/ManageIQ/manageiq/pull/12945))
  - Update Blueprint ui_properties with service template ids on publish ([#13153](https://github.com/ManageIQ/manageiq/pull/13153))

- User Interface (Classic)
  - Providers: OpenStack: Add ipv4 ipv6 selection to Subnet view for Network Manager ([#12650](https://github.com/ManageIQ/manageiq/pull/12650))
  - Access Control: Make a link from User/Group/Role screens text ([#13022](https://github.com/ManageIQ/manageiq/pull/13022))
  - Cloud Subnet UI: Task queue validation buttons ([#12045](https://github.com/ManageIQ/manageiq/pull/12045))
  - Floating IPs provisioning UI ([#12097](https://github.com/ManageIQ/manageiq/pull/12097))
  - Add Cores and Memory of Infra Provider list view ([#12758](https://github.com/ManageIQ/manageiq/pull/12758))
  - Cloud Providers: VCpus and Memory for Cloud Providers visual ([#13124](https://github.com/ManageIQ/manageiq/pull/13124))
  - Display IPv6Address on VM summary page ([#13190](https://github.com/ManageIQ/manageiq/pull/13190))

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+51+Ending+Jan+2%2C+2017%22+label%3Aenhancement)

- Automate
  - Provisioning: Update Azure provision template to restrict VM names ([#12947](https://github.com/ManageIQ/manageiq/pull/12947))
  - UI: Fixed code to expect keys as strings instead of symbols. ([#13087](https://github.com/ManageIQ/manageiq/pull/13087))

- Performance
  - Filter undercloud resource query for performance ([#13004](https://github.com/ManageIQ/manageiq/pull/13004))

- Platform
  - Chargeback: Set different undeleteable default rate for container image chargeback ([#13063](https://github.com/ManageIQ/manageiq/pull/13063))
  - Upgrade pglogical to 1.2.1 ([#13070](https://github.com/ManageIQ/manageiq/pull/13070))
  - Reporting: Introduce report result purging timer ([#13044](https://github.com/ManageIQ/manageiq/pull/13044))
  - Introduce purge timer for drift states ([#13086](https://github.com/ManageIQ/manageiq/pull/13086))
  - Add configuration support for websocket logging level ([#13265](https://github.com/ManageIQ/manageiq/pull/13265))

- User Interface
  - Add validation for charts with values ([#13079](https://github.com/ManageIQ/manageiq/pull/13079))
  - Convert summary screen images to fonticons and SVGs ([#13222](https://github.com/ManageIQ/manageiq/pull/13222))
  - Rename the `:icon` parameter in tree nodes to `:image` ([#13297](https://github.com/ManageIQ/manageiq/pull/13297))
  - UI Repository Split ([#13303](https://github.com/ManageIQ/manageiq/pull/13303))

### [Fixed](https://github.com/ManageIQ/manageiq/issues?utf8=%E2%9C%93&q=milestone%3A%22Sprint%2051%20Ending%20Jan%202%2C%202017%22%20label%3Bbug)

Notable fixes include:

- Platform
  - Chargeback: Fix chargeback for container Images with rate assigning by docker label ([#12851](https://github.com/ManageIQ/manageiq/pull/12851))
  - Fix master server failover race condition ([#13065](https://github.com/ManageIQ/manageiq/pull/13065))
  - Notify only a group of users when notifying about MiqRequest ([#13051](https://github.com/ManageIQ/manageiq/pull/13051))
  - Remove default consumption admin user ([#13039](https://github.com/ManageIQ/manageiq/pull/13039))
  - Filter attempt from the authentication_check options ([#13026](https://github.com/ManageIQ/manageiq/pull/13026))
  - Reporting: Added 'VMware ESXi' to the list of known operating systems ([#13249](https://github.com/ManageIQ/manageiq/pull/13249))

- Providers
  - Ensure AnsibleTowerClient.logger is set to $log not a NullLogger ([#12996](https://github.com/ManageIQ/manageiq/pull/12996))

- User Interface
  - OpenStack: Remove duplicate flash message. ([#13035](https://github.com/ManageIQ/manageiq/pull/13035))
  - Memory checkbox should not show when VM is not powerd on ([#12678](https://github.com/ManageIQ/manageiq/pull/12678))
  - Disallow subnet deletion if it has an associated instance ([#13098](https://github.com/ManageIQ/manageiq/pull/13098))
  - Fix format in providers view list in Infrastructure ([#13248](https://github.com/ManageIQ/manageiq/pull/13248))


## Unreleased - as of Sprint 50 end 2016-12-05

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+50+Ending+Dec+5%2C+2016%22+label%3Aenhancement)

- Automate
  - Retirement: Generic service retirement option ([#12619](https://github.com/ManageIQ/manageiq/pull/12619))
  - Service Dialog: Add dynamic dropdown list support for orchestration service dialog ([#12693](https://github.com/ManageIQ/manageiq/pull/12693))
  - Service Model
    - Expose custom_attribute methods to ext_management_system service model. ([#12602](https://github.com/ManageIQ/manageiq/pull/12602))
    - Move snapshot code to Vm in service model. ([#12726](https://github.com/ManageIQ/manageiq/pull/12726))
    - RBAC support for Automate Service Models ([#12369](https://github.com/ManageIQ/manageiq/pull/12369))
    - Add ae_service for google auth_key_pair ([#12973](https://github.com/ManageIQ/manageiq/pull/12973))
    - Expose miq_groups ([#12294](https://github.com/ManageIQ/manageiq/pull/12294))
  - Notifications: Send Notification when retirement starts for Services and VMs ([#12796](https://github.com/ManageIQ/manageiq/pull/12796))

- Platform
  - Reporting: Round of metric values to precision 2 in chargeback reports ([#12629](https://github.com/ManageIQ/manageiq/pull/12629))
  - Allow network manager features for tenant administrator ([#12383](https://github.com/ManageIQ/manageiq/pull/12383))
  - Use settings.yaml for purging records ([#12552](https://github.com/ManageIQ/manageiq/pull/12552))
  - Chargebacks without rollups :: Fixed metrics for HyperV ([#13229](https://github.com/ManageIQ/manageiq/pull/13229))

- Providers
  - Middleware: Add link to Server Group in the summary page of a server ([#12815](https://github.com/ManageIQ/manageiq/pull/12815))
  - Add root password validation regex for Azure dialog ([#12967](https://github.com/ManageIQ/manageiq/pull/12967))

- REST API
  - Add option to hide resources ([#12694](https://github.com/ManageIQ/manageiq/pull/12694))
  - Allow adding custom attributes with sections ([#12913](https://github.com/ManageIQ/manageiq/pull/12913))

- User Interface (Classic)
  - Add Replication excluded tables to the Settings Replication tab ([#12604](https://github.com/ManageIQ/manageiq/pull/12604))
  - Orchestration: Support hash values in dropdown orchestration dialog fields ([#12570](https://github.com/ManageIQ/manageiq/pull/12570))
  - Containers
    - Provider policies ([#11002](https://github.com/ManageIQ/manageiq/pull/11002))
    - Custom attributes table on Container Node ([#12832](https://github.com/ManageIQ/manageiq/pull/12832))
  - OpenStack: Add human readable names of private and public openstack cloud networks ([#12855](https://github.com/ManageIQ/manageiq/pull/12855))
  - Add settings key to disable console proxy ([#12675](https://github.com/ManageIQ/manageiq/pull/12675))
  - Separate Storage Managers By Type ([#12399](https://github.com/ManageIQ/manageiq/pull/12399))
  - Launch an URL returned by an automate button ([#10118](https://github.com/ManageIQ/manageiq/pull/10118))

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+50+Ending+Dec+5%2C+2016%22+label%3Aenhancement)

- Performance
  - DTO refresh optimization for saves ([#12679](https://github.com/ManageIQ/manageiq/pull/12679))
  - Purge remaining records using single query ([#12560](https://github.com/ManageIQ/manageiq/pull/12560))
  - Use `Settings` API over `VMDB::Config.new` for speed improvements for `VmOrTemplate::RightSizing`  ([#12751](https://github.com/ManageIQ/manageiq/pull/12751))
  - Don't queue ntp reload on newly created zones ([#12974](https://github.com/ManageIQ/manageiq/pull/12974))

- Platform
  - LDAP: Allow apostrophes in email address ([#12729](https://github.com/ManageIQ/manageiq/pull/12729))
  - Increase the web socket worker's pool size  ([#12800](https://github.com/ManageIQ/manageiq/pull/12800))
  - Drop currency column when editing chargeback rates ([#12834](https://github.com/ManageIQ/manageiq/pull/12834))

- REST API: Updating API versioning to 2.4.0-pre ([#12890](https://github.com/ManageIQ/manageiq/pull/12890))

- Service UI
  - Hid  power status and buttons in the SUI Services list view until more performant [manageiq-ui-service #368](https://github.com/ManageIQ/manageiq-ui-service/pull/368)
  - Add power status and buttons to the Service detail page
[ManageIQ/manageiq-ui-service #330](https://github.com/ManageIQ/manageiq-ui-service/pull/330)

- SmartState analysis
  - Containers deletion: Separate the pod deletion and skip it if no pod was created before ([#12750](https://github.com/ManageIQ/manageiq/pull/12750))

- User Interface
  - Reports: Better names for policy event sample reports  ([#12934](https://github.com/ManageIQ/manageiq/pull/12934))

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+50+Ending+Dec+5%2C+2016%22%20label%3Bbug)

Notable fixes include:

- Automate
  - Automate Provisioned Notifications - Use Automate notifications instead of event notifications ([#12424](https://github.com/ManageIQ/manageiq/pull/12424))
  - Provisioning
    - Fix auto-placement for hosts without a datastore that can hold the new VM ([#12931](https://github.com/ManageIQ/manageiq/pull/12931))
    - Support provider name & template name to uniquely identify a template ([#11669](https://github.com/ManageIQ/manageiq/pull/11669))
  - Git Domains: Delete the repo directory for Git based domains ([#12539](https://github.com/ManageIQ/manageiq/pull/12539))

- Platform
  - Authentication
    - Support a separate auth URL for external authentication ([#12697](https://github.com/ManageIQ/manageiq/pull/12697))
    - Remove the FQDN from group names for ext authentication ([#12752](https://github.com/ManageIQ/manageiq/pull/12752))
  - Fix Audit Log to record settings/values when creating new user ([#12786](https://github.com/ManageIQ/manageiq/pull/12786))
  - Fix issue where local settings files were ignoredFix issue where local settings files were ignored ([#12821](https://github.com/ManageIQ/manageiq/pull/12821))

- Providers
  - RHVM
    - Require a description when creating Snapshot ([#12637](https://github.com/ManageIQ/manageiq/pull/12637))
    - Update cluster when modified ([#12927](https://github.com/ManageIQ/manageiq/pull/12927))
  - Openstack: Remove port_security_enabled from attributes passed to network create ([#12736](https://github.com/ManageIQ/manageiq/pull/12736))
  - Fetch disk info when a vm removed ([#12788](https://github.com/ManageIQ/manageiq/pull/12788))

- User Interface
  - Prevent service dialog refreshing every time a dropdown item is selected ([#12718](https://github.com/ManageIQ/manageiq/pull/12718))
  - Fix angular controller for Network Router Network Router ([#12707](https://github.com/ManageIQ/manageiq/pull/12707)) and Cloud Subnet ([#12706](https://github.com/ManageIQ/manageiq/pull/12706))
  - Ansible: Add configuration_scripts to the list of trees with advanced search ([#12704](https://github.com/ManageIQ/manageiq/pull/12704))
  - RBAC: Add Storage Product Features for Adding Roles ([#12701](https://github.com/ManageIQ/manageiq/pull/12701))
  - Remove confirmation when opening the HTML5 vnc/spice console. ([#12673](https://github.com/ManageIQ/manageiq/pull/12673))
  - Set categories correctly for policy timelines ([#12664](https://github.com/ManageIQ/manageiq/pull/12664))
  - Display name of a chosen filter in Infrastructure Providers ([#12307](https://github.com/ManageIQ/manageiq/pull/12307))
  - Only enable git import submit button when a branch or tag is selected ([#12753](https://github.com/ManageIQ/manageiq/pull/12753))
  - Send notifications only when user is authorized to see the referenced object ([#12771](https://github.com/ManageIQ/manageiq/pull/12771))
  - Add tags to objects in list view in Cloud Tenant ([#12833](https://github.com/ManageIQ/manageiq/pull/12833))
  - Set start date explicitly only when changing schedule interval ([#12816](https://github.com/ManageIQ/manageiq/pull/12816))
  - Display parent tenant only when it is allowed by RBAC ([#12848](https://github.com/ManageIQ/manageiq/pull/12848))
  - Fix position of chart menu in C&U when clicking close to right edge ([#12922](https://github.com/ManageIQ/manageiq/pull/12922))
  Fix missing Smart State Analysis button on Cloud Instances list view ([#12559](https://github.com/ManageIQ/manageiq/pull/12559))

## Unreleased - as of Sprint 49 end 2016-11-14

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+49+Ending+Nov+14%2C+2016%22+label%3Aenhancement)

- Automate
  - Git Support: Support automate model git repositories without domain directory
  - Notification: Add global and tenant notification audiences
  - Service Model
    - Expose ems_events to Vm service model
    - Expose a group's filters.
    - Expose authentication_key in EMS service model
  - Provisioning
    - Set zone when deliver a service template provision task
    - Create a request per region for VM reconfigure
  - Services
    - Expose service power state
- Platform
  - High Availability: Raise event when failover successful
  - Chargeback: Add daily to chargeback rate for 'per time' types
  - Replication: Add logging when the replication set is altered
  - Logging: Add configurable number of saved logfile rotations
- Providers
  - Containers UI: Label based Auto-Tagging UI
  - Middleware (Hawkular)
    - Add support to overwrite an existing deployment
  - Networks
    - Nuage: UI for Network elements
    - Add Network Topology button for the Load Balancer class
  - Red Hat Enterprise Virtualization Manager
      - Enable VM reconfigure disks for supported rhevm version
      - Migrate support
  - VMware vCloud: Event monitoring
- REST API
  - Add IDs to Dialog Content
  - Actions support
  - Conditions support
  - Support for /api/requests approve and deny actions
  - Service Dialogs Copy API
  - MiqPolicies support
  - Service Request Delete
- SmartState: Support analysis of VMs residing on NFS41 datastores

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+49+Ending+Nov+14%2C+2016%22+label%3Aenhancement)

- Performance
  - For resource_pools only bring back usable Resource Pools
  - Prune VM Tree folders first, so nodes can be properly prune and tree nodes can then be collapsed
  - Remove full refresh from provisioning flow
- Platform
 - Chargeback: Simplify Chargeback rates editor to only show relevant parameters
- Providers
 - RHEVM: Make C&U Metrics Database a mandatory field for Validation

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+49+Ending+Nov+14%2C+2016%22%20label%3Bbug)

Notable fixes include:

- Automate
  - Services: Set default value of param visible to true for all field types
  - Git Domains for Automate: Ensure a response when git repository does not contain domains
- Platform
  - Increase worker memory thresholds to avoid frequent restarts.
  - Perform RBAC user filter check on requested ids before allowing request
- Providers
  - Fix targeted refresh of a VM without its host clearing all folder relationships
  - OpenStack Cloud
    - Add logs for network and subnet CRUD
    - UI: Add missing toolbar options for cloud tenants and host aggregates
    - UI: Add missing add/remove hosts actions to host aggregate UI
  - RHVM: Pass storage domains collection in disks RHV api request
- User Interface
  - Internationalization: i18n support in pdf reports
  - Fix custom logo issue in header
  - Routing Error for reload on infrastructure networking
  - Add Advanced Search to Containers explorer
  - Fall-"back" to VMRC desktop client if no NPAPI plugin is available
  - Displays a more informative message on datasource deletion.
  - Display Advanced Search in Configuration management
  - Allow the retirement date to be cleared
  - Default Filters can be saved or reset

## Unreleased - as of Sprint 48 end 2016-10-24

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+48+Ending+Oct+24%2C+2016%22+label%3Aenhancement)

- Automate
  - Reset domain priorities at startup and restore
  - Set default entry points for non-generic catalog items
  - Model: Schema change for Cloud Orchestration Retirement class
  - Automation method that will choose VDC networks available in the given
cloud provider
  - Provisioning
    - Show shared networks in the OpenStack provisioning dialog
    - Reconnect orchestration stack with its template at post-provisioning
  - Domain Import
    - Rake task to import an Automate Model stored in a  Git Repository
    - Allow for setting up self signed certificate in Import Screen
    - REST API Git refresh and import
    - Route the REST API import call to the correct server with the Git Owner Server role
  - Added Automate $evm.create_notification method
  - Retirement
    - Allow VM's with unknown power state to retire.
    - Allow archived/orphaned VM's to retire
    - Added checks and logging for amazon retirement
  - Service Model
    - Added cinder backup/restore actions
    - RBAC for service models
  - Scheduling Automate Tasks via the rails console
- Platform
  - Configure kerberos to do dns_lookups for external authentication
  - Add additional cloud objects to RBAC filter
  - Chargeback
    - Add Vm Guid to report fields for ChargebackVm reports
    - Enable custom attributes for chargeback reports
    - Add monthly/hourly/weekly in rates for 'per time' types
    - Calculation changes taking into account averages and maximums per selected interval in report(monthly, weekly, daily)
  - Logging: Add the ability to use a different disk for storing log files
  - Tenancy: Introduce service for sharing resources across tenants
- Providers
  - Allow Vm to show floating and fixed ip addresses
  - Containers
    - Persist Container Templates
    - UI: Add Container Templates
  - Google Compute Engine: Support for parsing Google health checks during refresh
  - OpenStack
    - Cloud
      - UI: Cloud volume backup
      - CRUD for OpenStack Cloud tenants
      - Enable Image Snapshots
      - CRUD for OpenStack Host Aggregates
    - Infra
      - Enable node start and stop
      - Node destroy deletes node from Ironic
      - Add Ironic Controls
      - Set boot image for registered hosts
  - Storage: Cinder backup
- REST API
  - Service power operations
  - Add custom attributes to provider
  - Service Dialog Create
  - Support for /api/requests creation and edits
- SmartState: Add /etc/redhat-access-insights/machine-id to the sample VM analysis profile
- User Interface
  - Dashboard view for Infrastructure views
  - Conversion of Middleware Provider form to Angular
  - Add human name for Google & Azure load balancers
  - Ability to get to details of Ansible jobs
  - Add UI for generating authorization keys for remote regions
  - Disable tenant edit from cloud tenant mapping
  - Topology for Cloud Manager
  - Topology for Infra provider

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+48+Ending+Oct+24%2C+2016%22+label%3Aenhancement)

- Performance
  - Speed up RBAC when no vm in tree in Virtual Machine Explorer
  - Speed-up lookup for min/max storage_used metric
  - Add option to hide VMs in trees
- Platform: Set appliance "system" memory/swap information
- Providers
  - Google Cloud Platform: Use standard health states
  - Microsoft SCVMM: Set  default security protocol to ssl
  - Network: Use RESTful routes


### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+48+Ending+Oct+24%2C+2016%22%20label%3Bbug)

Notable fixes include:

- Automate
  - Broken ordering ae_domains for a root tenant.
  - Model: Added missing ServiceTemplateProvisionRequest_denied and ServiceTemplateProvisionRequest_pending instances so that Denied Service requests will properly generate emails.
  - Validate user roles against domain edit before allowing copy/edit on any objects under it
  - Provisioning: Stop appending the `_` character as part of the enforced VM naming.
  - Fixed case where user can't add alerts.
  - Fixed issue where alerts don't send SNMP v1 traps
- Platform
  - Chargeback: Fix Group by tag in chargeback report
  - Replication
    - Add repmgr tables to replication excludes
    - Don't consider tables that are always excluded during the schema check
    - Fixed bug in settings/access control where tenants from remote regions
are displayed in the tenant list view and in the tenant selection when adding/editing a group
- Providers
  - Containers: Ability to add a container provider with a port other than 8443
  - Azure: Show 'Memory (MB)' chart for azure instance
  - Hawkular UI: Domain mode server has different operations than normal standalone server
- User Interface
  - Enable Provision VMs button via relationships
  - Missing reset button for Job Template Service Dialog
  - Display the number of access control elements based on user permission
  - Rebuild timeline options when Apply button is pressed


## Unreleased - as of Sprint 47 end 2016-10-03

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+47+Ending+Oct+3%2C+2016%22+label%3Aenhancement)

- Automate
  - Provisioning
    - Filter networks and floating_ips for OpenStack provisioning
    - Added Google pre and post provisioning methods
    - Enabled support for vApp provisioning service
    - Backend support to enable VMware provisioning through selection of a DRS-enabled cluster instead of a host
    - Set VM storage profile in provisioning
  - Services
    - Log properly dynamic dialog field script error
    - Back-end support for Power Operations on Services
      - Service Items: Pass start/stop commands to associated resources.
      - Service Bundles: Honor bundle resource configuration for start/stop actions
  - Added top_level_namespace to miq_ae_namespace model to support filtering for pluggable providers
  - Created service_connections table to support connecting services together along with metadata
  - Generic Objects
    - Process Generic Object method call via automate
    - Methods content stored in Automate
    - Generic Object Definition model contains the method name only (Parameters defined in automate)
    - Methods can return data to caller
    - Methods can be overridden by domain ordering
- Platform
  - Centralized Administration
    - VM power operations
    - VM retirement
    - Leverages new ManageIQ API Client gem
  - Chargeback
    - Generate monthly report for a Service
Instance method on Service class
    - Daily schedule generates report for each Service
    - Enables SUI display of Service costs over last 30 days
    - Containers
      - Added image tag names for Containers in vim performance state.
      - Added a 'fixed_compute_metric' column to chargeback
      - Added rate assigning by tags to container images
      - Chargeback vm group by tag
  - Notifications
    - Dynamic substitution in notification messages
    - Generate for Lifecycle events
  - Tenancy
    - Mapping Cloud Tenants to ManageIQ Tenants
      - Prevent deleting mapped tenants from cloud provider
      - Added checkbox "Tenant Mapping Enabled" to Openstack Manager
    - Ad hoc sharing of resources across tenants
      - Backend modeling completed
      - Implementation in progress
- Providers
  - Core
    - Override default http proxy
    - Default reasons for supported features
    - Known features are discoverable
    - Every known feature is unsupported by default
    - `supports :reboot_guest`
  - Generate a csv of features supported across all models
  - Containers
    - Allow policies to prevent Container image scans
    - Chargeback rates based on container image tags
    - Keep pod-container relationship after disconnection
  - Google Compute Engine: Load Balancer refresh
  - Middleware (Hawkular)
    - Change labels in middleware topology
    - Added "Server State" into Middleware Server Details
    - Enabled search for Middleware entities
    - Users can add Middleware Datasources and JDBC Drivers
    - Metrics for JMS Topics and Queues
  - Microsoft Cloud (Azure)
    - Load Balancer inventory collection for Azure
    - Pagination support in armrest gem
  - Microsoft Infrastructure (SCVMM)
    - Set CPU sockets and cores per socket
  - Network
    - Nuage policy groups added
    - Load balancer service type actions for reconfigure, retirement, provisioning
    - UI for creating subnets
  - OpenStack
    - Add hardware state for Hosts
    - Map Flavors to Cloud Tenants during Openstack Cloud refresh
    - Cinder backup/restore actions added to model
    - UI to register Ironic nodes through Mistral
  - Red Hat Enterprise Virtualization
    - Report manufacturer and product info for RHEVM hosts
  - Storage
    - New Swift Storage Manager
    - New Cinder Storage Manager
    - Initial User Interface support for Storage Managers
  - VMware Cloud
    - Cloud orchestration stack operation: Create and delete stack
    - Collect virtual datacenters as availability zones
    - Event Catcher
  - VMware Infrastructure: Datastores are filtered by Storage Profiles in provisioning
- REST API
  - Version bumped to 2.3.0 in preparation for Euwe release
  - New /api/automate primary collection
  - Enhanced to return additional product information for the About modal
  - Bulk queries now support referencing resources by attributes
  - Added ability to delete one’s own notifications
  - Publish Blueprint API
  - Update Blueprint API to store bundle info in ui_properties
  - CRUD for Service create and orchestration template
  - Api for refreshing automate domain from git
  - Allow compressed IDs in resource references
- Service UI
  - Create picture
  - Generic requests OPTION method
  - Delete dialogs API
  - Updated the “update” API for blueprints to be more efficient
  - Cockpit integration
  - Added About modal
- SmartState
  - Containers: Settings for proxy environment variables
- User Interface
  - Add GUID validation for certain Azure fields in Cloud Provider screen
  - OpenStack: Register new Ironic nodes through Mistral
  - Timelines resdesigned
  - vSphere Distributed Switches tagging
  - Patternfly Labels for OpenSCAP Results
  - Operations UI Notifications




### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+47+Ending+Oct+3%2C+2016%22+label%3Aenhancement)

- Automate:
  - Changed Automate import to enable system domains
  - Google schema changes in Cloud Provision Method class
- Performance: Do not reload miq server in tree builder
- Providers: vSphere Host storage device inventory collection improvements
- REST API: Update API CLI to support the HTTP OPTIONS method.
- User Interface
  - Updated PatternFly to v3.11.0
  - Summary Screen styling updates

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+47+Ending+Oct+3%2C+2016%22+label%3bugs)

Notable fixes include:

- Automate
  - Fixed problem with request_pending email method
  - Set User.current_user in Automation Engine to fix issue where provisioning resources were not being assigned to the correct tenant
- Platform
  - Use correct adjustment in chargeback reports
  - Replication: Fix typo prevention full error message
  - Tenancy: User friendly tenant names
- Providers
    - Openstack: Catch unauthorized exception in refresh
    - Middleware: Fix operation timeout parameter fetch
    - Red Hat Enterprise Virtualization: Access VM Cluster relationship correctly
- Provisioning: VMware Infrastructure: sysprep_product_id field is no longer required
- REST API
  - API: Fix creation of Foreman provider
  - Ensure api config references only valid miq_product_features
- SmartState: Update logging and job error message when getting the service account for Containers
- User Interface
  - Add missing Searchbar and Advanced Search button
  - Containers: Download to PDF/CSV/Text - don't download deleted containers
  - Allow bring VM out of retirement from detail page
  - Inconsitent menues in Middleware Views
  - Save Authentication status on a Save
  - User friendly tenant names
  - RBAC:List only those VMs that the user has access to in planning

## Unreleased - as of Sprint 46 end 2016-09-12

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+46+Ending+Sep+12%2C+2016%22+label%3Aenhancement)

- Automate
  - Import Rake task `OVERWRITE` argument: Setting  `OVERWRITE=true` removes the target domain prior to import
  - New `extend_retires_on` method: Used by Automate methods to set a retirement date to specified number of days from today, or from a future date.
  - Service model updates
    - MiqAeServiceHardware
    - MiqAeServicePartition
    - MiqAeServiceVolume
- Platform
  - Centralized Administration
    - Server to server authentication
    - Invoke tasks on remote regions
    - Leverage new API client (WIP)
  - Chargeback
    - Support for generating chargeback for services
    - Will be used in Service UI for showing the cost of a service
  - Database Maintenance
    - Hourly reindex: High Churn Tables
    - Periodic full vacuum
    - Configure in appliance console
  - Notification Backend
    - Model for asynchronous notifications
    - Authentication token generation for web sockets
    - API for notification drawer
  - PostgreSQL High Availability
    - DB Cluster - Primary, Standbys
    - Uses [repmgr](http://www.repmgr.org/) (replication)
    - Failover
      - Primary to Standby
      - Appliance connects to new primary DB
  - Tenancy: Mapping Cloud Tenants to ManageIQ Tenants
    - Post refresh hook on OpenStack provider
    - Create provider base tenant under a root tenant
    - Cloud Tenant tree generated under provider base tenant
    - Create / Update / Delete
- Providers
  - Containers
    - Reports: Pods for images per project, Pods per node
    - Deployment wizard
  - Google Compute Engine: Provision Preemptible VMs
  - Hawkular  
    - JMS support (entities, topology)
    - Reports for Transactions (in App servers)
    - Support micro-lifecycle for Middleware-deployments
    - Middleware provider now uses restful routes
  - Microsoft Azure
    - Handle new events: Create Security Group, VM Capture
    - Provider-specific logging
  - Networking
    - Allow port ranges for Load Balancers
    - Load Balancer user interface
  - OpenStack
    - Collect inventory for cloud volume backups
    - Show topology for undercloud
    - Associate/Disassociate Floating IPs
  - Red Hat Enterprise Virtualization
    - Get Host OS version and type
    - Disk Management in VM Reconfigure
  - VMware: Filter Storage by Profile
  - vCloud
    - Collect status of vCloud Orchestration Stacks
    - Add Network Manager
    - Collect networking inventory
- REST API
  - Token manager supports for web sockets
  - Added querying for cockpit support
  - Added support for Bulk queries
  - Added support for UI notification drawer
  - API entrypoint returns details about the appliance via server_info
  - Blueprint updates now supports removal of the Service Catalog or Service Dialog from a Blueprint
- Service Broker: Service UI (name change from Self Service UI)
  - Renamed due to expanding number of use cases
  - Adding in Arbitration Rules UI
- User Interface
  - Added mandatory Subscription field to Microsoft Azure Discovery screen
  - Added Notifications Drawer and Toast Notifications List
  - Added support for vSphere Distributed Switches
  - Added support to show child/parent relations of Orchestration Stacks
  - Added Middleware Messaging entities to topology chart

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+46+Ending+Sep+12%2C+2016%22+label%3Aenhancement)

- Automate: Description for Datastore Reset action now includes list of target domains
- Performance
  - Page rendering
    - Compute -> Infrastructure -> Virtual Machines: 9% faster, 32% fewer rows tested on 3k active vms and 3k archived vms
    - Services -> My Services: 60% faster, 98% fewer queries, 32% fewer db rows returned
  - `Ownershipmixin`
    - Filtering now done in SQL
    - 99.5% faster (93.8s -> 0.5s) testing
      - VMs / All VMs / VMs I Own
      - VMs / All VMs / VMs in My LDAP Group
- User Interface: Dynatree replaced with bootstrap-treeview

## Unreleased - as of Sprint 45 end 2016-08-22

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+45+Ending+Aug+22%2C+2016%22+label%3Aenhancement)

- Automate
  - Enhanced messaging for provisioning: Displayed elements
    - ManageIQ Server name
    - Name of VM/Service being provisioned
    - Current Automate state machine step
    - Status message
    - Provision Task Message
    - Retry count (when applicable)
  - New method `taggable?` to programmatically determine if a Service Model class or instance is taggable.
  - Generic Objects: Model updates
    - Associations
    - Tagging
    - Service Methods: `add_to_service / remove_from_service`
  - Git Automate support
    - Branch/Tag support
    - Contents are locked and can be copied to other domains for editing
    - Editable properties
      - Enabled/Disabled
      - Priority
      - Removal of Domain
    - Dedicated Server Role to store the repository
- Platform
  - PostgreSQL High Availability
    - Primary/Standby DB config in Appliance Console
    - Database-only appliance config in Appliance Console
    - Failover Monitor
  - Tenancy
    - Groundwork in preparation for supporting multiple entitlements
    - ApplicationHelper#role_allows and User#role_allows? combined and moved to RBAC
    - Post refresh hook to queue mapping of Cloud Tenants
  - Database maintenance scripts added to appliance
- Providers
  - Containers: Models for container deployments
  - Google Compute Engine
    - Preemptible Instances
    - Retirement support
  - Hawkular    
    - Alerts
       - Link miq alerts and hawkular events on the provider
       - Convert ManageIQ alerts/profiles to hawkular group triggers/members of group triggers
       - Sync the provider when ManageIQ alerts and alert profiles are created/updated
   - Added entities: Domains and Server Groups including their visualization in topology
   - Datasource entity now has deletion operation
   - Support more event types for datasource and deployment
   - Cross linking to VMs added to topology
  - Microsoft Azure: Added memory and disk utilization metrics
  - OpenStack
    - Host Aggregates
    - Region Support
  - Red Hat Enterprise Virtualization: Snapshot support
  - VMware vSphere: Storage profiles
- REST API
  - Support for compressed ids in inbound requests
  - CRUD support for Arbitration Rules
- Service Broker
  - Service Designer: Blueprint API is 90% done, edit and publish are still in development
  - Arbitration Profiles
      - Collection of pre-defined settings
      - Work in conjunction with the Arbitration Engine
  - Rules Engine: API completed
- SmartState: Deployed new MiqDiskCache module for use with Microsoft Azure
    - Scan time reduced from >20 minutes to <5 minutes
    - Microsoft Azure backed read requests reduced from >7000 requests to <1000
- User Interface
  - I18n support for UI plugins
  - Arbitration Profiles management for Service Broker
  - Re-check Authentication button added to Provider list views
  - Provisioning button added to the Templates & Images list and summary screens
  - Subtype option added to Generic Catalog Items
  - About modal added to OPS UI

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+45+Ending+Aug+22%2C+2016%22+label%3Aenhancement)

- Performance: Page rendering performance
  - Services -> Workloads -> All VMs page load time reduced from 93,770ms to 524ms (99%) with a test of 20,000 VMs
- Platform
  - Upgrade ruby 2.2.5 to 2.3.1
  - Configure Rails web server - Puma or Thin
    - Puma is still the default
    - Planning on adding additional servers

### [Fixes](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+45+Ending+Aug+22%2C+2016%22+label%3A"technical+debt")

Notable fixes include:
- Microsoft Azure: Fix proxy for template lookups
- VMware vSphere: Block duplicate events
- REST API
  - Hide internal Tenant Groups from /api/groups
  - Raise 403 Forbidden for deleting read-only groups
  - API Request logging

## Unreleased - as of Sprint 44 end 2016-08-1

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+44+Ending+Aug+1%2C+2016%22+label%3Aenhancement)

- Automate
  - Simulation: RBAC filtering applied to Object Attributes
  - Service Provisioning: Exposed number_of_vms when building the provision request for a service
  - Service Dialogs: Support for “visible” flag for dynamic fields
  - Expose Compliance and ComplianceDetail models
  - New associations on VmOrTemplate and Host models:
    - `expose :compliances`
    - `expose :last_compliance`
  - New Service Models
    - Compliance: `expose :compliance_details`
    - ComplianceDetail: `expose :compliance`, `expose :miq_policy`
  - Generic Object: Service models created for GenericObject and GenericObjectDefinition
- Platform
  - PostgreSQL High Availability
    - Added [repmgr](http://repmgr.org/)  to support automatic failover
    - Maintain list of active standby database servers
    - Added [pg-dsn_parser](https://github.com/ManageIQ/pg-dsn_parser) for converting DSN to a hash
  - Tenancy: Added parent_id to CloudTenant as prerequisite for mapping OpenStack tenants to ManageIQ tenants
  - Watermark reports updated to be based on max of daily max value instead of max of average value
  - Nice values added to worker processes
-  Providers
  - Google Compute Engine: Metrics
  - Hawkular
    - Operations: Add Deployment, Start/stop deployment
    - Performance reports for datasources
    - Collect more metrics for datasource
  - Kubernetes: Cross-linking with OpenStack instances
  - Microsoft Azure: Support floating IPs during provisioning
  - Nuage: Inventory of Managed Cloud Subnets
  - Red Hat Enterprise Virtualization: v4 API
  - VMware vSphere: Storage Profiles modeling and inventory
  - VMware vCloud: Initial PRs for modeling and inventory
- REST API
  - Support for arbitrary resource paths
  - Work started on [ManageIQ API Client](https://github.com/ManageIQ/manageiq-api-client)
  - Support for Arbitration Profiles
  - Support for Cloud Networks queries
  - Support for Arbitration Settings
  - Updated /api/users to support edits of user settings
- User Interface
  - Both UIs updated to latest PatternFly and Angular PatternFly
  - Self Service UI language selections separated from Operations UI
  - Internationalization
    - Virtual Columns
    - Toolbars
    - Removed string interpolation (for better localization)
    - Changed to use gettext’s pluralization
  - Ansible Tower Jobs moved to the Configuration tab (from Clouds/Stacks)
  - Interactivity added to C3 charts on C&U screens  

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+44+Ending+Aug+1%2C+2016%22+label%3Aenhancement)

- Automate
  - Simulation: Updated defaults
    - Entry-point: `/System/Process/Request` (Previous value of “Automation”)
    - Execute Method: Enabled
  - Infrastructure Provision: Updated memory values for VM provisioning dialogs to 1, 2, 4, 8, 12, 16, 32 GB
- Performance: Reduced the time and memory required to schedule Capacity and Utilization data collection.
- Platform: Expression refactoring and cleanup with relative dates and times
- Providers: Hawkular
  - Upgrade of Hawkular gem to 2.3.0
  - Skip unreachable middleware providers when reporting
  - Add re-checking authentication status functionality/button
- User Interface
  - Converted to TreeBuilder - Snapshot, Policy, Policy RSOP, C&U Build Datastores and Clusters/Hosts, Automate Results
  - CodeMirror version updated (used for text/yaml editors)

### [Removed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+44+Ending+Aug+1%2C+2016%22+label%3Aenhancement)

- Platform
  - Removed rubyrep
  - Removed hourly checking of log growth and rotation if > 1gb
- User Interface: Explorer Presenter RJS removal

## Unreleased - as of Sprint 43 end 2016-07-11

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+43+Ending+July+11%2C+2016%22+label%3Aenhancement)

- Automate
  - Service resolution based on Provision Order
  - Added /System/Process/MiqEvent instance
  - Added Provider refresh call to Amazon retire state machine in Pre-Retirement state
  - Service Dialogs: Added ‘Visible’ flag to all dialog fields
  - Class Schema allows for EMS, Host, Policy, Provision, Request, Server, Storage, and VM(or Template) datatypes
    - Value is id of the objects
    - If object is not found, the attribute is not defined.
  - Null Coalescing Operator
    - Multiple String values separated by “||”
    - Evaluated on new attribute data type “Null Coalescing”
    - Order dependent, left to right evaluation
    - First non-blank value is used
    - Skip and warn about missing objects
- Platform: Custom attributes support in reporting and expressions
  - Selectable as a column
  - Usable in report filters and charts
- Providers
  - Amazon: Public Images Filter
  - Networking
    - Separate Google Network Manager
    - NFV: VNFD Templates and VNF Stacks
  - Hawkular
    - Deployment entity operations: Undeploy, redeploy
    - Server operations: Reload, suspend, resume
    - Live metrics for datasources and transactions
    - Performance reports for middleware servers
    - Support for alert profiles and alert automated expressions for middleware server
    - Crosslink middleware servers with RHEV VMs
    - Collect and display deployment status
    - Datasources topology view
- REST API
  - Support for report schedules
  - Support for approving or denying service requests
  - Support for OpenShift Container Deployments
  - Support for Virtual Templates
- Service Broker
  - Started work on Service Broker to allow ManageIQ to select VM for you based on criteria (cloud, cost, or performance)
  - Added API backend for Resourceless Servers
  - Added datastore for the default settings for resourceless servers
- SmartState: Generalized disk LRU caching module
  - Caching module can be used by any disk module, eliminating duplication.
  - Can be inserted “higher” in the IO path.
  - Configurable caching parameters (memory vs performance)
  - Will be employed to address Azure performance and throttling issues.
  - Other disk modules converted over time.
- User Interface
  - Settings moved to top right navigation header
  - C3 Charts fully implemented - chart interaction coming soon!
  - Tagging for Ansible Tower job templates
  - Live Search added to bootstrap selects
  - Self Service UI Order History with detail

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+43+Ending+July+11%2C+2016%22+label%3Aenhancement)

- Automate: Generic Object: Model refactoring/cleanup, use PostgreSQL jsonb column
- Performance
  - Capacity and Utlization improvements included reduced number of SQL queries and number of objects
  - Improved tag processing for Alert Profiles
  - UI Performance: specific pages targeted resulted in up to 98% reduction in rendering for those pages
- Platform: PostgreSQL upgraded to 9.5 needed for HA feature
- Providers:
  - Pluggability: Began extraction of Amazon Provider into separate repository
  - Hawkular
      - Upgraded to hawkular gem version 2.2.1
      - Refactor infrastructure for easier configuration
  - Ansible: Automate method updated to pass JobTemplate “Extra Variables” defined in the Provision Task
- User Interface
  - Default Filters tree converted to TreeBuilder - more on the way
  - Cloud Key Pair form converted to AngularJS (Dana - UX team)
  - Toolbars:Cleaned up partials, YAML -> classes
  - Provider Forms: Credentials Validation improvements

## Unreleased - as of Sprint 42 end 2016-06-20

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+42+Ending+June+20%2C+2016%22+label%3Aenhancement)

- Providers
  - Ansible Tower
      - Collect Job parameters during Provider Refresh
      - Log Ansible Tower Job output when deployment fails
  - Containers: Limit number of concurrent SmartState Analyses
  - OpenStack
      - Cleanup of Nova services after scale down
      - Prevent retired instances from starting
  - Hawkular
      - Added missing fields in UI to improve user experience
      - Middleware as top level menu item
      - Default view for Middleware is datasource
- Platform: Appliance Console
  - Limited menu when running inside a container
  - Removed menu items that are not applicable when running inside a container
- Automate
  - Engine: Allow arguments in method calls during substitution
  - Policy: Built-in policy to prevent retired VM from starting on a resume power operation
  - Service Model: Expose provision_priority value
  - Retirement: Restored retirement logic to verify that VM was provisioned or contains Lifecycle tag before processing
  - Added lifecycle tag as a default tag

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+42+Ending+June+20%2C+2016%22+label%3Aenhancement)

- Providers: Pluggability
  - Ask, Don't Assume
      - Remove provider specific constants
      - Ask whether provider supports VM architecture instead of assuming support by provider type
- Platform
  - Performance: Lazy load message catalogs for faster startup and reduced memory
  - Replication: Added "deprecated" in replication worker screen (Rubyrep replication will be removed in Euwe release)
  - Testing: Support for running tests in parallel
- REST API
  - Documentation version is 2.2 for Darga
  - Updated /api entrypoint so collection list is sorted

### [Fixes](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+42+Ending+June+20%2C+2016%22+label%3A"bug")

Notable fixes include:

- Providers
  - Hawkular: Fixes for LiveMetrics
  - VMware: Fix for adding multiple disks

## Unreleased - as of Sprint 41 end 2016-05-30

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+41+Ending+May+30%2C+2016%22+label%3Aenhancement)

- REST API: API CLI moved to tools/rest_api.rb
- Providers: Hawkular
  - Test additions for topology
  - Optimization and enhancement of event fetching

### [Removed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+41+Ending+May+30%2C+2016%22+label%3A"technical debt")

- REST API: gems/cfme_client removed

## Unreleased - as of Sprint 40 end 2016-05-09

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+40+Ending+May+30%2C+2016%22+label%3Aenhancement)

- REST API
  - Post Darga versioning updated to v2.3.0-pre
  - Added GET role identifiers

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+40+Ending+May+9%2C+2016%22+label%3Aenhancement)

- Platform
  - Tenancy: Splitting MiqGroup, Part 2
     - Filters moved to to Entitlement model
     - Enabler for sharing entitlements   
   - MiqExpression Refactoring

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
