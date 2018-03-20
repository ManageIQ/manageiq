describe MiqHostProvision do
  it "#host_name" do
    host_name = "fred"
    host = FactoryGirl.create(:host, :name => host_name)
    mhp  = MiqHostProvision.create(:host => host)
    expect(mhp.host_name).to eq(host_name)
  end

  it "#host_rediscovered?" do
    pxe_image_type = FactoryGirl.create(:pxe_image_type, :name => 'esx')
    pxe_image = FactoryGirl.create(:pxe_image, :pxe_image_type => pxe_image_type)

    mhp = MiqHostProvision.create
    allow(mhp).to receive(:pxe_image).and_return(pxe_image)
    expect(mhp.host_rediscovered?).to be_falsey

    mhp.host = FactoryGirl.create(:host, :vmm_vendor => 'unknown')
    expect(mhp.host_rediscovered?).to be_falsey

    mhp.host.vmm_vendor = 'vmware'
    expect(mhp.host_rediscovered?).to be_truthy
  end

  context "with default server and zone" do
    before do
      @miq_server = EvmSpecHelper.local_miq_server
    end

    context "with host and miq_host_provision" do
      let(:host) { FactoryGirl.create(:host_vmware_esx, :name => 'fred') }
      let(:mhp)  { MiqHostProvision.create(:host => host) }

      it "#reset_host_credentials" do
        password = 'secret'
        allow(mhp).to receive(:get_option).with(:root_password).and_return(password)
        expect(mhp).to receive(:signal).with(:create_pxe_configuration_files)
        mhp.reset_host_credentials
        expect(mhp.host.authentications.length).to eq(1)
        expect(mhp.host.authentication_userid(:default)).to eq('root')
        expect(mhp.host.authentication_password(:default)).to eq(password)
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
        host.update_authentication(:ipmi    => {:userid => ipmi_userid,    :password => ipmi_password})
        host.update_authentication(:default => {:userid => default_userid, :password => default_password})

        expect(mhp.host).to be_kind_of(ManageIQ::Providers::Vmware::InfraManager::HostEsx)
        allow(mhp).to receive(:get_option).with(:root_password).and_return(dialog_password)
        expect(mhp).to receive(:signal).with(:reset_host_credentials)
        mhp.reset_host_in_vmdb

        expect(mhp.host).to be_kind_of(Host)
        expect(mhp.host.operating_system).to be_nil

        expect(mhp.host.authentications.length).to eq(2)
        expect(mhp.host.authentication_userid(:ipmi)).to eq(ipmi_userid)
        expect(mhp.host.authentication_password(:ipmi)).to eq(ipmi_password)

        expect(mhp.host.authentication_userid(:default)).to eq(dialog_userid)
        expect(mhp.host.authentication_password(:default)).to eq(dialog_password)
      end

      it "#provision_completed" do
        expect(mhp).to receive(:signal).with(:post_install_callback)
        mhp.provision_completed
      end

      it "#post_install_callback" do
        expect(mhp).to receive(:update_and_notify_parent)
        expect(mhp).to receive(:signal).with(:delete_pxe_configuration_files)
        mhp.post_install_callback
      end
    end
  end
end
