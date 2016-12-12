describe ManageIQ::Providers::Amazon::CloudManager::OrchestrationServiceOptionConverter do
  subject { described_class.new(options) }

  describe '#stack_create_options' do
    context 'no option is set' do
      let(:options) { {} }

      it 'returns an empty option hash for stack creation' do
        expect(subject.stack_create_options).to be_empty
      end
    end

    context 'all options are empty' do
      let(:options) do
        {
          "dialog_stack_timeout"        => "",
          "dialog_stack_onfailure"      => "",
          "dialog_stack_notifications"  => "",
          "dialog_stack_capabilities"   => "",
          "dialog_stack_resource_types" => "",
          "dialog_stack_policy"         => "",
          "dialog_stack_role"           => "",
          "dialog_stack_tags"           => ""
        }
      end

      it 'returns an empty option hash for stack creation' do
        expect(subject.stack_create_options).to be_empty
      end
    end
  end

  context 'timeout option' do
    let(:options) { {'dialog_stack_timeout' => '30'} }

    it { expect(subject.stack_create_options[:timeout_in_minutes]).to eq(30) }
  end

  context 'on_failure option' do
    let(:options) { {'dialog_stack_onfailure' => 'ROLLBACK'} }

    it { expect(subject.stack_create_options[:on_failure]).to eq('ROLLBACK') }
  end

  context 'notification arn option' do
    let(:options) { {'dialog_stack_notifications' => "ARN1\n ARN2\n\n"} }

    it { expect(subject.stack_create_options[:notification_arns]).to eq(%w(ARN1 ARN2)) }
  end

  context 'capabilities option' do
    let(:options) { {'dialog_stack_capabilities' => %w(CAPABILITY_IAM CAPABILITY_NAMED_IAM)} }

    it { expect(subject.stack_create_options[:capabilities]).to eq(%w(CAPABILITY_IAM CAPABILITY_NAMED_IAM)) }
  end

  context 'capabilities option with single value' do
    let(:options) { {'dialog_stack_capabilities' => 'CAPABILITY_IAM'} }

    it { expect(subject.stack_create_options[:capabilities]).to eq(['CAPABILITY_IAM']) }
  end

  context 'resource types option' do
    let(:options) { {'dialog_stack_resource_types' => "AWS::EC2::Instance \nAWS::EC2::*"} }

    it { expect(subject.stack_create_options[:resource_types]).to eq(%w(AWS::EC2::Instance AWS::EC2::*)) }
  end

  context 'role arn option' do
    let(:options) { {'dialog_stack_role' => 'RoleARN'} }

    it { expect(subject.stack_create_options[:role_arn]).to eq('RoleARN') }
  end

  context 'policy body option' do
    let(:options) { {'dialog_stack_policy' => '{"valid":"JSON string"}'} }

    it { expect(subject.stack_create_options[:stack_policy_body]).to eq('{"valid":"JSON string"}') }
  end

  context 'policy url option' do
    let(:options) { {'dialog_stack_policy' => 'http://url'} }

    it { expect(subject.stack_create_options[:stack_policy_url]).to eq('http://url') }
  end

  context 'tags option' do
    let(:options) { {'dialog_stack_tags' => "tag_key1 => tag_val1 \ntag_key2=>tag_val2\n\n"} }

    it { expect(subject.stack_create_options[:tags]).to eq(
      [{:key => 'tag_key1', :value => 'tag_val1'}, {:key => 'tag_key2', :value => 'tag_val2'}]) }
  end
end
