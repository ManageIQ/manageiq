require "spec_helper"

describe "MiqAeStateMachine" do
  before do
    MiqAeDatastore.reset_default_namespace
    @domain           = 'FLINTSTONE'
    @namespace        = 'WILMA'
    @state_class      = 'FRED'
    @other_class      = 'BARNEY'
    @other1           = 'HOPPY'
    @other2           = 'GAZOO'
    @other3           = 'BETTY'
    @state_instance1  = 'PEBBLES'
    @state_instance2  = 'BAMM_BAMM'
    @state_instance3  = 'DINO'
    setup_model
  end

  def setup_model
    dom = FactoryGirl.create(:miq_ae_domain, :enabled => true, :name => @domain)
    ns  = FactoryGirl.create(:miq_ae_namespace, :parent_id => dom.id, :name => @namespace)
    @ns_fqname = ns.fqname
    create_other_class(:namespace => @ns_fqname, :name => @other_class)
    create_state_class(:namespace => @ns_fqname, :name => @state_class)
  end

  def create_other_class(attrs = {})
    ae_fields = {'var1' => {:aetype => 'attribute', :datatype => 'string'}}
    ae_instances = {@other1 => {'var1' => {:value => "1"}},
                    @other3 => {'var1' => {:value => "3"}}}
    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_instances' => ae_instances,
                                   'ae_methods'   => {}))
  end

  def create_state_class(attrs = {})
    ae_fields = {'state1' => {:aetype => 'state', :datatype => 'string', :max_retries => 10,
                              :message => 'create', :priority => 1, :collect => 'var1'},
                 'state2' => {:aetype => 'state', :datatype => 'string', :max_retries => 10,
                              :message => 'create', :priority => 2, :collect => 'var1'},
                 'state3' => {:aetype => 'state', :datatype => 'string', :max_retries => 10,
                              :message => 'create', :priority => 3, :collect => 'var1'}}
    fqname1    = "/#{@domain}/#{@namespace}/#{@other_class}/#{@other1}"
    missing_fq = "/#{@domain}/#{@namespace}/#{@other_class}/#{@other2}"
    fqname3    = "/#{@domain}/#{@namespace}/#{@other_class}/#{@other3}"
    ae_instances = {@state_instance1 => {'state1' => {:value => missing_fq},
                                         'state2' => {:value => ""},
                                         'state3' => {:value => ""}},
                    @state_instance2 => {'state1' => {:value => fqname1},
                                         'state2' => {:value => missing_fq},
                                         'state3' => {:value => fqname3}},
                    @state_instance3 => {'state1' => {:value => fqname1},
                                         'state2' => {:value => fqname3},
                                         'state3' => {:value => missing_fq}}
                   }

    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_methods'   => {},
                                   'ae_instances' => ae_instances))
  end

  it "missing instance in first slot" do
    fqname = "#{@domain}/#{@namespace}/#{@state_class}/#{@state_instance1}"
    ws = MiqAeEngine.instantiate(fqname)
    ws.root['ae_result'].should eql('error')
  end

  it "missing instance in middle slot" do
    fqname = "#{@domain}/#{@namespace}/#{@state_class}/#{@state_instance2}"
    ws = MiqAeEngine.instantiate(fqname)
    ws.root['ae_result'].should eql('error')
    ws.root['var1'].should == '1'
  end

  it "missing instance in last slot" do
    fqname = "#{@domain}/#{@namespace}/#{@state_class}/#{@state_instance3}"
    ws = MiqAeEngine.instantiate(fqname)
    ws.root['ae_result'].should eql('error')
    ws.root['var1'].should == '3'
  end
end
