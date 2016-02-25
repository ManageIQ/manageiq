require 'aws-sdk'

describe Authenticator::Amazon do
  AWS_ROOT_USER_KEY = 'aws_root_key'
  AWS_IAM_USER_KEY = 'aws_iam_key'

  subject { Authenticator::Amazon.new(config) }

  let(:local_user) { FactoryGirl.create(:user, :userid => username) }
  let(:username) { 'some_user' }
  let(:config) do
    {
      :amazon_role   => false,
      :amazon_key    => AWS_ROOT_USER_KEY,
      :amazon_secret => 'aws_secret_key',
    }
  end
  let(:describe_regions_response) do
    {
      :regions => [
        {:region_name => 'us-east-1'},
        {:region_name => 'us-west-1'},
      ]
    }
  end
  let(:aws_group_name) { 'group_on_aws' }
  let(:miq_group_name) { aws_group_name }

  def aws_allow_list_users!(resource)
    response = resource.client.stub_data(:get_user)
    resource.client.stub_responses(:list_users, :users => [response.user.to_h])
  end

  def aws_deny_list_users!(resource)
    resource.client.stub_responses(:list_users, 'AccessDenied')
  end

  def aws_get_user_is_root!(resource)
    response = resource.client.stub_data(
      :get_user,
      :user => {:arn => 'arn:aws:iam::123456789:root'}
    )
    resource.client.stub_responses(:get_user, response)
  end

  def aws_allow_get_user!(resource)
    response = resource.client.stub_data(:get_user).to_h
    resource.client.stub_responses(:get_user, response)
  end

  def aws_allow_list_keys!(resource)
    response = resource.client.stub_data(
      :list_access_keys,
      :access_key_metadata => [{:access_key_id => AWS_IAM_USER_KEY}]
    )
    resource.client.stub_responses(:list_access_keys, response)
  end

  def aws_allow_list_groups!(resource)
    response = resource.client.stub_data(:list_groups_for_user, :groups => [:group_name => aws_group_name])
    resource.client.stub_responses(:list_groups_for_user, response)
  end

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

    miq_group = FactoryGirl.create(:miq_group, :description => miq_group_name)
    allow(MiqLdap).to receive(:using_ldap?) { false }

    allow_any_instance_of(described_class).to receive(:aws_connect) do |_instance, access_key_id, _secret_access_key, service|
      service ||= :IAM
      resource = Aws.const_get(service.to_s)::Resource.new(:stub_responses => true)

      if resource.kind_of? Aws::IAM::Resource
        case access_key_id
        when AWS_ROOT_USER_KEY
          aws_get_user_is_root!(resource)
          aws_allow_list_groups!(resource)
          aws_allow_list_keys!(resource)
          aws_allow_list_users!(resource)
        when AWS_IAM_USER_KEY
          aws_allow_get_user!(resource)
          aws_deny_list_users!(resource)
        end
      end

      if resource.kind_of? Aws::EC2::Resource
        resource.client.stub_responses(:describe_regions, describe_regions_response)
      end

      resource
    end
  end

  describe '#uses_stored_password?' do
    it "is false" do
      expect(subject.uses_stored_password?).to be_falsey
    end
  end

  describe '#lookup_by_identity' do
    it "finds existing users" do
      expect(local_user.userid).to eq(username)
      expect(subject.lookup_by_identity(local_user.userid)).to eq(local_user)
    end

    it "doesn't create new users" do
      expect(subject.lookup_by_identity('bob')).not_to be
    end
  end

  describe '.validate_connection' do
    let(:config) { super().merge(:mode => 'amazon') }

    context "with aws root account" do
      it "succeeds" do
        result, errors = described_class.validate_connection(:authentication => config)
        expect(result).to be_truthy
        expect(errors).to eq({})
      end
    end

    context "with bad credentials" do
      # Aws::EC2::Errors::AuthFailure
      let(:describe_regions_response) { 'AuthFailure' }

      it "fails" do
        result, errors = described_class.validate_connection(:authentication => config)
        expect(result).not_to be
        expect(errors).to eq("authentication_amazon" => "Login failed due to a bad username or password.")
      end
    end

    context "with IAM credentials" do
      let(:config) { super().merge(:amazon_key => AWS_IAM_USER_KEY) }

      it "fails" do
        result, errors = described_class.validate_connection(:authentication => config)
        expect(result).not_to be
        expect(errors).to eq("authentication_amazon" => "Access key #{config[:amazon_key]} belongs to IAM user, not to the AWS account holder.")
      end
    end
  end

  describe '#authenticate' do
    def authenticate
      subject.authenticate(username, "some_password")
    end

    let(:username) { AWS_IAM_USER_KEY }

    context "without root credentials" do
      let(:config) { super().merge(:amazon_key => AWS_IAM_USER_KEY) }

      it "fails" do
        expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
      end

      it "logs why we failed" do
        expect($log).to receive(:error).with(/belongs to IAM user/)
        authenticate rescue nil
      end
    end

    context "with correct password" do
      let!(:local_user) { FactoryGirl.create(:user, :userid => username) }

      context "using local authorization" do
        it "succeeds" do
          expect(authenticate).to eq(local_user)
        end

        it "records two successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_amazon',
            :userid  => username,
            :message => "User #{username} successfully validated by Amazon IAM",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_amazon',
            :userid  => username,
            :message => "Authentication successful for user #{username}",
          )
          expect(AuditEvent).not_to receive(:failure)
          authenticate
        end

        it "updates lastlogon" do
          expect(-> { authenticate }).to change { local_user.reload.lastlogon }
        end

        context "with no corresponding Amazon IAM user" do
          let(:username) { 'some_key_not_on_IAM' }
          it "fails" do
            expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
          end
        end
      end

      context "using external authorization" do
        let(:config) { super().merge(:amazon_role => true) }
        before(:each) { allow(subject).to receive(:authorize_queue?).and_return(false) }

        it "enqueues an authorize task" do
          expect(subject).to receive(:authorize_queue).and_return(123)
          expect(authenticate).to eq(123)
        end

        it "records two successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_amazon',
            :userid  => username,
            :message => "User #{username} successfully validated by Amazon IAM",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_amazon',
            :userid  => username,
            :message => "Authentication successful for user #{username}",
          )
          expect(AuditEvent).not_to receive(:failure)
          authenticate
        end

        it "updates lastlogon" do
          expect(-> { authenticate }).to change { local_user.reload.lastlogon }
        end

        it "immediately completes the task" do
          task_id = authenticate
          task = MiqTask.find(task_id)
          expect(User.find_by_userid(task.userid)).to eq(local_user)
        end

        context "with no corresponding Amazon IAM user" do
          let(:username) { 'some_key_not_on_IAM' }
          it "fails" do
            expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
          end
        end
      end

      context "without EC2 permissions" do
        # Aws::EC2::Errors::UnauthorizedOperation
        let(:describe_regions_response) { 'UnauthorizedOperation' }
        it "succeeds" do
          expect(authenticate).to eq(local_user)
        end
      end

      context "without IAM permissions" do
        it "succeeds" do
          expect(authenticate).to eq(local_user)
        end
      end

      context "with signature mismatch" do
        let(:describe_regions_response) { 'SignatureDoesNotMatch' }
        it "fails" do
          # Aws::EC2::Errors::SignatureDoesNotMatch
          expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
        end
      end

      context "with root account credentials" do
        let(:username) { AWS_ROOT_USER_KEY }

        it "fails" do
          expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
        end

        it "logs why we failed" do
          expect($log).to receive(:error).with(/belongs to the AWS account holder/)
          authenticate rescue nil
        end
      end
    end

    context "with bad password" do
      let(:username) { 'not_able_to_auth_on_aws' }

      it "fails" do
        expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
      end

      it "records one failing audit entry" do
        expect(AuditEvent).to receive(:failure).with(
          :event   => 'authenticate_amazon',
          :userid  => username,
          :message => "Authentication failed for userid #{username}",
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
        expect(-> { authenticate rescue nil }).not_to change { local_user.reload.lastlogon }
      end
    end

    context "with unknown username" do
      let(:username) { AWS_IAM_USER_KEY }

      context "with bad password" do
        # Aws::EC2::Errors::AuthFailure
        let(:describe_regions_response) { 'AuthFailure' }

        it "fails" do
          expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
        end

        it "records one failing audit entry" do
          expect(AuditEvent).to receive(:failure).with(
            :event   => 'authenticate_amazon',
            :userid  => username,
            :message => "Authentication failed for userid #{username}",
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
            :event   => 'authenticate_amazon',
            :userid  => username,
            :message => "User #{username} successfully validated by Amazon IAM",
          )
          expect(AuditEvent).to receive(:failure).with(
            :event   => 'authenticate_amazon',
            :userid  => username,
            :message => "User #{username} authenticated but not defined in EVM",
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
        let(:config) { super().merge(:amazon_role => true) }
        before(:each) { allow(subject).to receive(:authorize_queue?).and_return(false) }

        it "enqueues an authorize task" do
          expect(subject).to receive(:authorize_queue).and_return(123)
          expect(authenticate).to eq(123)
        end

        it "records two successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_amazon',
            :userid  => username,
            :message => "User #{username} successfully validated by Amazon IAM",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_amazon',
            :userid  => username,
            :message => "Authentication successful for user #{username}",
          )
          expect(AuditEvent).not_to receive(:failure)
          authenticate
        end

        it "immediately completes the task" do
          task_id = authenticate
          task = MiqTask.find(task_id)
          user = User.find_by_userid(task.userid)
          expect(user.userid).to eq(username)
          expect(user.email).to be_nil
        end

        it "creates a new User" do
          expect(-> { authenticate }).to change { User.where(:userid => username).count }.from(0).to(1)
        end

        context "with no matching groups" do
          let(:miq_group_name) { 'not_aws_group' }

          it "enqueues an authorize task" do
            expect(subject).to receive(:authorize_queue).and_return(123)
            expect(authenticate).to eq(123)
          end

          it "records two successful audit entries plus one failure" do
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authenticate_amazon',
              :userid  => username,
              :message => "User #{username} successfully validated by Amazon IAM",
            )
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authenticate_amazon',
              :userid  => username,
              :message => "Authentication successful for user #{username}",
            )
            expect(AuditEvent).to receive(:failure).with(
              :event   => 'authorize',
              :userid  => username,
              :message => "Authentication failed for userid #{username}, unable to match user's group membership to an EVM role",
            )
            authenticate
          end

          it "doesn't create a new User" do
            expect(-> { authenticate }).not_to change { User.where(:userid => username).count }.from(0)
          end

          it "immediately marks the task as errored" do
            task_id = authenticate
            task = MiqTask.find(task_id)
            expect(task.status).to eq('Error')
            expect(MiqTask.status_error?(task.status)).to be_truthy
          end
        end
      end
    end
  end
end
