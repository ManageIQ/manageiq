# Change Log

All notable changes to this project will be documented in this file.

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
