Kaminari.configure do |config|
  config.default_per_page = 20
  config.max_per_page = 100
  config.window = 2
  config.outer_window = 1
  config.left = 1
  config.right = 1
  config.page_method_name = :page
  config.param_name = :page
end 