describe TaskHelpers::Exports::Alerts do
  let(:guid) { "8f0d49a0-22b0-0135-5de8-54ee7549b627" }

  let(:alert_export_attrs) do
    [
      {
        "MiqAlert" => {
          "guid"               => "8f0d49a0-22b0-0135-5de8-54ee7549b627",
          "description"        => "Alert Export Test",
          "options"            => nil,
          "db"                 => nil,
          "expression"         => nil,
          "responds_to_events" => nil,
          "enabled"            => true,
          "read_only"          => nil
        }
      }
    ]
  end

  let(:alert_create_attrs) do
    {
      :description => "Alert Export Test",
      :guid        => guid,
      :enabled     => true
    }
  end

  before(:each) do
    FactoryGirl.create(:miq_alert, alert_create_attrs)
    @export_dir = Dir.mktmpdir('miq_exp_dir')
  end

  after(:each) do
    FileUtils.remove_entry(@export_dir)
  end

  it 'should export alerts to a given directory' do
    TaskHelpers::Exports::Alerts.new.export(:directory => @export_dir)
    file_contents = File.read("#{@export_dir}/Alert_Export_Test.yaml")
    expect(YAML.safe_load(file_contents)).to eq(alert_export_attrs)
  end
end
