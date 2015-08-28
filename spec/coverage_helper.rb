require "spec_helper"

if ENV['CI']
  require 'active_support/core_ext/kernel/reporting'

  # Require all ruby files for accuracte test coverage reports
  %w(app gems lib spa_ui).each do |path|
    Dir.glob(Rails.root.join(path, "**", "*.rb")) do |file|
      next if file.include?("/bin/") || file.include?("/spec/") || file.include?("/test/") || file.include?("test.rb") || file.include?("require_with_logging.rb")
      begin
        silence_warnings { require file }
      rescue StandardError, LoadError, MissingSourceFile
      end
    end
  end
end
