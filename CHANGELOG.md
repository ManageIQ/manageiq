# Change Log

All notable changes to this project will be documented in this file.

## Unreleased - as of Sprint 19 end 2015-02-16

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+19+Ending+Feb+16%2C+2015%22+label%3Aenhancement)

- Providers
  - OpenStack Infrastructure Host Events
  - Kubernetes Inventory Collection
  - Foreman
     - Provider refresh (inventory)
     - Enabled Reporting / Tagging
     - Automate service models
     - Zone enablement
- Rest APIs
  - Tag Collection /api/tags 
  - Tag Management (assign and unassign to/from resources)
  - Foundational
     - Virtual attribute support  
     - Id/Href separation
  - Policy Management
     - Query policy and policy profiles conditions
 - VM Management
     - Custom Attributes
     - Add LifeCycle Events
- I18n Status
  - All strings in the views have been converted to use gettext (I18n) calls
  - Can add/update I18n files with translations
- Service Dialogs: Added Dynamic checkbox
- Orchestration
  - Provisioning dialog generator
  - Enabled Reporting / Tagging
  - Automate service models

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+19+Ending+Feb+16%2C+2015%22+label%3Aenhancement)

- UI
  - Login screen converted to Bootstrap / Patternfly
  - Header, navigation, and outer layouts converted to Bootstrap / Patternfly
  - Advanced search converted to Bootstrap / Patternfly
  - Stacks screens have icons now
  - Orchestration Insight
  - Schedule editor converted to AngularJS
  - UI Customizations with Less
  - Dashboard tabs updated

### [Removed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+19+Ending+Feb+16%2C+2015%22+label%3A%22technical+debt%22)

- I18N: All views converted to HAML
- Removed Prototype

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+19+Ending+Feb+16%2C+2015%22+label%3Abug)

- Notable fixes include:
 - EventEx is now disabled by default to help prevent event storms
 - Fixed ftp log collection regression
 - Fixed “High CPU usage” due to continually restarting workers, when a provider is unreachable or password is invalid
 - Fixed bug causing fleecing timeout
 - Fixed timeout issue with remove_from_disk method on a VM in Automate
 - Fixed duplicate VM name generation issue during provisioning

## Unreleased - as of Sprint 18 end 2015-01-26

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+18+Ending+Jan+26%2C+2015%22+label%3Aenhancement)

- Providers
  - Added refresh status and errors, viewable on Provider Summary Page.
  - Amazon EC2: Added C4 instance types.
- Rest API: VM start, stop, suspend, delete actions added.
- UI
 - Multi-character set language support
 - Cloud Stacks summary and list views
- Service Dialogs: Dynamic field support for text boxes and text area boxes
- IPv6: Ensure an IPv6 literal address, such as "[::1]", passed to the Excon gem removes the square brackets [], when establishing a Socket connection to the address, "::1".

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+18+Ending+Jan+26%2C+2015%22+label%3Aenhancement)

- Rails Updates
  - Moved to Rails 4 finders.
  - Removed patches against the logger classes.
  - Removed assumptions that associations are eagerly loaded.
- Fog gem updates for OpenStack

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+18+Ending+Jan+26%2C+2015%22+label%3Abug)

- 48 issues fixed. 
- Notable fixes include:
  - A new version of the Rake gem broke the nightly CentOS community builds requiring users to run `rake db:migrate`
  - OpenStack provisioning fix for non-admin tenants.

## Unreleased - as of Sprint 17 end 2015-01-05

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+17+Ending+Jan+5%2C+2015%22+label%3Aenhancement)

- UI  
  - Can now set the locale for both server and user
  - Repository Editor using AngularJS
  - Donut chart support
- IPv6: Underlying libraries for VMware and RHEVM/oVirt have been completed to support IPv6 literals. RHEVM/oVirt requires new releases from RESTClient and Ruby 2.0.
- SCVMM: Virtual DVD drives for templates
- Amazon
  - AWS Region EU Frankfurt
  - Inventory collection for AWS CloudFormation
  - Parsing of parameters from orchestration templates
- Provisioning: 
  - Allow removing keys from :clone_options by setting value to nil
  - Dynamic radio button support in dialogs

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+17+Ending+Jan+5%2C+2015%22+label%3Aenhancement)

- Rails 4 Upgrades
  - Updated  preloader patches against Rails
  - Updated virtual column / reflection code to integrate with Rails
  - Started moving ActiveRecord 2.3 hash based finders to Relation based finders
  - Backports and refactorings on master for Rails 4 support
- Changed classification seeding to only add classification if missing


### [Removed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+17+Ending+Jan+5%2C+2015%22+label%3A%22technical+debt%22)

- Support for repository refreshes, since they are not used.
- Support for Host-only refreshes.  Instead, an ESX/ESXi server should be added as an EMS, if that.


### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+17+Ending+Jan+5%2C+2015%22+label%3Abug)

- 38 issues fixed. 
- Notable fixes include:
  - UI: Fixed code to not allow deletion of locked domains.
  - OpenStack: Fixed image pagination issue where all of the images would not be collected.
  - RHEVM/oVirt: Ignore user login failed events to prevent event flooding.
  - SCVMM: Fixed refresh when Virtual DVD drives are not present.
  - Fleecing: Fixed handling of nil directory entries and empty files
  - Fixed virtual column inheritance creating duplicate entries.


## Unreleased - as of Sprint 16 end 2014-12-02

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+16+Ending+Dec+2%2C+2014%22+label%3Aenhancement)

- Rest API
  - Added support for accounts sub-collection /api/vms/#/accounts
  - Added support for software sub-collection /api/vms/#/software
- Providers: Amazon Events
  - Enables event-based policies for AWS
- UI: Continued work on supporting I18N
- IPv6 support
  - VMware communication (complete)
  - RHEVM/oVirt communication (in progress)
  
### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+16+Ending+Dec+2%2C+2014%22+label%3Aenhancement)

- UI: jqPlot, default charts, chart styling
- Cloud Orchestration: Modeling complete
- Services
  - Dialog seeding for imports
  - Service provisioning request overrides
- Automate Enhancements
  - Specify zone for web service automation request
  - Request message override
- LDAP
  - Allow undefined users to log in when “Get User Groups from LDAP” is disabled
  - Ability to set default group for LDAP Authentication

### [Removed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+16+Ending+Dec+2%2C+2014%22+label%3A%22technical+debt%22)

- SmartProxy (host) directory
- Rails Fork removal
  - Backport disable_ddl_transaction! from Rails master to our fork
  - Update the main app to use disable_ddl_transaction!
  - Add bigserial support for primary keys to Rails (including table creation and FK column creation)
  - Backport bigserial API to our fork
  - Update application to use new API

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+16+Ending+Dec+2%2C+2014%22+label%3Abug)

- 44 issues fixed. 
- Notable fixes include:
  - Fixed issue where deleting a cluster or host tries to delete all policy_events, thus never completing when there are millions of events.
  - Fixed inheriting tags from resource pool.
  - Fixed openstack provisioning to deal with multiple security groups with the same name.
  - Fixed seeding of VmdbDatabase timing out with millions of vmdb_metrics rows

## Unreleased - as of Sprint 15 end 2014-11-10

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+15+Ending+Nov+10%2C+2014%22+label%3Aenhancement)

- Security: Lock down [POODLE](http://en.wikipedia.org/wiki/POODLE) attacks.
- Ruby 2.0
  - Appliance now built using Ruby 2.0
  - New commits and pull requests - tested with Ruby 2.0
- Service Dialogs: Exports can be copied onto an appliance and seeded during appliance startup
- UI: Continued work on supporting I18N.
   
### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+15+Ending+Nov+10%2C+2014%22+label%3Aenhancement)

- Security
  - Command tool fix_auth now can update passwords in database.yml
  - Better messaging around overwriting database encryption keys (aka v2_key)
- More Rails patches removed/upstreamed/backported
  - Bigint id columns
  - Memoist gem replaced deprecated ActiveSupport::Memoizable
- UI: Replaced many legacy Prototype calls with jQuery equivalents.
- Upgraded AWS SDK gem
- Upgraded Fog gem

### [Removed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+15+Ending+Nov+10%2C+2014%22+label%3A%22technical+debt%22)

- Old C-Language VixDiskLib binding code
- Code from product that has been upstreamed into Rails.
- Testing: Removed have_same_elements custom matcher in favor of built-in match_array

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+15+Ending+Nov+10%2C+2014%22+label%3Abug)

- 45 issues closed.

## Unreleased - as of Sprint 14 end 2014-10-20

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+14+Ending+Oct+20%2C+2014%22+is%3Aclosed+label%3Aenhancement)

- Support SSL for OpenStack
  - Deals with different ways to configure SSL for OpenStack
    - SSL termination at OpenStack services
    - SSL termination at proxy
    - Doesn’t always change the service ports
  - Attempts non-SSL first, then fails over to SSL
- Model Template many-to-many Cloud Tenant
- Support Version 5 XFS filesystem
- Allow Automate methods to override or extend parameters passed to provider by
  updating the clone_options during provisioning

### [Changed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+14+Ending+Oct+20%2C+2014%22+is%3Aclosed+label%3Aenhancement)

- Updated report listviews to use glyphicons
- Chart Themes
- Allow Default Zone description to be changed   

### [Removed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+14+Ending+Oct+20%2C+2014%22+is%3Aclosed+label%3A%22technical+debt%22)

- Graphical summary screens
- VDI support
- Various monkey patches to prepare for Ruby 2 and Rails 4 upgrades  

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+14+Ending+Oct+20%2C+2014%22+is%3Aclosed+label%3Abug)

- 42 issues closed.

## Unreleased - as of Sprint 13 end 2014-09-29

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+13+Ending+Sept+29%2C+2014%22+is%3Aclosed+label%3Aenhancement)

- UI
  - OpenStack: Tenant relationships added to summary screens.
  - Cloud images and instances: Added root device type to summary screens.
  - Cloud flavors: Added block storage restriction to summary screens.
  - Cleaned up Service Requests list and detail views.
  - Added cloud models to reporting.
- Automate
  - Added new service model for CloudResourceQuota and exposed relationships
    through EmsCloud and CloudTenant models.
  - Enhanced import to allow granularity down to the namespace.
- Provisioning
  - OpenStack: Added tenant filtering on security groups, floating IPs, and
    networks.
  - Amazon: added filtering of flavors based on root device type and block
    storage restrictions.
- Providers
  - All: Added collection of raw power state and exposed to reporting.
  - Cloud: Added a backend attribute to identify public images.
  - OpenStack: Added support for non-admin users to EMS Refresh.
- Fleecing
  - Added XFS filesystem support.
- Security
  - Added Kerberos ticket based SSO to web UI login.
- Appliance
  - Added a rake task to allow a user to replicate all pending backlog before
    upgrading.
  - Appliance Console: Added ability to copy keys across appliances.

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+13+Ending+Sept+29%2C+2014%22+is%3Aclosed+label%3Abug)

- 80 issues fixed.  Notable fixes include
  - UI: Fixed RBAC / Feature bugs
  - OpenStack provider will gracefully handle 404 errors.
  - server_monitor_poll default setting changed to 5 seconds.  This should
    result in shorter queue wait times across the board.
  - Fixed issue where deleting an EMS and adding it back would cause failure to
    refresh.
  - Fixed issue where a stopped or paused OpenStack instance could not be
    restarted.
  - More Ruby 2.0 backward compatible fixes.

## Unreleased - as of Sprint 12 end 2014-09-09

### [Added](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+12+Ending+Sept+9%2C+2014%22+is%3Aclosed+label%3Aenhancement)

- Automate
  - Exposed cloud relationships in automate service models.
  - Persist state data through automate state machine retries.
  - Moved auto-placement into an Automate state-machine step for Cloud and
    Infrastructure provisioning.
  - Added common "Finished" step to all Automate state machine classes.
  - Added eligible_* and set_* methods for cloud resources to provision task
    service model.
- EMS Refresh / Provisioning
  - Amazon EC2 virtualization type collected during EMS refresh for better
    filtering of available types during provisioning.
- UI
  - UI updates to form buttons with Patternfly.
- REST API
  - Support for external authentication (httpd) against an IPA server.
- Appliance
  - Ability to configure a temp disk for OpenStack fleecing added to the
    appliance console.
  - Generation of encryption keys added to the appliance console and CLI.
  - Generation of PostgreSQL certificates, leveraging IPA, added to the
    appliance console CLI.
  - Support for Certmonger/IPA to the appliance certificate authority.
- Other
  - EVM dump tool enhanced.
  - A change log!

### [Fixed](https://github.com/ManageIQ/manageiq/issues?q=milestone%3A%22Sprint+12+Ending+Sept+9%2C+2014%22+is%3Aclosed+label%3Abug)

- 63 issues fixed.  Notable fixes include
  - Fixed appliance logrotate not actually rotating the logs.
  - Some Ruby 2.0 backward compatible fixes.
  - Gem upgrades for bugs/enhancements
    - haml
    - net-ldap
    - net-ping
