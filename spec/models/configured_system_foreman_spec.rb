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

    it { expect(subject.configuration_realm).to eq(nil) }

    it "reads tag helpers" do
      subject.configuration_tags << cd
      subject.configuration_tags << cr
      subject.configuration_tags << ConfigurationArchitecture.new(:name => "CA")
      subject.configuration_tags << ConfigurationComputeProfile.new(:name => "CC")
      subject.configuration_tags << ConfigurationEnvironment.new(:name => "CE")

      expect(subject.configuration_domain).to eq(cd)
      expect(subject.configuration_realm).to eq(cr)
      expect(subject.configuration_architecture).not_to be_nil
      expect(subject.configuration_compute_profile).not_to be_nil
      expect(subject.configuration_environment).not_to be_nil

      expect(subject.configuration_tags.size).to eq(5)
    end
  end
end
