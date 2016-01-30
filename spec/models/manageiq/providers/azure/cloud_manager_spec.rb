describe ManageIQ::Providers::Azure::CloudManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('azure')
  end

  it ".description" do
    expect(described_class.description).to eq('Azure')
  end

  context "#connectivity" do
    before do
      @e = FactoryGirl.create(:ems_azure)
      @e.authentications << FactoryGirl.create(:authentication, :userid => "klmnopqrst", :password => "1234567890")
      @e.azure_tenant_id = "abcdefghij"
    end

    context "#connect " do
      it "defaults" do
        expect(described_class).to receive(:raw_connect) do |clientid, clientkey|
          expect(clientid).to eq("klmnopqrst")
          expect(clientkey).to eq("1234567890")
        end
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
        expect { @e.verify_credentials }.to raise_error(MiqException::MiqHostError, /Unexpected response returned*/)
      end

      it "handles incorrect password" do
        allow(ManageIQ::Providers::Azure::CloudManager).to receive(:raw_connect).and_raise(
          Azure::Armrest::UnauthorizedException.new(nil, nil, nil))
        expect { @e.verify_credentials }.to raise_error(MiqException::MiqHostError, /Incorrect credentials*/)
      end
    end
  end

  context ".discover" do
    AZURE_PREFIX = /Azure-(\w+)/

    before do
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)

      @user              = "0123456789ABCDEFGHIJ"
      @pass              = "ABCDEFGHIJKLMNO1234567890abcdefghijklmno"
      @tenant_id         = "0123456789ABCDEFGHIJ0123456789AB"
      @another_user      = "testuser"
      @another_password  = "secret"
      @another_tenant_id = "ABCDEFGHIJABCDEFGHIJ0123456789AB"
    end

    def recorded_discover(example)
      cassette_name = example.description.tr(" ", "_").delete(",").underscore
      VCR.use_cassette(
        "#{described_class.name.underscore}/discover/#{cassette_name}",
        :allow_unused_http_interactions => true) do
        ManageIQ::Providers::Azure::CloudManager.discover(@user, @pass, @tenant_id)
      end
    end

    def assert_region(ems, name)
      expect(ems.name).to eq(name)
      expect(ems.provider_region).to eq(name[AZURE_PREFIX, 1])
      expect(ems.auth_user_pwd).to eq([@user, @pass])
      expect(ems.azure_tenant_id).to eq(@tenant_id)
    end

    def assert_region_on_another_account(ems, name)
      expect(ems.name).to eq(name)
      expect(ems.provider_region).to eq(name[AZURE_PREFIX, 1])
      expect(ems.auth_user_pwd).to eq([@another_user, @another_password])
      expect(ems.azure_tenant_id).to eq(@another_tenant_id)
    end

    def create_factory_ems(name, region)
      ems = FactoryGirl.create(:ems_azure, :name => name, :provider_region => region)
      cred = {
        :userid   => @user,
        :password => @pass,
      }
      ems.update_attributes(:azure_tenant_id => @tenant_id)
      ems.authentications << FactoryGirl.create(:authentication, cred)
    end

    it "with no existing records" do |example|
      found = recorded_discover(example)
      expect(found.count).to eq(2)

      emses = ManageIQ::Providers::Azure::CloudManager.order(:name)
      expect(emses.count).to eq(2)
      assert_region(emses[0], "Azure-eastus")
      assert_region(emses[1], "Azure-westus")
    end

    it "with some existing records" do |example|
      create_factory_ems("Azure-eastus", "eastus")

      found = recorded_discover(example)
      expect(found.count).to eq(1)

      emses = ManageIQ::Providers::Azure::CloudManager.order(:name)
      expect(emses.count).to eq(2)
      assert_region(emses[0], "Azure-eastus")
      assert_region(emses[1], "Azure-westus")
    end

    it "with all existing records" do |example|
      create_factory_ems("Azure-eastus", "eastus")
      create_factory_ems("Azure-westus", "westus")

      found = recorded_discover(example)
      expect(found.count).to eq(0)

      emses = ManageIQ::Providers::Azure::CloudManager.order(:name)
      expect(emses.count).to eq(2)
      assert_region(emses[0], "Azure-eastus")
      assert_region(emses[1], "Azure-westus")
    end

    context "with records from a different account" do
      it "with the same name" do |example|
        FactoryGirl.create(:ems_azure_with_authentication, :name => "Azure-westus", :provider_region => "westus")

        found = recorded_discover(example)
        expect(found.count).to eq(2)

        emses = ManageIQ::Providers::Azure::CloudManager.order(:name).includes(:authentications)
        expect(emses.count).to eq(3)
        assert_region(emses[0], "Azure-eastus")
        assert_region_on_another_account(emses[1], "Azure-westus")
        assert_region(emses[2], "Azure-westus #{@user}")
      end

      it "with the same name and backup name" do |example|
        FactoryGirl.create(
          :ems_azure_with_authentication,
          :name            => "Azure-westus",
          :provider_region => "westus")
        FactoryGirl.create(
          :ems_azure_with_authentication,
          :name            => "Azure-westus #{@user}",
          :provider_region => "westus")

        found = recorded_discover(example)
        expect(found.count).to eq(2)

        emses = ManageIQ::Providers::Azure::CloudManager.order(:name).includes(:authentications)
        expect(emses.count).to eq(4)

        assert_region(emses[0], "Azure-eastus")
        assert_region_on_another_account(emses[1], "Azure-westus")
        assert_region_on_another_account(emses[2], "Azure-westus #{@user}")
        assert_region(emses[3], "Azure-westus 1")
      end

      it "with the same name, backup name, and secondary backup name" do |example|
        FactoryGirl.create(:ems_azure_with_authentication, :name => "Azure-westus", :provider_region => "westus")
        FactoryGirl.create(
          :ems_azure_with_authentication,
          :name            => "Azure-westus #{@user}",
          :provider_region => "westus")
        FactoryGirl.create(:ems_azure_with_authentication, :name => "Azure-westus 1", :provider_region => "westus")

        found = recorded_discover(example)
        expect(found.count).to eq(2)

        emses = ManageIQ::Providers::Azure::CloudManager.order(:name).includes(:authentications)
        expect(emses.count).to eq(5)

        assert_region(emses[0], "Azure-eastus")
        assert_region_on_another_account(emses[1], "Azure-westus")
        assert_region_on_another_account(emses[2], "Azure-westus #{@user}")
        assert_region_on_another_account(emses[3], "Azure-westus 1")
        assert_region(emses[4], "Azure-westus 2")
      end
    end
  end
end
