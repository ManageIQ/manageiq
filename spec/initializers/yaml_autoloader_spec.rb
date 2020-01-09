require 'fileutils'
require 'pathname'

describe Psych::Visitors::ToRuby do
  let(:model_directory) { Pathname.new(Dir.mktmpdir("yaml_autoloader")) }
  let(:missing_model)   { model_directory.join("zzz_model.rb") }

  before do
    File.write(missing_model, "class ZzzModel\nend\n")
    ActiveSupport::Dependencies.autoload_paths << model_directory
  end

  after do
    FileUtils.rm_f(missing_model)
    ActiveSupport::Dependencies.autoload_paths.reject! { |p| p == model_directory }
    Object.send(:remove_const, "ZzzModel") if Object.const_defined?("ZzzModel")
  end

  it "YAML.load autoloads missing constants" do
    dump = "--- !ruby/object:ZzzModel {}\n"
    expect(YAML.load(dump).class.name).to eql "ZzzModel"
  end

  it "YAML.safe_load does not autoload missing constants" do
    dump = "--- !ruby/object:ZzzModel {}\n"
    expect(YAML.load(dump).class.name).to eql "ZzzModel"
    expect { YAML.safe_load(dump) }.to raise_error(Psych::DisallowedClass)
  end
end
