require "spec_helper"

describe ConfiguredSystemForeman do
  context "::Placement" do
    context "#available_configuration_profiles" do
      let(:arch1) { FactoryGirl.create(:configuration_architecture, :name => "i386") }
      let(:arch2) { FactoryGirl.create(:configuration_architecture, :name => "x86_64") }
      let(:cl)    { FactoryGirl.create(:configuration_location) }
      let(:cl2)   { FactoryGirl.create(:configuration_location) }
      let(:co)    { FactoryGirl.create(:configuration_organization) }
      let(:co2)   { FactoryGirl.create(:configuration_organization) }
      let(:cp1)   { FactoryGirl.create(:configuration_profile_foreman) }
      let(:cp2)   { FactoryGirl.create(:configuration_profile_foreman, :parent => cp1) }
      let(:cp3)   { FactoryGirl.create(:configuration_profile_foreman, :parent => cp2) }
      let(:cs)    { FactoryGirl.create(:configured_system_foreman, :configuration_organization => co, :configuration_location => cl) }

      before { cp1; cp2; cp3 }  # Create ConfigurationProfiles location and/or organization to be assigned by the spec

      context "filters based on locations" do
        it "profiles in other locations are not available" do
          cl.configuration_profiles.push(cp1, cp2)
          cl2.configuration_profiles.push(cp3)

          expect(cs.available_configuration_profiles).to match_array([cp1, cp2])
        end

        it "profiles with nil locations are available" do
          cl.configuration_profiles.push(cp1, cp2)

          expect(cs.available_configuration_profiles).to match_array([cp1, cp2, cp3])
        end
      end

      context "filters based on organizations" do
        it "profiles in other organizations are not available" do
          co.configuration_profiles.push(cp1, cp2)
          co2.configuration_profiles.push(cp3)

          expect(cs.available_configuration_profiles).to match_array([cp1, cp2])
        end

        it "profiles with nil organizations are available" do
          co.configuration_profiles.push(cp1, cp2)

          expect(cs.available_configuration_profiles).to match_array([cp1, cp2, cp3])
        end
      end

      it "filters based on architectures" do
        cp3.configuration_tags.push(arch1)
        cs.configuration_tags.push(arch2)

        expect(cs.available_configuration_profiles).to match_array([cp1, cp2])
      end
    end
  end
end
