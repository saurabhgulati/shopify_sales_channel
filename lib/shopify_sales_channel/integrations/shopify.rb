module ShopifySalesChannel::Integrations::Shopify
  def get_access_token(code, shop_url)
    token_params = {'code' => code, 'client_id' =>	SHOPIFY_CLIENT_ID, 'client_secret' => SHOPIFY_CLIENT_SECRET}
		response = Net::HTTP.post_form(URI.parse("https://#{shop_url}/admin/oauth/access_token"), token_params)
    response = JSON.parse(response.body)
    store_details = get_store_details(response["access_token"], shop_url)
    response = response.merge!(store_details["shop"])
  end

  def get_store_details(access_token, shop_name)
    url = URI("https://#{shop_name}/admin/shop.json")
		http = Net::HTTP.new(url.host, url.port)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		request = Net::HTTP::Get.new(url)
		request["x-shopify-access-token"] = access_token
		response = http.request(request)
		response = JSON.parse(response.body)
    return response
  end

  def set_webhooks(store)
    url = URI("https://#{store.url}/admin/webhooks.json")

		http = Net::HTTP.new(url.host, url.port)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE

		request = Net::HTTP::Post.new(url)
		request["x-shopify-access-token"] = store.access_token
		request["content-type"] = 'application/json'
		SHOPIFY_WEBHOOKS.each do |webhook|
			request.body = {"webhook" => {"topic" => webhook, "address" => "#{HOST}/#{webhook}", "format" => "json"}}.to_json
			response = http.request(request)
			response = JSON.parse(response.body)
			unless response["errors"]
        #do something
      end
		end
  end

  # def get_customers(store)
  #   customers = []
  #   store.marketplaces.each do |marketplace|
  #     url = URI("https://#{store.domain}/admin/customers.json")
  #     http = Net::HTTP.new(url.host, url.port)
  # 		http.use_ssl = true
  # 		http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  #
  # 		request = Net::HTTP::Get.new(url)
  #     request["x-shopify-access-token"] = store.access_token
  #     response = http.request(request)
	# 		response = JSON.parse(response.body)
  #     response["customers"].each do |customer|
  #       name = {"name"=> "#{customer["first_name"]} #{customer["last_name"]}"}
  #       customers << (customer.merge!(name))
  #     end
  #     return customers
  #   end
  # end

  def sync_orders(store, orders, marketplace)
    order = orders.first
    if check_products(store, orders)
      url = URI("https://#{store.url}/admin/orders.json")

  		http = Net::HTTP.new(url.host, url.port)
  		http.use_ssl = true
  		http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  		request = Net::HTTP::Post.new(url)
  		request["x-shopify-access-token"] = store.access_token
  		request["content-type"] = 'application/json'
      cust_name = separate_name(order["ordNm"])
      rec_name = separate_name(order["rcvrNm"])
      line_items = []
      store.variants.map{|v| line_items << {"variant_id" => v["id"], "quantity" => v["order_quantity"]}}
      base_addr_arr = order["rcvrBaseAddr"].split(",")
      state = base_addr_arr.pop.squish || "."
      city_and_postal_code = base_addr_arr.join(" ").split(" ")
      city = city_and_postal_code[1..-1].try(:first) || "."
      postcode = order["rcvrMailNo"] || city_and_postal_code[0]
      request.body = {"order" => {"line_items": line_items, "customer": {"first_name": cust_name[0], "last_name": cust_name[1], "email": order["ordEmail"]}, "shipping_address": {"first_name": rec_name[0], "last_name": rec_name[1], "address1": order["rcvrDtlsAddr"], "city": city, "province": state, "country": marketplace.country, "phone": order["rcvrTlphn"], "zip": postcode}}}.to_json
      response = http.request(request)
      response = JSON.parse(response.body)
      response
    else
      store.errors.add(:base, "products not present for order #{order['ordNo']}")
      return false
    end
  end

  def separate_name(name)
    name_array = name.split(" ")
    first_name = name_array[0]
    last_name = name_array[1..-1].join(" ")
    last_name = "." unless last_name.present?
    separate_name = [first_name, last_name]
  end

  def count_products(store)
    url = URI("https://#{store.url}/admin/products/count.json")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(url)
    request["x-shopify-access-token"] = store.access_token
    request["content-type"] = 'application/json'
    response = http.request(request)
    count = JSON.parse(response.read_body)["count"]
    return count
  end


  def check_products(store, orders)
    url = URI("https://#{store.url}/admin/products.json?limit=150")

		http = Net::HTTP.new(url.host, url.port)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE

		request = Net::HTTP::Get.new(url)
		request["x-shopify-access-token"] = store.access_token
		request["content-type"] = 'application/json'
    response = http.request(request)
    products = JSON.parse(response.read_body)["products"]
    flag = true
    variants = []
    order_sku_qty = orders.map{|x| [x["partCode"], x["ordQty"]] if x["partCode"].present?} | orders.map{|x| [x["sellerPrdCd"], x["ordQty"]] if x["sellerPrdCd"].present?}
    order_sku_hash = order_sku_qty.compact.to_h
    products.each do |product|
    	product["variants"].each do |variant|
        order_skus = order_sku_hash.keys
    	  if (order_skus.include?(variant["sku"]))
          variant["order_quantity"] = order_sku_hash[variant["sku"]]
          variant["pre_order"] = true if product["tags"].split(", ").include?("pre-order")
      	  variants << variant
    	  end
    	end
    end
    #variants = variants.select{|variant| (variant["sku"] == orders["partCode"] || variant["sku"] == orders["sellerPrdCd"])}
    store.variants = variants
    flag = false if variants.blank?
    return flag
  end

  def get_order(store, order_no)
    url = URI("https://#{store.url}/admin/orders/#{order_no}.json")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(url)
    request["x-shopify-access-token"] = store.access_token
    response = http.request(request)
    JSON.parse(response.read_body)
  end

  def add_tag_to_order(store, order_no, data)
    url = URI("https://#{store.url}/admin/orders/#{order_no}.json")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Put.new(url)
    request["content-type"] = 'application/json'
    request["x-shopify-access-token"] = store.access_token
    request.body = {"order": { "tags": data.to_s }}.to_json

    response = http.request(request)
    puts response.read_body
  end
end
