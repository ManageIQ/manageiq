class MigrateAnsibleTowerConfigurationManagerSettingsToAutomationManager < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  def up
    say_with_time('Migrate /ems_refresh/ansible_tower_configuration% to be of Automation Manager') do
      SettingsChange.where('key LIKE ?', '/ems_refresh/ansible_tower_configuration%').each do |s|
        s.key = s.key.sub('/ansible_tower_configuration', '/ansible_tower_automation')
        s.save!
      end
    end

    say_with_time('Migrate /workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_configuration%' \
      ' to be of Automation Manager') do
      SettingsChange.where('key LIKE ?', '/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_configuration%').each do |s|
        s.key = s.key.sub(
          '/ems_refresh_worker_ansible_tower_configuration',
          '/ems_refresh_worker_ansible_tower_automation'
        )
        s.save!
      end
    end
  end

  def down
    say_with_time('Migrate /ems_refresh/ansible_tower_automation% back to be of Configuration Manager') do
      SettingsChange.where("key LIKE ?", "/ems_refresh/ansible_tower_automation%").each do |s|
        s.key = s.key.sub('/ansible_tower_automation', '/ansible_tower_configuration')
        s.save!
      end
    end

    say_with_time('Migrate /workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_configuration%' \
      ' back to be of Configuration Manager') do
      SettingsChange.where('key LIKE ?', '/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_automation%').each do |s|
        s.key = s.key.sub(
          '/ems_refresh_worker_ansible_tower_automation',
          '/ems_refresh_worker_ansible_tower_configuration'
        )
        s.save!
      end
    end
  end
end
