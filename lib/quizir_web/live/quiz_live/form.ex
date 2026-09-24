defmodule QuizirWeb.QuizLive.Form do
  use QuizirWeb, :live_view

  on_mount {QuizirWeb.UserAuth, :ensure_authenticated}

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
      quiz_params = quiz_to_params(quiz)
      changeset = Quizzes.change_quiz(quiz)

      socket
      |> assign(:page_title, "Modifier le Quiz")
      |> assign(:quiz, quiz)
      |> assign(:quiz_params, quiz_params)
      |> ensure_uploads(quiz_params)
      |> assign(:form, to_form(changeset))
    else
      socket
      |> put_flash(:error, "Vous n'êtes pas autorisé à modifier ce quiz.")
      |> push_navigate(to: ~p"/quizzes")
    end
  end

  defp apply_action(socket, :new, _params) do
    new_temp_id = "q_#{System.unique_integer([:positive])}"

    default_quiz_params = %{
      "title" => "",
      "description" => "",
      "visibility" => "public",
      "image_url" => "",
      "questions" => [
        %{
          "temp_id" => new_temp_id,
          "order" => 1,
          "body" => "",
          "image_url" => "",
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
    |> ensure_uploads(default_quiz_params)
    |> assign(:form, to_form(changeset))
  end

  defp quiz_to_params(%Quiz{} = quiz) do
    %{
      "id" => quiz.id,
      "title" => quiz.title || "",
      "description" => quiz.description || "",
      "visibility" => quiz.visibility || "public",
      "image_url" => quiz.image_url || "",
      "questions" =>
        Enum.map(quiz.questions || [], fn q ->
          %{
            "id" => q.id,
            "temp_id" => "q_#{q.id || System.unique_integer([:positive])}",
            "order" => q.order,
            "body" => q.body || "",
            "image_url" => q.image_url || "",
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

  defp ensure_uploads(socket, quiz_params) do
    socket =
      if socket.assigns[:uploads] && socket.assigns[:uploads][:quiz_image] do
        socket
      else
        allow_upload(socket, :quiz_image,
          accept: ~w(.jpg .jpeg .png .webp .gif),
          max_entries: 1,
          max_file_size: 10_000_000
        )
      end

    questions = normalize_questions(quiz_params["questions"] || [])

    Enum.reduce(questions, socket, fn q, acc ->
      temp_id = q["temp_id"]

      if temp_id && temp_id != "" do
        upload_name = String.to_atom("question_image_#{temp_id}")

        if acc.assigns[:uploads] && acc.assigns[:uploads][upload_name] do
          acc
        else
          allow_upload(acc, upload_name,
            accept: ~w(.jpg .jpeg .png .webp .gif),
            max_entries: 1,
            max_file_size: 10_000_000
          )
        end
      else
        acc
      end
    end)
  end

  @impl true
  def handle_event("validate", %{"quiz" => quiz_params}, socket) do
    questions = normalize_questions(quiz_params["questions"] || [])
    quiz_params = Map.put(quiz_params, "questions", questions)

    socket = ensure_uploads(socket, quiz_params)

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
    new_temp_id = "q_#{System.unique_integer([:positive])}"

    new_question = %{
      "temp_id" => new_temp_id,
      "order" => length(questions) + 1,
      "body" => "",
      "image_url" => "",
      "time_limit_seconds" => 20,
      "answer_options" => [
        %{"body" => "", "is_correct" => true},
        %{"body" => "", "is_correct" => false}
      ]
    }

    updated_questions = questions ++ [new_question]
    updated_params = Map.put(params, "questions", updated_questions)

    socket =
      allow_upload(socket, String.to_atom("question_image_#{new_temp_id}"),
        accept: ~w(.jpg .jpeg .png .webp .gif),
        max_entries: 1,
        max_file_size: 10_000_000
      )

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

    {removed_q, remaining_questions} =
      if length(questions) > 1 do
        removed = Enum.at(questions, index)

        rem =
          questions
          |> List.delete_at(index)
          |> Enum.with_index(1)
          |> Enum.map(fn {q, i} -> Map.put(q, "order", i) end)

        {removed, rem}
      else
        {nil, questions}
      end

    socket =
      if removed_q && removed_q["temp_id"] do
        upload_name = String.to_atom("question_image_#{removed_q["temp_id"]}")

        if socket.assigns[:uploads] && socket.assigns[:uploads][upload_name] do
          disallow_upload(socket, upload_name)
        else
          socket
        end
      else
        socket
      end

    updated_params = Map.put(params, "questions", remaining_questions)
    changeset = Quizzes.change_quiz(socket.assigns.quiz, updated_params)

    {:noreply,
     socket
     |> assign(:quiz_params, updated_params)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref, "upload" => upload_name_str}, socket) do
    upload_name = String.to_atom(upload_name_str)
    {:noreply, cancel_upload(socket, upload_name, ref)}
  end

  @impl true
  def handle_event("remove-quiz-image", _params, socket) do
    socket =
      if socket.assigns[:uploads] && socket.assigns[:uploads][:quiz_image] do
        case socket.assigns.uploads[:quiz_image].entries do
          [entry | _] -> cancel_upload(socket, :quiz_image, entry.ref)
          _ -> socket
        end
      else
        socket
      end

    updated_params = Map.put(socket.assigns.quiz_params, "image_url", nil)
    changeset = Quizzes.change_quiz(socket.assigns.quiz, updated_params)

    {:noreply,
     socket
     |> assign(:quiz_params, updated_params)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("remove-question-image", %{"temp-id" => temp_id}, socket) do
    upload_name = String.to_atom("question_image_#{temp_id}")

    socket =
      if socket.assigns[:uploads] && socket.assigns[:uploads][upload_name] do
        case socket.assigns.uploads[upload_name].entries do
          [entry | _] -> cancel_upload(socket, upload_name, entry.ref)
          _ -> socket
        end
      else
        socket
      end

    questions = normalize_questions(socket.assigns.quiz_params["questions"] || [])

    updated_questions =
      Enum.map(questions, fn q ->
        if q["temp_id"] == temp_id do
          Map.put(q, "image_url", nil)
        else
          q
        end
      end)

    updated_params = Map.put(socket.assigns.quiz_params, "questions", updated_questions)
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
    questions =
      normalize_questions(
        quiz_params["questions"] || socket.assigns.quiz_params["questions"] || []
      )

    # 1. Process quiz cover image upload
    quiz_image_url =
      if socket.assigns[:uploads] && socket.assigns[:uploads][:quiz_image] do
        case consume_uploaded_entries(socket, :quiz_image, fn %{path: path}, entry ->
               case Quizir.Storage.upload_file(path, entry.client_name) do
                 {:ok, url} -> {:ok, url}
                 {:error, _} -> {:ok, nil}
               end
             end) do
          [url | _] when is_binary(url) and url != "" ->
            url

          _ ->
            val = quiz_params["image_url"] || socket.assigns.quiz_params["image_url"]
            if val in [nil, ""], do: nil, else: val
        end
      else
        val = quiz_params["image_url"] || socket.assigns.quiz_params["image_url"]
        if val in [nil, ""], do: nil, else: val
      end

    # 2. Process questions images uploads
    updated_questions =
      Enum.map(questions, fn q ->
        temp_id = q["temp_id"]
        upload_name = temp_id && String.to_atom("question_image_#{temp_id}")

        q_image_url =
          if upload_name && socket.assigns[:uploads] && socket.assigns[:uploads][upload_name] do
            case consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
                   case Quizir.Storage.upload_file(path, entry.client_name) do
                     {:ok, url} -> {:ok, url}
                     {:error, _} -> {:ok, nil}
                   end
                 end) do
              [url | _] when is_binary(url) and url != "" ->
                url

              _ ->
                val = q["image_url"]
                if val in [nil, ""], do: nil, else: val
            end
          else
            val = q["image_url"]
            if val in [nil, ""], do: nil, else: val
          end

        Map.put(q, "image_url", q_image_url)
      end)

    final_quiz_params =
      quiz_params
      |> Map.put("image_url", quiz_image_url)
      |> Map.put("questions", updated_questions)

    save_quiz(socket, socket.assigns.live_action, final_quiz_params)
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

  defp ensure_temp_id(%{"temp_id" => id} = q) when is_binary(id) and id != "", do: q

  defp ensure_temp_id(q) do
    id = q["id"] || System.unique_integer([:positive])
    Map.put(q, "temp_id", "q_#{id}")
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
    |> Enum.map(fn {_k, q} ->
      q
      |> ensure_temp_id()
      |> Map.update("answer_options", [], &normalize_options/1)
    end)
  end

  defp normalize_questions(qs) when is_list(qs) do
    Enum.map(qs, fn q ->
      q
      |> ensure_temp_id()
      |> Map.update("answer_options", [], &normalize_options/1)
    end)
  end

  defp normalize_questions(_), do: []

  defp error_to_string(:too_large), do: "Le fichier est trop volumineux (max 10 Mo)."
  defp error_to_string(:not_accepted), do: "Format de fichier non supporté (JPG, PNG, WebP, GIF)."
  defp error_to_string(:too_many_files), do: "Trop de fichiers sélectionnés."
  defp error_to_string(err), do: "Erreur de téléversement : #{inspect(err)}"

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

            <!-- Image d'illustration du quiz (card cover) entre titre et description -->
            <div>
              <label class="label text-sm font-semibold pb-1">
                Image d'illustration du quiz (optionnelle)
              </label>
              <input type="hidden" name="quiz[image_url]" value={@quiz_params["image_url"] || ""} />

              <%= if @quiz_params["image_url"] && @quiz_params["image_url"] != "" && (!@uploads.quiz_image || Enum.empty?(@uploads.quiz_image.entries)) do %>
                <div class="relative group max-w-sm rounded-xl overflow-hidden border border-base-300 shadow-sm bg-base-200/50">
                  <img
                    id="quiz-cover-preview"
                    src={@quiz_params["image_url"]}
                    alt="Illustration du quiz"
                    class="w-full h-44 object-cover"
                  />
                  <div class="p-2 bg-base-100/90 backdrop-blur-xs flex items-center justify-between border-t border-base-200">
                    <span class="text-xs text-base-content/70 truncate">Image actuelle</span>
                    <button
                      type="button"
                      id="remove-quiz-image-btn"
                      phx-click="remove-quiz-image"
                      class="btn btn-xs btn-error btn-ghost gap-1"
                    >
                      <.icon name="hero-trash" class="size-3.5" /> Supprimer
                    </button>
                  </div>
                </div>
              <% else %>
                <%= if @uploads.quiz_image do %>
                  <div
                    class="border-2 border-dashed border-base-300 rounded-xl p-4 text-center hover:border-primary/50 transition cursor-pointer bg-base-200/20"
                    phx-drop-target={@uploads.quiz_image.ref}
                  >
                    <%= for entry <- @uploads.quiz_image.entries do %>
                      <div class="flex flex-col items-center gap-2">
                        <div class="max-w-xs rounded-lg overflow-hidden border border-base-300">
                          <.live_img_preview entry={entry} class="w-full h-36 object-cover" />
                        </div>
                        <div class="w-full max-w-xs space-y-1">
                          <div class="flex items-center justify-between text-xs">
                            <span class="truncate">{entry.client_name}</span>
                            <button
                              type="button"
                              phx-click="cancel-upload"
                              phx-value-ref={entry.ref}
                              phx-value-upload="quiz_image"
                              class="text-error hover:underline text-xs"
                            >
                              Annuler
                            </button>
                          </div>
                          <progress
                            class="progress progress-primary w-full h-1.5"
                            value={entry.progress}
                            max="100"
                          >
                            {entry.progress}%
                          </progress>
                        </div>
                      </div>
                    <% end %>

                    <%= if Enum.empty?(@uploads.quiz_image.entries) do %>
                      <label for={@uploads.quiz_image.ref} class="cursor-pointer block">
                        <.icon name="hero-photo" class="size-8 mx-auto text-base-content/40 mb-1" />
                        <span class="text-sm font-medium text-primary hover:underline">
                          Téléverser une image de couverture
                        </span>
                        <span class="text-xs text-base-content/60 block mt-0.5">
                          Glissez-déposez ou cliquez (PNG, JPG, WebP, GIF jusqu'à 10 Mo)
                        </span>
                      </label>
                    <% end %>
                    <.live_file_input upload={@uploads.quiz_image} class="hidden" />
                  </div>

                  <%= for err <- upload_errors(@uploads.quiz_image) do %>
                    <p class="text-xs text-error mt-1">{error_to_string(err)}</p>
                  <% end %>
                  <%= for entry <- @uploads.quiz_image.entries, err <- upload_errors(@uploads.quiz_image, entry) do %>
                    <p class="text-xs text-error mt-1">{error_to_string(err)}</p>
                  <% end %>
                <% end %>
              <% end %>
            </div>

            <.input
              field={@form[:description]}
              id="quiz-description"
              type="textarea"
              label="Description"
              placeholder="Description brève de votre quiz..."
            />

            <div>
              <.input
                field={@form[:visibility]}
                id="quiz-visibility"
                type="select"
                label="Visibilité du quiz"
                options={[
                  {"Public (tout le monde peut lancer une partie ou le dupliquer)", "public"},
                  {"Privé (réservé exclusivement à votre usage)", "private"}
                ]}
              />
              <p class="text-xs text-base-content/60 mt-1.5">
                Un quiz public permet à tous les utilisateurs d'organiser des parties ou d'en créer une copie personnelle.
              </p>
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
                <% current_q =
                  Enum.at(normalize_questions(@quiz_params["questions"]), q_form.index) || %{} %>
                <% temp_id = q_form[:temp_id].value || current_q["temp_id"] %>
                <% upload_name = temp_id && String.to_atom("question_image_#{temp_id}") %>
                <% q_upload = upload_name && @uploads[upload_name] %>
                <% q_img_url = q_form[:image_url].value || current_q["image_url"] %>

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
                    <input type="hidden" name={q_form[:temp_id].name} value={temp_id} />
                    <input type="hidden" name={q_form[:image_url].name} value={q_img_url || ""} />

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
                        placeholder="Ex: Quel est le nom de cet acteur ?"
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

                  <!-- Question Image Upload / Preview -->
                  <div class="mb-4">
                    <label class="label text-xs font-semibold text-base-content/80 pb-1">
                      Illustration de la question (optionnelle)
                    </label>

                    <%= if q_img_url && q_img_url != "" && (!q_upload || Enum.empty?(q_upload.entries)) do %>
                      <div class="relative group max-w-xs rounded-xl overflow-hidden border border-base-300 shadow-sm bg-base-200/50">
                        <img
                          id={"question-image-preview-#{q_form.index}"}
                          src={q_img_url}
                          alt="Illustration de la question"
                          class="w-full h-32 object-contain bg-base-200/30"
                        />
                        <div class="p-1.5 bg-base-100/90 backdrop-blur-xs flex items-center justify-between border-t border-base-200">
                          <span class="text-xs text-base-content/70 truncate">Image actuelle</span>
                          <button
                            type="button"
                            id={"remove-question-image-#{q_form.index}-btn"}
                            phx-click="remove-question-image"
                            phx-value-temp-id={temp_id}
                            class="btn btn-xs btn-error btn-ghost gap-1"
                          >
                            <.icon name="hero-trash" class="size-3" /> Supprimer
                          </button>
                        </div>
                      </div>
                    <% else %>
                      <%= if q_upload do %>
                        <div
                          class="border border-dashed border-base-300 rounded-lg p-3 text-center hover:border-primary/50 transition cursor-pointer bg-base-200/20"
                          phx-drop-target={q_upload.ref}
                        >
                          <%= for entry <- q_upload.entries do %>
                            <div class="flex items-center gap-3 p-1 rounded-lg">
                              <div class="size-16 rounded-md overflow-hidden shrink-0 border border-base-300">
                                <.live_img_preview entry={entry} class="size-full object-cover" />
                              </div>
                              <div class="flex-1 min-w-0 space-y-1 text-left">
                                <div class="flex items-center justify-between text-xs">
                                  <span class="truncate font-medium">{entry.client_name}</span>
                                  <button
                                    type="button"
                                    phx-click="cancel-upload"
                                    phx-value-ref={entry.ref}
                                    phx-value-upload={to_string(upload_name)}
                                    class="text-error hover:underline text-xs"
                                  >
                                    Annuler
                                  </button>
                                </div>
                                <progress
                                  class="progress progress-primary w-full h-1.5"
                                  value={entry.progress}
                                  max="100"
                                >
                                  {entry.progress}%
                                </progress>
                              </div>
                            </div>
                          <% end %>

                          <%= if Enum.empty?(q_upload.entries) do %>
                            <label
                              for={q_upload.ref}
                              class="cursor-pointer flex items-center justify-center gap-2"
                            >
                              <.icon name="hero-photo" class="size-4 text-primary" />
                              <span class="text-xs font-semibold text-primary hover:underline">
                                Ajouter une photo pour cette question
                              </span>
                              <span class="text-2xs text-base-content/50">
                                (PNG, JPG, WebP, GIF jusqu'à 10 Mo)
                              </span>
                            </label>
                          <% end %>
                          <.live_file_input upload={q_upload} class="hidden" />
                        </div>

                        <%= for err <- upload_errors(q_upload) do %>
                          <p class="text-xs text-error mt-0.5">{error_to_string(err)}</p>
                        <% end %>
                        <%= for entry <- q_upload.entries, err <- upload_errors(q_upload, entry) do %>
                          <p class="text-xs text-error mt-0.5">{error_to_string(err)}</p>
                        <% end %>
                      <% end %>
                    <% end %>
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
    </Layouts.app>
    """
  end
end
