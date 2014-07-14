require 'rubygems'
require 'trollop'

module Build
  class Cli
    attr_reader :options
    ALLOWED_TYPES = %w(nightly test)

    def parse
      git_ref_desc = "provide a git reference such as a branch or tag"
      type_desc    = "build type: nightly, test, a named yum repository"

      @options = Trollop.options do
        banner "Usage: build.rb [options]"

        opt :type,      type_desc,    :type => :string, :short => "t"
        opt :reference, git_ref_desc, :type => :string, :short => "r"
      end

      options[:type] &&= options[:type].strip

      Trollop.die(:reference, git_ref_desc) if options[:reference].to_s.empty?
      options[:reference] = options[:reference].to_s.strip
      self
    end

    def self.parse
      new.parse
    end
  end
end
