$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "shopify_sales_channel/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "shopify_sales_channel"
  s.version     = ShopifySalesChannel::VERSION
  s.authors     = [""]
  s.email       = [""]
  s.homepage    = ""
  s.summary     = "Summary of ShopifySalesChannel."
  s.description = "Description of ShopifySalesChannel."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 5.1.4"

  s.add_development_dependency "sqlite3"
end
