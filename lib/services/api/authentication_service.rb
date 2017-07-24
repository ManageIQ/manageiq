module Api
  class AuthenticationService
    def self.create_authentication_task(manager_resource, attrs)
      klass = ::Authentication.descendant_get(attrs['type'])
      # TODO: Temporary validation - remove
      raise 'type not currently supported' unless klass.respond_to?(:create_in_provider_queue)
      klass.create_in_provider_queue(manager_resource.id, attrs.deep_symbolize_keys)
    end
  end
end
