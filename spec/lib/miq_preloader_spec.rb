describe MiqPreloader do
  describe ".preload" do
    it "preloads once from an object" do
      ems = FactoryGirl.create(:ems_infra)
      expect(ems.vms).not_to be_loaded
      expect { preload(ems, :vms) }.to match_query_limit_of(1)
      expect(ems.vms).to be_loaded
      expect { preload(ems, :vms) }.to match_query_limit_of(0)
    end

    it "preloads from an array" do
      emses = FactoryGirl.create_list(:ems_infra, 2)
      expect { preload(emses, :vms) }.to match_query_limit_of(1)
      expect(emses[0].vms).to be_loaded
    end

    it "preloads from an association" do
      ems = FactoryGirl.create(:ems_infra)
      FactoryGirl.create_list(:vm, 2, :ext_management_system => ems)

      emses = ExtManagementSystem.all
      expect { preload(emses, :vms) }.to match_query_limit_of(2)
    end

    def preload(*args)
      MiqPreloader.preload(*args)
    end
  end

  describe ".preload_and_map" do
    it "preloads from an object" do
      ems = FactoryGirl.create(:ems_infra)
      FactoryGirl.create_list(:vm, 2, :ext_management_system => ems)

      vms = nil
      expect { vms = preload_and_map(ems, :vms) }.to match_query_limit_of(1)
      expect { expect(vms.size).to eq(2) }.to match_query_limit_of(0)
    end

    it "preloads from an association" do
      ems = FactoryGirl.create(:ems_infra)
      FactoryGirl.create_list(:vm, 2, :ext_management_system => ems)

      emses = ExtManagementSystem.all
      expect { preload_and_map(emses, :vms) }.to match_query_limit_of(2)
    end

    def preload_and_map(*args)
      MiqPreloader.preload_and_map(*args)
    end
  end

  describe ".preload_and_scope" do
    it "preloads (object).has_many" do
      ems = FactoryGirl.create(:ems_infra)
      FactoryGirl.create_list(:vm, 2, :ext_management_system => ems)

      vms = nil
      expect { vms = preload_and_scope(ems, :vms) }.to match_query_limit_of(0)
      expect { expect(vms.count).to eq(2) }.to match_query_limit_of(1)
    end

    it "preloads (object.all).has_many" do
      FactoryGirl.create_list(:vm, 2, :ext_management_system => FactoryGirl.create(:ems_infra))
      FactoryGirl.create(:template, :ext_management_system => FactoryGirl.create(:ems_infra))

      vms = nil
      expect { vms = preload_and_scope(ExtManagementSystem.all, :vms_and_templates) }.to match_query_limit_of(0)
      expect { expect(vms.count).to eq(3) }.to match_query_limit_of(1)
    end

    it "respects scopes (object.all).has_many {with scope}" do
      FactoryGirl.create_list(:vm, 2, :ext_management_system => FactoryGirl.create(:ems_infra))
      FactoryGirl.create(:template, :ext_management_system => FactoryGirl.create(:ems_infra))

      expect { expect(preload_and_scope(ExtManagementSystem.all, :vms).count).to eq(2) }.to match_query_limit_of(1)
    end

    it "preloads (object.all).has_many.belongs_to" do
      ems = FactoryGirl.create(:ems_infra)
      FactoryGirl.create_list(:vm, 2,
                              :ext_management_system => ems,
                              :host                  => FactoryGirl.create(:host, :ext_management_system => ems))
      FactoryGirl.create(:vm, :ext_management_system => ems,
                              :host                  => FactoryGirl.create(:host, :ext_management_system => ems))

      hosts = nil
      vms = nil
      expect { vms = preload_and_scope(ExtManagementSystem.all, :vms_and_templates) }.to match_query_limit_of(0)
      expect { hosts = preload_and_scope(vms, :host) }.to match_query_limit_of(0)
      expect { expect(hosts.count).to eq(2) }.to match_query_limit_of(1)
    end

    it "preloads (object.all).belongs_to.has_many" do
      ems = FactoryGirl.create(:ems_infra)
      host = FactoryGirl.create(:host, :ext_management_system => ems)
      FactoryGirl.create_list(:vm, 2,
                              :ext_management_system => ems,
                              :host                  => host)
      host = FactoryGirl.create(:host, :ext_management_system => ems)
      FactoryGirl.create(:vm, :ext_management_system => ems,
                              :host                  => host)

      emses = nil
      vms = nil
      expect { emses = preload_and_scope(Host.all, :ext_management_system) }.to match_query_limit_of(0)
      expect { vms = preload_and_scope(emses, :vms) }.to match_query_limit_of(0)
      expect { expect(vms.count).to eq(3) }.to match_query_limit_of(1)
    end

    def preload_and_scope(*args)
      MiqPreloader.preload_and_scope(*args)
    end
  end

  describe ".polymorphic_preload_for_child_classes" do
    include_context "simple ems_metadata tree" do
      before { init_full_tree }
    end

    it "preloads polymorphic relationships that are defined" do
      tree    = ems.fulltree_rels_arranged(:except_type => "VmOrTemplate")
      records = Relationship.flatten_arranged_rels(tree)

      hosts_scope   = Host.select(Host.arel_table[Arel.star], :v_total_vms)
      class_loaders = { EmsCluster => [:hosts, hosts_scope], Host => hosts_scope }

      # 4 queries are expected here:
      #
      # - 1 for ExtManagementSystem (root)
      # - 1 for EmsClusters in the tree
      # - 1 for Hosts in the tree
      # - 1 for Hosts from relation in EmsClusters
      #
      # Since all the hosts in this case are also part of the tree, there are
      # "duplicate hosts loaded", but that was the nature of this prior to the
      # change anyway, so this is not new.  This does make it soe that any
      # hosts accessed through a EmsCluster are preloaded, however, instead of
      # an N+1.
      #
      # In some cases, a ems_metatdata tree might not include all of the
      # hosts of a EMS, but some still exist as part of the cluster.  This also
      # makes sure both cases are covered, and the minimal amount of queries
      # are still executed.
      #
      # rubocop:disable Style/BlockDelimiters
      expect {
        MiqPreloader.polymorphic_preload_for_child_classes(records, :resource, class_loaders)
        records.select   { |rel|  rel.resource if rel.resource_type == "Host" }
               .each     { |rel|  rel.resource.v_total_vms }
        records.select   { |rel|  rel.resource if rel.resource_type == "EmsCluster" }
               .flat_map { |rel|  rel.resource.hosts }.each(&:v_total_vms)
      }.to match_query_limit_of(4)
      # rubocop:enable Style/BlockDelimiters
    end
  end
end
