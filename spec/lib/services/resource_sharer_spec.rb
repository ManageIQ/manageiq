describe ResourceSharer do
  before { allow(User).to receive_messages(:server_timezone => "UTC") }

  describe "#share" do
    subject do
      described_class.new(:user => user,
                          :resource => resource_to_be_shared,
                          :tenants => tenants,
                          :features => features)
    end

    let(:user) { FactoryGirl.create(:user,
                                    :role     => "user",
                                    :features => "service") }
    let(:resource_to_be_shared) { FactoryGirl.create(:miq_template) }
    let(:tenants) { [FactoryGirl.create(:tenant)] }
    let(:features) { :all }

    context "with the :all option" do
      it "uses the user's current features" do
        shares = subject.share
        expect(shares.first.miq_product_features).to match_array(user.miq_user_role.miq_product_features)
      end
    end

    context "with an invalid resource" do
      let(:resource_to_be_shared) { FactoryGirl.build(:miq_group) }

      it "is invalid" do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages).to include(a_string_including("Resource is not sharable"))
      end
    end

    context "attempting to share a resource the user doesn't have access to" do
      pending "is invalid"
    end

    context "with tenants that aren't tenants" do
      let(:tenants) { [FactoryGirl.build(:miq_group)] }

      it "is invalid" do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages)
          .to include(a_string_including("Tenants must be an array of Tenant objects"))
      end
    end
  end
end
