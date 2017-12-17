module CockpitMixin
  extend ActiveSupport::Concern
  def cockpit_server
    ext_management_system.try(:zone).try(:remote_cockpit_ws_miq_server)
  end

  def cockpit_worker
    cockpit_server && MiqCockpitWsWorker.fetch_worker_settings_from_server(cockpit_server)
  end
end
