require "spec_helper"
require Rails.root.join("db/migrate/20131210202928_update_log_collection_path_in_configurations_settings")

describe UpdateLogCollectionPathInConfigurationsSettings do
  let(:configuration_stub) { migration_stub(:Configuration) }

  migration_context :up do
    it "updates the configuration to have the new PG settings" do
      old_settings = {
        "log" => {
          "collection" => {
            :current => {
              :pattern => [
                "log/*.log",
                "log/apache/*.log",
                "log/*.txt",
                "config/*",
                "/var/lib/pgsql/data/*.conf",
                "/var/lib/pgsql/data/serverlog*",
                "/var/log/syslog*",
                "/var/log/daemon.log*",
                "/etc/default/ntp*",
                "/var/log/messages*",
                "/var/log/cron*",
                "BUILD",
                "GUID",
                "VERSION"
              ]
            }
          }
        }
      }
      configuration_stub.create!(:typ => 'vmdb', :settings => old_settings)

      migrate

      settings = configuration_stub.first.settings
      settings.fetch_path("log", "collection", :current, :pattern, 4).should eq("/opt/rh/postgresql92/root/var/lib/pgsql/data/*.conf")
      settings.fetch_path("log", "collection", :current, :pattern, 5).should eq("/opt/rh/postgresql92/root/var/lib/pgsql/data/pg_log/*")
    end

    it "ignores changes when expected path doesn't exist" do
      old_settings = {
        "log" => {
          "collection" => {
            :current => {
              :pattern => []
            }
          }
        }
      }
      configuration_stub.create!(:typ => 'vmdb', :settings => old_settings)

      migrate

      settings = configuration_stub.first.settings
      settings.fetch_path("log", "collection", :current, :pattern).should be_empty
    end
  end

  migration_context :down do
    it "updates the configuration to have the old PG settings" do
      new_settings = {
        "log" => {
          "collection" => {
            :current => {
              :pattern => [
                "log/*.log",
                "log/apache/*.log",
                "log/*.txt",
                "config/*",
                "/opt/rh/postgresql92/root/var/lib/pgsql/data/*.conf",
                "/opt/rh/postgresql92/root/var/lib/pgsql/data/pg_log/*",
                "/var/log/syslog*",
                "/var/log/daemon.log*",
                "/etc/default/ntp*",
                "/var/log/messages*",
                "/var/log/cron*",
                "BUILD",
                "GUID",
                "VERSION"
              ]
            }
          }
        }
      }
      configuration_stub.create!(:typ => 'vmdb', :settings => new_settings)

      migrate

      settings = configuration_stub.first.settings
      settings.fetch_path("log", "collection", :current, :pattern, 4).should eq("/var/lib/pgsql/data/*.conf")
      settings.fetch_path("log", "collection", :current, :pattern, 5).should eq("/var/lib/pgsql/data/serverlog*")
    end

    it "ignores changes when expected path doesn't exist" do
      new_settings = {
        "log" => {
          "collection" => {
            :current => {
              :pattern => []
            }
          }
        }
      }
      configuration_stub.create!(:typ => 'vmdb', :settings => new_settings)

      migrate

      settings = configuration_stub.first.settings
      settings.fetch_path("log", "collection", :current, :pattern).should be_empty
    end
  end
end
