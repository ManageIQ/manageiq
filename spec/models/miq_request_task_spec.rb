RSpec.describe MiqRequestTask do
  describe ".with_destination" do
    it "filters by destination_type and joins destination table for VmOrTemplate" do
      vm = FactoryBot.create(:vm_vmware)
      service = FactoryBot.create(:service)

      task_with_vm = FactoryBot.create(:miq_request_task, :destination => vm)
      task_with_service = FactoryBot.create(:miq_request_task, :destination => service)
      task_without_destination = FactoryBot.create(:miq_request_task)

      result = described_class.with_destination('VmOrTemplate')

      expect(result).to include(task_with_vm)
      expect(result).not_to include(task_with_service)
      expect(result).not_to include(task_without_destination)
    end

    it "works with Service type" do
      service = FactoryBot.create(:service)
      task_with_service = FactoryBot.create(:miq_request_task, :destination => service)
      task_without_destination = FactoryBot.create(:miq_request_task)

      result = described_class.with_destination('Service')

      expect(result).to include(task_with_service)
      expect(result).not_to include(task_without_destination)
    end

    it "works with PhysicalServer type" do
      physical_server = FactoryBot.create(:physical_server)
      task_with_server = FactoryBot.create(:miq_request_task, :destination => physical_server)
      task_without_destination = FactoryBot.create(:miq_request_task)

      result = described_class.with_destination('PhysicalServer')

      expect(result).to include(task_with_server)
      expect(result).not_to include(task_without_destination)
    end
  end

  describe ".having_request" do
    it "returns only tasks with a miq_request_id" do
      request = FactoryBot.create(:miq_provision_request, :requester => FactoryBot.create(:user))
      task_with_request = FactoryBot.create(:miq_request_task, :miq_request => request)
      task_without_request = FactoryBot.create(:miq_request_task, :miq_request_id => nil)

      result = described_class.having_request

      expect(result).to include(task_with_request)
      expect(result).not_to include(task_without_request)
    end
  end
end
