require "spec_helper"
require_migration

describe MigrateOldConfigurationSettings do
  let(:config_stub) { migration_stub(:Configuration) }

  let(:old_settings) do
    {
      :api => {:token_ttl => "5.minutes"},
      :server => {:role => "role1,role2"},
      :workers => {
        :worker_base => {
          :queue_worker_base => {
            :ems_refresh_worker => {
              :default_stuff => "default_stuff",
              :ems_refresh_worker_rhevm => {:specific_stuff => "specific_stuff"},
            },
            :perf_collector_worker => {
              :default_stuff => "default_stuff",
              :ems_metrics_collector_worker_amazon => {:specific_stuff => "specific_stuff"},
            },
            :perf_processor_worker => {
              :default_stuff => "default_stuff",
            },
          },
          :event_catcher => {
            :default_stuff => "default_stuff",
            :event_catcher_redhat => {:specific_stuff => "specific_stuff"},
          }
        }
      }
    }
  end

  let(:new_settings) do
    {
      :api     => {:token_ttl => "5.minutes"},
      :server  => {:role => "role1,role2,user_interface,web_services"},
      :workers => {
        :worker_base => {
          :queue_worker_base => {
            :ems_refresh_worker           => {:defaults => {:default_stuff => "default_stuff"}},
            :ems_metrics_processor_worker => {:defaults => {:default_stuff => "default_stuff"}},
            :ems_metrics_collector_worker => {:defaults => {:default_stuff => "default_stuff"}},
          },
          :event_catcher => {:defaults => {:default_stuff => "default_stuff"}},
        }
      }
    }
  end

  let(:new_settings_with_web_server_worker_keys) do
    new_settings.tap do |s|
      s.store_path(:workers, :worker_base, :ui_worker, {})
      s.store_path(:workers, :worker_base, :web_service_worker, {})
      s.store_path(:server, :role, "role1,role2,role3")
    end
  end

  migration_context :up do
    it "with really old configuration data" do
      config_stub.create!(:typ => "vmdb", :settings => old_settings)

      migrate

      expect(config_stub.first.settings).to eq new_settings
    end

    it "with newer configuration data" do
      config_stub.create!(:typ => "vmdb", :settings => new_settings)

      migrate

      expect(config_stub.first.settings).to eq new_settings
    end

    it "will not modify the server roles if the ui_worker key is present" do
      config_stub.create!(:typ => "vmdb", :settings => new_settings_with_web_server_worker_keys)

      migrate

      expect(config_stub.first.settings).to eq new_settings_with_web_server_worker_keys
    end
  end
end
