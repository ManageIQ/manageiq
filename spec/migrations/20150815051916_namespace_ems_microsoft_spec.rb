require "spec_helper"
require_migration

describe NamespaceEmsMicrosoft do
  class NamespaceEmsMicrosoft::ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "EmsMicrosoft")

      migrate

      expect(ems.reload).to have_attributes(:type => "ManageIQ::Providers::Microsoft::InfraManager")
    end
  end

  migration_context :down do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ManageIQ::Providers::Microsoft::InfraManager")

      migrate

      expect(ems.reload).to have_attributes(:type => "EmsMicrosoft")
    end
  end
end
