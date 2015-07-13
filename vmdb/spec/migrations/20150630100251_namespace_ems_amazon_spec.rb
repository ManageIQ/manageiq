require "spec_helper"
require Rails.root.join("db/migrate/20150630100251_namespace_ems_amazon")

describe NamespaceEmsAmazon do
  class NamespaceEmsAmazon::ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "EmsAmazon")

      migrate

      expect(ems.reload).to have_attributes(:type => "ManageIQ::Providers::Amazon::CloudManager")
    end
  end

  migration_context :down do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ManageIQ::Providers::Amazon::CloudManager")

      migrate

      expect(ems.reload).to have_attributes(:type => "EmsAmazon")
    end
  end
end
