module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScriptSource
  extend ActiveSupport::Concern

  include ProviderObjectMixin

  module ClassMethods
    def provider_params(params)
      authentication_id = params.delete(:authentication_id)
      params[:credential] = Authentication.find(authentication_id).manager_ref if authentication_id
      params
    end

    def provider_collection(manager)
      manager.with_provider_connection do |connection|
        connection.api.projects
      end
    end
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.projects.find(manager_ref)
  end

  REFRESH_ON_TOWER_SLEEP = 1.second
  def refresh_in_provider
    with_provider_object do |project|
      return unless project.can_update?

      project_update = project.update

      # this is really just a quick hack. We should do this properly once
      # https://github.com/ManageIQ/manageiq/pull/14405 is merged
      log_header = "updating project #{project.id} (#{self.class.name} #{id})"
      _log.info "#{log_header}..."
      Timeout.timeout(5.minutes) do
        while project_update.finished.blank?
          sleep REFRESH_ON_TOWER_SLEEP
          project_update = project_update.api.project_updates.find(project_update.id)
        end
      end
      _log.info "#{log_header}...Complete"
    end
  end
end
