require "spec_helper"

describe ManageIQ::Providers::Google::CloudManager do
  it ".ems_type" do
    described_class.ems_type.should == 'gce'
  end

  it ".description" do
    described_class.description.should == 'Google Compute Engine'
  end

  context "#connectivity" do
    before do
      @google_project = "yourprojectid"
      @google_json_key = "{\r\n\"type\": \"service_account\",\r\n\"private_key_id\": \"abcdefg\"}"
      @e = FactoryGirl.create(:ems_google)
      @e.authentications << FactoryGirl.create(:authentication, :userid => "_", :auth_key => @google_json_key)
      @e.project = @google_project
    end

    context "#connect " do
      it "defaults" do
        described_class.should_receive(:raw_connect).with do |project, auth_key|
          project.should eq(@google_project)
          auth_key.should eq(@google_json_key)
        end
        @e.connect
      end
    end

    context "#validation" do
      it "handles incorrect password" do
        ManageIQ::Providers::Google::CloudManager.stub(:connect).and_raise(StandardError)
        expect { @e.verify_credentials }.to raise_error(MiqException::MiqInvalidCredentialsError, /Invalid Google JSON*/)
      end
    end
  end
end
