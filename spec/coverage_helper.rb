require 'active_support/core_ext/kernel/reporting'

module CoverageHelper
  # Require all ruby files for accuracte test coverage reports
  def self.require_files_from(*directories)
    directories.each do |path|
      Dir.glob(Rails.root.join(path, "**", "*.rb")) do |file|
        next if file.include?("/bin/") || file.include?("/spec/")
        begin
          puts "requiring: #{file}"
          silence_warnings { require file }
        rescue StandardError, LoadError, MissingSourceFile
        end
      end
    end
  end
end

case ENV["TEST_SUITE"]
when "migrations" then CoverageHelper.require_files_from("db/migrate")
when "vmdb"       then CoverageHelper.require_files_from("app", "lib")
end
