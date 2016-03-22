describe MiqPolicySet do
  let(:desc) { "Test Profile" }
  before { FactoryGirl.create(:miq_policy_set, :name => "Profile 1", :description => desc) }

  it "unique description in one class" do
    expect {
      FactoryGirl.create(:miq_policy_set, :name => "Profile 2", :description => desc)
    }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Description has already been taken")
  end

  it "same description in different class" do
    expect {
      FactoryGirl.create(:miq_alert_set, :name => "Profile 2", :description => desc)
    }.not_to raise_error
  end
end
