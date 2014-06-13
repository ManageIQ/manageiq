require "spec_helper"
require Rails.root.join("db/migrate/20120706153004_agnostic_server_roles.rb")
require 'set'

ROLE_MAPPING = {:up => {}, :down => {}}
ROLE_MAPPING[:up] = {
  :unchanged => {
    "automate"                  => "automate",
    "event"                     => "event",
    "notifier"                  => "notifier",
    "reporting"                 => "reporting",
    "scheduler"                 => "scheduler",
    "smartproxy"                => "smartproxy",
    "smartstate"                => "smartstate"
  },
  :changed => {
    "dbops"                     => "database_operations",
    "dbowner"                   => "database_owner",
    "dbsync"                    => "database_synchronization",
    "performancecollector"      => "ems_metrics_collector",
    "performancecoordinator"    => "ems_metrics_coordinator",
    "performanceprocessor"      => "ems_metrics_processor",
    "storagemetricscollector"   => "storage_metrics_collector",
    "storagemetricscoordinator" => "storage_metrics_coordinator",
    "storagemetricsprocessor"   => "storage_metrics_processor",
    "vcrefresh"                 => "ems_inventory",
    "vcenter"                   => "ems_operations",
    "vmdbstoragebridge"         => "vmdb_storage_bridge",
    "netapprefresh"             => "storage_inventory",
    "smisrefresh"               => "storage_inventory", ## this one is also in the deleted roles list?
    "userinterface"             => "user_interface",
    "webservices"               => "web_services"
  }
}

ROLE_MAPPING[:down][:unchanged] = ROLE_MAPPING[:up][:unchanged]
ROLE_MAPPING[:down][:changed]   = ROLE_MAPPING[:up][:changed].delete_if{|k,v| k == "smisrefresh"}.invert

DELETED_SERVER_ROLES = ["scvmm", "kvm", "rhevm", "smisrefresh", "smartstate_drift"]

describe AgnosticServerRoles do
  migration_context :up do
    let(:assigned_server_role_stub)   { migration_stub(:AssignedServerRole) }
    let(:server_role_stub)            { migration_stub(:ServerRole) }
    let(:miq_queue_stub)              { migration_stub(:MiqQueue) }
    let(:miq_server_stub)             { migration_stub(:MiqServer) }
    let(:configuration_stub)          { migration_stub(:Configuration) }

    context "server roles" do
      it "updates server roles to be vendor/platform agnostic" do
        # ems_inventory, Management System Inventory
        sr_vcrefresh        = server_role_stub.create!(:name => "vcrefresh", :description => "Old VC Refresh Description")
        # ems_operations, Management System Operations
        sr_vcenter          = server_role_stub.create!(:name => "vcenter", :description => "Old VCenter Description")
        # storage_inventory, Storage Inventory
        sr_netapprefresh    = server_role_stub.create!(:name => "netapprefresh", :description => "Old Net App Refresh Description")

        # deleted
        sr_deleted = DELETED_SERVER_ROLES.map do |name|
          server_role_stub.create!(:name => name, :description => "#{name} description")
        end

        # unchanged
        sr_mapped_unchanged = ROLE_MAPPING[:up][:unchanged].map do |k,v|
          {:old_name => k, :new_name => v, :object => server_role_stub.create!(:name => k, :description => "#{k} description")}
        end

        # changed (ignore smisrefresh, since it's in the deleted set above)
        sr_mapped_changed = ROLE_MAPPING[:up][:changed].select{|k,v| k != "smisrefresh"}.map do |k,v|
          {:old_name => k, :new_name => v, :object => server_role_stub.create!(:name => k, :description => "#{k} description")}
        end

        migrate

        sr_vcrefresh.reload.name.should eq "ems_inventory"
        sr_vcrefresh.description.should eq "Management System Inventory"

        sr_vcenter.reload.name.should eq "ems_operations"
        sr_vcenter.description.should eq "Management System Operations"

        sr_netapprefresh.reload.name.should eq "storage_inventory"
        sr_netapprefresh.description.should eq "Storage Inventory"

        sr_deleted.each do |sr|
          server_role_stub.should_not exist(:id => sr.id)
        end

        sr_mapped_unchanged.each do |mapping|
          mapping[:object].reload.name.should eq mapping[:new_name]
        end

        sr_mapped_changed.each do |mapping|
          mapping[:object].reload.name.should eq mapping[:new_name]
        end
      end
    end

    context "miq queue messages" do
      it "deletes miq queue messages with vcrefresh roles" do
        miq_queue = miq_queue_stub.create!(:role => "vcrefresh")
        migrate
        miq_queue_stub.should_not exist(:id => miq_queue.id)
      end

      it "updates queue messages to have vendor/platform agnostic roles" do
        unchanged_messages = ROLE_MAPPING[:up][:unchanged].map do |k,v|
          {:old_role => k, :new_role => v, :object => miq_queue_stub.create!(:role => k)}
        end
        changed_messages = ROLE_MAPPING[:up][:changed].select{|k,v| k != "vcrefresh"}.map do |k,v|
          {:old_role => k, :new_role => v, :object => miq_queue_stub.create!(:role => k)}
        end

        migrate

        unchanged_messages.each do |mapping|
          mapping[:object].reload.role.should eq mapping[:new_role]
        end

        changed_messages.each do |mapping|
          mapping[:object].reload.role.should eq mapping[:new_role]
        end
      end

      it "applies new queue names to queue messages" do
        unchanged_messages = ROLE_MAPPING[:up][:unchanged].map do |k,v|
          {:old_role => k, :new_role => v, :object => miq_queue_stub.create!(:queue_name => k)}
        end
        changed_messages = ROLE_MAPPING[:up][:changed].map do |k,v|
          {:old_role => k, :new_role => v, :object => miq_queue_stub.create!(:queue_name => k)}
        end

        migrate

        unchanged_messages.each do |mapping|
          mapping[:object].reload.queue_name.should eq mapping[:new_role]
        end

        changed_messages.each do |mapping|
          mapping[:object].reload.queue_name.should eq mapping[:new_role]
        end
      end
    end

    context "miq servers" do
      it "updates miq servers with new configuration roles" do
        miq_server_unchanged = miq_server_stub.create!(:guid =>  MiqUUID.new_guid)
        roles = ROLE_MAPPING[:up][:unchanged].keys
        settings_yaml = configuration_stub.hash_to_yaml({"server" => {"role" => roles.join(",")}})
        configuration = configuration_stub.create!(:typ => "vmdb", :settings => settings_yaml, :miq_server_id => miq_server_unchanged.id)

        miq_server_changed = miq_server_stub.create!(:guid =>  MiqUUID.new_guid)
        roles = ROLE_MAPPING[:up][:changed].keys
        settings_yaml = configuration_stub.hash_to_yaml({"server" => {"role" => roles.join(",")}})
        configuration = configuration_stub.create!(:typ => "vmdb", :settings => settings_yaml, :miq_server_id => miq_server_changed.id)

        migrate

        configuration = miq_server_unchanged.reload.configurations.where(:typ => "vmdb").first
        settings = configuration_stub.yaml_to_hash(configuration.settings)
        settings["server"]["role"].split(",").to_set.should eq ROLE_MAPPING[:up][:unchanged].values.to_set

        configuration = miq_server_changed.reload.configurations.where(:typ => "vmdb").first
        settings = configuration_stub.yaml_to_hash(configuration.settings)
        settings["server"]["role"].split(",").to_set.should eq ROLE_MAPPING[:up][:changed].values.to_set
      end
    end
  end

  migration_context :down do
    let(:assigned_server_role_stub)   { migration_stub(:AssignedServerRole) }
    let(:server_role_stub)            { migration_stub(:ServerRole) }
    let(:miq_queue_stub)              { migration_stub(:MiqQueue) }
    let(:miq_server_stub)             { migration_stub(:MiqServer) }
    let(:configuration_stub)          { migration_stub(:Configuration) }

    context "server roles" do
      it "reverts server roles to be vendor/platform specific" do
        # ems_inventory, Management System Inventory
        sr_vcrefresh        = server_role_stub.create!(:name => "ems_inventory", :description => "Old VC Refresh Description")
        # ems_operations, Management System Operations
        sr_vcenter          = server_role_stub.create!(:name => "ems_operations", :description => "Old VCenter Description")
        # storage_inventory, Storage Inventory
        sr_netapprefresh    = server_role_stub.create!(:name => "storage_inventory", :description => "Old Net App Refresh Description")

        # mapped
        sr_mapped_unchanged = ROLE_MAPPING[:down][:unchanged].map do |k,v|
          {:old_name => k, :new_name => v, :object => server_role_stub.create!(:name => k, :description => "#{k} description")}
        end

        sr_mapped_changed = ROLE_MAPPING[:down][:changed].map do |k,v|
          {:old_name => k, :new_name => v, :object => server_role_stub.create!(:name => k, :description => "#{k} description")}
        end

        migrate

        sr_vcrefresh.reload.name.should eq "vcrefresh"
        sr_vcrefresh.description.should eq "vCenter Inventory"

        sr_vcenter.reload.name.should eq "vcenter"
        sr_vcenter.description.should eq "vCenter Operations"

        sr_netapprefresh.reload.name.should eq "netapprefresh"
        sr_netapprefresh.description.should eq "Storage Inventory (NetApp)"

        sr_mapped_unchanged.each do |mapping|
          mapping[:object].reload.name.should eq mapping[:new_name]
        end

        sr_mapped_changed.each do |mapping|
          mapping[:object].reload.name.should eq mapping[:new_name]
        end
      end
    end

    context "miq queue messages" do
      it "deletes miq queue messages with ems_inventory roles" do
        miq_queue = miq_queue_stub.create!(:role => "ems_inventory")
        migrate
        miq_queue_stub.should_not exist(:id => miq_queue.id)
      end

      it "revert queue messages to have vendor/platform specific roles" do
        unchanged_messages = ROLE_MAPPING[:down][:unchanged].map do |k,v|
          {:old_role => k, :new_role => v, :object => miq_queue_stub.create!(:role => k)}
        end
        changed_messages = ROLE_MAPPING[:down][:changed].select{|k,v| k != "ems_inventory"}.map do |k,v|
          {:old_role => k, :new_role => v, :object => miq_queue_stub.create!(:role => k)}
        end

        migrate

        unchanged_messages.each do |mapping|
          mapping[:object].reload.role.should eq mapping[:new_role]
        end

        changed_messages.each do |mapping|
          mapping[:object].reload.role.should eq mapping[:new_role]
        end
      end

      it "reverts queue messages to use old queue names" do
        unchanged_messages = ROLE_MAPPING[:down][:unchanged].map do |k,v|
          {:old_role => k, :new_role => v, :object => miq_queue_stub.create!(:queue_name => k)}
        end
        changed_messages = ROLE_MAPPING[:down][:changed].map do |k,v|
          {:old_role => k, :new_role => v, :object => miq_queue_stub.create!(:queue_name => k)}
        end

        migrate

        unchanged_messages.each do |mapping|
          mapping[:object].reload.queue_name.should eq mapping[:new_role]
        end

        changed_messages.each do |mapping|
          mapping[:object].reload.queue_name.should eq mapping[:new_role]
        end
      end
    end

    context "miq servers" do
      it "updates miq servers with new configuration roles" do
        miq_server_unchanged = miq_server_stub.create!(:guid => MiqUUID.new_guid)
        roles = ROLE_MAPPING[:down][:unchanged].keys
        settings_yaml = configuration_stub.hash_to_yaml({"server" => {"role" => roles.join(",")}})
        configuration = configuration_stub.create!(:typ => "vmdb", :settings => settings_yaml, :miq_server_id => miq_server_unchanged.id)

        miq_server_changed = miq_server_stub.create!(:guid => MiqUUID.new_guid)
        roles = ROLE_MAPPING[:down][:changed].keys
        settings_yaml = configuration_stub.hash_to_yaml({"server" => {"role" => roles.join(",")}})
        configuration = configuration_stub.create!(:typ => "vmdb", :settings => settings_yaml, :miq_server_id => miq_server_changed.id)

        migrate

        configuration = miq_server_unchanged.reload.configurations.where(:typ => "vmdb").first
        settings = configuration_stub.yaml_to_hash(configuration.settings)
        settings["server"]["role"].split(",").to_set.should eq ROLE_MAPPING[:down][:unchanged].values.to_set

        configuration = miq_server_changed.reload.configurations.where(:typ => "vmdb").first
        settings = configuration_stub.yaml_to_hash(configuration.settings)
        settings["server"]["role"].split(",").to_set.should eq ROLE_MAPPING[:down][:changed].values.to_set
      end
    end
  end
end
