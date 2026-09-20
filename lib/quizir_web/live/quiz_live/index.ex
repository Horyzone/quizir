defmodule QuizirWeb.QuizLive.Index do
  use QuizirWeb, :live_view
  alias Quizir.Quizzes

  @impl true
  def mount(_params, _session, socket) do
    quizzes = Quizzes.list_quizzes()
    {:ok, stream(socket, :quizzes, quizzes)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto py-8">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-3xl font-bold">Quiz disponibles</h1>
          <.button id="new-quiz-button" navigate={~p"/quizzes/new"}>
            Nouveau Quiz
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
            class="p-5 border rounded-lg shadow-sm bg-white hover:border-zinc-400"
          >
            <div class="flex justify-between items-start">
              <h2 class="text-xl font-semibold">{quiz.title}</h2>
              <span class={[
                "text-xs px-2 py-1 rounded font-semibold",
                if(quiz.visibility == "public",
                  do: "bg-green-100 text-green-800",
                  else: "bg-amber-100 text-amber-800"
                )
              ]}>
                {String.capitalize(quiz.visibility)}
              </span>
            </div>
            <p class="text-zinc-600 text-sm mt-2">{quiz.description || "Aucune description"}</p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
