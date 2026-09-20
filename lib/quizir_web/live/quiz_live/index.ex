defmodule QuizirWeb.QuizLive.Index do
  use QuizirWeb, :live_view
  alias Quizir.Quizzes

  @impl true
  def mount(_params, _session, socket) do
    quizzes = Quizzes.list_quizzes()
    {:ok, stream(socket, :quizzes, quizzes)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    quiz = Quizzes.get_quiz!(id)
    {:ok, _} = Quizzes.delete_quiz(quiz)

    {:noreply,
     socket
     |> put_flash(:info, "Quiz « #{quiz.title} » supprimé avec succès.")
     |> stream_delete(:quizzes, quiz)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto py-8">
        <div class="flex justify-between items-center mb-6">
          <div>
            <h1 class="text-3xl font-bold">Quiz disponibles</h1>
            <p class="text-sm text-zinc-500">
              Parcourez, lancez ou créez de nouveaux quiz multijoueurs.
            </p>
          </div>
          <.button id="new-quiz-button" navigate={~p"/quizzes/new"}>
            <.icon name="hero-plus" class="size-4 mr-1" /> Nouveau Quiz
          </.button>
        </div>

        <div id="quizzes" phx-update="stream" class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div
            id="empty-quizzes-state"
            class="hidden only:block text-zinc-500 py-8 text-center col-span-2"
          >
            Aucun quiz disponible pour le moment.
          </div>
          <div
            :for={{dom_id, quiz} <- @streams.quizzes}
            id={dom_id}
            class="p-5 border rounded-2xl shadow-sm bg-base-100 border-base-300 hover:border-zinc-400 transition flex flex-col justify-between"
          >
            <div>
              <div class="flex justify-between items-start gap-2">
                <.link
                  navigate={~p"/quizzes/#{quiz}"}
                  id={"quiz-title-link-#{quiz.id}"}
                  class="text-xl font-semibold hover:text-primary transition"
                >
                  {quiz.title}
                </.link>
                <span class={[
                  "text-xs px-2 py-0.5 rounded-full font-semibold shrink-0",
                  if(quiz.visibility == "public",
                    do: "bg-green-100 text-green-800",
                    else: "bg-amber-100 text-amber-800"
                  )
                ]}>
                  {String.capitalize(quiz.visibility)}
                </span>
              </div>
              <p class="text-zinc-600 text-sm mt-2 line-clamp-2">
                {quiz.description || "Aucune description"}
              </p>
            </div>

            <div class="mt-4 pt-3 border-t border-base-200 flex items-center justify-between">
              <.link
                navigate={~p"/quizzes/#{quiz}"}
                id={"view-quiz-#{quiz.id}-btn"}
                class="btn btn-xs btn-primary gap-1"
              >
                <.icon name="hero-eye" class="size-3.5" /> Voir les détails
              </.link>

              <div class="flex items-center gap-1">
                <.link
                  navigate={~p"/quizzes/#{quiz}/edit"}
                  id={"edit-quiz-#{quiz.id}-btn"}
                  class="btn btn-xs btn-ghost gap-1"
                >
                  <.icon name="hero-pencil" class="size-3.5" /> Modifier
                </.link>
                <button
                  type="button"
                  id={"delete-quiz-#{quiz.id}-btn"}
                  phx-click="delete"
                  phx-value-id={quiz.id}
                  data-confirm="Êtes-vous sûr de vouloir supprimer ce quiz ?"
                  class="btn btn-xs btn-ghost text-error hover:bg-error/10 gap-1"
                  aria-label="Supprimer le quiz"
                >
                  <.icon name="hero-trash" class="size-3.5" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
