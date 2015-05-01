require "spec_helper"

describe ConfiguredSystemForeman do
  context "::Placement" do
    context "#available_configuration_profiles" do
      let(:arch1) { FactoryGirl.create(:configuration_architecture, :name => "i386") }
      let(:arch2) { FactoryGirl.create(:configuration_architecture, :name => "x86_64") }
      let(:cl)    { FactoryGirl.create(:configuration_location) }
      let(:co)    { FactoryGirl.create(:configuration_organization) }
      let(:cp1)   { FactoryGirl.create(:configuration_profile_foreman) }
      let(:cp2)   { FactoryGirl.create(:configuration_profile_foreman, :parent => cp1) }
      let(:cp3)   { FactoryGirl.create(:configuration_profile_foreman, :parent => cp2) }
      let(:cs)    { FactoryGirl.create(:configured_system_foreman, :configuration_organization => co, :configuration_location => cl) }

      it "filters based on locations" do
        cl.configuration_profiles.push(cp1, cp2)
        co.configuration_profiles.push(cp1, cp2, cp3)

        expect(cs.available_configuration_profiles).to match_array([cp1, cp2])
      end

      it "filters based on organizations" do
        cl.configuration_profiles.push(cp1, cp2, cp3)
        co.configuration_profiles.push(cp1, cp2)

        expect(cs.available_configuration_profiles).to match_array([cp1, cp2])
      end

      it "filters based on architectures" do
        cl.configuration_profiles.push(cp1, cp2, cp3)
        co.configuration_profiles.push(cp1, cp2, cp3)
        cp3.configuration_tags.push(arch1)
        cs.configuration_tags.push(arch2)

        expect(cs.available_configuration_profiles).to match_array([cp1, cp2])
      end
    end
  end
end
