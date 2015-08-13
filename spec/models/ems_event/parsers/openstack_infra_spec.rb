require "spec_helper"

describe ManageIQ::Providers::Openstack::InfraManager::EventParser do

  context ".event_to_hash" do
    it "with a compute.instance.create.end event" do
      event = YAML.load_file(File.join(data_dir, 'compute_instance_create_end.yml'))
      data = described_class.event_to_hash(event, 123)

      expected_attributes = common_attributes(event).merge(
        :event_type   => "compute.instance.create.end",
        :chain_id     => "r-otxomvqw",
        :timestamp    => "2015-05-12 07:24:39.462895",
        :host_ems_ref => "cdab9a8d-d653-4dee-81f9-173f9a22bd2e",
        :message      => "Success"
      )

      data.should have_attributes(expected_attributes)

      data[:full_data].should    be_instance_of Hash
      data[:host_ems_ref].should be_instance_of String
    end

    it "with a compute.instance.create.error event" do
      event = YAML.load_file(File.join(data_dir, 'compute_instance_create_error.yml'))
      data = described_class.event_to_hash(event, 123)

      expected_attributes = common_attributes(event).merge(
        :event_type   => "compute.instance.create.error",
        :chain_id     => "r-36dfs67z",
        :timestamp    => "2015-05-12 07:22:19.122336",
        :host_ems_ref => "b94ebb7a-34f2-4146-94c3-5bbc46b4d5ff",
        :message      => "Failed to provision instance 3a0c66d5-d762-4b60-b604-850bc9a13cff: Failed to deploy. Error:" \
                         " Failed to execute command via SSH: LC_ALL=C /usr/bin/virsh --connect qemu:///system start"\
                         " baremetal_2."
      )

      data.should have_attributes(expected_attributes)

      data[:full_data].should    be_instance_of Hash
      data[:host_ems_ref].should be_instance_of String
    end

    it "with an orchestration.stack.create.end event" do
      event = YAML.load_file(File.join(data_dir, 'orchestration_stack_create_end.yml'))
      data = described_class.event_to_hash(event, 123)

      expected_attributes = common_attributes(event).merge(
        :event_type => "orchestration.stack.create.end",
        :timestamp  => "2015-05-12 07:24:45.026776"
      )

      data.should have_attributes(expected_attributes)

      data[:full_data].should be_instance_of Hash
    end

    it "with an orchestration.stack.update.end event" do
      event = YAML.load_file(File.join(data_dir, 'orchestration_stack_update_end.yml'))
      data = described_class.event_to_hash(event, 123)

      expected_attributes = common_attributes(event).merge(
        :event_type => "orchestration.stack.update.end",
        :timestamp  => "2015-05-12 07:33:57.772136"
      )

      data.should have_attributes(expected_attributes)

      data[:full_data].should be_instance_of Hash
    end

    it "with a port.create.end event" do
      event = YAML.load_file(File.join(data_dir, 'port_create_end.yml'))
      data = described_class.event_to_hash(event, 123)

      expected_attributes = common_attributes(event).merge(
        :event_type => "port.create.end",
        :timestamp  => "2015-05-12 07:22:37.008738"
      )

      data.should have_attributes(expected_attributes)

      data[:full_data].should be_instance_of Hash
    end

    it "with a port.update.end event" do
      event = YAML.load_file(File.join(data_dir, 'port_update_end.yml'))
      data = described_class.event_to_hash(event, 123)

      expected_attributes = common_attributes(event).merge(
        :event_type => "port.update.end",
        :timestamp  => "2015-05-12 07:22:43.948145"
      )

      data.should have_attributes(expected_attributes)

      data[:full_data].should be_instance_of Hash
    end
  end

  def data_dir
    File.expand_path(File.join(File.dirname(__FILE__), "data", "openstack_infra"))
  end

  def common_attributes(event)
    {
      :event_type   => "compute.instance.create.error",
      :chain_id     => nil,
      :is_task      => nil,
      :source       => "OPENSTACK",
      :message      => nil,
      :timestamp    => nil,
      :full_data    => event,
      :ems_id       => 123,
      :username     => nil,
      :vm_ems_ref   => nil,
      :vm_name      => nil,
      :vm_location  => nil,
      :host_ems_ref => nil,
      :host_name    => nil,
    }
  end
end
