RSpec.describe ResourceSharer do
  before { allow(User).to receive_messages(:server_timezone => "UTC") }

  describe "#share" do
    subject do
      described_class.new(:user     => user,
                          :resource => resource_to_be_shared,
                          :tenants  => tenants,
                          :features => features)
    end

    let(:user) do
      FactoryBot.create(:user,
                         :role     => "user",
                         :features => user_allowed_feature)
    end
    let(:user_allowed_feature) { "service" }
    let(:resource_to_be_shared) { FactoryBot.create(:miq_template) }
    let(:tenants) { [FactoryBot.create(:tenant)] }
    let(:features) { :all }

    context "with valid arguments" do
      before do
        expect(user.owned_shares.count).to eq(0)
        expect(subject).to be_valid
        subject.share
      end

      it "creates a share from the user to the tenant" do
        expect(user.owned_shares.count).to eq(1)
      end
    end

    context "product features" do
      context "with the :all option on initialization" do
        it "uses the user's current features" do
          expect(subject.features).to match_array(user.miq_user_role.miq_product_features)
        end
      end

      context "with an unauthorized product feature (across tree)" do
        let(:features) { MiqProductFeature.find_by(:identifier => "host") }
        let(:user_allowed_feature) { "service" }

        before { EvmSpecHelper.seed_specific_product_features(%w(host service)) }

        it "is invalid" do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include(a_string_including("Features not permitted"))
        end
      end

      context "with an unauthorized product feature (up tree)" do
        let(:features) { MiqProductFeature.find_by(:identifier => "host") }
        let(:user_allowed_feature) { "host_edit" }

        before { EvmSpecHelper.seed_specific_product_features(%w(host)) }

        it "is invalid" do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include(a_string_including("Features not permitted"))
        end
      end

      context "with a 'sees everything' product feature user" do
        let(:features) { MiqProductFeature.find_by(:identifier => "host_edit") }
        let(:user_allowed_feature) { "everything" }

        before { EvmSpecHelper.seed_specific_product_features(%w(host_edit everything)) }

        it "is valid" do
          expect(subject).to be_valid
        end
      end
    end

    context "with an invalid resource" do
      let(:resource_to_be_shared) { FactoryBot.build(:miq_group) }

      it "is invalid" do
        User.with_user(user) do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include(a_string_including("Resource is not sharable"))
        end
      end
    end

    context "attempting to share a resource the user doesn't have access to via RBAC" do
      let(:user) do
        FactoryBot.create(:user,
                           :role     => "user",
                           :features => user_allowed_feature,
                           :tenant   => FactoryBot.create(:tenant, :name => "Tenant under root"))
      end
      let(:resource_to_be_shared) do
        FactoryBot.create(:miq_template,
                           :tenant => FactoryBot.create(:tenant,
                                                         :name => "Sibling tenant"))
      end
      let(:tenants) { [user.current_tenant] } # Attempt to share a resource in Sibling tenant to one's own tenant

      before { Tenant.seed }

      it "is invalid" do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages).to include(a_string_including("is not authorized to share this resource"))
      end
    end

    context "with tenants that aren't tenants" do
      let(:tenants) { [FactoryBot.build(:miq_group)] }

      it "is invalid" do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages)
          .to include(a_string_including("Tenants must be an array of Tenant objects"))
      end
    end
  end
end
