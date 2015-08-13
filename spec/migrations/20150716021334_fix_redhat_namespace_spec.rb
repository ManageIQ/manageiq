require "spec_helper"
require Rails.root.join("db/migrate/20150716021334_fix_redhat_namespace")

describe FixRedhatNamespace do
  class FixRedhatNamespace::ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ManageIQ::Providers::Redhat::CloudManager")

      migrate

      expect(ems.reload).to have_attributes(:type => "ManageIQ::Providers::Redhat::InfraManager")
    end
  end

  migration_context :down do
    it "migrates a representative row" do
      ems = ems_stub.create!(:type => "ManageIQ::Providers::Redhat::InfraManager")

      migrate

      expect(ems.reload).to have_attributes(:type => "ManageIQ::Providers::Redhat::CloudManager")
    end
  end
end
