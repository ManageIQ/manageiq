require "spec_helper"

describe MiqUserScope do
  context "testing hash_to_scope method" do
    before(:each) do
    end

    it "should return the correct converted scope instance" do
      filters = {"managed"=>[["/managed/function/desktop"]], "belongsto"=>[]}
      scope = MiqUserScope.hash_to_scope(filters)
      scope.view.should    == {:managed=>{:_all_=>[["/managed/function/desktop"]]}}
      scope.admin.should   == nil
      scope.control.should == nil
    end
  end

  context "testing get_filters method" do
    before(:each) do
      @scope1 = MiqUserScope.new(
        {:view=>
          {:belongsto=>
            {:_all_=>
              ["/belongsto/ExtManagementSystem|VC1/EmsFolder|Datacenters/EmsFolder|DataCenter1/EmsFolder|host/EmsCluster|Cluster1",
               "/belongsto/ExtManagementSystem|VC1/EmsFolder|Datacenters/EmsFolder|DataCenter2/EmsFolder|host/EmsCluster|Cluster3"]},
           :managed=>
            {:_all_=>
              [["/managed/department/accounting", "/managed/department/automotive"],
               ["/managed/location/london", "/managed/location/ny"],
               ["/managed/service_level/gold", "/managed/service_level/platinum"]]}}}
      )

      @scope2_exp = MiqExpression.new("=" => {})
      @scope2 = MiqUserScope.new(
        :view => {
          :belongsto => {
            :vm => ["/belongsto/ExtManagementSystem|VC4 IP 14/EmsFolder|Datacenters/EmsFolder|Prod/EmsFolder|vm/EmsFolder|Discovered virtual machine"],
          },
          :managed => {
            :_all_ => [["/managed/location/chicago", "/managed/location/ny"]],
            :host => [["/managed/environment/prod"]],
            :vm => [["/managed/environment/dev"]]
          },
          :expression => {
            :storage => @scope2_exp
          }
        },
        :control => {
          # Same structure as :view but refers to a subset of CIs
          :managed => {
            :_all_ => [["/managed/location/chicago"]]
          }
        },
        :admin => {
          # Same structure as :view but refers to a subset of CIs
          :managed => {
            :_all_ => [["/managed/location/ny"]]
          }
        }
      )
    end

    it "should return the correct filters for search" do
      @scope1.get_filters(:class => Vm, :feature_type => :view).should == {
        :belongsto =>
            ["/belongsto/ExtManagementSystem|VC1/EmsFolder|Datacenters/EmsFolder|DataCenter1/EmsFolder|host/EmsCluster|Cluster1",
             "/belongsto/ExtManagementSystem|VC1/EmsFolder|Datacenters/EmsFolder|DataCenter2/EmsFolder|host/EmsCluster|Cluster3"],
        :managed =>
            [["/managed/department/accounting", "/managed/department/automotive"],
             ["/managed/location/london", "/managed/location/ny"],
             ["/managed/service_level/gold", "/managed/service_level/platinum"]],
        :expression => nil
      }
      @scope1.get_filters(:class => Vm, :feature_type => :admin).should   == {:expression=>nil, :belongsto=>nil, :managed=>nil}
      @scope1.get_filters(:class => Vm, :feature_type => :control).should == {:expression=>nil, :belongsto=>nil, :managed=>nil}

      @scope2.get_filters(:class => Vm, :feature_type => :view).should == {
        :belongsto =>
            ["/belongsto/ExtManagementSystem|VC4 IP 14/EmsFolder|Datacenters/EmsFolder|Prod/EmsFolder|vm/EmsFolder|Discovered virtual machine"],
        :managed =>
            [["/managed/location/chicago", "/managed/location/ny"], ["/managed/environment/dev"]],
        :expression => nil
      }

      filters = @scope2.get_filters(:class => Storage, :feature_type => :view)
      filters[:belongsto].should == nil
      filters[:managed].should   == [["/managed/location/chicago", "/managed/location/ny"]]
      filters[:expression].should== @scope2_exp

      @scope2.get_filters(:class => Vm, :feature_type => :control).should == {:expression=>nil, :belongsto=>nil, :managed=>[["/managed/location/chicago"]]}
      @scope2.get_filters(:class => Vm, :feature_type => :admin).should   == {:expression=>nil, :belongsto=>nil, :managed=>[["/managed/location/ny"]]}
    end
  end

  context "testing merging methods" do
    before(:each) do
      @exp1  = {">"=>{"value"=>"2", "count"=>"Vm.hardware.disks"}}
      @exp2  = {">="=>{"value"=>"4096", "field"=>"Vm-mem_cpu"}}
      @scope = MiqUserScope.new(
        :view => {
          :belongsto => {
            :_all_ => ["/belongsto/ExtManagementSystem|VC1", "/belongsto/ExtManagementSystem|VC4"],
            :vm    => ["/belongsto/ExtManagementSystem|VC4/EmsFolder|Datacenters/EmsFolder|Prod/EmsFolder|vm/EmsFolder|Discovered virtual machine"],
          },
          :managed => {
            :_all_ => [["/managed/location/chicago", "/managed/location/ny"]],
            :host  => [["/managed/environment/prod"], ["/managed/location/london"]],
            :vm    => [["/managed/location/ny"]]
          },
            :expression => {
              :_all_ => MiqExpression.new(@exp1),
              :vm    => MiqExpression.new(@exp2)
          }
        }
      )
    end

    it "should correctly merge managed filters" do
      filters = @scope.get_filters(:class => Vm, :feature_type => :view)
      filters[:managed].should == [["/managed/location/chicago", "/managed/location/ny"]]

      filters = @scope.get_filters(:class => Host, :feature_type => :view)
      filters[:managed].should == [["/managed/location/chicago", "/managed/location/ny", "/managed/location/london"], ["/managed/environment/prod"]]
    end

    it "should correctly merge belongsto filters" do
      filters = @scope.get_filters(:class => Vm, :feature_type => :view)
      filters[:belongsto].should == ["/belongsto/ExtManagementSystem|VC1", "/belongsto/ExtManagementSystem|VC4", "/belongsto/ExtManagementSystem|VC4/EmsFolder|Datacenters/EmsFolder|Prod/EmsFolder|vm/EmsFolder|Discovered virtual machine"]
      # filters[:belongsto].should == ["/belongsto/ExtManagementSystem|VC1", "/belongsto/ExtManagementSystem|VC4"]
    end

    it "should correctly merge expression filters" do
      filters = @scope.get_filters(:class => Vm, :feature_type => :view)
      filters[:expression].exp.should == {"or" => [@exp1, @exp2]}
    end
  end
end
