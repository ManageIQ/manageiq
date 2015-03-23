require "spec_helper"

describe MiqProvisionMixin do
  describe "#get_owner" do
    let(:miq_request) { double("MiqRequest", :requester => requester) }
    let(:owner) { FactoryGirl.create(:user_with_email) }
    let(:options) { {:owner_email => owner.email} }
    let(:requester) { FactoryGirl.create(:user_with_email) }
    subject do
      Class.new do
        include MiqProvisionMixin
        attr_accessor :options, :miq_request

        def initialize(miq_request, options)
          @miq_request = miq_request
          @options     = options
        end

        def get_option(name)
          options[name]
        end
      end.new(miq_request, options)
    end

    context "with no owner_email" do
      let(:owner) { nil }
      let(:options) { {} }
      it { expect(subject.get_owner).to be_nil }
    end

    it do
      expect(User).to receive(:where).once.and_call_original
      expect(subject.get_owner).to eq(owner)
    end

    context "with owner = requester" do
      let(:owner) { requester }
      it "leverages requester record (and doesn't look up the owner again)" do
        expect(User).not_to receive(:where)
        expect(subject.get_owner).to eq(owner)
      end
    end

    describe ".current_group" do
      before do
        owner.update_attributes(:current_group => my_group,
                                :miq_groups    => [my_group, my_alt_group])
      end
      let(:my_group) { FactoryGirl.create(:miq_group) }
      let(:my_alt_group) { FactoryGirl.create(:miq_group, :description => 'yay') }
      let(:bad_group) { FactoryGirl.create(:miq_group, :description => 'boo') }

      it "keeps current_group" do
        expect(subject.get_owner.current_group).to eq(my_group)
      end

      context "with specified group" do
        let(:options) do
          {:owner_email => owner.email, :owner_group => my_alt_group.description}
        end

        it "overrides current_group" do
          expect(subject.get_owner.current_group).to eq(my_alt_group)
        end
      end

      context "with specified but invalid group" do
        let(:options) do
          {:owner_email => owner.email, :owner_group => bad_group.description}
        end

        it "keeps current_group" do
          expect(subject.get_owner.current_group).to eq(my_group)
        end
      end
    end
  end
end
