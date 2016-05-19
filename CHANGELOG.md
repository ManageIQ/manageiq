# Darga Release Candidate 1

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
- Appliance Console
  - Ability to reset database
  - Ability to create region in external database
  - Added alias 'ap' as shortcut for appliance_console
  - Updates for external authentication settings
- Shopping cart model for ordering services
- Consumption_administrator role with chargeback/reporting duties

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
    - MiqAction to annotate container images as non-secure at OpenShift
- Google Compute Engine 
  - Inventory
  - Power Operations
  - Provisioning
  - Events
  - Better OS identification for VMs
- Hawkular 
  - First Middleware provider
  - Inventory and topology
  - Event Catcher and power operations to reload and stop Middleware servers
  - Capacity and Utilization collected live on demand without need for Cap and U workers
  - Links to provider and entity in event popups on Timelines
     - Ability to configure default views
     - New Datasource entity (UI and Backend only)- Microsoft Azure
  - Http proxy support
  - Provisioning
  - Subscriptions and Events
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


### SmartState
- Microsoft SCVMM: new 
  -  Virtual hard disks residing on Hyper-V servers
  -  VHD, and newer VHDX disk formats
  -  Snapshotted disks
  -  Same filesystems as other providers
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
   

## Removed

- Providers: Removed Amazon SDK v1
- Platform: Removed rubyrep

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
- VM Provisoning: Disabled Auto-Placement logic for create_provision_request and Rest API calls
- Performance
  - Support for sorting Virtual Columns in the database
  - Service Tree improvement
  - RBAC: Ongoing effort to reduce the number SQL queries and quantity of data being transferred
  - Metrics Rollups bug fix
  - Performance capture failure on cloud platforms caused by orphan VMs
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

