require "spec_helper"

module MiqAeServiceSpec
  describe MiqAeMethodService::MiqAeService do
    before(:each) do
      @domain = 'TEST_DOMAIN'
      identifiers = {:domain => @domain, :namespace => 'EVM',
                          :class  => 'AUTOMATE', :instance => 'test1', :method => 'test'}
      fields      = [{:name => 'method1', :type => 'method',
                               :priority => 1, :value => 'test'},
                     {:name => 'var1', :type => 'attribute',
                               :priority => 2, :value => 'testvalueforvar1'},
                     {:name => 'var2', :type => 'attribute',
                               :priority => 3}
                    ]
      MiqAutomateHelper.create_dummy_method(identifiers, fields)
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1")
    end

    def assert_readonly_instance(automate_method_script)
      dom_obj = MiqAeDomain.find_by_name(@domain)
      dom_obj.update_attributes!(:system => true)
      @ae_method.update_attributes(:data => automate_method_script)
      result = invoke_ae.root(@ae_result_key)
      dom_obj.update_attributes!(:system => false)
      result.should be_false
    end

    context "$evm.instance_exists?" do
      it "nonexistant instance " do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_exists?('/bogus/evenworse/fred')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == false
      end

      it "existing instance " do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_exists?('#{@domain}/EVM/AUTOMATE/test1')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == true
      end
    end

    context "$evm.instance_create" do
      it "instance already exists" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_create('#{@domain}/EVM/AUTOMATE/test1', 'method1' => 'testattributevalue', 'var1' => 'variablevalue1')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == false
      end

      it "readonly domain" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_create('#{@domain}/EVM/AUTOMATE/freddy', 'method1' => 'a', 'var1' => 'b')"
        assert_readonly_instance(method)
      end

      it "instance does not exist, create it, check that it exists, then get the instance values" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_create('#{@domain}/EVM/AUTOMATE/testadd', 'method1' => 'testattributevalue', 'var1' => 'variablevalue1' )"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == true

        #Now the instance should exist
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_exists?('#{@domain}/EVM/AUTOMATE/testadd')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == true

        #Make sure we can get instance values
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_get('#{@domain}/EVM/AUTOMATE/testadd')"
        @ae_method.update_attributes(:data => method)
        result_hash = invoke_ae.root(@ae_result_key)
        result_hash.should be_kind_of(Hash)
        result_hash.length.should == 3
      end
    end

    context "$evm.instance_find" do
      context "single instance in datastore" do
        it "instance not found" do
          method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_find('#{@domain}/EVM/AUTOMATE/testadd')"
          @ae_method.update_attributes(:data => method)
          result_hash = invoke_ae.root(@ae_result_key)
          result_hash.should == {}
        end

        context "instance found" do
          it "with no options specified" do
            method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_find('#{@domain}/EVM/AUTOMATE/te*')"
            @ae_method.update_attributes(:data => method)
            result_hash = invoke_ae.root(@ae_result_key)
            result_hash.should be_kind_of(Hash)
            result_hash.length.should == 1
            key = 'test1'
            result_hash.keys.should == [key]
            result_hash[key].should be_kind_of(Hash)
            result_hash[key].length.should == 3
          end

          it "with path option specified" do
            method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_find('#{@domain}/EVM/AUTOMATE/te*', :path => true)"
            @ae_method.update_attributes(:data => method)
            result_hash = invoke_ae.root(@ae_result_key)
            result_hash.should be_kind_of(Hash)
            result_hash.length.should == 1
            key = "/#{@domain}/EVM/AUTOMATE/test1"
            result_hash.keys.should == [key]
            result_hash[key].should be_kind_of(Hash)
            result_hash[key].length.should == 3
          end
        end
      end

      context "multiple instances in datastore" do
        before(:each) do
          ['test12', 'test21', 'teXt12'].each do |iname|
            method = "$evm.root['#{@ae_result_key}'] = $evm.instance_create('#{@domain}/EVM/AUTOMATE/#{iname}')"
            @ae_method.update_attributes(:data => method)
            invoke_ae.root(@ae_result_key)
          end
        end

        it "should find 3 instances when searching for te?t1*" do
          method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_find('#{@domain}/EVM/AUTOMATE/te?t1*')"
          @ae_method.update_attributes(:data => method)
          result_hash = invoke_ae.root(@ae_result_key)
          result_hash.should be_kind_of(Hash)
          result_hash.length.should == 3
          ['test1', 'test12', 'teXt12'].each do |iname|
            result_hash.keys.should include iname
            result_hash[iname].should be_kind_of(Hash)
            result_hash[iname].length.should == 3
          end
        end

        it "should find 3 instances when searching for test*" do
          method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_find('#{@domain}/EVM/AUTOMATE/test*')"
          @ae_method.update_attributes(:data => method)
          result_hash = invoke_ae.root(@ae_result_key)
          result_hash.should be_kind_of(Hash)
          result_hash.length.should == 3
          ['test1', 'test12', 'test21'].each do |iname|
            result_hash.keys.should include iname
            result_hash[iname].should be_kind_of(Hash)
            result_hash[iname].length.should == 3
          end
        end

        it "should find 2 instances when searching for test1*" do
          method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_find('#{@domain}/EVM/AUTOMATE/test1*')"
          @ae_method.update_attributes(:data => method)
          result_hash = invoke_ae.root(@ae_result_key)
          result_hash.should be_kind_of(Hash)
          result_hash.length.should == 2
          ['test1', 'test12'].each do |iname|
            result_hash.keys.should include iname
            result_hash[iname].should be_kind_of(Hash)
            result_hash[iname].length.should == 3
          end
        end

        it "should find 1 instances when searching for test1?" do
          method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_find('#{@domain}/EVM/AUTOMATE/test1?')"
          @ae_method.update_attributes(:data => method)
          result_hash = invoke_ae.root(@ae_result_key)
          result_hash.should be_kind_of(Hash)
          result_hash.length.should == 1
          ['test12'].each do |iname|
            result_hash.keys.should include iname
            result_hash[iname].should be_kind_of(Hash)
            result_hash[iname].length.should == 3
          end
        end
      end

    end

    context "$evm.instance_get" do
      it "instance does not exist" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_get('#{@domain}/EVM/AUTOMATE/testadd')"
        @ae_method.update_attributes(:data => method)
        result_hash = invoke_ae.root(@ae_result_key)
        result_hash.should be_nil
      end

      it "instance exists" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_get('#{@domain}/EVM/AUTOMATE/test1')"
        @ae_method.update_attributes(:data => method)
        result_hash = invoke_ae.root(@ae_result_key)
        result_hash.should be_kind_of(Hash)
        result_hash.length.should == 3
      end
    end

    context "$evm.instance_get_display_name" do
      it "instance does not exist" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_get_display_name('#{@domain}/EVM/AUTOMATE/testadd')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == nil
      end

      it "instance does exist" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_get_display_name('#{@domain}/EVM/AUTOMATE/test1')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should be_nil
      end
    end

    context "$evm.instance_set_display_name" do
      it "instance does not exist" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_set_display_name('#{@domain}/EVM/AUTOMATE/testadd', 'foo')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == false
      end

      it "instance does exist" do
        display_name = 'Supercalifragilisticexpialidocious'
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_set_display_name('#{@domain}/EVM/AUTOMATE/test1', #{display_name.inspect})"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == true

        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_get_display_name('#{@domain}/EVM/AUTOMATE/test1')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == display_name
      end
    end

    context "$evm.instance_update" do
      it "instance does not exist" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_update('#{@domain}/EVM/AUTOMATE/testadd', 'method1' => 'testattributevalue', 'var1' => 'variablevalue1')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == false
      end

      it "readonly domain" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_update('#{@domain}/EVM/AUTOMATE/test1', 'method1' => 'a', 'var1' => 'b')"
        assert_readonly_instance(method)
      end

      it "instance does not exist, create it, then update it" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_create('#{@domain}/EVM/AUTOMATE/testadd', { 'method1' => 'testattributevalue', 'var1' => 'variablevalue1'})"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == true

        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_update('#{@domain}/EVM/AUTOMATE/testadd', { 'method1' => 'testattributevaluechanged', 'var1' => 'variablevalue1changed'})"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == true
      end
    end

    context "$evm.instance_delete" do
      it "nonexistant instance " do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_delete('#{@domain}/bogus/evenworse/fred')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == false
      end

      it "readonly domain " do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_delete('#{@domain}/EVM/AUTOMATE/test1')"
        assert_readonly_instance(method)
      end

      it "make sure instance does not exist, create new instance, make sure it exists, delete it, then check if it exists" do
        #Now the instance should not exist
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_exists?('#{@domain}/EVM/AUTOMATE/testadd')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == false

        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_create('#{@domain}/EVM/AUTOMATE/testadd', { 'method1' => 'testattributevalue' , 'var1' => 'variablevalue1'})"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == true

        #Now the instance should exist
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_exists?('#{@domain}/EVM/AUTOMATE/testadd')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == true

        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_delete('#{@domain}/EVM/AUTOMATE/testadd')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == true

        #Now the instance should not exist
        method   = "$evm.root['#{@ae_result_key}'] = $evm.instance_exists?('#{@domain}/EVM/AUTOMATE/testadd')"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should == false
      end
    end

  end
end
