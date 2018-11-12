describe TaskHelpers::Exports::CustomButtons do
  let!(:custom_button)     { FactoryGirl.create(:custom_button, :name => "export_test_button", :description => "Export Test", :applies_to_class => "Vm") }
  let!(:custom_button2)    { FactoryGirl.create(:custom_button, :name => "export_test_button2", :description => "Export Test", :applies_to_class => "Service") }
  let!(:custom_button_set) { FactoryGirl.create(:custom_button_set, :name => "custom_button_set", :description => "Default Export Test") }
  let(:export_dir)         { Dir.mktmpdir('miq_exp_dir') }

  let(:custom_button_export_test) do
    {"custom_button_set" => [{
      "attributes" => {
        "name"        => "custom_button_set",
        "description" => "Default Export Test",
        "set_type"    => "CustomButtonSet",
        "guid"        => custom_button_set.guid,
        "read_only"   => nil,
        "set_data"    => nil,
        "mode"        => nil,
        "owner_type"  => nil,
        "owner_id"    => nil,
        "userid"      => nil,
        "group_id"    => nil
      },
      "children"   => {
        "custom_button" => [{
          "attributes" => {
            "guid"                  => custom_button.guid,
            "description"           => "Export Test",
            "applies_to_class"      => "Vm",
            "visibility_expression" => nil,
            "options"               => {},
            "userid"                => nil,
            "wait_for_complete"     => nil,
            "name"                  => "export_test_button",
            "visibility"            => nil,
            "applies_to_id"         => nil,
            "enablement_expression" => nil,
            "disabled_text"         => nil
          }
        }]
      }
    }],
     "custom_button"     => [{
       "attributes" => {
         "guid"                  => custom_button2.guid,
         "description"           => "Export Test",
         "applies_to_class"      => "Service",
         "visibility_expression" => nil,
         "options"               => {},
         "userid"                => nil,
         "wait_for_complete"     => nil,
         "name"                  => "export_test_button2",
         "visibility"            => nil,
         "applies_to_id"         => nil,
         "enablement_expression" => nil,
         "disabled_text"         => nil
       }
     }]}
  end

  before do
    custom_button_set.add_member(custom_button)
  end

  after do
    FileUtils.remove_entry export_dir
  end

  it 'exports custom buttons to a given directory' do
    TaskHelpers::Exports::CustomButtons.new.export(:directory => export_dir)
    file_contents = File.read("#{export_dir}/CustomButtons.yaml")
    expect(YAML.safe_load(file_contents)).to contain_exactly(*custom_button_export_test)
    expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(1)
  end

  it 'exports all custom buttons to a given directory' do
    TaskHelpers::Exports::CustomButtons.new.export(:directory => export_dir, :all => true)
    file_contents = File.read("#{export_dir}/CustomButtons.yaml")
    expect(YAML.safe_load(file_contents)).to contain_exactly(*custom_button_export_test)
    expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(1)
  end
end
