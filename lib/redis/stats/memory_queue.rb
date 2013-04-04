class Redis
  class Stats
    module MemoryQueue
      class << self
        def logger
          @logger ||= Logger.new STDOUT
        end

        def status id
          @status ||= {}
          @status[id] || false
        end

        def run id, params = {}
          @status[id] = true
          Thread.new do
            logger.info "Running job: #{id}"
            begin
              yield params
            rescue Exception => e
              logger.error e
            end
            logger.info "Finished job: #{id}"
            @status[id] = false
          end
        end
      end
    end
  end
end