describe 'ops/_settings_label_tag_mapping_tab.html.haml' do
  before { assign(:sb, :active_tab => 'settings_label_tag_mapping') }

  context 'table view' do
    it 'renders the table with zero mappings' do
      @lt_mapping = []
      render
      expect(response.body).to include('Click on this row to create a new mapping rule')
      expect(response.body).to have_selector('button', :text => 'Add')
    end

    it 'renders the table with mappings' do
      @lt_mapping = [{:entity => 'Node', :label_name => 'my-label', :category => 'My Cat'}]
      render
      expect(response.body).to include('Click on this row to create a new mapping rule')
      expect(response.body).to have_selector('button', :text => 'Add')
      expect(response.body).to include('Node')
      expect(response.body).to include('my-label')
      expect(response.body).to include('My Cat')
      expect(response.body).to have_selector('button', :text => 'Delete')
    end
  end
end
