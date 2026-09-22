defmodule QuizirWeb.QuizLive.MyQuizzes do
  use QuizirWeb, :live_view

  alias Quizir.Quizzes

  @impl true
  def mount(_params, _session, socket) do
    counts = Quizzes.count_user_quizzes_by_visibility(socket.assigns.current_user)

    socket =
      socket
      |> assign(:page_title, "Mes quiz")
      |> assign(:counts, counts)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = normalize_filter(params["filter"])
    user = socket.assigns.current_user
    quizzes = Quizzes.list_user_quizzes(user, filter)

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:quizzes_empty?, quizzes == [])
     |> stream(:quizzes, quizzes, reset: true)}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, push_patch(socket, to: ~p"/my-quizzes?filter=#{filter}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    quiz = Quizzes.get_quiz!(id)
    user = socket.assigns.current_user

    if Quizzes.can_manage_quiz?(quiz, user) do
      {:ok, _} = Quizzes.delete_quiz(quiz)
      counts = Quizzes.count_user_quizzes_by_visibility(user)
      remaining_quizzes = Quizzes.list_user_quizzes(user, socket.assigns.filter)

      {:noreply,
       socket
       |> put_flash(:info, "Quiz « #{quiz.title} » supprimé avec succès.")
       |> assign(:counts, counts)
       |> assign(:quizzes_empty?, remaining_quizzes == [])
       |> stream_delete(:quizzes, quiz)}
    else
      {:noreply, put_flash(socket, :error, "Vous n'êtes pas autorisé à supprimer ce quiz.")}
    end
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Quizzes.duplicate_quiz(id, user) do
      {:ok, duplicated_quiz} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Quiz dupliqué avec succès ! Vous pouvez désormais le personnaliser."
         )
         |> push_navigate(to: ~p"/quizzes/#{duplicated_quiz}/edit")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Impossible de dupliquer ce quiz.")}
    end
  end

  @impl true
  def handle_event("start_game", %{"id" => id} = params, socket) do
    quiz = Quizzes.get_quiz_with_details!(id)
    user = socket.assigns.current_user

    can_start? =
      quiz.visibility == "public" or Quizzes.can_manage_quiz?(quiz, user)

    if can_start? do
      default_vis = if quiz.visibility == "private", do: "private", else: "public"
      visibility = params["visibility"] || default_vis

      case Quizir.Games.create_game(quiz, visibility: visibility) do
        {:ok, %{code: code, host_token: host_token}} ->
          vis_label = if visibility == "public", do: "publique", else: "privée"

          {:noreply,
           socket
           |> put_flash(:info, "Partie #{vis_label} créée ! Code de salon : #{code}")
           |> push_navigate(to: ~p"/games/#{code}?host_token=#{host_token}")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Impossible de démarrer la partie pour ce quiz.")}
      end
    else
      {:noreply,
       put_flash(socket, :error, "Ce quiz est privé. Seul son créateur peut lancer une partie.")}
    end
  end

  defp normalize_filter(filter) when filter in ["public", "private"], do: filter
  defp normalize_filter(_), do: "all"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto py-8 px-4 sm:px-6">
        <!-- 1. En-tête -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-8">
          <div>
            <div class="flex items-center gap-3">
              <div class="p-2.5 rounded-2xl bg-primary/10 text-primary">
                <.icon name="hero-rectangle-stack" class="size-6" />
              </div>
              <h1 class="text-3xl font-black tracking-tight text-base-content">
                Mes Quiz
              </h1>
            </div>
            <p class="text-sm text-base-content/60 mt-1">
              Gérez vos créations, organisez des parties en direct et modifiez vos quiz.
            </p>
          </div>

          <div class="flex items-center gap-3 w-full sm:w-auto">
            <.link
              navigate={~p"/quizzes/new"}
              id="create-quiz-header-btn"
              class="btn btn-primary btn-md font-bold gap-2 flex-1 sm:flex-initial shadow-md"
            >
              <.icon name="hero-plus" class="size-5" /> Créer un quiz
            </.link>
          </div>
        </div>

        <!-- 2. Filtres par statut (Tous / Public / Privé) -->
        <div class="bg-base-100 border border-base-200 rounded-2xl p-2 mb-8 shadow-xs flex flex-wrap items-center justify-between gap-3">
          <div class="flex items-center gap-1.5 flex-wrap" role="tablist">
            <.link
              patch={~p"/my-quizzes?filter=all"}
              id="filter-all-btn"
              class={[
                "btn btn-sm font-bold gap-2 rounded-xl transition",
                if(@filter == "all",
                  do: "btn-primary shadow-xs",
                  else: "btn-ghost text-base-content/70 hover:text-base-content"
                )
              ]}
            >
              <.icon name="hero-squares-2x2" class="size-4" /> Tous
              <span class={[
                "badge badge-xs font-semibold",
                if(@filter == "all", do: "badge-neutral", else: "badge-ghost")
              ]}>
                {@counts.total}
              </span>
            </.link>

            <.link
              patch={~p"/my-quizzes?filter=public"}
              id="filter-public-btn"
              class={[
                "btn btn-sm font-bold gap-2 rounded-xl transition",
                if(@filter == "public",
                  do: "btn-primary shadow-xs",
                  else: "btn-ghost text-base-content/70 hover:text-base-content"
                )
              ]}
            >
              <span class="size-2 rounded-full bg-emerald-500"></span>
              Publics
              <span class={[
                "badge badge-xs font-semibold",
                if(@filter == "public", do: "badge-neutral", else: "badge-ghost")
              ]}>
                {@counts.public}
              </span>
            </.link>

            <.link
              patch={~p"/my-quizzes?filter=private"}
              id="filter-private-btn"
              class={[
                "btn btn-sm font-bold gap-2 rounded-xl transition",
                if(@filter == "private",
                  do: "btn-primary shadow-xs",
                  else: "btn-ghost text-base-content/70 hover:text-base-content"
                )
              ]}
            >
              <.icon name="hero-lock-closed" class="size-3.5 text-amber-500" /> Privés
              <span class={[
                "badge badge-xs font-semibold",
                if(@filter == "private", do: "badge-neutral", else: "badge-ghost")
              ]}>
                {@counts.private}
              </span>
            </.link>
          </div>

          <div class="text-xs text-base-content/50 px-2">
            {@counts.total} quiz au total
          </div>
        </div>

        <!-- 3. Grille des quiz avec stream -->
        <div id="my-quizzes" phx-update="stream" class="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div
            id="empty-quizzes-state"
            class="hidden only:block text-center py-16 px-4 col-span-1 md:col-span-2 bg-base-100 border border-dashed border-base-300 rounded-3xl"
          >
            <div class="size-16 rounded-2xl bg-primary/10 text-primary mx-auto flex items-center justify-center mb-4">
              <.icon name="hero-folder-plus" class="size-8" />
            </div>
            <%= if @counts.total == 0 do %>
              <h3 class="text-xl font-bold text-base-content mb-1">
                Vous n'avez pas encore créé de quiz
              </h3>
              <p class="text-sm text-base-content/60 max-w-md mx-auto mb-6">
                Concevez des questions captivantes, invitez vos amis ou collègues et organisez des parties en direct inoubliables.
              </p>
              <.link navigate={~p"/quizzes/new"} class="btn btn-primary btn-sm font-bold gap-2">
                <.icon name="hero-plus" class="size-4" /> Créer mon premier quiz
              </.link>
            <% else %>
              <h3 class="text-xl font-bold text-base-content mb-1">
                Aucun quiz {if @filter == "public", do: "public", else: "privé"} trouvé
              </h3>
              <p class="text-sm text-base-content/60 max-w-md mx-auto mb-6">
                Vous n'avez aucun quiz correspondant à ce filtre actuellement.
              </p>
              <.link patch={~p"/my-quizzes?filter=all"} class="btn btn-outline btn-sm font-bold gap-2">
                Voir tous mes quiz
              </.link>
            <% end %>
          </div>

          <div
            :for={{dom_id, quiz} <- @streams.quizzes}
            id={dom_id}
            class="bg-base-100 border border-base-300 hover:border-primary/50 transition-all duration-200 rounded-3xl p-6 shadow-xs hover:shadow-md flex flex-col justify-between group"
          >
            <div>
              <div class="flex items-start justify-between gap-3 mb-3">
                <span class={[
                  "inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold shrink-0",
                  if(quiz.visibility == "public",
                    do:
                      "bg-emerald-100 text-emerald-800 dark:bg-emerald-950/50 dark:text-emerald-300",
                    else: "bg-amber-100 text-amber-800 dark:bg-amber-950/50 dark:text-amber-300"
                  )
                ]}>
                  <%= if quiz.visibility == "public" do %>
                    <span class="size-1.5 rounded-full bg-emerald-500"></span> Public
                  <% else %>
                    <.icon name="hero-lock-closed" class="size-3 text-amber-600" /> Privé
                  <% end %>
                </span>
              </div>

              <h2 class="text-xl font-bold text-base-content group-hover:text-primary transition-colors">
                <.link navigate={~p"/quizzes/#{quiz}"} id={"quiz-link-#{quiz.id}"}>
                  {quiz.title}
                </.link>
              </h2>

              <p class="text-xs text-base-content/65 mt-2 line-clamp-2 leading-relaxed">
                {quiz.description || "Aucune description fournie pour ce quiz."}
              </p>
            </div>

            <div class="mt-6 pt-4 border-t border-base-200">
              <div class="flex items-center justify-between text-xs text-base-content/60 mb-4">
                <span class="inline-flex items-center gap-1.5 font-medium">
                  <.icon name="hero-question-mark-circle" class="size-4 text-primary" />
                  {length(quiz.questions || [])} question{if length(quiz.questions || []) > 1,
                    do: "s",
                    else: ""}
                </span>
                <span class="text-xs">
                  {Calendar.strftime(quiz.inserted_at, "%d/%m/%Y")}
                </span>
              </div>

              <div class="flex items-center justify-between gap-2 flex-wrap">
                <div class="flex items-center gap-1.5">
                  <div class="dropdown dropdown-top sm:dropdown-bottom dropdown-start">
                    <div
                      tabindex="0"
                      role="button"
                      id={"start-game-btn-#{quiz.id}"}
                      class="btn btn-xs btn-primary gap-1 font-bold shadow-xs cursor-pointer"
                    >
                      <.icon name="hero-play" class="size-3.5" />
                      <span>Lancer</span>
                      <.icon name="hero-chevron-down" class="size-3 opacity-70" />
                    </div>
                    <ul
                      tabindex="0"
                      class="dropdown-content menu p-2 shadow-xl bg-base-100 rounded-2xl w-60 border border-base-200 mt-1 z-50 space-y-1"
                    >
                      <li class="menu-title px-2 py-1 text-[11px] text-base-content/50 font-bold">
                        Mode de la session
                      </li>
                      <li>
                        <button
                          type="button"
                          id={"launch-public-session-btn-#{quiz.id}"}
                          phx-click="start_game"
                          phx-value-id={quiz.id}
                          phx-value-visibility="public"
                          class="flex items-center gap-2 p-2 rounded-xl text-left hover:bg-base-200 w-full"
                        >
                          <.icon name="hero-globe-alt" class="size-4 text-emerald-500 shrink-0" />
                          <div>
                            <div class="font-bold text-xs text-base-content">Partie Publique</div>
                            <span class="text-[10px] text-base-content/60 block">Sans code PIN</span>
                          </div>
                        </button>
                      </li>
                      <li>
                        <button
                          type="button"
                          id={"launch-private-session-btn-#{quiz.id}"}
                          phx-click="start_game"
                          phx-value-id={quiz.id}
                          phx-value-visibility="private"
                          class="flex items-center gap-2 p-2 rounded-xl text-left hover:bg-base-200 w-full"
                        >
                          <.icon name="hero-lock-closed" class="size-4 text-amber-500 shrink-0" />
                          <div>
                            <div class="font-bold text-xs text-base-content">Partie Privée</div>
                            <span class="text-[10px] text-base-content/60 block">Code PIN obligatoire</span>
                          </div>
                        </button>
                      </li>
                    </ul>
                  </div>

                  <.link
                    navigate={~p"/quizzes/#{quiz}"}
                    id={"view-quiz-#{quiz.id}-btn"}
                    class="btn btn-xs btn-ghost gap-1 text-base-content/70 hover:text-base-content"
                    title="Voir les détails"
                  >
                    <.icon name="hero-eye" class="size-3.5" />
                    <span class="hidden sm:inline">Détails</span>
                  </.link>
                </div>

                <div class="flex items-center gap-1">
                  <.link
                    navigate={~p"/quizzes/#{quiz}/edit"}
                    id={"edit-quiz-#{quiz.id}-btn"}
                    class="btn btn-ghost btn-xs font-semibold gap-1"
                    title="Modifier ce quiz"
                  >
                    <.icon name="hero-pencil" class="size-3.5" /> Modifier
                  </.link>

                  <button
                    type="button"
                    id={"duplicate-quiz-#{quiz.id}-btn"}
                    phx-click="duplicate"
                    phx-value-id={quiz.id}
                    class="btn btn-ghost btn-xs font-semibold gap-1 text-base-content/70 hover:text-base-content"
                    title="Dupliquer ce quiz"
                  >
                    <.icon name="hero-document-duplicate" class="size-3.5" />
                  </button>

                  <button
                    type="button"
                    id={"delete-quiz-#{quiz.id}-btn"}
                    phx-click="delete"
                    phx-value-id={quiz.id}
                    data-confirm={"Êtes-vous sûr de vouloir supprimer définitivement le quiz « #{quiz.title} » ?"}
                    class="btn btn-ghost btn-xs text-error hover:bg-error/10"
                    title="Supprimer ce quiz"
                  >
                    <.icon name="hero-trash" class="size-3.5" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
