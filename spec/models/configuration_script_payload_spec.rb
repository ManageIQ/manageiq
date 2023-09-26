RSpec.describe ConfigurationScriptPayload do
  let(:subject) { FactoryBot.create(:configuration_script_payload) }

  describe "#credentials=" do
    context "with a valid payload" do
      let(:credentials) { {"my_username" => {"credential_ref" => "my", "credential_field" => "userid"}, "my_password" => "password"} }

      it "saves without error" do
        subject.credentials = credentials
        subject.save!
        expect(subject.reload.credentials).to eq(credentials)
      end
    end

    context "with an invalid payload" do
      context "with an array" do
        let(:credentials) { ["foo", "bar"] }

        it "raises a validation exception" do
          subject.credentials = credentials
          expect { subject.save! }.to raise_error("Validation failed: ConfigurationScriptPayload: Credentials Invalid payload: credentials must be a hash")
        end
      end

      context "with invalid values" do
        let(:credentials) { {"my_username" => 0.1} }

        it "raises a validation exception" do
          subject.credentials = credentials
          expect { subject.save! }.to raise_error("Validation failed: ConfigurationScriptPayload: Credentials Invalid payload: credential value must be string or a hash")
        end
      end

      context "with missing credential keys" do
        let(:credentials) { {"my_username" => {"credential_ref" => "my"}} }

        it "raises a validation exception" do
          subject.credentials = credentials
          expect { subject.save! }.to raise_error("Validation failed: ConfigurationScriptPayload: Credentials Invalid payload: credential value must have credential_ref and credential_field")
        end
      end
    end
  end
end
