require "spec_helper"

describe BottleneckEvent do
  describe ".future_event_definitions_for_obj" do
    it "contains things" do
      MiqEvent.seed_default_definitions
      expect(BottleneckEvent.future_event_definitions_for_obj(HostVmware.new)).not_to be_empty
    end
  end
end
