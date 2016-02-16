require "spec_helper"

module MiqAeServiceConfigurationScriptSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceConfigurationScript do
    it "get the service model class" do
      expect { described_class }.not_to raise_error
    end
  end
end
