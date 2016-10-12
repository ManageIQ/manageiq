module Spec
  module Support
    module ControllerHelper
      def assigns(key = nil)
        if key.nil?
          @controller.view_assigns.symbolize_keys
        else
          @controller.view_assigns[key.to_s]
        end
      end

      def setup_zone
        EvmSpecHelper.create_guid_miq_server_zone
      end

      shared_context "valid session" do
        let(:privilege_checker_service) { double("PrivilegeCheckerService", :valid_session?  => true) }

        before do
          allow(controller).to receive(:set_user_time_zone)
          allow(PrivilegeCheckerService).to receive(:new).and_return(privilege_checker_service)
        end
      end

      def seed_session_trees(a_controller, active_tree, node = nil)
        session[:sandboxes] = {
          a_controller => {
            :trees       => {
              active_tree => {}
            },
            :active_tree => active_tree
          }
        }
        session[:sandboxes][a_controller][:trees][active_tree][:active_node] = node unless node.nil?
      end

      def assert_nested_list(parent, children, relation, label, child_path: nil, gtl_types: nil)
        gtl_types    ||= [:list, :tile, :grid]
        child_path   ||= relation.singularize
        parent_route = controller.restful? ? controller.class.table_name : "#{controller.class.table_name}/show"
        child_route  = "#{child_path}/show"

        controller.instance_variable_set(:@breadcrumbs, [])
        # TODO(lsmola) we should just cycle through all gtl types, to test all list views
        controller.instance_variable_set(:@gtl_type, gtl_types.first)
        # Get the nested table
        get :show, :params => {:id => parent.id, :display => relation}

        expect(response.status).to eq(200)
        expect(response).to render_template("layouts/listnav/_#{controller.class.table_name}")

        # Breadcrumbs of nested table contains the right link to itself, which will surface by clicking on the table item
        expect(assigns(:breadcrumbs)).to include(:name => "#{parent.name} (#{label})",
                                                 :url  => "/#{parent_route}/#{parent.id}?display=#{relation}")

        # TODO(lsmola) for some reason, the toolbar is not being rendered
        # expect(response.body).to include('title="Grid View" id="view_grid" data-url="/show/" data-url_parms="?type=grid"')
        # expect(response.body).to include('title="Tile View" id="view_tile" data-url="/show/" data-url_parms="?type=tile"')
        # expect(response.body).to include('title="List View" id="view_list" data-url="/show/" data-url_parms="?type=list"')

        # The table renders all children objects
        children.each do |child_object|
          child_object_row = "miqRowClick(&#39;#{child_object.compressed_id}&#39;, &#39;/#{child_route}/&#39;"
          expect(response.body).to include(child_object_row)
        end

        # display needs to be saved to session for GTL pagination and such
        expect(session["#{controller.class.table_name}_display".to_sym]).to eq(relation)
      end
    end
  end
end
