require "spec_helper"

describe ConfiguredSystemForeman do
  subject { described_class.new }

  describe "#configuration_tags" do
    let(:cd) { ConfigurationDomain.new(:name => "cd") }
    let(:cr) { ConfigurationRealm.new(:name => "cr") }
    let(:cr2) { ConfigurationRealm.new(:name => "cr2") }

    it "defaults to no tags" do
      expect(subject.configuration_tags).to eq([])
    end

    it "reads tags" do
      subject.raw_configuration_tags << cd
      subject.raw_configuration_tags << cr
      expect(subject.configuration_tags).to match_array([cr, cd])
      expect(subject.raw_configuration_tags).to match_array([cr, cd])
    end

    it "reads tag helpers" do
      subject.raw_configuration_tags << cd
      subject.raw_configuration_tags << cr
      subject.raw_configuration_tags << ConfigurationArchitecture.new(:name => "CA")
      subject.raw_configuration_tags << ConfigurationComputeProfile.new(:name => "CC")
      subject.raw_configuration_tags << ConfigurationEnvironment.new(:name => "CE")

      expect(subject.configuration_domain).to eq(cd)
      expect(subject.configuration_realm).to eq(cr)
      expect(subject.configuration_architecture).not_to be_nil
      expect(subject.configuration_compute_profile).not_to be_nil
      expect(subject.configuration_environment).not_to be_nil

      expect(subject.configuration_tags.size).to eq(5)
    end

    context "with a profile" do
      let(:profile) { subject.build_configuration_profile }

      it "loads tags from profile" do
        profile.raw_configuration_tags << cr
        expect(subject.configuration_tags).to eq([cr])
      end

      it "leverages tags from child" do
        subject.raw_configuration_tags << cr
        profile.raw_configuration_tags << cr2
        expect(subject.configuration_tags).to eq([cr])
      end

      context "and a parent" do
        let(:parent) { profile.build_parent }
        it "loads tags from profile profile" do
          profile.raw_configuration_tags << cd
          parent.raw_configuration_tags << cr
          expect(subject.configuration_tags).to match_array([cr, cd])
        end
      end
    end
  end

  describe "inherited attributes" do
    it "defaults to nil" do
      expect(subject.operating_system_flavor).to be_nil
      expect(subject.customization_script_medium).to be_nil
      expect(subject.customization_script_ptable).to be_nil
    end

    it "loads attributes with nil profile" do
      subject.raw_operating_system_flavor = OperatingSystemFlavor.new(:name => "osf")
      subject.raw_customization_script_medium = CustomizationScriptMedium.new(:name => "csm")
      subject.raw_customization_script_ptable = CustomizationScriptPtable.new(:name => "csp")
      expect(subject.operating_system_flavor).not_to be_nil
      expect(subject.customization_script_medium).not_to be_nil
      expect(subject.customization_script_ptable).not_to be_nil
    end

    context "with a profile" do
      let(:profile) { subject.build_configuration_profile }
      it "loads attributes from profile" do
        profile.raw_operating_system_flavor = OperatingSystemFlavor.new(:name => "osf")
        profile.raw_customization_script_medium = CustomizationScriptMedium.new(:name => "csm")
        profile.raw_customization_script_ptable = CustomizationScriptPtable.new(:name => "csp")
        expect(subject.operating_system_flavor).not_to be_nil
        expect(subject.customization_script_medium).not_to be_nil
        expect(subject.customization_script_ptable).not_to be_nil
      end
    end
  end
end
