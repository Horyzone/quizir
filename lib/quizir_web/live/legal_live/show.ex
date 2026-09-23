defmodule QuizirWeb.LegalLive.Show do
  use QuizirWeb, :live_view

  alias Quizir.Legal

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:pages, Legal.list_pages())
     |> assign(:page, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    slug =
      case socket.assigns.live_action do
        :mentions_legales -> "mentions-legales"
        :cgu -> "cgu"
        :rgpd -> "rgpd"
        _ -> Map.get(params, "page", "mentions-legales")
      end

    case Legal.get_page(slug) do
      {:ok, page} ->
        {:noreply,
         socket
         |> assign(:page, page)
         |> assign(:page_title, page.title)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Le document demandé est introuvable.")
         |> push_navigate(to: ~p"/mentions-legales")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_admin_user={@current_admin_user}
      is_admin={false}
      container_class="mx-auto max-w-4xl space-y-6"
    >
      <!-- Navigation fil d'Ariane -->
      <div class="flex items-center justify-between gap-4">
        <.link
          navigate={~p"/"}
          class="inline-flex items-center gap-1.5 text-xs font-semibold text-base-content/60 hover:text-primary transition-colors py-1"
        >
          <.icon name="hero-arrow-left" class="size-3.5" />
          <span>Retour à l'accueil</span>
        </.link>

        <div class="flex items-center gap-2 text-xs text-base-content/60">
          <span class="inline-flex items-center gap-1">
            <.icon name="hero-shield-check" class="size-3.5 text-success" />
            <span class="hidden xs:inline">Données sécurisées</span>
          </span>
          <span>•</span>
          <span class="inline-flex items-center gap-1">
            <.icon name="hero-no-symbol" class="size-3.5 text-info" />
            <span>0 tiers</span>
          </span>
        </div>
      </div>

      <!-- Bannière de contexte démonstrateur technique -->
      <div class="card bg-linear-to-r from-primary/10 via-base-200 to-secondary/10 border border-primary/20 p-4 sm:p-5 rounded-2xl shadow-xs">
        <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div class="flex items-start gap-3.5">
            <div class="p-2.5 rounded-xl bg-primary/15 text-primary shrink-0 mt-0.5 sm:mt-0">
              <.icon name="hero-code-bracket" class="size-6" />
            </div>
            <div>
              <div class="flex flex-wrap items-center gap-2">
                <h2 class="font-bold text-base-content text-sm sm:text-base">
                  Plateforme de démonstration technique
                </h2>
                <span class="badge badge-primary badge-xs font-semibold">Non commercial</span>
              </div>
              <p class="text-xs sm:text-sm text-base-content/75 mt-1 leading-relaxed">
                Ce projet a pour objet exclusif l'expérimentation et l'illustration des compétences techniques des développeurs (Elixir, Phoenix LiveView, OTP, PostgreSQL).
                <strong>Aucune donnée personnelle n'est transmise ou vendue à des tiers.</strong>
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Onglets de sélection des documents légaux -->
      <div class="flex items-center gap-1.5 sm:gap-2 p-1 bg-base-200/80 rounded-2xl border border-base-300/60 overflow-x-auto">
        <%= for p <- @pages do %>
          <.link
            navigate={legal_path(p.slug)}
            class={[
              "flex items-center gap-2 px-3 sm:px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition-all shrink-0 select-none",
              if(@page && @page.slug == p.slug,
                do: "bg-primary text-primary-content shadow-sm",
                else: "text-base-content/70 hover:text-base-content hover:bg-base-100"
              )
            ]}
          >
            <.icon name={p.icon} class="size-4 shrink-0" />
            <span>{p.title}</span>
          </.link>
        <% end %>
      </div>

      <!-- Corps du document légal -->
      <%= if @page do %>
        <article
          id={"legal-doc-#{@page.slug}"}
          class="card bg-base-100 border border-base-200 shadow-lg p-6 sm:p-10 lg:p-12 rounded-3xl"
        >
          <div class="prose max-w-none">
            {raw(@page.content_html)}
          </div>

          <div class="divider my-8"></div>

          <!-- Section de bas de page du document -->
          <div class="flex flex-col sm:flex-row items-center justify-between gap-4 pt-2 text-xs text-base-content/60">
            <div class="flex items-center gap-2">
              <.icon name="hero-check-badge" class="size-4 text-success" />
              <span>Document conforme aux exigences de transparence et de déontologie logicielle.</span>
            </div>

            <div class="flex items-center gap-3">
              <.link
                navigate={~p"/quizzes"}
                class="btn btn-primary btn-xs sm:btn-sm font-semibold gap-1.5"
              >
                <.icon name="hero-sparkles" class="size-3.5" />
                <span>Découvrir les quiz</span>
              </.link>
            </div>
          </div>
        </article>
      <% end %>
    </Layouts.app>
    """
  end

  defp legal_path("mentions-legales"), do: ~p"/mentions-legales"
  defp legal_path("cgu"), do: ~p"/cgu"
  defp legal_path("rgpd"), do: ~p"/rgpd"
  defp legal_path(slug), do: ~p"/legal/#{slug}"
end
