require "spec_helper"

describe "MiqAeStateMachineRetry" do
  before do
    @method_name     = 'MY_RETRY_METHOD'
    @method_instance = 'MY_RETRY_INSTANCE'
    @retry_class     = 'MY_RETRY_CLASS'
    @domain          = 'SPEC_DOMAIN'
    @namespace       = 'NS1'
    @state_class     = 'MY_STATE_MACHINE'
    @state_instance  = 'MY_STATE_INSTANCE'
    @max_retries     = 1
    @max_time        = 2
    @root_class      = "TOP_OF_THE_WORLD"
    @root_instance   = "EVEREST"
    @automate_args   = {:namespace        => @namespace,
                        :class_name       => @root_class,
                        :instance_name    => @root_instance,
                        :automate_message => 'create'}
    MiqServer.stub(:my_zone).and_return('default')
  end

  def perpetual_retry_script
    <<-'RUBY'
      $evm.root['ae_result'] = 'retry'
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

  def setup_model(method_script)
    dom = FactoryGirl.create(:miq_ae_domain, :enabled => true, :name => @domain)
    ns  = FactoryGirl.create(:miq_ae_namespace, :parent_id => dom.id, :name => @namespace)
    @ns_fqname = ns.fqname
    create_retry_class(:namespace => @ns_fqname, :name => @retry_class, :method_script => method_script)
    create_state_class(:namespace => @ns_fqname, :name => @state_class)
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

  def create_state_class(attrs = {})
    ae_fields = {'state1' => {:aetype      => 'state',      :datatype => 'string',
                              :max_retries => @max_retries, :message  => 'create',
                              :max_time    => @max_time}}
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

  it "check persistent hash" do
    setup_model(method_script_state_var)
    expected = {'three' => 3, 'one'  => 1, 'two'  => 2, 'gravy' => 'train'}
    send_ae_request_via_queue(@automate_args)
    status, _message, ws = deliver_ae_request_from_queue
    status.should_not eq(MiqQueue::STATUS_ERROR)
    ws.should_not be_nil
    MiqQueue.count.should eq(2)
    status, _message, ws = deliver_ae_request_from_queue
    status.should_not eq(MiqQueue::STATUS_ERROR)
    ws.persist_state_hash.should eq(expected)
    ws.root.attributes['finished'].should be_true
  end

  it "check max retries" do
    setup_model(perpetual_retry_script)
    send_ae_request_via_queue(@automate_args)
    (@max_retries + 2).times do
      status, _message, ws = deliver_ae_request_from_queue
      status.should_not eq(MiqQueue::STATUS_ERROR)
      ws.should_not be_nil
    end
    deliver_ae_request_from_queue.should be_nil
  end

  it "check max_time" do
    setup_model(perpetual_retry_script)
    send_ae_request_via_queue(@automate_args)

    status, _message, ws = deliver_ae_request_from_queue
    expect(status).not_to eq(MiqQueue::STATUS_ERROR)
    expect(ws).to be

    Timecop.travel(@max_time + 1) do
      status, _message, ws = deliver_ae_request_from_queue
      expect(status).not_to eq(MiqQueue::STATUS_ERROR)
      expect(ws).to be
    end

    Timecop.travel(@max_time*2 + 2) do
      status, _message, ws = deliver_ae_request_from_queue
      expect(status).not_to be
    end
  end
end
