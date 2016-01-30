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

  context ".discover" do
    before do
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)
      @ec2_user = "0123456789ABCDEFGHIJ"
      @ec2_pass = "ABCDEFGHIJKLMNO1234567890abcdefghijklmno"
      @ec2_user2 = "testuser"
      @ec2_pass2 = "secret"
    end

    def recorded_discover(example)
      cassette_name = example.description.tr(" ", "_").delete(",").underscore
      VCR.use_cassette("#{described_class.name.underscore}/discover/#{cassette_name}") do
        ManageIQ::Providers::Amazon::CloudManager.discover(@ec2_user, @ec2_pass)
      end
    end

    def assert_region(ems, name)
      expect(ems.name).to eq(name)
      expect(ems.provider_region).to eq(name.split(" ").first)
      expect(ems.auth_user_pwd).to eq([@ec2_user, @ec2_pass])
    end

    def assert_region_on_another_account(ems, name)
      expect(ems.name).to eq(name)
      expect(ems.provider_region).to eq(name.split(" ").first)
      expect(ems.auth_user_pwd).to eq([@ec2_user2, @ec2_pass2])
    end

    it "with no existing records" do |example|
      found = recorded_discover(example)
      expect(found.count).to eq(2)

      emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
      expect(emses.count).to eq(2)
      assert_region(emses[0], "us-east-1")
      assert_region(emses[1], "us-west-1")
    end

    it "with no existing records and greenfield Amazon" do |example|
      found = recorded_discover(example)
      expect(found.count).to eq(1)

      emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
      expect(emses.count).to eq(1)
      assert_region(emses[0], "us-east-1")
    end

    it "with some existing records" do |example|
      FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-west-1", :provider_region => "us-west-1")

      found = recorded_discover(example)
      expect(found.count).to eq(1)

      emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
      expect(emses.count).to eq(2)
      assert_region(emses[0], "us-east-1")
      assert_region(emses[1], "us-west-1")
    end

    it "with all existing records" do |example|
      FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-east-1", :provider_region => "us-east-1")
      FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-west-1", :provider_region => "us-west-1")

      found = recorded_discover(example)
      expect(found.count).to eq(0)

      emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
      expect(emses.count).to eq(2)
      assert_region(emses[0], "us-east-1")
      assert_region(emses[1], "us-west-1")
    end

    context "with records from a different account" do
      it "with the same name" do |example|
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1", :provider_region => "us-west-1")

        found = recorded_discover(example)
        expect(found.count).to eq(2)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name).includes(:authentications)
        expect(emses.count).to eq(3)
        assert_region(emses[0], "us-east-1")
        assert_region_on_another_account(emses[1], "us-west-1")
        assert_region(emses[2], "us-west-1 #{@ec2_user}")
      end

      it "with the same name and backup name" do |example|
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1", :provider_region => "us-west-1")
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1 #{@ec2_user}", :provider_region => "us-west-1")

        found = recorded_discover(example)
        expect(found.count).to eq(2)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name).includes(:authentications)
        expect(emses.count).to eq(4)
        assert_region(emses[0], "us-east-1")
        assert_region_on_another_account(emses[1], "us-west-1")
        assert_region_on_another_account(emses[2], "us-west-1 #{@ec2_user}")
        assert_region(emses[3], "us-west-1 1")
      end

      it "with the same name, backup name, and secondary backup name" do |example|
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1", :provider_region => "us-west-1")
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1 #{@ec2_user}", :provider_region => "us-west-1")
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1 1", :provider_region => "us-west-1")

        found = recorded_discover(example)
        expect(found.count).to eq(2)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name).includes(:authentications)
        expect(emses.count).to eq(5)
        assert_region(emses[0], "us-east-1")
        assert_region_on_another_account(emses[1], "us-west-1")
        assert_region_on_another_account(emses[2], "us-west-1 #{@ec2_user}")
        assert_region_on_another_account(emses[3], "us-west-1 1")
        assert_region(emses[4], "us-west-1 2")
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
    before :all do
      require 'aws-sdk'
    end

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
end
