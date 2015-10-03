require "spec_helper"
require_migration

describe NamespaceEmsOpenstack do
  class NamespaceEmsOpenstack::ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "EmsOpenstack")

      migrate

      expect(ems.reload).to have_attributes(:type => "ManageIQ::Providers::Openstack::CloudManager")
    end
  end

  migration_context :down do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ManageIQ::Providers::Openstack::CloudManager")

      migrate

      expect(ems.reload).to have_attributes(:type => "EmsOpenstack")
    end
  end
end
