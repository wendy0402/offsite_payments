module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    module Veritrans

      mattr_accessor :service_url

      def self.service_url
        OffsitePayments.mode == :test ? 'https://api.sandbox.veritrans.co.id/v2' : 'https://api.veritrans.co.id/v2'
      end

      def self.notification(post)
        Notification.new(post)
      end

      class Helper < OffsitePayments::Helper
        attr_accessor :amount, :order

        def initialize(order, account, options = {})
          @payment_type = 'vtweb'
          @server_key = options.delete(:server_key)
          super
        end

        def credential_based_url
          vt_client = VtClient.new(@server_key)
          vt_client.get_redirect_url(mapping_params)
        end

        def form_method
          "GET"
        end

        private
        def mapping_params
          {
            payment_type: 'vtweb',
            transaction_details: { order_id: self.order, gross_amount: self.amount },
            vtweb: {
              credit_card_3d_secure: true
            }
          }
        end
      end

      class VtClient
        def initialize(server_key)
          @server_key = server_key
        end

        def get_redirect_url(params = {})
          uri = URI.parse("#{Veritrans.service_url}/charge")

          request = Net::HTTP::Post.new(uri.path)
          request.basic_auth(@server_key, '')
          request['Accept'] = "application/json"
          request['Content-Type'] = "application/json"
          request.body = params.to_json
          http = Net::HTTP.new(uri.host, uri.port)
          http.verify_mode    = OpenSSL::SSL::VERIFY_NONE unless @ssl_strict
          http.use_ssl        = true

          response = http.request(request)
          json_response = JSON.parse(response.body)

          if [200, 201].include?(json_response['status_code'].to_i)
            json_response['redirect_url']
          else
            raise "status code: #{json_response['status_code']}, validation error: #{json_response['validation_messages']}"
          end
        end

        private
        def uri?(string)
          uri = URI.parse(string)
          ['http','https'].include?(uri.scheme)
        rescue URI::BadURIError
          false
        rescue URI::InvalidURIError
          false
        end
      end

      class Notification < OffsitePayments::Notification
        def complete?
          params['']
        end

        def item_id
          params['']
        end

        def transaction_id
          params['']
        end

        # When was this payment received by the client.
        def received_at
          params['']
        end

        def payer_email
          params['']
        end

        def receiver_email
          params['']
        end

        def security_key
          params['']
        end

        # the money amount we received in X.2 decimal.
        def gross
          params['']
        end

        def currency
          'IDR'
        end

        # Was this a test transaction?
        def test?
          params[''] == 'test'
        end

        def status
          params['']
        end

        # Acknowledge the transaction to Veritrans. This method has to be called after a new
        # apc arrives. Veritrans will verify that all the information we received are correct and will return a
        # ok or a fail.
        #
        # Example:
        #
        #   def ipn
        #     notify = VeritransNotification.new(request.raw_post)
        #
        #     if notify.acknowledge
        #       ... process order ... if notify.complete?
        #     else
        #       ... log possible hacking attempt ...
        #     end
        def acknowledge(authcode = nil)
          payload = raw

          uri = URI.parse(Veritrans.notification_confirmation_url)

          request = Net::HTTP::Post.new(uri.path)

          request['Content-Length'] = "#{payload.size}"
          request['User-Agent'] = "Active Merchant -- http://activemerchant.org/"
          request['Content-Type'] = "application/x-www-form-urlencoded"

          http = Net::HTTP.new(uri.host, uri.port)
          http.verify_mode    = OpenSSL::SSL::VERIFY_NONE unless @ssl_strict
          http.use_ssl        = true

          response = http.request(request, payload)

          # Replace with the appropriate codes
          raise StandardError.new("Faulty Veritrans result: #{response.body}") unless ["AUTHORISED", "DECLINED"].include?(response.body)
          response.body == "AUTHORISED"
        end

        private

        # Take the posted data and move the relevant data into a hash
        def parse(post)
          @raw = post.to_s
          for line in @raw.split('&')
            key, value = *line.scan( %r{^([A-Za-z0-9_.-]+)\=(.*)$} ).flatten
            params[key] = CGI.unescape(value.to_s) if key.present?
          end
        end
      end
    end
  end
end
