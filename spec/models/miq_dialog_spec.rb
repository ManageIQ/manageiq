describe MiqDialog do
  context '.seed' do
    it 'seeds from the core with correct metadata' do
      root = Rails.root.join('product', 'dialogs', 'miq_dialogs')
      allow(described_class).to receive(:find_by)
      allow(described_class).to receive(:sync_from_file).with(any_args)

      expect(described_class).to receive(:sync_from_file).at_least(:once).with(/^#{root}/, root).and_call_original
      expect(described_class).to receive(:find_by).once.with(
        :name => "miq_host_provision_dialogs", :filename => "miq_host_provision_dialogs.yaml"
      )

      described_class.seed
    end

    it 'seed from plugins' do
      mock_engine = double(:root => Pathname.new('/some/root'))
      allow(described_class).to receive(:sync_from_dir)

      expect(Vmdb::Plugins.instance).to receive(:vmdb_plugins).and_return([mock_engine])
      expect(described_class).to receive(:sync_from_dir).once.with(
        mock_engine.root.join('content', 'miq_dialogs')
      )

      described_class.seed
    end
  end
end
