require "spec_helper"

describe EmsCloudController do
  describe "#create" do
    before do
      controller.stub(:check_privileges).and_return(true)
      controller.stub(:assert_privileges).and_return(true)
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)
      login_as FactoryGirl.create(:user, :features => "ems_cloud_new")
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
      FactoryGirl.create(:ems_amazon, :zone => Zone.seed)
      ems = ManageIQ::Providers::Amazon::CloudManager.first
      get :edit, :id => ems.id
      expect(response.status).to eq(200)
    end

    it 'creates on post' do
      expect do
        post :create,           "button"               => "add",
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
      end.to change { ManageIQ::Providers::Amazon::CloudManager.count }.by(1)
    end

    it 'creates an authentication record on post' do
      expect do
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
      end.to change { Authentication.count }.by(1)
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
      Zone.seed
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

    it 'strips whitespace from the name form field on create' do
      MiqServer.stub(:my_zone).and_return("default")
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack     ",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "zone"             => "default",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:hostname => 'host_openstack')
      expect(openstack.to_a[0].name).to eq('foo_openstack')
    end

    it 'strips whitespace from the hostname form field on create' do
      MiqServer.stub(:my_zone).and_return("default")
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack     ",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "zone"             => "default",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => 'foo_openstack')
      expect(openstack.to_a[0].hostname).to eq('host_openstack')
    end

    it 'strips whitespace from the api port form field on create' do
      MiqServer.stub(:my_zone).and_return("default")
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "api_port"         => "5000     ",
           "zone"             => "default",
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => 'foo_openstack')
      expect(openstack.to_a[0].port).to eq('5000')
    end
  end

  describe "#show_link" do
    before do
      Zone.seed
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

    it 'gets the restful timeline link path' do
      MiqServer.stub(:my_zone).and_return("default")
      session[:settings] = {:views =>{:vm_summary_cool => ""}}
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

      post :show,
           "button"           => "timeline",
           "display"          => "timeline",
           "id"               => openstack.to_a[0].id

      expect(response.status).to eq(200)
      show_link_actual_path = controller.send(:show_link, openstack.to_a[0], :display=>"timeline")
      expect(show_link_actual_path).to eq("/ems_cloud/#{openstack.to_a[0].id}?display=timeline")
    end
  end
  context "#build_credentials" do
    let(:mocked_ems) { mock_model(ManageIQ::Providers::Openstack::CloudManager) }
    it "uses params[:default_password] for validation if one exists" do
      controller.instance_variable_set(:@_params,
                                       :default_userid   => "default_userid",
                                       :default_password => "default_password2")
      creds = {:userid => "default_userid", :password => "default_password2"}
      mocked_ems.should_receive(:supports_authentication?).with(:amqp)
      expect(controller.send(:build_credentials, mocked_ems)).to include(:default => creds)
    end

    it "uses the stored password for validation if params[:default_password] does not exist" do
      controller.instance_variable_set(:@_params, :default_userid => "default_userid")
      mocked_ems.should_receive(:authentication_password).and_return('default_password')
      creds = {:userid => "default_userid", :password => "default_password"}
      mocked_ems.should_receive(:supports_authentication?).with(:amqp)
      expect(controller.send(:build_credentials, mocked_ems)).to include(:default => creds)
    end

    it "uses the passwords from params for validation if they exist" do
      controller.instance_variable_set(:@_params,
                                       :default_userid   => "default_userid",
                                       :default_password => "default_password2",
                                       :amqp_userid      => "amqp_userid",
                                       :amqp_password    => "amqp_password2")
      default_creds = {:userid => "default_userid", :password => "default_password2"}
      amqp_creds = {:userid => "amqp_userid", :password => "amqp_password2"}
      mocked_ems.should_receive(:supports_authentication?).with(:amqp).and_return(true)
      expect(controller.send(:build_credentials, mocked_ems)).to include(:default => default_creds,
                                                                         :amqp    => amqp_creds)
    end

    it "uses the stored passwords for validation if passwords dont exist in params" do
      controller.instance_variable_set(:@_params,
                                       :default_userid => "default_userid",
                                       :amqp_userid    => "amqp_userid",)
      mocked_ems.should_receive(:authentication_password).and_return('default_password')
      mocked_ems.should_receive(:authentication_password).with(:amqp).and_return('amqp_password')
      default_creds = {:userid => "default_userid", :password => "default_password"}
      amqp_creds = {:userid => "amqp_userid", :password => "amqp_password"}
      mocked_ems.should_receive(:supports_authentication?).with(:amqp).and_return(true)
      expect(controller.send(:build_credentials, mocked_ems)).to include(:default => default_creds,
                                                                         :amqp    => amqp_creds)
    end

    it "uses the stored passwords/passwords from params to do validation" do
      controller.instance_variable_set(:@_params,
                                       :default_userid   => "default_userid",
                                       :default_password => "default_password2",
                                       :amqp_userid      => "amqp_userid")
      mocked_ems.should_receive(:authentication_password).with(:amqp).and_return('amqp_password')
      default_creds = {:userid => "default_userid", :password => "default_password2"}
      amqp_creds = {:userid => "amqp_userid", :password => "amqp_password"}
      mocked_ems.should_receive(:supports_authentication?).with(:amqp).and_return(true)
      expect(controller.send(:build_credentials, mocked_ems)).to include(:default => default_creds,
                                                                         :amqp    => amqp_creds)
    end
  end
end
