require "spec_helper"

describe EmsCloudController do
  describe "#create" do
    before do
      EvmSpecHelper.seed_specific_product_features("ems_cloud_new")
      feature = MiqProductFeature.find_all_by_identifier(["ems_cloud_new"])
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

    it 'creates an authentication record on post' do
      MiqServer.stub(:my_zone).and_return("default")
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack")
      expect(openstack).not_to be_nil
      authentication = Authentication.where(:resource_id => openstack.to_a[0].id).first
      expect(authentication).not_to be_nil
    end
  end

  describe "#update" do
    before do
      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
      controller.stub(:assert_privileges).and_return(true)
    end
    it 'updates an authentication record on post' do
      MiqServer.stub(:my_zone).and_return("default")
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      @openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack")
      expect(@openstack).not_to be_nil
      authentication = Authentication.where(:resource_id => @openstack.to_a[0].id).first
      expect(authentication).not_to be_nil

      post :update,
           "id"               => @openstack.to_a[0].id,
           "button"           => "save",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack2",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      openstack_updated = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack2")
      expect(openstack_updated).not_to be_nil
      authentication = Authentication.where(:resource_id => openstack_updated.to_a[0].id).first
      expect(authentication).not_to be_nil
    end
  end

  describe "#ems_cloud_form_fields" do
    before do
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
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      @openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack")

      get :ems_cloud_form_fields, "id" => @openstack.to_a[0].id

      expect(response.status).to eq(200)
      expect(response.body).to include('"name":"foo_openstack"')
    end
  end

  describe "#render views" do
    before do
      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
      controller.stub(:assert_privileges).and_return(true)

      MiqServer.stub(:my_zone).and_return("default")
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"
    end

    it 'renders a new cloud provider form' do
      post :new, :format => :js
      expect(response.status).to eq(200)
    end

    it 'renders an edit cloud provider form' do
      expect(response.status).to eq(200)
      @openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack")
      post :edit, :id => @openstack.to_a[0].id, :format => :js
      expect(response.status).to eq(200)
    end
  end
end
