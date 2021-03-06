require 'contentful/management'
require 'contentful/management/error'
require 'contentful/bootstrap/templates'
require 'contentful/bootstrap/commands/base'
require 'contentful/bootstrap/commands/generate_token'

module Contentful
  module Bootstrap
    module Commands
      class CreateSpace < Base
        attr_reader :template_name, :json_template
        def initialize(token, space, options = {})
          @template_name = options.fetch(:template, nil)
          @json_template = options.fetch(:json_template, nil)
          @mark_processed = options.fetch(:mark_processed, false)

          super(token, space, options)
        end

        def run
          output "Creating Space '#{@space}'"

          new_space = fetch_space

          output "Space '#{@space}' created!"
          output

          create_template(new_space) unless @template_name.nil?
          create_json_template(new_space) unless @json_template.nil?

          access_token = generate_token(new_space)
          output
          output "Space ID: '#{new_space.id}'"
          output "Access Token: '#{access_token}'"
          output
          output 'You can now insert those values into your configuration blocks'
          output "Manage your content at https://app.contentful.com/spaces/#{new_space.id}"

          new_space
        end

        protected

        def fetch_space
          new_space = nil
          begin
            options = {
              name: @space
            }
            options[:organization_id] = @token.read_organization_id unless @token.read_organization_id.nil?
            management_client_init
            new_space = client.spaces.create(options)
          rescue Contentful::Management::NotFound
            fail "Organization ID is required, provide it in Configuration File" if no_input

            output 'Your account has multiple organizations:'
            output organizations.join("\n")
            Support.input('Please insert the Organization ID you\'d want to create the spaces for: ', no_input) do |answer|
              organization_id = answer
              @token.write_organization_id(organization_id)
              output 'Your Organization ID has been stored as the default organization.'
              new_space = client.spaces.create(
                name: @space,
                organization_id: organization_id
              )
            end
          end

          new_space
        end

        private

        def organizations
          management_client_init
          url = client.base_url.sub('spaces', 'token')
          response = client.class.get_http(url, nil, client.request_headers)
          organization_ids = JSON.load(response.body.to_s)['includes']['Organization'].map do |org|
            sprintf('%-20s %s', org['name'], org['sys']['id'])
          end
          organization_ids.sort
        end

        def templates
          {
            blog: Templates::Blog,
            gallery: Templates::Gallery,
            catalogue: Templates::Catalogue
          }
        end

        def create_template(space)
          if templates.key? @template_name.to_sym
            output "Creating Template '#{@template_name}'"

            templates[@template_name.to_sym].new(space, quiet).run
            output "Template '#{@template_name}' created!"
          else
            output "Template '#{@template_name}' not found. Valid templates are '#{templates.keys.map(&:to_s).join('\', \'')}'"
          end
          output
        end

        def create_json_template(space)
          if ::File.exist?(@json_template)
            output "Creating JSON Template '#{@json_template}'"
            Templates::JsonTemplate.new(space, @json_template, @mark_processed, true, quiet).run
            output "JSON Template '#{@json_template}' created!"
          else
            output "JSON Template '#{@json_template}' does not exist. Please check that you specified the correct file name."
          end
          output
        end

        def generate_token(space)
          Contentful::Bootstrap::Commands::GenerateToken.new(
            @token, space, options
          ).run
        end
      end
    end
  end
end
