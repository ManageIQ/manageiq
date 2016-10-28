require 'active_support/core_ext/kernel/reporting'

# Require all ruby files for accuracte test coverage reports
%w(app lib).each do |path|
  Dir.glob(Rails.root.join(path, "**", "*.rb")) do |file|
    next if file.include?("/bin/") || file.include?("/spec/") || file.include?("/lib/generators/provider/templates/")
    begin
      silence_warnings { require file }
    rescue StandardError, LoadError, MissingSourceFile
    end
  end
end
