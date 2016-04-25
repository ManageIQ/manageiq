describe Vmdb::PermissionStores do
  it 'should be configurable' do
    stub_vmdb_permission_store do
      Vmdb::PermissionStores.configure do |config|
        config.backend = 'yaml'
        config.options[:filename] = 'some file'
      end
      config = Vmdb::PermissionStores.configuration

      expect(config.backend).to eq('yaml')
      expect(config.options[:filename]).to eq('some file')
    end
  end

  context 'configuration' do
    it 'requires the backend' do
      stub_vmdb_permission_store do
        required_file = nil

        klass = Class.new(Vmdb::PermissionStores::Configuration) do
          define_method(:require) do |file|
            required_file = file
          end
        end

        config = klass.new
        config.backend = 'yaml'
        config.load

        expect(required_file).to eq('vmdb/permission_stores/yaml')
      end
    end

    it 'can initialize the yaml back end' do
      stub_vmdb_permission_store do
        Tempfile.create(%w(config yml)) do |f|
          f.write(['foo'].to_yaml)
          f.close

          config = Vmdb::PermissionStores::Configuration.new
          config.backend = 'yaml'
          config.options[:filename] = f.path
          config.load
          expect(config.create).to be_truthy
        end
      end
    end
  end

  describe '::YAML' do
    it '#can?' do
      stub_vmdb_permission_store_with_types(["foo"]) do
        instance = Vmdb::PermissionStores.instance
        expect(instance.can?('foo')).to be_truthy
        expect(instance.can?('bar')).to be_falsey
      end
    end

    it '#supported_ems_type?' do
      stub_vmdb_permission_store_with_types(["ems-type:foo"]) do
        instance = Vmdb::PermissionStores.instance
        expect(instance.supported_ems_type?('foo')).to be_truthy
        expect(instance.supported_ems_type?('bar')).to be_falsey
      end
    end
  end
end
