class ApiController
  module GitRepositories
    CREDENTIALS_ATTR = 'credentials'.freeze
    VERIFY_SSL_ATTR = 'verify_ssl'.freeze
    SUPPORTED_CRED_ATTRS = %w(userid password).freeze

    def create_resource_git_repositories(_type, _id, data = {})
      klass = collection_class(@req.collection)
      git_repository_data = data.except(CREDENTIALS_ATTR)
      git_repository_data.merge!(data[CREDENTIALS_ATTR].slice(VERIFY_SSL_ATTR)) if data[CREDENTIALS_ATTR]
      invalid_keys = git_repository_data.keys - klass.columns_hash.keys
      raise BadRequestError, "Invalid attributes #{invalid_keys.join(', ')} specified" if invalid_keys.present?
      git_repository = klass.create!(git_repository_data)
      update_git_repository_authentication(git_repository, data)
      git_repository
    rescue
      git_repository.destroy if git_repository
      raise
    end

    def refresh_resource_git_repositories(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id of #{type} resource for refresh" unless id

      api_action(type, id) do |klass|
        git = resource_search(id, type, klass)
        desc = "Refreshing Git: #{git.url}"
        task_id = queue_object_action(git, desc, :method_name => 'refresh')
        action_result(true, desc, :task_id => task_id)
      end
    end

    def delete_resource_git_repositories(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for deleting a #{type} resource" unless id

      api_action(type, id) do |klass|
        git = resource_search(id, type, klass)
        desc = "Destroying Git: #{git.url}"
        task_id = queue_object_action(git, desc, :method_name => "destroy")
        action_result(true, desc, :task_id => task_id)
      end
    end

    private

    def update_git_repository_authentication(git_repository, data)
      credentials = data[CREDENTIALS_ATTR]
      return if credentials.blank? || credentials.except!(VERIFY_SSL_ATTR).blank?
      invalid_keys = credentials.keys - SUPPORTED_CRED_ATTRS
      raise BadRequestError, "Invalid attributes #{invalid_keys.join(', ')} specified" if invalid_keys.present?
      git_repository.update_authentication(:password => credentials.symbolize_keys)
    end
  end
end
