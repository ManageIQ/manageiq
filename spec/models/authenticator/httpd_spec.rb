describe Authenticator::Httpd do
  subject { Authenticator::Httpd.new(config) }
  let!(:alice) { FactoryGirl.create(:user, :userid => 'alice') }
  let(:config) { {:httpd_role => false} }

  before(:each) do
    # If anything goes looking for the currently configured
    # Authenticator during any of these tests, we'd really rather they
    # found the one we're working on.
    #
    # This specifically comes up when we auto-create a new user from an
    # external auth system: they get saved without a password, so User's
    # dummy_password_for_external_auth hook runs, and it needs to ask
    # Authenticator#uses_stored_password? whether it's allowed to do anything.

    allow(User).to receive(:authenticator).and_return(subject)
  end

  before(:each) do
    wibble = FactoryGirl.create(:miq_group, :description => 'wibble')
    wobble = FactoryGirl.create(:miq_group, :description => 'wobble')

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

  describe '#lookup_by_identity' do
    it "finds existing users" do
      expect(subject.lookup_by_identity('alice')).to eq(alice)
    end

    it "doesn't create new users" do
      expect(subject.lookup_by_identity('bob')).to be_nil
    end
  end

  describe '#authenticate' do
    def authenticate
      subject.authenticate(username, nil, request)
    end

    let(:request) do
      env = {}
      headers.each do |k, v|
        env["HTTP_#{k.upcase.tr '-', '_'}"] = v if v
      end
      ActionDispatch::Request.new(Rack::MockRequest.env_for("/", env))
    end

    let(:headers) do
      {
        'X-Remote-User'           => username,
        'X-Remote-User-FullName'  => 'Alice Aardvark',
        'X-Remote-User-FirstName' => 'Alice',
        'X-Remote-User-LastName'  => 'Aardvark',
        'X-Remote-User-Email'     => 'alice@example.com',
        'X-Remote-User-Groups'    => user_groups,
      }
    end

    let(:username) { 'alice' }
    let(:user_groups) { 'wibble@fqdn:bubble@fqdn' }

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
          expect(-> { authenticate }).to change { alice.reload.lastlogon }
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
          expect(-> { authenticate }).to change { alice.reload.lastlogon }
        end

        it "immediately completes the task" do
          task_id = authenticate
          task = MiqTask.find(task_id)
          expect(User.find_by_userid(task.userid)).to eq(alice)
        end
      end
    end

    context "with invalid user" do
      let(:headers) { super().except('X-Remote-User') }

      it "fails" do
        expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
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
        expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
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
        expect(-> { authenticate rescue nil }).not_to change { alice.reload.lastlogon }
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

    context "with unknown username" do
      let(:username) { 'bob' }
      let(:headers) do
        super().merge('X-Remote-User-FullName' => 'Bob Builderson',
                      'X-Remote-User-Email'    => 'bob@example.com')
      end

      context "using local authorization" do
        it "fails" do
          expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError)
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

        it "records two successful audit entries" do
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
          user = User.find_by_userid(task.userid)
          expect(user.name).to eq('Bob Builderson')
          expect(user.email).to eq('bob@example.com')
        end

        it "creates a new User" do
          expect(-> { authenticate }).to change { User.where(:userid => 'bob').count }.from(0).to(1)
        end

        context "with no matching groups" do
          let(:headers) { super().merge('X-Remote-User-Groups' => 'bubble:trouble') }

          it "enqueues an authorize task" do
            expect(subject).to receive(:authorize_queue).and_return(123)
            expect(authenticate).to eq(123)
          end

          it "records two successful audit entries plus one failure" do
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
              :message => "Authentication failed for userid bob, unable to match user's group membership to an EVM role",
            )
            authenticate
          end

          it "doesn't create a new User" do
            expect(-> { authenticate }).not_to change { User.where(:userid => 'bob').count }.from(0)
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
            expect(-> { authenticate }).to change { User.where(:name => 'Betty Boop').count }.from(0).to(1)
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

          it "creates a new User with name set to the userid" do
            expect(-> { authenticate }).to change { User.where(:name => 'sam').count }.from(0).to(1)
          end
        end
      end

      describe ".user_attrs_from_external_directory" do
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
          expect(subject.send(:user_attrs_from_external_directory, nil)).to be_nil
        end

        it "should return user attributes hash for valid user" do
          requested_attrs = %w(mail givenname sn displayname)

          jdoe_attrs = [{"mail"        => ["jdoe@example.com"],
                         "givenname"   => ["John"],
                         "sn"          => ["Doe"],
                         "displayname" => ["John Doe"]}]

          expected_jdoe_attrs = {"mail"        => "jdoe@example.com",
                                 "givenname"   => "John",
                                 "sn"          => "Doe",
                                 "displayname" => "John Doe"}

          allow(@ifp_interface).to receive(:GetUserAttr).with('jdoe', requested_attrs).and_return(jdoe_attrs)

          expect(subject.send(:user_attrs_from_external_directory, 'jdoe')).to eq(expected_jdoe_attrs)
        end
      end
    end
  end
end
