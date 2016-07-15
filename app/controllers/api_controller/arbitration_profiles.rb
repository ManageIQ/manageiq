class ApiController
  module ArbitrationProfiles
    def create_resource_arbitration_profiles(_type, _id, data)
      validate_profile_data(data)
      parse_set_provider(data)
      parse_set_availability_zone(data)
      arbitration_profile = collection_class(:arbitration_profiles).create(data)
      if arbitration_profile.invalid?
        raise BadRequestError, "Failed to add new arbitration profile -
            #{arbitration_profile.errors.full_messages.join(', ')}"
      end
      arbitration_profile
    end

    def edit_resource_arbitration_profiles(type, id, data)
      validate_profile_data(data)
      parse_set_provider(data)
      parse_set_availability_zone(data)
      edit_resource(type, id, data)
    end

    private

    def parse_set_provider(data)
      provider = parse_fetch_provider(data.delete('provider')) ||
                 parse_fetch_provider(data.delete('ext_management_system'))
      data.merge!('ext_management_system' => provider) if provider
    end

    def parse_set_availability_zone(data)
      availability_zone = parse_fetch_availability_zone(data.delete('availability_zone'))
      data.merge!('availability_zone' => availability_zone) if availability_zone
    end

    def validate_profile_data(data)
      if data.key?('id') || data.key?('href')
        raise BadRequestError, 'Resource id or href should not be specified when creating a new arbitration profile'
      elsif data.key?('provider') && data.key?('ext_management_system')
        raise BadRequestError, 'Only one of provider or ext_management_system may be specified'
      end
    end
  end
end
