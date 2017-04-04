describe MiqAeEngine::MiqAeBuiltinMethod do
  describe '.miq_check_policy_prevent' do
    let(:event)     { FactoryGirl.create(:miq_event) }
    let(:svc_event) { MiqAeMethodService::MiqAeServiceEventStream.find(event.id) }
    let(:workspace) { double('WORKSPACE', :get_obj_from_path => { 'event_stream' => svc_event }) }
    let(:obj)       { double('OBJ', :workspace => workspace) }

    subject { described_class.send(:miq_check_policy_prevent, obj, {}) }

    it 'with policy not prevented' do
      expect { subject }.not_to raise_error
    end

    it 'with policy prevented' do
      event.update_attributes(:full_data => {:policy => {:prevented => true}})
      expect { subject }.to raise_error(MiqAeException::StopInstantiation)
    end
  end
end
