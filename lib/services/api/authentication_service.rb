module Api
  class AuthenticationService
    def self.create_authentication(manager_resource, attrs)
      klass = ::Authentication.class_from_request_data(attrs)
      # TODO: Temporary validation - remove
      raise 'type not currently supported' unless klass.respond_to?(:create_in_provider_queue)
      klass.create_in_provider_queue(manager_resource, attrs)
    end
  end
end
