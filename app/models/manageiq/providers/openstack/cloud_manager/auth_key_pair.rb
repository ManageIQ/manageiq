class ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair < ManageIQ::Providers::CloudManager::AuthKeyPair
  def self.raw_create_key_pair(ext_management_system, create_options)
    connection_options = {:service => 'Compute'}
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.key_pairs.create(create_options)
    end
  rescue => err
    _log.error "keypair=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, err.to_s, err.backtrace
  end

  def self.validate_create_key_pair(ext_management_system)
    validate_key_pair(ext_management_system)
  end

  def raw_delete_key_pair
    connection_options = {:service => 'Compute'}
    resource.with_provider_connection(connection_options) do |service|
      service.delete_key_pair(name)
    end
  rescue => err
    _log.error "keypair=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, err.to_s, err.backtrace
  end

  def validate_delete_key_pair
    validate_key_pair
  end
end
