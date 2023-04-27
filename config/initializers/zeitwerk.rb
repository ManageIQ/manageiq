if Rails.application.config.autoloader == :zeitwerk && Rails.autoloaders.main
  # These specific directories are for code organization, not namespacing:
  Rails.autoloaders.main.collapse(Rails.root.join("lib/manageiq/reporting/charting"))
  Rails.autoloaders.main.collapse(Rails.root.join("lib/ansible/runner/credential"))

  # requires qpid, which is an optional dependency because LOL mac
  if RUBY_PLATFORM.include?("darwin")
    message_handler_path = Pathname.new(Vmdb::Plugins.paths[ManageIQ::Providers::Nuage::Engine]).join("app/models/manageiq/providers/nuage/network_manager/event_catcher/messaging_handler.rb")
    Rails.autoloaders.main.ignore(message_handler_path)
  end
end
