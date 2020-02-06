RSpec.describe MiqTask do
  context "::Purging" do
    describe ".purge_by_date" do
      before do
        Timecop.freeze(8.days.ago) do
          @old_task = VmScan.create_job(:guid => "old").miq_task
          FactoryBot.create(:binary_blob, :name => "old", :resource_type => 'MiqTask', :resource_id => @old_task.id)
          FactoryBot.create(:log_file, :name => "old", :miq_task_id => @old_task.id)
        end

        Timecop.freeze(6.days.ago) do
          @new_task = VmScan.create_job(:guid => "recent").miq_task
          @new_task.state_finished
          FactoryBot.create(:binary_blob, :name => "recent", :resource_type => 'MiqTask', :resource_id => @new_task.id)
          FactoryBot.create(:log_file, :name => "recent", :miq_task_id => @new_task.id)
        end
      end

      it "purges old finished tasks" do
        @old_task.state_finished
        expect(described_class.all).to match_array([@old_task, @new_task])

        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.all).to match_array([@new_task])
        expect(BinaryBlob.count).to eq(1)
        expect(BinaryBlob.first.name).to eq("recent")
        expect(LogFile.count).to eq(1)
        expect(LogFile.first.name).to eq("recent")
        expect(Job.count).to eq(1)
        expect(Job.first.guid).to eq("recent")
      end

      it "does not purge old not finished tasks" do
        @old_task.state_active
        described_class.purge_by_date(described_class.purge_date)
        expect(described_class.all).to match_array([@old_task, @new_task])
      end
    end

    describe ".purge_timer" do
      it "queues the correct purge method" do
        EvmSpecHelper.local_miq_server
        described_class.purge_timer
        q = MiqQueue.first
        expect(q).to have_attributes(:class_name => described_class.name, :method_name => "purge_by_date")
      end
    end
  end
end
