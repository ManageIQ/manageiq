RSpec.describe CloudService, :type => :model do
  let(:cloud_service) do
    FactoryBot.create(:cloud_service).tap do |cs|
      allow(cs).to receive(:fog_service).and_return(fog_service)
    end
  end

  let(:cloud_service_with_scheduling_enabled) do
    cloud_service.tap do |cs|
      cs.scheduling_disabled = false
    end
  end

  let(:cloud_service_with_scheduling_disabled) do
    cloud_service.tap do |cs|
      cs.scheduling_disabled = true
    end
  end

  let(:fog_service) do
    double('fog_service').tap do |fs|
      allow(fs).to receive(:enable).with(no_args)
      allow(fs).to receive(:disable).with(no_args)
    end
  end

  describe '#enable_scheduling' do
    subject do
      cloud_service.enable_scheduling
      fog_service
    end
    it { is_expected.to have_received(:enable) }
    it { is_expected.to_not have_received(:disable) }
  end

  describe '#disable_scheduling' do
    subject do
      cloud_service.disable_scheduling
      fog_service
    end
    it { is_expected.to_not have_received(:enable) }
    it { is_expected.to have_received(:disable) }
  end

  describe '#scheduling_enabled?' do
    subject { cloud_service.scheduling_enabled? }
    it { is_expected.to be_truthy }
  end

  describe '#scheduling_disabled?' do
    subject { cloud_service.scheduling_disabled? }
    it { is_expected.to be_falsy }
  end

  describe '#validate_enable_scheduling' do
    context 'with Fog service available' do
      context 'with scheduling enabled' do
        subject { cloud_service_with_scheduling_enabled.validate_enable_scheduling }
        it { is_expected.to be_falsy }
      end

      context 'with scheduling disabled' do
        subject { cloud_service_with_scheduling_disabled.validate_enable_scheduling }
        it { is_expected.to be_truthy }
      end
    end

    context 'with Fog service not available' do
      let(:fog_service) do
        nil
      end

      context 'with scheduling enabled' do
        subject { cloud_service_with_scheduling_enabled.validate_enable_scheduling }
        it { is_expected.to be_falsy }
      end

      context 'with scheduling disabled' do
        subject { cloud_service_with_scheduling_disabled.validate_enable_scheduling }
        it { is_expected.to be_falsy }
      end
    end
  end

  describe '#validate_disable_scheduling' do
    context 'with Fog service available' do
      context 'with scheduling enabled' do
        subject { cloud_service_with_scheduling_enabled.validate_disable_scheduling }
        it { is_expected.to be_truthy }
      end

      context 'with scheduling disabled' do
        subject { cloud_service_with_scheduling_disabled.validate_disable_scheduling }
        it { is_expected.to be_falsy }
      end
    end

    context 'with Fog service not available' do
      let(:fog_service) do
        nil
      end

      context 'with scheduling enabled' do
        subject { cloud_service_with_scheduling_enabled.validate_disable_scheduling }
        it { is_expected.to be_falsy }
      end

      context 'with scheduling disabled' do
        subject { cloud_service_with_scheduling_disabled.validate_disable_scheduling }
        it { is_expected.to be_falsy }
      end
    end
  end
end
