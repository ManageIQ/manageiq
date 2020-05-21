RSpec.describe TaskHelpers::Exports::ServiceDialogs do
  let(:buttons) { "the buttons" }
  let(:description1) { "the first description" }
  let(:description2) { "the second description" }
  let(:label1) { "the first label" }
  let(:label2) { "TheSecondLabel" }

  let(:expected_data1) do
    [{
      "description" => description1,
      "buttons"     => buttons,
      "label"       => label1,
      "dialog_tabs" => [],
      "system"      => false
    }]
  end

  let(:expected_data2) do
    [{
      "description" => description2,
      "buttons"     => buttons,
      "label"       => label2,
      "dialog_tabs" => [],
      "system"      => false
    }]
  end

  let(:export_dir) do
    Dir.mktmpdir('miq_exp_dir')
  end

  before do
    FactoryBot.create(:dialog, :name => label1, :description => description1, :buttons => buttons)
    FactoryBot.create(:dialog, :name => label2, :description => description2, :buttons => buttons)
  end

  after do
    FileUtils.remove_entry export_dir
  end

  def load_yaml(filename)
    data = File.read(filename)
    YAML.safe_load(data)
  end

  def without_version(data)
    data.map do |dialog|
      dialog.except('export_version')
    end
  end

  it 'exports service dialogs as individual files in a given directory' do
    TaskHelpers::Exports::ServiceDialogs.new.export(:directory => export_dir)
    file_contents = load_yaml("#{export_dir}/the_first_label.yaml")
    file_contents2 = load_yaml("#{export_dir}/TheSecondLabel.yaml")
    expect(without_version(file_contents)).to eq(expected_data1)
    expect(without_version(file_contents2)).to eq(expected_data2)
    expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(2)
  end

  it 'exports with current export_version' do
    TaskHelpers::Exports::ServiceDialogs.new.export(:directory => export_dir)
    file_contents = load_yaml("#{export_dir}/the_first_label.yaml")
    expect(file_contents.first).to include('export_version' => DialogImportService::CURRENT_DIALOG_VERSION)
  end
end
