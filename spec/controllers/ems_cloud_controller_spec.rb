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
          "emstype"              => "ec2",
          "provider_region"      => "ap-southeast-1",
          "port"                 => "",
          "zone"                 => "default",
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
          "emstype"          => "openstack",
          "provider_region"  => "",
          "port"             => "5000",
          "zone"             => "default",
          "default_userid"   => "foo",
          "default_password" => "[FILTERED]",
          "default_verify"   => "[FILTERED]"

        expect(response.status).to eq(200)
        openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack")
        authentication = Authentication.where(:resource_id => openstack.to_a[0].id).first
        expect(authentication).not_to be_nil
      }.to change { Authentication.count }.by(1)
    end

    it 'updates an authentication record on post' do
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "zone"             => "default",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack")
      authentication = Authentication.where(:resource_id => openstack.to_a[0].id).first
      expect(authentication).not_to be_nil

      post :update,
           "id"               => openstack.to_a[0].id,
           "button"           => "save",
           "hostname"         => "host_openstack_updated",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack")
      authentication = Authentication.where(:resource_id => openstack.to_a[0].id).first
      expect(authentication.userid).to eq("foo")
      expect(authentication.password).to eq("[FILTERED]")
    end

    it "validates credentials for a new record" do
      post :create,
           "button"           => "validate",
           "cred_type"        => "default",
           "name"             => "foo_ec2",
           "emstype"          => "ec2",
           "provider_region"  => "ap-southeast-1",
           "zone"             => "default",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
    end

    it "cancels a new record" do
      post :create,
           "button"           => "cancel",
           "cred_type"        => "default",
           "name"             => "foo_ec2",
           "emstype"          => "ec2",
           "provider_region"  => "ap-southeast-1",
           "zone"             => "default",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
    end

    it "adds a record of type azure" do
      post :create,
           "button"           => "add",
           "azure_tenant_id"  => "azure",
           "name"             => "foo_azure",
           "emstype"          => "azure",
           "zone"             => "default",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      edit = controller.instance_variable_get(:@edit)
      expect(edit[:new][:azure_tenant_id]).to eq("azure")
    end
  end

  describe "#ems_cloud_form_fields" do
    before do
      Zone.first || FactoryGirl.create(:zone)
      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
      controller.stub(:assert_privileges).and_return(true)
    end
    it 'gets the ems cloud form fields on a get' do
      MiqServer.stub(:my_zone).and_return("default")
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "zone"             => "default",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack")
      get :ems_cloud_form_fields, "id" => openstack.to_a[0].id
      expect(response.status).to eq(200)
      expect(response.body).to include('"name":"foo_openstack"')
    end
  end

  describe "#show_link" do
    before do
      Zone.first || FactoryGirl.create(:zone)
      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
      controller.stub(:assert_privileges).and_return(true)
    end
    it 'gets the restful show link path' do
      MiqServer.stub(:my_zone).and_return("default")
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "zone"             => "default",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"
      
      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack")
      show_link_actual_path = controller.send(:show_link, openstack.to_a[0])
      expect(show_link_actual_path).to eq("/ems_cloud/#{openstack.to_a[0].id}")
    end
  end
end
