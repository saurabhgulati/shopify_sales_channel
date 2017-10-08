module ShopifySalesChannel::Integrations
  def self.included(sub_klass)
    sub_klass.extend ShopifySalesChannel::Integrations::Shopify
  end

  def get_access_token
    return self.class.get_access_token(code, url)
  end

  def get_store_details
    return self.class.get_store_details(access_token, url)
  end

  def set_webhooks
    return self.class.get_store_details(self)
  end

  def sync_orders
    return self.class.sync_orders(self, self.data["orders"], self.data["country"])
  end

  def count_products
    return self.class.count_products(self)
  end


  def check_products
    return self.class.check_products(self, self.data["orders"])
  end

  def get_order
    return self.class.get_order(self, self.order_no)
  end

  def add_tag_to_order
    return self.class.add_tag_to_order(self, self.order_no, self.data["tag"])
  end
end
