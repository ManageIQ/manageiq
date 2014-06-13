require "spec_helper"

describe MiqRequestTask do
  before do
    MiqRegion.seed
    EvmSpecHelper.create_guid_miq_server_zone
    fred          = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
    approver_role = FactoryGirl.create(:ui_task_set_approver)
    miq_request   = FactoryGirl.create(:miq_request)
    @task         = FactoryGirl.create(:miq_request_task, :miq_request => miq_request, :type => 'MiqRequestTask')
  end

  context ".post_install_callback" do
    it "valid id" do
      described_class.post_install_callback(@task.id)
      expect(MiqQueue.first.method_name).to eq("provision_completed")
    end

    it "invalid id" do
      described_class.post_install_callback(0)
      expect(MiqQueue.count).to eq(0)
    end
  end

  context "#post_install_callback_url" do
    it "nil data" do
      expect(@task.post_install_callback_url).to be_nil
    end

    it "with data" do
      MiqServer.first.update_attributes(:ipaddress => "1.2.3.4", :has_active_userinterface => true)
      expect(@task.post_install_callback_url).to eq("https://1.2.3.4/miq_request/post_install_callback?task_id=#{@task.id}")
    end
  end
end
