RSpec.describe ResourceActionSerializer do
  let(:resource_action_serializer) { described_class.new }

  describe "#serialize" do
    let(:resource_action) { ResourceAction.new(expected_serialized_values) }

    let(:expected_serialized_values) do
      {
        "resource_type" => "DialogField",
        "ae_namespace"  => "Customer/Sample",
        "ae_class"      => "Methods",
        "ae_instance"   => "Testing",
      }
    end

    it "serializes the resource_action" do
      serialized = resource_action_serializer.serialize(resource_action)
      expect(serialized).to include(expected_serialized_values)
      expect(serialized.keys).to include("action", "ae_attributes", "ae_message")
      expect(serialized.keys).not_to include(*described_class::EXCLUDED_ATTRIBUTES)
    end
  end
end
