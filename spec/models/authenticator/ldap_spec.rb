describe Authenticator::Ldap do
  subject { Authenticator::Ldap.new(config) }
  let!(:alice) { FactoryGirl.create(:user, :userid => 'alice') }
  let(:config) do
    {
      :ldap_role => false,
      :bind_dn   => 'rootdn',
      :bind_pwd  => 'verysecret',
    }
  end

  let(:fake_ldap) do
    Class.new do
      def initialize(user_data)
        @user_data = user_data
      end

      def bind(username, password)
        @user_data[username].try(:[], :password) == password
      end

      def fqusername(username)
        username.delete('X')
      end

      def get_user_object(username)
        @user_data[username]
      end

      def get_memberships(user_obj, _max_depth)
        user_obj.fetch(:groups)
      end

      def get_attr(user_obj, attr_name)
        user_obj.fetch(attr_name)
      end

      def normalize(dn)
        dn
      end
    end
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
    FactoryGirl.create(:miq_group, :description => 'wibble')
    FactoryGirl.build_stubbed(:miq_group, :description => 'wobble')
  end

  let(:user_data) do
    {
      'rootdn' => {:password => 'verysecret'},
      'alice'  => alice_data,
      'bob'    => bob_data,
      'betty'  => betty_data,
      'sam'    => sam_data,
    }
  end
  let(:alice_data) do
    {
      :userprincipalname => 'alice',
      :password          => 'secret',
      :displayname       => 'Alice Aardvark',
      :givenname         => 'Alice',
      :sn                => 'Aardvark',
      :mail              => 'alice@example.com',
      :groups            => %w(wibble bubble),
    }
  end
  let(:bob_data) do
    {
      :userprincipalname => 'bob',
      :password          => 'secret',
      :displayname       => 'Bob Builderson',
      :givenname         => 'Bob',
      :sn                => 'Builderson',
      :mail              => 'bob@example.com',
      :groups            => %w(wibble bubble),
    }
  end
  let(:betty_data) do
    {
      :userprincipalname => 'betty',
      :password          => 'secret',
      :displayname       => nil,
      :givenname         => 'Betty',
      :sn                => 'Builderson',
      :mail              => 'betty@example.com',
      :groups            => %w(wibble bubble),
    }
  end
  let(:sam_data) do
    {
      :userprincipalname => 'sam',
      :password          => 'secret',
      :displayname       => nil,
      :givenname         => nil,
      :sn                => nil,
      :mail              => 'sam@example.com',
      :groups            => %w(wibble bubble),
    }
  end

  before do
    allow(MiqLdap).to receive(:new) { fake_ldap.new(user_data) }
    allow(MiqLdap).to receive(:using_ldap?) { true }
  end

  describe '#uses_stored_password?' do
    it "is false" do
      expect(subject.uses_stored_password?).to be_falsey
    end
  end

  describe ".user_authorizable_without_authentication?" do
    it "is true" do
      expect(subject.user_authorizable_without_authentication?).to be_truthy
    end
  end

  describe '#lookup_by_identity' do
    it "finds existing users" do
      expect(subject.lookup_by_identity('alice')).to eq(alice)
    end

    context "using internal authorization" do
      it "refuses users that exist in LDAP" do
        expect(subject.lookup_by_identity('bob')).to eq(nil)
      end

      it "refuses users that don't exist in LDAP" do
        expect(subject.lookup_by_identity('carol')).to eq(nil)
      end
    end

    context "not getting groups from LDAP" do
      let(:config) { super().merge(:ldap_role => false) }

      context "with a default group" do
        let(:config) { super().merge(:default_group_for_users => 'wibble') }

        it "creates new users from LDAP" do
          expect(subject.lookup_by_identity('bob')).to eq(nil)
          expect(subject.autocreate_user('bob').name).to eq('Bob Builderson')
        end
      end

      context "with no default group" do
        let(:config) { super().merge(:default_group_for_users => '') }
        it "refuses LDAP users" do
          expect(subject.autocreate_user('bob')).to eq(nil)
        end
      end

      context "with no corresponding LDAP user" do
        let(:alice_data) { nil }

        it "still finds the user" do
          expect(subject.lookup_by_identity('alice')).to eq(alice)
        end
      end

      it "refuses users that don't exist in LDAP" do
        expect(subject.lookup_by_identity('carol')).to eq(nil)
      end
    end
  end

  describe '#authenticate' do
    def authenticate
      subject.authenticate(username, password)
    end

    let(:username) { 'alice' }
    let(:password) { 'secret' }

    context "when using LDAP" do
      let(:config) { super().merge(:ldap_role => true) }

      before do
        allow(MiqQueue).to receive(:put)
        allow(MiqTask).to receive(:create).and_return(double(:id => :return_value))
      end

      it "encrypts password for queuing" do
        expect(subject).to receive(:encrypt_ldap_password)
        authenticate
      end
    end

    context "with correct password" do
      context "using local authorization" do
        it "succeeds" do
          expect(authenticate).to eq(alice)
        end

        it "records two successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_ldap',
            :userid  => 'alice',
            :message => "User alice successfully validated by LDAP",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_ldap',
            :userid  => 'alice',
            :message => "Authentication successful for user alice",
          )
          expect(AuditEvent).not_to receive(:failure)
          authenticate
        end

        it "updates lastlogon" do
          expect(-> { authenticate }).to change { alice.reload.lastlogon }
        end

        context "with no corresponding LDAP user" do
          let(:alice_data) { nil }
          it "fails" do
            expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
          end
        end
      end

      context "using external authorization" do
        let(:config) { super().merge(:ldap_role => true) }
        before { allow(subject).to receive(:authorize_queue?).and_return(false) }

        context "with an LDAP user" do
          before { allow(subject).to receive(:run_task) }

          it "decrypts password after dequeuing" do
            expect(subject).to receive(:decrypt_ldap_password)
            subject.authorize(22, 'alice', 1)
          end
        end

        it "enqueues an authorize task" do
          expect(subject).to receive(:authorize_queue).and_return(123)
          expect(authenticate).to eq(123)
        end

        it "records three successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_ldap',
            :userid  => 'alice',
            :message => "User alice successfully validated by LDAP",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_ldap',
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

        context "new user creation" do
          let(:username) { 'bob' }
          it "logs the success" do
            authenticate
            expect(MiqQueue.count).to eq 1
            expect(MiqQueue.first.args.last(2)).to eq(
              ["user_created",
                {
                  :event_details => "User creation successful for User: Bob Builderson with ID: bob"
                }
              ]
            )
          end
        end

        context "with no corresponding LDAP user" do
          let(:alice_data) { nil }
          it "fails" do
            expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
          end
        end
      end
    end

    context "with bad password" do
      let(:password) { 'incorrect' }

      it "fails" do
        expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
      end

      it "records one failing audit entry" do
        expect(AuditEvent).to receive(:failure).with(
          :event   => 'authenticate_ldap',
          :userid  => 'alice',
          :message => "Authentication failed for userid alice",
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
    end

    context "with unknown username" do
      let(:username) { 'bob' }

      context "with bad password" do
        let(:password) { 'incorrect' }

        it "fails" do
          expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
        end

        it "records one failing audit entry" do
          expect(AuditEvent).to receive(:failure).with(
            :event   => 'authenticate_ldap',
            :userid  => 'bob',
            :message => "Authentication failed for userid bob",
          )
          expect(AuditEvent).not_to receive(:success)
          authenticate rescue nil
        end
        it "logs the failure" do
          allow($log).to receive(:warn).with(/Audit/)
          expect($log).to receive(:warn).with(/Authentication failed$/)
          authenticate rescue nil
        end
      end

      context "using local authorization" do
        it "fails" do
          expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError)
        end

        it "records one successful and one failing audit entry" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_ldap',
            :userid  => 'bob',
            :message => "User bob successfully validated by LDAP",
          )
          expect(AuditEvent).to receive(:failure).with(
            :event   => 'authenticate_ldap',
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

        context "with a default group configured" do
          let(:config) { super().merge(:default_group_for_users => 'wibble') }

          it "succeeds" do
            expect(authenticate).to be_a(User)
          end

          it "records two successful audit entries" do
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authenticate_ldap',
              :userid  => 'bob',
              :message => "User bob successfully validated by LDAP",
            )
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authenticate_ldap',
              :userid  => 'bob',
              :message => "Authentication successful for user bob",
            )
            expect(AuditEvent).not_to receive(:failure)
            authenticate
          end

          it "creates a new User" do
            expect(-> { authenticate }).to change { User.where(:userid => 'bob').count }.from(0).to(1)
          end
        end

        context "with a non-existant default group configured" do
          let(:config) { super().merge(:default_group_for_users => 'bubble') }

          it "fails" do
            expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError)
          end
        end
      end

      context "using external authorization" do
        let(:config) { super().merge(:ldap_role => true) }
        before { allow(subject).to receive(:authorize_queue?).and_return(false) }

        it "enqueues an authorize task" do
          expect(subject).to receive(:authorize_queue).and_return(123)
          expect(authenticate).to eq(123)
        end

        it "records three successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_ldap',
            :userid  => 'bob',
            :message => "User bob successfully validated by LDAP",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authorize',
            :userid  => 'bob',
            :message => "User creation successful for User: Bob Builderson with ID: bob",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_ldap',
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
          let(:bob_data) { super().merge(:groups => %w(bubble trouble)) }

          it "enqueues an authorize task" do
            expect(subject).to receive(:authorize_queue).and_return(123)
            expect(authenticate).to eq(123)
          end

          it "records three successful audit entries plus one failure" do
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authenticate_ldap',
              :userid  => 'bob',
              :message => "User bob successfully validated by LDAP",
            )
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authorize',
              :userid  => 'bob',
              :message => "User creation successful for User: Bob Builderson with ID: bob",
            )
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authenticate_ldap',
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

        context "when display name is blank" do
          let(:username) { 'betty' }

          it "creates a new User with name set to givenname + sn" do
            expect(-> { authenticate }).to change { User.where(:name => 'Betty Builderson').count }.from(0).to(1)
          end
        end

        context "when display name, givenname and sn are blank" do
          let(:username) { 'sam' }

          it "creates a new User with name set to the userid" do
            expect(-> { authenticate }).to change { User.where(:name => 'sam').count }.from(0).to(1)
          end
        end
      end
    end
  end
end
