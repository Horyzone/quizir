defmodule QuizirWeb.QuizLive.Index do
  use QuizirWeb, :live_view
  alias Quizir.Quizzes

  @impl true
  def mount(_params, _session, socket) do
    quizzes = Quizzes.list_public_quizzes()

    {:ok,
     socket
     |> assign(:page_title, "Explorer")
     |> stream(:quizzes, quizzes)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    quiz = Quizzes.get_quiz!(id)

    if Quizzes.can_manage_quiz?(quiz, socket.assigns.current_user) do
      {:ok, _} = Quizzes.delete_quiz(quiz)

      {:noreply,
       socket
       |> put_flash(:info, "Quiz « #{quiz.title} » supprimé avec succès.")
       |> stream_delete(:quizzes, quiz)}
    else
      {:noreply, put_flash(socket, :error, "Vous n'êtes pas autorisé à supprimer ce quiz.")}
    end
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, socket) do
    if socket.assigns.current_user do
      case Quizzes.duplicate_quiz(id, socket.assigns.current_user) do
        {:ok, duplicated_quiz} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             "Quiz dupliqué avec succès ! Vous pouvez maintenant le personnaliser."
           )
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
  def handle_event("start_game", %{"id" => id} = params, socket) do
    quiz = Quizzes.get_quiz_with_details!(id)
    current_user = socket.assigns[:current_user]

    can_start? =
      quiz.visibility == "public" or Quizzes.can_manage_quiz?(quiz, current_user)

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
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto py-8">
        <div class="flex justify-between items-center mb-6">
          <div>
            <h1 class="text-3xl font-bold">Quiz disponibles</h1>
            <p class="text-sm text-zinc-500">
              Parcourez, lancez ou créez de nouveaux quiz.
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
                <div>
                  <.link
                    navigate={~p"/quizzes/#{quiz}"}
                    id={"quiz-title-link-#{quiz.id}"}
                    class="text-xl font-semibold hover:text-primary transition"
                  >
                    {quiz.title}
                  </.link>
                  <%= if quiz.user do %>
                    <p class="text-xs text-zinc-400 mt-0.5 flex items-center gap-1">
                      <.icon name="hero-user" class="size-3" /> {quiz.user.username}
                    </p>
                  <% end %>
                </div>
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

              <%= if quiz.image_url do %>
                <div class="mt-3 overflow-hidden rounded-xl border border-base-200">
                  <img
                    src={quiz.image_url}
                    alt={quiz.title}
                    class="w-full h-40 object-cover hover:scale-105 transition duration-300"
                    loading="lazy"
                  />
                </div>
              <% end %>

              <p class="text-zinc-600 text-sm mt-2 line-clamp-2">
                {quiz.description || "Aucune description"}
              </p>
            </div>

            <div class="mt-4 pt-3 border-t border-base-200 flex items-center justify-between gap-2 flex-wrap">
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
                          <span class="text-[10px] text-base-content/60 block">Sans code PIN requis</span>
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
                <%= if Quizzes.can_manage_quiz?(quiz, @current_user) do %>
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
                <% else %>
                  <button
                    type="button"
                    id={"duplicate-quiz-#{quiz.id}-btn"}
                    phx-click="duplicate"
                    phx-value-id={quiz.id}
                    class="btn btn-xs btn-ghost gap-1 text-zinc-600 hover:text-primary"
                    aria-label="Dupliquer le quiz"
                  >
                    <.icon name="hero-document-duplicate" class="size-3.5" /> Dupliquer
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
