require "spec_helper"

describe OpsController do
  describe '#ap_set_record_vars_set' do
    let(:scanitemset) { double }

    context 'missing description' do
      it 'sets scanitemset parameters' do
        expect(scanitemset).to receive(:name=).with('some_name')
        expect(scanitemset).to receive(:description=).with('')
        expect(scanitemset).to receive(:mode=).with(nil)

        subject.instance_variable_set(:@edit, :new => {:name => 'some_name'})

        subject.send(:ap_set_record_vars_set, scanitemset)
      end
    end
  end
end
