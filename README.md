# About
Redis-stats is an application to monitor your redis servers easily. It also provides a way to visualize the memory usage of your keys which is pretty experimental at the moment.

# Authentication
The app has no authentication unless you set one or more of the environment variables below (Basic HTTP authentication is used):

* REDIS_STATS_USERNAME
* REDIS_STATS_PASSWORD


# Configuration
Configuration is done via the redis.yml file in config directory. The default one is a pretty simple version for the localhost.

Below there's an advanced example followed by the available options.

```
production.1:
  url: redis://production.1.redis:11008/
  fields: redis_version, connected_clients
  limit: 1073741824
  
production.2:
  url: redis://production.2.redis:11008/
  fields: redis_version, connected_clients
  limit: 1073741824  
```

## Options
* **url:** URL of your server
* **fields:** which fields from your server's INFO response (defaults are redis_version, os, uptime_in_seconds, uptime_in_days, connected_clients, used_memory_human, used_memory_peak_human, mem_fragmentation_ratio, role and connected_slaves)
* **limit:** Memory limit of your server in bytes (This value may not be present in INFO responses so it must be written here).

## Usage Bar
Usage bar in your server's dashboard only appears if you have specified a limit in the configuration.

# Warning
This project uses **DEBUG OBJECT** call to find out the sizes of keys in memory. If this call is not enabled in your server you won't be able to use **Memory Map** feature.