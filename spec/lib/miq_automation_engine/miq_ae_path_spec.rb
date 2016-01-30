module MiqAePathSpec
  include MiqAeEngine
  describe MiqAePath do
    context "#to_s" do
      it "handles empty path" do
        path = MiqAePath.new
        expect(path.to_s).to eq("")
      end

      it "handles single namespace" do
        path = MiqAePath.new(:ae_namespace => "NAMESPACE")
        expect(path.to_s).to eq("/NAMESPACE//")
      end

      it "handles compound namespace" do
        path = MiqAePath.new(:ae_namespace => "NAMESPACE/FOO")
        expect(path.to_s).to eq("/NAMESPACE/FOO//")
      end

      it "handles namespace and class" do
        path = MiqAePath.new(:ae_namespace => "NAMESPACE", :ae_class => "CLASS")
        expect(path.to_s).to eq("/NAMESPACE/CLASS/")
      end

      it "handles namespace, class and instance" do
        path = MiqAePath.new(:ae_namespace => "NAMESPACE", :ae_class => "CLASS", :ae_instance => "INSTANCE")
        expect(path.to_s).to eq("/NAMESPACE/CLASS/INSTANCE")
      end

      it "handles namespace, class, instance and attribute" do
        path = MiqAePath.new(:ae_namespace => "NAMESPACE", :ae_class => "CLASS", :ae_instance => "INSTANCE", :ae_attribute => "ATTRIBUTE")
        expect(path.to_s).to eq("/NAMESPACE/CLASS/INSTANCE/ATTRIBUTE")
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
      expect(path).to be_kind_of MiqAePath
      expect(path.ae_namespace).to eq(ae_namespace)
      expect(path.ae_class).to eq(ae_class)
      expect(path.ae_instance).to eq(ae_instance)
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

      expect(path).to be_kind_of MiqAePath
      expect(path.ae_namespace).to eq(ae_namespace)
      expect(path.ae_class).to eq(ae_class)
      expect(path.ae_instance).to eq(ae_instance)
      expect(path.to_s).to eq(path_string)
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

        expect(n).to eq(assertions[:ae_namespace])
        expect(c).to eq(assertions[:ae_class])
        expect(i).to eq(assertions[:ae_instance])
        expect(a).to eq(assertions[:ae_attribute])
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
        assertions = {:ae_namespace => [@ae_namespace, @ae_class].join("/"), :ae_class => @ae_instance}
        assert_split(@parts, assertions, :has_instance_name => false)
      end

      it "with option :has_attribute_name => true" do
        @parts[:ae_attribute] = "attr1"
        assert_split(@parts, @parts, :has_attribute_name => true)
      end
    end
  end
end
