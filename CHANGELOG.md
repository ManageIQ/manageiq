# Change Log

All notable changes to this project will be documented in this file.

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

