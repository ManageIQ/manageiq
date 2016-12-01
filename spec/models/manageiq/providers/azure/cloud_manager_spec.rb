require 'azure-armrest'
describe ManageIQ::Providers::Azure::CloudManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('azure')
  end

  it ".description" do
    expect(described_class.description).to eq('Azure')
  end

  it "does not create orphaned network_manager" do
    # When the cloud_manager is destroyed during a refresh the there will still be an instance
    # of the cloud_manager in the refresh worker. After the refresh we will try to save the cloud_manager
    # and because the network_manager was added before_validate it would create a new network_manager
    #
    # https://bugzilla.redhat.com/show_bug.cgi?id=1389459
    # https://bugzilla.redhat.com/show_bug.cgi?id=1393675
    ems = FactoryGirl.create(:ems_azure)
    same_ems = ExtManagementSystem.find(ems.id)

    ems.destroy
    expect(ExtManagementSystem.count).to eq(0)

    same_ems.save!
    expect(ExtManagementSystem.count).to eq(0)
  end

  context "#connectivity" do
    before do
      @e = FactoryGirl.create(:ems_azure)
      @e.authentications << FactoryGirl.create(:authentication, :userid => "klmnopqrst", :password => "1234567890")
      @e.azure_tenant_id = "abcdefghij"
    end

    context "#connect " do
      it "defaults" do
        expect(described_class).to receive(:raw_connect) do |clientid, clientkey, azure_tenant_id, subscription|
          expect(clientid).to eq("klmnopqrst")
          expect(clientkey).to eq("1234567890")
          expect(azure_tenant_id).to eq("abcdefghij")
          expect(subscription).to eq("fghij67890")
        end
        @e.subscription = "fghij67890"
        @e.connect
      end

      it "without subscription id" do
        expect(described_class).to receive(:raw_connect) do |clientid, clientkey, azure_tenant_id, subscription|
          expect(clientid).to eq("klmnopqrst")
          expect(clientkey).to eq("1234567890")
          expect(azure_tenant_id).to eq("abcdefghij")
          expect(subscription).to eq(nil)
        end
        @e.subscription = nil
        @e.connect
      end

      it "accepts overrides" do
        expect(described_class).to receive(:raw_connect) do |clientid, clientkey|
          expect(clientid).to eq("user")
          expect(clientkey).to eq("pass")
        end
        @e.connect(:user => "user", :pass => "pass")
      end
    end

    context "#validation" do
      it "handles unknown error" do
        allow(ManageIQ::Providers::Azure::CloudManager).to receive(:raw_connect).and_raise(StandardError)
        expect { @e.verify_credentials }.to raise_error(MiqException::MiqInvalidCredentialsError, /Unexpected response returned*/)
      end

      it "handles incorrect password" do
        allow(ManageIQ::Providers::Azure::CloudManager).to receive(:raw_connect).and_raise(
          Azure::Armrest::UnauthorizedException.new(nil, nil, nil))
        expect { @e.verify_credentials }.to raise_error(MiqException::MiqInvalidCredentialsError, /Incorrect credentials*/)
      end
    end
  end

  context ".discover" do
    AZURE_PREFIX = /Azure-(\w+)/

    before do
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)

      @client_id    = Rails.application.secrets.azure.try(:[], 'client_id') || 'AZURE_CLIENT_ID'
      @client_key   = Rails.application.secrets.azure.try(:[], 'client_secret') || 'AZURE_CLIENT_SECRET'
      @tenant_id    = Rails.application.secrets.azure.try(:[], 'tenant_id') || 'AZURE_TENANT_ID'
      @subscription = Rails.application.secrets.azure.try(:[], 'subscription_id') || 'AZURE_SUBSCRIPTION_ID'

      @alt_client_id    = 'testuser'
      @alt_client_key   = 'secret'
      @alt_tenant_id    = 'ABCDEFGHIJABCDEFGHIJ0123456789AB'
      @alt_subscription = '0123456789ABCDEFGHIJABCDEFGHIJKL'

      # A true thread may fail the test with VCR
      allow(Thread).to receive(:new) do |*args, &block|
        block.call(*args)
        Class.new do
          def join; end
        end.new
      end
    end

    after do
      ::Azure::Armrest::Configuration.clear_caches
    end

    def recorded_discover(example)
      cassette_name = example.description.tr(" ", "_").delete(",").underscore
      name = "#{described_class.name.underscore}/discover/#{cassette_name}"
      VCR.use_cassette(name, :allow_unused_http_interactions => true, :decode_compressed_response => true) do
        ManageIQ::Providers::Azure::CloudManager.discover(@client_id, @client_key, @tenant_id, @subscription)
      end
    end

    def assert_region(ems, name)
      expect(ems.name).to eq(name)
      expect(ems.provider_region).to eq(name[AZURE_PREFIX, 1])
      expect(ems.auth_user_pwd).to eq([@client_id, @client_key])
      expect(ems.azure_tenant_id).to eq(@tenant_id)
      expect(ems.subscription).to eq(@subscription)
    end

    def assert_region_on_another_account(ems, name)
      expect(ems.name).to eq(name)
      expect(ems.provider_region).to eq(name[AZURE_PREFIX, 1])
      expect(ems.auth_user_pwd).to eq([@alt_client_id, @alt_client_key])
      expect(ems.azure_tenant_id).to eq(@alt_tenant_id)
      expect(ems.subscription).to eq(@alt_subscription)
    end

    def create_factory_ems(name, region)
      ems = FactoryGirl.create(:ems_azure, :name => name, :provider_region => region)
      cred = {
        :userid   => @client_id,
        :password => @client_key,
      }
      ems.update_attributes(:azure_tenant_id => @tenant_id)
      ems.update_attributes(:subscription => @subscription)
      ems.authentications << FactoryGirl.create(:authentication, cred)
    end

    it "with no existing records" do |example|
      found = recorded_discover(example)
      expect(found.count).to eq(3)

      emses = ManageIQ::Providers::Azure::CloudManager.order(:name)
      expect(emses.count).to eq(3)
      assert_region(emses[1], "Azure-eastus")
      assert_region(emses[2], "Azure-westus")
    end

    it "with some existing records" do |example|
      create_factory_ems("Azure-eastus", "eastus")

      found = recorded_discover(example)
      expect(found.count).to eq(2)

      emses = ManageIQ::Providers::Azure::CloudManager.order(:name)
      expect(emses.count).to eq(3)
      assert_region(emses[1], "Azure-eastus")
      assert_region(emses[2], "Azure-westus")
    end

    it "with all existing records" do |example|
      create_factory_ems("Azure-eastus", "eastus")
      create_factory_ems("Azure-westus", "westus")

      found = recorded_discover(example)
      expect(found.count).to eq(1)

      emses = ManageIQ::Providers::Azure::CloudManager.order(:name)
      expect(emses.count).to eq(3)
      assert_region(emses[1], "Azure-eastus")
      assert_region(emses[2], "Azure-westus")
    end

    context "with records from a different account" do
      it "with the same name" do |example|
        FactoryGirl.create(:ems_azure_with_authentication, :name => "Azure-westus", :provider_region => "westus")

        found = recorded_discover(example)
        expect(found.count).to eq(3)

        emses = ManageIQ::Providers::Azure::CloudManager.order(:name).includes(:authentications)
        expect(emses.count).to eq(4)
        assert_region(emses[0], "Azure-centralus")
        assert_region(emses[1], "Azure-eastus")
        assert_region_on_another_account(emses[2], "Azure-westus")
        assert_region(emses[3], "Azure-westus #{@client_id}")
      end

      it "with the same name and backup name" do |example|
        FactoryGirl.create(
          :ems_azure_with_authentication,
          :name            => "Azure-westus",
          :provider_region => "westus")
        FactoryGirl.create(
          :ems_azure_with_authentication,
          :name            => "Azure-westus #{@client_id}",
          :provider_region => "westus")

        found = recorded_discover(example)
        expect(found.count).to eq(3)

        emses = ManageIQ::Providers::Azure::CloudManager.order(:name).includes(:authentications)
        expect(emses.count).to eq(5)

        assert_region(emses[1], "Azure-eastus")
        assert_region_on_another_account(emses[2], "Azure-westus")
        assert_region(emses[3], "Azure-westus 1")
        assert_region_on_another_account(emses[4], "Azure-westus #{@client_id}")
      end

      it "with the same name, backup name, and secondary backup name" do |example|
        FactoryGirl.create(:ems_azure_with_authentication, :name => "Azure-westus", :provider_region => "westus")
        FactoryGirl.create(
          :ems_azure_with_authentication,
          :name            => "Azure-westus #{@client_id}",
          :provider_region => "westus")
        FactoryGirl.create(:ems_azure_with_authentication, :name => "Azure-westus 1", :provider_region => "westus")

        found = recorded_discover(example)
        expect(found.count).to eq(3)

        emses = ManageIQ::Providers::Azure::CloudManager.order(:name).includes(:authentications)
        expect(emses.count).to eq(6)

        assert_region(emses[1], "Azure-eastus")
        assert_region_on_another_account(emses[2], "Azure-westus")
        assert_region_on_another_account(emses[3], "Azure-westus 1")
        assert_region(emses[4], "Azure-westus 2")
        assert_region_on_another_account(emses[5], "Azure-westus #{@client_id}")
      end
    end
  end
end
