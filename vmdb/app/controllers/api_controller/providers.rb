class ApiController
  module Providers
    CREDENTIAL_ATTRS = %w(userid password)
    RESTRICTED_ATTRS  = %w(type zone) + CREDENTIAL_ATTRS

    def create_resource_providers(type, _id, data = {})
      if data.key?("id") || data.key?("href")
        raise BadRequestError,
              "Resource id or href should not be specified for creating a new #{type}"
      end

      create_provider(data)
    end

    def edit_resource_providers(type, id = nil, data = {})
      raise BadRequestError, "Must specify an id for editing a #{type} resource" unless id
      raise BadRequestError, "Provider type cannot be updated" if data.key?("type")

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
      supported_types = klass.supported_types.join(", ")

      unless data.key?("type")
        raise BadRequestError, "Must specify a provider type, supported types are: #{supported_types}"
      end
      type = data["type"]
      unless klass.supported_types.include?(type)
        raise BadRequestError, "Invalid provider type #{type} specified, supported types are: #{supported_types}"
      end
      klass.supported_subclasses.detect { |p| p.ems_type == data["type"] }
    end

    def create_provider(data)
      klass = collection_config[:providers][:klass].constantize
      provider_data = data.except(*RESTRICTED_ATTRS).merge(:zone => Zone.default_zone)
      provider = fetch_provider_klass(klass, data).create!(provider_data)
      update_provider_authentication(provider, data)
      provider
    rescue => err
      provider.destroy if provider
      raise BadRequestError, "Could not create the new provider - #{err}"
    end

    def edit_provider(provider, data)
      update_data = data.except(*RESTRICTED_ATTRS)
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
      credentials = data.slice(*CREDENTIAL_ATTRS)
      provider.update_authentication(:default => credentials.symbolize_keys!) if credentials.present?
    end
  end
end
