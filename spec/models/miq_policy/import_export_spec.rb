RSpec.describe MiqPolicy::ImportExport do
  context '.import_from_hash' do
    it "loads attributes" do
      p_hash = {
        "name"             => "t_name",
        "description"      => "t_description",
        "expression"       => nil,
        "towhat"           => "ContainerImage",
        "guid"             => "e7a270bc-109b-11e6-86ba-02424d459b45",
        "mode"             => "control",
        "read_only"        => true,
        "MiqPolicyContent" => []
      }
      policy, _status = MiqPolicy.import_from_hash(p_hash)
      expect(policy).to have_attributes(p_hash.except("MiqPolicyContent"))
    end

    it "creates an active policy when the 'active' attribute is missing" do
      policy, _status = MiqPolicy.import_from_hash("MiqPolicyContent" => [])
      expect(policy.active).to be_truthy
    end

    it "creates an inactive policy when the 'active' attribute is true" do
      policy, _status = MiqPolicy.import_from_hash("active" => true, "MiqPolicyContent" => [])
      expect(policy.active).to be_truthy
    end

    it "creates an inactive policy when the 'active' attribute is false" do
      policy, _status = MiqPolicy.import_from_hash("active" => false, "MiqPolicyContent" => [])
      expect(policy.active).to be_falsey
    end
  end
end
