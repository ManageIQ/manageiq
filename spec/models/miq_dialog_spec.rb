describe MiqDialog do
  context '.seed' do
    it 'seeds from the core with correct metadata' do
      root = Rails.root.join(described_class::DIALOG_DIR)
      allow(described_class).to receive(:find_by)

      expect(described_class).to receive(:sync_from_file).at_least(:once).with(/^#{root}/, root).and_call_original

      described_class.seed

      expect(described_class).to have_received(:find_by).once.with(
        :name => "miq_host_provision_dialogs", :filename => "miq_host_provision_dialogs.yaml"
      )
    end

    it 'seed from plugins' do
      mock_engine = double(:root => Pathname.new('/some/root'))
      allow(Vmdb::Plugins.instance).to receive(:registered_provider_plugins).and_return([mock_engine])
      allow(described_class).to receive(:sync_from_dir)

      described_class.seed

      expect(described_class).to have_received(:sync_from_dir).at_least(:once).with(mock_engine.root)
    end
  end
end
