require 'uri'
class Redis
  class Stats
    def initialize config
      @servers = Hash[config.collect do |server, options|
        uri = URI.parse options["url"]
        [server, Redis.new(timeout: 60, host: uri.host, port: uri.port, password: uri.password, thread_safe: true)]
      end]
      @options = config
    end

    def servers
      @servers.collect do |name, server|
        {
          name: name,
          host: server.client.host,
          port: server.client.port,
          info: server.info,
          usage: usage(name),
          fields: fields(name)
        }
      end
    end

    def as_size s
      units = %W(B K M G T)

      size, unit = units.reduce(s.to_f) do |(fsize, _), utype|
        fsize > 512 ? [fsize / 1024, utype] : (break [fsize, utype])
      end

      "#{size > 9 || size.modulo(1) < 0.1 ? '%d' : '%.1f'}%s" % [size, unit]
    end

    def fields name
      limit = @options[name]["fields"]
      limit ||= [
        "redis_version",
        "os",
        "uptime_in_seconds",
        "uptime_in_days",
        "connected_clients",
        "used_memory_human",
        "used_memory_peak_human",
        "mem_fragmentation_ratio",
        "role",
        "connected_slaves"
      ]
    end

    def usage name
      limit = @options[name]["limit"]
      server_info = @servers[name].info
      return nil if limit.nil?
      {
        limit: as_size(limit),
        used: server_info["used_memory_human"],
        percentage: ((server_info["used_memory"].to_f / limit.to_f) * 100).round
      }
    end

    def key_tree name
      self.class.to_tree self.class.key_sizes(@servers[name])
    end

    def key_sizes name
      self.class.key_sizes(@servers[name])
    end

    class << self
      def key_sizes server
        server.keys.collect do |k|
          begin
            {name: k, children:[], size: key_size(server, k)}
          rescue
            nil
          end
        end.reject(&:nil?)
      end

      def to_tree array
        tree = {}
        array.each do |leaf|
          parts = leaf[:name].squeeze(":").split(":",2)
          if parts.size > 1
            tree[parts.first] ||= {
              name: parts.first,
              children: [],
              size: 0
            }
            tree[parts.first][:size] += leaf[:size]
            tree[parts.first][:children] << {
              name: parts.last,
              children: [],
              size: leaf[:size]
            }
          else
            tree[leaf[:name]] ||= {
              name: leaf[:name],
              children: [],
              size: 0
            }
            tree[leaf[:name]][:size] += leaf[:size]
          end
        end
        tree.collect do |k,n|
          n[:children] = to_tree n[:children]
          n
        end
      end

      # Key size in bytes
      def key_size server, key
        server
          .debug(:object, key)
          .scan(/serializedlength:([0-9]+)/)
          .flatten.first.to_i
      end
    end
  end
end
