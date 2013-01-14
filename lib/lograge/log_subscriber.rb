require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/hash'
require 'active_support/log_subscriber'

module Lograge
  class RequestLogSubscriber < ActiveSupport::LogSubscriber
    def process_action(event)
      payload = event.payload

      data      = extract_request(payload)
      data.merge! extract_status(payload)
      data.merge! runtimes(event)
      data.merge! location(event)
      data.merge! custom_options(event)
      data.merge! add_params(payload)

      logger.info send(:"process_action_#{Lograge.log_format}", data)
    end

    LOGRAGE_FIELDS = [
      :method, :path, :format, :controller, :action, :status, :error,
      :duration, :view, :db, :location, :params
    ]
    def process_action_lograge(data)
      fields  = LOGRAGE_FIELDS
      fields += (data.keys - LOGRAGE_FIELDS)

      event = fields.inject([]) do |message, key|
        next message unless data.has_key?(key)
        # Exactly preserve the previous output
        # Parsing this can be ambigious if the error messages contains
        # a single quote
        data[key] = "'#{data[key]}'" if key == :error
        # Ensure that we always have exactly two decimals
        data[key] = "%.2f" % data[key] if data[key].is_a? Float

        message << "#{key}=#{data[key]}"
        message
      end
      event.join(" ")
    end

    def process_action_logstash(data)
      event = LogStash::Event.new("@fields" => data)
      event.to_json
      # TODO this bit looks suspect
      # message = "[END]   #{payload[:method]} #{payload[:path]} format=#{payload[:format]} action=#{payload[:params]['controller']}##{payload[:params]['action']}"
      # message << extract_status(payload)
      # message << runtimes(event)
      # message << location(event)
      # message << custom_options(event)
      # message << add_params(payload)
      # logger.info(message)
    end

    def redirect_to(event)
      Thread.current[:lograge_location] = event.payload[:location]
    end

    private

    def extract_request(payload)
      {
        :method => payload[:method],
        :path => extract_path(payload),
        :format => extract_format(payload),
        :controller => payload[:params]['controller'],
        :action => payload[:params]['action']
      }
    end

    def extract_path(payload)
      payload[:path].split("?").first
    end

    def extract_format(payload)
      if ::ActionPack::VERSION::MAJOR == 3 && ::ActionPack::VERSION::MINOR == 0
        payload[:formats].first
      else
        payload[:format]
      end
    end

    def extract_status(payload)
      if payload[:status]
        { :status => payload[:status].to_i }
      elsif payload[:exception]
        exception, message = payload[:exception]
        { :status => 500, :error => "#{exception}:#{message}" }
      else
        { :status => 0 }
      end
    end

    INTERNAL_PARAMS = %w(controller action format _method only_path)
    def add_params(payload)
      params = (payload[:params] || {}).except(*INTERNAL_PARAMS)
      if params.present?
        {:params => params.each {|name,value| " #{name}=#{value}"} }
      else
        {}
      end
    end

    def custom_options(event)
      Lograge.custom_options(event) || {}
    end

    def runtimes(event)
      {
        :duration => event.duration,
        :view => event.payload[:view_runtime],
        :db => event.payload[:db_runtime]
      }.inject({}) do |runtimes, (name, runtime)|
        runtimes[name] = runtime.to_f.round(2) if runtime
        runtimes
      end
    end

    def location(event)
      if location = Thread.current[:lograge_location]
        Thread.current[:lograge_location] = nil
        { :location => location }
      else
        {}
      end
    end
  end
end
