RSpec.describe PhysicalServerFirmwareUpdateTask do
  it '#description' do
    expect(subject.description).to eq('Physical Server Firmware Update')
  end

  it '.base_model' do
    expect(described_class.base_model).to eq(PhysicalServerFirmwareUpdateTask)
  end

  it '.request_class' do
    expect(described_class.request_class).to eq(PhysicalServerFirmwareUpdateRequest)
  end

  it '#do_request' do
    expect(subject).to receive(:signal).with(:run_firmware_update)
    subject.do_request
  end
end
