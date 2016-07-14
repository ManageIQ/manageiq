describe TreeBuilderRolesByServer do
  context 'TreeBuilderRolesByServer' do
    before do
      MiqRegion.seed
      @miq_server = EvmSpecHelper.local_miq_server
      @server_role = FactoryGirl.create(
        :server_role,
        :name              => "smartproxy",
        :description       => "SmartProxy",
        :max_concurrent    => 1,
        :external_failover => false,
        :role_scope        => "zone"
      )

      @assigned_server_role1 = FactoryGirl.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server.id,
        :server_role_id => @server_role.id,
        :active         => true,
        :priority       => 1
      )

      @assigned_server_role2 = FactoryGirl.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server.id,
        :server_role_id => @server_role.id,
        :active         => true,
        :priority       => 2
      )
      @sb = {:active_tree => :diagnostics_tree}
      parent = MiqRegion.my_region
      @sb[:selected_server_id] = parent.id
      @sb[:selected_typ] = "miq_region"
      @server_tree = TreeBuilderRolesByServer.new(:roles_by_server_tree, :roles_by_server, @sb, true, parent)
    end


    it "is not lazy" do
      tree_options = @server_tree.send(:tree_init_options, :roles_by_server)
      expect(tree_options[:lazy]).to eq(false)
    end

    it 'has no root' do
      tree_options = @server_tree.send(:tree_init_options, :roles_by_server)
      root = @server_tree.send(:root_options)
      expect(tree_options[:add_root]).to eq(false)
      expect(root).to eq([])
    end

    it 'returns server nodes as root kids' do
      server_nodes = @server_tree.send(:x_get_tree_roots, false)
      expect(server_nodes).to eq([@miq_server])
    end

    it 'returns Roles by Servers' do
      nodes = [{:key      => "svr-#{MiqRegion.compress_id(@miq_server.id)}",
                :title    => "<b class='dynatree-title'>Server: #{@miq_server.name} [#{@miq_server.id}] (current) (started)</b>",
                :icon     => ActionController::Base.helpers.image_path('100/miq_server.png'),
                :expand   => true,
                :tooltip  => "Server: #{@miq_server.name} [#{@miq_server.id}] (current) (started)",
                :children => [{:key      => "asr-#{MiqRegion.compress_id(@assigned_server_role1.id)}",
                               :addClass => "dynatree-title",
                               :title    => "Role: SmartProxy (primary, active, PID=)",
                               :icon     => ActionController::Base.helpers.image_path('100/on.png'),
                               :expand   => true,
                               },
                              {:key      => "asr-#{MiqRegion.compress_id(@assigned_server_role2.id)}",
                               :addClass => "dynatree-title",
                               :title    => "Role: SmartProxy (secondary, active, PID=)",
                               :icon     => ActionController::Base.helpers.image_path('100/on.png'),
                               :expand   => true,
                              },
                ],
               }]
      p "XXXX #{@server_tree.locals_for_render[:json_tree].inspect}"
      p "XXXX #{nodes.to_json.inspect}"
      expect(@server_tree.locals_for_render[:json_tree]).to eq(nodes.to_json)
    end
  end
end
