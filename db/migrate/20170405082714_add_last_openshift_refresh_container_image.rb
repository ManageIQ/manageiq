class AddLastOpenshiftRefreshContainerImage < ActiveRecord::Migration[5.0]
  def change
    add_column :container_images, :last_openshift_refresh, :datetime
  end
end
