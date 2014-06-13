module MiqAutomateHelper
  def self.create_dummy_method(identifiers, field_array)
    MiqAeDatastore.reset
    @aed = FactoryGirl.create(:miq_ae_namespace, :name => identifiers[:domain],
                              :priority => 10, :enabled => true)
    @aen1 = FactoryGirl.create(:miq_ae_namespace, :name      => identifiers[:namespace],
                                                  :parent_id => @aed.id)
    @aec1 = FactoryGirl.create(:miq_ae_class, :name         => identifiers[:class],
                                              :namespace_id => @aen1.id)
    @aei1 = FactoryGirl.create(:miq_ae_instance, :name     => identifiers[:instance],
                                                 :class_id => @aec1.id)
    @aem1 = FactoryGirl.create(:miq_ae_method, :class_id => @aec1.id,
                               :name => identifiers[:method], :scope => "instance",
                               :language => "ruby", :data => "puts 1",
                               :location => "inline") if identifiers[:method].present?
    field_array.each { |f| create_field(@aec1, @aei1, nil, f) }
  end

  def self.create_field(class_obj, instance_obj, method_obj, options)
    if method_obj.nil?
      field = FactoryGirl.create(:miq_ae_field,
                                 :class_id   => class_obj.id,
                                 :name       => options[:name],
                                 :aetype     => options[:type],
                                 :priority   => options[:priority],
                                 :substitute => true)
      create_field_value(instance_obj, field, options[:value]) unless options[:value].nil?
    else
      FactoryGirl.create(:miq_ae_field,
                         :method_id     => method_obj.id,
                         :name          => options[:name],
                         :aetype        => options[:type],
                         :priority      => options[:priority],
                         :substitute    => true,
                         :default_value => options[:value])
    end
  end

  def self.create_field_value(instance_obj, field_obj, value)
    FactoryGirl.create(:miq_ae_value,
                       :instance_id => instance_obj.id,
                       :field_id    => field_obj.id,
                       :value       => value)
  end

  def self.create_service_model_method(domain, namespace, klass, instance, method)
    identifiers = {:domain => domain, :namespace => namespace,
                  :class  => klass, :instance => instance, :method => method}
    fields      = [{:name => 'method1', :type => 'method',
                   :priority => 1, :value => method}]
    create_dummy_method(identifiers, fields)
  end
end
