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

  def default_ae_model_attributes(attrs = {})
    attrs.reverse_merge!(
      :ae_class      => 'CLASS1',
      :ae_namespace  => 'A/B/C',
      :priority      => 10,
      :enabled       => true,
      :instance_name => 'instance1')
  end
end
