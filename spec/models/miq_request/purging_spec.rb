RSpec.describe MiqRequest do
  let(:user) { FactoryBot.create(:user) }
  context "::Purging" do
    describe ".purge_by_date" do
      let!(:old_request) do
        Timecop.freeze(7.months.ago) do
          FactoryBot.create(:vm_migrate_request, :requester => user)
        end
      end

      let!(:old_request_task) { FactoryBot.create(:miq_request_task, :miq_request => old_request) }
      let!(:old_parent_task)  { FactoryBot.create(:miq_request_task, :miq_request => old_request) }
      let!(:old_child_task)   { FactoryBot.create(:miq_request_task, :miq_request_task => old_parent_task) }
      let!(:old_approval)     { FactoryBot.create(:miq_approval, :miq_request => old_request) }
      let!(:old_request_log)  { FactoryBot.create(:request_log, :resource => old_request) }

      let!(:new_request) do
        Timecop.freeze(6.days.ago) do
          FactoryBot.create(:vm_migrate_request, :requester => user)
        end
      end

      let!(:new_parent_task) { FactoryBot.create(:miq_request_task, :miq_request => new_request) }
      let!(:new_child_task)  { FactoryBot.create(:miq_request_task, :miq_request_task => new_parent_task) }
      let!(:new_approval)    { FactoryBot.create(:miq_approval, :miq_request => new_request) }
      let!(:new_request_log) { FactoryBot.create(:request_log, :resource => new_request) }

      it "deletes rows and associated table rows, leaving only newer rows" do
        expect(described_class.all).to match_array([old_request, new_request])
        expect(MiqRequestTask.count).to eq(5)
        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.all).to match_array([new_request])
        expect(MiqRequestTask.pluck(:id)).to match_array([new_parent_task.id, new_child_task.id])
        expect(MiqApproval.pluck(:id)).to match_array(new_request.reload.miq_approval_ids) # there's a default approval created for each request, so just check ids
        expect(RequestLog.pluck(:id)).to eq(new_request.request_log_ids)
      end

      def create_provision_task(request, destination = nil)
        FactoryBot.create(:miq_request_task, :miq_request => request, :destination => destination).tap do |task|
          task.update!(:type => "MiqProvision")
        end
      end

      it "retains old provision requests with a live provisioned vm" do
        protected_request = nil

        Timecop.freeze(7.months.ago) do
          protected_request = FactoryBot.create(:miq_provision_request, :requester => user)
          vm = FactoryBot.create(:vm_vmware, :ems_id => 1, :storage_id => 1)
          create_provision_task(protected_request, vm)
        end

        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.exists?(protected_request.id)).to be(true)
      end

      it "purges old provision requests whose provisioned vm is archived" do
        purgeable_request = nil

        Timecop.freeze(7.months.ago) do
          purgeable_request = FactoryBot.create(:miq_provision_request, :requester => user)
          vm = FactoryBot.create(:vm_vmware, :ems_id => nil, :storage_id => nil)
          create_provision_task(purgeable_request, vm)
        end

        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.exists?(purgeable_request.id)).to be(false)
      end

      it "purges old provision requests whose provisioned vm is orphaned" do
        purgeable_request = nil

        Timecop.freeze(7.months.ago) do
          purgeable_request = FactoryBot.create(:miq_provision_request, :requester => user)
          vm = FactoryBot.create(:vm_vmware, :ems_id => nil, :storage_id => 1)
          create_provision_task(purgeable_request, vm)
        end

        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.exists?(purgeable_request.id)).to be(false)
      end

      it "purges old provision requests without a provisioned vm" do
        purgeable_request = nil

        Timecop.freeze(7.months.ago) do
          purgeable_request = FactoryBot.create(:miq_provision_request, :requester => user)
          create_provision_task(purgeable_request)
        end

        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.exists?(purgeable_request.id)).to be(false)
      end

      def create_service_provision_task(request, destination = nil)
        FactoryBot.create(:miq_request_task, :miq_request => request, :destination => destination).tap do |task|
          task.update!(:type => "ServiceTemplateProvisionTask")
        end
      end

      it "retains old service provision requests with a live provisioned service" do
        protected_request = nil

        Timecop.freeze(7.months.ago) do
          protected_request = FactoryBot.create(:service_template_provision_request, :requester => user)
          service = FactoryBot.create(:service)
          create_service_provision_task(protected_request, service)
        end

        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.exists?(protected_request.id)).to be(true)
      end

      it "purges old service provision requests without a provisioned service" do
        purgeable_request = nil

        Timecop.freeze(7.months.ago) do
          purgeable_request = FactoryBot.create(:service_template_provision_request, :requester => user)
          create_service_provision_task(purgeable_request)
        end

        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.exists?(purgeable_request.id)).to be(false)
      end

      def create_physical_server_provision_task(request, destination = nil)
        FactoryBot.create(:miq_request_task, :miq_request => request, :destination => destination).tap do |task|
          task.update!(:type => "PhysicalServerProvisionTask")
        end
      end

      it "retains old physical server provision requests with a live provisioned server" do
        protected_request = nil

        Timecop.freeze(7.months.ago) do
          protected_request = FactoryBot.create(:physical_server_provision_request, :requester => user)
          physical_server = FactoryBot.create(:physical_server, :ems_id => 1)
          create_physical_server_provision_task(protected_request, physical_server)
        end

        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.exists?(protected_request.id)).to be(true)
      end

      it "purges old physical server provision requests whose provisioned server is orphaned" do
        purgeable_request = nil

        Timecop.freeze(7.months.ago) do
          purgeable_request = FactoryBot.create(:physical_server_provision_request, :requester => user)
          physical_server = FactoryBot.create(:physical_server, :ems_id => nil)
          create_physical_server_provision_task(purgeable_request, physical_server)
        end

        described_class.purge_by_date(described_class.purge_date)

        expect(described_class.exists?(purgeable_request.id)).to be(false)
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
