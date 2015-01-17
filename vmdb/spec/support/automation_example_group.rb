module AutomationExampleGroup
  extend ActiveSupport::Concern

  included do
    metadata[:type] = :automation

    before(:all) do
      MiqAeDatastore.reset
      MiqAeDatastore.reset_manageiq_domain
    end

    after(:all) do
      MiqAeDatastore.reset
    end
  end
end
