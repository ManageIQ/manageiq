require 'spec_helper'

require 'schedule_worker'

describe ScheduleWorker::Jobs do
  context "#ems_refresh_timer" do
    it "with no EMSes" do
      described_class.new.ems_refresh_timer(EmsVmware)

      expect(MiqQueue.count).to eq(0)
    end

    it "with an EMS" do
      _, _, zone = EvmSpecHelper.create_guid_miq_server_zone
      FactoryGirl.create(:ems_vmware, :zone => zone)
      described_class.new.ems_refresh_timer(EmsVmware)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first).to have_attributes(
        :class_name  => "EmsVmware",
        :instance_id => nil,
        :method_name => "refresh_all_ems_timer",
        :zone        => zone.name
      )
    end
  end
end
