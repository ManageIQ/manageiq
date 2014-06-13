class MigrateAutomateUriDataToResourceActions < ActiveRecord::Migration
  class AutomationUri < ActiveRecord::Base
    serialize :options
  end

  class ResourceAction < ActiveRecord::Base
    serialize :ae_attributes
  end

  # Copied from MiqAeEngine
  DEFAULT_ATTRIBUTES = %w{ User::user MiqServer::miq_server object_name }

  # Copied from MiqAeEngine::MiqAePath
  def split(path, options = {})
    options[:has_instance_name] = true unless options.has_key?(:has_instance_name)
    parts = path.split('/')
    parts << nil if path[-1,1] == '/' && options[:has_instance_name]  # Nil instance if trailing /
    parts.shift  if path[0,1]  == '/'                                 # Remove the leading blank piece
    attribute_name = options[:has_attribute_name] ? parts.pop : nil
    instance       = options[:has_instance_name]  ? parts.pop : nil
    klass          = parts.pop
    ns             = parts.join('/')
    [ns, klass, instance, attribute_name].each { |k| k.downcase! unless k.nil? } if options[:downcase]
    return ns, klass, instance, attribute_name
  end

  # Copied from MiqAeEngine::MiqAePath
  def join(ns, klass, instance, attribute_name = nil)
    return [nil, ns, klass, instance].join("/") if attribute_name.nil?
    return [nil, ns, klass, instance, attribute_name].join("/")
  end


  def up
    say_with_time("Migrating AutomationUri data to ResourceAction") do
      AutomationUri.all.each do |au|
        ns, klass, inst, _ = split(au.uri_path)
        ae_attrs = au.options.delete(:attributes) || {}
        ae_attrs.reject! { |key, _| DEFAULT_ATTRIBUTES.include?(key) }

        ResourceAction.create!(
          :resource_type  => "AutomationUri",
          :resource_id    => au.id,
          :action         => 'automation_button',
          :ae_namespace   => ns,
          :ae_class       => klass,
          :ae_instance    => inst,
          :ae_message     => au.uri_message,
          :ae_attributes  => ae_attrs
        )
      end
    end

    change_table :automation_uris do |t|
      t.remove  :uri
      t.remove  :uri_path
      t.remove  :uri_message
    end

  end

  def down
    change_table :automation_uris do |t|
      t.text    :uri
      t.string  :uri_path
      t.string  :uri_message
    end

    say_with_time("Reverting AutomationUri data from ResourceAction") do
      AutomationUri.all.each do |au|
        rsc_action = ResourceAction.where(:resource_type => "AutomationUri", :resource_id => au.id).first
        next if rsc_action.nil?

        uri_path = join(rsc_action.ae_namespace, rsc_action.ae_class, rsc_action.ae_instance)
        uri_message = rsc_action.ae_message

        attrs = rsc_action.ae_attributes.dup
        attrs.delete('request')
        uri = "#{uri_path}?"
        uri << attrs.collect {|k,v| "#{k}=#{v}"}.join('&')
        uri << "##{uri_message}"

        au.uri = uri
        au.uri_path = uri_path
        au.uri_message = uri_message
        au.options ||= {}
        au.options[:attributes] = rsc_action.ae_attributes

        au.save
        rsc_action.destroy
      end
    end
  end
end
