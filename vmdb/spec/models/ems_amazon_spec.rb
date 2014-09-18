require "spec_helper"

describe EmsAmazon do
  it ".ems_type" do
    described_class.ems_type.should == 'ec2'
  end

  it ".description" do
    described_class.description.should == 'Amazon EC2'
  end

  context ".discover" do
    before do
      EvmSpecHelper.seed_for_miq_queue
      @ec2_user = "0123456789ABCDEFGHIJ"
      @ec2_pass = "ABCDEFGHIJKLMNO1234567890abcdefghijklmno"
      @ec2_user2 = "testuser"
      @ec2_pass2 = "secret"
    end

    def recorded_discover(example)
      cassette_name = example.description.tr(" ", "_").gsub(",", "").underscore
      VCR.use_cassette("#{described_class.name.underscore}/discover/#{cassette_name}") do
        EmsAmazon.discover(@ec2_user, @ec2_pass)
      end
    end

    def assert_region(ems, name)
      ems.name.should            == name
      ems.provider_region.should == name.split(" ").first
      ems.auth_user_pwd.should   == [@ec2_user, @ec2_pass]
    end

    def assert_region_on_another_account(ems, name)
      ems.name.should            == name
      ems.provider_region.should == name.split(" ").first
      ems.auth_user_pwd.should   == [@ec2_user2, @ec2_pass2]
    end


    it "with no existing records" do
      found = recorded_discover(example)
      found.count.should == 2

      emses = EmsAmazon.order(:name).all
      emses.count.should == 2
      assert_region(emses[0], "us-east-1")
      assert_region(emses[1], "us-west-1")
    end

    it "with no existing records and greenfield Amazon" do
      found = recorded_discover(example)
      found.count.should == 1

      emses = EmsAmazon.order(:name).all
      emses.count.should == 1
      assert_region(emses[0], "us-east-1")
    end

    it "with some existing records" do
      FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-west-1", :provider_region => "us-west-1")

      found = recorded_discover(example)
      found.count.should == 1

      emses = EmsAmazon.order(:name).all
      emses.count.should == 2
      assert_region(emses[0], "us-east-1")
      assert_region(emses[1], "us-west-1")
    end

    it "with all existing records" do
      FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-east-1", :provider_region => "us-east-1")
      FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-west-1", :provider_region => "us-west-1")

      found = recorded_discover(example)
      found.count.should == 0

      emses = EmsAmazon.order(:name).all
      emses.count.should == 2
      assert_region(emses[0], "us-east-1")
      assert_region(emses[1], "us-west-1")
    end

    context "with records from a different account" do
      it "with the same name" do
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1", :provider_region => "us-west-1")

        found = recorded_discover(example)
        found.count.should == 2

        emses = EmsAmazon.order(:name).includes(:authentications).all
        emses.count.should == 3
        assert_region(emses[0], "us-east-1")
        assert_region_on_another_account(emses[1], "us-west-1")
        assert_region(emses[2], "us-west-1 #{@ec2_user}")
      end

      it "with the same name and backup name" do
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1", :provider_region => "us-west-1")
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1 #{@ec2_user}", :provider_region => "us-west-1")

        found = recorded_discover(example)
        found.count.should == 2

        emses = EmsAmazon.order(:name).includes(:authentications).all
        emses.count.should == 4
        assert_region(emses[0], "us-east-1")
        assert_region_on_another_account(emses[1], "us-west-1")
        assert_region_on_another_account(emses[2], "us-west-1 #{@ec2_user}")
        assert_region(emses[3], "us-west-1 1")
      end

      it "with the same name, backup name, and secondary backup name" do
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1", :provider_region => "us-west-1")
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1 #{@ec2_user}", :provider_region => "us-west-1")
        FactoryGirl.create(:ems_amazon_with_authentication_on_other_account, :name => "us-west-1 1", :provider_region => "us-west-1")

        found = recorded_discover(example)
        found.count.should == 2

        emses = EmsAmazon.order(:name).includes(:authentications).all
        emses.count.should == 5
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
    ems.description.should == "US East (Northern Virginia)"

    ems = FactoryGirl.build(:ems_amazon, :provider_region => "us-west-1")
    ems.description.should == "US West (Northern California)"
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
end
