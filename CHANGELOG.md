# Change Log

All notable changes to this project will be documented in this file.

## Unreleased - as of Sprint 23 end 2015-05-11

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+23+Ending+May+11%2C+2015%22+label%3Aenhancement)

- Foreman
  - Filtering of available Configuration Profiles based on selected Configured Systems in provisioning dialog
  - Exposed additional properties to reporting

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+23+Ending+May+11%2C+2015%22+label%3Aenhancement) 

- UI: Foreman Enhancements

# Botvinnik Release

### Added Features

#### Providers
- General
  - Added refresh status and errors, viewable on Provider Summary Page.
  - Added collection of raw power state and exposed to reporting.
  - Orchestration: Support for Retirement
  - Update authentication status when clicking validate for existing Providers
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
  - Added tag processing during provisioning
  - Added inventory collection of direct and inherited host/host-group settings
  - Organization and location inventory
- Cloud Providers
 - Cloud images and instances: Added root device type to summary screens.
 - Cloud flavors: Added block storage restriction to summary screens.
 - Enabled Reporting
- OpenStack
  - Inventory for Heat Stacks (Cloud and Infrastructure)
  - Connect Cloud provider to Infrastructure provider
  - OpenStack Infrastructure Host Events
  - Autoscale compute nodes via Automate
  - Support for non-admin users to EMS Refresh
  - Tenant relationships added to summary screens
  - OpenStack Infrastructure Event processing
  - Handling of power states: paused, rebooting, waiting to launch) 
  - UI OpenStack Terminology: Clusters vs Deployment Roles, Hosts vs Nodes
- Amazon
  - AWS Region EU Frankfurt
  - Inventory collection for AWS CloudFormation
  - Parsing of parameters from orchestration templates
  - Amazon Events via AWS Config service
  - Enables event-based policies for AWS
  - Added a backend attribute to identify public images.
  - Added C4, D2, and G2 instance types.
  - Virtualization type collected during EMS refresh for better
    filtering of available types during provisioning.
  - Handling of power states
- Orchestration
 - Orchestration Stacks includes tagging
 - Cloud Stacks: Summary and list views.
 - Orchestration templates
     - Create, edit, delete, tagging, ‘draft’ support
     - Create Service Dialog from template contents
 - Enabled Reporting / Tagging
 - Improved rollback error message in UI
 - Collect Stack Resource name and status reason message
     
#### Provisioning
- Heat Orchestration provisioning through services
- Foreman
  - Provisioning of bare metal systems
  - Uses latest Foreman Apipie gem
- Allow removing keys from :clone_options by setting value to nil
- OpenStack: Added tenant filtering on security groups, floating IPs, and
    networks.
- Amazon: Filtering of flavors based on root device type and block
    storage restrictions.

#### User Interface
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

#### Rest API 
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

#### Automate 
- Enhanced UI import to allow granularity down to the namespace.
- Cloud Objects exposed to Automate. 
- Allow Automate methods to override or extend parameters passed to provider by
  updating the clone_options during provisioning.  
- New service model for CloudResourceQuota.
- Exposed relationships through EmsCloud and CloudTenant models.
- Exposed cloud relationships in automate service models.
- Persist state data through automate state machine retries.
- Moved auto-placement into an Automate state-machine step for Cloud and Infrastructure provisioning.
- Added common "Finished" step to all Automate state machine classes.
- Added eligible_* and set_* methods for cloud resources to provision task service model.
- Ability to specify zone for web service automation request
- Ability to override request message
- Updated provisioning/retirement entry point in a catalog item or bundle.
- Disabled domains clearly marked in UI.
- Automate entry point selection reduced to state machine classes.
- Retirement
  - New workflow
  - Detection of User vs. System initiated retirement

#### Fleecing
- Qcow3
- VSAN (VMware)
- OpenStack instances
- Systemd fleecing support
- XFS filesystem support

#### I18n
  - All strings in the views have been converted to use gettext (I18n) calls
  - Can add/update I18n files with translations

#### Service Dialogs
- Dynamic field support: text boxes, text area boxes, checkboxes, radio buttons, date/time control
- Dynamic list field refactored into standard drop-down field
- Read only field support
- Dialog seeding for imports
- Service provisioning request overrides

#### IPv6 
- Allow IPv6 literals in VMware communication by upgrading httpclient
- Allow IPv6 literals in RHEVM/ovirt communication by fixing and upgrading rest-client and ruby 2.0
- Fixed URI building within ManageIQ to wrap/unwrap IPv6 literals as neede
  
#### Security 
- Lock down [POODLE](http://en.wikipedia.org/wiki/POODLE) attacks.
- Support SSL for OpenStack
  - Deals with different ways to configure SSL for OpenStack
    - SSL termination at OpenStack services
    - SSL termination at proxy
    - Doesn’t always change the service ports
  - Attempts non-SSL first, then fails over to SSL
- Kerberos ticket based SSO to web UI login.
- Fix_auth command tool can now update passwords in database.yml
- Better messaging around overwriting database encryption keys
- Make memcached listen on loopback address, not all addresses
- Migrate empty memcache_server_opts to bind on localhost by default 

#### Appliance
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


### Removed

- SmartProxy: 
  - Removed from UI
  - Directory removed
- IP Address Form Field: Removed from UI (use Hostname)
- Prototype from UI
- Support for repository refreshes, since they are not used.
- Support for Host-only refreshes.  Instead, an ESX/ESXi server should be added as a Provider.
- Rails Fork removal
  - Backport disable_ddl_transaction! from Rails master to our fork
  - Update the main app to use disable_ddl_transaction!
  - Add bigserial support for primary keys to Rails (including table creation and FK column creation)
  - Backport bigserial API to our fork
  - Update application to use new API
- Old C-Language VixDiskLib binding code
- Reduce need for Rails fork
- Testing: Removed have_same_elements custom matcher in favor of built-in match_array
- Graphical summary screens
- VDI support
- Various monkey patches to prepare for Ruby 2 and Rails 4 upgrades  

### Notable Fixes and Changes

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
 - Fixed “High CPU usage” due to continually restarting workers when a provider is unreachable or password is invalid.
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
  - Don’t collect cpus/memory available unless you have usage.- Clean up of CPU details in UI
 - SMTP domain length updated to match SMTP host length
 - Fleecing: Fixed handling of nil directory entries and empty files 
 - Fixed issue where deleting a cluster or host tries to delete all policy_events, thus never completing when there are millions of events.
 - Fixed inheriting tags from resource pool.
 - UI: Fixed RBAC / Feature bugs
 