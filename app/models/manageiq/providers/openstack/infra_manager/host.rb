require 'openstack/openstack_configuration_parser'

class ManageIQ::Providers::Openstack::InfraManager::Host < ::Host
  belongs_to :availability_zone

  has_many :host_service_group_openstacks, :foreign_key => :host_id, :dependent => :destroy,
    :class_name => 'ManageIQ::Providers::Openstack::InfraManager::HostServiceGroup'

  has_many :network_ports, :as => :device
  has_many :network_routers, :through => :cloud_subnets
  has_many :cloud_networks, :through => :cloud_subnets
  alias_method :private_networks, :cloud_networks
  has_many :cloud_subnets, :through    => :network_ports
  has_many :public_networks, :through => :cloud_subnets

  has_many :floating_ips

  include_concern 'Operations'

  supports :refresh_network_interfaces

  # TODO(lsmola) for some reason UI can't handle joined table cause there is hardcoded somewhere that it selects
  # DISTINCT id, with joined tables, id needs to be prefixed with table name. When this is figured out, replace
  # cloud tenant with rails relations
  # in /app/models/miq_report/search.rb:83 there is select(:id) by hard
  # has_many :vms, :class_name => 'ManageIQ::Providers::Openstack::CloudManager::Vm', :foreign_key => :host_id
  # has_many :cloud_tenants, :through => :vms, :uniq => true

  def cloud_tenants
    ::CloudTenant.where(:id => vms.collect(&:cloud_tenant_id).uniq)
  end

  # TODO(aveselov) Added 3 empty methods here because 'entity' inside 'build_recursive_topology' calls for these methods.
  # Work still in progress, but at least it makes a topology visible for rhos undercloud.

  def load_balancers
  end

  def cloud_tenant
  end

  def security_groups
  end

  def ssh_users_and_passwords
    user_auth_key, auth_key = auth_user_keypair
    user_password, password = auth_user_pwd
    su_user, su_password = nil, nil

    # TODO(lsmola) make sudo user work with password. We will not probably support su, as root will not have password
    # allowed. Passwordless sudo is good enough for now

    if !user_auth_key.blank? && !auth_key.blank?
      passwordless_sudo = user_auth_key != 'root'
      return user_auth_key, nil, su_user, su_password, {:key_data => auth_key, :passwordless_sudo => passwordless_sudo}
    else
      passwordless_sudo = user_password != 'root'
      return user_password, password, su_user, su_password, {:passwordless_sudo => passwordless_sudo}
    end
  end

  def get_parent_keypair(type = nil)
    # Get private key defined on Provider level, in the case all hosts has the same user
    ext_management_system.try(:authentication_type, type)
  end

  def authentication_best_fit(requested_type = nil)
    [requested_type, :ssh_keypair, :default].compact.uniq.each do |type|
      auth = authentication_type(type)
      return auth if auth && auth.available?
    end
    # If auth is not defined on this specific host, get auth defined for all hosts from the parent provider.
    get_parent_keypair(:ssh_keypair)
  end

  def authentication_status
    if !authentication_type(:ssh_keypair).try(:auth_key).blank?
      authentication_type(:ssh_keypair).status
    elsif !authentication_type(:default).try(:password).blank?
      authentication_type(:default).status
    else
      # If credentials are not on host's auth, we use host's ssh_keypair as a placeholder for status
      authentication_type(:ssh_keypair).try(:status) || "None"
    end
  end

  def verify_credentials(auth_type = nil, options = {})
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(auth_type)
    raise MiqException::MiqHostError, "Logon to platform [#{os_image_name}] not supported" if auth_type.to_s != 'ipmi' && os_image_name !~ /linux_*/

    case auth_type.to_s
    when 'remote', 'default', 'ssh_keypair' then verify_credentials_with_ssh(auth_type, options)
    when 'ws'                               then verify_credentials_with_ws(auth_type)
    when 'ipmi'                             then verify_credentials_with_ipmi(auth_type)
    else
      verify_credentials_with_ws(auth_type)
    end

    true
  end

  def update_ssh_auth_status!
    # Creating just Auth status placeholder, the credentials are stored in parent or this auth, parent is
    # EmsOpenstackInfra in this case. We will create Auth per Host where we will store state, if it not exists
    auth = authentication_type(:ssh_keypair) ||
           ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair.create(
             :name          => "#{self.class.name} #{name}",
             :authtype      => :ssh_keypair,
             :resource_id   => id,
             :resource_type => 'Host')

    # If authentication is defined per host, use that
    best_fit_auth = authentication_best_fit
    auth = best_fit_auth if best_fit_auth && !parent_credentials?

    status, details = authentication_check_no_validation(auth.authtype, {})
    status == :valid ? auth.validation_successful : auth.validation_failed(status, details)
  end

  def missing_credentials?(type = nil)
    if type.to_s == "ssh_keypair"
      if !authentication_type(:ssh_keypair).try(:auth_key).blank?
        # Credential are defined on host
        !has_credentials?(type)
      else
        # Credentials are defined on parent ems
        get_parent_keypair(:ssh_keypair).try(:userid).blank?
      end
    else
      !has_credentials?(type)
    end
  end

  def parent_credentials?
    # Whether credentials are defined in parent or host. Missing credentials can be taken as parent.
    authentication_best_fit.try(:resource_type) != 'Host'
  end

  def refresh_openstack_services(ssu)
    openstack_status = ssu.shell_exec("openstack-status")
    services = MiqLinux::Utils.parse_openstack_status(openstack_status)
    self.host_service_group_openstacks = services.map do |service|
      # find OpenstackHostServiceGroup records by host and name and initialize if not found
      host_service_group_openstacks.where(:name => service['name'])
        .first_or_initialize.tap do |host_service_group_openstack|
        # find SystemService records by host
        # filter SystemService records by names from openstack-status results
        sys_services = system_services.where(:name => service['services'].map { |ser| ser['name'] })
        # associate SystemService record with OpenstackHostServiceGroup
        host_service_group_openstack.system_services = sys_services

        # find Filesystem records by host
        # filter Filesystem records by names
        # we assume that /etc/<service name>* is good enough pattern
        dir_name = "/etc/#{host_service_group_openstack.name.downcase.gsub(/\sservice.*/, '')}"

        matcher = Filesystem.arel_table[:name].matches("#{dir_name}%")
        files = filesystems.where(matcher)
        host_service_group_openstack.filesystems = files

        # save all changes
        host_service_group_openstack.save
        # parse files into attributes
        refresh_custom_attributes_from_conf_files(files) unless files.blank?
      end
    end
  rescue => err
    _log.log_backtrace(err)
    raise err
  end

  def refresh_custom_attributes_from_conf_files(files)
    # Will parse all conf files and save them to CustomAttribute
    files.select { |x| x.name.include?('.conf') }.each do |file|
      save_custom_attributes(file) if file.contents
    end
  end

  def add_unique_names(file, hashes)
    hashes.each do |x|
      # Adding unique ID for all custom attributes of a host, otherwise drift filters out the non unique ones
      section = x[:section] || ""
      name    = x[:name]    || ""
      x[:unique_name] = "#{file.name}:#{section}:#{name}"
    end
    hashes
  end

  def save_custom_attributes(file)
    hashes = OpenstackConfigurationParser.parse(file.contents)
    hashes = add_unique_names(file, hashes)
    EmsRefresh.save_custom_attributes_inventory(file, hashes, :scan) if hashes
  end

  def validate_set_node_maintenance
    {:available => true,   :message => nil}
  end

  def validate_unset_node_maintenance
    {:available => true,   :message => nil}
  end

  def disconnect_ems(e = nil)
    self.availability_zone = nil if e.nil? || ext_management_system == e
    super
  end

  def manageable_queue(userid = "system", _options = {})
    log_target = "#{self.class.name} name: [#{name}], id: [#{id}]"

    task = MiqTask.create(:name => "Setting node '#{name}' to manageable", :userid => userid)

    $log.info("Requesting manageable of #{log_target}")
    begin
      MiqEvent.raise_evm_job_event(self, :type => "manageable", :prefix => "request")
    rescue => err
      $log.warn("Error raising request manageable for #{log_target}: #{err.message}")
      return
    end

    $log.info("Queuing provide of #{log_target}")
    timeout = (VMDB::Config.new("vmdb").config.fetch_path(:host_manageable, :queue_timeout) || 20.minutes).to_i_with_method
    cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
    MiqQueue.put(
      :class_name   => self.class.name,
      :instance_id  => id,
      :args         => [task.id],
      :method_name  => "manageable",
      :miq_callback => cb,
      :msg_timeout  => timeout,
      :zone         => my_zone
    )
  end

  def manageable(taskid = nil)
    unless taskid.nil?
      task = MiqTask.find_by_id(taskid)
      task.state_active if task
    end

    log_target = "#{self.class.name} name: [#{name}], id: [#{id}]"

    $log.info("Setting to manageable #{log_target}...")

    task.update_status("Active", "Ok", "Setting to manageable") if task

    status = "Fail"
    task_status = "Ok"
    _dummy, t = Benchmark.realtime_block(:total_time) do
      begin
        connection = ext_management_system.openstack_handle.detect_baremetal_service
        response = connection.set_node_provision_state(name, "manage")

        if response.status == 202
          status = "Success"
          EmsRefresh.queue_refresh(ext_management_system)
        end
      rescue => err
        task_status = "Error"
        status = err
      end

      begin
        MiqEvent.raise_evm_job_event(self, :type => "manageable", :suffix => "complete")
      rescue => err
        $log.warn("Error raising complete manageable event for #{log_target}: #{err.message}")
      end
    end

    task.update_status("Finished", task_status, "Setting to Manageable Complete with #{status}") if task
    $log.info("Setting to Manageable #{log_target}...Complete - Timings: #{t.inspect}")
  end

  def introspect_queue(userid = "system", _options = {})
    log_target = "#{self.class.name} name: [#{name}], id: [#{id}]"

    task = MiqTask.create(:name => "Hardware Introspection for '#{name}' ", :userid => userid)

    $log.info("Requesting Hardware Introspection of #{log_target}")
    begin
      MiqEvent.raise_evm_job_event(self, :type => "introspect", :prefix => "request")
    rescue => err
      $log.warn("Error raising request introspection for #{log_target}: #{err.message}")
      return
    end

    $log.info("Queuing introspection of #{log_target}")
    timeout = (VMDB::Config.new("vmdb").config.fetch_path(:host_introspect, :queue_timeout) || 20.minutes).to_i_with_method
    cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
    MiqQueue.put(
      :class_name   => self.class.name,
      :instance_id  => id,
      :args         => [task.id],
      :method_name  => "introspect",
      :miq_callback => cb,
      :msg_timeout  => timeout,
      :zone         => my_zone
    )
  end

  def introspect(taskid = nil)
    unless taskid.nil?
      task = MiqTask.find_by_id(taskid)
      task.state_active if task
    end

    log_target = "#{self.class.name} name: [#{name}], id: [#{id}]"

    $log.info("Introspecting #{log_target}...")

    task.update_status("Active", "Ok", "Introspecting") if task

    workflow_state = ""
    task_status = "Ok"
    _dummy, t = Benchmark.realtime_block(:total_time) do
      begin
        connection = ext_management_system.openstack_handle.detect_workflow_service
        workflow = "tripleo.baremetal.v1.introspect"
        input = { :node_uuids => [name] }
        response = connection.create_execution(workflow, input)
        workflow_state = response.body["state"]
        workflow_execution_id = response.body["id"]

        while workflow_state == "RUNNING"
          sleep 5
          response = connection.get_execution(workflow_execution_id)
          workflow_state = response.body["state"]
        end
      rescue => err
        task_status = "Error"
        workflow_state = err
      end

      if workflow_state == "SUCCESS"
        EmsRefresh.queue_refresh(ext_management_system)
      end

      begin
        MiqEvent.raise_evm_job_event(self, :type => "introspect", :suffix => "complete")
      rescue => err
        $log.warn("Error raising complete introspect event for #{log_target}: #{err.message}")
      end
    end

    task.update_status("Finished", task_status, "Introspecting Complete with #{workflow_state}") if task
    $log.info("Introspecting #{log_target}...Complete - Timings: #{t.inspect}")
  end

  def provide_queue(userid = "system", _options = {})
    log_target = "#{self.class.name} name: [#{name}], id: [#{id}]"

    task = MiqTask.create(:name => "Providing node '#{name}' ", :userid => userid)

    $log.info("Requesting Provide of #{log_target}")
    begin
      MiqEvent.raise_evm_job_event(self, :type => "provide", :prefix => "request")
    rescue => err
      $log.warn("Error raising request provide for #{log_target}: #{err.message}")
      return
    end

    $log.info("Queuing provide of #{log_target}")
    timeout = (VMDB::Config.new("vmdb").config.fetch_path(:host_provide, :queue_timeout) || 20.minutes).to_i_with_method
    cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
    MiqQueue.put(
      :class_name   => self.class.name,
      :instance_id  => id,
      :args         => [task.id],
      :method_name  => "provide",
      :miq_callback => cb,
      :msg_timeout  => timeout,
      :zone         => my_zone
    )
  end

  def provide(taskid = nil)
    unless taskid.nil?
      task = MiqTask.find_by_id(taskid)
      task.state_active if task
    end

    log_target = "#{self.class.name} name: [#{name}], id: [#{id}]"

    $log.info("Provide #{log_target}...")

    task.update_status("Active", "Ok", "Provide") if task

    workflow_state = ""
    task_status = "Ok"
    _dummy, t = Benchmark.realtime_block(:total_time) do
      begin
        connection = ext_management_system.openstack_handle.detect_workflow_service
        workflow = "tripleo.baremetal.v1.provide"
        input = { :node_uuids => [name] }
        response = connection.create_execution(workflow, input)
        workflow_state = response.body["state"]
        workflow_execution_id = response.body["id"]

        while workflow_state == "RUNNING"
          sleep 5
          response = connection.get_execution(workflow_execution_id)
          workflow_state = response.body["state"]
        end
      rescue => err
        task_status = "Error"
        workflow_state = err
      end

      if workflow_state == "SUCCESS"
        EmsRefresh.queue_refresh(ext_management_system)
      end

      begin
        MiqEvent.raise_evm_job_event(self, :type => "provide", :suffix => "complete")
      rescue => err
        $log.warn("Error raising complete provide event for #{log_target}: #{err.message}")
      end
    end

    task.update_status("Finished", task_status, "Provide Complete with #{workflow_state}") if task
    $log.info("Provide #{log_target}...Complete - Timings: #{t.inspect}")
  end

  def validate_destroy
    if hardware.provision_state == "active"
      {:available => false, :message => "Cannot remove #{name} because it is in #{hardware.provision_state} state."}
    else
      {:available => true, :message => nil}
    end
  end

  def destroy_queue
    destroy_ironic_queue
  end

  def destroy_ironic_queue(userid = "system")
    log_target = "#{self.class.name} name: [#{name}], id: [#{id}]"

    task = MiqTask.create(:name => "Deleting Ironic node '#{name}'", :userid => userid)

    _log.info("Requesting Ironic delete of #{log_target}")
    begin
      MiqEvent.raise_evm_job_event(self, :type => "destroy_ironic", :prefix => "request")
    rescue => err
      $log.warn("Error raising request delete for #{log_target}: #{err.message}")
      return
    end

    _log.info("Queuing destroy_ironic of #{log_target}")
    timeout = (VMDB::Config.new("vmdb").config.fetch_path(:host_delete, :queue_timeout) || 20.minutes).to_i_with_method
    cb = {:class_name  => task.class.name,
          :instance_id => task.id,
          :method_name => :queue_callback_on_exceptions,
          :args        => ['Finished']}
    MiqQueue.put(
      :class_name   => self.class.name,
      :instance_id  => id,
      :args         => [task.id],
      :method_name  => "destroy_ironic",
      :miq_callback => cb,
      :msg_timeout  => timeout,
      :zone         => my_zone
    )
  end

  def destroy_ironic(taskid = nil)
    unless taskid.nil?
      task = MiqTask.find_by_id(taskid)
      task.state_active if task
    end

    log_target = "#{self.class.name} name: [#{name}], id: [#{id}]"

    _log.info("Deleting Ironic node #{log_target}...")

    task.update_status("Active", "Ok", "Deleting Ironic Node") if task

    status = "Fail"
    task_status = "Ok"
    _dummy, t = Benchmark.realtime_block(:total_time) do
      begin
        connection = ext_management_system.openstack_handle.detect_baremetal_service
        response = connection.delete_node(name)

        if response.status == 204
          Host.destroy_queue(id)
          status = "Success"
        end
      rescue => err
        task_status = "Error"
        status = err
      end
    end

    task.update_status("Finished", task_status, "Delete Ironic node #{log_target} finished with #{status}") if task
    _log.info("Delete Ironic node #{log_target}...Complete - Timings: #{t.inspect}")
  end

  def refresh_network_interfaces(ssu)
    smartstate_network_ports = MiqLinux::Utils.parse_network_interface_list(ssu.shell_exec("ip a"))

    neutron_network_ports = network_ports.where(:source => :refresh).each_with_object({}) do |network_port, obj|
      obj[network_port.mac_address] = network_port
    end
    neutron_cloud_subnets = ext_management_system.network_manager.cloud_subnets
    hashes = []

    smartstate_network_ports.each do |network_port|
      existing_network_port = neutron_network_ports[network_port[:mac_address]]
      if existing_network_port.blank?
        cloud_subnets = neutron_cloud_subnets.select do |neutron_cloud_subnet|
          if neutron_cloud_subnet.ip_version == 4
            IPAddr.new(neutron_cloud_subnet.cidr).include?(network_port[:fixed_ip])
          else
            IPAddr.new(neutron_cloud_subnet.cidr).include?(network_port[:fixed_ipv6])
          end
        end

        hashes << {:name          => network_port[:name] || network_port[:mac_address],
                   :type          => "ManageIQ::Providers::Openstack::NetworkManager::NetworkPort",
                   :mac_address   => network_port[:mac_address],
                   :cloud_subnets => cloud_subnets,
                   :device        => self,
                   :fixed_ips     => {:subnet_id     => nil,
                                      :ip_address    => network_port[:fixed_ip],
                                      :ip_address_v6 => network_port[:fixed_ipv6]}}

      elsif existing_network_port.name.blank?
        # Just updating a names of network_ports refreshed from Neutron, rest of attributes
        # is handled in refresh section.
        existing_network_port.update_attributes(:name => network_port[:name])
      end
    end
    unless hashes.blank?
      EmsRefresh.save_network_ports_inventory(ext_management_system, hashes, nil, :scan)
    end
  rescue => e
    _log.warn("Error in refreshing network interfaces of host #{id}. Error: #{e.message}")
    _log.warn(e.backtrace.join("\n"))
  end
end
