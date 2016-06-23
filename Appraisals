appraise "flapjack_1_6" do
  gem "redis", "~> 3.0.6"
  gem "flapjack", "1.6.0"
  gem "flapjack-diner", "1.2.0"
end

appraise "flapjack_2_0" do
  gem 'oj'
  gem "stackprof" # NOTE requires intrumenting flapjack/zermelo gems directly
  gem "zermelo", :github => 'tom-tuddenham-bulletproof/zermelo', :branch => 'merge_and_cache'
  gem "hiredis", "~> 0.6.1"
  gem "redis", "~> 3.2", :require => ["redis", "redis/connection/hiredis"]
  gem "flapjack", "2.0.0", :github => 'tom-tuddenham-bulletproof/flapjack', :branch => 'remove_statistics'
#  gem "flapjack-diner", "2.0.0"
end
