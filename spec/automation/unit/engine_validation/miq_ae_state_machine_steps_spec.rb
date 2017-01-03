describe "MiqAeStateMachineSteps" do
  before do
    @user                = FactoryGirl.create(:user_with_group)
    @instance1           = 'instance1'
    @instance2           = 'instance2'
    @instance3           = 'instance3'
    @method_class        = 'MY_METHOD_CLASS'
    @common_method_name  = 'standard'
    @common_state_method = 'common_state_method'
    @domain              = 'SPEC_DOMAIN'
    @namespace           = 'NS1'
    @state_class         = 'MY_STATE_MACHINE'
    @state_instance      = 'MY_STATE_INSTANCE'
    @fqname              = '/SPEC_DOMAIN/NS1/MY_STATE_MACHINE/MY_STATE_INSTANCE'
    @method_params       = {'ae_result'     => {:datatype => 'string', :default_value => 'ok'},
                            'ae_next_state' => {:datatype => 'string'},
                            'raise'         => {:datatype => 'string'}
                           }
    clear_domain
    setup_model
  end

  def clear_domain
    MiqAeDomain.find_by_name(@domain).try(:destroy)
  end

  def common_method_script
    <<-'RUBY'
      $evm.log(:info, "Method starting #{$evm.inputs.inspect}")
      inputs = $evm.inputs
      $evm.log(:info, "Common Method: State #{$evm.root['ae_state']} Step #{$evm.root['ae_state_step']}")
      states_executed = $evm.root['states_executed'].to_a
      states_executed << $evm.current_object.instance_name
      $evm.root['states_executed'] = states_executed
      $evm.root['ae_result'] = inputs['ae_result']
      $evm.root['ae_next_state']  = inputs['ae_next_state'] unless inputs['ae_next_state'].blank?
      raise inputs['raise'] unless inputs['raise'].blank?
    RUBY
  end

  def common_state_method_script
    <<-'RUBY'
      $evm.log(:info, "State Method starting #{$evm.inputs.inspect}")
      $evm.log(:info, "State Method: State #{$evm.root['ae_state']} Step #{$evm.root['ae_state_step']}")
      inputs = $evm.inputs
      step_name = "step_#{$evm.root['ae_state_step']}"
      steps_executed = $evm.root[step_name].to_a
      steps_executed << $evm.root['ae_state']
      $evm.root[step_name] = steps_executed
      $evm.root['ae_result'] = inputs['ae_result']
      $evm.root['ae_next_state']  = inputs['ae_next_state'] unless inputs['ae_next_state'].blank?
      raise inputs['raise'] unless inputs['raise'].blank?
    RUBY
  end

  def setup_model
    dom = FactoryGirl.create(:miq_ae_domain, :enabled => true, :name => @domain)
    ns  = FactoryGirl.create(:miq_ae_namespace, :parent_id => dom.id, :name => @namespace)
    @ns_fqname = ns.fqname
    create_method_class(:namespace => @ns_fqname, :name => @method_class)
    create_state_class(:namespace => @ns_fqname, :name => @state_class)
  end

  def create_method_class(attrs = {})
    ae_fields = {'ae_result'     => {:aetype => 'attribute', :datatype => 'string',
                                     :default_value => "ok", :priority => 1},
                 'ae_next_state' => {:aetype => 'attribute', :datatype => 'string',
                                     :priority => 2},
                 'raise'         => {:aetype => 'attribute', :datatype => 'string',
                                     :priority => 3},
                 'execute'       => {:aetype => 'method',    :datatype => 'string',
                                     :priority => 4}}
    inst_values = {'execute'       => {:value => @common_method_name},
                   'ae_result'     => {:value => 'ok'},
                   'ae_next_state' => {:value => ""},
                   'raise'         => {:value => ""}}
    ae_instances = {@instance1 => inst_values, @instance2 => inst_values,
                    @instance3 => inst_values}
    ae_methods = {@common_method_name  => {:scope => 'instance', :location => 'inline',
                                           :data => common_method_script,
                                           :language => 'ruby', 'params' => @method_params}
                 }

    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_instances' => ae_instances,
                                   'ae_methods'   => ae_methods))
  end

  def create_state_class(attrs = {})
    all_steps = {'on_entry' => "common_state_method",
                 'on_exit'  => "common_state_method",
                 'on_error' => "common_state_method"}
    ae_fields = {'state1' => {:aetype => 'state', :datatype => 'string', :priority => 1},
                 'state2' => {:aetype => 'state', :datatype => 'string', :priority => 2},
                 'state3' => {:aetype => 'state', :datatype => 'string', :priority => 3}}
    state1_value = "/#{@domain}/#{@namespace}/#{@method_class}/#{@instance1}"
    state2_value = "/#{@domain}/#{@namespace}/#{@method_class}/#{@instance2}"
    state3_value = "/#{@domain}/#{@namespace}/#{@method_class}/#{@instance3}"
    ae_instances = {@state_instance => {'state1' => {:value => state1_value}.merge(all_steps),
                                        'state2' => {:value => state2_value}.merge(all_steps),
                                        'state3' => {:value => state3_value}.merge(all_steps)}}

    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_methods'   => state_methods,
                                   'ae_instances' => ae_instances))
  end

  def state_methods
    {@common_state_method => {:scope => 'instance', :location => 'inline',
                              :data => common_state_method_script,
                              :language => 'ruby', 'params' => @method_params}
    }
  end

  def tweak_instance(class_fqname, instance, field_name, attribute, value)
    klass = MiqAeClass.find_by_fqname(class_fqname)
    field = klass.ae_fields.detect { |f| f.name == field_name }
    ins   = klass.ae_instances.detect { |inst| inst.name == instance }
    update_value(ins, field, attribute, value)
  end

  def update_value(instance, field, attribute, value)
    ins_v = instance.ae_values.detect { |v| v.field_id == field.id }
    ins_v[attribute] = value
    ins_v.save
    instance.save
  end

  it "process all states" do
    all_instance_names = [@instance1, @instance2, @instance3]
    all_state_names    = %w(state1 state2 state3)

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['states_executed']).to match_array(all_instance_names)
    expect(ws.root.attributes['step_on_entry']).to match_array(all_state_names)
    expect(ws.root.attributes['step_on_exit']).to match_array(all_state_names)
    expect(ws.root.attributes['step_on_error']).to be_nil
  end

  it "one of the state raises an exception" do
    tweak_instance("/#{@domain}/#{@namespace}/#{@method_class}", @instance2,
                   'raise', 'value', "Intentionally raise an error")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance2])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1))
    expect(ws.root.attributes['step_on_error']).to match_array(%w(state2))
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state2))
  end

  it "one of the state has an error" do
    tweak_instance("/#{@domain}/#{@namespace}/#{@method_class}", @instance2,
                   'ae_result', 'value', "error")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance2])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1))
    expect(ws.root.attributes['step_on_error']).to match_array(%w(state2))
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state2))
  end

  it "goto a specific state from on_entry" do
    # When the next state is set run the on_exit method before going to
    # next state
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state1', 'on_entry', "common_state_method(ae_next_state => 'state3')")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['states_executed']).to match_array([@instance3])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state3))
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state3))
    expect(ws.root.attributes['step_on_error']).to be_nil
  end

  it "goto a specific state from on_exit" do
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state1', 'on_exit', "common_state_method(ae_next_state => 'state3')")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance3])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1 state3))
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state3))
    expect(ws.root.attributes['step_on_error']).to be_nil
  end

  it "goto a specific state from on_error" do
    tweak_instance("/#{@domain}/#{@namespace}/#{@method_class}", @instance1,
                   'ae_result', 'value', "error")
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state1', 'on_error',
                   "common_state_method(ae_next_state => 'state3', ae_result => 'continue')")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance3])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state3))
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state3))
    expect(ws.root.attributes['step_on_error']).to match_array(%w(state1))
  end

  it "goto a specific state from main state" do
    tweak_instance("/#{@domain}/#{@namespace}/#{@method_class}", @instance1,
                   'ae_next_state', 'value', "state3")
    ws = MiqAeEngine.instantiate(@fqname, @user)

    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance3])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1 state3))
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state3))
    expect(ws.root.attributes['step_on_error']).to be_nil
  end

  it "on_entry has an error" do
    # The state wont get executed but the on_error for the state will be
    # processed.
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state2', 'on_entry', "common_state_method(ae_result => 'error')")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state2))
    expect(ws.root.attributes['states_executed']).to match_array([@instance1])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1))
    expect(ws.root.attributes['step_on_error']).to match_array(%w(state2))
  end

  it "on_exit has an error" do
    # The state machine will stop and all the subsequent states would be skipped
    # The on_error wont get executed
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state2', 'on_exit', "common_state_method(ae_result => 'error')")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state2))
    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance2])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1 state2))
    expect(ws.root.attributes['step_on_error']).to be_nil
  end

  it "continue even when a state has an error" do
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state2', 'on_error', "common_state_method(ae_result => 'continue')")
    tweak_instance("/#{@domain}/#{@namespace}/#{@method_class}", @instance2,
                   'ae_result', 'value', "error")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state2 state3))
    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance2, @instance3])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1 state3))
    expect(ws.root.attributes['step_on_error']).to match_array(%w(state2))
  end

  it "skip a state" do
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state1', 'on_entry', "common_state_method(ae_result => 'skip')")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state2 state3))
    expect(ws.root.attributes['states_executed']).to match_array([@instance2, @instance3])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state2 state3))
    expect(ws.root.attributes['step_on_error']).to be_nil
  end

  it "non existent on_entry method" do
    # Executes the on_error method when the on_entry has a method missing
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state2', 'on_entry', "does_not_exist(ae_result => 'skip')")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1))
    expect(ws.root.attributes['states_executed']).to match_array([@instance1])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1))
    expect(ws.root.attributes['step_on_error']).to match_array(%w(state2))
  end

  it "non existent on_exit method" do
    # Does not execute the on_error method when the on_exit has a method missing
    # This is different from when the on_entry is missing. Is this an intentional
    # design
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state2', 'on_exit', "does_not_exist(ae_result => 'skip')")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state2))
    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance2])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1))
    expect(ws.root.attributes['step_on_error']).to be_nil
  end

  it "allow for retry to be set on on_exit method even if the state ends in retry" do
    tweak_instance("/#{@domain}/#{@namespace}/#{@method_class}", @instance2,
                   'ae_result', 'value', "retry")
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state2', 'on_exit', "common_state_method(ae_result => 'retry')")
    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state2))
    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance2])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1 state2))
    expect(ws.root.attributes['step_on_error']).to be_nil
    expect(ws.root.attributes['ae_state_retries']).to eq(1)
  end

  it "allow for retry to be set on on_exit method" do
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state2', 'on_exit', "common_state_method(ae_result => 'retry')")
    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state2))
    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance2])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1 state2))
    expect(ws.root.attributes['step_on_error']).to be_nil
    expect(ws.root.attributes['ae_state_retries']).to eq(1)
  end

  it "non existent on_error method" do
    # If the on_error is missing the whole state machine aborts
    tweak_instance("/#{@domain}/#{@namespace}/#{@method_class}", @instance2,
                   'ae_result', 'value', "error")
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state2', 'on_error', "does_not_exist(ae_result => 'skip')")

    ws = MiqAeEngine.instantiate(@fqname, @user)
    expect(ws.root.attributes['step_on_entry']).to match_array(%w(state1 state2))
    expect(ws.root.attributes['states_executed']).to match_array([@instance1, @instance2])
    expect(ws.root.attributes['step_on_exit']).to match_array(%w(state1))
    expect(ws.root.attributes['step_on_error']).to be_nil
  end

  it "goto a non existent state from on_entry" do
    tweak_instance("/#{@domain}/#{@namespace}/#{@state_class}", @state_instance,
                   'state1', 'on_entry', "common_state_method(ae_next_state => 'state_missing')")

    expect { MiqAeEngine.instantiate(@fqname, @user) }.to raise_error(MiqAeException::AbortInstantiation)
  end
end
