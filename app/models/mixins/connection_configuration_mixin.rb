module ConnectionConfigurationMixin
  extend ActiveSupport::Concern

  # Takes multiple connection data
  # endpoints, and authentications
  def connection_configurations=(options)
    options.each do |option|
      add_connection_configuration_by_role(option)
    end

    delete_unused_connection_configurations(options)
  end

  def delete_unused_connection_configurations(options)
    chosen_endpoints = options.map { |x| x.deep_symbolize_keys.fetch_path(:endpoint, :role).try(:to_sym) }.compact.uniq
    existing_endpoints = endpoints.pluck(:role).map(&:to_sym)
    # Delete endpoint that were not picked
    roles_for_deletion = existing_endpoints - chosen_endpoints
    endpoints.select { |x| x.role && roles_for_deletion.include?(x.role.to_sym) }.each(&:mark_for_destruction)
    authentications.select { |x| x.authtype && roles_for_deletion.include?(x.authtype.to_sym) }.each(&:mark_for_destruction)
  end

  def connection_configurations
    roles = endpoints.map(&:role)
    options = {}

    roles.each do |role|
      conn = connection_configuration_by_role(role)
      options[role] = conn
    end

    connections = OpenStruct.new(options)
    connections.roles = roles
    connections
  end

  # Takes a hash of connection data
  # hostname, port, and authentication
  # if no role is passed in assume is default role
  def add_connection_configuration_by_role(connection)
    connection.deep_symbolize_keys!
    unless connection[:endpoint].key?(:role)
      connection[:endpoint][:role] ||= "default"
    end
    if connection[:authentication].blank?
      connection.delete(:authentication)
    else
      unless connection[:authentication].key?(:role)
        endpoint_role = connection[:endpoint][:role]
        authentication_role = endpoint_role == "default" ? default_authentication_type.to_s : endpoint_role
        connection[:authentication][:role] ||= authentication_role
      end
    end

    build_connection(connection)
  end

  def connection_configuration_by_role(role = "default")
    endpoint = endpoints.detect { |e| e.role == role }

    if endpoint
      authtype = endpoint.role == "default" ? default_authentication_type.to_s : endpoint.role
      auth = authentications.detect { |a| a.authtype == authtype }

      options = {:endpoint => endpoint, :authentication => auth}
      OpenStruct.new(options)
    end
  end

  private

  def build_connection(options = {})
    build_endpoint_by_role(options[:endpoint])
    build_authentication_by_role(options[:authentication])
  end

  def build_endpoint_by_role(options)
    return if options.blank?
    endpoint = endpoints.detect { |e| e.role == options[:role].to_s }
    if endpoint
      endpoint.assign_attributes(options)
    else
      endpoints.build(options)
    end
  end

  def build_authentication_by_role(options)
    return if options.blank?
    role = options.delete(:role)
    creds = {}
    creds[role] = options
    update_authentication(creds,options)
  end
end
