require_migration

describe MigrateAnsibleTowerConfigurationManagerSettingsToAutomationManager do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it 'changes the key of /ems_refresh/ansible_tower_configuration% to /ems_refresh/ansible_tower_automation%' do
      s1 = settings_change_stub.create!(
        :key   => '/ems_refresh/ansible_tower_configuration_abc/abc',
        :value => "targetedThing"
      )
      s2 = settings_change_stub.create!(
        :key   => '/ems_refresh/ansible_tower_configuration/abc',
        :value => "targetedThingAbc"
      )
      s3 = settings_change_stub.create!(
        :key   => '/ems_refresh/ansible_tower_something/abc',
        :value => "something"
      )

      migrate

      expect(s1.reload.key).to eq('/ems_refresh/ansible_tower_automation_abc/abc')
      expect(s2.reload.key).to eq('/ems_refresh/ansible_tower_automation/abc')
      expect(s3.reload.key).to eq('/ems_refresh/ansible_tower_something/abc')
    end

    it 'changes the keys /workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_configuration%' \
      ' to /workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_automation%' do
      s1 = settings_change_stub.create!(
        :key   => '/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_configuration_abc/abc',
        :value => "targetedThing"
      )
      s2 = settings_change_stub.create!(
        :key   => '/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_configuration/abc',
        :value => "targetedThingAbc"
      )
      s3 = settings_change_stub.create!(
        :key   => '/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_something/abc',
        :value => "something"
      )

      migrate

      expect(s1.reload.key).to eq('/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_automation_abc/abc')
      expect(s2.reload.key).to eq('/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_automation/abc')
      expect(s3.reload.key).to eq('/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_something/abc')
    end
  end

  migration_context :down do
    it 'changes the keys of /ems_refresh/ansible_tower_automation% back to be of Configuration Manager' do
      s1 = settings_change_stub.create!(
        :key   => '/ems_refresh/ansible_tower_automation_abc/abc',
        :value => "targetedThing"
      )
      s2 = settings_change_stub.create!(
        :key   => '/ems_refresh/ansible_tower_automation/abc',
        :value => "targetedThingAbc"
      )
      s3 = settings_change_stub.create!(
        :key   => '/ems_refresh/ansible_tower_something/abc',
        :value => "something"
      )

      migrate

      expect(s1.reload.key).to eq('/ems_refresh/ansible_tower_configuration_abc/abc')
      expect(s2.reload.key).to eq('/ems_refresh/ansible_tower_configuration/abc')
      expect(s3.reload.key).to eq('/ems_refresh/ansible_tower_something/abc')
    end

    it 'changes the keys of /workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_automation%' \
      ' back to be of Configuration Manager' do
      s1 = settings_change_stub.create!(
        :key   => '/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_automation_abc/abc',
        :value => "targetedThing"
      )
      s2 = settings_change_stub.create!(
        :key   => '/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_automation/abc',
        :value => "targetedThingAbc"
      )
      s3 = settings_change_stub.create!(
        :key   => '/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_something/abc',
        :value => "something"
      )

      migrate

      expect(s1.reload.key).to eq('/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_configuration_abc/abc')
      expect(s2.reload.key).to eq('/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_configuration/abc')
      expect(s3.reload.key).to eq('/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_ansible_tower_something/abc')
    end
  end
end
