# Rake script to export and import Alerts and AlertSets (Alert Profiles)

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
  end
end
