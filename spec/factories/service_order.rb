FactoryBot.define do
  factory(:service_order) do
    name { "service order" }
    state { "ordered" }

    factory(:shopping_cart) do
      name { "shopping cart" }
      state { "cart" }
    end
  end
end
