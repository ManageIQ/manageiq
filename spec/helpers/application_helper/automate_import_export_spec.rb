describe ApplicationHelper::AutomateImportExport do
  describe "#git_import_submit_help" do
    let(:my_region) { double("MiqRegion") }

    before do
      allow(MiqRegion).to receive(:my_region).and_return(my_region)
      allow(my_region).to receive(:role_active?).with("git_owner").and_return(active_git_owner)
    end

    context "when the MiqRegion has an active git_owner role" do
      let(:active_git_owner) { true }

      it "renders nothing" do
        expect(helper.git_import_submit_help).to eq(nil)
      end
    end

    context "when the MiqRegion does not have an active git_owner role" do
      let(:active_git_owner) { false }

      it "renders an i tag with a title and class" do
        expect(helper.git_import_submit_help).to eq("<i class=\"fa fa-lg fa-question-circle\" title=\"Git Owner role is not enabled, enable it in Settings -&gt; Configuration\"></i>")
      end
    end
  end
end
