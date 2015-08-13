require "spec_helper"
require Rails.root.join("db/migrate/20150724030353_namespace_ems_foreman")

describe NamespaceEmsForeman do
  class NamespaceEmsForeman::ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ConfigurationManagerForeman")

      migrate

      expect(ems.reload).to have_attributes(:type => "ManageIQ::Providers::Foreman::ConfigurationManager")
    end
  end

  migration_context :down do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ManageIQ::Providers::Foreman::ConfigurationManager")

      migrate

      expect(ems.reload).to have_attributes(:type => "ConfigurationManagerForeman")
    end
  end
end
