describe "MiqAeStateMachineRetry" do
  include Spec::Support::AutomationHelper

  before do
    @method_name     = 'MY_RETRY_METHOD'
    @method_instance = 'MY_RETRY_INSTANCE'
    @retry_class     = 'MY_RETRY_CLASS'
    @domain          = 'SPEC_DOMAIN'
    @namespace       = 'NS1'
    @state_class     = 'MY_STATE_MACHINE'
    @state_instance  = 'MY_STATE_INSTANCE'
    @max_retries     = 1
    @root_class      = "TOP_OF_THE_WORLD"
    @root_instance   = "EVEREST"
    @user            = FactoryGirl.create(:user_with_group)
    @automate_args   = {:namespace        => @namespace,
                        :class_name       => @root_class,
                        :instance_name    => @root_instance,
                        :user_id          => @user.id,
                        :miq_group_id     => @user.current_group_id,
                        :tenant_id        => @user.current_tenant.id,
                        :automate_message => 'create'}
    EvmSpecHelper.create_guid_miq_server_zone
    clear_domain
  end

  def clear_domain
    MiqAeDomain.find_by_name(@domain).try(:destroy)
  end

  def perpetual_retry_script
    <<-'RUBY'
      $evm.root['ae_result'] = 'retry'
    RUBY
  end

  alias_method :retry_script, :perpetual_retry_script

  def perpetual_restart_script_with_nextstate
    <<-'RUBY'
      $evm.root['ae_result'] = 'restart'
      $evm.root['ae_next_state'] = 'state2'
    RUBY
  end

  def perpetual_restart_script
    <<-'RUBY'
      $evm.log("info", "Setting restart for state")
      $evm.root['ae_result'] = 'restart'
    RUBY
  end

  def simpleton_script
    <<-'RUBY'
      $evm.root['ae_result'] = 'ok'
    RUBY
  end

  def retry_server_affinity_script
    <<-'RUBY'
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_server_affinity'] = true
    RUBY
  end

  def method_script_state_var
    <<-'RUBY'
      root   = $evm.object("/")
      if $evm.state_var_exist?(:gravy) && $evm.get_state_var('gravy') == 'train'
        root['finished'] = true
        $evm.set_state_var(:three, 3)
        $evm.set_state_var('one', $evm.get_state_var(:one) + 1)
        status = 'ok'
      else
        $evm.set_state_var(:one, 0)
        $evm.set_state_var(:two, 2)
        $evm.set_state_var('gravy', 'train')
        status = 'retry'
      end

      case status
        when 'retry'
          root['ae_result']         = 'retry'
          root['ae_retry_interval'] = '1.minute'
        when 'ok'
          root['ae_result'] = 'ok'
        end
      exit MIQ_OK
    RUBY
  end

  def setup_model(method_script, max_time = nil)
    dom = FactoryGirl.create(:miq_ae_domain, :enabled => true, :name => @domain)
    ns  = FactoryGirl.create(:miq_ae_namespace, :parent_id => dom.id, :name => @namespace)
    @ns_fqname = ns.fqname
    create_retry_class(:namespace => @ns_fqname, :name => @retry_class, :method_script => method_script)
    create_state_class({:namespace => @ns_fqname, :name => @state_class}, max_time)
    create_root_class(:namespace => @ns_fqname, :name => @root_class)
  end

  def create_retry_class(attrs = {})
    method_script = attrs.delete(:method_script)
    ae_fields = {'execute' => {:aetype => 'method', :datatype => 'string'}}
    ae_instances = {@method_instance => {'execute' => {:value => @method_name}}}
    ae_methods = {@method_name => {:scope => 'instance', :location => 'inline',
                                   :data => method_script,
                                   :language => 'ruby', 'params' => {}}}

    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_instances' => ae_instances,
                                   'ae_methods'   => ae_methods))
  end

  def create_state_class(attrs = {}, max_time = nil)
    ae_fields = {'state1' => {:aetype      => 'state',      :datatype => 'string',
                              :max_retries => @max_retries, :message  => 'create',
                              :max_time    => max_time}}
    fqname = "/#{@domain}/#{@namespace}/#{@retry_class}/#{@method_instance}"
    ae_instances = {@state_instance => {'state1' => {:value => fqname}}}

    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_methods'   => {},
                                   'ae_instances' => ae_instances))
  end

  def create_root_class(attrs = {})
    ae_fields = {'rel1' => {:aetype => 'relationship', :datatype => 'string'}}
    fqname = "/#{@domain}/#{@namespace}/#{@state_class}/#{@state_instance}"
    ae_instances = {@root_instance => {'rel1' => {:value => fqname}}}
    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_methods'   => {},
                                   'ae_instances' => ae_instances))
  end

  def create_method_class(attrs, script1, script2, script3)
    ae_fields = {'execute' => {:aetype => 'method', :datatype => 'string'}}
    ae_instances = {'meth1' => {'execute' => {:value => 'meth1'}},
                    'meth2' => {'execute' => {:value => 'meth2'}},
                    'meth3' => {'execute' => {:value => 'meth3'}}}
    ae_methods = {'meth1' => {:scope => 'instance', :location => 'inline',
                              :data => script1,
                              :language => 'ruby', 'params' => {}},
                  'meth2' => {:scope => 'instance', :location => 'inline',
                              :data => script2,
                              :language => 'ruby', 'params' => {}},
                  'meth3' => {:scope => 'instance', :location => 'inline',
                              :data => script3,
                              :language => 'ruby', 'params' => {}}}

    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_instances' => ae_instances,
                                   'ae_methods'   => ae_methods))
  end

  def create_multi_state_class(attrs = {})
    ae_fields = {'state1' => {:aetype => 'state', :datatype => 'string', :priority => 1},
                 'state2' => {:aetype => 'state', :datatype => 'string', :priority => 2},
                 'state3' => {:aetype => 'state', :datatype => 'string', :priority => 3}}
    fq1 = "/#{@domain}/#{@namespace}/#{@retry_class}/meth1"
    fq2 = "/#{@domain}/#{@namespace}/#{@retry_class}/meth2"
    fq3 = "/#{@domain}/#{@namespace}/#{@retry_class}/meth3"
    ae_instances = {@state_instance => {'state1' => {:value => fq1},
                                        'state2' => {:value => fq2},
                                        'state3' => {:value => fq3}}}
    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_methods'   => {},
                                   'ae_instances' => ae_instances))
  end

  def create_restart_model(script1, script2, script3)
    dom = FactoryGirl.create(:miq_ae_domain, :name => @domain)
    ns  = FactoryGirl.create(:miq_ae_namespace, :parent => dom, :name => @namespace)
    @ns_fqname = ns.fqname
    create_multi_state_class(:namespace => @ns_fqname, :name => @state_class)
    attrs = {:namespace => @ns_fqname, :name => @retry_class}
    create_method_class(attrs, script1, script2, script3)
    create_root_class(:namespace => @ns_fqname, :name => @root_class)
  end

  it "check persistent hash" do
    setup_model(method_script_state_var)
    expected = {'three' => 3, 'one'  => 1, 'two'  => 2, 'gravy' => 'train'}
    send_ae_request_via_queue(@automate_args)
    status, _message, ws = deliver_ae_request_from_queue
    expect(status).not_to eq(MiqQueue::STATUS_ERROR)
    expect(ws).not_to be_nil
    expect(MiqQueue.count).to eq(2)
    status, _message, ws = deliver_ae_request_from_queue
    expect(status).not_to eq(MiqQueue::STATUS_ERROR)
    expect(ws.persist_state_hash).to eq(expected)
    expect(ws.root.attributes['finished']).to be_truthy
  end

  it "check max retries" do
    setup_model(perpetual_retry_script)
    send_ae_request_via_queue(@automate_args)
    (@max_retries + 2).times do
      status, _message, ws = deliver_ae_request_from_queue
      expect(status).not_to eq(MiqQueue::STATUS_ERROR)
      expect(ws).not_to be_nil
    end
    expect(deliver_ae_request_from_queue).to be_nil
  end

  it "check max_time" do
    max_time = 2
    setup_model(perpetual_retry_script, max_time)
    send_ae_request_via_queue(@automate_args)

    status, _message, ws = deliver_ae_request_from_queue
    expect(status).not_to eq(MiqQueue::STATUS_ERROR)
    expect(ws).to be_truthy

    Timecop.travel(max_time + 1) do
      status, _message, ws = deliver_ae_request_from_queue
      expect(status).not_to eq(MiqQueue::STATUS_ERROR)
      expect(ws).to be_truthy
    end

    Timecop.travel(max_time * 2 + 2) do
      status, _message, ws = deliver_ae_request_from_queue
      expect(status).not_to be
    end
  end

  it "check restart without next state" do
    create_restart_model(simpleton_script, simpleton_script, perpetual_restart_script)
    send_ae_request_via_queue(@automate_args)
    status, _message, ws = deliver_ae_request_from_queue
    expect(status).not_to eq(MiqQueue::STATUS_ERROR)
    expect(ws).not_to be_nil
    q = MiqQueue.where(:state => 'ready').first
    expect(q.args[0][:state]).to eql('state1')
  end

  it "check restart with next state" do
    create_restart_model(simpleton_script, simpleton_script, perpetual_restart_script_with_nextstate)
    send_ae_request_via_queue(@automate_args)
    status, _message, ws = deliver_ae_request_from_queue
    expect(status).not_to eq(MiqQueue::STATUS_ERROR)
    expect(ws).not_to be_nil
    q = MiqQueue.where(:state => 'ready').first
    expect(q.args[0][:state]).to eql('state2')
  end

  it "retry with server affinity set" do
    setup_model(retry_server_affinity_script)
    send_ae_request_via_queue(@automate_args)
    status, _message, ws = deliver_ae_request_from_queue
    expect(status).not_to eq(MiqQueue::STATUS_ERROR)
    expect(ws).not_to be_nil
    expect(MiqQueue.count).to eq(2)
    q = MiqQueue.where(:state => 'ready').first
    expect(q[:server_guid]).to eql(MiqServer.my_guid)
  end

  it "retry without server affinity set" do
    setup_model(retry_script)
    send_ae_request_via_queue(@automate_args)
    status, _message, ws = deliver_ae_request_from_queue
    expect(status).not_to eq(MiqQueue::STATUS_ERROR)
    expect(ws).not_to be_nil
    expect(MiqQueue.count).to eq(2)
    q = MiqQueue.where(:state => 'ready').first
    expect(q[:server_guid]).to be_nil
  end
end
