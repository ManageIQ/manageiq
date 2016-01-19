describe MiqPolicy do
  context "Testing edge cases on conditions" do
    # The conditions reflection on MiqPolicy is affected when called through a
    # belongs_to or has_one, which is used under the covers in MiqSet.  This
    # test verifies that changing things under the covers doesn't affect
    # calling conditions.

    before(:each) do
      @ps = FactoryGirl.create(:miq_policy_set)
      @p  = FactoryGirl.create(:miq_policy)
      @ps.add_member(@p)
    end

    it "should return the correct conditions" do
      expect(@ps.miq_policies.first.conditions).to eq([])
      expect(@p.conditions).to eq([])
    end
  end

  context "#description=" do
    subject { FactoryGirl.create(:miq_policy, :description => @description) }

    it "should keep the description < 255" do
      @description = "a" * 30
      expect(subject.description.length).to eq(30)
    end

    it "should raise an error with empty description" do
      @description = nil
      expect { subject.description }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Description can't be blank")
    end

    it "should raise an error when description is reset to empty" do
      @description = "a" * 30
      subject.description = nil
      expect { subject.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Description can't be blank")
    end
  end

  describe "#seed" do
    let(:miq_policy_instance) { FactoryGirl.create(:miq_policy) }

    context "when fields(towhat, active, mode) are not yet set in database" do
      it "should be filled up by default values" do
        # be sure that we have not values in those fields
        miq_policy_instance.towhat = nil
        miq_policy_instance.active = nil
        miq_policy_instance.mode = nil
        miq_policy_instance.save

        MiqPolicy.seed

        updated_miq_policy = MiqPolicy.find(miq_policy_instance.id)

        # testing against default values from app/models/miq_policy.rb:366
        expect(updated_miq_policy.towhat).to eq("Vm")
        expect(updated_miq_policy.active).to eq(true)
        expect(updated_miq_policy.mode).to eq("control")
      end
    end

    context "when fields(towhat, active, mode) are already set in database" do
      it "should not be filled up by default values" do
        miq_policy_instance.towhat = "Host"
        miq_policy_instance.active = false
        miq_policy_instance.mode = "compliance"
        miq_policy_instance.save

        MiqPolicy.seed

        miq_policy = MiqPolicy.find(miq_policy_instance.id)

        # testing against default values from app/models/miq_policy.rb:366
        expect(miq_policy.towhat).not_to eq("Vm")
        expect(miq_policy.active).not_to eq(true)
        expect(miq_policy.mode).not_to eq("control")

        # testing that our values stayed untouched
        expect(miq_policy.towhat).to eq("Host")
        expect(miq_policy.active).to eq(false)
        expect(miq_policy.mode).to eq("compliance")
      end
    end
  end
end
