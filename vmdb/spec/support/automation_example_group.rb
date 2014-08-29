module RSpec::Rails
  module AutomationExampleGroup
    extend ActiveSupport::Concern

    included do
      metadata[:type] = :automation

      before(:all) do
        MiqAeDatastore.reset
        MiqAeDatastore.reset_to_defaults
      end

      after(:all) do
        MiqAeDatastore.reset
      end
    end
  end
end
