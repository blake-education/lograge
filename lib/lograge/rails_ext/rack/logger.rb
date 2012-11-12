require 'rails/rack/logger'

module Rails
  module Rack
    # Makes
    # Started GET / for 192.168.2.1...
    # look more like lograge's output
    class Logger
      # Overwrites Rails 3.2 code that logs new requests
      def call_app(*args)
        env = args.last
        request = ActionDispatch::Request.new(env)
        path = request.filtered_path
        Rails.logger.info "[START] #{request.request_method} #{path}"

        @app.call(env)
      ensure
        ActiveSupport::LogSubscriber.flush_all!
      end

      # Overwrites Rails 3.0/3.1 code that logs new requests
      def before_dispatch(env)
      end
    end
  end
end
