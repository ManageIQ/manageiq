RSpec.describe VimPerformanceState do
  context "::Purging" do
    describe ".purge_by_orphaned" do
      before do
        # Create an orphaned row referencing VmOrTemplate
        vm1      = FactoryBot.create(:vm_or_template)
        @vm_perf1 = FactoryBot.create(:vim_performance_state, :resource => vm1)
        vm1.delete

        # Create a non-orphaned row referencing VmOrTemplate
        @vm_perf2 = FactoryBot.create(:vim_performance_state, :resource => FactoryBot.create(:vm_or_template))

        # Create an orphaned row referencing ExtManagementSystem
        ems1      = FactoryBot.create(:ext_management_system)
        @ems_perf1 = FactoryBot.create(:vim_performance_state, :resource => ems1)
        ems1.delete

        # Create a non-orphaned row referencing ExtManagementSystem
        @ems_perf2 = FactoryBot.create(:vim_performance_state, :resource => FactoryBot.create(:ext_management_system))
        expect(described_class.all).to match_array([@vm_perf1, @vm_perf2, @ems_perf1, @ems_perf2])
      end

      it "purges all the orphaned rows for all referenced classes" do
        count = described_class.purge_by_orphaned("resource")
        expect(described_class.all).to match_array([@vm_perf2, @ems_perf2])
        expect(count).to eq(2)
      end

      it "count purge_mode returns count of the orphaned rows for all referenced classes without actually purging" do
        count = described_class.purge_by_orphaned("resource", 1000, :count)
        expect(described_class.all).to match_array([@vm_perf1, @vm_perf2, @ems_perf1, @ems_perf2])
        expect(count).to eq(2)
      end
    end

    describe ".purge_timer" do
      it "queues the correct purge method" do
        EvmSpecHelper.local_miq_server
        stub_settings_merge(:vim_performance_states => {:history => {:keep_states => "6.months"}})
        described_class.purge_timer

        expect(MiqQueue.count).to eq(1)
        q = MiqQueue.first
        expect(q).to have_attributes(:class_name => described_class.name, :method_name => "purge_by_date_and_orphaned")
        expect(q.args.first).to be_within(2.days).of 6.months.ago.utc
        expect(q.args.last).to eq("resource")
      end
    end
  end
end
