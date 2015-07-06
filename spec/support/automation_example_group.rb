module AutomationExampleGroup
  extend ActiveSupport::Concern

  class << self
    attr_accessor :fixtures_loaded
  end

  included do
    metadata[:type] = :automation

    unless AutomationExampleGroup.fixtures_loaded
      RSpec.configure do |config|
        config.before(:suite) do
          puts "** Resetting ManageIQ domain"
          MiqAeDatastore.reset
          MiqAeDatastore.reset_manageiq_domain
        end

        config.after(:suite) do
          MiqAeDatastore.reset
        end
      end

      AutomationExampleGroup.fixtures_loaded = true
    end
  end
end
