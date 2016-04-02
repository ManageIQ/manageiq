describe MiqPolicySet do
  context ".seed" do
    it "should contain policy sets" do
      MiqPolicy.seed
      MiqPolicySet.seed
      specifications = YAML.load_file(File.join(ApplicationRecord::FIXTURE_DIR, "miq_policy_sets.yml"))
      specifications.reverse!
      MiqPolicySet.all.each do |mps|
        spec = specifications.pop
        miq_policies = mps.miq_policies
        expect(mps).to have_attributes(spec.except(:miq_policies))

        miq_policies.each_with_index do |miq_policy, index|
          expect(miq_policy).to eq(MiqPolicy.find_by_guid(spec[:miq_policies][index]))
        end
      end
    end
  end
end
