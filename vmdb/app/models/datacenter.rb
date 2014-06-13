class Datacenter < EmsFolder
  default_scope where(:is_datacenter => true)
end
