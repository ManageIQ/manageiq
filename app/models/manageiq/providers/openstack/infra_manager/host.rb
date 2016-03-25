require 'openstack/openstack_configuration_parser'

class ManageIQ::Providers::Openstack::InfraManager::Host < ::Host
  belongs_to :availability_zone

  has_many :host_service_group_openstacks, :foreign_key => :host_id, :dependent => :destroy,
    :class_name => 'ManageIQ::Providers::Openstack::InfraManager::HostServiceGroup'

  has_many :network_ports, :as => :device
  has_many :network_routers, :through => :cloud_subnets
  has_many :cloud_networks, :through => :cloud_subnets
  alias_method :private_networks, :cloud_networks
  has_many :cloud_subnets, :through    => :network_ports,
                           :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet"
  has_many :public_networks, :through => :cloud_subnets

  has_many :floating_ips

  include_concern 'Operations'

  # TODO(lsmola) for some reason UI can't handle joined table cause there is hardcoded somewhere that it selects
  # DISTINCT id, with joined tables, id needs to be prefixed with table name. When this is figured out, replace
  # cloud tenant with rails relations
  # in /app/models/miq_report/search.rb:83 there is select(:id) by hard
  # has_many :vms, :class_name => 'ManageIQ::Providers::Openstack::CloudManager::Vm', :foreign_key => :host_id
  # has_many :cloud_tenants, :through => :vms, :uniq => true

  def cloud_tenants
    ::CloudTenant.where(:id => vms.collect(&:cloud_tenant_id).uniq)
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
end
