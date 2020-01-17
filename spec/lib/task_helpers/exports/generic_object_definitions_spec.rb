RSpec.describe TaskHelpers::Exports::GenericObjectDefinitions do
  let(:export_dir) do
    Dir.mktmpdir('miq_exp_dir')
  end

  after do
    FileUtils.remove_entry export_dir
  end

  context 'when there is something to export' do
    let(:god_filename1) { "#{export_dir}/#{@god1.name}.yaml" }
    let(:god_filename2) { "#{export_dir}/#{@god2.name}.yaml" }

    before do
      @god1 = FactoryBot.create(:generic_object_definition, :with_methods_attributes_associations, :description => 'god_description')
      @god2 = FactoryBot.create(:generic_object_definition)
    end

    it 'export all definitions' do
      TaskHelpers::Exports::GenericObjectDefinitions.new.export(:directory => export_dir)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(2)
      god1_yaml = YAML.load_file(god_filename1)
      expect(god1_yaml.first["GenericObjectDefinition"]["name"]).to eq(@god1.name)
      expect(god1_yaml.first["GenericObjectDefinition"]["description"]).to eq(@god1.description)
      expect(god1_yaml.first["GenericObjectDefinition"]["properties"]).to eq(@god1.properties)

      god2_yaml = YAML.load_file(god_filename2)
      expect(god2_yaml.first["GenericObjectDefinition"]["name"]).to eq(@god2.name)
      expect(god2_yaml.first["GenericObjectDefinition"]["description"]).to eq(nil)
      expect(god2_yaml.first["GenericObjectDefinition"]["properties"]).to eq(
        :attributes => {}, :associations => {}, :methods => []
      )
    end
  end

  context 'when there is nothing to export' do
    it 'export no definitions' do
      TaskHelpers::Exports::GenericObjectDefinitions.new.export(:directory => export_dir)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(0)
    end
  end
end
