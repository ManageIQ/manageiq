require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class CoverageHelper < ActiveSupport::TestCase
  EXCLUDE_GLOBS = [
    'lib/extensions/**/*.rb',
    'lib/db_administration/**/*.rb',
    'lib/miq_automation_engine/**/*.rb',
    'lib/rubyrep_filters/**/*.rb',
    'lib/tasks/**/*.rb',
    'app/models/mixins/acts_as_ar_model_mixin.rb',
    'app/models/state.rb'
  ]
  def test_coverage
    excludes = Dir.glob(EXCLUDE_GLOBS)
    ['lib', 'app/jobs'].each do |path|
      Dir.glob("#{path}/**/*.rb") do |file|
        if excludes.include?(file)
          puts "Skipping direct require of #{file} due to exclusion"
          next
        end
        begin
          require File.basename(file, ".rb")
        rescue StandardError, LoadError, MissingSourceFile
          puts $!.message + " in " + file
        end
      end
    end

    ['app/models'].each do |path|
      Dir.glob("#{path}/**/*.rb") do |file|
        if excludes.include?(file)
          puts "Skipping ConstMissing require #{file} due to exclusion"
          next
        end
        begin
          File.basename(file, ".rb").camelize.constantize
        rescue StandardError, LoadError, MissingSourceFile
          puts "Failed to load #{file}"
        end
      end
    end
  end
end
