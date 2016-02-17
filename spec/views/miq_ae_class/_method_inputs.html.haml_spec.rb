require 'spec_helper'
include AutomationSpecHelper

describe "miq_ae_class/_method_inputs.html.haml" do
  context 'display method inputs' do
    before do
      method_params = {'ae_result'     => {:datatype => 'string', :default_value => 'ok'},
                       'ae_next_state' => {:datatype => 'string'},
                       'raise'         => {:datatype => 'string'}
                      }
      attrs = {:method_script => "puts 1",
               :method_params => method_params,
               :method_name   => "method1"
              }
      create_ae_model_with_method(attrs)
      ae_method = MiqAeMethod.where(:name => 'method1').first

      assign(:in_a_form, false)
      assign(:ae_method, ae_method)
      assign(:record, ae_method)
      assign(:sb, :namespace_path => "/somevalue")
    end

    it "Check inputs", :js => true do
      render
      expect(response).to have_text('ae_result')
      expect(response).to have_text('ae_next_state')
    end
  end
end
