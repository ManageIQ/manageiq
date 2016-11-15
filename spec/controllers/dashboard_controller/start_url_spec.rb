describe DashboardController do
  describe '#start_page_allowed?' do
    let(:controller) { described_class.new }
    let(:subj) { ->(page) { controller.send(:start_page_allowed?, page) } }

    before do
      stub_user(:features => :all)
    end

    context 'cim_storage_extent_show_list' do
      subject { subj.call('cim_storage_extent_show_list') }

      it 'should return true for storage start pages when product flag is set' do
        stub_settings(:product => {:storage => true})
        is_expected.to be_truthy
      end

      it 'should return false for storage start pages when product flag is not set' do
        is_expected.to be_falsey
      end
    end

    context 'ems_container_show_list' do
      subject { subj.call('ems_container_show_list') }

      it 'should return true for containers start pages when product flag is set' do
        stub_settings(:product => {:containers => true})
        is_expected.to be_truthy
      end

      it 'should return false for containers start pages when product flag is not set' do
        is_expected.to be_falsey
      end
    end

    it 'should return true for host start page' do
      expect(subj.call('host_show_list')).to be_truthy
    end
  end
end
