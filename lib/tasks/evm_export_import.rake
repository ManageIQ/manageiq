# Rake script to export and import
#   * Alerts and AlertSets (Alert Profiles)
#   * Policies and PolicySets (Policy Profiles)
#   * Roles
#   * Tags
#   * Service Dialogs
#   * Provision Dialogs
#   * Custom Buttons
#   * SmartState Analysis Scan Profiles
#   * Customization Templates

namespace :evm do
  namespace :export do
    desc 'Exports all alerts to individual YAML files'
    task :alerts => :environment do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::Alerts.new.export(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Exports all alert profiles to individual YAML files'
    task :alertprofiles => :environment do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::AlertSets.new.export(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Exports all policies to individual YAML files'
    task :policies => :environment do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::Policies.new.export(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Exports all policy profiles to individual YAML files'
    task :policyprofiles => :environment do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::PolicySets.new.export(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Exports all roles to individual YAML files'
    task :roles => :environment do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::Roles.new.export(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Exports all scan profiles to individual YAML files'
    task :scan_profiles => [:environment] do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::ScanProfiles.new.export(options)
    end

    desc 'Exports all tags to individual YAML files'
    task :tags => :environment do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::Tags.new.export(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Exports all service dialogs to individual YAML files'
    task :service_dialogs => :environment do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::ServiceDialogs.new.export(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Exports all custom buttons to a single YAML file'
    task :custom_buttons => :environment do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::CustomButtons.new.export(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Exports all provision dialogs to individual YAML files'
    task :provision_dialogs => :environment do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::ProvisionDialogs.new.export(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Exports all customization templates to individual YAML files'
    task :customization_templates => :environment do
      options = TaskHelpers::Exports.parse_options
      TaskHelpers::Exports::CustomizationTemplates.new.export(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end
  end

  namespace :import do
    desc 'Imports all alerts from individual YAML files'
    task :alerts => :environment do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::Alerts.new.import(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Imports all alerts from individual YAML files'
    task :alertprofiles => :environment do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::AlertSets.new.import(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Imports all policies from individual YAML files'
    task :policies => :environment do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::Policies.new.import(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Imports all policy profiles from individual YAML files'
    task :policyprofiles => :environment do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::PolicySets.new.import(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Imports all roles from individual YAML files'
    task :roles => :environment do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::Roles.new.import(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Imports all scan profiles from individual YAML files'
    task :scan_profiles => [:environment] do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::ScanProfiles.new.import(options)
    end

    desc 'Imports all tags to individual YAML files'
    task :tags => :environment do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::Tags.new.import(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Imports all service dialogs from individual YAML files'
    task :service_dialogs => :environment do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::ServiceDialogs.new.import(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Imports all provision dialogs from individual YAML files'
    task :provision_dialogs => :environment do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::ProvisionDialogs.new.import(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Imports all custom buttons from YAML file'
    task :custom_buttons => :environment do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::CustomButtons.new.import(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc 'Imports all customization templates from individual YAML files'
    task :customization_templates => :environment do
      options = TaskHelpers::Imports.parse_options
      TaskHelpers::Imports::CustomizationTemplates.new.import(options)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end
  end
end
