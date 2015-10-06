class ApiController
  module Roles
    include FeatureHelper
    def create_resource_roles(type, _id = nil, data = {})
      if data.key?("id") || data.key?("href")
        raise BadRequestError, "Resource id or href should not be specified for creating a new #{type}"
      end

      # Can't create a read-only role (reserved for out-of-box roles)
      if data ['read_only']
        raise BadRequestError, "Cannot create a read-only role."
      end

      role_klass = collection_class(type)

      get_settings_and_features(data)

      role = role_klass.create!(data.except(*ID_ATTRS))
      api_log_info("Created new role #{role.name}")
      role
    rescue => err
      role.destroy if role
      raise err
    end

    def edit_resource_roles(type, id = nil, data = {})
      unless id
        raise BadRequestError, "Must specify an id for editing a #{type} resource"
      end

      # Can't set an existing role to read-only (reserved for out-of-box roles)
      if data['read_only']
        raise BadRequestError, "Cannot set a non-system role to read-only."
      end

      role = resource_search(id, type, collection_class(:roles))

      # Can't edit a read-only role
      if role.read_only
        raise BadRequestError, "Cannot edit a role that is read-only."
      end

      get_settings_and_features(data)

      role.update_attributes!(data.except(*ID_ATTRS))
      api_log_info("Modified role #{role.name}")
      role
    end

    private

    def get_settings_and_features(data)
      if data['settings']
        data['settings'][:restrictions] = get_role_settings(data)
        data.delete('settings') if data['settings'].empty?
      end

      # Build miq_product_features hash from passed in features, remove features
      if data['features']
        data['miq_product_features'] = get_product_features(data['features'])
        data.delete('features')
      end
    end

    def get_role_settings(data)
      restrictions = {:vms => data['settings']['restrictions']['vms'].to_sym}
      data['settings'].delete('restrictions')
      restrictions
    end
  end
end
