require 'active_support/cache'
require 'active_support/cache/memory_store'
require 'redis/stats/memory_queue'
require 'active_support/core_ext/numeric'

class Redis
  class Stats
    class App < Sinatra::Base
      CONFIG = YAML.load_file(File.dirname(__FILE__) + "/../../../config/redis.yml")
      set :static, true
      set :public_folder, File.dirname(__FILE__) + "/../../../public"
      set :static_cache_control, [:public, :max_age => 300]

      # authentication options
      if !ENV["REDIS_STATS_USERNAME"].nil? or !ENV["REDIS_STATS_PASSWORD"].nil?
        use Rack::Auth::Basic, "Restricted Area" do |username, password|
          [username, password] == [ENV["REDIS_STATS_USERNAME"].to_s, ENV["REDIS_STATS_PASSWORD"].to_s]
        end
      end

      # helpers
      helpers do
        def logger
          @@logger ||= Logger.new STDOUT
        end
        def cache
          @@cache ||= ActiveSupport::Cache::MemoryStore.new
        end
        def stats
          @stats ||= Redis::Stats.new CONFIG
        end
      end

      get '/' do
        IO.read File.dirname(__FILE__) + "/../../../views/index.html"
      end

      get '/servers.json' do
        content_type :json
        stats.servers.to_json
      end

      get '/:name' do
        IO.read File.dirname(__FILE__) + "/../../../views/index.html"
      end

      get '/:name/stats.json' do
        content_type :json
        cache_key = "map:#{params[:name]}"
        map = cache.read cache_key
        if map.nil? or map[:timestamp] < 5.minutes.ago.to_i
          # map is not calculated yet
          # be sure that cache is empty
          cache.delete cache_key
          # check for the status of job
          unless Redis::Stats::MemoryQueue.status cache_key
            # job is not working so run it!
            Redis::Stats::MemoryQueue.run cache_key, { name: params[:name] } do |params|
              # calculate the stats
              server_stats = stats.key_sizes params[:name]
              # form the response hash
              cache.write cache_key, {
                status: true,
                timestamp: Time.now.to_i,
                name: "redis",
                children: server_stats,
                size: server_stats.collect{|s|s["size"]}.inject{|sum,x| sum.to_i + x.to_i }
              }
            end
          end
          # return false as status
          { status: false }.to_json
        else
          map.to_json
        end
      end
    end
  end
end