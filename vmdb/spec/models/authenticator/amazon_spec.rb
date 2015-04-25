require "spec_helper"
require "aws-sdk"

describe Authenticator::Amazon do
  subject { Authenticator::Amazon.new(config) }
  let!(:alice) { FactoryGirl.create(:user, :userid => 'alice') }
  let(:config) do
    {
      :amazon_role   => false,
      :amazon_key    => 'awskey',
      :amazon_secret => 'awssecret',
    }
  end

  class FakeAmazon
    def initialize(user_data, *connect_args)
      @user_data = user_data
      _connect *connect_args
    end

    def _connect(username, password, service = nil)
      if @user_data[username] && @user_data[username][:password] == password
        @user = username
      else
        raise AWS::EC2::Errors::AuthFailure
      end
    end

    def regions
      []
    end

    def users
      @user_data.reject { |k, _v| k =~ /aws/ }.map { |k, v| FakeUser.new(k, v) }
    end

    def client
      iam_username =
        case @user_data[@user][:iam]
        when false
          nil
        when :denied
          raise AWS::IAM::Errors::AccessDenied
        else
          @user
        end

      Object.new.tap do |obj|
        class << obj
          attr_accessor :username
          def get_user
            {:user => {:user_name => username}}
          end
        end
        obj.username = iam_username
      end
    end

    class FakeUser < Struct.new(:username, :data)
      def name
        data[:name]
      end

      def access_keys
        data[:access_keys].map { |key| FakeKey.new(key) }
      end

      def groups
        data[:groups].map { |group| FakeGroup.new(group) }
      end
    end

    class FakeKey < Struct.new(:id)
    end

    class FakeGroup < Struct.new(:name)
    end
  end

  before(:each) do
    # If anything goes looking for the currently configured
    # Authenticator during any of these tests, we'd really rather they
    # found the one we're working on.
    #
    # This specifically comes up when we auto-create a new user from an
    # external auth system: they get saved without a password, so User's
    # dummy_password_for_external_auth hook runs, and it needs to ask
    # Authenticator#password? whether it's allowed to do anything.

    allow(User).to receive(:authenticator).and_return(subject)
  end

  before(:each) do
    wibble = FactoryGirl.create(:miq_group, :description => 'wibble')
    wobble = FactoryGirl.build_stubbed(:miq_group, :description => 'wobble')

    allow(MiqServer).to receive(:my_server).and_return(
      double(:my_server, :permitted_groups => [wibble, wobble])
    )
  end

  let(:user_data) do
    {
      'awskey' => {:password => 'awssecret', :iam => false},
      'alice'  => alice_data,
      'bob'    => bob_data,
    }
  end
  let(:alice_data) do
    {
      :name        => 'Alice Aardvark',
      :password    => 'secret',
      :access_keys => %w(alice),
      :groups      => %w(wibble bubble),
    }
  end
  let(:bob_data) do
    {
      :name        => 'Bob Builderson',
      :password    => 'secret',
      :access_keys => %w(bob),
      :groups      => %w(wibble bubble),
    }
  end

  before(:each) do
    allow_any_instance_of(described_class).to receive(:aws_connect) { |*args| FakeAmazon.new(user_data, *args) }
  end

  its(:password?) { should be_false }

  describe '#lookup_by_identity' do
    it "finds existing users" do
      expect(subject.lookup_by_identity('alice')).to eq(alice)
    end

    it "doesn't create new users" do
      expect(subject.lookup_by_identity('bob')).not_to be
    end
  end

  describe '.validate_connection' do
    let(:config) { super().merge(:mode => 'amazon') }

    context "with valid details" do
      it "succeeds" do
        result, errors = described_class.validate_connection(:authentication => config)
        expect(result).to be
        expect(errors).to eq({})
      end
    end

    context "with bad credentials" do
      let(:config) { super().merge(:amazon_secret => 'incorrect') }

      it "fails" do
        result, errors = described_class.validate_connection(:authentication => config)
        expect(result).not_to be
        expect(errors).to eq("authentication_amazon" => "Login failed due to a bad username or password.")
      end
    end

    context "with IAM credentials" do
      let(:config) { super().merge(:amazon_key => 'alice', :amazon_secret => 'secret') }

      it "fails" do
        result, errors = described_class.validate_connection(:authentication => config)
        expect(result).not_to be
        expect(errors).to eq("authentication_amazon" => "Access key alice belongs to IAM user, not to the AWS account holder.")
      end
    end
  end

  describe '#authenticate' do
    def authenticate
      subject.authenticate(username, password)
    end

    let(:username) { 'alice' }
    let(:password) { 'secret' }

    context "without root credentials" do
      let(:config) { super().merge(:amazon_key => 'alice', :amazon_secret => 'secret') }

      it "fails" do
        expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
      end

      it "logs why we failed" do
        expect($log).to receive(:error).with(/belongs to IAM user/)
        authenticate rescue nil
      end
    end

    context "with correct password" do
      context "using local authorization" do
        it "succeeds" do
          expect(authenticate).to eq(alice)
        end

        it "records two successful audit entries" do
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_amazon',
            :userid  => 'alice',
            :message => "User alice successfully validated by Amazon IAM",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_amazon',
            :userid  => 'alice',
            :message => "Authentication successful for user alice",
          )
          expect(AuditEvent).not_to receive(:failure)
          authenticate
        end

        it "updates lastlogon" do
          expect(-> { authenticate }).to change { alice.reload.lastlogon }
        end

        context "with no corresponding Amazon IAM user" do
          let(:alice_data) { nil }
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
            :userid  => 'alice',
            :message => "User alice successfully validated by Amazon IAM",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_amazon',
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

        context "with no corresponding Amazon IAM user" do
          let(:alice_data) { nil }
          it "fails" do
            expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
          end
        end
      end

      context "without EC2 permissions" do
        it "succeeds" do
          allow_any_instance_of(FakeAmazon).to receive(:regions) { raise AWS::EC2::Errors::UnauthorizedOperation }
          expect(authenticate).to eq(alice)
        end
      end

      context "without IAM permissions" do
        let(:alice_data) { super().merge(:iam => :denied) }
        it "succeeds" do
          expect(authenticate).to eq(alice)
        end
      end

      context "with signature mismatch" do
        it "fails" do
          allow_any_instance_of(FakeAmazon).to receive(:regions) { raise AWS::EC2::Errors::SignatureDoesNotMatch }
          expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
        end
      end

      context "with root account credentials" do
        let(:username) { 'awskey' }
        let(:password) { 'awssecret' }

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
      let(:password) { 'incorrect' }

      it "fails" do
        expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
      end

      it "records one failing audit entry" do
        expect(AuditEvent).to receive(:failure).with(
          :event   => 'authenticate_amazon',
          :userid  => 'alice',
          :message => "Authentication failed for userid alice",
        )
        expect(AuditEvent).not_to receive(:success)
        authenticate rescue nil
      end
      it "logs the failure" do
        allow($log).to receive(:warn).with(/Audit/)
        expect($log).to receive(:warn).with("Authentication failed")
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
            :event   => 'authenticate_amazon',
            :userid  => 'bob',
            :message => "Authentication failed for userid bob",
          )
          expect(AuditEvent).not_to receive(:success)
          authenticate rescue nil
        end
        it "logs the failure" do
          allow($log).to receive(:warn).with(/Audit/)
          expect($log).to receive(:warn).with("Authentication failed")
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
            :userid  => 'bob',
            :message => "User bob successfully validated by Amazon IAM",
          )
          expect(AuditEvent).to receive(:failure).with(
            :event   => 'authenticate_amazon',
            :userid  => 'bob',
            :message => "User bob authenticated but not defined in EVM",
          )
          authenticate rescue nil
        end

        it "logs the failure" do
          allow($log).to receive(:warn).with(/Audit/)
          expect($log).to receive(:warn).with("User authenticated but not defined in EVM, please contact your EVM administrator")
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
            :userid  => 'bob',
            :message => "User bob successfully validated by Amazon IAM",
          )
          expect(AuditEvent).to receive(:success).with(
            :event   => 'authenticate_amazon',
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
          expect(user.email).to be_nil
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

          it "records two successful audit entries plus one failure" do
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authenticate_amazon',
              :userid  => 'bob',
              :message => "User bob successfully validated by Amazon IAM",
            )
            expect(AuditEvent).to receive(:success).with(
              :event   => 'authenticate_amazon',
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
            expect(MiqTask.status_error?(task.status)).to be_true
          end
        end
      end
    end
  end
end
