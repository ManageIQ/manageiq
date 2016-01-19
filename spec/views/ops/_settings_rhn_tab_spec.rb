describe 'ops/_settings_rhn_tab' do
  before { assign(:sb, :active_tab => 'settings_rhn') }
  before { assign(:customer, MiqHashStruct.new(:registered => registered)) }

  context 'no active subscription' do
    let(:registered) { false }

    it 'renders the edit button' do
      expect(render).to have_selector('button#settings_rhn_edit', :text => 'Edit Registration')
    end
  end

  context 'with active subscription' do
    let(:registered) { true }

    it 'renders the edit button' do
      expect(render).to have_selector('button#settings_rhn_edit', :text => 'Edit Registration')
    end
  end
end
