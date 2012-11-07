require 'active_support/core_ext/class/attribute'
require 'active_support/log_subscriber'

module Lograge
  class RequestLogSubscriber < ActiveSupport::LogSubscriber
    def process_action(event)
      payload = event.payload

      message = "[END] #{payload[:method]} #{payload[:path]} format=#{payload[:format]} action=#{payload[:params]['controller']}##{payload[:params]['action']}"

      message << extract_status(payload)
      message << runtimes(event)
      message << location(event)
      message << custom_options(event)
      message << add_params(payload)
      logger.info(message)
    end

    def redirect_to(event)
      Thread.current[:lograge_location] = event.payload[:location]
    end

    private

    def extract_request(payload)
      "#{payload[:method]} #{payload[:path]} format=#{payload[:format]} action=#{payload[:params]['controller']}##{payload[:params]['action']}"
    end

    def extract_status(payload)
      if payload[:status]
        " status=#{payload[:status]}"
      elsif payload[:exception]
        exception, message = payload[:exception]
        " status=500 error='#{exception}:#{message}'"
      else
        " status=0"
      end
    end

    INTERNAL_PARAMS = %w(controller action format _method only_path)
    def add_params(payload)
      params = (payload[:params] || {}).except(*INTERNAL_PARAMS)
      if params.present?
        message = " params=("
        params.each do |name,value|
          message << " #{name}=#{value}"
        end
        message + " )"
      else
        ""
      end
    end


    def custom_options(event)
      message = ""
      (Lograge.custom_options(event) || {}).each do |name, value|
        message << " #{name}=#{value}"
      end
      message
    end

    def runtimes(event)
      message = ""
      {:duration => event.duration,
       :view => event.payload[:view_runtime],
       :db => event.payload[:db_runtime]}.each do |name, runtime|
        message << " #{name}=%.2f" % runtime if runtime
      end
      message
    end

    def location(event)
      if location = Thread.current[:lograge_location]
        Thread.current[:lograge_location] = nil
        " location=#{location}"
      else
        ""
      end
    end
  end
end
