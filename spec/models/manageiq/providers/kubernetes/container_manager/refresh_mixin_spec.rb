require 'kubeclient'

describe ManageIQ::Providers::Kubernetes::ContainerManager::RefresherMixin do
  let(:client)  { double("client") }
  let(:dummy) { (Class.new { include ManageIQ::Providers::Kubernetes::ContainerManager::RefresherMixin }).new }

  context 'when an exception is thrown' do
    before { allow(client).to receive(:get_pods) { raise KubeException.new(0, 'oh-no', nil) } }

    context 'and there is no default value' do
      it 'should raise' do
        expect { dummy.fetch_entities(client, [{:name => 'pods'}]) }.to raise_error(KubeException)
      end
    end

    context 'and there is a default value' do
      it 'should be returned' do
        expect(dummy.fetch_entities(client, [{:name => 'pods', :default => []}])).to eq('pod' => [])
      end
    end
  end
end
