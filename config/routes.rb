Rails.application.routes.draw do

  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  root :to => redirect(RISM::ROOT_REDIRECT)
	
	## TO BE REVISED!
	get 'catalog/:id/mei' => 'catalog#mei'
	get 'catalog/geosearch/:id' => 'catalog#geosearch'
  post 'catalog/holding' => 'catalog#holding'
  get "catalog/download_xslt" => 'catalog#download_xslt'
  
	##############################
	### Blacklight 6 configuration

  mount Blacklight::Engine => '/'
  mount BlacklightAdvancedSearch::Engine => '/'


  concern :searchable, Blacklight::Routes::Searchable.new
  concern :exportable, Blacklight::Routes::Exportable.new

  resource :catalog, only: [:index], controller: 'catalog' do
    concerns :searchable
    concerns :range_searchable
		concerns :exportable

  end

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end
	
	##############################
  
  devise_for :users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  
  #scope ':locale', locale: I18n.locale do
  #  ActiveAdmin.routes(self)
  #end 
  
  get "/manuscripts", to: redirect('/sources')
  get "/manuscripts/:name", to: redirect('/sources/%{name}')

  get "/sources", to: redirect('/catalog')
  get "/sources/:name", to: redirect('/catalog/%{name}')

  ## Set up routes to redirect legacy /pages from muscat2
  ## to the new site URL
  get '/pages', to: redirect(RISM::LEGACY_PAGES_URL)
  get '/pages/:name', to: redirect(RISM::LEGACY_PAGES_URL + '/pages/%{name}')

  get 'sru' => 'sru#service'
  get 'sru/sources' => 'sru#service'
  # To have backward compatibility with the old interface
  get 'muscat' => 'sru#service'
  get 'sru/people' => 'sru#service'
  get 'sru/institutions' => 'sru#service'
  get 'sru/catalogues' => 'sru#service'
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end
  
  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
