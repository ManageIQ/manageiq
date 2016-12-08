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
          Tenant.seed
          MiqAeDatastore.reset
          MiqAeDatastore.reset_to_defaults
        end

        config.after(:suite) do
          MiqAeDatastore.reset
        end

        # rspec-rails 3 will no longer automatically infer an example group's spec type
        # from the file location. You can explicitly opt-in to the feature using this
        # config option.
        # To explicitly tag specs without using automatic inference, set the `:type`
        # metadata manually:
        #
        #     describe ThingsController, :type => :controller do
        #       # Equivalent to being in spec/controllers
        #     end
        config.infer_spec_type_from_file_location!
      end

      AutomationExampleGroup.fixtures_loaded = true
    end
  end
end
