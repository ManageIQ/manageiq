require "spec_helper"

describe ManageIQ::Providers::Azure::CloudManager do
  it ".ems_type" do
    described_class.ems_type.should == 'azure'
  end

  it ".description" do
    described_class.description.should == 'Azure'
  end

  context "#connectivity" do
    before do
      @e = FactoryGirl.create(:ems_azure)
      @e.authentications << FactoryGirl.create(:authentication, :userid => "klmnopqrst", :password => "1234567890")
      @e.azure_tenant_id = "abcdefghij"
    end

    context "#connect " do
      it "defaults" do
        described_class.should_receive(:raw_connect).with do |clientid, clientkey|
          clientid.should eq("klmnopqrst")
          clientkey.should eq("1234567890")
        end
        @e.connect
      end

      it "accepts overrides" do
        described_class.should_receive(:raw_connect).with do |clientid, clientkey|
          clientid.should eq("user")
          clientkey.should eq("pass")
        end
        @e.connect(:user => "user", :pass => "pass")
      end
    end

    context "#validation" do
      it "handles unknown error" do
        ManageIQ::Providers::Azure::CloudManager.stub(:raw_connect).and_raise(StandardError)
        expect { @e.verify_credentials }.to raise_error(MiqException::MiqHostError, /Unexpected response returned*/)
      end

      it "handles incorrect password" do
        ManageIQ::Providers::Azure::CloudManager.stub(:raw_connect).and_raise(
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
      ems.name.should eq(name)
      ems.provider_region.should eq(name[AZURE_PREFIX, 1])
      ems.auth_user_pwd.should eq([@user, @pass])
      ems.azure_tenant_id.should eq(@tenant_id)
    end

    def assert_region_on_another_account(ems, name)
      ems.name.should eq(name)
      ems.provider_region.should eq(name[AZURE_PREFIX, 1])
      ems.auth_user_pwd.should eq([@another_user, @another_password])
      ems.azure_tenant_id.should eq(@another_tenant_id)
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

    it "with no existing records" do
      found = recorded_discover(example)
      found.count.should eq(2)

      emses = ManageIQ::Providers::Azure::CloudManager.order(:name)
      emses.count.should eq(2)
      assert_region(emses[0], "Azure-eastus")
      assert_region(emses[1], "Azure-westus")
    end

    it "with some existing records" do
      create_factory_ems("Azure-eastus", "eastus")

      found = recorded_discover(example)
      found.count.should eq(1)

      emses = ManageIQ::Providers::Azure::CloudManager.order(:name)
      emses.count.should eq(2)
      assert_region(emses[0], "Azure-eastus")
      assert_region(emses[1], "Azure-westus")
    end

    it "with all existing records" do
      create_factory_ems("Azure-eastus", "eastus")
      create_factory_ems("Azure-westus", "westus")

      found = recorded_discover(example)
      found.count.should eq(0)

      emses = ManageIQ::Providers::Azure::CloudManager.order(:name)
      emses.count.should eq(2)
      assert_region(emses[0], "Azure-eastus")
      assert_region(emses[1], "Azure-westus")
    end

    context "with records from a different account" do
      it "with the same name" do
        FactoryGirl.create(:ems_azure_with_authentication, :name => "Azure-westus", :provider_region => "westus")

        found = recorded_discover(example)
        found.count.should eq(2)

        emses = ManageIQ::Providers::Azure::CloudManager.order(:name).includes(:authentications)
        emses.count.should eq(3)
        assert_region(emses[0], "Azure-eastus")
        assert_region_on_another_account(emses[1], "Azure-westus")
        assert_region(emses[2], "Azure-westus #{@user}")
      end

      it "with the same name and backup name" do
        FactoryGirl.create(
          :ems_azure_with_authentication,
          :name            => "Azure-westus",
          :provider_region => "westus")
        FactoryGirl.create(
          :ems_azure_with_authentication,
          :name            => "Azure-westus #{@user}",
          :provider_region => "westus")

        found = recorded_discover(example)
        found.count.should eq(2)

        emses = ManageIQ::Providers::Azure::CloudManager.order(:name).includes(:authentications)
        emses.count.should eq(4)

        assert_region(emses[0], "Azure-eastus")
        assert_region_on_another_account(emses[1], "Azure-westus")
        assert_region_on_another_account(emses[2], "Azure-westus #{@user}")
        assert_region(emses[3], "Azure-westus 1")
      end

      it "with the same name, backup name, and secondary backup name" do
        FactoryGirl.create(:ems_azure_with_authentication, :name => "Azure-westus", :provider_region => "westus")
        FactoryGirl.create(
          :ems_azure_with_authentication,
          :name            => "Azure-westus #{@user}",
          :provider_region => "westus")
        FactoryGirl.create(:ems_azure_with_authentication, :name => "Azure-westus 1", :provider_region => "westus")

        found = recorded_discover(example)
        found.count.should eq(2)

        emses = ManageIQ::Providers::Azure::CloudManager.order(:name).includes(:authentications)
        emses.count.should eq(5)

        assert_region(emses[0], "Azure-eastus")
        assert_region_on_another_account(emses[1], "Azure-westus")
        assert_region_on_another_account(emses[2], "Azure-westus #{@user}")
        assert_region_on_another_account(emses[3], "Azure-westus 1")
        assert_region(emses[4], "Azure-westus 2")
      end
    end
  end
end
