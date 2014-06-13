require "spec_helper"

describe MiqRequestController do
  context "#post_install_callback should render nothing" do
    before(:each) do
      described_class.any_instance.stub(:set_user_time_zone)
    end

    it "when called with a task id" do
      MiqRequestTask.should_receive(:post_install_callback).with("12345").once
      get 'post_install_callback', :task_id => 12345
      expect(response.body).to be_blank
    end

    it "when called without a task id" do
      MiqRequestTask.should_not_receive(:post_install_callback)
      get 'post_install_callback'
      expect(response.body).to be_blank
    end
  end
end
