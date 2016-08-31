values_hash = {}
values_hash[nil] = '-- select a subnet from a list --'

service = $evm.root.attributes["service_template"] || $evm.root.attributes["service"]
if service.respond_to?(:load_balancer_manager) && service.load_balancer_manager
  unless $evm.root["dialog_cloud_network"].blank?
    cloud_network = $evm.vmdb(:CloudNetwork, $evm.root["dialog_cloud_network"])
    cloud_network.cloud_subnets.each { |f| values_hash[f.id] = f.name }
  end
end

list_values = {
  'sort_by'       => :value,
  'sor_order'     => :ascending,
  'data_type'     => :string,
  'required'      => false,
  'values'        => values_hash,
  'default_value' => nil
}
list_values.each { |key, value| $evm.object[key] = value }
