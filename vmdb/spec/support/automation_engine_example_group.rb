module AutomationEngineExampleGroup
  extend ActiveSupport::Concern

  included do
    metadata[:type] = :automation_engine

    ENV['AUTOMATE_DB_DIRECTORY'] = Dir.mktmpdir
    before(:each) do
      require 'miq_ae_datastore'
      stub_const("MiqAeDatastore::DATASTORE_DIRECTORY", ENV['AUTOMATE_DB_DIRECTORY'])
      FileUtils.remove_entry_secure(ENV['AUTOMATE_DB_DIRECTORY']) if Dir.exist?(ENV['AUTOMATE_DB_DIRECTORY'])
      FileUtils.mkdir(ENV['AUTOMATE_DB_DIRECTORY'])
    end

    after(:each) do
      FileUtils.remove_entry_secure(ENV['AUTOMATE_DB_DIRECTORY']) if Dir.exist?(ENV['AUTOMATE_DB_DIRECTORY'])
    end
  end
end
