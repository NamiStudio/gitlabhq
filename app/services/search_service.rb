class SearchService
  include Gitlab::Allowable

  def initialize(current_user, params = {})
    @current_user = current_user
    @params = params.dup
  end

  def project
    return @project if defined?(@project)

    @project =
      if params[:project_id].present?
        the_project = Project.find_by(id: params[:project_id])
        can?(current_user, :download_code, the_project) ? the_project : nil
      else
        nil
      end
  end

  def group
    return @group if defined?(@group)

    @group =
      if params[:group_id].present?
        the_group = Group.find_by(id: params[:group_id])
        can?(current_user, :read_group, the_group) ? the_group : nil
      else
        nil
      end
  end

  def show_snippets?
    return @show_snippets if defined?(@show_snippets)

    @show_snippets = params[:snippets] == 'true'
  end

  delegate :scope, to: :search_service

  def search_results
    @search_results ||= search_service.execute
  end

  def search_objects
    @search_objects ||= search_results.objects(scope, params[:page])
  end

  private

  def search_service
    @search_service ||=
      if project
        Search::ProjectService.new(project, current_user, params)
      elsif show_snippets?
        Search::SnippetService.new(current_user, params)
      else
        Search::GlobalService.new(current_user, params)
      end
  end

  attr_reader :current_user, :params
end
