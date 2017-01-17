class SelfReferentialOrchestrationTemplate < ActiveRecord::Migration[5.0]
  def change
    change_table :orchestration_templates do |t|
      t.string :ancestry, :index => true, :comment => "Required field for ancestry gem"
      t.string :url, :comment => "URL for nested/child template"
    end
  end
end
