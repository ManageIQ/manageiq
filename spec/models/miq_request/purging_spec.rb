RSpec.describe MiqRequest do
  let(:user) { FactoryBot.create(:user) }
  context "::Purging" do
    describe ".purge_by_date" do
      before do
        Timecop.freeze(7.months.ago) do
          @old_request = FactoryBot.create(:vm_migrate_request, :requester => user)
          FactoryBot.create(:miq_request_task, :miq_request => @old_request)
          parent_task = FactoryBot.create(:miq_request_task, :miq_request => @old_request)
          FactoryBot.create(:miq_request_task, :miq_request_task => parent_task)
          FactoryBot.create(:miq_approval, :miq_request => @old_request)
          FactoryBot.create(:request_log, :resource => @old_request)
        end

        Timecop.freeze(6.days.ago) do
          @new_request = FactoryBot.create(:vm_migrate_request, :requester => user)
          @new_parent_task = FactoryBot.create(:miq_request_task, :miq_request => @new_request)
          @new_child_task = FactoryBot.create(:miq_request_task, :miq_request_task => @new_parent_task)
          FactoryBot.create(:miq_approval, :miq_request => @new_request)
          FactoryBot.create(:request_log, :resource => @new_request)
        end
      end

      it "deletes rows and associated table rows, leaving only newer rows" do
        expect(described_class.all).to match_array([@old_request, @new_request])
        expect(MiqRequestTask.count).to eq(5)
        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.all).to match_array([@new_request])
        expect(MiqRequestTask.all.pluck(:id)).to match_array([@new_parent_task.id, @new_child_task.id])
        expect(MiqApproval.all.pluck(:id)).to match_array(@new_request.reload.miq_approval_ids) # there's a default approval created for each request, so just check ids
        expect(RequestLog.all.pluck(:id)).to eq(@new_request.request_log_ids)
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
