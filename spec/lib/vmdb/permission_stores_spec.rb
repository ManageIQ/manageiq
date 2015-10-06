require 'spec_helper'
require 'vmdb/permission_stores'
require 'tempfile'

describe Vmdb::PermissionStores do
  before(:each) do
    @original_store = Vmdb::PermissionStores.instance
  end

  after(:each) do
    Vmdb::PermissionStores.instance = @original_store
  end

  it 'should be configurable' do
    Vmdb::PermissionStores.configure do |config|
      config.backend = 'yaml'
      config.options[:filename] = 'some file'
    end
    config = Vmdb::PermissionStores.configuration

    expect(config.backend).to eq('yaml')
    expect(config.options[:filename]).to eq('some file')
  end

  context 'configuration' do
    it 'requires the backend' do
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

    it 'can initialize the yaml back end' do
      Tempfile.create(['config', 'yml']) do |f|
        f.write Psych.dump(['foo'])
        f.close

        config = Vmdb::PermissionStores::Configuration.new
        config.backend = 'yaml'
        config.options[:filename] = f.path
        config.load
        expect(config.create).to be
      end
    end
  end

  context 'backend' do
    it 'can be asked about permissions' do
      Tempfile.create(['config', 'yml']) do |f|
        f.write Psych.dump(['foo'])
        f.close

        Vmdb::PermissionStores.configure do |config|
          config.backend = 'yaml'
          config.options[:filename] = f.path
        end

        Vmdb::PermissionStores.initialize!
        instance = Vmdb::PermissionStores.instance
        expect(instance.can?('foo')).to be_true
        expect(instance.can?('bar')).to be_false
      end
    end
  end
end
