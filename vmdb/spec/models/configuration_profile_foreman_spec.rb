require "spec_helper"

describe ConfigurationProfileForeman do
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
        ConfigurationRealm  => cr,
        ConfigurationDomain => cd,
      )
    end

    context "with a parent" do
      let(:parent) { subject.build_parent }

      it "supports empty parents" do
        subject.configuration_tags << cr
        expect(subject.all_tags).to eq(
          ConfigurationRealm => cr
        )
      end

      it "loads tags from parent" do
        parent.build_parent
        parent.configuration_tags << cr
        expect(subject.all_tags).to eq(
          ConfigurationRealm => cr
        )
      end

      it "leverages tags from child" do
        subject.configuration_tags << cr
        parent.configuration_tags << cr2
        expect(subject.all_tags).to eq(
          ConfigurationRealm => cr
        )
      end

      context "and a parent" do
        let(:parent_parent) { parent.build_parent }
        it "loads tags from parent parent" do
          parent.configuration_tags << cd
          parent_parent.configuration_tags << cr
          expect(subject.all_tags).to eq(
            ConfigurationRealm  => cr,
            ConfigurationDomain => cd,
          )
        end

        it "loads respects hierarchy" do
          parent.configuration_tags << cr
          parent_parent.configuration_tags << cr2
          parent_parent.configuration_tags << cd
          expect(subject.all_tags).to eq(
            ConfigurationRealm  => cr,
            ConfigurationDomain => cd,
          )
        end
      end
    end
  end
end
