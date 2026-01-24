# frozen_string_literal: true

require 'securerandom'

# Builds multipart form data for file uploads
class MultipartBuilder
  attr_reader :boundary

  def initialize
    @boundary = generate_boundary
    @body = +''
  end

  def build(binary_data, extension, expiration)
    reset_body
    add_all_fields(binary_data, extension, expiration)
    @body
  end

  def content_type
    "multipart/form-data; boundary=#{@boundary}"
  end

  private

  def generate_boundary
    "----RubyFormBoundary#{SecureRandom.hex(16)}"
  end

  def reset_body
    @body = +''
  end

  def add_all_fields(binary, extension, expiration)
    add_file(binary, extension)
    add_secret
    add_expires(expiration)
    add_closing
  end

  def add_file(data, ext)
    add_boundary
    add_file_headers(ext)
    @body << data
    @body << "\r\n"
  end

  def add_file_headers(extension)
    @body << file_disposition(extension)
    @body << content_type_header
  end

  def file_disposition(extension)
    "Content-Disposition: form-data; name=\"file\"; filename=\"image.#{extension}\"\r\n"
  end

  def content_type_header
    "Content-Type: application/octet-stream\r\n\r\n"
  end

  def add_secret
    add_boundary
    add_field_header('secret')
    @body << "\r\n"
  end

  def add_expires(expiration)
    add_boundary
    add_field_header('expires')
    @body << expiration.to_s
    @body << "\r\n"
  end

  def add_boundary
    @body << "--#{@boundary}\r\n"
  end

  def add_field_header(name)
    @body << "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n"
  end

  def add_closing
    @body << "--#{@boundary}--\r\n"
  end
end
