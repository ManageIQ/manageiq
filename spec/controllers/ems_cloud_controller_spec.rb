require "spec_helper"

describe EmsCloudController do
  describe "#create" do
    before do
      EvmSpecHelper.seed_specific_product_features("ems_cloud_new")
      feature = MiqProductFeature.find_all_by_identifier(["ems_cloud_new"])
      Zone.first || FactoryGirl.create(:zone)
      test_user_role  = FactoryGirl.create(:miq_user_role,
                                           :name                 => "test_user_role",
                                           :miq_product_features => feature)
      test_user_group = FactoryGirl.create(:miq_group, :miq_user_role => test_user_role)
      user = FactoryGirl.create(:user, :name => 'test_user', :miq_groups => [test_user_group])

      allow(user).to receive(:server_timezone).and_return("UTC")
      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
      login_as user
    end

    it "adds a new provider" do
      controller.instance_variable_set(:@breadcrumbs, [])
      get :new
      expect(response.status).to eq(200)
      expect(controller.stub(:edit)).to_not be_nil
    end

    it 'creates on post' do
      expect {
        post :create, {
          "button"               => "add",
          "name"                 => "foo",
          "server_emstype"       => "ec2",
          "provider_region"      => "ap-southeast-1",
          "port"                 => "",
          "default_userid"       => "foo",
          "default_password"     => "[FILTERED]",
          "default_verify"       => "[FILTERED]",
          "metrics_userid"       => "",
          "metrics_password"     => "[FILTERED]",
          "metrics_verify"       => "[FILTERED]",
          "amqp_userid"          => "",
          "amqp_password"        => "[FILTERED]",
          "amqp_verify"          => "[FILTERED]",
          "ssh_keypair_userid"   => "",
          "ssh_keypair_password" => "[FILTERED]"
        }
      }.to change { ManageIQ::Providers::Amazon::CloudManager.count }.by(1)
    end
  end
end
