module AutomationSpecHelper

  # Find fields in automation XML file
  def sanitize_miq_ae_fields(fields)
    unless fields.nil?
      fields.each do |f|
        f["message"]       = @defaults_miq_ae_field[:message]      if f["message"].nil?
        f["substitute"]    = @defaults_miq_ae_field[:substitute]   if f["substitute"].blank?
        f["priority"]      = 1                                     if f["priority"].nil?
        unless f["collect"].blank?
          f["collect"] = f["collect"].first["content"]             if f["collect"].kind_of?(Array)
          f["collect"] = REXML::Text.unnormalize(f["collect"].strip)
        end
        ['on_entry', 'on_exit', 'on_error'].each { |k| f[k] = REXML::Text.unnormalize(f[k].strip) unless f[k].blank? }
        f["default_value"] = f.delete("content").strip             unless f["content"].nil?
        f["default_value"] = ""                                    if f["default_value"].nil?
        f["default_value"] = MiqAePassword.encrypt(f["default_value"]) if f["datatype"] == 'password'
      end
    end
    fields
  end

  def assert_method_executed(uri, value)
    ws = MiqAeEngine.instantiate(uri)
    ws.should_not be_nil
    roots = ws.roots
    roots.should have(1).item
    roots.first.attributes['method_executed'].should == value
  end

  def create_ae_model(attrs = {})
    attrs = default_ae_model_attributes(attrs)
    instance_name = attrs.delete(:instance_name)
    ae_fields = {'field1' => {:aetype => 'relationship', :datatype => 'string'}}
    ae_instances = {instance_name => {'field1' => {:value => 'hello world'}}}

    FactoryGirl.create(:miq_ae_domain, :with_small_model, :with_instances,
                       attrs.merge('ae_fields' => ae_fields, 'ae_instances' => ae_instances))
  end

  def create_state_ae_model(attrs = {})
    attrs = default_ae_model_attributes(attrs)
    instance_name = attrs.delete(:instance_name)
    ae_fields = {'field1' => {:aetype => 'state', :datatype => 'string'}}
    ae_instances = {instance_name => {'field1' => {:value => 'phases of matter'}}}

    FactoryGirl.create(:miq_ae_domain, :with_small_model, :with_instances,
                       attrs.merge('ae_fields' => ae_fields, 'ae_instances' => ae_instances))
  end

  def default_ae_model_attributes(attrs = {})
    attrs.reverse_merge!(
      :ae_class      => 'CLASS1',
      :ae_namespace  => 'A/B/C',
      :priority      => 10,
      :enabled       => true,
      :instance_name => 'instance1')
  end

  def send_ae_request_via_queue(args)
    MiqQueue.put(:role        => 'automate',
                 :class_name  => 'MiqAeEngine',
                 :method_name => 'deliver',
                 :args        => [args])
  end

  def deliver_ae_request_from_queue
    q = MiqQueue.all.detect { |item| item.state == 'ready' && item.class_name == "MiqAeEngine" }
    return nil unless q
    q.state = 'dequeue'
    q.save
    q.deliver
  end

  def create_temp_automate_dir
    ae_dir = Dir.mktmpdir
    require 'miq_ae_datastore'
    stub_const("MiqAeDatastore::DATASTORE_DIRECTORY", ae_dir)
    FileUtils.remove_entry_secure(ae_dir) if Dir.exist?(ae_dir)
    FileUtils.mkdir(ae_dir)
    ae_dir
  end

  def remove_temp_automate_dir(ae_dir)
    FileUtils.remove_entry_secure(ae_dir) if Dir.exist?(ae_dir)
  end
end
