describe TreeBuilderAeCustomization  do
  let(:sandbox) { {} }

  describe "#init_tree" do
    let(:expected_sandbox_values) do
      {
        :tree        => :dialog_import_export_tree,
        :type        => :dialog_import_export,
        :klass_name  => "TreeBuilderAeCustomization",
        :leaf        => nil,
        :add_root    => true,
        :open_nodes  => [],
        :lazy        => true,
        :open_all    => true,
        :active_node => "root"
      }
    end

    before do
      TreeBuilderAeCustomization.new("dialog_import_export_tree", "dialog_import_export", sandbox)
    end

    it "stores values into the sandbox" do
      expect(sandbox[:trees][:dialog_import_export_tree]).to eq(expected_sandbox_values)
    end
  end
end
