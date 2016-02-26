require_relative 'aws_helper'

describe ManageIQ::Providers::Amazon::CloudManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('ec2')
  end

  it ".description" do
    expect(described_class.description).to eq('Amazon EC2')
  end

  describe ".metrics_collector_queue_name" do
    it "returns the correct queue name" do
      worker_queue = ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker.default_queue_name
      expect(described_class.metrics_collector_queue_name).to eq(worker_queue)
    end
  end

  describe ".discover" do
    let(:ec2_user) { "0123456789ABCDEFGHIJ" }
    let(:ec2_pass) { "ABCDEFGHIJKLMNO1234567890abcdefghijklmno" }
    subject { described_class.discover(ec2_user, ec2_pass) }

    before do
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)
    end

    around do |example|
      with_aws_stubbed(:ec2 => stub_responses) do
        example.run
      end
    end

    def assert_region(ems, name)
      expect(ems.name).to eq(name)
      expect(ems.provider_region).to eq(name.split(" ").first)
      expect(ems.auth_user_pwd).to eq([ec2_user, ec2_pass])
    end

    def assert_region_on_another_account(ems, name)
      expect(ems.name).to eq(name)
      expect(ems.provider_region).to eq(name.split(" ").first)
      default_auth = FactoryGirl.build(:authentication)
      expect(ems.auth_user_pwd).to eq([default_auth.userid, default_auth.password])
    end

    context "on greenfield amazon" do
      let(:stub_responses) do
        {
          :describe_regions => {
            :regions => [
              {:region_name => 'us-east-1'},
              {:region_name => 'us-west-1'},
            ]
          }
        }
      end

      it "with no existing records only creates default ems" do
        expect(subject.count).to eq(1)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
        expect(emses.count).to eq(1)
        assert_region(emses[0], "us-east-1")
      end
    end

    context "on amazon with two populated regions" do
      let(:stub_responses) do
        {
          :describe_regions => {
            :regions => [
              {:region_name => 'us-east-1'},
              {:region_name => 'us-west-1'},
            ]
          },
          :describe_instances => {
            :reservations => [
              {
                :instances => [
                  {:instance_id => "id-1"},
                  {:instance_id => "id-2"},
                ]
              }
            ]
          }
        }
      end

      it "with no existing records" do
        expect(subject.count).to eq(2)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
        expect(emses.count).to eq(2)
        assert_region(emses[0], "us-east-1")
        assert_region(emses[1], "us-west-1")
      end

      it "with some existing records" do
        FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-west-1", :provider_region => "us-west-1")

        expect(subject.count).to eq(1)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
        expect(emses.count).to eq(2)
        assert_region(emses[0], "us-east-1")
        assert_region(emses[1], "us-west-1")
      end

      it "with all existing records" do
        FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-east-1", :provider_region => "us-east-1")
        FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-west-1", :provider_region => "us-west-1")

        expect(subject.count).to eq(0)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
        expect(emses.count).to eq(2)
        assert_region(emses[0], "us-east-1")
        assert_region(emses[1], "us-west-1")
      end

      context "with records on other account" do
        def create_ems_on_other_account(name)
          FactoryGirl.create(:ems_amazon_with_authentication_on_other_account,
                             :name            => name,
                             :provider_region => "us-west-1")
        end

        it "with the same name" do
          create_ems_on_other_account("us-west-1")
          expect(subject.count).to eq(2)

          emses = ManageIQ::Providers::Amazon::CloudManager.order(:name).includes(:authentications)
          expect(emses.count).to eq(3)
          assert_region(emses[0], "us-east-1")
          assert_region_on_another_account(emses[1], "us-west-1")
          assert_region(emses[2], "us-west-1 #{ec2_user}")
        end

        it "with the same name and backup name" do
          create_ems_on_other_account("us-west-1")
          create_ems_on_other_account("us-west-1 #{ec2_user}")

          expect(subject.count).to eq(2)

          emses = ManageIQ::Providers::Amazon::CloudManager.order(:name).includes(:authentications)
          expect(emses.count).to eq(4)
          assert_region(emses[0], "us-east-1")
          assert_region_on_another_account(emses[1], "us-west-1")
          assert_region_on_another_account(emses[2], "us-west-1 #{ec2_user}")
          assert_region(emses[3], "us-west-1 1")
        end

        it "with the same name, backup name, and secondary backup name" do
          create_ems_on_other_account("us-west-1")
          create_ems_on_other_account("us-west-1 #{ec2_user}")
          create_ems_on_other_account("us-west-1 1")

          expect(subject.count).to eq(2)

          emses = ManageIQ::Providers::Amazon::CloudManager.order(:name).includes(:authentications)
          expect(emses.count).to eq(5)
          assert_region(emses[0], "us-east-1")
          assert_region_on_another_account(emses[1], "us-west-1")
          assert_region_on_another_account(emses[2], "us-west-1 #{ec2_user}")
          assert_region_on_another_account(emses[3], "us-west-1 1")
          assert_region(emses[4], "us-west-1 2")
        end
      end
    end
  end

  it "#description" do
    ems = FactoryGirl.build(:ems_amazon, :provider_region => "us-east-1")
    expect(ems.description).to eq("US East (Northern Virginia)")

    ems = FactoryGirl.build(:ems_amazon, :provider_region => "us-west-1")
    expect(ems.description).to eq("US West (Northern California)")
  end

  context "validates_uniqueness_of" do
    it "name" do
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_1", :provider_region => "us-east-1") }.to_not raise_error
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_1", :provider_region => "us-east-1") }.to     raise_error(ActiveRecord::RecordInvalid)
    end

    it "blank region" do
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_1", :provider_region => "") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "nil region" do
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_1", :provider_region => nil) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "duplicate provider_region" do
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_1", :provider_region => "us-east-1") }.to_not raise_error
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_2", :provider_region => "us-east-1") }.to_not raise_error
    end
  end

  context "translate_exception" do
    before :each do
      @ems = FactoryGirl.build(:ems_amazon, :provider_region => "us-east-1")

      creds = {:default => {:userid => "fake_user", :password => "fake_password"}}
      @ems.update_authentication(creds, :save => false)
    end

    it "preserves and logs message for unknown exceptions" do
      allow(@ems).to receive(:with_provider_connection).and_raise(StandardError, "unlikely")
      expect($log).to receive(:error).with(/unlikely/)
      expect { @ems.verify_credentials }.to raise_error(MiqException::MiqHostError, /Unexpected.*unlikely/)
    end

    it "handles SignatureDoesNotMatch" do
      exception = Aws::EC2::Errors::SignatureDoesNotMatch.new(:no_context, :no_message)
      allow(@ems).to receive(:with_provider_connection).and_raise(exception)
      expect { @ems.verify_credentials }.to raise_error(MiqException::MiqHostError, /Signature.*match/)
    end

    it "handles AuthFailure" do
      exception = Aws::EC2::Errors::AuthFailure.new(:no_context, :no_message)
      allow(@ems).to receive(:with_provider_connection).and_raise(exception)
      expect { @ems.verify_credentials }.to raise_error(MiqException::MiqHostError, /Login failed/)
    end

    it "handles MissingCredentialsErrror" do
      allow(@ems).to receive(:with_provider_connection).and_raise(Aws::Errors::MissingCredentialsError)
      expect { @ems.verify_credentials }.to raise_error(MiqException::MiqHostError, /Missing credentials/i)
    end
  end

  context "#orchestration_template_validate" do
    def with_aws_stubbed(stub_responses_per_service)
      stub_responses_per_service.each do |service, stub_responses|
        raise "Aws.config[#{service}][:stub_responses] already set" if Aws.config.fetch(service, {})[:stub_responses]
        Aws.config[service] ||= {}
        Aws.config[service][:stub_responses] = stub_responses
      end
      yield
    ensure
      stub_responses_per_service.keys.each do |service|
        Aws.config[service].delete(:stub_responses)
      end
    end

    it "validates a correct template" do
      template = FactoryGirl.create(:orchestration_template_cfn_with_content)
      stubbed_aws = {:validate_template => {}}
      with_aws_stubbed(:cloudformation => stubbed_aws) do
        ems = FactoryGirl.create(:ems_amazon_with_authentication)
        expect(ems.orchestration_template_validate(template)).to be_nil
      end
    end

    it "returns an error string for an incorrect template" do
      template      = FactoryGirl.create(:orchestration_template_cfn_with_content)
      stubbed_aws   = {:validate_template => 'ValidationError'}
      with_aws_stubbed(:cloudformation => stubbed_aws) do
        ems = FactoryGirl.create(:ems_amazon_with_authentication)
        expect(ems.orchestration_template_validate(template)).to eq('stubbed-response-error-message')
      end
    end
  end
end
