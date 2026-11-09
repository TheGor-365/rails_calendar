class ApplicationController < ActionController::Base
  include AccountAuthentication
  include AdminAuthentication
end
