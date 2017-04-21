describe 'TaskHelpers::Imports::AlertSets' do
  let(:data_dir) { File.join(File.expand_path(__dir__), 'data', 'alert_sets') }
  let(:alert) { 'Alert_Profile_Host_Import_Test.yaml' }
  let(:bad_alert) { 'Bad_Alert_Profile_Host_Import_Test.yml' }

  it 'should import all .yaml files in a specified directory' do
    options = { :source => data_dir }
    expect do
      TaskHelpers::Imports::AlertSets.new.import(options)
    end.to_not output.to_stderr
  end

  it 'should import a specified alert export file' do
    options = { :source => "#{data_dir}/#{alert}" }
    expect do
      TaskHelpers::Imports::AlertSets.new.import(options)
    end.to_not output.to_stderr
  end

  it 'should fail to import a specified alert file' do
    options = { :source => "#{data_dir}/#{bad_alert}" }
    expect do
      TaskHelpers::Imports::AlertSets.new.import(options)
    end.to output.to_stderr
  end
end
