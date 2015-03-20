require "spec_helper"

describe CloudTenantController do
  context "#button" do
    before(:each) do
      set_user_privileges
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
    end

    it "when Instance Retire button is pressed" do
      controller.should_receive(:retirevms).once
      post :button, :pressed => "instance_retire", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when Instance Tag is pressed" do
      controller.should_receive(:tag).with(VmOrTemplate)
      post :button, :pressed => "instance_tag", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end
  end
end
