require "spec_helper"

describe "UiCoverageHelper" do
  EXCLUDE_GLOBS = [
    'app/controllers/application.rb',
    'app/controllers/application_controller.rb'
  ]
  it "should require the world" do
    excludes = Dir.glob(EXCLUDE_GLOBS)
    [].each do |path|
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

    ['app/controllers'].each do |path|
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
