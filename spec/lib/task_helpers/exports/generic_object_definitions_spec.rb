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
        :attributes => {}, :attribute_constraints=>{}, :associations => {}, :methods => []
      )
    end
  end

  context 'when there is nothing to export' do
    it 'export no definitions' do
      TaskHelpers::Exports::GenericObjectDefinitions.new.export(:directory => export_dir)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(0)
    end
  end

  context 'when exporting definitions with attribute constraints' do
    let(:god_filename) { "#{export_dir}/#{@god.name}.yaml" }

    before do
      @god = FactoryBot.create(
        :generic_object_definition,
        :name        => 'ProductDefinition',
        :description => 'Product with constraints',
        :properties  => {
          :attributes            => {
            'name'     => :string,
            'sku'      => :string,
            'priority' => :integer,
            'price'    => :float,
            'active'   => :boolean
          },
          :attribute_constraints => {
            'name'     => {:required => true, :min_length => 3, :max_length => 100},
            'sku'      => {:required => true, :format => /\A[A-Z]{3}-\d{6}\z/},
            'priority' => {:enum => [1, 2, 3, 4, 5]},
            'price'    => {:min => 0.0, :max => 999999.99},
            'active'   => {:required => true}
          },
          :associations          => {},
          :methods               => []
        }
      )
    end

    it 'exports definition with attribute constraints' do
      TaskHelpers::Exports::GenericObjectDefinitions.new.export(:directory => export_dir)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(1)
      
      god_yaml = YAML.load_file(god_filename)
      expect(god_yaml.first["GenericObjectDefinition"]["name"]).to eq(@god.name)
      expect(god_yaml.first["GenericObjectDefinition"]["description"]).to eq(@god.description)
      expect(god_yaml.first["GenericObjectDefinition"]["properties"]).to eq(@god.properties)
      
      # Verify attribute constraints are exported
      exported_constraints = god_yaml.first["GenericObjectDefinition"]["properties"][:attribute_constraints]
      expect(exported_constraints).to be_present
      expect(exported_constraints['name']).to include(:required => true, :min_length => 3, :max_length => 100)
      expect(exported_constraints['sku']).to include(:required => true, :format => /\A[A-Z]{3}-\d{6}\z/)
      expect(exported_constraints['priority']).to include(:enum => [1, 2, 3, 4, 5])
      expect(exported_constraints['price']).to include(:min => 0.0, :max => 999999.99)
      expect(exported_constraints['active']).to include(:required => true)
    end
  end
end
