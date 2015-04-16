require "spec_helper"

describe Authenticate::Ldap do
  before do
    EvmSpecHelper.create_guid_miq_server_zone
    @auth_config = {
      :authentication => {
        :mode        => "ldap",
        :ldap_role   => true,
        :user_suffix => "manageiq.org",
        :user_type   => "userprincipalname",
      }
    }
    @auth = Authenticate::Ldap.new(@auth_config[:authentication])
  end

  context ".lookup_by_identity" do
    let(:current_user) { @auth.lookup_by_identity(@username) }

    before do
      @username    = "upnuser"
      @user_suffix = @auth_config.fetch_path(:authentication, :user_suffix)
      @fqusername  = "#{@username}@#{@user_suffix}"

      init_ldap_setup
      @ldap.stub(:fqusername => @fqusername)
    end

    it "initial status" do
      expect(User.all.size).to eq(0)
    end

    it "user exists" do
      user = FactoryGirl.create(:user_admin, :userid => @fqusername)
      expect(current_user).to eq(user)
    end

    it "user does not exist" do
      group = create_super_admin_group
      setup_to_create_user(group)

      expect(current_user).to be_present
      expect(User.all.size).to eq(1)
    end
  end

  context ".authenticate" do
    before do
      @password = "secret"
      setup_vmdb_config
      init_ldap_setup
      setup_to_get_fqdn
    end
    subject { @auth.authenticate("username", @password, nil) }

    it "password is blank" do
      @password = ""
      expect(AuditEvent).to receive(:failure)
      expect(-> { subject }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
    end

    it "ldap bind fails" do
      @login_ldap.stub(:bind => false)

      expect(AuditEvent).to receive(:failure)
      expect(-> { subject }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
    end

    context "ldap binds" do
      it "get groups from ldap" do
        user = double("some user")
        @auth.stub(:authorize_queue => user)
        expect(subject).to eq(user)
      end

      context "get groups from ldap not enabled" do
        before do
          @auth_config[:authentication][:ldap_role] = false
        end

        it "no default group for users" do
          expect { subject }.to raise_error(MiqException::MiqEVMLoginError)
        end

        context "with default group for users enabled" do
          it "group exists" do
            group = create_super_admin_group
            setup_to_create_user(group)
            @auth_config[:authentication][:default_group_for_users] = group.description
            expect(subject.current_group).to eq(group)
          end

          it "group does not exist" do
            @auth_config[:authentication][:default_group_for_users] = "a deleted group"
            expect { subject }.to raise_error(MiqException::MiqEVMLoginError)
          end
        end
      end
    end
  end

  def create_super_admin_group
    FactoryGirl.create(
      :miq_group,
      :description   => "EvmGroup-super_administrator",
      :miq_user_role => FactoryGirl.create(:miq_user_role, :name => "EvmRole-super_administrator")
    )
  end

  def init_ldap_setup
    @login_ldap = double('login_ldap')
    @login_ldap.stub(:bind => true)
    MiqLdap.stub(:new).and_return(@login_ldap)

    @ldap = double('ldap')
    @auth.stub(:ldap => @ldap)
  end

  def setup_vmdb_config
    vmdb_config = double("vmdb_config")
    vmdb_config.stub(:config => @auth_config)
    VMDB::Config.stub(:new).with("vmdb").and_return(vmdb_config)
  end

  def setup_to_create_user(group)
    setup_vmdb_config
    @ldap.stub(:get_user_object => "A Net::LDAP::Entry object")
    @ldap.stub(:normalize => "some unique string")
    @ldap.stub(:get_attr => "xx@xx.com")
    @auth.stub(:groups_for => [group.description])
  end

  def setup_to_get_fqdn
    @ldap.stub(:fqusername => "some FQDN")
    @ldap.stub(:normalize => "some normalized name")
  end
end
