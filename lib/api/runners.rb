module API
  # Runners API
  class Runners < Grape::API
    before { authenticate! }

    resource :runners do
      # Get available shared runners
      #
      # Example Request:
      #   GET /runners
      get do
        runners =
          if current_user.is_admin?
            Ci::Runner.all
          else
            current_user.ci_authorized_runners
          end

        runners = filter_runners(runners, params[:scope])
        present paginate(runners), with: Entities::Runner
      end

      get ':id' do
        runner = get_runner(params[:id])
        can_show_runner?(runner) unless current_user.is_admin?

        present runner, with: Entities::RunnerDetails
      end

      put ':id' do
        runner = get_runner(params[:id])
        can_update_runner?(runner) unless current_user.is_admin?

        attrs = attributes_for_keys [:description, :active, :tag_list]
        if runner.update(attrs)
          present runner, with: Entities::RunnerDetails
        else
          render_validation_error!(runner)
        end
      end

      delete ':id' do
        runner = get_runner(params[:id])
        can_delete_runner?(runner)
        runner.destroy!

        present runner, with: Entities::RunnerDetails
      end
    end

    resource :projects do
      before { authorize_admin_project }

      # Get runners available for project
      #
      # Example Request:
      #   GET /projects/:id/runners
      get ':id/runners' do
        runners = filter_runners(Ci::Runner.owned_or_shared(user_project.id), params[:scope])
        present paginate(runners), with: Entities::Runner
      end
    end

    helpers do
      def filter_runners(runners, scope)
        return runners unless scope.present?

        available_scopes = ::Ci::Runner::AVAILABLE_SCOPES
        unless (available_scopes && scope).empty?
          runners.send(scope)
        else
          render_api_error!('Scope contains invalid value', 400)
        end
      end

      def get_runner(id)
        runner = Ci::Runner.find(id)
        not_found!('Runner') unless runner
        runner
      end

      def can_show_runner?(runner)
        return true if runner.is_shared
        forbidden!("Can't show runner's details - no access granted") unless user_can_access_runner?(runner)
      end

      def can_update_runner?(runner)
        return true if current_user.is_admin?
        forbidden!("Can't update shared runner") if runner.is_shared?
        forbidden!("Can't update runner - no access granted") unless user_can_access_runner?(runner)
      end

      def can_delete_runner?(runner)
        return true if current_user.is_admin?
        forbidden!("Can't delete shared runner") if runner.is_shared?
        forbidden!("Can't delete runner - associated with more than one project") if runner.projects.count > 1
        forbidden!("Can't delete runner - no access granted") unless user_can_access_runner?(runner)
      end

      def user_can_access_runner?(runner)
        runner.projects.inject(false) do |final, project|
          final ||= abilities.allowed?(current_user, :admin_project, project)
        end
      end
    end
  end
end
