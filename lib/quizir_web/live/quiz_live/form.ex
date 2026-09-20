defmodule QuizirWeb.QuizLive.Form do
  use QuizirWeb, :live_view

  alias Quizir.Quizzes
  alias Quizir.Quizzes.Quiz

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    quiz = Quizzes.get_quiz_with_details!(id)

    if Quizzes.can_manage_quiz?(quiz, socket.assigns.current_user) do
      changeset = Quizzes.change_quiz(quiz)

      socket
      |> assign(:page_title, "Modifier le Quiz")
      |> assign(:quiz, quiz)
      |> assign(:quiz_params, quiz_to_params(quiz))
      |> assign(:form, to_form(changeset))
    else
      socket
      |> put_flash(:error, "Vous n'êtes pas autorisé à modifier ce quiz.")
      |> push_navigate(to: ~p"/quizzes")
    end
  end

  defp apply_action(socket, :new, _params) do
    default_quiz_params = %{
      "title" => "",
      "description" => "",
      "visibility" => "public",
      "access_code" => "",
      "questions" => [
        %{
          "order" => 1,
          "body" => "",
          "time_limit_seconds" => 20,
          "answer_options" => [
            %{"body" => "", "is_correct" => true},
            %{"body" => "", "is_correct" => false}
          ]
        }
      ]
    }

    quiz = %Quiz{}
    changeset = Quizzes.change_quiz(quiz, default_quiz_params)

    socket
    |> assign(:page_title, "Créer un Quiz")
    |> assign(:quiz, quiz)
    |> assign(:quiz_params, default_quiz_params)
    |> assign(:form, to_form(changeset))
  end

  defp quiz_to_params(%Quiz{} = quiz) do
    %{
      "id" => quiz.id,
      "title" => quiz.title || "",
      "description" => quiz.description || "",
      "visibility" => quiz.visibility || "public",
      "access_code" => quiz.access_code || "",
      "questions" =>
        Enum.map(quiz.questions || [], fn q ->
          %{
            "id" => q.id,
            "order" => q.order,
            "body" => q.body || "",
            "time_limit_seconds" => q.time_limit_seconds || 20,
            "answer_options" =>
              Enum.map(q.answer_options || [], fn opt ->
                %{
                  "id" => opt.id,
                  "body" => opt.body || "",
                  "is_correct" => opt.is_correct
                }
              end)
          }
        end)
    }
  end

  @impl true
  def handle_event("validate", %{"quiz" => quiz_params}, socket) do
    changeset =
      socket.assigns.quiz
      |> Quizzes.change_quiz(quiz_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:quiz_params, quiz_params)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("add-question", _params, socket) do
    params = socket.assigns.quiz_params
    questions = normalize_questions(params["questions"] || [])

    new_question = %{
      "order" => length(questions) + 1,
      "body" => "",
      "time_limit_seconds" => 20,
      "answer_options" => [
        %{"body" => "", "is_correct" => true},
        %{"body" => "", "is_correct" => false}
      ]
    }

    updated_questions = questions ++ [new_question]
    updated_params = Map.put(params, "questions", updated_questions)
    changeset = Quizzes.change_quiz(socket.assigns.quiz, updated_params)

    {:noreply,
     socket
     |> assign(:quiz_params, updated_params)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("remove-question", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    params = socket.assigns.quiz_params
    questions = normalize_questions(params["questions"] || [])

    updated_questions =
      if length(questions) > 1 do
        questions
        |> List.delete_at(index)
        |> Enum.with_index(1)
        |> Enum.map(fn {q, i} -> Map.put(q, "order", i) end)
      else
        questions
      end

    updated_params = Map.put(params, "questions", updated_questions)
    changeset = Quizzes.change_quiz(socket.assigns.quiz, updated_params)

    {:noreply,
     socket
     |> assign(:quiz_params, updated_params)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("add-answer-option", %{"question-index" => q_index_str}, socket) do
    q_index = String.to_integer(q_index_str)
    params = socket.assigns.quiz_params
    questions = normalize_questions(params["questions"] || [])

    updated_questions =
      List.update_at(questions, q_index, fn q ->
        opts = normalize_options(q["answer_options"] || [])
        new_option = %{"body" => "", "is_correct" => false}
        Map.put(q, "answer_options", opts ++ [new_option])
      end)

    updated_params = Map.put(params, "questions", updated_questions)
    changeset = Quizzes.change_quiz(socket.assigns.quiz, updated_params)

    {:noreply,
     socket
     |> assign(:quiz_params, updated_params)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event(
        "remove-answer-option",
        %{"question-index" => q_index_str, "option-index" => opt_index_str},
        socket
      ) do
    q_index = String.to_integer(q_index_str)
    opt_index = String.to_integer(opt_index_str)
    params = socket.assigns.quiz_params
    questions = normalize_questions(params["questions"] || [])

    updated_questions =
      List.update_at(questions, q_index, fn q ->
        opts = normalize_options(q["answer_options"] || [])

        if length(opts) > 2 do
          Map.put(q, "answer_options", List.delete_at(opts, opt_index))
        else
          q
        end
      end)

    updated_params = Map.put(params, "questions", updated_questions)
    changeset = Quizzes.change_quiz(socket.assigns.quiz, updated_params)

    {:noreply,
     socket
     |> assign(:quiz_params, updated_params)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"quiz" => quiz_params}, socket) do
    save_quiz(socket, socket.assigns.live_action, quiz_params)
  end

  defp save_quiz(socket, :edit, quiz_params) do
    if Quizzes.can_manage_quiz?(socket.assigns.quiz, socket.assigns.current_user) do
      case Quizzes.update_quiz(socket.assigns.quiz, quiz_params) do
        {:ok, quiz} ->
          {:noreply,
           socket
           |> put_flash(:info, "Quiz « #{quiz.title} » mis à jour avec succès !")
           |> push_navigate(to: ~p"/quizzes/#{quiz}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> assign(:quiz_params, quiz_params)
           |> assign(:form, to_form(changeset))}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Vous n'êtes pas autorisé à modifier ce quiz.")
       |> push_navigate(to: ~p"/quizzes")}
    end
  end

  defp save_quiz(socket, :new, quiz_params) do
    case Quizzes.create_quiz(quiz_params, socket.assigns.current_user) do
      {:ok, quiz} ->
        {:noreply,
         socket
         |> put_flash(:info, "Quiz « #{quiz.title} » créé avec succès !")
         |> push_navigate(to: ~p"/quizzes")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:quiz_params, quiz_params)
         |> assign(:form, to_form(changeset))}
    end
  end

  defp normalize_options(opts) when is_map(opts) do
    opts
    |> Enum.sort_by(fn {k, _} -> String.to_integer(to_string(k)) end)
    |> Enum.map(&elem(&1, 1))
  end

  defp normalize_options(opts) when is_list(opts), do: opts
  defp normalize_options(_), do: []

  defp normalize_questions(qs) when is_map(qs) do
    qs
    |> Enum.sort_by(fn {k, _} -> String.to_integer(to_string(k)) end)
    |> Enum.map(fn {_k, q} -> Map.update(q, "answer_options", [], &normalize_options/1) end)
  end

  defp normalize_questions(qs) when is_list(qs) do
    Enum.map(qs, fn q -> Map.update(q, "answer_options", [], &normalize_options/1) end)
  end

  defp normalize_questions(_), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="py-4">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-2xl font-bold">{@page_title}</h1>
            <p class="text-sm text-zinc-500">
              Configurez votre quiz et ses questions avant de lancer une partie.
            </p>
          </div>
          <.button
            id="back-button"
            navigate={if @live_action == :edit, do: ~p"/quizzes/#{@quiz}", else: ~p"/quizzes"}
            class="btn btn-ghost btn-sm"
          >
            <.icon name="hero-arrow-left" class="size-4 mr-1" /> Retour
          </.button>
        </div>

        <.form for={@form} id="quiz-form" phx-change="validate" phx-submit="save" class="space-y-6">
          <div class="p-6 rounded-2xl bg-base-100 border border-base-300 shadow-sm space-y-4">
            <h2 class="text-lg font-semibold border-b border-base-200 pb-2">
              Informations générales
            </h2>

            <.input
              field={@form[:title]}
              id="quiz-title"
              label="Titre du quiz"
              placeholder="Ex: Culture générale"
            />
            <.input
              field={@form[:description]}
              id="quiz-description"
              type="textarea"
              label="Description"
              placeholder="Description brève de votre quiz..."
            />

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.input
                field={@form[:visibility]}
                id="quiz-visibility"
                type="select"
                label="Visibilité"
                options={[
                  {"Public (ouvert à tous)", "public"},
                  {"Privé (code d'accès requis)", "private"}
                ]}
              />
              <div>
                <.input
                  field={@form[:access_code]}
                  id="quiz-access-code"
                  label="Code d'accès"
                  placeholder="Ex: 4821"
                  phx-hook=".AccessCodeMask"
                />
              </div>
            </div>
          </div>

          <div class="mt-8 border-t border-zinc-200 pt-6">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h2 class="text-xl font-bold">Questions</h2>
                <p class="text-xs text-zinc-500">
                  Ajoutez au moins une question avec ses options de réponse.
                </p>
              </div>
              <.button
                type="button"
                id="add-question-top-btn"
                phx-click="add-question"
                class="btn btn-sm btn-outline gap-1"
              >
                <.icon name="hero-plus" class="size-4" /> Ajouter une question
              </.button>
            </div>

            <div class="space-y-6">
              <.inputs_for :let={q_form} field={@form[:questions]}>
                <div
                  id={"question-card-#{q_form.index}"}
                  class="p-5 rounded-xl bg-base-100 border border-base-300 shadow-sm transition hover:shadow-md"
                >
                  <div class="flex items-center justify-between pb-3 mb-4 border-b border-base-200">
                    <span class="badge badge-neutral font-semibold">
                      Question #{q_form.index + 1}
                    </span>

                    <input type="hidden" name={q_form[:order].name} value={q_form.index + 1} />
                    <input
                      :if={q_form[:id].value}
                      type="hidden"
                      name={q_form[:id].name}
                      value={q_form[:id].value}
                    />

                    <%= if length(normalize_questions(@quiz_params["questions"])) > 1 do %>
                      <button
                        type="button"
                        id={"remove-question-#{q_form.index}-btn"}
                        phx-click="remove-question"
                        phx-value-index={q_form.index}
                        class="btn btn-ghost btn-xs text-error hover:bg-error/10"
                        aria-label="Supprimer la question"
                      >
                        <.icon name="hero-trash" class="size-4" /> Supprimer
                      </button>
                    <% end %>
                  </div>

                  <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
                    <div class="md:col-span-3">
                      <.input
                        field={q_form[:body]}
                        id={"question-#{q_form.index}-body"}
                        label="Énoncé de la question"
                        placeholder="Ex: Quelle est la capitale de l'Australie ?"
                      />
                    </div>
                    <div>
                      <.input
                        field={q_form[:time_limit_seconds]}
                        id={"question-#{q_form.index}-time-limit"}
                        type="number"
                        label="Délai (sec, 5 à 120)"
                      />
                    </div>
                  </div>

                  <div class="mt-4 pt-4 border-t border-base-200">
                    <div class="flex items-center justify-between mb-3">
                      <span class="text-sm font-semibold text-base-content/80 flex items-center gap-1.5">
                        <.icon name="hero-list-bullet" class="size-4 text-primary" />
                        Options de réponse
                      </span>
                      <.button
                        type="button"
                        id={"add-option-#{q_form.index}-btn"}
                        phx-click="add-answer-option"
                        phx-value-question-index={q_form.index}
                        class="btn btn-xs btn-ghost gap-1 text-primary"
                      >
                        <.icon name="hero-plus" class="size-3.5" /> Ajouter une option
                      </.button>
                    </div>

                    <div class="space-y-3">
                      <.inputs_for :let={opt_form} field={q_form[:answer_options]}>
                        <div
                          id={"question-#{q_form.index}-option-#{opt_form.index}"}
                          class="flex items-center gap-3 p-2.5 rounded-lg bg-base-200/50 border border-base-300"
                        >
                          <div class="flex-1">
                            <input
                              :if={opt_form[:id].value}
                              type="hidden"
                              name={opt_form[:id].name}
                              value={opt_form[:id].value}
                            />
                            <.input
                              field={opt_form[:body]}
                              id={"question-#{q_form.index}-option-#{opt_form.index}-body"}
                              placeholder={"Choix #{opt_form.index + 1}..."}
                            />
                          </div>
                          <div class="pt-1">
                            <.input
                              field={opt_form[:is_correct]}
                              id={"question-#{q_form.index}-option-#{opt_form.index}-is-correct"}
                              type="checkbox"
                              label="Bonne réponse"
                            />
                          </div>
                          <% current_q =
                            Enum.at(normalize_questions(@quiz_params["questions"]), q_form.index) ||
                              %{} %>
                          <% current_opts = normalize_options(current_q["answer_options"] || []) %>
                          <%= if length(current_opts) > 2 do %>
                            <button
                              type="button"
                              id={"remove-option-#{q_form.index}-#{opt_form.index}-btn"}
                              phx-click="remove-answer-option"
                              phx-value-question-index={q_form.index}
                              phx-value-option-index={opt_form.index}
                              class="btn btn-ghost btn-square btn-xs text-error hover:bg-error/10"
                              aria-label="Supprimer le choix"
                            >
                              <.icon name="hero-x-mark" class="size-4" />
                            </button>
                          <% end %>
                        </div>
                      </.inputs_for>
                    </div>
                  </div>
                </div>
              </.inputs_for>
            </div>

            <div class="mt-6 flex justify-center">
              <.button
                type="button"
                id="add-question-btn"
                phx-click="add-question"
                class="btn btn-outline btn-wide gap-2"
              >
                <.icon name="hero-plus" class="size-4" /> Ajouter une question
              </.button>
            </div>
          </div>

          <div class="mt-8 pt-6 border-t border-zinc-200 flex items-center justify-end gap-3">
            <.button
              id="cancel-button"
              navigate={if @live_action == :edit, do: ~p"/quizzes/#{@quiz}", else: ~p"/quizzes"}
              class="btn btn-ghost"
            >
              Annuler
            </.button>
            <.button
              id="save-quiz-button"
              variant="primary"
              phx-disable-with="Enregistrement..."
            >
              {if @live_action == :edit, do: "Enregistrer les modifications", else: "Créer le quiz"}
            </.button>
          </div>
        </.form>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".AccessCodeMask">
        export default {
          mounted() {
            this.el.addEventListener("input", e => {
              this.el.value = this.el.value.toUpperCase().replace(/[^A-Z0-9]/g, "")
            })
          }
        }
      </script>
    </Layouts.app>
    """
  end
end
