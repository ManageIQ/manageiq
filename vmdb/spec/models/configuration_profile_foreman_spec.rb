require "spec_helper"

describe ConfigurationProfileForeman do
  subject { described_class.new }

  describe "#configuration_tags" do
    let(:cd) { ConfigurationDomain.new(:name => "cd") }
    let(:cr) { ConfigurationRealm.new(:name => "cr") }
    let(:cr2) { ConfigurationRealm.new(:name => "cr2") }

    it "defaults to no tags" do
      expect(subject.configuration_tags).to eq([])
    end

    it { expect(subject.configuration_realm).to eq(nil) }

    it "reads tags" do
      subject.direct_configuration_tags << cd
      subject.direct_configuration_tags << cr
      expect(subject.configuration_tags).to match_array([cr, cd])
      expect(subject.direct_configuration_tags).to match_array([cr, cd])
    end

    it "reads tag helpers" do
      subject.direct_configuration_tags << cd
      subject.direct_configuration_tags << cr
      subject.direct_configuration_tags << ConfigurationArchitecture.new(:name => "CA")
      subject.direct_configuration_tags << ConfigurationComputeProfile.new(:name => "CC")
      subject.direct_configuration_tags << ConfigurationEnvironment.new(:name => "CE")

      expect(subject.configuration_domain).to eq(cd)
      expect(subject.configuration_realm).to eq(cr)
      expect(subject.configuration_architecture).not_to be_nil
      expect(subject.configuration_compute_profile).not_to be_nil
      expect(subject.configuration_environment).not_to be_nil
    end

    context "with a parent" do
      let(:parent) { subject.build_parent }

      it "supports empty parents" do
        subject.direct_configuration_tags << cr
        expect(subject.configuration_tags).to eq([cr])
      end

      it "loads tags from parent" do
        parent.direct_configuration_tags << cr
        expect(subject.configuration_tags).to eq([cr])
        expect(subject.direct_configuration_tags).to eq([])
      end

      it "loads tags from parent helpers" do
        parent.direct_configuration_tags << cr
        expect(subject.configuration_realm).to eq(cr)
      end

      it "leverages tags from child" do
        subject.direct_configuration_tags << cr
        parent.direct_configuration_tags << cr2
        expect(subject.configuration_tags).to eq([cr])
      end

      it "leverages tags from child helpers" do
        subject.direct_configuration_tags << cr
        parent.direct_configuration_tags << cr2
        expect(subject.configuration_realm).to eq(cr)
      end

      context "and a grandparent" do
        let(:grandparent) { parent.build_parent }

        it "loads tags from grandparent" do
          parent.direct_configuration_tags << cd
          grandparent.direct_configuration_tags << cr
          expect(subject.configuration_tags).to match_array([cr, cd])
          expect(subject.direct_configuration_tags).to eq([])
        end

        it "loads tags from grandparent helpers" do
          parent.direct_configuration_tags << cd
          grandparent.direct_configuration_tags << cr
          expect(subject.configuration_domain).to eq(cd)
          expect(subject.configuration_realm).to eq(cr)
        end

        it "loads respects hierarchy" do
          parent.direct_configuration_tags << cr
          grandparent.direct_configuration_tags << cr2
          grandparent.direct_configuration_tags << cd
          expect(subject.configuration_tags).to eq([cr, cd])
          expect(subject.direct_configuration_tags).to eq([])
        end

        it "loads respects hierarchy helpers" do
          parent.direct_configuration_tags << cr
          grandparent.direct_configuration_tags << cr2
          grandparent.direct_configuration_tags << cd
          expect(subject.configuration_domain).to eq(cd)
          expect(subject.configuration_realm).to eq(cr)
        end
      end
    end
  end
end
