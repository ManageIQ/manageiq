RSpec.describe MiqRequestTask::PostInstallCallback do
  let(:miq_request) { FactoryBot.build(:miq_provision_request, :requester => user) }
  let(:task)        { FactoryBot.create(:miq_request_task, :miq_request => miq_request) }
  let(:user)        { FactoryBot.build(:user) }

  context ".post_install_callback" do
    it "valid id" do
      MiqRequestTask.post_install_callback(task.id)
      expect(MiqQueue.first).to have_attributes(:method_name => "provision_completed", :instance_id => task.id)
    end

    it "invalid id" do
      MiqRequestTask.post_install_callback(0)
      expect(MiqQueue.count).to eq(0)
    end
  end

  context "#post_install_callback_url" do
    before { MiqRegion.seed }

    it "without remote ui url" do
      expect(task.post_install_callback_url).to be_nil
    end

    it "with remote ui url" do
      EvmSpecHelper.create_guid_miq_server_zone
      MiqServer.first.update(:ipaddress => "192.0.2.1", :has_active_userinterface => true)
      expect(task.post_install_callback_url).to eq("https://192.0.2.1/miq_request/post_install_callback?task_id=#{task.id}")
    end
  end
end
