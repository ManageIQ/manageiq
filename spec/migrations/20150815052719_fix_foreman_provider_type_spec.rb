require "spec_helper"
require Rails.root.join("db/migrate/20150815052719_fix_foreman_provider_type")

describe FixForemanProviderType do
  class FixForemanProviderType::Provider < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  let(:ems_stub) { migration_stub(:Provider) }

  migration_context :up do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ProviderForeman")

      migrate

      expect(ems.reload).to have_attributes(:type => "ManageIQ::Providers::Foreman::Provider")
    end
  end

  migration_context :down do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ManageIQ::Providers::Foreman::Provider")

      migrate

      expect(ems.reload).to have_attributes(:type => "ProviderForeman")
    end
  end
end
