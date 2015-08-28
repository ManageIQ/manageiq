require "spec_helper"
require_migration

describe NamespaceEmsContainer do
  class NamespaceEmsContainer::ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "EmsKubernetes")

      migrate

      expect(ems.reload).to have_attributes(:type => "ManageIQ::Providers::Kubernetes::ContainerManager")
    end
  end

  migration_context :down do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ManageIQ::Providers::Kubernetes::ContainerManager")

      migrate

      expect(ems.reload).to have_attributes(:type => "EmsKubernetes")
    end
  end
end
