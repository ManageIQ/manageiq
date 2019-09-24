require 'pathname'
require 'active_support/core_ext/object/blank'
require 'active_support/string_inquirer'

module ManageIQ
  # Defined in the same fashion as Rails.env
  def self.env
    @_env ||= begin
      if defined?(Rails)
        Rails.env
      else
        ActiveSupport::StringInquirer.new(ENV["RAILS_ENV"].presence || ENV["RACK_ENV"].presence || "development")
      end
    end
  end

  def self.root
    @_root ||= begin
      if defined?(Rails)
        Rails.root
      else
        Pathname.new(File.expand_path("../..", __FILE__))
      end
    end
  end
end
