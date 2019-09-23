module Spec
  module Support
    module AutomationHelper
      def assert_method_executed(uri, value, user)
        ws = MiqAeEngine.instantiate(uri, user)
        expect(ws).not_to be_nil
        roots = ws.roots
        expect(roots.size).to eq(1)
        expect(roots.first.attributes['method_executed']).to eq(value)
      end

      def create_ae_model(attrs = {})
        attrs = default_ae_model_attributes(attrs)
        instance_name = attrs.delete(:instance_name)
        ae_fields = attrs.delete(:ae_fields)
        ae_instances = attrs.delete(:ae_instances)
        ae_fields ||= {'field1' => {:aetype => 'relationship', :datatype => 'string'}}
        ae_instances ||= {instance_name => {'field1' => {:value => 'hello world'}}}

        FactoryBot.create(:miq_ae_domain, :with_small_model, :with_instances,
                           attrs.merge('ae_fields' => ae_fields, 'ae_instances' => ae_instances))
      end

      def create_state_ae_model(attrs = {})
        attrs = default_ae_model_attributes(attrs)
        instance_name = attrs.delete(:instance_name)
        ae_fields = {'field1' => {:aetype => 'state', :datatype => 'string'}}
        ae_instances = {instance_name => {'field1' => {:value => 'phases of matter'}}}

        FactoryBot.create(:miq_ae_domain, :with_small_model, :with_instances,
                           attrs.merge('ae_fields' => ae_fields, 'ae_instances' => ae_instances))
      end

      def create_ae_model_with_method(attrs = {})
        attrs = default_ae_model_attributes(attrs)
        method_script = attrs.delete(:method_script)
        method_params = attrs.delete(:method_params) || {}
        method_loc = attrs.delete(:method_loc) || "inline"
        instance_name = attrs.delete(:instance_name)
        method_name = attrs.delete(:method_name)
        ae_fields = {'execute' => {:aetype => 'method', :datatype => 'string'}}
        ae_instances = {instance_name => {'execute' => {:value => method_name}}}
        ae_methods = {method_name => {:scope => 'instance', :location => method_loc,
                                      :data => method_script,
                                      :language => 'ruby', 'params' => method_params}}

        FactoryBot.create(:miq_ae_domain, :with_small_model, :with_instances, :with_methods,
                           attrs.merge('ae_fields'    => ae_fields,
                                       'ae_instances' => ae_instances,
                                       'ae_methods'   => ae_methods))
      end

      def default_ae_model_attributes(attrs = {})
        attrs.reverse_merge!(
          :ae_class      => 'CLASS1',
          :ae_namespace  => 'A/B/C',
          :enabled       => true,
          :instance_name => 'instance1')
      end

      def send_ae_request_via_queue(args, timeout = nil)
        queue_args = {:role        => 'automate',
                      :class_name  => 'MiqAeEngine',
                      :method_name => 'deliver',
                      :args        => [args]}
        queue_args.merge!(:msg_timeout => timeout) if timeout
        MiqQueue.put(queue_args)
      end

      def deliver_ae_request_from_queue
        q = MiqQueue.all.detect { |item| item.state == 'ready' && item.class_name == "MiqAeEngine" }
        return nil unless q
        q.state = 'dequeue'
        q.save
        q.deliver
      end

      def add_call_method
        aec = MiqAeClass.lookup_by_fqname('/ManageIQ/System/Request')
        aei = aec.ae_instances.detect { |ins| ins.name == 'Call_Method' } if aec
        return if aei
        aef = aec.ae_fields.detect { |fld| fld.name == 'meth1' }
        aei = MiqAeInstance.new('name' => 'Call_Method')
        aev = MiqAeValue.new(:ae_field => aef, :value =>  "${/#namespace}/${/#class}.${/#method}")
        aei.ae_values << aev
        aec.ae_instances << aei
        aec.save
      end
    end
  end
end
