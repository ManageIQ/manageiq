module RSpec::Rails
  module AutomationExampleGroup
    extend ActiveSupport::Concern

    included do
      metadata[:type] = :automation

      let(:automation_filename) { Rails.root.join('db', 'fixtures', 'automation_base.xml') }

      before(:all) do
        MiqAeDatastore.reset
        MiqAeDatastore.import(automation_filename)
      end

      after(:all) do
        MiqAeDatastore.reset
      end
    end
  end
end