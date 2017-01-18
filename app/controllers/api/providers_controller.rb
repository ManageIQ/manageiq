# rubocop:disable ClassLength
module Api
  class ProvidersController < BaseController
    TYPE_ATTR         = "type".freeze
    ZONE_ATTR         = "zone".freeze
    CREDENTIALS_ATTR  = "credentials".freeze
    AUTH_TYPE_ATTR    = "auth_type".freeze
    DEFAULT_AUTH_TYPE = "default".freeze
    CONNECTION_ATTRS  = %w(connection_configurations).freeze
    ENDPOINT_ATTRS    = %w(hostname url ipaddress port security_protocol certificate_authority).freeze
    RESTRICTED_ATTRS  = [TYPE_ATTR, CREDENTIALS_ATTR, ZONE_ATTR, "zone_id"].freeze

    include Subcollections::Policies
    include Subcollections::PolicyProfiles
    include Subcollections::Tags
    include Subcollections::CloudNetworks
    include Subcollections::CustomAttributes
    include Subcollections::LoadBalancers

    def create_resource(type, _id, data = {})
      assert_id_not_specified(data, type)

      create_provider(data)
    end

    def edit_resource(type, id = nil, data = {})
      raise BadRequestError, "Must specify an id for editing a #{type} resource" unless id
      raise BadRequestError, "Provider type cannot be updated" if data.key?(TYPE_ATTR)

      provider = resource_search(id, type, collection_class(:providers))
      edit_provider(provider, data)
    end

    def refresh_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for refreshing a #{type} resource" unless id

      api_action(type, id) do |klass|
        provider = resource_search(id, type, klass)
        api_log_info("Refreshing #{provider_ident(provider)}")

        refresh_provider(provider)
      end
    end

    def delete_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for deleting a #{type} resource" unless id

      api_action(type, id) do |klass|
        provider = resource_search(id, type, klass)
        api_log_info("Deleting #{provider_ident(provider)}")

        destroy_provider(provider)
      end
    end

    def custom_attributes_edit_resource(object, type, id, data = nil)
      formatted_data = format_provider_custom_attributes(data)
      super(object, type, id, formatted_data)
    end

    def custom_attributes_add_resource(object, type, id, data = nil)
      formatted_data = format_provider_custom_attributes(data)
      super(object, type, id, formatted_data)
    end

    def import_vm_resource(type, id = nil, data = {})
      raise BadRequestError, "Must specify an id for import of VM to a #{type} resource" unless id

      api_action(type, id) do |klass|
        provider = resource_search(id, type, klass)

        vm_id = parse_id(data['source'], :vms)
        # check if user can access the VM
        resource_search(vm_id, :vms, Vm)

        api_log_info("Importing VM to #{provider_ident(provider)}")
        target_params = {
          :name       => data.fetch_path('target', 'name'),
          :cluster_id => parse_id(data.fetch_path('target', 'cluster'), :clusters),
          :storage_id => parse_id(data.fetch_path('target', 'data_store'), :data_stores),
          :sparse     => data.fetch_path('target', 'sparse')
        }
        import_vm_to_provider(provider, vm_id, target_params)
      end
    end

    private

    def format_provider_custom_attributes(attribute)
      if CustomAttribute::ALLOWED_API_VALUE_TYPES.include? attribute["field_type"]
        attribute["value"] = attribute.delete("field_type").safe_constantize.parse(attribute["value"])
      end
      attribute["section"] ||= "metadata" unless @req.action == "edit"
      if attribute["section"].present? && !(CustomAttribute::ALLOWED_API_SECTIONS.include? attribute["section"])
        raise "Invalid attribute section specified: #{attribute["section"]}"
      end
      attribute
    rescue => err
      raise BadRequestError, "Invalid provider custom attributes specified - #{err}"
    end

    def provider_ident(provider)
      "Provider id:#{provider.id} name:'#{provider.name}'"
    end

    def fetch_provider_klass(klass, data)
      supported_types = klass.supported_subclasses.collect(&:name)
      types_string    = supported_types.join(", ")
      unless data.key?(TYPE_ATTR)
        raise BadRequestError, "Must specify a provider type, supported types are: #{types_string}"
      end

      type = data[TYPE_ATTR]
      unless supported_types.include?(type)
        raise BadRequestError, "Invalid provider type #{type} specified, supported types are: #{types_string}"
      end
      klass.supported_subclasses.detect { |p| p.name == data[TYPE_ATTR] }
    end

    def create_provider(data)
      provider_klass = fetch_provider_klass(collection_class(:providers), data)
      create_data    = fetch_provider_data(provider_klass, data, :requires_zone => true)
      provider       = provider_klass.create!(create_data)
      update_provider_authentication(provider, data)
      provider
    rescue => err
      provider.destroy if provider
      raise BadRequestError, "Could not create the new provider - #{err}"
    end

    def edit_provider(provider, data)
      update_data = fetch_provider_data(provider.class, data)
      provider.update_attributes(update_data) if update_data.present?
      update_provider_authentication(provider, data)
      provider
    rescue => err
      raise BadRequestError, "Could not update the provider - #{err}"
    end

    def refresh_provider(provider)
      desc = "#{provider_ident(provider)} refreshing"
      provider.refresh_ems
      action_result(true, desc)
    rescue => err
      action_result(false, err.to_s)
    end

    def destroy_provider(provider)
      desc = "#{provider_ident(provider)} deleting"
      task_id = queue_object_action(provider, desc, :method_name => "destroy")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def import_vm_to_provider(provider, source_vm_id, target_params)
      desc = "#{provider_ident(provider)} importing vm"
      task_id = queue_object_action(provider, desc,
                                    :method_name => 'import_vm',
                                    :args        => [source_vm_id, target_params])
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def update_provider_authentication(provider, data)
      credentials = data[CREDENTIALS_ATTR]
      return if credentials.blank?
      all_credentials = Array.wrap(credentials).each_with_object({}) do |creds, hash|
        auth_type, creds = validate_auth_type(provider, creds)
        validate_credential_attributes(provider, creds)
        hash[auth_type.to_sym] = creds.symbolize_keys!
      end
      provider.update_authentication(all_credentials) if all_credentials.present?
    end

    def validate_auth_type(provider, creds)
      auth_type  = creds.delete(AUTH_TYPE_ATTR) || DEFAULT_AUTH_TYPE
      auth_types = provider.respond_to?(:supported_auth_types) ? provider.supported_auth_types : [DEFAULT_AUTH_TYPE]
      unless auth_types.include?(auth_type)
        raise BadRequestError, "Unsupported authentication type %s specified, %s supports: %s" %
                               [auth_type, provider.class.name, auth_types.join(", ")]
      end
      [auth_type, creds]
    end

    def validate_credential_attributes(provider, creds)
      auth_attrs    = provider.supported_auth_attributes
      invalid_attrs = creds.keys - auth_attrs
      return if invalid_attrs.blank?
      raise BadRequestError, "Unsupported credential attributes %s specified, %s supports: %s" %
                             [invalid_attrs.join(', '), provider.class.name, auth_attrs.join(", ")]
    end

    def fetch_provider_data(provider_klass, data, options = {})
      provider_data = data.except(*RESTRICTED_ATTRS)
      invalid_keys  = provider_data.keys - provider_klass.columns_hash.keys - ENDPOINT_ATTRS - CONNECTION_ATTRS
      raise BadRequestError, "Invalid Provider attributes #{invalid_keys.join(', ')} specified" if invalid_keys.present?

      specify_zone(provider_data, data, options)
      provider_data
    end

    def specify_zone(provider_data, data, options)
      if data[ZONE_ATTR].present?
        provider_data[ZONE_ATTR] = fetch_zone(data)
      elsif options[:requires_zone]
        provider_data[ZONE_ATTR] = Zone.default_zone
      end
    end

    def fetch_zone(data)
      return unless data[ZONE_ATTR].present?

      zone_id = parse_id(data[ZONE_ATTR], :zone)
      raise BadRequestError, "Missing zone href or id" if zone_id.nil?
      resource_search(zone_id, :zone, Zone) # Only support Rbac allowed zone
    end
  end
end
