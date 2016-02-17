require 'spec_helper'
include AutomationSpecHelper

describe "miq_ae_class/_instance_fields.html.haml" do
  context 'display instances' do
    before do
      ae_fields = {'ae_var1' => {:aetype => 'relationship', :datatype => 'string'}}
      ae_instances = {"BARNEY" => {'ae_var1' => {:value => 'hello world'}}}
      create_ae_model(:ae_class      => "FRED",
                      :instance_name => "BARNEY",
                      :ae_instances  => ae_instances,
                      :ae_fields     => ae_fields)

      assign(:in_a_form, false)
      assign(:ae_class, MiqAeClass.where(:name => 'FRED').first)
      assign(:record, MiqAeInstance.where(:name => 'BARNEY').first)
    end

    it "Check instance", :js => true do
      render
      expect(response).to have_text('ae_var1')
      expect(response).to have_text('hello world')
    end
  end
end
