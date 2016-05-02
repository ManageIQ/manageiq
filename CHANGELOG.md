# Change Log

All notable changes to this project will be documented in this file.


## Unreleased - as of Sprint 39 end 2016-04-19

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+39+Ending+Apr+19%2C+2016%22+label%3Aenhancement)

- User Interface
  - Vertical navigation menus
  - VM Reconfigure - add/remove disks support
  - Orderable Orchestration Templates - create and copy 
  - Explorer for Datastore Clusters for VMware vSphere 5+ 
  - Template/Image compliance policy checking (previously only allowed for VMs/Instances)
  - New UI for replication configuration
- Providers
  - VMware: Clustered Datastores in Provisioning
  - Azure: Subscriptions and Events
  - OpenStack: Ceilometer Events
  - Hawkular: Event Catcher and power operations to reload and stop Middleware servers
  - Containers
     - Chargeback
     - SmartState extended with OpenSCAP support
     - Policies
     - Cloud Cross Linking
     - Pod Network Metrics
  - Generic Targeted refresh process
  - RHEV: Targeted refresh process
  - Multiple Endpoints
  - Ansible Tower
     - Model updates
         - Link JobTemplate instances to Inventory
         - Link Ansible hosts to VMs (when possible)
     - New Automate namespace: /ManageIQ/ConfigurationManagement/AnsibleTower
- Platform
  - Replication
     - Global and Remote regions
     - Enable replication on remote regions
     - Subscribe to remote regions on global
  - Chargeback: Rate tiers
- Appliance Console
  - Added alias `ap` as shortcut for appliance_console
  - Updates for external authentication settings
- REST API
  - CRUD for Tenant quotas
  - Version increased to 2.2.0
  - Support for /api/settings
- SmartState
  - LVM thin volume support
  - SmartState Analysis for Azure
- Automate
  - Modeling changes
     - `quota_source_type` moved into instance
     - Added Auto-Approval/Email to VM Reconfigure
     - New models for Generic Object
  - Beginning of git support for automate models
- Appliance: Ability to deliver ManageIQ docker appliance, first revision.

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+39+Ending+Apr+19%2C+2016%22+label%3Aenhancement)

- User Interface
  - SVG replacement of PNGs
  - SlickGrid replaced with Patternfly TreeGrid
  - Patternfly style updates to the Dashboard and other areas
  - Updates to support multiple provider endpoints
- VM Provisoning: Support disabling Auto-Placement logic for create_provision_request and Rest API calls
- Performance
  - Support for sorting Virtual Columns in the database
  - Service Tree improvement
  - RBAC: Ongoing effort to reduce the number SQL queries and quantity of data being transferred

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+39+Ending+Apr+19%2C+2016%22+label%3Abug)

Notable fixes include:

-Performance: Metrics Rollups bug fix

## Unreleased - as of Sprint 38 end 2016-03-28

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+38+Ending+Mar+28%2C+2016%22+label%3Aenhancement)

- Providers
  - Amazon as a pluggable provider: almost completed
  - Azure: http proxy support
  - Vmware: read-only datastores
  - Networking providers: new tab
  - Middleware: New provider type
  - Hawkular: first middleware provider, inventory and topology
- Appliance Core Chargeback
  - Able to assign rates to tenants
  - Can generate reports by tenant
  - Currencies added to rates
- Appliance Core Authentication
  - Appliance Console External Auth updated to also work with 6.x IPA Servers
  - SAML Authentication (verified with KeyCloak 1.8)
- REST API
  - Enhanced filtering to use MiqExpression
  - Enhanced API to include Role identifiers for collections and augmented the authorization hash in the entrypoint to include that correlation
- User Interface
  - VM: Devices and Network Adapters
  - Cloud: Key Pairs, Object Stores, Objects, Object Summary
  - SSUI: Support for Custom Buttons that use Dialogs
  - Containers: New Container Builds tab, Chargeback
  - More Bootstrap switches
  - C3 Charts (jqPlot replacement)
- SmartState
  - SCVMM: Support for network-mounted HyperV virtual disks and performance improvements (HyperDisk caching)
  - Azure
      - Azure-armrest: added offset/length blob read support.
      - Added AzureBlobDisk module for MiqDisk.
      - Implemented MiqAzureVm subclass of MiqVm.
  - Testing: Added TestEnvHelper class for gems/pending.
- Ansible Tower
  - Modeling for AnsibleTowerJob
  - Support for launching JobTemplates with a limit. (Target specific system)

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+38+Ending+Mar+28%2C+2016%22+label%3Aenhancement)

- Appliance Configuration Revamp
  - Relies heavily on the config gem
  - New classes Settings and Vmdb::Settings
  - `VMDB::Config` is deprecated
  - `config/*.tmpl.yml` -> `config/settings.yml`
  - Locally override with `config/settings.local.yml` or `config/settings/development.local.yml` 
- Replication (pglogical)
  - New MiqPglogical class: provides generic functionality for remote and global regions
  - New PglogicalSubscription model: Provides global region functionality as an ActiveRecord model
- Appliance Core - Tenancy - Splitting MiqGroup
  - New model created for entitlements
  - Will enable sharing entitlements across tenants
  - Will provide more flexibility for defining groups in LDAP
- Automate
  - Enhance state-machine fields to support methods
  - New Syntax: `METHOD::<method_name>`
- Services Back End
  - Service Order (Cart) created for each Service Request based on current user and tenant.
  - VMware add/remove disk methods for reconfigure


## Unreleased - as of Sprint 37 end 2016-03-07

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+37+Ending+Mar+7%2C+2016%22+label%3Aenhancement)

- Providers
  - Vmware: Clustered datastores
  - Containers: Bug fixes and UI updates
  - Microsoft SCVMM: Inventory Performance
  - Red Hat OpenStack: Instance Evacuation, better neutron modeling, Ceilometer events
  - Pluggable providers: Amazon extraction
- Tenancy
  - Added scoping strategy for provision request
  - Added ability to report on tenants and tenant quotas
- REST API
  - Added support for Service Reconfigure action
  - Added new service orders collection and CRUD operations
- SSUI
  - RBAC Control of Menus and Features
  - Reconfiguring a Service
  - Set Ownership of a Service
- Automate
  - Ansible Service Models
  - Added Google Auto-Placement methods

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+37+Ending+Mar+7%2C+2016%22+label%3Aenhancement)

- Core
  - Updated to Rails 5 (using Rails master branch until stable branch is cut)
  - Replacement of rubyrep with pglogical in progress
- Appliance Console
  - Ability to reset database
  - Ability to create region in external database

### [Removed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+37+Ending+Mar+7%2C+2016%22+label%3A%22technical+debt%22)

- Providers: Removed Amazon SDK v1

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+37+Ending+Mar+7%2C+2016%22+label%3Abug)

Notable fixes include:

- Tag management cleanup
  - Tags are removed from managed filters for all groups after deletion
  - Update of managed filters after tag rename (in progress)
- SmartState Analysis
  - LVM thin volume - fatal error: No longer fatal, but not supported. Thin volume support planned.
  - LVM logical volume names containing “-”: LV name to device file mapping now properly accounts for “-”
  - EXT4 - 64bit group descriptor: Variable group descriptor size correctly determined.
  - Collect services that are symlinked

## Unreleased - as of Sprint 36 end 2016-02-15

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+36+Ending+Feb+15%2C+2016%22+label%3Aenhancement)

- Providers
  - Containers
    - Reports
    - Linking registries with services
  - OpenStack Integration Features
     - Backend support for Live VM Migration
     - Backend support for VM resize
     - Support for Cinder and Glance v2
  - Continued work on conversion to Amazon SDK v2
  - Continued work on Multi-endpoint modeling
  - Azure Provisioning
  - Google Provisioning
- Appliance
  - Shopping cart model for ordering services
  - consumption_administrator role with chargeback/reporting duties
- REST API
  - Actions for instances: stop, start, pause, suspend, shelve, reset, reboot guest
  - Actions provided to approve or deny provision requests
  - Ability to delete one’s own authenticated token
- User Interface
  - I18n support added to the Self Service UI
  - Self Service UI group switcher
  - Ansible Tower providers
  - Containers: Persistent volumes, topology context menus     
- Ansible
  - Add Ansible as a Configuration Management Provider
  - Refresh of Configuration Scripts (Job Templates)

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+36+Ending+Feb+15%2C+2016%22+label%3Aenhancement)

- Automate
  - Retirement state-machine updates for SCVMM
  - Enhanced .missing method support
     - Save original method name in `_missing`_instance property
     - Accessible during instance resolution and within methods
- Updated to newer [ansible`_tower`_client gem](https://github.com/ManageIQ/ansible_tower_client):
    - Accessors for Host#groups and #inventory_id
  - Allow passing extra_vars to Job Template launch
  - Added JSON validation for extra_vars
- [Self Service UI](https://github.com/ManageIQ/manageiq-ui-self_service) extracted into its own repository setting up pattern for other independent UIs

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+36+Ending+Feb+15%2C+2016%22+label%3Abug)

Notable fixes include:

-  Initializers can now load ApplicationController w/o querying DB
-  10-20% performance improvement in vm explorer
-  DB seeding no longer silently catches exceptions

## Unreleased - as of Sprint 35 end 2016-01-25

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+35+Ending+Jan+25%2C+2016%22+label%3Aenhancement)

- Providers
  - OpenStack: cleanup SSL support, VM operations
  - Google Cloud Engine: Inventory, Power Operations
  - Microsoft SCVMM: Ability to delete VMs
- REST API
  - Added primary collection for Instances.
  - Added terminate action for instances.
  - Ability to filter string equality/inequality on virtual attributes.
  - For SSUI, ability to retrieve user’s default language
 and support for Dynamic Dialogs.
- User Interface
  - I18n: Marked translated strings directly in UI, Gettext support
  - Containers
    - Dashboard network trends
    - Container environment variables table
    - Search functionality for Container topology
    - Dashboard no data cards
    - Refresh option in Configuration dropdown
- Automate
  - SSUI: Support dialogs with dynamic fields
  - Simulate UI support for state machine retries
  - Service Models: Support where method, find_by, and find_by!
- Ansible
  - Modeling for Provider, Configuration Manager, and Configured Systems
  - Provider connection logic
  - Support refresh of Configured Systems
  - [ansible_tower_client](https://github.com/ManageIQ/ansible_tower_client) gem
    - Credential validation
    - Supported resources: Hosts, JobTemplates, Adhoc commands
- SmartState Analysis Support for Microsoft SCVMM
  -  Virtual hard disks residing on Hyper-V servers.
  -  VHD, and newer VHDX disk formats.
  -  Snapshotted disks.
  -  Same filesystems as other providers.

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+35+Ending+Jan+25%2C+2016%22+label%3Aenhancement)

- Appliance Core: Workers forked from main server process instead of spawned
- User Interface
  - Converted toolbar images to font icons
  - Enabled font icon support in list views
  - Implemented Bootstrap switch

## Unreleased - as of Sprint 34 end 2016-01-04

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+34+Ending+Jan+4%2C+2016%22+label%3Aenhancement)

- Providers
  - Containers: Network Trends, Heat Maps, Donuts
  - OpenStack: Memory metrics, image details, API over SSL
  - Google Cloud Engine: Power Operations
- REST API
  - Support for Case insensitive sorting
  - Adding new VM actions
  - Authentication: Option to not extend a token’s TTL
- External Authentication with IPA: Added support for top level domains needed in test environments
- User Interface
  - I18n for toolbars
  - Topology Status Colors
- Automate
  - Azure VM retirement modeling added
  - Switchboard events for OpenStack
    - New: compute.instance.reboot.end, compute.instance.reset.end, compute.instance.snapshot.start
    - Policy event updates: compute.instance.snapshot.end, compute.instance.suspend
- Service Model: Added “networks” relationship to Hardware model
-  Services
  -  Added instances/methods to generate emails for consolidated quota (Denied, Pending, Warning)
  - Enhanced Dialogs validation at build time to check tabs, and boxes in addition to fields.

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+34+Ending+Jan+4%2C+2016%22+label%3Aenhancement)

- Appliance OS updated to CentOS 7.2 build 1511
- Log Collection behavior updated
  - Zone depot used if requested on zone and defined. Else, collection disabled
  - Appliance depot used if requested on appliance and defined. Else, collection disabled
- User Interface: Bootstrap switches to replace checkboxes



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
- Google Cloud Engine
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
