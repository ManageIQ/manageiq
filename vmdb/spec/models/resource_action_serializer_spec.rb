require "spec_helper"

describe ResourceActionSerializer do
  let(:resource_action_serializer) { described_class.new }

  describe "#serialize" do
    let(:resource_action) do
      ResourceAction.new(
        :dialog_id     => 123,
        :resource_id   => 321,
        :created_at    => Time.now,
        :updated_at    => Time.now,
        :resource_type => "DialogField",
        :ae_namespace  => "Customer/Sample",
        :ae_class      => "Methods",
        :ae_instance   => "Testing"
      )
    end

    let(:expected_serialized_values) do
      {
        "action"        => nil,
        "resource_type" => "DialogField",
        "ae_namespace"  => "Customer/Sample",
        "ae_class"      => "Methods",
        "ae_instance"   => "Testing",
        "ae_message"    => nil,
        "ae_attributes" => {}
      }
    end

    it "serializes the resource_action" do
      resource_action_serializer.serialize(resource_action).should == expected_serialized_values
    end
  end
end
