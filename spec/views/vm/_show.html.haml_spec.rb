describe "vm/show.html.haml" do
  shared_examples_for "miq_before_onload JS is needed" do
    it "renders proper JS" do
      js_string = "var miq_after_onload = \"miqAsyncAjax('/vm/#{action}/#{vm.id}');\""
      render
      expect(rendered).to include(js_string)
    end
  end

  let(:vm) { FactoryGirl.create(:vm, :name => 'vm', :description => 'vm description') }
  let(:action) { 'show' }

  before do
    assign(:record, vm)
    assign(:ajax_action, action)
    assign(:showtype, showtype)
  end

  context "when showtype is 'policies'" do
    let(:showtype) { 'policies' }
    let(:display) { 'main' }

    it 'should render policies view' do
      assign(:lastaction, 'policy_sim')
      stub_template "vm_common/_policies.html.haml" => "Stubbed Content"
      render
      expect(rendered).to render_template(:partial => 'vm_common/policies', :locals => {:controller => 'vm'})
    end
  end
end
