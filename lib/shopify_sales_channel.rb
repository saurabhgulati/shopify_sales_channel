module ShopifySalesChannel
  # Your code goes here...
  require "shopify_sales_channel/integrations"
  require "shopify_sales_channel/integrations/shopify"
  require "json"

  def initialize_sales_channel
    attr_accessor :url, :access_token, :code
    self.class_eval do
      def initialize_store(&param)
        ShopifySalesChannel::Store.new.tap(&param)
      end
    end
  end

  class Store
    attr_accessor :url, :access_token, :code, :webhook_address, :client_id, :client_secret

    include ShopifySalesChannel::Integrations

    def initialize(options={})
      self.url = options[:url]
      self.access_token = options[:access_token]
      self.code = options[:code]
    end
    # def init_store
    #   ShopifySalesChannel::Store.new.tap do |store|
    #     self.access_token = store.access_token
    #   end
    # end
  end

  def self.configure(&param)
    ShopifySalesChannel::Store.new.tap(&param)
  end
end
