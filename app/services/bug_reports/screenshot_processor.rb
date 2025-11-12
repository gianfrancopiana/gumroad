# frozen_string_literal: true

module BugReports
  class ScreenshotProcessor
    def initialize(screenshot_blob, page_url:)
      @screenshot_blob = screenshot_blob
      @page_url = page_url
    end

    def process
      return nil unless @screenshot_blob

      original_path = download_to_temp_file(@screenshot_blob)
      sanitized_path = blur_sensitive_content(original_path)

      {
        original: original_path,
        sanitized: sanitized_path,
        blur_metadata: @blur_metadata
      }
    rescue => e
      Rails.logger.error("ScreenshotProcessor failed: #{e.message}")
      nil
    end

    private
      attr_reader :page_url

      def download_to_temp_file(blob)
        temp_file = Tempfile.new(["screenshot", ".png"])
        temp_file.binmode
        blob.download { |chunk| temp_file.write(chunk) }
        temp_file.rewind
        @original_temp_file = temp_file
        temp_file.path
      end

      def blur_sensitive_content(image_path)
        config = get_sanitization_config
        return image_path if config[:blur_patterns].all? { |_, v| v == false } && config[:blur_selectors].empty?

        @blur_metadata = {
          blurred_patterns: [],
          blurred_selectors: [],
          timestamp: Time.current.iso8601
        }

        sanitized_path = Tempfile.new(["screenshot_sanitized", ".png"])
        sanitized_path.binmode

        if image_processing_available?
          process_with_image_magick(image_path, sanitized_path.path, config)
        else
          FileUtils.cp(image_path, sanitized_path.path)
        end

        sanitized_path.path
      end

      def get_sanitization_config
        page_type = detect_page_type
        config = BUG_REPORT_SANITIZATION_CONFIG[page_type.to_sym] || BUG_REPORT_SANITIZATION_CONFIG[:default]

        {
          blur_patterns: config[:blur_patterns] || {},
          blur_selectors: config[:blur_selectors] || []
        }
      end

      def detect_page_type
        return "default" if page_url.blank?

        url_path = URI.parse(page_url).path rescue "/"

        case url_path
        when %r{/checkout}, %r{/cart}
          "checkout"
        when %r{/dashboard}, %r{/sales}, %r{/analytics}
          "dashboard"
        when %r{/settings}, %r{/account}
          "settings"
        when %r{/p/}, %r{/products}
          "product"
        when %r{/discover}, %r{^/$}
          "marketing"
        else
          "default"
        end
      end

      def image_processing_available?
        system("which convert > /dev/null 2>&1")
      end

      def process_with_image_magick(input_path, output_path, config)
        blur_patterns = config[:blur_patterns]

        if blur_patterns[:email_addresses] || blur_patterns[:credit_card_numbers] || blur_patterns[:phone_numbers]
          blur_entire_image(input_path, output_path)
          @blur_metadata[:blurred_patterns] = blur_patterns.select { |_, v| v }.keys.map(&:to_s)
        else
          FileUtils.cp(input_path, output_path)
        end
      end

      def blur_entire_image(input_path, output_path)
        system("convert", input_path, "-blur", "0x15", output_path)
      end
  end
end

