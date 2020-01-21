module ConfigurationManagementMixin
  extend ActiveSupport::Concern

  included do
    has_many :settings_changes, :as => :resource, :dependent => :destroy
  end

  def settings_for_resource
    Vmdb::Settings.for_resource(self)
  end

  def settings_for_resource_yaml
    Vmdb::Settings.for_resource_yaml(self)
  end

  def add_settings_for_resource(settings)
    Vmdb::Settings.save!(self, settings)
    immediately_reload_settings
  end

  def add_settings_for_resource_yaml(contents)
    Vmdb::Settings.save_yaml!(self, contents)
    immediately_reload_settings
  end

  def remove_settings_path_for_resource(*keys)
    Vmdb::Settings.destroy!(self, keys)
    immediately_reload_settings
  end

  def reload_all_server_settings
    servers_for_settings_reload.each do |server|
      server.enqueue_for_server("reload_settings") if server.started?
    end
  end

  private def immediately_reload_settings
    # Reload the settings immediately for this worker. This is typically a UI
    # worker making the change, who will need to see the changes right away.
    Vmdb::Settings.reload!

    # Reload the settings for all workers on the servers whether local or remote.
    reload_all_server_settings
  end
end
