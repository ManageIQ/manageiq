describe MiqPolicyContent do
  context ".seed" do
    it "should contain conditions" do
      [MiqAction, MiqEventDefinition, Condition, MiqPolicy, MiqPolicyContent].each(&:seed)

      specifications = YAML.load_file(File.join(ApplicationRecord::FIXTURE_DIR, "#{MiqPolicyContent.table_name}.yml"))
      specifications.reverse!
      MiqPolicyContent.all.each do |mpc|
        spec = specifications.pop
        expect(mpc).to have_attributes(
          spec.except(:created_on, :updated_on, :miq_policy_guid, :miq_action_name, :miq_event_definition_name)
        )
        expect(mpc.miq_policy.guid).to eq(spec[:miq_policy_guid])
      end
    end
  end
end
