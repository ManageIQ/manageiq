RSpec.describe VimPerformanceState do
  context "::Purging" do
    describe ".purge_by_orphaned" do
      it "purges all the orphaned rows for all referenced classes" do
        # Create an orphaned row referencing VmOrTemplate
        vm1      = FactoryBot.create(:vm_or_template)
        vm_perf1 = FactoryBot.create(:vim_performance_state, :resource => vm1)
        vm1.delete

        # Create a non-orphaned row referencing VmOrTemplate
        vm_perf2 = FactoryBot.create(:vim_performance_state, :resource => FactoryBot.create(:vm_or_template))

        # Create an orphaned row referencing ExtManagementSystem
        ems1      = FactoryBot.create(:ext_management_system)
        ems_perf1 = FactoryBot.create(:vim_performance_state, :resource => ems1)
        ems1.delete

        # Create a non-orphaned row referencing ExtManagementSystem
        ems_perf2 = FactoryBot.create(:vim_performance_state, :resource => FactoryBot.create(:ext_management_system))

        expect(described_class.all).to match_array([vm_perf1, vm_perf2, ems_perf1, ems_perf2])
        count = described_class.purge_by_orphaned("resource")
        expect(described_class.all).to match_array([vm_perf2, ems_perf2])
        expect(count).to eq(2)
      end
    end

    describe ".purge_timer" do
      it "queues the correct purge method" do
        EvmSpecHelper.local_miq_server
        stub_settings_merge(:vim_performance_states => {:history => {:keep_states => "6.months"}})
        described_class.purge_timer

        expect(MiqQueue.count).to eq(2)
        q1, q2 = MiqQueue.order(:id).to_a
        expect(q1).to have_attributes(:class_name => described_class.name, :method_name => "purge_by_orphaned", :args => ["resource"])
        expect(q2).to have_attributes(:class_name => described_class.name, :method_name => "purge_by_date")
        expect(q2.args.first).to be_within(2.days).of 6.months.ago.utc
      end
    end
  end
end
