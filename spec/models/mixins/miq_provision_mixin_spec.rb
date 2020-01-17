RSpec.describe MiqProvisionMixin do
  describe "#get_owner" do
    let(:owner) { FactoryBot.create(:user_with_email) }
    let(:options) { {:owner_email => owner.email} }
    let(:requester) { FactoryBot.create(:user_with_email) }
    subject do
      Class.new do
        include MiqProvisionMixin
        attr_accessor :options

        def initialize(user, options)
          @options     = options
          @requester   = user
        end

        def get_user
          @requester
        end

        def get_option(name)
          options[name]
        end
      end.new(requester, options)
    end

    context "with no owner_email" do
      let(:owner) { nil }
      let(:options) { {} }
      it { expect(subject.get_owner).to be_nil }
    end

    it "find owner (no group)" do
      expect(subject.get_owner).to eq(owner)
    end

    context "with owner = requester" do
      let(:owner) { requester }

      it "leverages requester record (and doesn't look up the owner again)" do
        expect(subject.get_owner.object_id).to eq(requester.object_id)
      end
    end

    context "#with different email case" do
      let(:options) { {:owner_email => owner.email.upcase} }
      it "still finds owner" do
        expect(subject.get_owner).to eq(owner)
      end
    end

    describe ".current_group" do
      before do
        owner.update(:current_group => my_group,
                                :miq_groups    => [my_group, my_alt_group])
      end
      let(:my_group) { FactoryBot.create(:miq_group) }
      let(:my_alt_group) { FactoryBot.create(:miq_group, :description => 'yay') }
      let(:bad_group) { FactoryBot.create(:miq_group, :description => 'boo') }

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
