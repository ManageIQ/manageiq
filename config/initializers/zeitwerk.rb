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
