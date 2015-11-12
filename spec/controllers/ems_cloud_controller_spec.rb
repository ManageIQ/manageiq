require "spec_helper"

describe EmsCloudController do
  let(:server) { EvmSpecHelper.local_miq_server(:zone => zone) }
  let(:zone)   { FactoryGirl.build(:zone) }
  describe "#create" do
    before do
      server
      controller.stub(:check_privileges).and_return(true)
      controller.stub(:assert_privileges).and_return(true)
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
      get :edit, :id => FactoryGirl.create(:ems_amazon).id
      expect(response.status).to eq(200)
    end

    it 'creates on post' do
      expect do
        post :create,
             "button"               => "add",
             "name"                 => "foo",
             "emstype"              => "ec2",
             "provider_region"      => "ap-southeast-1",
             "port"                 => "",
             "zone"                 => zone.name,
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

    it 'creates and updates an authentication record on post' do
      expect do
        post :create,
             "button"           => "add",
             "hostname"         => "host_openstack",
             "name"             => "foo_openstack",
             "emstype"          => "openstack",
             "provider_region"  => "",
             "port"             => "5000",
             "zone"             => zone.name,
             "default_userid"   => "foo",
             "default_password" => "[FILTERED]",
             "default_verify"   => "[FILTERED]"
      end.to change { Authentication.count }.by(1)

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack").first
      expect(openstack.authentications.size).to eq(1)

      expect do
        post :update,
             "id"               => openstack.id,
             "button"           => "save",
             "hostname"         => "host_openstack_updated",
             "name"             => "foo_openstack",
             "emstype"          => "openstack",
             "provider_region"  => "",
             "port"             => "5000",
             "default_userid"   => "bar",
             "default_password" => "[FILTERED]",
             "default_verify"   => "[FILTERED]"
      end.not_to change { Authentication.count }

      expect(response.status).to eq(200)
      expect(openstack.authentications.first).to have_attributes(:userid => "bar", :password => "[FILTERED]")
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
           "zone"             => zone.name,
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
      server
      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
      controller.stub(:assert_privileges).and_return(true)
    end

    it 'gets the ems cloud form fields on a get' do
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "zone"             => zone.name,
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack").first
      get :ems_cloud_form_fields, "id" => openstack.id
      expect(response.status).to eq(200)
      expect(response.body).to include('"name":"foo_openstack"')
    end

    it 'strips whitespace from name, hostname and api_port form fields on create' do
      post :create,
           "button"           => "add",
           "hostname"         => "  host_openstack     ",
           "name"             => "  foo_openstack     ",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "api_port"         => "   5000     ",
           "zone"             => zone.name,
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      expect(ManageIQ::Providers::Openstack::CloudManager.where(:hostname => 'host_openstack', :name => 'foo_openstack', :port => '5000').count).to eq(1)
    end
  end

  describe "#show_link" do
    before do
      server
      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
      controller.stub(:assert_privileges).and_return(true)
    end

    it 'gets the restful show link and timeline link paths' do
      session[:settings] = {:views =>{:vm_summary_cool => ""}}
      post :create,
           "button"           => "add",
           "hostname"         => "host_openstack",
           "name"             => "foo_openstack",
           "emstype"          => "openstack",
           "provider_region"  => "",
           "port"             => "5000",
           "zone"             => zone.name,
           "default_userid"   => "foo",
           "default_password" => "[FILTERED]",
           "default_verify"   => "[FILTERED]"

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::CloudManager.where(:name => "foo_openstack").first
      show_link_actual_path = controller.send(:show_link, openstack)
      expect(show_link_actual_path).to eq("/ems_cloud/#{openstack.id}")

      post :show,
           "button"           => "timeline",
           "display"          => "timeline",
           "id"               => openstack.id

      expect(response.status).to eq(200)
      show_link_actual_path = controller.send(:show_link, openstack, :display => "timeline")
      expect(show_link_actual_path).to eq("/ems_cloud/#{openstack.id}?display=timeline")
    end
  end

  context "#build_credentials only contains credentials that it supports and has a username for in params" do
    let(:mocked_ems)    { mock_model(ManageIQ::Providers::Openstack::CloudManager) }
    let(:default_creds) { {:userid => "default_userid", :password => "default_password"} }
    let(:amqp_creds)    { {:userid => "amqp_userid",    :password => "amqp_password"} }

    it "uses the passwords from params for validation if they exist" do
      controller.instance_variable_set(:@_params,
                                       :default_userid   => default_creds[:userid],
                                       :default_password => default_creds[:password],
                                       :amqp_userid      => amqp_creds[:userid],
                                       :amqp_password    => amqp_creds[:password])
      expect(mocked_ems).to receive(:supports_authentication?).with(:amqp).and_return(true)
      expect(mocked_ems).to receive(:supports_authentication?).with(:oauth)
      expect(mocked_ems).to receive(:supports_authentication?).with(:service_account)
      expect(controller.send(:build_credentials, mocked_ems)).to eq(:default => default_creds, :amqp => amqp_creds)
    end

    it "uses the stored passwords for validation if passwords dont exist in params" do
      controller.instance_variable_set(:@_params,
                                       :default_userid => default_creds[:userid],
                                       :amqp_userid    => amqp_creds[:userid])
      expect(mocked_ems).to receive(:authentication_password).and_return(default_creds[:password])
      expect(mocked_ems).to receive(:authentication_password).with(:amqp).and_return(amqp_creds[:password])
      expect(mocked_ems).to receive(:supports_authentication?).with(:amqp).and_return(true)
      expect(mocked_ems).to receive(:supports_authentication?).with(:oauth)
      expect(mocked_ems).to receive(:supports_authentication?).with(:service_account)
      expect(controller.send(:build_credentials, mocked_ems)).to eq(:default => default_creds, :amqp => amqp_creds)
    end
  end

  context "#update_ems_button_validate" do
    let(:mocked_ems) { mock_model(ManageIQ::Providers::Openstack::CloudManager) }
    it "calls authentication_check with save = true if validation is done for an existing record" do
      controller.stub(:set_ems_record_vars)
      controller.stub(:render)
      controller.instance_variable_set(:@_params,
                                       :button    => "validate",
                                       :id        => mocked_ems.id,
                                       :cred_type => "default")
      expect(mocked_ems).to receive(:authentication_check).with("default", :save => true)
      controller.send(:update_ems_button_validate, mocked_ems)
    end

    it "calls authentication_check with save = false if validation is done for a new record" do
      controller.stub(:set_ems_record_vars)
      controller.stub(:render)
      controller.instance_variable_set(:@_params,
                                       :button           => "validate",
                                       :id               => "new",
                                       :default_password => "[FILTERED]",
                                       :cred_type        => "default")
      expect(mocked_ems).to receive(:authentication_check).with("default", :save => false)
      controller.send(:update_ems_button_validate, mocked_ems)
    end
  end
end
