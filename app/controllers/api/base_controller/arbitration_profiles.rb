module Api
  class BaseController
    module ArbitrationProfiles
      def create_resource_arbitration_profiles(_type, _id, data)
        validate_profile_data(data)
        attributes = build_arbitration_attributes(data)
        arbitration_profile = collection_class(:arbitration_profiles).create(attributes)
        validate_profile(arbitration_profile)
        arbitration_profile
      end

      def edit_resource_arbitration_profiles(type, id, data)
        validate_profile_data(data)
        attributes = build_arbitration_attributes(data)
        edit_resource(type, id, attributes)
      end

      private

      def build_arbitration_attributes(data)
        attributes = data.dup
        attributes['ext_management_system'] = fetch_provider(provider_from_data(data)) if provider_from_data(data)
        attributes['availability_zone'] = fetch_availability_zone(data['availability_zone']) if data['availability_zone']
        attributes.delete('provider')
        attributes
      end

      def provider_from_data(data)
        @provider_ref ||= data['provider'] || data['ext_management_system']
      end

      def validate_profile_data(data)
        assert_id_not_specified(data, 'arbitration profile')
        if data.key?('provider') && data.key?('ext_management_system')
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
end
