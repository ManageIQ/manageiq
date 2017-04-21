describe 'TaskHelpers::Exports::AlertSets' do
  let(:data_dir) { File.join(File.expand_path(__dir__), '..', 'imports', 'data', 'alert_sets') }
  let(:alert) {'Alert_Profile_VM_Import_Test.yaml'}

  before(:each) do
    @export_dir = Dir.mktmpdir('miq_exp_dir')
  end

  after(:each) do
    FileUtils.remove_entry @export_dir
  end

  it 'should export alert sets to a given directory' do
    options = { :source => "#{data_dir}/#{alert}" }
    TaskHelpers::Imports::AlertSets.new.import(options)

    options = { :directory => @export_dir }
    TaskHelpers::Exports::AlertSets.new.export(options)
    expect( (Dir.entries(@export_dir) - %w{ . .. }) ).not_to be_empty
  end
end
