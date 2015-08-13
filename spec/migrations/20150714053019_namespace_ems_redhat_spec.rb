require "spec_helper"
require Rails.root.join("db/migrate/20150714053019_namespace_ems_redhat")

describe NamespaceEmsRedhat do
  class NamespaceEmsRedhat::ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "EmsRedhat")

      migrate

      expect(ems.reload).to have_attributes(:type => "ManageIQ::Providers::Redhat::CloudManager")
    end
  end

  migration_context :down do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ManageIQ::Providers::Redhat::CloudManager")

      migrate

      expect(ems.reload).to have_attributes(:type => "EmsRedhat")
    end
  end
end
