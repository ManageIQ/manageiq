describe MiqAeEngine::MiqAeDomainSearch do
  include Spec::Support::AutomationHelper

  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:search) { described_class.new }

  def create_ae_instances
    create_ae_model(:name => 'FRED', :ae_namespace => 'FRED', :ae_class => 'WILMA',
                    :instance_name => 'DOGMATIX')
    create_ae_model(:name => 'BARNEY', :ae_namespace => 'FRED', :ae_class => 'WILMA',
                    :instance_name => 'DOGMATIX')
  end

  def create_vendor_ae_instances
    create_ae_model(:name => 'AMAZON', :ae_namespace => 'AMAZON/TEST', :ae_class => 'PROV',
                    :instance_name => 'ONE')
    create_ae_model(:name => 'MIQ', :ae_namespace => 'TEST', :ae_class => 'PROV',
                    :instance_name => 'ONE')
  end

  def create_ae_methods
    create_ae_model_with_method(:name => 'FRED', :ae_namespace => 'FRED',
                                :ae_class => 'WILMA', :instance_name => 'DOGMATIX',
                                :method_name => 'OBELIX', :method_script => 'x=1')
    create_ae_model_with_method(:name => 'BARNEY', :ae_namespace => 'FRED',
                                :ae_class => 'WILMA', :instance_name => 'DOGMATIX',
                                :method_name => 'OBELIX', :method_script => 'x=1')
  end

  def create_vendor_ae_methods
    create_ae_model_with_method(:name => 'OPENSTACK', :ae_namespace => 'OPENSTACK/TEST',
                                :ae_class => 'WILMA', :instance_name => 'DOGMATIX',
                                :method_name => 'OBELIX', :method_script => 'x=1')
    create_ae_model_with_method(:name => 'BARNEY', :ae_namespace => 'TEST',
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

  it "#get_alternate_domain with vendor" do
    create_vendor_ae_instances
    search.ae_user = user
    search.prepend_namespace = "/AMAZON/"
    ns = search.get_alternate_domain('miqaedb', '/TEST/PROV/ONE', 'TEST', 'PROV', 'ONE')
    expect(ns).to eq('AMAZON/AMAZON/TEST')
  end

  it "#get_alternate_domain_method with vendor" do
    create_vendor_ae_methods
    search.ae_user = user
    search.prepend_namespace = "/OPENSTACK/"
    ns = search.get_alternate_domain_method('miqaedb', '/TEST/WILMA/OBELIX', 'TEST', 'WILMA', 'OBELIX')
    expect(ns).to eq('OPENSTACK/OPENSTACK/TEST')
  end
end
