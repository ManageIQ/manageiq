class SelfReferentialOrchestrationTemplate < ActiveRecord::Migration[5.0]
  def change
    change_table :orchestration_templates do |t|
      t.references :parent, index: true, comment: "Nested template reference"
      t.string :url, comment: "URL for nested/child template"
    end
  end
end
