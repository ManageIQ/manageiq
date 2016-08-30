module Api
  class BaseController
    module Hosts
      CREDENTIALS_ATTR = "credentials"
      AUTH_TYPE_ATTR = "auth_type"
      DEFAULT_AUTH_TYPE = "default"

      def edit_resource_hosts(type, id, data = {})
        credentials = data.delete(CREDENTIALS_ATTR)
        raise BadRequestError, "Cannot update non-credentials attributes of host resource" if data.any?
        resource_search(id, type, collection_class(:hosts)).tap do |host|
          all_credentials = Array.wrap(credentials).each_with_object({}) do |creds, hash|
            auth_type = creds.delete(AUTH_TYPE_ATTR) || DEFAULT_AUTH_TYPE
            creds.reverse_merge!(:userid => host.authentication_userid(auth_type))
            hash[auth_type.to_sym] = creds.symbolize_keys!
          end
          host.update_authentication(all_credentials) if all_credentials.present?
        end
      end
    end
  end
end
