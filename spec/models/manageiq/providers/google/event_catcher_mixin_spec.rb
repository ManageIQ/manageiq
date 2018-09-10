describe ManageIQ::Providers::Google::EventCatcherMixin do
  include described_class
  let(:resource_id) {}
  let(:type) {}
  let(:subtype) {}
  let(:event) do
    {
      'jsonPayload' => {
        'event_type'    => type,
        'event_subtype' => subtype,
        'resource'      => { 'id' => resource_id }
      }
    }
  end

  describe ".parse_event_type" do
    subject { parse_event_type(event) }

    context "proper event_type" do
      let(:type) { "GCE_OPERATION_DONE" }

      it { is_expected.to eq "GceOperationDone_unknown" }
    end

    context "proper event_subtype" do
      let(:subtype) { "compute.instances.delete" }

      it { is_expected.to eq "Unknown_compute.instances.delete" }
    end

    context "fully specified event" do
      let(:type) { "GCE_OPERATION_DONE" }
      let(:subtype) { "compute.instances.delete" }

      it { is_expected.to eq "GceOperationDone_compute.instances.delete" }
    end

    context "event_type and event_subtype missing" do
      it { is_expected.to eq "Unknown_unknown" }
    end
  end

  describe ".parse_resource_id" do
    subject { parse_resource_id(event) }

    context "resource_id is nill" do
      it { is_expected.to eq "unknown" }
    end

    context "with resource_id" do
      let(:resource_id) { "1925828475519697814" }

      it { is_expected.to eq resource_id }
    end
  end
end
