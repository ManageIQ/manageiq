RSpec.describe MiqUserScope do
  context "testing hash_to_scope method" do
    before do
    end

    it "should return the correct converted scope instance" do
      filters = {"managed" => [["/managed/function/desktop"]], "belongsto" => []}
      scope = MiqUserScope.hash_to_scope(filters)
      expect(scope.view).to eq({:managed => {:_all_ => [["/managed/function/desktop"]]}})
      expect(scope.admin).to be_nil
      expect(scope.control).to be_nil
    end
  end

  context "testing get_filters method" do
    before do
      @scope1 = MiqUserScope.new(
        :view =>           {:belongsto =>
                                          {:_all_ =>               ["/belongsto/ExtManagementSystem|VC1/EmsFolder|Datacenters/EmsFolder|DataCenter1/EmsFolder|host/EmsCluster|Cluster1",
                                                                    "/belongsto/ExtManagementSystem|VC1/EmsFolder|Datacenters/EmsFolder|DataCenter2/EmsFolder|host/EmsCluster|Cluster3"]},
                            :managed   =>
                                          {:_all_ =>               [["/managed/department/accounting", "/managed/department/automotive"],
                                                                    ["/managed/location/london", "/managed/location/ny"],
                                                                    ["/managed/service_level/gold", "/managed/service_level/platinum"]]}}
      )

      @scope2_exp = MiqExpression.new("=" => {})
      @scope2 = MiqUserScope.new(
        :view    => {
          :belongsto  => {
            :vm => ["/belongsto/ExtManagementSystem|VC4 IP 14/EmsFolder|Datacenters/EmsFolder|Prod/EmsFolder|vm/EmsFolder|Discovered virtual machine"],
          },
          :managed    => {
            :_all_ => [["/managed/location/chicago", "/managed/location/ny"]],
            :host  => [["/managed/environment/prod"]],
            :vm    => [["/managed/environment/dev"]]
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
        :admin   => {
          # Same structure as :view but refers to a subset of CIs
          :managed => {
            :_all_ => [["/managed/location/ny"]]
          }
        }
      )
    end

    it "should return the correct filters for search" do
      expect(@scope1.get_filters(:class => Vm, :feature_type => :view)).to eq({
        :belongsto  =>
                       ["/belongsto/ExtManagementSystem|VC1/EmsFolder|Datacenters/EmsFolder|DataCenter1/EmsFolder|host/EmsCluster|Cluster1",
                        "/belongsto/ExtManagementSystem|VC1/EmsFolder|Datacenters/EmsFolder|DataCenter2/EmsFolder|host/EmsCluster|Cluster3"],
        :managed    =>
                       [["/managed/department/accounting", "/managed/department/automotive"],
                        ["/managed/location/london", "/managed/location/ny"],
                        ["/managed/service_level/gold", "/managed/service_level/platinum"]],
        :expression => nil
      })
      expect(@scope1.get_filters(:class => Vm, :feature_type => :admin)).to eq({:expression => nil, :belongsto => nil, :managed => nil})
      expect(@scope1.get_filters(:class => Vm, :feature_type => :control)).to eq({:expression => nil, :belongsto => nil, :managed => nil})

      expect(@scope2.get_filters(:class => Vm, :feature_type => :view)).to eq({
        :belongsto  =>
                       ["/belongsto/ExtManagementSystem|VC4 IP 14/EmsFolder|Datacenters/EmsFolder|Prod/EmsFolder|vm/EmsFolder|Discovered virtual machine"],
        :managed    =>
                       [["/managed/location/chicago", "/managed/location/ny"], ["/managed/environment/dev"]],
        :expression => nil
      })

      filters = @scope2.get_filters(:class => Storage, :feature_type => :view)
      expect(filters[:belongsto]).to be_nil
      expect(filters[:managed]).to eq([["/managed/location/chicago", "/managed/location/ny"]])
      expect(filters[:expression]).to eq(@scope2_exp)

      expect(@scope2.get_filters(:class => Vm, :feature_type => :control)).to eq({:expression => nil, :belongsto => nil, :managed => [["/managed/location/chicago"]]})
      expect(@scope2.get_filters(:class => Vm, :feature_type => :admin)).to eq({:expression => nil, :belongsto => nil, :managed => [["/managed/location/ny"]]})
    end
  end

  context "testing merging methods" do
    before do
      @exp1  = {">" => {"value" => "2", "count" => "Vm.hardware.disks"}}
      @exp2  = {">=" => {"value" => "4096", "field" => "Vm-mem_cpu"}}
      @scope = MiqUserScope.new(
        :view => {
          :belongsto  => {
            :_all_ => ["/belongsto/ExtManagementSystem|VC1", "/belongsto/ExtManagementSystem|VC4"],
            :vm    => ["/belongsto/ExtManagementSystem|VC4/EmsFolder|Datacenters/EmsFolder|Prod/EmsFolder|vm/EmsFolder|Discovered virtual machine"],
          },
          :managed    => {
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
      expect(filters[:managed]).to eq([["/managed/location/chicago", "/managed/location/ny"]])

      filters = @scope.get_filters(:class => Host, :feature_type => :view)
      expect(filters[:managed]).to eq([["/managed/location/chicago", "/managed/location/ny", "/managed/location/london"], ["/managed/environment/prod"]])
    end

    it "should correctly merge belongsto filters" do
      filters = @scope.get_filters(:class => Vm, :feature_type => :view)
      expect(filters[:belongsto]).to eq(["/belongsto/ExtManagementSystem|VC1", "/belongsto/ExtManagementSystem|VC4", "/belongsto/ExtManagementSystem|VC4/EmsFolder|Datacenters/EmsFolder|Prod/EmsFolder|vm/EmsFolder|Discovered virtual machine"])
    end

    it "should correctly merge expression filters" do
      filters = @scope.get_filters(:class => Vm, :feature_type => :view)
      expect(filters[:expression].exp).to eq({"or" => [@exp1, @exp2]})
    end
  end
end
