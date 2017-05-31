describe TaskHelpers::Imports::Policies do
  let(:data_dir)        { File.join(File.expand_path(__dir__), 'data', 'policies') }
  let(:policy_file)     { 'Policy_Import_Test.yaml' }
  let(:bad_policy_file) { 'Bad_Policy_Import_Test.yml' }
  let(:policy_one_guid) { "7562ca69-a00d-4017-be8f-d31d39a07deb" }
  let(:policy_two_guid) { "b314df11-9790-47a1-8e12-14fa124cc862" }

  it 'should import all .yaml files in a specified directory' do
    options = { :source => data_dir }
    expect do
      TaskHelpers::Imports::Policies.new.import(options)
    end.to_not output.to_stderr
    assert_test_policy_one_present
    assert_test_policy_two_present
  end

  it 'should import a specified policy export file' do
    options = { :source => "#{data_dir}/#{policy_file}" }
    expect do
      TaskHelpers::Imports::Policies.new.import(options)
    end.to_not output.to_stderr

    assert_test_policy_one_present
    expect(MiqPolicy.find_by(:guid => policy_two_guid)).to be_nil
  end

  it 'should fail to import a specified policy file' do
    options = { :source => "#{data_dir}/#{bad_policy_file}" }
    expect do
      TaskHelpers::Imports::Policies.new.import(options)
    end.to output.to_stderr
  end

  def assert_test_policy_one_present
    p = MiqPolicy.find_by(:guid => policy_one_guid)
    expect(p.description).to eq("Policy Import Test")
    expect(p.mode).to eq("compliance")
    expect(p.active).to be true
  end

  def assert_test_policy_two_present
    p = MiqPolicy.find_by(:guid => policy_two_guid)
    expect(p.description).to eq("Policy Import Test 2")
    expect(p.mode).to eq("control")
    expect(p.active).to be true
  end
end
