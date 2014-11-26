module MiqAutomateHelper
  def self.create_dummy_method(identifiers, field_array)
    MiqAeDatastore.reset
    @aed = FactoryGirl.create(:miq_ae_namespace, :name => identifiers[:domain],
                              :priority => 10, :enabled => true)
    @aen1 = FactoryGirl.create(:miq_ae_namespace, :name      => identifiers[:namespace],
                                                  :parent_id => @aed.id)
    @aec1 = FactoryGirl.create(:miq_ae_class, :name         => identifiers[:class],
                                              :namespace_id => @aen1.id)
    @aec1.ae_fields << build_fields(field_array)
    @aei1 = FactoryGirl.create(:miq_ae_instance, :name     => identifiers[:instance],
                                                 :class_id => @aec1.id)
    @aem1 = FactoryGirl.create(:miq_ae_method, :class_id => @aec1.id,
                               :name => identifiers[:method], :scope => "instance",
                               :language => "ruby", :data => "puts 1",
                               :location => "inline") if identifiers[:method].present?
    @aei1.ae_values << build_values(field_array, @aec1.ae_fields)
  end

  def self.build_values(field_array, field_objects)
    field_array.collect do |field|
      field_obj = field_objects.detect { |f| f.name == field[:name] }
      next unless field_obj
      FactoryGirl.build(:miq_ae_value, :field_id => field_obj.id, :value => field[:value])
    end.compact
  end

  def self.build_fields(field_array, aem_params = false)
    field_array.collect do |field|
      FactoryGirl.build(:miq_ae_field,
                        :name          => field[:name],
                        :aetype        => field[:type],
                        :priority      => field[:priority],
                        :default_value => aem_params ? field[:value] : field[:default_value],
                        :substitute    => true)
    end
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
