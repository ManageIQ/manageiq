RSpec.describe PhysicalServerProvisionTask do
  it '#description' do
    expect(subject.description).to eq('Provision Physical Server')
  end

  it '#model_class' do
    expect(subject.model_class).to eq(PhysicalServer)
  end

  it '.request_class' do
    expect(described_class.request_class).to eq(PhysicalServerProvisionRequest)
  end

  describe '#deliver_to_automate' do
    before do
      allow(subject).to receive(:approved?).and_return(true)
      allow(subject).to receive(:get_user).and_return(double('USER').as_null_object)
      allow(subject).to receive(:my_zone).and_return(double('ZONE').as_null_object)
    end

    let(:request) { FactoryBot.create(:physical_server_provision_request) }

    subject { described_class.new(:miq_request => request) }

    it do
      expect(MiqQueue).to receive(:put).with(satisfy { |args| args[:class_name] == 'MiqAeEngine' })
      subject.deliver_to_automate
    end
  end
end
