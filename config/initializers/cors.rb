Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:3001', 'https://mon-garage-d73hunanv-amine-affifs-projects.vercel.app'

    resource '*',
         headers: :any,
         methods: [:get, :post, :put, :patch, :delete, :options, :head],
         credentials: true,
         expose: ['Authorization']
  end
end
