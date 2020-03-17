FactoryBot.define do
  factory(:service_order, :class => :ServiceOrderCart) do
    name { "service order" }
    state { "ordered" }

    factory(:shopping_cart) do
      name { "shopping cart" }
      state { "cart" }
    end

    factory :service_order_cart, :parent => :service_order,
                                 :class  => "ServiceOrderCart"
  end
end
