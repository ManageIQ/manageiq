require 'spec_helper'

include AutomationSpecHelper
module MiqAeDomainSearchSpec
  include MiqAeEngine
  describe MiqAeDomainSearch do
    let(:user) { FactoryGirl.create(:user_with_group) }
    let(:search) { MiqAeDomainSearch.new }

    def create_ae_instances
      create_ae_model(:name => 'FRED', :ae_namespace => 'FRED', :ae_class => 'WILMA',
                      :instance_name => 'DOGMATIX')
      create_ae_model(:name => 'BARNEY', :ae_namespace => 'FRED', :ae_class => 'WILMA',
                      :instance_name => 'DOGMATIX')
    end

    def create_ae_methods
      create_ae_model_with_method(:name => 'FRED', :ae_namespace => 'FRED',
                                  :ae_class => 'WILMA', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_script => 'x=1')
      create_ae_model_with_method(:name => 'BARNEY', :ae_namespace => 'FRED',
                                  :ae_class => 'WILMA', :instance_name => 'DOGMATIX',
                                  :method_name => 'OBELIX', :method_script => 'x=1')
    end

    it "#get_alternate_domain" do
      create_ae_instances
      search.ae_user = user
      ns = search.get_alternate_domain('miqaedb', '/FRED/WILMA/DOGMATIX', 'FRED', 'WILMA', 'DOGMATIX')
      expect(ns).to eq('BARNEY/FRED')
    end

    it "#get_alternate_domain_method" do
      create_ae_methods
      search.ae_user = user
      ns = search.get_alternate_domain_method('miqaedb', '/FRED/WILMA/OBELIX', 'FRED', 'WILMA', 'OBELIX')
      expect(ns).to eq('BARNEY/FRED')
    end
  end
end
