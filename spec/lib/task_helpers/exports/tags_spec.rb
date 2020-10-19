RSpec.describe TaskHelpers::Exports::Tags do
  let(:parent)      { FactoryBot.create(:classification, :name => "export_test_category",   :description => "Export Test") }
  let(:def_parent)  { FactoryBot.create(:classification, :name => "default_test_category",  :description => "Default Export Test",   :default => true) }
  let(:def_parent2) { FactoryBot.create(:classification, :name => "default_test2_category", :description => "Default Export Test 2", :default => true) }
  let(:export_dir)  { Dir.mktmpdir('miq_exp_dir') }

  let(:tag_export_test) do
    [{"description"  => "Export Test",
      "icon"         => nil,
      "read_only"    => false,
      "syntax"       => "string",
      "single_value" => false,
      "example_text" => nil,
      "show"         => true,
      "default"      => nil,
      "perf_by_tag"  => nil,
      "name"         => "export_test_category",
      "entries"      => array_including([{"description"  => "Test Entry",
                                          "icon"         => nil,
                                          "read_only"    => false,
                                          "syntax"       => "string",
                                          "single_value" => false,
                                          "example_text" => nil,
                                          "show"         => true,
                                          "default"      => nil,
                                          "perf_by_tag"  => nil,
                                          "name"         => "test_entry"},
                                         {"description"  => "Another Test Entry",
                                          "icon"         => nil,
                                          "read_only"    => false,
                                          "syntax"       => "string",
                                          "single_value" => false,
                                          "example_text" => nil,
                                          "show"         => true,
                                          "default"      => nil,
                                          "perf_by_tag"  => nil,
                                          "name"         => "another_test_entry"}])}]
  end

  let(:tag_default_export_test) do
    [{"description"  => "Default Export Test",
      "icon"         => nil,
      "read_only"    => false,
      "syntax"       => "string",
      "single_value" => false,
      "example_text" => nil,
      "show"         => true,
      "default"      => true,
      "perf_by_tag"  => nil,
      "name"         => "default_test_category",
      "entries"      => array_including([{"description"  => "Default Test Entry",
                                          "icon"         => nil,
                                          "read_only"    => false,
                                          "syntax"       => "string",
                                          "single_value" => false,
                                          "example_text" => nil,
                                          "show"         => true,
                                          "default"      => true,
                                          "perf_by_tag"  => nil,
                                          "name"         => "def_test_entry"}])}]
  end

  let(:tag_default_export_test_2) do
    [{"description"  => "Default Export Test 2",
      "icon"         => nil,
      "read_only"    => false,
      "syntax"       => "string",
      "single_value" => false,
      "example_text" => nil,
      "show"         => true,
      "default"      => true,
      "perf_by_tag"  => nil,
      "name"         => "default_test2_category",
      "entries"      => array_including([{"description"  => "Default Test Entry 2",
                                          "icon"         => nil,
                                          "read_only"    => false,
                                          "syntax"       => "string",
                                          "single_value" => false,
                                          "example_text" => nil,
                                          "show"         => true,
                                          "default"      => true,
                                          "perf_by_tag"  => nil,
                                          "name"         => "def_test_entry_2"},
                                         {"description"  => "Default Test Entry 3",
                                          "icon"         => nil,
                                          "read_only"    => false,
                                          "syntax"       => "string",
                                          "single_value" => false,
                                          "example_text" => nil,
                                          "show"         => true,
                                          "default"      => nil,
                                          "perf_by_tag"  => nil,
                                          "name"         => "def_test_entry_3"}])}]
  end

  before do
    FactoryBot.create(:classification_tag, :name => "test_entry",         :description => "Test Entry",           :parent => parent)
    FactoryBot.create(:classification_tag, :name => "another_test_entry", :description => "Another Test Entry",   :parent => parent)
    FactoryBot.create(:classification_tag, :name => "def_test_entry",     :description => "Default Test Entry",   :parent => def_parent,  :default => true)
    FactoryBot.create(:classification_tag, :name => "def_test_entry_2",   :description => "Default Test Entry 2", :parent => def_parent2, :default => true)
    FactoryBot.create(:classification_tag, :name => "def_test_entry_3",   :description => "Default Test Entry 3", :parent => def_parent2)
  end

  after do
    FileUtils.remove_entry export_dir
  end

  it 'exports user tags to a given directory' do
    TaskHelpers::Exports::Tags.new.export(:directory => export_dir)
    file_contents = File.read("#{export_dir}/Export_Test.yaml")
    file_contents2 = File.read("#{export_dir}/Default_Export_Test_2.yaml")
    expect(YAML.safe_load(file_contents)).to contain_exactly(*tag_export_test)
    expect(YAML.safe_load(file_contents2)).to contain_exactly(*tag_default_export_test_2)
    expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(2)
  end

  it 'exports all tags to a given directory' do
    TaskHelpers::Exports::Tags.new.export(:directory => export_dir, :all => true)
    file_contents = File.read("#{export_dir}/Export_Test.yaml")
    file_contents2 = File.read("#{export_dir}/Default_Export_Test.yaml")
    file_contents3 = File.read("#{export_dir}/Default_Export_Test_2.yaml")
    expect(YAML.safe_load(file_contents)).to contain_exactly(*tag_export_test)
    expect(YAML.safe_load(file_contents2)).to contain_exactly(*tag_default_export_test)
    expect(YAML.safe_load(file_contents3)).to contain_exactly(*tag_default_export_test_2)
    expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(3)
  end
end
