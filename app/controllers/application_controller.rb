class ApplicationController < ActionController::Base
  include AccountAuthentication
  include StudioClientAuthentication
  include AdminAuthentication
end
