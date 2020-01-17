RSpec.describe TaskHelpers::Exports::AlertSets do
  let(:guid) { "eca41687-5ca9-40f2-93f7-3fe1ef08e16e" }

  let(:alert_set_export_attrs) do
    [
      {
        "MiqAlertSet" => {
          "name"        => "eca41687-5ca9-40f2-93f7-3fe1ef08e16e",
          "description" => "Alert Set Export Test",
          "set_type"    => "MiqAlertSet",
          "guid"        => "eca41687-5ca9-40f2-93f7-3fe1ef08e16e",
          "read_only"   => nil,
          "set_data"    => nil,
          "mode"        => "VmOrTemplate",
          "owner_type"  => nil,
          "owner_id"    => nil,
          "userid"      => nil,
          "group_id"    => nil,
          "MiqAlert"    => []
        }
      }
    ]
  end

  let(:alert_set_create_attrs) do
    {
      :description => "Alert Set Export Test",
      :guid        => guid,
      :name        => guid
    }
  end

  before do
    FactoryBot.create(:miq_alert_set_vm, alert_set_create_attrs)
    @export_dir = Dir.mktmpdir('miq_exp_dir')
  end

  after do
    FileUtils.remove_entry @export_dir
  end

  it 'should export alert sets to a given directory' do
    TaskHelpers::Exports::AlertSets.new.export(:directory => @export_dir)
    file_contents = File.read("#{@export_dir}/Alert_Set_Export_Test.yaml")
    expect(YAML.safe_load(file_contents)).to eq(alert_set_export_attrs)
  end
end
