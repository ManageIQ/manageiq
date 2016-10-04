require 'active_support/core_ext/kernel/reporting'

# Require all ruby files for accuracte test coverage reports
EXCLUSIONS_LIST = %w(/bin/ /ext/ /spec/ /test/ /vendor/ appliance_console.rb bundler_setup.rb test.rb require_with_logging.rb VixDiskLibServer.rb VMwareWebService/wsdl41 )
Dir.glob(File.join(GEMS_PENDING_ROOT, "**", "*.rb")).each do |file|
  next if EXCLUSIONS_LIST.any? { |exclusion| file.include?(exclusion) }
  begin
    silence_warnings { require file }
  rescue LoadError, MissingSourceFile
  end
end
