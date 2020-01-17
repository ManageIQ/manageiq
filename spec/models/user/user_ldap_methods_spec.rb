RSpec.describe Authenticator::Ldap do
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
    @auth = Authenticator::Ldap.new(@auth_config[:authentication])
  end

  context ".lookup_by_identity" do
    let(:current_user) { @auth.lookup_by_identity(@username) }
    let(:autocreate_current_user) { @auth.autocreate_user(@username) }

    before do
      @username    = "upnuser"
      @user_suffix = @auth_config.fetch_path(:authentication, :user_suffix)
      @fqusername  = "#{@username}@#{@user_suffix}"

      init_ldap_setup
      allow(@miq_ldap).to receive_messages(:fqusername => @fqusername)
    end

    it "initial status" do
      expect(User.all.size).to eq(0)
    end

    it "user exists" do
      user = FactoryBot.create(:user_admin, :userid => @fqusername)
      allow(@auth).to receive(:lookup_by_identity).and_return(user)
      expect(current_user).to eq(user)
    end

    it "user does not exist" do
      group = create_super_admin_group
      @auth_config[:authentication][:default_group_for_users] = group.name
      setup_to_create_user(group)

      expect(autocreate_current_user).to be_present
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
      expect { subject }.to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
    end

    it "ldap bind fails" do
      allow(@miq_ldap).to receive_messages(:bind => false)

      expect(AuditEvent).to receive(:failure)
      expect { subject }.to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
    end

    context "ldap binds" do
      it "get groups from ldap" do
        user = double("some user")
        allow(@auth).to receive_messages(:authorize_queue => user)
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
    FactoryBot.create(
      :miq_group,
      :description   => "EvmGroup-super_administrator",
      :miq_user_role => FactoryBot.create(:miq_user_role, :role => "super_administrator")
    )
  end

  def init_ldap_setup
    @miq_ldap = double('miq_ldap')
    allow(@miq_ldap).to receive_messages(:bind => true)
    allow(MiqLdap).to receive(:new).and_return(@miq_ldap)

    @ldap = double('ldap')
    allow(@auth).to receive_messages(:ldap => @ldap)
  end

  def setup_vmdb_config
    stub_settings(@auth_config)
  end

  def setup_to_create_user(group)
    setup_vmdb_config
    allow(@ldap).to receive_messages(:get_user_object => "A Net::LDAP::Entry object")
    allow(@ldap).to receive_messages(:normalize => "some unique string")
    allow(@ldap).to receive_messages(:get_attr => "xx@xx.com")
    allow(@auth).to receive_messages(:groups_for => [group.description])
  end

  def setup_to_get_fqdn
    allow(@miq_ldap).to receive_messages(:fqusername => "some FQDN")
    allow(@miq_ldap).to receive_messages(:normalize => "some normalized name")
  end
end
