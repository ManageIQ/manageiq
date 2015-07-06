require "spec_helper"

module MiqAePathSpec
  include MiqAeEngine
  describe MiqAePath do
    context "#to_s" do
      it "handles empty path" do
        path = MiqAePath.new
        path.to_s.should == ""
      end

      it "handles single namespace" do
        path = MiqAePath.new(:ae_namespace => "NAMESPACE")
        path.to_s.should == "/NAMESPACE//"
      end

      it "handles compound namespace" do
        path = MiqAePath.new(:ae_namespace => "NAMESPACE/FOO")
        path.to_s.should == "/NAMESPACE/FOO//"
      end

      it "handles namespace and class" do
        path = MiqAePath.new(:ae_namespace => "NAMESPACE", :ae_class => "CLASS")
        path.to_s.should == "/NAMESPACE/CLASS/"
      end

      it "handles namespace, class and instance" do
        path = MiqAePath.new(:ae_namespace => "NAMESPACE", :ae_class => "CLASS", :ae_instance => "INSTANCE")
        path.to_s.should == "/NAMESPACE/CLASS/INSTANCE"
      end

      it "handles namespace, class, instance and attribute" do
        path = MiqAePath.new(:ae_namespace => "NAMESPACE", :ae_class => "CLASS", :ae_instance => "INSTANCE", :ae_attribute => "ATTRIBUTE")
        path.to_s.should == "/NAMESPACE/CLASS/INSTANCE/ATTRIBUTE"
      end
    end

    it ".build" do
      ae_namespace = "TEST_NAMESPACE"
      ae_class     = "TEST_CLASS"
      ae_instance  = "TEST_INSTANCE"
      parts =  {
          :ae_namespace => ae_namespace,
          :ae_class     => ae_class,
          :ae_instance  => ae_instance
        }

      path = MiqAePath.build(parts)
      path.should be_kind_of MiqAePath
      path.ae_namespace.should == ae_namespace
      path.ae_class.should     == ae_class
      path.ae_instance.should  == ae_instance
    end


    it ".parse" do
      ae_namespace = "TEST_NAMESPACE"
      ae_class     = "TEST_CLASS"
      ae_instance  = "TEST_INSTANCE"
      parts =  {
          :ae_namespace => ae_namespace,
          :ae_class     => ae_class,
          :ae_instance  => ae_instance
        }

      path_string = MiqAePath.new(parts).to_s
      path = MiqAePath.parse(path_string)

      path.should be_kind_of MiqAePath
      path.ae_namespace.should == ae_namespace
      path.ae_class.should     == ae_class
      path.ae_instance.should  == ae_instance
      path.to_s.should         == path_string
    end

    context ".split" do
      before do
        @ae_namespace = "TEST_NAMESPACE"
        @ae_class     = "TEST_CLASS"
        @ae_instance  = "TEST_INSTANCE"
        @parts =  {
            :ae_namespace => @ae_namespace,
            :ae_class     => @ae_class,
            :ae_instance  => @ae_instance
          }
      end

      def assert_split(parts, assertions = parts, method_options = {})
        path = MiqAePath.new(parts).to_s
        n, c, i, a = MiqAePath.split(path, method_options)

        n.should == assertions[:ae_namespace]
        c.should == assertions[:ae_class]
        i.should == assertions[:ae_instance]
        a.should == assertions[:ae_attribute]
      end

      it "with simple namespace" do
        @parts[:ae_namespace] = "NS"
        assert_split(@parts)
      end

      it "with complex namespace" do
        @parts[:ae_namespace] = "FOO/BAR"
        assert_split(@parts)
      end

      it "with embedded blanks in instance name" do
        @parts[:ae_instance] == "test3%20with%20blank"
        assert_split(@parts)
      end

      it "with option :has_instance_name => false" do
        assertions = { :ae_namespace => [@ae_namespace, @ae_class].join("/"), :ae_class => @ae_instance }
        assert_split(@parts, assertions, :has_instance_name => false)
      end

      it "with option :has_attribute_name => true" do
        @parts[:ae_attribute] = "attr1"
        assert_split(@parts, @parts, :has_attribute_name => true)
      end
    end

  end
end
