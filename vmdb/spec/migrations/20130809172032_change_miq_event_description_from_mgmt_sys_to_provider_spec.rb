require "spec_helper"
require Rails.root.join("db/migrate/20130809172032_change_miq_event_description_from_mgmt_sys_to_provider.rb")

describe ChangeMiqEventDescriptionFromMgmtSysToProvider do
  migration_context :up do
    let(:miq_event_stub) { migration_stub(:MiqEvent) }

    it "updates description for ems_auth_* events" do
      changed = miq_event_stub.create!(:name => "ems_auth_changed",     :description => "Mgmt Sys Auth Changed")
      ignored = miq_event_stub.create!(:name => "abc_ems_auth_changed", :description => "Mgmt Sys Auth Changed")
      
      migrate
      
      changed.reload.description.should == "Provider Auth Changed"
      ignored.reload.description.should == "Mgmt Sys Auth Changed"
    end
  end
end
