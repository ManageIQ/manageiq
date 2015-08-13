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
      controller.stub(:assert_privileges).and_return(true)
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
      login_as user
    end

    it "adds a new provider" do
      controller.instance_variable_set(:@breadcrumbs, [])
      get :new
      expect(response.status).to eq(200)
      expect(controller.stub(:edit)).to_not be_nil
    end

    render_views

    it 'shows the edit page' do
      expect(MiqServer.my_server).to be
      FactoryGirl.create(:ems_amazon, :zone => Zone.first)
      ems = ManageIQ::Providers::Amazon::CloudManager.first
      get :edit, :id => ems.id
      expect(response.status).to eq(200)
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

    it 'creates an authentication record on post' do
      expect {
        post :create,
          "button"           => "add",
          "hostname"         => "host_openstack",
          "name"             => "foo_openstack",
          "server_emstype"   => "openstack",
          "provider_region"  => "",
          "port"             => "5000",
          "default_userid"   => "foo",
          "default_password" => "[FILTERED]",
          "default_verify"   => "[FILTERED]"

        expect(response.status).to eq(200)
        openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack")
        authentication = Authentication.where(:resource_id => openstack.to_a[0].id).first
        expect(authentication).not_to be_nil
      }.to change { Authentication.count }.by(1)
    end
  end
end
