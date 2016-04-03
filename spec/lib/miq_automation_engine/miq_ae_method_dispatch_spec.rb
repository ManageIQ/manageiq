include AutomationSpecHelper

describe "MiqAeMethodDispatch" do
  before do
    @method_name     = 'MY_METHOD'
    @method_instance = 'MY_METHOD_INSTANCE'
    @method_class    = 'MY_METHOD_CLASS'
    @domain          = 'SPEC_DOMAIN'
    @namespace       = 'NS1'
    @root_class      = "TOP_OF_THE_WORLD"
    @root_instance   = "EVEREST"
    @user            = FactoryGirl.create(:user_with_group)
    @automate_args   = {:namespace        => @namespace,
                        :class_name       => @root_class,
                        :instance_name    => @root_instance,
                        :user_id          => @user.id,
                        :miq_group_id     => @user.current_group.id,
                        :tenant_id        => @user.current_tenant.id,
                        :automate_message => 'create'}
    allow(MiqServer).to receive(:my_zone).and_return('default')
    @pidfile = File.join(Dir.mktmpdir, "rip_van_winkle.pid")
    clear_domain
  end

  def clear_domain
    MiqAeDomain.find_by_name(@domain).try(:destroy)
  end

  def rip_van_winkle_script
    <<-'RUBY'
      pidfile    = $evm.inputs['pidfile']
      File.open(pidfile, 'w') { |file| file.write(Process.pid.to_s) }
      10.times do
          STDERR.puts "Hello from stderr channel"
          STDOUT.puts "Hello from stdout channel"
      end
      # Intentional Sleep, this process gets terminated by the
      # Automate Engine, since it thinks its unresponsive
      # look at long running method spec in this file
      sleep(60)
    RUBY
  end

  def std_script
    <<-'RUBY'
      pidfile    = $evm.inputs['pidfile']
      File.open(pidfile, 'w') { |file| file.write(Process.pid.to_s) }
      $evm.root['method_pid'] = Process.pid
      10.times do
          STDERR.puts "Hello from stderr channel"
          STDOUT.puts "Hello from stdout channel"
      end
      exit(MIQ_OK)
    RUBY
  end

  def setup_model(method_script)
    dom = FactoryGirl.create(:miq_ae_domain, :enabled => true, :name => @domain)
    ns  = FactoryGirl.create(:miq_ae_namespace, :parent_id => dom.id, :name => @namespace)
    @ns_fqname = ns.fqname
    create_method_class(:namespace => @ns_fqname, :name => @method_class,
                        :method_script => method_script)
    create_root_class(:namespace => @ns_fqname, :name => @root_class)
  end

  def create_method_class(attrs = {})
    params = {'pidfile' => {'aetype'        => 'attribute',
                            'datatype'      => 'string',
                            'default_value' => @pidfile}
             }
    method_script = attrs.delete(:method_script)
    ae_fields = {'execute' => {:aetype => 'method', :datatype => 'string'}}
    ae_instances = {@method_instance => {'execute' => {:value => @method_name}}}
    ae_methods = {@method_name => {:scope => 'instance', :location => 'inline',
                                   :data => method_script,
                                   :language => 'ruby', 'params' => params}}

    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_instances' => ae_instances,
                                   'ae_methods'   => ae_methods))
  end

  def create_root_class(attrs = {})
    ae_fields = {'rel1' => {:aetype => 'relationship', :datatype => 'string'}}
    fqname = "/#{@domain}/#{@namespace}/#{@method_class}/#{@method_instance}"
    ae_instances = {@root_instance => {'rel1' => {:value => fqname}}}
    FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                       attrs.merge('ae_fields'    => ae_fields,
                                   'ae_methods'   => {},
                                   'ae_instances' => ae_instances))
  end

  it "long running method" do
    File.delete(@pidfile) if File.exist?(@pidfile)
    setup_model(rip_van_winkle_script)
    # Set the timeout to 2 seconds so we can terminate
    # unresponsive method
    send_ae_request_via_queue(@automate_args, 2)
    status, _msg, _ws = deliver_ae_request_from_queue
    expect(status).to eql 'timeout'
    if File.exist?(@pidfile)
      pid = File.read(@pidfile).to_i
      expect { Process.getpgid(pid) }.to raise_error(Errno::ESRCH)
    end
  end

  it "run method that writes to stderr and stdout" do
    setup_model(std_script)
    send_ae_request_via_queue(@automate_args)
    _, _, ws = deliver_ae_request_from_queue
    pid = File.read(@pidfile).to_i
    expect(ws.root['method_pid']).to eql pid
  end
end
