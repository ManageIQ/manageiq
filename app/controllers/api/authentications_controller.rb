module Api
  class AuthenticationsController < BaseController
    def delete_resource(type, id, _data = {})
      auth = resource_search(id, type, collection_class(:authentications))
      raise "Delete not supported for #{authentication_ident(auth)}" unless auth.respond_to?(:delete_in_provider_queue)
      task_id = auth.delete_in_provider_queue
      action_result(true, "Deleting #{authentication_ident(auth)}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def options
      render_options(:authentications, :credential_types => build_additional_fields)
    end

    private

    def authentication_ident(auth)
      "Authentication id:#{auth.id} name: '#{auth.name}'"
    end

    def build_additional_fields
      {
        :ansible_tower_credentials    => build_ansible_tower_creds,
        :embedded_ansible_credentials => build_embedded_ansible_creds
      }
    end

    def build_ansible_tower_creds
      ManageIQ::Providers::AnsibleTower::AutomationManager::Credential.descendants.each_with_object({}) do |klass, fields|
        fields[klass.name] = klass::API_OPTIONS if defined? klass::API_OPTIONS
      end
    end

    def build_embedded_ansible_creds
      ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential.descendants.each_with_object({}) do |klass, fields|
        fields[klass.name] = klass::API_OPTIONS if defined? klass::API_OPTIONS
      end
    end
  end
end
