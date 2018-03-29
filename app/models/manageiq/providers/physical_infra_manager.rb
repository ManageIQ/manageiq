module ManageIQ::Providers
  class PhysicalInfraManager < BaseManager
    include SupportsFeatureMixin

    virtual_total :total_physical_racks,      :physical_racks
    virtual_total :total_physical_switches,   :physical_switches
    virtual_total :total_physical_chassis,    :physical_chassis
    virtual_total :total_physical_servers,    :physical_servers
    virtual_column :total_hosts,              :type => :integer
    virtual_column :total_vms,                :type => :integer

    class << model_name
      define_method(:route_key) { "ems_physical_infras" }
      define_method(:singular_route_key) { "ems_physical_infra" }
    end

    def self.ems_type
      @ems_type ||= "physical_infra_manager".freeze
    end

    def self.description
      @description ||= "PhysicalInfraManager".freeze
    end

    def validate_authentication_status
      {:available => true, :message => nil}
    end

    def count_physical_servers_with_host
      physical_servers.inject(0) { |t, physical_server| physical_server.host.nil? ? t : t + 1 }
    end

    alias total_hosts count_physical_servers_with_host

    def count_vms
      physical_servers.inject(0) { |t, physical_server| physical_server.host.nil? ? t : t + physical_server.host.vms.size }
    end

    alias total_vms count_vms

    supports :console do
      unless console_supported?
        unsupported_reason_add(:console, N_("Console not supported"))
      end
    end

    def console_supported?
      false
    end

    def console_url
      raise MiqException::Error, _("Console not supported")
    end

    supports :change_password

    # Changes the password of userId on provider client and database.
    #
    # @param [current_password] password currently used for connected userId in provider client
    # @param [new_password]     password that will replace the current one
    #
    # @return [Boolean] true if the password was changed successfully
    def change_password(current_password, new_password, auth_type = :default)
      raw_change_password(current_password, new_password)
      update_authentication(auth_type => {:userid => authentication_userid, :password => new_password})

      true
    end

    def change_password_queue(userid, current_password, new_password, auth_type = :default)
      task_opts = {
        :action => "Changing the password for Physical Provider named '#{name}'",
        :userid => userid
      }

      queue_opts = {
        :class_name  => self.class.name,
        :instance_id => id,
        :method_name => 'change_password',
        :role        => 'ems_operations',
        :zone        => my_zone,
        :args        => [current_password, new_password, auth_type]
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end

    # This method must provide a way to change password on provider client.
    #
    # @param [_current_password]   password currently used for connected userId in provider client
    # @param [_new_password]       password that will replace the current one
    #
    # @return [Boolean]            true if the password was changed successfully
    #
    # @raise [MiqException::Error] containing the error message if was not changed successfully
    def raw_change_password(_current_password, _new_password)
      raise NotImplementedError, _("must be implemented in subclass")
    end
  end
end
