class ApiController
  module Hosts
    CREDENTIALS_ATTR = "credentials"
    AUTH_TYPE_ATTR = "type"
    DEFAULT_AUTH_TYPE = "default"

    def edit_resource_hosts(type, id, data = {})
      host = resource_search(id, type, collection_class(:hosts))
      credentials = data[CREDENTIALS_ATTR]
      all_credentials = Array.wrap(credentials).each_with_object({}) do |creds, hash|
        auth_type = creds.delete(AUTH_TYPE_ATTR) || DEFAULT_AUTH_TYPE
        creds.reverse_merge!(:userid => host.authentication_userid(auth_type))
        hash[auth_type.to_sym] = creds.symbolize_keys!
      end
      host.update_authentication(all_credentials) if all_credentials.present?
      host
    end
  end
end
