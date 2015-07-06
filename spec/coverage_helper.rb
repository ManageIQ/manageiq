require "spec_helper"

module Kernel
  def suppress_warnings
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    result = yield
    $VERBOSE = original_verbosity
    return result
  end
end

describe "CoverageHelper" do
  EXCLUDE_GLOBS = [
    'lib/workers/bin/*',
    'bin/*',
    'lib/workers/evm_server.rb'
  ]
  it "should require the world" do
    excludes = Dir.glob(EXCLUDE_GLOBS)
    ['lib', 'app', ].each do |path|
      Dir.glob("#{path}/**/*.rb") do |file|
        if excludes.include?(file)
          #puts "Skipping direct require of #{file} due to exclusion"
          next
        end
        begin
          suppress_warnings { require File.basename(file, ".rb") }
        rescue StandardError, LoadError, MissingSourceFile
        end
      end
    end
  end
end
