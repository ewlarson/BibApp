Bibapp::Application.routes.draw do

  def make_routes
    resources :works do
      collection do
        get :orphans
        delete :destroy_multiple
        #Following support legacy RJS stuff
        post :reorder_list
        post :add_item_to_list
        post :remove_item_from_list
        post :add_author_to_list
        post :remove_author_from_list
        post :add_contributor_to_list
        post :remove_contributor_from_list
        post :orphans_delete
      end
      member do
        get :merge_duplicates
        get :add_to_saved
        get :remove_from_saved
        put :change_type
      end

      resources :attachments
    end

    #####
    # Person routes
    #####
    resources :people do
      collection do
        get :batch_csv_show
        post :batch_csv_create
      end
      resources :attachments
      resources :works
      resources :groups
      resources :pen_names
      resources :memberships
      resources :roles do
        collection do
          get :new_admin
          get :new_editor
        end
      end
      resources :keywords do
        collection do
          get :timeline
        end
      end
    end

    #####
    # Group routes
    #####
    # Add Auto-Complete routes for adding new groups
    resources :groups do
      collection do
        get :autocomplete
        get :hidden
      end
      member do
        get :hide
        get :unhide
      end
      resources :works
      resources :people
      resources :roles do
        collection do
          get :new_admin
          get :new_editor
        end
      end
      resources :keywords do
        collection do
          get :timeline
        end
      end
    end

    #####
    # Membership routes
    #####
    # Add Auto-Complete routes
    resources :memberships do
      collection do
        put :create_multiple
        post :sort
        post :ajax_sort
        post :search_groups
      end
    end

    #####
    # Contributorship routes
    #####
    resources :contributorships do
      collection do
        get :admin
        get :archivable
        put :act_on_multiple
      end

      member do
        put :verify
        put :deny
      end
    end
    #####
    # Publisher routes
    #####
    resources :publishers do
      collection do
        get :authorities
        put :update_multiple
        get :add_to_box
        get :remove_from_box
        get :autocomplete
      end
    end

    #####
    # Publication routes
    #####
    resources :publications do
      collection do
        get :authorities
        put :update_multiple
        get :add_to_box
        get :remove_from_box
        get :autocomplete
      end
    end

    ####
    # User routes
    ####
    # Make URLs like /user/1/password/edit for Users managing their passwords
    resources :users do
      resources :imports
      resource :password
      collection do
        match 'activate(/:activation_code)', :to => 'users#activate', :as => 'activate'
      end
      member do
        get :update_email
        post :request_update_email
      end
    end

    ####
    # Import routes
    ####
    resources :imports do
      resource :user
      resources :attachments
    end

    ####
    # Search route
    ####
    match 'search', :to => 'search#index', :as => 'search'
    match 'search/advanced', :to => 'search#advanced', :as => 'advanced_search'

    ####
    # Saved routes
    ####
    match 'saved', :to => 'user_sessions#saved', :as => 'saved'
    match 'sessions/delete_saved', :to => 'user_sessions#delete_saved',
          :as => 'delete_saved'
    match 'sessions/add_many_to_saved', :to => 'user_sessions#add_many_to_saved',
          :as => 'add_many_to_saved'
    ####
    # Authentication routes
    ####
    # Make easier routes for authentication (via restful_authentication)
    match 'signup', :to => 'users#new', :as => 'signup'
    match 'login', :to => 'user_sessions#new', :as => 'login'
    match 'logout', :to => 'user_sessions#destroy', :as => 'logout'
    match 'activate/:activation_code', :to => 'users#activate', :as => 'activate'

    ####
    # DEFAULT ROUTES
    ####
    # Install the default routes as the lowest priority.
    resources :name_strings do
      collection do
        get :autocomplete
      end
    end
    resources :memberships
    resources :pen_names do
      collection do
        post :create_name_string
        post :live_search_for_name_strings
        post :sort
      end
    end
    resources :keywords
    resources :keywordings
    resources :passwords
    resources :attachments do
      collection do
        get :add_upload_box
      end
    end

    match 'citations', :to => 'works#index'

    resource :user_session
    resources :authentications
    match '/auth/:provider/callback' => 'authentications#create'
    match '/admin/index' => "admin#index"
    match 'admin/duplicates' => "admin#duplicates"
    match 'admin/ready_to_archive' => "admin#ready_to_archive"
    match 'admin/update_sherpa_data' => "admin#update_sherpa_data"
    match 'admin/deposit_via_sword' => "admin#deposit_via_sword"
    match 'admin/update_publishers_from_sherpa' => "admin#update_publishers_from_sherpa"

    match 'roles/index' => "roles#index"
    match 'roles/destroy' => "roles#destroy"
    match 'roles/create' => "roles#create"
    match 'roles/new_admin' => "roles#new_admin"
    match 'roles/new_editor' => "roles#new_editor"

    # Default homepage to works index action
    root :to => 'works#index'
  end

  #if there are multiple locales we make routes with the locale in the path of the url
  if I18n.available_locales.many?
    locale_regexp = Regexp.new(I18n.available_locales.join('|'))
    scope "(:locale)", :locale => locale_regexp do
      make_routes
    end
  end
  #combined with what ApplicationController does the following makes routes without a locale work
  #properly (making them use the default locale). For a single-locale installation this is all that we need.
  make_routes

end
