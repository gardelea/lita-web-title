require "uri"
require "nokogiri"
module Lita
  module Handlers
    class WebTitle < Handler
      config :ignore_patterns, types: [String, Array]

      URI_PROTOCOLS = %w( http https )
      route(URI.regexp(URI_PROTOCOLS), :parse_uri_request, help: {
        "URL" => "Responds with the title of the web page at URL"
      })

      def parse_uri_request(request)
        requestUri = URI::extract(request.message.body, URI_PROTOCOLS).first
        if config.ignore_patterns then
          if config.ignore_patterns.kind_of?(String) then
            Array(config.ignore_patterns)
          end
          config.ignore_patterns.each do |pattern|
            return if requestUri.match(%r{#{pattern}})
          end
        end
        result = parse_uri(requestUri)
        request.reply(
          render_template("web_title",
            :title => result.delete("\n").strip,
            :link => requestUri
          )
        )
      end

      def parse_uri(uriString)
        httpRequest = http.get(uriString)
        if httpRequest.status == 200
          return unless httpRequest.headers['Content-Type'] =~ %r{text/x?html}
          find_title(httpRequest.body)
        elsif [300, 301, 302, 303].include? httpRequest.status then
          parse_uri httpRequest.headers["Location"]
        else
          nil
        end
      rescue Exception => msg
        log.error("lita-web-title: Exception attempting to load URL: #{msg}")
        nil
      end

      def find_title(html)
        title_tag = Nokogiri::HTML(html).css('title').first
        return if title_tag.nil?

        title_tag.text
          .gsub(/(\A\s+|\s+\Z)/, '')
          .gsub(/\s+/, ' ')
      end
    end

    Lita.register_handler(WebTitle)
  end
end
