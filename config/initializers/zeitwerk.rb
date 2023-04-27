if Rails.application.config.autoloader == :zeitwerk && Rails.autoloaders.main
  # These specific directories are for code organization, not namespacing:
  Rails.autoloaders.main.collapse(Rails.root.join("lib/manageiq/reporting/charting"))
  Rails.autoloaders.main.collapse(Rails.root.join("lib/ansible/runner/credential"))
end
