class AddContainerNodeVersionsAndOsImage < ActiveRecord::Migration
  def change
    add_column    :operating_systems, :kernel_version, :string
    add_column    :container_nodes, :kubernetes_kubelet_version, :string
    add_column    :container_nodes, :kubernetes_proxy_version, :string
    add_column    :container_nodes, :container_runtime_version, :string
  end
end
