if Rails.application.config.autoloader == :zeitwerk && Rails.autoloaders.main
  if ENV['DEBUG_MANAGEIQ_ZEITWERK'].present?
    Zeitwerk::Loader.default_logger = method(:puts)
    Rails.autoloaders.main.logger = Logger.new($stdout)
  end

  # These specific directories are for code organization, not namespacing:
  # TODO: these should be either renamed with good names, the intermediate directory removed
  # and/or both.
  Rails.autoloaders.main.collapse(Rails.root.join("lib/manageiq/reporting/charting"))
  Rails.autoloaders.main.collapse(Rails.root.join("lib/ansible/runner/credential"))
  Rails.autoloaders.main.collapse(Rails.root.join("lib/pdf_generator"))

  # The following file should not be eager loaded as it depends on being installed, which isn't possible on macs and isn't done by default
  # in ci for other plugins, core, etc.
  message_handler_path = Pathname.new(Vmdb::Plugins.paths[ManageIQ::Providers::Nuage::Engine]).join("app/models/manageiq/providers/nuage/network_manager/event_catcher/messaging_handler.rb")
  Rails.autoloaders.main.ignore(message_handler_path)
end
