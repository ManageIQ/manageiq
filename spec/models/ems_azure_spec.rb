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
        ManageIQ::Providers::Azure::CloudManager.stub(:raw_connect).and_raise(RestClient::Unauthorized)
        expect { @e.verify_credentials }.to raise_error(MiqException::MiqHostError, /Incorrect credentials*/)
      end
    end
  end
end
