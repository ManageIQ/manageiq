RSpec.describe Authenticator::Httpd do
  subject { Authenticator::Httpd.new(config) }
  let!(:alice) { FactoryBot.create(:user, :userid => 'alice') }
  let!(:cheshire) { FactoryBot.create(:user, :userid => 'cheshire@example.com') }
  let(:user_groups) { 'wibble@fqdn:bubble@fqdn' }
  let(:config) { {:httpd_role => false} }
  let(:request) do
    env = {}
    headers.each do |k, v|
      env["HTTP_#{k.upcase.tr '-', '_'}"] = v if v
    end
    ActionDispatch::Request.new(Rack::MockRequest.env_for("/", env))
  end

  before do
    # If anything goes looking for the currently configured
    # Authenticator during any of these tests, we'd really rather they
    # found the one we're working on.
    #
    # This specifically comes up when we auto-create a new user from an
    # external auth system: they get saved without a password, so User's
    # dummy_password_for_external_auth hook runs, and it needs to ask
    # Authenticator#uses_stored_password? whether it's allowed to do anything.

    allow(User).to receive(:authenticator).and_return(subject)

    EvmSpecHelper.create_guid_miq_server_zone
  end

  before do
    FactoryBot.create(:miq_group, :description => 'wibble')
    FactoryBot.create(:miq_group, :description => 'wobble')

    allow(MiqLdap).to receive(:using_ldap?) { false }
  end

  describe '#uses_stored_password?' do
    it "is false" do
      expect(subject.uses_stored_password?).to be_falsey
    end
  end

  describe '.user_authorizable_without_authentication?' do
    it "is true" do
      expect(subject.user_authorizable_without_authentication?).to be_truthy
    end
  end

  describe '.user_authorizable_with_system_token?' do
    let(:auth_oidc_settings) do
      {
        :mode          => "httpd",
        :httpd_role    => true,
        :oidc_enabled  => true,
        :saml_enabled  => false,
        :provider_type => "oidc"
      }
    end

    let(:auth_saml_settings) do
      {
        :mode          => "httpd",
        :httpd_role    => true,
        :oidc_enabled  => false,
        :saml_enabled  => true,
        :provider_type => "saml"
      }
    end

    it "is false" do
      expect(subject.user_authorizable_with_system_token?).to be_falsey
    end

    it "is true for OIDC" do
      stub_settings_merge(:authentication => auth_oidc_settings)

      expect(subject.user_authorizable_with_system_token?).to be_truthy
    end

    it "is true for SAML" do
      stub_settings_merge(:authentication => auth_saml_settings)

      expect(subject.user_authorizable_with_system_token?).to be_truthy
    end
  end

  describe '#lookup_by_identity' do
    let(:dn) { 'cn=towmater,ou=people,ou=prod,dc=example,dc=com' }
    let!(:towmater_dn) { FactoryBot.create(:user, :userid => dn) }

    let(:headers) do
      {
        'X-Remote-User'           => username,
        'X-Remote-User-FullName'  => 'Cheshire Cat',
        'X-Remote-User-FirstName' => 'Chechire',
        'X-Remote-User-LastName'  => 'Cat',
        'X-Remote-User-Email'     => 'cheshire@example.com',
        'X-Remote-User-Domain'    => 'example.com',
        'X-Remote-User-Groups'    => user_groups,
      }
    end

    let(:username) { 'cheshire' }

    it "Handles missing request parameter" do
      expect(subject.lookup_by_identity('alice')).to eq(alice)
    end

    it "finds existing users as username" do
      expect(subject.lookup_by_identity('alice', request)).to eq(alice)
    end

    it "finds existing users as UPN" do
      expect(subject.lookup_by_identity('cheshire', request)).to eq(cheshire)
    end

    it "finds existing users as distinguished name" do
      expect(subject.lookup_by_identity('towmater', request)).to eq(towmater_dn)
    end

    it "doesn't create new users" do
      expect(subject.lookup_by_identity('bob', request)).to be_nil
    end
  end

  describe '#find_or_initialize_user' do
    let(:user_attrs_simple) do
      { :username  => "sal",
        :fullname  => "Test User Sal",
        :firstname => "Salvadore",
        :lastname  => "Bigs",
        :email     => "sal_email@example.com",
        :domain    => "example.com" }
    end

    let(:identity_simple) { [user_attrs_simple, %w(mumble bumble bee)] }

    let(:user_attrs_upn) do
      { :username  => "sal@example.com",
        :fullname  => "Test User Sal",
        :firstname => "Salvadore",
        :lastname  => "Bigs",
        :email     => "sal_email@example.com",
        :domain    => "example.com" }
    end

    let(:identity_upn) { [user_attrs_upn, %w(mumble bumble bee)] }

    let(:upn_sal) { FactoryBot.create(:user, :userid => 'sal@example.com') }

    before do
      upn_sal
    end

    it "Returns UPN username when passed UPN username" do
      expect(subject.find_or_initialize_user(identity_upn, 'sal@example.com')).to match_array(["sal@example.com", upn_sal])
    end

    it "Returns UPN username when passed simple username" do
      expect(subject.find_or_initialize_user(identity_simple, 'sal')).to match_array(["sal@example.com", upn_sal])
    end
  end

  describe '#authenticate' do
    def authenticate
      subject.authenticate(username, nil, request)
    end

    let(:headers) do
      {
        'X-Remote-User'           => username,
        'X-Remote-User-FullName'  => 'Alice Aardvark',
        'X-Remote-User-FirstName' => 'Alice',
        'X-Remote-User-LastName'  => 'Aardvark',
        'X-Remote-User-Email'     => 'alice@example.com',
        'X-Remote-User-Domain'    => 'example.com',
        'X-Remote-User-Groups'    => user_groups,
      }
    end

    let(:username) { 'alice' }

    context "with user details" do
      context "using local authorization" do
        it "succeeds" do
          expect(authenticate).to eq(alice)
        end

        it "records two successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_httpd',
            :userid  => 'alice',
            :message => "User alice successfully validated by External httpd",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_httpd',
            :userid  => 'alice',
            :message => "Authentication successful for user alice",
          )
          expect(AuditEvent).not_to receive(:failure)
          authenticate
        end

        it "updates lastlogon" do
          expect { authenticate }.to(change { alice.reload.lastlogon })
        end
      end

      context "using external authorization" do
        let(:config) { {:httpd_role => true} }

        it "enqueues an authorize task" do
          expect(subject).to receive(:authorize_queue).and_return(123)
          expect(authenticate).to eq(123)
        end

        it "records two successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_httpd',
            :userid  => 'alice',
            :message => "User alice successfully validated by External httpd",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_httpd',
            :userid  => 'alice',
            :message => "Authentication successful for user alice",
          )
          expect(AuditEvent).not_to receive(:failure)
          authenticate
        end

        it "updates lastlogon" do
          expect { authenticate }.to(change { alice.reload.lastlogon })
        end

        it "immediately completes the task" do
          task_id = authenticate
          task = MiqTask.find(task_id)
          expect(User.lookup_by_userid(task.userid)).to eq(alice)
        end
      end
    end

    context "with invalid user" do
      let(:headers) { super().except('X-Remote-User') }

      it "fails" do
        expect { authenticate }.to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
      end

      it "puts the right name in a failing audit entry" do
        expect(AuditEvent).to receive(:failure).with(
          :event   => 'authenticate_httpd',
          :userid  => 'alice',
          :message => "Authentication failed for userid alice",
        )
        expect(AuditEvent).not_to receive(:success)
        authenticate rescue nil
      end
    end

    context "without a user" do
      let(:username) { '' }

      it "fails" do
        expect { authenticate }.to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
      end

      it "records one failing audit entry" do
        expect(AuditEvent).to receive(:failure).with(
          :event   => 'authenticate_httpd',
          :userid  => '',
          :message => "Authentication failed for userid ",
        )
        expect(AuditEvent).not_to receive(:success)
        authenticate rescue nil
      end
      it "logs the failure" do
        allow($log).to receive(:warn).with(/Audit/)
        expect($log).to receive(:warn).with(/Authentication failed$/)
        authenticate rescue nil
      end
      it "doesn't change lastlogon" do
        expect { authenticate rescue nil }.not_to(change { alice.reload.lastlogon })
      end

      context "with specific failure message" do
        let(:headers) { super().merge('X-External-Auth-Error' => 'because reasons') }

        it "reflects in the audit message" do
          expect(AuditEvent).to receive(:failure).with(
            :event   => 'authenticate_httpd',
            :userid  => '',
            :message => "Authentication failed for userid : because reasons",
          )
          authenticate rescue nil
        end
      end
    end

    context "with potential for multiple user records" do
      let(:dn) { 'cn=sally,ou=people,ou=prod,dc=example,dc=com' }
      let(:config) { {:httpd_role => true} }

      let(:username) { 'saLLy' }
      let(:headers) do
        super().merge('X-Remote-User-FullName'  => 'Sally Porsche',
                      'X-Remote-User-FirstName' => 'Sally',
                      'X-Remote-User-LastName'  => 'Porsche',
                      'X-Remote-User-Email'     => 'Sally@example.com')
      end

      context "with a race condition on create user" do
        before do
          authenticate
        end

        it "update the exiting user" do
          allow(User).to receive(:lookup_by_userid).and_return(nil)
          allow(User).to receive(:in_my_region).and_return(User.none, User.all)
          expect { authenticate }.not_to(change { User.where(:userid => 'sally@example.com').count }.from(1))
        end
      end

      context "when user record with userid in upn format already exists" do
        let!(:sally_username) { FactoryBot.create(:user, :userid => 'sAlly') }
        let!(:sally_dn) { FactoryBot.create(:user, :userid => dn) }
        let!(:sally_upn) { FactoryBot.create(:user, :userid => 'sAlly@example.com') }

        it "leaves user record with userid in username format unchanged" do
          expect { authenticate }.to_not(change { sally_username.reload.userid })
        end

        it "leaves user record with userid in distinguished name format unchanged" do
          expect { authenticate }.to_not(change { sally_dn.reload.userid })
        end

        it "downcases user record with userid in upn format" do
          expect { authenticate }
            .to(change { sally_upn.reload.userid }.from("sAlly@example.com").to("sally@example.com"))
        end
      end

      context "when user record with userid in upn format does not already exists" do
        it "updates userid from username format to upn format" do
          sally_username = FactoryBot.create(:user, :userid => 'sally')
          expect { authenticate }.to(change { sally_username.reload.userid }.from("sally").to("sally@example.com"))
        end

        it "updates userid from distinguished name format to upn format" do
          sally_dn = FactoryBot.create(:user, :userid => dn)
          expect { authenticate }.to(change { sally_dn.reload.userid }.from(dn).to("sally@example.com"))
        end

        it "does not modify userid if already in upn format" do
          sally_upn = FactoryBot.create(:user, :userid => 'sally@example.com')
          expect { authenticate }.to_not(change { sally_upn.reload.userid })
        end
      end

      context "when user record is for a different region" do
        let(:my_region_number) { ApplicationRecord.my_region_number }
        let(:other_region) { ApplicationRecord.my_region_number + 1 }
        let(:other_region_id) { other_region * ApplicationRecord.rails_sequence_factor + 1 }

        it "does not modify the user record when userid is in username format" do
          sally_username = FactoryBot.create(:user, :userid => 'sally', :id => other_region_id)
          expect { authenticate }.to_not(change { sally_username.reload.userid })
        end

        it "does not modify the user record when userid is in distinguished name format" do
          sally_dn = FactoryBot.create(:user, :userid => dn, :id => other_region_id)
          expect { authenticate }.to_not(change { sally_dn.reload.userid })
        end

        it "does not modify the user record when userid is in already upn format" do
          sally_upn = FactoryBot.create(:user, :userid => 'sally@example.com', :id => other_region_id)
          expect { authenticate }.to_not(change { sally_upn.reload.userid })
        end
      end
    end

    context "with unknown username in mixed case" do
      let(:username) { 'bOb' }
      let(:headers) do
        super().merge('X-Remote-User-FullName' => 'Bob Builderson',
                      'X-Remote-User-Email'    => 'bob@example.com')
      end

      context "using local authorization" do
        it "fails" do
          expect { authenticate }.to raise_error(MiqException::MiqEVMLoginError)
        end

        it "records one successful and one failing audit entry" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_httpd',
            :userid  => 'bob',
            :message => "User bob successfully validated by External httpd",
          )
          expect(AuditEvent).to receive(:failure).with(
            :event   => 'authenticate_httpd',
            :userid  => 'bob',
            :message => "User bob authenticated but not defined in EVM",
          )
          authenticate rescue nil
        end
        it "logs the failure" do
          allow($log).to receive(:warn).with(/Audit/)
          expect($log).to receive(:warn).with(/User authenticated but not defined in EVM, please contact your EVM administrator/)
          authenticate rescue nil
        end
      end

      context "using external authorization" do
        let(:config) { {:httpd_role => true} }

        it "enqueues an authorize task" do
          expect(subject).to receive(:authorize_queue).and_return(123)
          expect(authenticate).to eq(123)
        end

        it "records three successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authorize',
            :userid  => 'bob',
            :message => "User creation successful for User: Bob Builderson with ID: bob@example.com",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_httpd',
            :userid  => 'bob',
            :message => "User bob successfully validated by External httpd",
          )

          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_httpd',
            :userid  => 'bob',
            :message => "Authentication successful for user bob",
          )
          expect(AuditEvent).not_to receive(:failure)
          authenticate
        end

        it "immediately completes the task" do
          task_id = authenticate
          task = MiqTask.find(task_id)
          user = User.lookup_by_userid(task.userid)
          expect(user.name).to eq('Bob Builderson')
          expect(user.email).to eq('bob@example.com')
        end

        it "creates a new User" do
          expect { authenticate }.to(change { User.where(:userid => 'bob@example.com').count }.from(0).to(1))
        end

        context "with no matching groups" do
          let(:headers) { super().merge('X-Remote-User-Groups' => 'bubble:trouble') }

          it "enqueues an authorize task" do
            expect(subject).to receive(:authorize_queue).and_return(123)
            expect(authenticate).to eq(123)
          end

          it "records three successful audit entries plus one failure" do
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authorize',
              :userid  => 'bob',
              :message => "User creation successful for User: Bob Builderson with ID: bob@example.com",
            )
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authenticate_httpd',
              :userid  => 'bob',
              :message => "User bob successfully validated by External httpd",
            )
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authenticate_httpd',
              :userid  => 'bob',
              :message => "Authentication successful for user bob",
            )
            expect(AuditEvent).to receive(:failure).with(
              :event   => 'authorize',
              :userid  => 'bob',
              :message => "Authentication failed for userid bob@example.com, unable to match user's group membership to an EVM role",
            )
            authenticate
          end

          it "doesn't create a new User" do
            expect { authenticate }.not_to(change { User.where(:userid => 'bob').count }.from(0))
          end

          it "immediately marks the task as errored" do
            task_id = authenticate
            task = MiqTask.find(task_id)
            expect(task.status).to eq('Error')
            expect(MiqTask.status_error?(task.status)).to be_truthy
          end
        end

        context "when fullname is blank" do
          let(:username) { 'betty' }
          let(:headers) do
            super().merge('X-Remote-User-FullName'  => '',
                          'X-Remote-User-FirstName' => 'Betty',
                          'X-Remote-User-LastName'  => 'Boop',
                          'X-Remote-User-Email'     => 'betty@example.com')
          end

          it "creates a new User with name set to FirstName + LastName" do
            expect { authenticate }.to(change { User.where(:name => 'Betty Boop').count }.from(0).to(1))
          end
        end

        context "when fullname, firstname and lastname are blank" do
          let(:username) { 'sam' }
          let(:headers) do
            super().merge('X-Remote-User-FullName'  => '',
                          'X-Remote-User-FirstName' => '',
                          'X-Remote-User-LastName'  => '',
                          'X-Remote-User-Email'     => 'sam@example.com')
          end

          it "creates a new User with the userid set to the UPN" do
            expect { authenticate }.to(change { User.where(:name => 'sam@example.com').count }.from(0).to(1))
          end
        end
      end

      describe ".user_attrs_from_external_directory_via_dbus" do
        before do
          require "dbus"
          sysbus = double('sysbus')
          ifp_service = double('ifp_service')
          ifp_object  = double('ifp_object')
          @ifp_interface = double('ifp_interface')

          allow(DBus).to receive(:system_bus).and_return(sysbus)
          allow(sysbus).to receive(:[]).with("org.freedesktop.sssd.infopipe").and_return(ifp_service)
          allow(ifp_service).to receive(:object).with("/org/freedesktop/sssd/infopipe").and_return(ifp_object)
          allow(ifp_object).to receive(:introspect)
          allow(ifp_object).to receive(:[]).with("org.freedesktop.sssd.infopipe").and_return(@ifp_interface)
        end

        it "should return nil for unspecified user" do
          expect(subject.send(:user_attrs_from_external_directory_via_dbus, nil)).to be_nil
        end

        it "should return user attributes hash for valid user" do
          requested_attrs = %w(mail givenname sn displayname domainname)

          jdoe_attrs = [{"mail"        => ["jdoe@example.com"],
                         "givenname"   => ["John"],
                         "sn"          => ["Doe"],
                         "displayname" => ["John Doe"],
                         "domainname"  => ["example.com"]}]

          expected_jdoe_attrs = {"mail"        => "jdoe@example.com",
                                 "givenname"   => "John",
                                 "sn"          => "Doe",
                                 "displayname" => "John Doe",
                                 "domainname"  => "example.com"}

          allow(@ifp_interface).to receive(:GetUserAttr).with('jdoe', requested_attrs).and_return(jdoe_attrs)

          expect(subject.send(:user_attrs_from_external_directory_via_dbus, 'jdoe')).to eq(expected_jdoe_attrs)
        end
      end
    end

    context "with a userid record in mixed case" do
      let!(:testuser_mixedcase) { FactoryBot.create(:user, :userid => 'TestUser') }
      let(:username) { 'testuser' }
      let(:headers) do
        super().merge('X-Remote-User-FullName' => 'Test User',
                      'X-Remote-User-Email'    => 'testuser@example.com')
      end

      context "using external authorization" do
        let(:config) { {:httpd_role => true} }

        it "records two successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_httpd',
            :userid  => 'testuser',
            :message => "User testuser successfully validated by External httpd",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_httpd',
            :userid  => 'testuser',
            :message => "Authentication successful for user testuser",
          )
          expect(AuditEvent).not_to receive(:failure)
          authenticate
        end
      end

      context "using a comma separated group list" do
        let(:config) { {:httpd_role => true} }
        let(:headers) do
          super().merge('X-Remote-User-Groups' => 'wibble@fqdn,bubble@fqdn')
        end
        let(:user_attrs) do
          { :username  => "testuser",
            :fullname  => "Test User",
            :firstname => "Alice",
            :lastname  => "Aardvark",
            :email     => "testuser@example.com",
            :domain    => "example.com" }
        end

        it "handles a comma separated grouplist" do
          expect(subject).to receive(:find_external_identity).with(username, user_attrs, ["wibble@fqdn", "bubble@fqdn"])
          authenticate
        end
      end

      context "when group names have escaped special characters" do
        let(:config) { {:httpd_role => true} }
        let(:headers) do
          super().merge('X-Remote-User-Groups' => CGI.escape('spécial_char@fqdn:moré@fqdn'))
        end
        let(:user_attrs) do
          { :username  => "testuser",
            :fullname  => "Test User",
            :firstname => "Alice",
            :lastname  => "Aardvark",
            :email     => "testuser@example.com",
            :domain    => "example.com" }
        end

        it "handles group names with escaped special characters" do
          expect(subject).to receive(:find_external_identity).with(username, user_attrs, ["spécial_char@fqdn", "moré@fqdn"])
          authenticate
        end
      end

      context "when there are no group names" do
        let(:config) { {:httpd_role => true} }
        let(:headers) do
          {
            'X-Remote-User'           => username,
            'X-Remote-User-FullName'  => 'Test User',
            'X-Remote-User-FirstName' => 'Alice',
            'X-Remote-User-LastName'  => 'Aardvark',
            'X-Remote-User-Email'     => 'testuser@example.com',
            'X-Remote-User-Domain'    => 'example.com',
            'X-Remote-User-Groups'    => nil,
          }
        end
        let(:user_attrs) do
          { :username  => "testuser",
            :fullname  => "Test User",
            :firstname => "Alice",
            :lastname  => "Aardvark",
            :email     => "testuser@example.com",
            :domain    => "example.com" }
        end

        it "handles nil group names" do
          expect(subject).to receive(:find_external_identity).with(username, user_attrs, [])
          authenticate
        end
      end
    end
  end
end
