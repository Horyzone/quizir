defmodule QuizirWeb.QuizLive.Show do
  use QuizirWeb, :live_view

  alias Quizir.Quizzes

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    quiz = Quizzes.get_quiz_with_details!(id)

    {:ok,
     socket
     |> assign(:page_title, quiz.title)
     |> assign(:quiz, quiz)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Quizzes.delete_quiz(socket.assigns.quiz) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Quiz « #{socket.assigns.quiz.title} » supprimé avec succès.")
         |> push_navigate(to: ~p"/quizzes")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erreur lors de la suppression du quiz.")}
    end
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    case Quizir.Games.create_game(socket.assigns.quiz) do
      {:ok, %{code: code, host_token: host_token}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Partie créée ! Code de salon : #{code}")
         |> push_navigate(to: ~p"/games/#{code}?host_token=#{host_token}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Impossible de démarrer la partie pour ce quiz.")}
    end
  end

  @impl true
  def render(assigns) do
    total_time =
      Enum.reduce(assigns.quiz.questions, 0, fn q, acc -> acc + (q.time_limit_seconds || 0) end)

    assigns = assign(assigns, :total_time, total_time)

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="py-4">
        <div class="flex flex-wrap items-center justify-between gap-4 mb-6">
          <.button id="back-to-quizzes-btn" navigate={~p"/quizzes"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4 mr-1" /> Retour aux quiz
          </.button>

          <div class="flex items-center gap-2">
            <.button
              id="edit-quiz-btn"
              navigate={~p"/quizzes/#{@quiz}/edit"}
              class="btn btn-outline btn-sm gap-1"
            >
              <.icon name="hero-pencil-square" class="size-4" /> Modifier
            </.button>

            <.button
              id="delete-quiz-btn"
              phx-click="delete"
              data-confirm="Êtes-vous sûr de vouloir supprimer définitivement ce quiz ?"
              class="btn btn-ghost btn-sm text-error hover:bg-error/10 gap-1"
            >
              <.icon name="hero-trash" class="size-4" /> Supprimer
            </.button>

            <.button
              id="start-game-btn"
              variant="primary"
              phx-click="start_game"
              class="btn btn-primary btn-sm gap-1 shadow-sm hover:shadow"
            >
              <.icon name="hero-play" class="size-4" /> Lancer une partie
            </.button>
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
              <p id="quiz-details-desc" class="text-zinc-600 text-base">
                {@quiz.description || "Aucune description fournie."}
              </p>
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

          <%= if @quiz.visibility == "private" && @quiz.access_code do %>
            <div class="mt-4 pt-4 border-t border-base-200 flex items-center gap-2">
              <span class="text-xs font-semibold uppercase text-zinc-500">Code d'accès requis :</span>
              <span
                id="quiz-access-code-badge"
                class="badge badge-outline font-mono font-bold tracking-wider"
              >
                {@quiz.access_code}
              </span>
            </div>
          <% end %>
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
