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

    it "reads tags" do
      subject.raw_configuration_tags << cd
      subject.raw_configuration_tags << cr
      expect(subject.configuration_tags).to match_array([cr, cd])
    end

    context "with a parent" do
      let(:parent) { subject.build_parent }

      it "supports empty parents" do
        subject.raw_configuration_tags << cr
        expect(subject.configuration_tags).to eq([cr])
      end

      it "loads tags from parent" do
        parent.build_parent
        parent.raw_configuration_tags << cr
        expect(subject.configuration_tags).to eq([cr])
      end

      it "leverages tags from child" do
        subject.raw_configuration_tags << cr
        parent.raw_configuration_tags << cr2
        expect(subject.configuration_tags).to eq([cr])
      end

      context "and a grandparent" do
        let(:grandparent) { parent.build_parent }
        it "loads tags from grandparent" do
          parent.raw_configuration_tags << cd
          grandparent.raw_configuration_tags << cr
          expect(subject.configuration_tags).to eq([cr, cd])
        end

        it "loads respects hierarchy" do
          parent.raw_configuration_tags << cr
          grandparent.raw_configuration_tags << cr2
          grandparent.raw_configuration_tags << cd
          expect(subject.configuration_tags).to eq([cr, cd])
        end
      end
    end
  end
end
