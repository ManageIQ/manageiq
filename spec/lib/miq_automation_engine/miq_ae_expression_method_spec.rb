require 'spec_helper'
include AutomationSpecHelper
module MiqAeExpressionMethodSpec
  include MiqAeEngine
  describe MiqAeExpressionMethod do
    let(:user) { FactoryGirl.create(:user_with_group) }
    let(:vm1) { FactoryGirl.create(:vm, :name => 'cfme_2.1', :cpu_shares => 400) }
    let(:vm2) { FactoryGirl.create(:vm, :name => 'cfme_3.1', :cpu_shares => 400) }
    let(:vm3) { FactoryGirl.create(:vm, :name => 'cfme_4.2', :cpu_shares => 11) }
    let(:complex_qs_exp) do
      {"and" => [{"STARTS WITH" => {"field" => "Vm-name", "value" => :user_input}},
                 {"ENDS WITH"   => {"field" => "Vm-name", "value" => :user_input}}]
      }
    end

    let(:m_params) do
      {'arg1'       => {'datatype' => 'string', 'default_value' => 'cfme'},
       'arg2'       => {'datatype' => 'string', 'default_value' => '1'},
       'attributes' => {'datatype' => 'array',  'default_value' => 'name'}
      }
    end

    let(:vm_search) do
      FactoryGirl.create(:miq_search,
                         :db     => "Vm",
                         :filter => MiqExpression.new(complex_qs_exp))
    end

    it "expression_method" do
      vm1
      vm2
      vm3
      m_params['result_type'] = {'datatype' => 'string', 'default_value' => 'array'}
      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => m_params,
                                  :method_loc  => 'expression',
                                  :method_script => vm_search.name)
      ws = MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)

      expect(ws.root.attributes['values']).to match_array(%w(cfme_2.1 cfme_3.1))
    end

    it "expression_method dialog_hash" do
      vm1
      vm2
      vm3
      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => m_params,
                                  :method_loc  => 'expression',
                                  :method_script => vm_search.name)
      ws = MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)

      expect(ws.root.attributes['values'].keys).to match_array([vm1.id, vm2.id])
      expect(ws.root.attributes['values'].values).to match_array([vm1.name, vm2.name])
    end

    it "expression_method no result" do
      vm1
      vm2
      vm3
      m_params['arg1'] = {'datatype' => 'string',  'default_value' => 'nada'}
      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => m_params,
                                  :method_loc  => 'expression',
                                  :method_script => vm_search.name)
      ws = MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)

      expect(ws.root.attributes['ae_result']).to eq('error')
    end

    it "expression_method no result use default value" do
      vm1
      vm2
      vm3
      m_params['arg1'] = {'datatype' => 'string', 'default_value' => 'nada'}
      m_params['default'] = {'datatype' => 'array', 'default_value' => 'nada'}
      m_params['on_empty'] = {'datatype' => 'string', 'default_value' => 'warn'}
      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => m_params,
                                  :method_loc  => 'expression',
                                  :method_script => vm_search.name)
      ws = MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)

      expect(ws.root.attributes['ae_result']).to eq('warn')
      expect(ws.root.attributes['values']).to match_array(%w(nada))
    end

    it "expression_method result attr" do
      vm1
      vm2
      vm3
      m_params['result_attr'] = {'datatype' => 'string', 'default_value' => 'vitalstatistix'}
      m_params['result_type'] = {'datatype' => 'string', 'default_value' => 'array'}
      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => m_params,
                                  :method_loc  => 'expression',
                                  :method_script => vm_search.name)
      ws = MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)

      expect(ws.root.attributes['vitalstatistix']).to match_array(%w(cfme_2.1 cfme_3.1))
    end

    it "expression_method distinct" do
      vm1
      vm2
      vm3
      m_params['distinct'] = {'datatype' => 'array', 'default_value' => 'cpu_shares'}
      m_params['result_type'] = {'datatype' => 'string', 'default_value' => 'array'}
      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => m_params,
                                  :method_loc  => 'expression',
                                  :method_script => vm_search.name)
      ws = MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)

      expect(ws.root.attributes['values']).to match_array([400])
    end

    it "expression_method undefined function" do
      vm1
      vm2
      m_params['attributes'] = {'datatype' => 'array', 'default_value' => 'nada'}
      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => m_params,
                                  :method_loc  => 'expression',
                                  :method_script => vm_search.name)

      expect do
        MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)
      end.to raise_error(MiqAeException::MethodNotDefined)
    end

    it "expression_method target object missing" do
      vm1
      vm2
      vm3
      m_params['result_obj'] = {'datatype' => 'string',  'default_value' => 'nada'}
      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => m_params,
                                  :method_loc  => 'expression',
                                  :method_script => vm_search.name)

      expect do
        MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)
      end.to raise_error(MiqAeException::MethodExpressionTargetObjectMissing)
    end

    it "expression_method invalid result type" do
      vm1
      vm2
      vm3
      m_params['result_type'] = {'datatype' => 'string', 'default_value' => 'nada'}

      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => m_params,
                                  :method_loc  => 'expression',
                                  :method_script => vm_search.name)
      expect do
        MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)
      end.to raise_error(MiqAeException::MethodExpressionResultTypeInvalid)
    end

    it "not all parameters provided" do
      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => {},
                                  :method_loc  => 'expression',
                                  :method_script => vm_search.name)

      expect do
        MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)
      end.to raise_error(MiqAeException::MethodParameterNotFound)
    end

    it "invalid search name" do
      create_ae_model_with_method(:ae_namespace => 'GAULS',
                                  :ae_class => 'ASTERIX', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_params => {},
                                  :method_loc  => 'expression',
                                  :method_script => "nada")

      expect do
        MiqAeEngine.instantiate('/GAULS/ASTERIX/DOGMATIX', user)
      end.to raise_error(MiqAeException::MethodExpressionNotFound)
    end
  end
end
