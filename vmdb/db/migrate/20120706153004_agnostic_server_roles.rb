class AgnosticServerRoles < ActiveRecord::Migration
  class AssignedServerRole < ActiveRecord::Base
    belongs_to :server_role, :class_name => "AgnosticServerRoles::ServerRole"
  end

  class ServerRole < ActiveRecord::Base
    has_many :assigned_server_roles, :class_name => "AgnosticServerRoles::AssignedServerRole", :dependent => :destroy
  end

  class MiqQueue < ActiveRecord::Base
    self.table_name = "miq_queue"
  end

  class MiqServer < ActiveRecord::Base
    has_many :configurations, :class_name => "AgnosticServerRoles::Configuration", :dependent => :destroy
  end

  class Configuration < ActiveRecord::Base
    belongs_to :miq_server, :class_name => "AgnosticServerRoles::MiqServer", :foreign_key => "miq_server_id"

    def self.stringify(h)
      ret = eval(h.inspect)
      ret = YAML::load(ret) if ret.is_a?(String) && ret =~ /^---/
      ret.each_key {|k| ret[k].stringify_keys!}.stringify_keys!
    end

    def self.hash_to_yaml(hash)
      YAML.dump(stringify(hash))
    end

    def self.yaml_to_hash(yaml)
      YAML::load(MiqERBForYAML.new(yaml).result) unless yaml.nil?
    end
  end

  def up
    # Return the key (as a string) if the key is not found.
    changed_up_hash = Hash.new { |_, k| k.to_s }.merge(
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
      "smisrefresh"               => "storage_inventory",
      "userinterface"             => "user_interface",
      "webservices"               => "web_services"
    )

    say_with_time("Migrating ServerRoles to be Vendor/Platform Agnostic") do
      ServerRole.all.each do |sr|
        role_name = sr.name
        case role_name
        when "vcrefresh"
          sr.update_attributes(
            :name        => "ems_inventory",
            :description => "Management System Inventory"
          )
        when "vcenter"
          sr.update_attributes(
            :name        => "ems_operations",
            :description => "Management System Operations"
          )
        when "netapprefresh"
          sr.update_attributes(
            :name        => "storage_inventory",
            :description => "Storage Inventory"
          )
        when "scvmm", "kvm", "rhevm", "smisrefresh", "smartstate_drift"
          sr.destroy
        else
          sr.update_attributes(:name => changed_up_hash[role_name]) if changed_up_hash.has_key?(role_name)
        end
      end
    end

    say_with_time("Deleting MiqQueue Messages with Role=vcrefresh") do
      MiqQueue.destroy_all(:role => "vcrefresh")
    end

    say_with_time("Migrating MiqQueue Messages to Vendor/Platform Agnostic Roles") do
      changed_up_hash.each do |key, value|
        MiqQueue.where(:role => key).update_all(:role => value)
      end
    end

    say_with_time("Migrating MiqQueue Messages to New Queue Names") do
      changed_up_hash.each do |key, value|
        MiqQueue.where(:queue_name => key).update_all(:queue_name => value)
      end
    end

    say_with_time("Migrating Configuration Roles for each MiqServer") do
      MiqServer.all.each do |s|
        c = s.configurations.where(:typ => "vmdb").first
        next if c.nil?
        settings = c.class.yaml_to_hash(c.settings)

        # HACK: existing VMDB::Config code allows for strings to be serialized as yaml twice
        settings = c.class.yaml_to_hash(settings) if settings.kind_of?(String)
        next unless settings.kind_of?(Hash)
        next unless settings['server'].kind_of?(Hash)
        roles = settings['server']['role']
        next if roles.nil?
        settings['server']['role'] = roles.split(",").collect { |r| changed_up_hash[r] }.compact.join(",")
        c.update_attributes(:settings => c.class.hash_to_yaml(settings))
      end
    end
  end

  def down
    # Return the key (as a string) if the key is not found.
    changed_down_hash = Hash.new { |_, k| k.to_s }.merge(
      "database_operations"         => "dbops",
      "database_owner"              => "dbowner",
      "database_synchronization"    => "dbsync",
      "ems_metrics_collector"       => "performancecollector",
      "ems_metrics_coordinator"     => "performancecoordinator",
      "ems_metrics_processor"       => "performanceprocessor",
      "storage_metrics_collector"   => "storagemetricscollector",
      "storage_metrics_coordinator" => "storagemetricscoordinator",
      "storage_metrics_processor"   => "storagemetricsprocessor",
      "ems_inventory"               => "vcrefresh",
      "ems_operations"              => "vcenter",
      "vmdb_storage_bridge"         => "vmdbstoragebridge",
      "storage_inventory"           => "netapprefresh",
      "user_interface"              => "userinterface",
      "web_services"                => "webservices"
    )

    say_with_time("Reverting ServerRoles to not be Vendor/Platform Agnostic") do
      ServerRole.all.each do |sr|
        role_name = sr.name
        case sr.name
        when "ems_inventory"
          sr.update_attributes(
            :name        => "vcrefresh",
            :description => "vCenter Inventory"
          )
        when "ems_operations"
          sr.update_attributes(
            :name        => "vcenter",
            :description => "vCenter Operations"
          )
        when "storage_inventory"
          sr.update_attributes(
            :name        => "netapprefresh",
            :description => "Storage Inventory (NetApp)"
          )
        else
          sr.update_attributes(:name => changed_down_hash[role_name]) if changed_down_hash.has_key?(role_name)
        end
      end
    end

    say_with_time("Deleting MiqQueue Messages with Role=ems_inventory") do
      MiqQueue.destroy_all(:role => "ems_inventory")
    end

    say_with_time("Reverting MiqQueue Messages to non Vendor/Platform Agnostic Roles") do
      changed_down_hash.each do |key, value|
        MiqQueue.where(:role => key).update_all(:role => value)
      end
    end

    say_with_time("Reverting MiqQueue Messages to old Queue Names") do
      changed_down_hash.each do |key, value|
        MiqQueue.where(:queue_name => key).update_all(:queue_name => value)
      end
    end

    say_with_time("Migrating Configuration Roles for each MiqServer") do
      MiqServer.all.each do |s|
        c = s.configurations.where(:typ => "vmdb").first
        next if c.nil?
        settings = c.class.yaml_to_hash(c.settings)
        next unless settings.kind_of?(Hash)
        next unless settings['server'].kind_of?(Hash)
        roles = settings['server']['role']
        next if roles.nil?
        settings['server']['role'] = roles.split(",").collect { |r| changed_down_hash[r] }.compact.join(",")
        c.update_attributes(:settings => c.class.hash_to_yaml(settings))
      end
    end
  end
end
