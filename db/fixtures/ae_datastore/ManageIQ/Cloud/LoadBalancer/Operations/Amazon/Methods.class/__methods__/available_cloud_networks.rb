values_hash = {}
values_hash[nil] = 'EC2-classic'

service = $evm.root.attributes["service_template"] || $evm.root.attributes["service"]
if service.respond_to?(:load_balancer_manager) && service.load_balancer_manager
  service.load_balancer_manager.cloud_networks.each { |f| values_hash[f.id] = f.name }
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
