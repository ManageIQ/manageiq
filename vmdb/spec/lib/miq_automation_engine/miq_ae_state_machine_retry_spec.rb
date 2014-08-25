require "spec_helper"

describe "MiqAeStateMachineRetry" do
  before do
    MiqAeDatastore.reset_default_namespace
    @method_name     = 'MY_RETRY_METHOD'
    @method_instance = 'MY_RETRY_INSTANCE'
    @retry_class     = 'MY_RETRY_CLASS'
    @domain          = 'SPEC_DOMAIN'
    @namespace       = 'NS1'
    @state_class     = 'MY_STATE_MACHINE'
    @state_instance  = 'MY_STATE_INSTANCE'
  end

  def method_script
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

  def setup_model
    dom = FactoryGirl.create(:miq_ae_domain, :enabled => true, :name => @domain)
    ns  = FactoryGirl.create(:miq_ae_namespace, :parent_id => dom.id, :name => @namespace)
    @ns_fqname = ns.fqname
    create_retry_class(:namespace => @ns_fqname, :name => @retry_class)
    create_state_class(:namespace => @ns_fqname, :name => @state_class)
  end

  def create_retry_class(attrs = {})
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
    ae_fields = {'state1' => {:aetype => 'state', :datatype => 'string', :max_retries => 10, :message => 'create'}}
    fqname = "/#{@domain}/#{@namespace}/#{@retry_class}/#{@method_instance}"
    ae_instances = {@state_instance => {'state1' => {:value => fqname}}}

    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_methods'   => {},
                                   'ae_instances' => ae_instances))
  end

  it "check retry" do
    setup_model
    MiqServer.stub(:my_zone).and_return('default')
    @expected = {'three' => 3, 'one'  => 1, 'two'  => 2, 'gravy' => 'train'}
    args = {
      :namespace        => @namespace,
      :class_name       => @state_class,
      :instance_name    => @state_instance,
      :automate_message => 'create'
    }
    q = MiqQueue.put(
                    :role        => 'automate',
                    :class_name  => 'MiqAeEngine',
                    :method_name => 'deliver',
                    :args        => [args])
    delivered_ids = []
    status, message, ws = q.deliver
    status.should_not eq(MiqQueue::STATUS_ERROR)
    ws.should_not be_nil
    delivered_ids << q.id
    MiqQueue.count.should eq(2)
    MiqQueue.all.each do |v|
      unless delivered_ids.include?(v.id)
        status, message, ws = v.deliver
        status.should_not eq(MiqQueue::STATUS_ERROR)
        ws.should_not be_nil
        delivered_ids << v.id
        ws.persist_state_hash.should eq(@expected)
        ws.root.attributes['finished'].should be_true
      end
    end
  end
end
