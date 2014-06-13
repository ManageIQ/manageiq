# encoding: utf-8

require "spec_helper"
require Rails.root.join("db/migrate/20130826174120_change_nil_provision_index_to_zero.rb")

describe ChangeNilProvisionIndexToZero do
  migration_context :up do
    let(:service_resource_stub)    { migration_stub(:ServiceResource) }

    it "change nil provision index to 0" do
      sr = service_resource_stub.create!(:provision_index => nil)

      migrate

      sr.reload.provision_index.should == 0
    end

    it "leave populated provision index unchanged" do
      sr = service_resource_stub.create!(:provision_index => 2)

      migrate

      sr.reload.provision_index.should == 2
    end

  end
end
