defmodule QuizirWeb.QuizLive.Show do
  use QuizirWeb, :live_view

  alias Quizir.Quizzes

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    quiz = Quizzes.get_quiz_with_details!(id)
    current_user = socket.assigns[:current_user]
    is_owner = current_user != nil and Quizzes.can_manage_quiz?(quiz, current_user)

    {:ok,
     socket
     |> assign(:page_title, quiz.title)
     |> assign(:quiz, quiz)
     |> assign(:is_owner, is_owner)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    if Quizzes.can_manage_quiz?(socket.assigns.quiz, socket.assigns.current_user) do
      case Quizzes.delete_quiz(socket.assigns.quiz) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Quiz « #{socket.assigns.quiz.title} » supprimé avec succès.")
           |> push_navigate(to: ~p"/quizzes")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erreur lors de la suppression du quiz.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Vous n'êtes pas autorisé à supprimer ce quiz.")}
    end
  end

  @impl true
  def handle_event("duplicate", _params, socket) do
    if socket.assigns.current_user do
      case Quizzes.duplicate_quiz(socket.assigns.quiz, socket.assigns.current_user) do
        {:ok, duplicated_quiz} ->
          {:noreply,
           socket
           |> put_flash(:info, "Quiz dupliqué avec succès ! Vous pouvez maintenant le modifier.")
           |> push_navigate(to: ~p"/quizzes/#{duplicated_quiz}/edit")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Impossible de dupliquer ce quiz.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Vous devez être connecté pour dupliquer un quiz.")
       |> push_navigate(to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_event("start_game", params, socket) do
    quiz = socket.assigns.quiz

    can_start? =
      quiz.visibility == "public" or Quizzes.can_manage_quiz?(quiz, socket.assigns.current_user)

    if can_start? do
      visibility = params["visibility"] || "public"

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

  @impl true
  def render(assigns) do
    total_time =
      Enum.reduce(assigns.quiz.questions, 0, fn q, acc -> acc + (q.time_limit_seconds || 0) end)

    assigns = assign(assigns, :total_time, total_time)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="py-4">
        <div class="flex flex-wrap items-center justify-between gap-4 mb-6">
          <.button id="back-to-quizzes-btn" navigate={~p"/quizzes"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4 mr-1" /> Retour aux quiz
          </.button>

          <div class="flex items-center gap-2">
            <%= if @is_owner do %>
              <.button
                id="edit-quiz-btn"
                navigate={~p"/quizzes/#{@quiz}/edit"}
                class="btn btn-outline btn-sm gap-1"
              >
                <.icon name="hero-pencil" class="size-4" /> Modifier
              </.button>

              <.button
                id="delete-quiz-btn"
                phx-click="delete"
                data-confirm="Êtes-vous sûr de vouloir supprimer définitivement ce quiz ?"
                class="btn btn-ghost btn-sm text-error hover:bg-error/10 gap-1"
              >
                <.icon name="hero-trash" class="size-4" /> Supprimer
              </.button>
            <% end %>

            <%= if @quiz.visibility == "public" or @is_owner do %>
              <%= if !@is_owner do %>
                <.button
                  id="duplicate-quiz-btn"
                  phx-click="duplicate"
                  class="btn btn-outline btn-sm gap-1"
                >
                  <.icon name="hero-document-duplicate" class="size-4" /> Dupliquer
                </.button>
              <% end %>

              <div class="dropdown dropdown-end">
                <div
                  tabindex="0"
                  role="button"
                  id="start-game-btn"
                  phx-click="start_game"
                  phx-value-visibility="public"
                  class="btn btn-primary btn-sm gap-1 shadow-sm hover:shadow"
                >
                  <.icon name="hero-play" class="size-4" /> Lancer une partie
                  <.icon name="hero-chevron-down" class="size-3 ml-0.5 opacity-70" />
                </div>
                <ul
                  tabindex="0"
                  class="dropdown-content menu p-2 shadow-xl bg-base-100 rounded-2xl w-64 border border-base-200 mt-2 z-50 space-y-1"
                >
                  <li class="menu-title px-3 py-1 text-xs text-base-content/50 font-bold">
                    Choisir le mode de session
                  </li>
                  <li>
                    <button
                      type="button"
                      id="launch-public-session-btn"
                      phx-click="start_game"
                      phx-value-visibility="public"
                      class="flex items-center justify-between p-2 rounded-xl text-left"
                    >
                      <div class="flex items-center gap-2 font-bold text-sm">
                        <.icon name="hero-globe-alt" class="size-4 text-emerald-500 shrink-0" />
                        <div>
                          <div>Partie Publique</div>
                          <span class="text-xs font-normal text-base-content/60 block">
                            Visible par tous, sans code PIN
                          </span>
                        </div>
                      </div>
                    </button>
                  </li>
                  <li>
                    <button
                      type="button"
                      id="launch-private-session-btn"
                      phx-click="start_game"
                      phx-value-visibility="private"
                      class="flex items-center justify-between p-2 rounded-xl text-left"
                    >
                      <div class="flex items-center gap-2 font-bold text-sm">
                        <.icon name="hero-lock-closed" class="size-4 text-amber-500 shrink-0" />
                        <div>
                          <div>Partie Privée</div>
                          <span class="text-xs font-normal text-base-content/60 block">
                            Code PIN obligatoire pour entrer
                          </span>
                        </div>
                      </div>
                    </button>
                  </li>
                </ul>
              </div>
            <% else %>
              <span class="text-xs text-amber-600 font-semibold bg-amber-50 px-3 py-1.5 rounded-xl border border-amber-200 flex items-center gap-1.5">
                <.icon name="hero-lock-closed" class="size-4" /> Quiz privé (réservé au créateur)
              </span>
            <% end %>
          </div>
        </div>

        <div
          id="quiz-details-card"
          class="p-6 mb-8 rounded-2xl bg-base-100 border border-base-300 shadow-sm"
        >
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <h1 id="quiz-details-title" class="text-3xl font-bold">{@quiz.title}</h1>
                <span class={[
                  "text-xs px-2.5 py-0.5 rounded-full font-semibold",
                  if(@quiz.visibility == "public",
                    do: "bg-green-100 text-green-800",
                    else: "bg-amber-100 text-amber-800"
                  )
                ]}>
                  {String.capitalize(@quiz.visibility)}
                </span>
              </div>
              <%= if @quiz.image_url do %>
                <div class="my-4 max-w-md overflow-hidden rounded-2xl border border-base-200 shadow-sm">
                  <img
                    id="quiz-details-image"
                    src={@quiz.image_url}
                    alt={@quiz.title}
                    class="w-full h-56 object-cover"
                  />
                </div>
              <% end %>
              <p id="quiz-details-desc" class="text-zinc-600 text-base">
                {@quiz.description || "Aucune description fournie."}
              </p>
              <%= if @quiz.user do %>
                <p id="quiz-author-badge" class="text-xs text-zinc-400 mt-2 flex items-center gap-1">
                  <.icon name="hero-user" class="size-3.5" /> Créé par
                  <span class="font-semibold text-zinc-600">{@quiz.user.username}</span>
                </p>
              <% end %>
            </div>

            <div class="flex items-center gap-4 text-sm text-zinc-500">
              <div class="flex items-center gap-1.5">
                <.icon name="hero-question-mark-circle" class="size-5 text-primary" />
                <span>{length(@quiz.questions)} question(s)</span>
              </div>
              <div class="flex items-center gap-1.5">
                <.icon name="hero-clock" class="size-5 text-secondary" />
                <span>~{@total_time} secondes</span>
              </div>
            </div>
          </div>

          <div class="mt-4 pt-4 border-t border-base-200 flex items-center justify-between gap-2 text-xs">
            <%= if @quiz.visibility == "public" do %>
              <span class="text-emerald-700 dark:text-emerald-400 flex items-center gap-1.5 font-medium">
                <.icon name="hero-globe-alt" class="size-4 shrink-0" />
                Quiz public : tout le monde peut créer une partie ou dupliquer ce quiz.
              </span>
            <% else %>
              <span class="text-amber-700 dark:text-amber-400 flex items-center gap-1.5 font-medium">
                <.icon name="hero-lock-closed" class="size-4 shrink-0" />
                Quiz privé : seul le propriétaire peut lancer des parties ou modifier ce quiz.
              </span>
            <% end %>
          </div>
        </div>

        <div class="space-y-6">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-bold">Questions du quiz</h2>
            <span class="text-sm text-zinc-500">{length(@quiz.questions)} au total</span>
          </div>

          <div id="questions-list" class="space-y-4">
            <%= for {question, q_idx} <- Enum.with_index(@quiz.questions) do %>
              <div
                id={"show-question-card-#{question.id || q_idx}"}
                class="p-5 rounded-xl bg-base-100 border border-base-300 shadow-sm"
              >
                <div class="flex items-center justify-between pb-3 mb-4 border-b border-base-200">
                  <span class="badge badge-neutral font-semibold">
                    Question #{question.order || q_idx + 1}
                  </span>
                  <span class="badge badge-ghost text-xs gap-1">
                    <.icon name="hero-clock" class="size-3.5" />
                    {question.time_limit_seconds}s
                  </span>
                </div>

                <p class="text-lg font-medium text-base-content mb-4">{question.body}</p>

                <%= if question.image_url do %>
                  <div class="mb-4 max-w-sm overflow-hidden rounded-xl border border-base-200">
                    <img
                      src={question.image_url}
                      alt={question.body}
                      class="w-full max-h-56 object-contain bg-base-200/30"
                    />
                  </div>
                <% end %>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <%= for option <- question.answer_options do %>
                    <div
                      id={"show-option-#{option.id}"}
                      class={[
                        "p-3 rounded-lg border text-sm flex items-center justify-between gap-2",
                        if(option.is_correct,
                          do: "bg-success/10 border-success/30 font-medium text-success-content",
                          else: "bg-base-200/40 border-base-300 text-base-content/80"
                        )
                      ]}
                    >
                      <span class="flex-1">{option.body}</span>
                      <%= if option.is_correct do %>
                        <span class="badge badge-success badge-sm gap-1 shrink-0">
                          <.icon name="hero-check" class="size-3" /> Correct
                        </span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
