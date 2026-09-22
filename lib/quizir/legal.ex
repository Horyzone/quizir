defmodule Quizir.Legal do
  @moduledoc """
  Contexte pour la gestion et l'affichage des documents légaux et d'information
  (Mentions Légales, CGU, RGPD) lus à partir de fichiers Markdown situés dans `priv/legal/`.
  """

  alias Quizir.Legal.Markdown

  @pages [
    %{
      slug: "mentions-legales",
      short_title: "Mentions Légales",
      title: "Mentions Légales",
      file: "mentions_legales.md",
      description: "Informations légales, éditeur, hébergement et engagement de transparence.",
      icon: "hero-information-circle"
    },
    %{
      slug: "cgu",
      short_title: "CGU",
      title: "Conditions Générales d'Utilisation",
      file: "cgu.md",
      description: "Règles d'utilisation de la plateforme de démonstration Quizir.",
      icon: "hero-document-text"
    },
    %{
      slug: "rgpd",
      short_title: "RGPD",
      title: "Protection des Données & RGPD",
      file: "rgpd.md",
      description: "Engagement de non-transmission à des tiers et respect de la vie privée.",
      icon: "hero-shield-check"
    }
  ]

  @pages_by_slug Map.new(@pages, fn page -> {page.slug, page} end)

  @doc """
  Retourne la liste de toutes les pages légales disponibles.
  """
  @spec list_pages() :: [map()]
  def list_pages, do: @pages

  @doc """
  Récupère une page légale par son slug, lit son fichier Markdown et convertit son contenu en HTML.
  """
  @spec get_page(String.t() | atom()) :: {:ok, map()} | {:error, :not_found | File.posix()}
  def get_page(slug) do
    normalized = normalize_slug(slug)

    case Map.get(@pages_by_slug, normalized) do
      nil ->
        {:error, :not_found}

      meta ->
        path = resolve_file_path(meta.file)

        case File.read(path) do
          {:ok, content_raw} ->
            content_html = Markdown.to_html(content_raw)
            {:ok, Map.merge(meta, %{content_raw: content_raw, content_html: content_html})}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Identique à `get_page/1`, mais lève une exception en cas d'erreur.
  """
  @spec get_page!(String.t() | atom()) :: map()
  def get_page!(slug) do
    case get_page(slug) do
      {:ok, page} -> page
      {:error, :not_found} -> raise "Page légale introuvable pour le slug: #{inspect(slug)}"
      {:error, reason} -> raise "Impossible de lire le document légal: #{inspect(reason)}"
    end
  end

  @doc """
  Convertit un texte Markdown en HTML stylisé via `Quizir.Legal.Markdown`.
  """
  defdelegate to_html(markdown), to: Markdown

  defp normalize_slug(slug) when is_atom(slug), do: normalize_slug(Atom.to_string(slug))

  defp normalize_slug(slug) when is_binary(slug) do
    case String.downcase(String.trim(slug)) do
      s when s in ["mentions-legales", "mentions_legales", "mentionslegales", "mentions"] ->
        "mentions-legales"

      s when s in ["cgu", "tos", "conditions", "terms"] ->
        "cgu"

      s when s in ["rgpd", "gdpr", "privacy", "confidentialite"] ->
        "rgpd"

      other ->
        other
    end
  end

  defp resolve_file_path(filename) do
    source_path = Path.join(["priv", "legal", filename])
    build_path = Application.app_dir(:quizir, ["priv", "legal", filename])

    cond do
      File.exists?(source_path) -> source_path
      File.exists?(build_path) -> build_path
      true -> source_path
    end
  end
end
