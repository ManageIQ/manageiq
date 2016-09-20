module ConfigurationManagementMixin
  extend ActiveSupport::Concern

  included do
    has_many :settings_changes, :as => :resource, :dependent => :destroy
  end

  def settings_for_resource
    Vmdb::Settings.for_resource(self)
  end

  def add_settings_for_resource(settings)
    Vmdb::Settings.save!(self, settings)
    # Reload the settings immediately for this worker. This is typically a UI
    # worker making the change, who will need to see the changes right away.
    Vmdb::Settings.reload!

    # Reload the settings for all workers on the servers whether local or remote.
    reload_all_server_settings
  end

  def reload_all_server_settings
    servers_for_settings_reload.each do |server|
      server.enqueue_for_server("reload_settings") if server.started?
    end
  end
end
