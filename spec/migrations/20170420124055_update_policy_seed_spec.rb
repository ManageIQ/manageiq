require_migration

describe UpdatePolicySeed do
  migration_context :up do
    let(:miq_policy) { migration_stub(:MiqPolicy) }

    it "updates null fields only" do
      first = miq_policy.create!(:mode => 'compliance')
      second = miq_policy.create!(:towhat => 'Host', :active => false)
      migrate

      first.reload
      second.reload

      expect(first).to have_attributes(:mode => 'compliance', :towhat => 'Vm', :active => true)
      expect(second).to have_attributes(:mode => 'control', :towhat => 'Host', :active => false)
    end
  end
end
