require 'spec_helper'
require 'vmdb/permission_stores'
require 'tempfile'

describe Vmdb::PermissionStores do
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

      expect(required_file).to eq('permission_stores/yaml')
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

# backport so that tests will run on 1.9 and 2.0.0
unless Tempfile.respond_to? :create
  def Tempfile.create(basename, *rest)
    tmpfile = nil
    Dir::Tmpname.create(basename, *rest) do |tmpname, n, opts|
      mode = File::RDWR|File::CREAT|File::EXCL
      perm = 0600
      if opts
        mode |= opts.delete(:mode) || 0
        opts[:perm] = perm
        perm = nil
      else
        opts = perm
      end
      tmpfile = File.open(tmpname, mode, opts)
    end
    if block_given?
      begin
        yield tmpfile
      ensure
        tmpfile.close if !tmpfile.closed?
        File.unlink tmpfile
      end
    else
      tmpfile
    end
  end
end
