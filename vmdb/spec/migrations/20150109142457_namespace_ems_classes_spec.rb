require "spec_helper"
require Rails.root.join("db/migrate/20150109142457_namespace_ems_classes")

describe NamespaceEmsClasses do
  class NamespaceEmsClasses::ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "EmsInfra")

      migrate

      expect(ems.reload).to have_attributes(:type => "ManageIQ::Providers::InfraManager")
    end
  end

  migration_context :down do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ManageIQ::Providers::InfraManager")

      migrate

      expect(ems.reload).to have_attributes(:type => "EmsInfra")
    end
  end
end
