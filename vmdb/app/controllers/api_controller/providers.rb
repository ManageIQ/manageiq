class ApiController
  module Providers
    TYPE_ATTR         = "type"
    ZONE_ATTR         = "zone"
    CREDENTIALS_ATTR  = "credentials"
    AUTH_TYPE_ATTR    = "auth_type"
    DEFAULT_AUTH_TYPE = "default"
    RESTRICTED_ATTRS  = [TYPE_ATTR, CREDENTIALS_ATTR, ZONE_ATTR, "zone_id"]

    def create_resource_providers(type, _id, data = {})
      if data.key?("id") || data.key?("href")
        raise BadRequestError,
              "Resource id or href should not be specified for creating a new #{type}"
      end

      create_provider(data)
    end

    def edit_resource_providers(type, id = nil, data = {})
      raise BadRequestError, "Must specify an id for editing a #{type} resource" unless id
      raise BadRequestError, "Provider type cannot be updated" if data.key?(TYPE_ATTR)

      klass = collection_config[:providers][:klass].constantize
      provider = resource_search(id, type, klass)
      edit_provider(provider, data)
    end

    def refresh_resource_providers(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for refreshing a #{type} resource" unless id

      api_action(type, id) do |klass|
        provider = resource_search(id, type, klass)
        api_log_info("Refreshing #{provider_ident(provider)}")

        refresh_provider(provider)
      end
    end

    def delete_resource_providers(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for deleting a #{type} resource" unless id

      api_action(type, id) do |klass|
        provider = resource_search(id, type, klass)
        api_log_info("Deleting #{provider_ident(provider)}")

        destroy_provider(provider)
      end
    end

    private

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
      klass = collection_config[:providers][:klass].constantize
      provider_klass = fetch_provider_klass(klass, data)
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
        raise BadRequestError, format("Unsupported authentication type %s specified, %s supports: %s",
                                      auth_type, provider.class.name, auth_types.join(", "))
      end
      [auth_type, creds]
    end

    def validate_credential_attributes(provider, creds)
      auth_attrs    = provider.supported_auth_attributes
      invalid_attrs = creds.keys - auth_attrs
      return if invalid_attrs.blank?
      raise BadRequestError, format("Unsupported credential attributes %s specified, %s supports: %s",
                                    invalid_attrs.join(', '), provider.class.name, auth_attrs.join(", "))
    end

    def fetch_provider_data(provider_klass, data, options = {})
      provider_data = data.except(*RESTRICTED_ATTRS)
      invalid_keys  = provider_data.keys - provider_klass.columns_hash.keys
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
      resource_search(zone_id, :zone, Zone)   # Only support Rbac allowed zone
    end
  end
end
