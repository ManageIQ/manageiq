require "spec_helper"

describe ManageIQ::Providers::Google::CloudManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('gce')
  end

  it ".description" do
    expect(described_class.description).to eq('Google Compute Engine')
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
        expect(described_class).to receive(:raw_connect).with { |project, auth_key|
          expect(project).to eq(@google_project)
          expect(auth_key).to eq(@google_json_key)
        }
        @e.connect
      end
    end

    context "#validation" do
      it "handles incorrect password" do
        allow(ManageIQ::Providers::Google::CloudManager).to receive(:connect).and_raise(StandardError)
        expect { @e.verify_credentials }.to raise_error(MiqException::MiqInvalidCredentialsError, /Invalid Google JSON*/)
      end
    end
  end
end
