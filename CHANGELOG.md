# Change Log

All notable changes to this project will be documented in this file.

# Euwe

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
