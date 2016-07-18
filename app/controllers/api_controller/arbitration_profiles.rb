class ApiController
  module ArbitrationProfiles
    def create_resource_arbitration_profiles(_type, _id, data)
      validate_profile_data(data)
      attributes = data.dup
      attributes['ext_management_system'] = fetch_provider(provider_from_data(data)) if provider_from_data(data)
      attributes['availability_zone'] = fetch_availability_zone(data['availability_zone']) if data['availability_zone']
      attributes.delete('provider')
      arbitration_profile = collection_class(:arbitration_profiles).create(attributes)
      validate_profile(arbitration_profile)
      arbitration_profile
    end

    def edit_resource_arbitration_profiles(type, id, data)
      validate_profile_data(data)
      attributes = data.dup
      attributes['ext_management_system'] = fetch_provider(provider_from_data(data)) if provider_from_data(data)
      attributes['availability_zone'] = fetch_availability_zone(data['availability_zone']) if data['availability_zone']
      attributes.delete('provider')
      edit_resource(type, id, attributes)
    end

    private

    def provider_from_data(data)
      @provider_ref ||= data['provider'] || data['ext_management_system']
    end

    def validate_profile_data(data)
      if data.key?('id') || data.key?('href')
        raise BadRequestError, 'Resource id or href should not be specified when creating a new arbitration profile'
      elsif data.key?('provider') && data.key?('ext_management_system')
        raise BadRequestError, 'Only one of provider or ext_management_system may be specified'
      end
    end
  end

  def validate_profile(profile)
    if profile.invalid?
      raise BadRequestError, "Failed to add new arbitration profile -
            #{profile.errors.full_messages.join(', ')}"
    end
  end
end
