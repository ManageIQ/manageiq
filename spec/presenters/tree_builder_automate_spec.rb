describe TreeBuilderAutomate do
  include Spec::Support::AutomationHelper

  describe '.select_node_builder' do
    subject { described_class.select_node_builder(controller) }

    context 'called from catalog controller' do
      let(:controller) { 'catalog' }
      it { expect(subject).to eq(TreeNodeBuilderAutomateCatalog) }
    end

    context 'called from automate controller' do
      let(:controller) { 'miq_ae_class' }
      it { expect(subject).to eq(TreeNodeBuilderAutomate) }
    end
  end
end
