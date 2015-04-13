require "spec_helper"

describe ConfiguredSystem do
  subject { described_class.new }

  describe "#all_tags" do
    let(:cd) { ConfigurationDomain.new(:name => "cd") }
    let(:cr) { ConfigurationRealm.new(:name => "cr") }
    let(:cr2) { ConfigurationRealm.new(:name => "cr2") }

    it "defaults to no tags" do
      expect(subject.all_tags).to eq({})
    end

    it "reads tags" do
      subject.configuration_tags << cd
      subject.configuration_tags << cr
      expect(subject.all_tags).to eq(
        ConfigurationDomain => cd,
        ConfigurationRealm  => cr
      )
    end

    context "with a profile" do
      let(:profile) { subject.build_configuration_profile }

      it "loads tags from profile" do
        profile.configuration_tags << cr
        expect(subject.all_tags).to eq(
          ConfigurationRealm => cr
        )
      end

      it "leverages tags from child" do
        subject.configuration_tags << cr
        profile.configuration_tags << cr2
        expect(subject.all_tags).to eq(
          ConfigurationRealm => cr
        )
      end

      context "and a parent" do
        let(:parent) { profile.build_parent }
        it "loads tags from profile profile" do
          profile.configuration_tags << cd
          parent.configuration_tags << cr
          expect(subject.all_tags).to eq(
            ConfigurationRealm  => cr,
            ConfigurationDomain => cd,
          )
        end
      end
    end
  end
end
