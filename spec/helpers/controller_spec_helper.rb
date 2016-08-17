module ControllerSpecHelper
  def assert_nested_list(parent, children, relation, label)
    singular_relation = relation.singularize
    parent_route      = controller.restful? ? controller.class.table_name : "#{controller.class.table_name}/show"
    child_route       = controller.restful? ? singular_relation : "#{singular_relation}/show"

    controller.instance_variable_set(:@breadcrumbs, [])
    # Get the nested table
    get :show, :params => {:id => parent.id, :display => relation}

    expect(response.status).to eq(200)
    expect(response).to render_template("layouts/listnav/_#{controller.class.table_name}")

    # Breadcrumbs of nested table contains the right link to itself, which will surface by clicking on the table item
    expect(assigns(:breadcrumbs)).to include({:name => "#{parent.name} (#{label})",
                                              :url  => "/#{parent_route}/#{parent.id}?display=#{relation}"})

    # The table renders all children objects
    children.each do |child_object|
      child_object_row = "miqRowClick(&#39;#{child_object.compressed_id}&#39;, &#39;/#{child_route}/&#39;"
      expect(response.body).to include(child_object_row)
    end

    # display needs to be saved to session for GTL pagination and such
    expect(session["#{controller.class.table_name}_display".to_sym]).to eq(relation)
  end
end
