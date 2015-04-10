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
      expect(subject.configuration_tags).to match_array([cd, cr])
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
end
