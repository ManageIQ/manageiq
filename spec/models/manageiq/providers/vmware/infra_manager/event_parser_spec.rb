require "spec_helper"

describe ManageIQ::Providers::Vmware::InfraManager::EventParser do
  EPV_DATA_DIR = File.expand_path(File.join(File.dirname(__FILE__), "event_data"))

  context ".event_to_hash" do
    it "with a GeneralUserEvent" do
      event = YAML.load_file(File.join(EPV_DATA_DIR, 'general_user_event.yml'))
      data = described_class.event_to_hash(event, 12345)

      data.should have_attributes(
        :event_type   => "GeneralUserEvent",
        :chain_id     => "5361104",
        :is_task      => false,
        :source       => "VC",
        :message      => "User logged event: EVM SmartState Analysis completed for VM [tch-UBUNTU-904-LTS-DESKTOP]",
        :timestamp    => "2010-08-24T01:08:10.396636Z",
        :full_data    => event,
        :ems_id       => 12345,
        :username     => "MANAGEIQ\\thennessy",

        :vm_ems_ref   => "vm-106741",
        :vm_name      => "tch-UBUNTU-904-LTS-DESKTOP",
        :vm_location  => "[msan2] tch-UBUNTU-904-LTS-DESKTOP/tch-UBUNTU-904-LTS-DESKTOP.vmx",
        :host_ems_ref => "host-106569",
        :host_name    => "yoda.manageiq.com",
      )

      data[:full_data].should    be_instance_of VimHash
      data[:vm_ems_ref].should   be_instance_of String
      data[:host_ems_ref].should be_instance_of String
    end

    context "with an EventEx event" do
      it "with an eventTypeId" do
        event = YAML.load_file(File.join(EPV_DATA_DIR, 'event_ex.yml'))
        data = described_class.event_to_hash(event, 12345)

        assert_result_fields(data, event)
        data.should have_attributes(
          :event_type => "vprob.vmfs.resource.corruptondisk",
          :message    => "event.vprob.vmfs.resource.corruptondisk.fullFormat (vprob.vmfs.resource.corruptondisk)"
        )
      end

      it "without an eventTypeId" do
        event = YAML.load_file(File.join(EPV_DATA_DIR, 'event_ex_without_eventtypeid.yml'))
        data = described_class.event_to_hash(event, 12345)

        assert_result_fields(data, event)
        data.should have_attributes(
          :event_type => "EventEx",
          :message    => ""
        )
      end

      def assert_result_fields(data, event)
        data.should have_attributes(
          :chain_id     => "297179",
          :is_task      => false,
          :source       => "VC",
          :timestamp    => "2010-11-12T17:15:42.661128Z",
          :full_data    => event,
          :ems_id       => 12345,
          :username     => nil,

          :vm_ems_ref   => nil,
          :vm_name      => nil,
          :vm_location  => nil,
          :host_ems_ref => "host-29",
          :host_name    => "vi4esx1.galaxy.local",
        )

        data[:full_data].should    be_instance_of VimHash
        data[:host_ems_ref].should be_instance_of String
      end
    end
  end
end

