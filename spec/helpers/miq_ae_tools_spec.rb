describe MiqAeToolsHelper do
  describe "#git_import_button_enabled?" do
    let(:my_region) { double("MiqRegion") }

    before do
      allow(MiqRegion).to receive(:my_region).and_return(my_region)
      allow(my_region).to receive(:role_active?).with("git_owner").and_return(active_git_owner)
    end

    context "when the MiqRegion has an active git_owner role" do
      let(:active_git_owner) { true }

      it "returns true" do
        expect(helper.git_import_button_enabled?).to eq(true)
      end
    end

    context "when the MiqRegion does not have an active git_owner role" do
      let(:active_git_owner) { false }

      it "returns false" do
        expect(helper.git_import_button_enabled?).to eq(false)
      end
    end
  end

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
        expect(helper.git_import_submit_help).to eq("<i class=\"fa fa-lg fa-question-circle\" title=\"Please enable the git owner role in order to import git repositories\"></i>")
      end
    end
  end
end
