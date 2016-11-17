describe "miq_ae_class/_class_fields.html.haml" do
  include Spec::Support::AutomationHelper

  context 'display class fields' do
    before do
      assign(:sb,
             :active_tab  => "schema",
             :active_tree => :ae_tree,
             :trees       => {:ae_tree => {:active_node => "aec-1"}})
      ae_fields = {'ae_var1' => {:aetype => 'relationship', :datatype => 'string', :default_value => "Wilma"}}
      create_ae_model(:ae_class     => "FRED",
                      :ae_instances => [],
                      :ae_fields    => ae_fields)

      assign(:in_a_form, false)
      assign(:ae_class, MiqAeClass.where(:name => 'FRED').first)
    end

    it "Check instance", :js => true do
      render
      expect(response).to have_text('ae_var1')
      expect(response).to have_text('Wilma')
    end
  end

  context 'loads class fields edit form' do
    before do
      assign(:sb,
             :active_tab  => "schema",
             :active_tree => :ae_tree,
             :trees       => {:ae_tree => {:active_node => "aec-1"}})
      ae_fields = {'ae_var1' => {:aetype => 'relationship', :datatype => 'string', :default_value => "Wilma"}}
      create_ae_model(:ae_class     => "FRED",
                      :ae_instances => [],
                      :ae_fields    => ae_fields)

      assign(:in_a_form_fields, true)
      @ae_class = MiqAeClass.where(:name => 'FRED').first
      assign(:edit,
             :key              => "aefields_edit__#{@ae_class.id}",
             :ae_class_id      => @ae_class.id,
             :fields_to_delete => [],
             :new              => {
               :datatypes => [],
               :aetypes   => [],
               :fields    => [@ae_class.ae_fields.first]
             })
      @combo_xml = [["Assertion", "assertion", {"data-icon"=>"product product-assertion"}]]
      @dtype_combo_xml = [["String", "string", {"data-icon"=>"product product-string"}]]
    end

    it "Check instance", :js => true do
      render
      expect(rendered).to have_selector('input#fields_default_value_0[value=\'Wilma\']')
    end
  end
end
