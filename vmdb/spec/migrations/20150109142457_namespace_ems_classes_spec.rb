require "spec_helper"
require Rails.root.join("db/migrate/20150109142457_namespace_ems_classes")

describe NamespaceEmsClasses do
  let(:ems_stub) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'ext_management_systems'
      self.inheritance_column = :_type_disabled # disable STI
    end
  end

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
