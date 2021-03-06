# frozen_string_literal: true

require 'faraday'
require 'json'

module Mailclerk
  DEFAULT_API_URL = "https://api.mailclerk.app"
  
  class << self
    attr_accessor :api_key
    attr_accessor :api_url
  end
  
  # Gem identity information.
  module Identity
    def self.name
      "mailclerk"
    end

    def self.label
      "Mailclerk Ruby"
    end

    def self.version
      "1.0.2"
    end

    def self.version_label
      "#{ label } #{ version }"
    end
  end

  class MailclerkError < StandardError
  end
  
  class MailclerkAPIError < MailclerkError
    attr_accessor :http_status
    attr_accessor :http_response
    
    def initialize(description, http_status=nil, http_response=nil)
      super(description)
      self.http_status = http_status
      self.http_response = http_response
    end

  end

  class Client
    def initialize(api_key, api_url=nil)
      @api_key = api_key
      @api_url = api_url || ENV['MAILCLERK_API_URL'] || DEFAULT_API_URL
      
      if @api_key.nil?
        raise MailclerkError.new(
          "No Mailclerk API Key provided. Set `Mailclerk.api_key`"
        )
      end

      if @api_url.nil? || @api_url.empty?
        raise MailclerkError.new("Mailclerk API URL empty")
      end
    end
    
    def deliver(template, recipient, data={}, options={})
      conn = Faraday.new(url: @api_url)
      conn.basic_auth(@api_key, '')
      
      response = conn.post('deliver', {
        'template' => template,
        'recipient' => recipient,
        'data' => data,
        'options' => options
      }.to_json, {
        'Content-Type' => 'application/json',
        'X-Client-Version' => Identity.version_label
      })
      
      if response.status >= 400
        begin
          message = JSON.parse(response.body)["message"] || "Unknown"
          description = "Mailclerk API Error: #{ message }"
        rescue JSON::ParserError
          description = "Mailclerk API Unknown Error"
        end
        
        raise MailclerkAPIError.new(
          description, response.status, response
        )

      end
      
      return response
    end
  end

  # Syntax intended to emulate ActionMailer
  def self.deliver(*args)
    api_key = self.api_key || ENV['MAILCLERK_API_KEY']
    
    client = Client.new(api_key, self.api_url)
    return client.deliver(*args)
  end

end
