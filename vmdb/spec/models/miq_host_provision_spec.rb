require "spec_helper"

describe MiqHostProvision do
  it "#host_name" do
    host_name = "fred"
    host = FactoryGirl.create(:host, :name => host_name)
    mhp  = MiqHostProvision.create(:host => host)
    mhp.host_name.should == host_name
  end

  it "#host_rediscovered?" do
    pxe_image_type = FactoryGirl.create(:pxe_image_type, :name => 'esx')
    pxe_image = FactoryGirl.create(:pxe_image, :pxe_image_type => pxe_image_type)

    mhp = MiqHostProvision.create
    mhp.stub(:pxe_image).and_return(pxe_image)
    mhp.host_rediscovered?.should be_false

    mhp.host = FactoryGirl.create(:host, :vmm_vendor => 'unknown')
    mhp.host_rediscovered?.should be_false

    mhp.host.vmm_vendor = 'vmware'
    mhp.host_rediscovered?.should be_true
  end

  context "with default server and zone" do
    before(:each) do
      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)

      @zone       = FactoryGirl.create(:zone)
      @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
      MiqServer.stub(:my_server).and_return(@miq_server)
    end

    context "with host and miq_host_provision" do
      let(:host) { FactoryGirl.create(:host_vmware_esx, :name => 'fred') }
      let(:mhp)  { MiqHostProvision.create(:host => host) }

      it "#reset_host_credentials" do
        password = 'secret'
        mhp.stub(:get_option).with(:root_password).and_return(password)
        mhp.should_receive(:signal).with(:create_pxe_configuration_files)
        mhp.reset_host_credentials
        mhp.host.authentications.length.should == 1
        mhp.host.authentication_userid(:default).should   == 'root'
        mhp.host.authentication_password(:default).should == password
      end

      it "#reset_host_in_vmdb" do
        ipmi_userid      = 'ipmi_user'
        ipmi_password    = 'ipmi_password'
        default_userid   = 'default_user'
        default_password = 'default_password'
        dialog_userid    = 'root'
        dialog_password  = 'dialog_password'
        ipmi_address     = '123.211.21.1'

        host.update_attributes(:ipmi_address => ipmi_address, :operating_system => FactoryGirl.create(:operating_system))
        host.update_authentication(:ipmi    => { :userid => ipmi_userid,    :password => ipmi_password    })
        host.update_authentication(:default => { :userid => default_userid, :password => default_password })

        mhp.host.should be_kind_of(HostVmwareEsx)
        mhp.stub(:get_option).with(:root_password).and_return(dialog_password)
        mhp.should_receive(:signal).with(:reset_host_credentials)
        mhp.reset_host_in_vmdb

        mhp.host.should be_kind_of(Host)
        mhp.host.operating_system.should be_nil

        mhp.host.authentications.length.should == 2
        mhp.host.authentication_userid(:ipmi).should   == ipmi_userid
        mhp.host.authentication_password(:ipmi).should == ipmi_password

        mhp.host.authentication_userid(:default).should   == dialog_userid
        mhp.host.authentication_password(:default).should == dialog_password
      end

      it "#provision_completed" do
        mhp.should_receive(:signal).with(:post_install_callback)
        mhp.provision_completed
      end

      it "#post_install_callback" do
        mhp.should_receive(:update_and_notify_parent)
        mhp.should_receive(:signal).with(:delete_pxe_configuration_files)
        mhp.post_install_callback
      end
    end
  end

end
