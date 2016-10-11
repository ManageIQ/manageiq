class GenericObjectController < ApplicationController
  before_action :check_privileges

  def create
    generic_object_definition = GenericObjectDefinition.new

    update_model_fields(generic_object_definition)
    generic_object_definition.save!

    render :json => {:message => _("Generic Object Definition created successfully")}
  end

  def save
    generic_object_definition = GenericObjectDefinition.find(params[:id])

    update_model_fields(generic_object_definition)

    render :json => {:message => _("Generic Object Definition saved successfully")}
  end

  def explorer
    @layout = "generic_object"

    allowed_features = ApplicationController::Feature.allowed_features(features)
    @accords = allowed_features.map(&:accord_hash)
    @trees = TreeBuilderGenericObject.new.nodes

    @explorer = true

    render :layout => "application"
  end

  def all_object_data
    all_generic_object_definitions = GenericObjectDefinition.all.select(%w(id name description))

    render :json => all_generic_object_definitions.to_json
  end

  def object_data
    generic_object_definition = GenericObjectDefinition.find(params[:id])

    render :json => {
      :id          => generic_object_definition.id,
      :name        => generic_object_definition.name,
      :description => generic_object_definition.description
    }
  end

  def tree_data
    tree_data = TreeBuilderGenericObject.new.nodes

    render :json => {:tree_data => tree_data}
  end

  private

  def update_model_fields(generic_object_definition)
    generic_object_definition.update_attribute(:name, params[:name])
    generic_object_definition.update_attribute(:description, params[:description])
  end

  def features
    [ApplicationController::Feature.new_with_hash(:role        => "generic_object_explorer",
                                                  :role_any    => true,
                                                  :name        => :generic_object_explorer,
                                                  :accord_name => "generic_object_definition_accordion",
                                                  :title       => _("Generic Objects"))]
  end

  menu_section :aut
end
