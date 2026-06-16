class ApplicationController < ActionController::Base
  before_action :set_header_gradient

  private

  def set_header_gradient
    return if valid_header_gradient?

    colors = helpers.session_gradient_palettes.sample

    session[:header_gradient] = {
      "angle" => rand(95..145),
      "colors" => colors
    }
  end

  def valid_header_gradient?
    colors = Array(session[:header_gradient]&.dig("colors"))
    allowed = helpers.session_gradient_palettes

    allowed.include?(colors)
  end
end
